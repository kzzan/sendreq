import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:grpc/grpc.dart' as grpc;

import 'package:sendreq/domain/grpc/grpc_transport.dart';

/// Windows、macOS 与 Linux 共用的 gRPC HTTP/2 transport。
///
/// 每个应用调用独占一个 channel。这样取消或调用结束时可以确定释放底层
/// socket，也避免一个请求的 TLS/认证配置影响另一个请求。
class DesktopGrpcTransport implements GrpcTransport, GrpcReflectionTransport {
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
    final requestStream = configuration.clientStreaming
        ? StreamController<Uint8List>()
        : null;
    final call = channel.createCall(
      method,
      requestStream?.stream ??
          Stream<Uint8List>.value(configuration.requestBytes),
      grpc.CallOptions(
        metadata: {
          for (final entry in configuration.metadata.entries)
            entry.key.toLowerCase(): entry.value,
        },
        timeout: configuration.timeout,
      ),
    );
    return _DesktopGrpcCall(call, channel, requestStream);
  }

  @override
  Future<Uint8List> discover(GrpcReflectionConfiguration configuration) async {
    _validateEndpoint(configuration.endpoint);
    try {
      return await _discoverWithService(
        configuration,
        'grpc.reflection.v1.ServerReflection',
      );
    } on grpc.GrpcError catch (error) {
      if (error.code != grpc.StatusCode.unimplemented) {
        throw GrpcReflectionException(
          error.code,
          error.message ?? 'Server reflection failed.',
        );
      }
      try {
        return await _discoverWithService(
          configuration,
          'grpc.reflection.v1alpha.ServerReflection',
        );
      } on grpc.GrpcError catch (fallbackError) {
        throw GrpcReflectionException(
          fallbackError.code,
          fallbackError.message ?? 'Server reflection is unavailable.',
        );
      }
    }
  }

  Future<Uint8List> _discoverWithService(
    GrpcReflectionConfiguration configuration,
    String serviceName,
  ) async {
    final servicesResponse = await _reflectionExchange(
      configuration,
      serviceName,
      _reflectionListServicesRequest(),
    );
    final services = _reflectionServiceNames(servicesResponse)
        .where((name) => !name.startsWith('grpc.reflection.'))
        .toList(growable: false);
    if (services.isEmpty) {
      throw const FormatException('Server reflection returned no services.');
    }
    final descriptors = <String, Uint8List>{};
    for (final symbol in services) {
      final response = await _reflectionExchange(
        configuration,
        serviceName,
        _reflectionFileContainingSymbolRequest(symbol),
      );
      for (final descriptor in _reflectionFileDescriptors(response)) {
        descriptors[base64Encode(descriptor)] = descriptor;
      }
    }
    if (descriptors.isEmpty) {
      throw const FormatException(
        'Server reflection returned no file descriptors.',
      );
    }
    final output = <int>[];
    for (final descriptor in descriptors.values) {
      _writeLengthDelimitedField(output, 1, descriptor);
    }
    return Uint8List.fromList(output);
  }

  Future<Uint8List> _reflectionExchange(
    GrpcReflectionConfiguration configuration,
    String serviceName,
    Uint8List request,
  ) async {
    final channel = _channel(
      configuration.endpoint,
      useTls: configuration.useTls,
    );
    try {
      final method = grpc.ClientMethod<Uint8List, Uint8List>(
        '/$serviceName/ServerReflectionInfo',
        (value) => value,
        Uint8List.fromList,
      );
      final call = channel.createCall(
        method,
        Stream<Uint8List>.value(request),
        grpc.CallOptions(
          metadata: {
            for (final entry in configuration.metadata.entries)
              entry.key.toLowerCase(): entry.value,
          },
          timeout: configuration.timeout,
        ),
      );
      final response = await call.response.single;
      final error = _reflectionError(response);
      if (error != null) throw grpc.GrpcError.custom(error.$1, error.$2);
      return response;
    } finally {
      await channel.shutdown();
    }
  }

  grpc.ClientChannel _channel(Uri endpoint, {required bool useTls}) =>
      grpc.ClientChannel(
        endpoint.host,
        port: endpoint.hasPort
            ? endpoint.port
            : useTls
            ? 443
            : 80,
        options: grpc.ChannelOptions(
          credentials: useTls
              ? const grpc.ChannelCredentials.secure()
              : const grpc.ChannelCredentials.insecure(),
        ),
      );

  void _validateEndpoint(Uri endpoint) {
    if (endpoint.host.isEmpty) {
      throw ArgumentError.value(
        endpoint,
        'configuration.endpoint',
        'gRPC endpoint must include a host.',
      );
    }
  }

  /// gRPC wire path 不带 protobuf 类型全名约定使用的前导点。
  static String _methodPath(String serviceName, String methodName) {
    final service = serviceName.trim().replaceFirst(RegExp(r'^\.+'), '');
    return '/$service/${methodName.trim()}';
  }
}

Uint8List _reflectionListServicesRequest() {
  final bytes = <int>[];
  _writeLengthDelimitedField(bytes, 7, const []);
  return Uint8List.fromList(bytes);
}

Uint8List _reflectionFileContainingSymbolRequest(String symbol) {
  final bytes = <int>[];
  _writeLengthDelimitedField(bytes, 4, utf8.encode(symbol));
  return Uint8List.fromList(bytes);
}

List<String> _reflectionServiceNames(Uint8List response) {
  final fields = _readWireFields(response);
  final listResponse = fields.where((field) => field.number == 6).firstOrNull;
  if (listResponse == null) return const [];
  return [
    for (final service in _readWireFields(listResponse.bytes))
      if (service.number == 1)
        for (final name in _readWireFields(service.bytes))
          if (name.number == 1) utf8.decode(name.bytes),
  ];
}

List<Uint8List> _reflectionFileDescriptors(Uint8List response) {
  final fields = _readWireFields(response);
  final descriptorResponse = fields
      .where((field) => field.number == 4)
      .firstOrNull;
  if (descriptorResponse == null) return const [];
  return [
    for (final field in _readWireFields(descriptorResponse.bytes))
      if (field.number == 1) field.bytes,
  ];
}

(int, String)? _reflectionError(Uint8List response) {
  final error = _readWireFields(
    response,
  ).where((field) => field.number == 7).firstOrNull;
  if (error == null) return null;
  var code = grpc.StatusCode.unknown;
  var message = 'Server reflection failed.';
  for (final field in _readWireFields(error.bytes)) {
    if (field.number == 1) code = field.varint ?? code;
    if (field.number == 2) message = utf8.decode(field.bytes);
  }
  return (code, message);
}

void _writeLengthDelimitedField(List<int> output, int number, List<int> value) {
  _writeVarint(output, (number << 3) | 2);
  _writeVarint(output, value.length);
  output.addAll(value);
}

void _writeVarint(List<int> output, int value) {
  var remaining = value;
  while (remaining > 127) {
    output.add((remaining & 127) | 128);
    remaining >>= 7;
  }
  output.add(remaining);
}

List<_WireField> _readWireFields(Uint8List bytes) {
  final fields = <_WireField>[];
  var offset = 0;
  int readVarint() {
    var value = 0;
    var shift = 0;
    while (offset < bytes.length && shift <= 63) {
      final byte = bytes[offset++];
      value |= (byte & 127) << shift;
      if (byte & 128 == 0) return value;
      shift += 7;
    }
    throw const FormatException('Invalid reflection response.');
  }

  while (offset < bytes.length) {
    final tag = readVarint();
    final number = tag >> 3;
    switch (tag & 7) {
      case 0:
        fields.add(_WireField(number, Uint8List(0), readVarint()));
      case 1:
        offset += 8;
      case 2:
        final length = readVarint();
        if (length < 0 || offset + length > bytes.length) {
          throw const FormatException('Invalid reflection response length.');
        }
        fields.add(
          _WireField(
            number,
            Uint8List.sublistView(bytes, offset, offset + length),
            null,
          ),
        );
        offset += length;
      case 5:
        offset += 4;
      default:
        throw const FormatException('Unsupported reflection wire type.');
    }
    if (offset > bytes.length) {
      throw const FormatException('Invalid reflection response.');
    }
  }
  return fields;
}

class _WireField {
  const _WireField(this.number, this.bytes, this.varint);

  final int number;
  final Uint8List bytes;
  final int? varint;
}

/// 将 `package:grpc` 的 ClientCall 适配为应用领域事件流。
class _DesktopGrpcCall implements GrpcCall {
  /// 订阅响应流并异步转发响应头。
  _DesktopGrpcCall(this._call, this._channel, this._requestStream) {
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

  /// 客户端流调用的可写请求流；一元与纯服务端流没有该入口。
  final StreamController<Uint8List>? _requestStream;

  /// 向订阅者派发 transport 事件。
  final StreamController<GrpcTransportEvent> _events = StreamController();

  /// 响应流订阅，用于统一取消。
  late final StreamSubscription<Uint8List> _responseSubscription;

  /// 是否已请求取消。
  bool _cancelled = false;

  /// 是否已完成清理（订阅、channel、事件流均已关闭）。
  bool _finished = false;

  /// 客户端发送方向是否已关闭。
  bool _requestStreamClosed = false;

  @override
  /// 暴露 transport 事件流。
  Stream<GrpcTransportEvent> get events => _events.stream;

  @override
  Future<void> send(Uint8List message) async {
    final requestStream = _requestStream;
    if (_finished || requestStream == null || _requestStreamClosed) {
      throw StateError(
        'This gRPC call does not accept another request message.',
      );
    }
    requestStream.add(Uint8List.fromList(message));
  }

  @override
  Future<void> closeRequestStream() async {
    final requestStream = _requestStream;
    if (_finished || requestStream == null || _requestStreamClosed) return;
    _requestStreamClosed = true;
    await requestStream.close();
  }

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
    await closeRequestStream();
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
