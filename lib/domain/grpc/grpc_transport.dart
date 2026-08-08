import 'dart:typed_data';

/// gRPC 调用生命周期状态。
enum GrpcCallState {
  /// 尚未发起调用。
  idle,

  /// 正在建立 HTTP/2 调用。
  connecting,

  /// 调用已开始；一元调用或服务端流都通过该状态接收事件。
  running,

  /// 用户已请求取消，等待底层调用结束。
  cancelling,

  /// 调用正常完成。
  completed,

  /// 调用已取消。
  cancelled,

  /// 调用失败。
  error,
}

/// gRPC 事件类型。
enum GrpcTransportEventKind {
  /// 响应头元数据。
  headers,

  /// 一条 Protobuf 响应消息。
  message,

  /// 响应 trailer 元数据。
  trailers,

  /// gRPC 状态。
  status,

  /// 调用错误。
  error,
}

/// 一次 gRPC 调用的配置。
class GrpcCallConfiguration {
  /// 构建一次 gRPC 调用的配置。
  const GrpcCallConfiguration({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
    required this.requestType,
    required this.responseType,
    required this.requestBytes,
    this.metadata = const {},
    this.useTls = true,
    this.serverStreaming = false,
    this.redactedValues = const [],
  });

  /// 服务地址，例如 `https://api.sendreq.io:443`。
  final Uri endpoint;

  /// 完整限定 service 名称。
  final String serviceName;

  /// RPC 方法名。
  final String methodName;

  /// 请求消息类型。
  final String requestType;

  /// 响应消息类型。
  final String responseType;

  /// 已编码的 Protobuf 请求体。
  final Uint8List requestBytes;

  /// 调用 metadata；由请求头与环境变量模板解析而来。
  final Map<String, String> metadata;

  /// 是否使用 TLS。
  final bool useTls;

  /// 是否为服务端流式调用。
  final bool serverStreaming;

  /// 需要在展示、历史和错误中脱敏的值。
  final List<String> redactedValues;
}

/// gRPC transport 事件，承载消息、元数据、状态或错误。
class GrpcTransportEvent {
  /// 构造响应头元数据事件。
  const GrpcTransportEvent.headers(this.metadata)
    : kind = GrpcTransportEventKind.headers,
      message = null,
      statusCode = null,
      statusMessage = null;

  /// 构造一条 Protobuf 响应消息事件。
  const GrpcTransportEvent.message(this.message)
    : kind = GrpcTransportEventKind.message,
      metadata = const {},
      statusCode = null,
      statusMessage = null;

  /// 构造响应 trailer 元数据事件。
  const GrpcTransportEvent.trailers(this.metadata)
    : kind = GrpcTransportEventKind.trailers,
      message = null,
      statusCode = null,
      statusMessage = null;

  /// 构造 gRPC 状态事件。
  const GrpcTransportEvent.status(this.statusCode, [this.statusMessage])
    : kind = GrpcTransportEventKind.status,
      metadata = const {},
      message = null;

  /// 构造调用错误事件。
  const GrpcTransportEvent.error(this.statusMessage)
    : kind = GrpcTransportEventKind.error,
      metadata = const {},
      message = null,
      statusCode = null;

  /// 事件类型。
  final GrpcTransportEventKind kind;

  /// 元数据（headers / trailers 事件携带）。
  final Map<String, String> metadata;

  /// 响应消息负载（message 事件携带）。
  final Uint8List? message;

  /// gRPC 状态码（status 事件携带）。
  final int? statusCode;

  /// 状态描述或错误信息。
  final String? statusMessage;
}

/// 已发起的 gRPC 调用。
abstract interface class GrpcCall {
  /// 调用事件流；一元响应和服务端流都从这里读取。
  Stream<GrpcTransportEvent> get events;

  /// 取消调用。
  Future<void> cancel();
}

/// gRPC 传输层抽象，负责建立一元或服务端流调用。
abstract interface class GrpcTransport {
  /// 根据 [configuration] 发起一元或服务端流调用。
  Future<GrpcCall> start(GrpcCallConfiguration configuration);
}
