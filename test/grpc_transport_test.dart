import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:sendreq/data/services/desktop_grpc_transport.dart';
import 'package:sendreq/domain/grpc/grpc_transport.dart';

void main() {
  // 用例：验证伪 gRPC 传输能完整记录启动时传入的配置，并按先后顺序
  // 播发 headers -> message -> trailers -> status 事件，且支持取消。
  test(
    'fake gRPC transport records configuration and emits ordered events',
    () async {
      final call = _FakeGrpcCall();
      final transport = _FakeGrpcTransport(call);
      final events = <GrpcTransportEvent>[];

      // 启动一次服务端流式调用，携带请求字节与鉴权元数据。
      final activeCall = await transport.start(
        GrpcCallConfiguration(
          endpoint: Uri.parse('https://api.sendreq.io'),
          serviceName: '.sendreq.Health',
          methodName: 'Watch',
          requestType: '.sendreq.CheckRequest',
          responseType: '.sendreq.CheckResponse',
          requestBytes: Uint8List.fromList([1, 2]),
          metadata: const {'authorization': 'Bearer token'},
          serverStreaming: true,
          redactedValues: const ['token'],
        ),
      );
      final subscription = activeCall.events.listen(events.add);

      // 按 gRPC 生命周期依次模拟四个阶段的事件。
      call.emit(
        const GrpcTransportEvent.headers({'content-type': 'application/grpc'}),
      );
      call.emit(GrpcTransportEvent.message(Uint8List.fromList([8, 1])));
      call.emit(const GrpcTransportEvent.trailers({'grpc-status': '0'}));
      call.emit(const GrpcTransportEvent.status(0, 'OK'));
      // 让异步事件队列先刷新，再断言收到的顺序。
      await Future<void>.delayed(Duration.zero);

      // 配置被完整记录，且事件顺序与发出顺序一致。
      expect(transport.configurations.single.serverStreaming, isTrue);
      expect(events.map((event) => event.kind), [
        GrpcTransportEventKind.headers,
        GrpcTransportEventKind.message,
        GrpcTransportEventKind.trailers,
        GrpcTransportEventKind.status,
      ]);
      // 取消调用会向下传递到伪传输层。
      await activeCall.cancel();
      expect(call.cancelled, isTrue);
      await subscription.cancel();
    },
  );

  test(
    'desktop gRPC transport forwards metadata and response lifecycle',
    () async {
      final service = _HealthService();
      final server = grpc.Server.create(services: [service]);
      await server.serve(
        address: InternetAddress.loopbackIPv4,
        port: 0,
        security: grpc.ServerLocalCredentials(),
      );
      addTearDown(server.shutdown);
      final transport = const DesktopGrpcTransport();

      final call = await transport.start(
        GrpcCallConfiguration(
          endpoint: Uri.parse('http://127.0.0.1:${server.port}'),
          serviceName: '.sendreq.Health',
          methodName: 'Check',
          requestType: '.sendreq.CheckRequest',
          responseType: '.sendreq.CheckResponse',
          requestBytes: Uint8List.fromList([8, 1]),
          metadata: const {'x-sendreq-token': 'test-token'},
          useTls: false,
        ),
      );
      final events = await call.events.toList();

      expect(events.map((event) => event.kind), [
        GrpcTransportEventKind.headers,
        GrpcTransportEventKind.message,
        GrpcTransportEventKind.trailers,
        GrpcTransportEventKind.status,
      ]);
      expect(events[1].message, Uint8List.fromList([8, 1]));
      expect(events[2].metadata['x-sendreq-trailer'], 'complete');
      expect(events[3].statusCode, 0);
      expect(service.receivedToken, 'test-token');
    },
  );

  test(
    'desktop gRPC transport forwards every server-streamed message',
    () async {
      final server = grpc.Server.create(services: [_HealthService()]);
      await server.serve(
        address: InternetAddress.loopbackIPv4,
        port: 0,
        security: grpc.ServerLocalCredentials(),
      );
      addTearDown(server.shutdown);
      final call = await const DesktopGrpcTransport().start(
        GrpcCallConfiguration(
          endpoint: Uri.parse('http://127.0.0.1:${server.port}'),
          serviceName: '.sendreq.Health',
          methodName: 'Watch',
          requestType: '.sendreq.CheckRequest',
          responseType: '.sendreq.CheckResponse',
          requestBytes: Uint8List.fromList([8, 1]),
          useTls: false,
          serverStreaming: true,
        ),
      );

      final events = await call.events.toList();
      final messages = events
          .where((event) => event.kind == GrpcTransportEventKind.message)
          .map((event) => event.message)
          .toList();

      expect(messages, [
        Uint8List.fromList([8, 1]),
        Uint8List.fromList([8, 2]),
      ]);
      expect(events.last.kind, GrpcTransportEventKind.status);
      expect(events.last.statusCode, 0);
    },
  );
}

class _HealthService extends grpc.Service {
  _HealthService() {
    $addMethod(
      grpc.ServiceMethod<Uint8List, Uint8List>(
        'Check',
        _check,
        false,
        false,
        Uint8List.fromList,
        (value) => value,
      ),
    );
    $addMethod(
      grpc.ServiceMethod<Uint8List, Uint8List>(
        'Watch',
        _watch,
        false,
        true,
        Uint8List.fromList,
        (value) => value,
      ),
    );
  }

  String? receivedToken;

  @override
  String get $name => 'sendreq.Health';

  @override
  void $onMetadata(grpc.ServiceCall context) {
    receivedToken = context.clientMetadata?['x-sendreq-token'];
  }

  Future<Uint8List> _check(
    grpc.ServiceCall call,
    Future<Uint8List> request,
  ) async {
    call.headers?['x-sendreq-header'] = 'ready';
    call.trailers?['x-sendreq-trailer'] = 'complete';
    return request;
  }

  Stream<Uint8List> _watch(
    grpc.ServiceCall call,
    Future<Uint8List> request,
  ) async* {
    yield await request;
    yield Uint8List.fromList([8, 2]);
  }
}

/// 伪传输实现：仅记录配置，并始终返回同一个伪调用对象。
class _FakeGrpcTransport implements GrpcTransport {
  _FakeGrpcTransport(this.call);

  final _FakeGrpcCall call;

  /// 所有启动过的调用配置，供测试断言。
  final configurations = <GrpcCallConfiguration>[];

  @override
  Future<GrpcCall> start(GrpcCallConfiguration configuration) async {
    configurations.add(configuration);
    return call;
  }
}

/// 伪调用实现：通过广播流对外播发事件，并记录是否被取消。
class _FakeGrpcCall implements GrpcCall {
  final _events = StreamController<GrpcTransportEvent>.broadcast();

  /// 标记是否收到 cancel()。
  bool cancelled = false;

  @override
  Stream<GrpcTransportEvent> get events => _events.stream;

  /// 向广播流推送一个事件（模拟服务端消息）。
  void emit(GrpcTransportEvent event) => _events.add(event);

  @override
  Future<void> cancel() async {
    cancelled = true;
  }
}
