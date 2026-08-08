import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/services/desktop_grpc_transport.dart';
import 'package:sendreq/data/services/desktop_websocket_transport.dart';
import 'package:sendreq/data/services/proto_source_parser.dart';
import 'package:sendreq/data/services/protobuf_dynamic_codec.dart';
import 'package:sendreq/domain/grpc/grpc_transport.dart';
import 'package:sendreq/domain/websocket/websocket_transport.dart';

/// Real Go interop tests are opt-in because they start local Go processes.
///
/// Run them on each desktop operating system with:
/// `SENDREQ_GO_INTEROP=1 flutter test test/go_protocol_interop_test.dart`
final _enabled =
    Platform.environment['SENDREQ_GO_INTEROP'] == '1' ||
    const bool.fromEnvironment('SENDREQ_GO_INTEROP');

void main() {
  final skipReason = _enabled
      ? false
      : 'Set SENDREQ_GO_INTEROP=1 to run local Go protocol interop tests.';

  test(
    'go-ws echoes text and binary Protobuf WebSocket frames unchanged',
    () async {
      await _requireGo();
      final service = await _GoService.start('go-ws');
      addTearDown(service.stop);
      await service.waitForPort();

      final descriptors = await _orderDescriptors();
      final codec = ProtobufDynamicCodec(descriptors);
      final request = codec.encodeJson(
        '.order.v1.CreateOrderRequest',
        '{"user_id":"interop-user","product":"sendreq","quantity":2}',
      );
      final connection = await const DesktopWebSocketTransport().connect(
        WebSocketConnectionConfiguration(
          url: Uri.parse('ws://127.0.0.1:${service.port}/ws'),
        ),
      );
      addTearDown(connection.close);

      await connection.sendText('sendreq text interop');
      final textEvent = await connection.events.firstWhere(
        (event) => event.kind == WebSocketFrameKind.text,
      );
      expect(textEvent.text, 'sendreq text interop');

      await connection.sendBinary(request);
      final binaryEvent = await connection.events.firstWhere(
        (event) => event.kind == WebSocketFrameKind.binary,
      );
      expect(binaryEvent.binary, request);
      expect(
        jsonDecode(
          codec.decodeJson('.order.v1.CreateOrderRequest', binaryEvent.binary!),
        ),
        {'user_id': 'interop-user', 'product': 'sendreq', 'quantity': 2},
      );
    },
    skip: skipReason,
  );

  test(
    'go-grpc accepts and returns dynamically encoded Protobuf messages',
    () async {
      await _requireGo();
      final service = await _GoService.start('go-grpc');
      addTearDown(service.stop);
      await service.waitForPort();

      final descriptors = await _orderDescriptors();
      final codec = ProtobufDynamicCodec(descriptors);
      final call = await const DesktopGrpcTransport().start(
        GrpcCallConfiguration(
          endpoint: Uri.parse('http://127.0.0.1:${service.port}'),
          serviceName: '.order.v1.OrderService',
          methodName: 'CreateOrder',
          requestType: '.order.v1.CreateOrderRequest',
          responseType: '.order.v1.CreateOrderResponse',
          requestBytes: codec.encodeJson(
            '.order.v1.CreateOrderRequest',
            '{"user_id":"interop-user","product":"sendreq","quantity":2}',
          ),
          useTls: false,
        ),
      );
      addTearDown(call.cancel);

      final events = await call.events.toList();
      final response = events.singleWhere(
        (event) => event.kind == GrpcTransportEventKind.message,
      );
      final decoded =
          jsonDecode(
                codec.decodeJson(
                  '.order.v1.CreateOrderResponse',
                  response.message!,
                ),
              )
              as Map<String, dynamic>;
      final order = decoded['order'] as Map<String, dynamic>;

      expect(order['order_id'], startsWith('ORD-'));
      expect(order['user_id'], 'interop-user');
      expect(order['product'], 'sendreq');
      expect(order['quantity'], 2);
      expect(
        events.where((event) => event.kind == GrpcTransportEventKind.status),
        contains(
          predicate<GrpcTransportEvent>((event) => event.statusCode == 0),
        ),
      );
    },
    skip: skipReason,
  );
}

Future<void> _requireGo() async {
  final result = await Process.run('go', ['version']);
  if (result.exitCode != 0) {
    throw StateError(
      'Go is required for protocol interop tests: ${result.stderr}',
    );
  }
}

Future<dynamic> _orderDescriptors() => const ProtoSourceParser().parseFile(
  '${Directory.current.parent.path}${Platform.pathSeparator}go-grpc'
  '${Platform.pathSeparator}proto${Platform.pathSeparator}order.proto',
);

/// Owns a `go run .` server process and ensures test ports are not fixed.
class _GoService {
  _GoService._(this._process, this.port, this._logs, this._buildDirectory);

  final Process _process;
  final int port;
  final StringBuffer _logs;
  final Directory _buildDirectory;

  bool _stopped = false;

  static Future<_GoService> start(String directoryName) async {
    final port = await _freeLoopbackPort();
    final logs = StringBuffer();
    final projectDirectory = Directory(
      '${Directory.current.parent.path}${Platform.pathSeparator}$directoryName',
    );
    final buildDirectory = await Directory.systemTemp.createTemp(
      'sendreq-go-interop-',
    );
    final executable = File(
      '${buildDirectory.path}${Platform.pathSeparator}$directoryName'
      '${Platform.isWindows ? '.exe' : ''}',
    );
    try {
      // Compile source for the current platform instead of relying on the
      // repository's Linux-only example binaries or leaving go-run children.
      final build = await Process.run('go', [
        'build',
        '-buildvcs=false',
        '-o',
        executable.path,
        '.',
      ], workingDirectory: projectDirectory.path);
      if (build.exitCode != 0) {
        throw StateError('Unable to build $directoryName: ${build.stderr}');
      }
      final process = await Process.start(
        executable.path,
        const [],
        environment: {...Platform.environment, 'PORT': '$port'},
      );
      unawaited(
        process.stdout.transform(utf8.decoder).listen(logs.write).asFuture(),
      );
      unawaited(
        process.stderr.transform(utf8.decoder).listen(logs.write).asFuture(),
      );
      return _GoService._(process, port, logs, buildDirectory);
    } on Object {
      await buildDirectory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> waitForPort() async {
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      try {
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(milliseconds: 250),
        );
        await socket.close();
        return;
      } on Object catch (error) {
        lastError = error;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    throw StateError('Go service did not listen on $port: $lastError\n$_logs');
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _process.kill();
    await _process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _process.kill();
        return -1;
      },
    );
    await _buildDirectory.delete(recursive: true);
  }
}

Future<int> _freeLoopbackPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
