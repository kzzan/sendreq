import 'dart:async';
import 'dart:typed_data';

import 'package:grpc/grpc.dart' as grpc;

import '../../domain/grpc/grpc_transport.dart';

/// Windows、macOS 与 Linux 共用的 gRPC HTTP/2 transport。
///
/// 每个应用调用独占一个 channel。这样取消或调用结束时可以确定释放底层
/// socket，也避免一个请求的 TLS/认证配置影响另一个请求。
class DesktopGrpcTransport implements GrpcTransport {
  /// 创建桌面 gRPC transport。
  const DesktopGrpcTransport();

  @override
  /// 按配置建立独立的 gRPC channel 并发起一次调用。
  Future<GrpcCall> start(GrpcCallConfiguration configuration) async {
    final host = configuration.endpoint.host;
    if (host.isEmpty) {
      throw ArgumentError.value(
        configuration.endpoint,
        'configuration.endpoint',
        'gRPC endpoint must include a host.',
      );
    }
    if (configuration.serviceName.trim().isEmpty ||
        configuration.methodName.trim().isEmpty) {
      throw ArgumentError('gRPC service and method must be selected.');
    }

    final channel = grpc.ClientChannel(
      host,
      port: configuration.endpoint.hasPort
          ? configuration.endpoint.port
          : configuration.useTls
          ? 443
          : 80,
      options: grpc.ChannelOptions(
        credentials: configuration.useTls
            ? const grpc.ChannelCredentials.secure()
            : const grpc.ChannelCredentials.insecure(),
      ),
    );
    final method = grpc.ClientMethod<Uint8List, Uint8List>(
      _methodPath(configuration.serviceName, configuration.methodName),
      (value) => value,
      Uint8List.fromList,
    );
    final call = channel.createCall(
      method,
      Stream<Uint8List>.value(configuration.requestBytes),
      grpc.CallOptions(metadata: configuration.metadata),
    );
    return _DesktopGrpcCall(call, channel);
  }

  /// gRPC wire path 不带 protobuf 类型全名约定使用的前导点。
  static String _methodPath(String serviceName, String methodName) {
    final service = serviceName.trim().replaceFirst(RegExp(r'^\.+'), '');
    return '/$service/${methodName.trim()}';
  }
}

/// 将 `package:grpc` 的 ClientCall 适配为应用领域事件流。
class _DesktopGrpcCall implements GrpcCall {
  /// 订阅响应流并异步转发响应头。
  _DesktopGrpcCall(this._call, this._channel) {
    _responseSubscription = _call.response.listen(
      (message) => _add(GrpcTransportEvent.message(message)),
      onError: _onError,
      onDone: _onDone,
      cancelOnError: true,
    );
    unawaited(_forwardHeaders());
  }

  /// 底层 gRPC 调用对象。
  final grpc.ClientCall<Uint8List, Uint8List> _call;

  /// 调用专属的 client channel，结束时需关闭以释放资源。
  final grpc.ClientChannel _channel;

  /// 向订阅者派发 transport 事件。
  final StreamController<GrpcTransportEvent> _events = StreamController();

  /// 响应流订阅，用于统一取消。
  late final StreamSubscription<Uint8List> _responseSubscription;

  /// 是否已请求取消。
  bool _cancelled = false;

  /// 是否已完成清理（订阅、channel、事件流均已关闭）。
  bool _finished = false;

  @override
  /// 暴露 transport 事件流。
  Stream<GrpcTransportEvent> get events => _events.stream;

  /// 转发响应头 metadata 到事件流。
  Future<void> _forwardHeaders() async {
    try {
      final metadata = await _call.headers;
      _add(GrpcTransportEvent.headers(metadata));
    } on Object catch (error) {
      _onError(error);
    }
  }

  /// 流结束时读取 trailers 并发出 status/trailers 事件，然后收尾。
  Future<void> _onDone() async {
    if (_cancelled || _finished) return;
    try {
      final trailers = await _call.trailers;
      _add(GrpcTransportEvent.trailers(trailers));
      _add(
        GrpcTransportEvent.status(
          int.tryParse(trailers['grpc-status'] ?? '0') ?? 0,
          trailers['grpc-message'],
        ),
      );
      await _finish();
    } on Object catch (error) {
      _onError(error);
    }
  }

  /// 将错误转为 error 事件并结束调用。
  void _onError(Object error, [StackTrace? stackTrace]) {
    if (_cancelled || _finished) return;
    _add(GrpcTransportEvent.error(error.toString()));
    unawaited(_finish());
  }

  /// 仅在尚未结束时向事件流添加事件。
  void _add(GrpcTransportEvent event) {
    if (!_finished && !_events.isClosed) _events.add(event);
  }

  /// 释放订阅、关闭 channel 并终止事件流（幂等）。
  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    await _responseSubscription.cancel();
    await _channel.shutdown();
    await _events.close();
  }

  @override
  /// 取消底层调用并完成清理。
  Future<void> cancel() async {
    if (_cancelled || _finished) return;
    _cancelled = true;
    await _call.cancel();
    await _finish();
  }
}
