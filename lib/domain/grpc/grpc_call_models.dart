import 'dart:typed_data';

import 'package:sendreq/domain/grpc/grpc_rpc_shape.dart';
import 'package:sendreq/domain/grpc/grpc_transport.dart';
import 'package:sendreq/domain/request_runtime/long_lived_session_context.dart';

enum GrpcCallCommand { start, sendNext, endSending, cancel, restart }

/// 一条 gRPC 调用事件的本地快照。
class GrpcCallEvent {
  const GrpcCallEvent({
    required this.kind,
    required this.timestamp,
    required this.byteLength,
    this.metadata = const {},
    this.message,
    this.statusCode,
    this.statusMessage,
  });

  /// 事件类型（headers/trailers/status/message/error）。
  final GrpcTransportEventKind kind;

  /// 事件产生的时间。
  final DateTime timestamp;

  /// 该事件计入内存预算的字节数。
  final int byteLength;

  /// 脱敏后的 metadata 键值对。
  final Map<String, String> metadata;

  /// 二进制消息体；仅在 message 类事件中存在。
  final Uint8List? message;

  /// gRPC 状态码；仅在 status 类事件中存在。
  final int? statusCode;

  /// 状态说明或错误消息；已做脱敏。
  final String? statusMessage;
}

/// 单个请求的 gRPC 调用状态，事件数量和字节数始终受限。
class GrpcCallSnapshot {
  const GrpcCallSnapshot({
    required this.requestId,
    required this.state,
    required this.events,
    required this.omittedEventCount,
    required this.retainedByteCount,
    this.headers = const {},
    this.trailers = const {},
    this.errorMessage,
    this.endpoint,
    this.sessionContext = const GrpcSessionContextSnapshot.unbound(),
    this.rpcShape = GrpcRpcShape.unary,
    this.requestStreamOpen = false,
    this.requiresRestart = false,
  });

  /// 所属请求 ID。
  final String requestId;

  /// 当前调用生命周期状态。
  final GrpcCallState state;

  /// 有界的事件历史（按数量与字节上限裁剪）。
  final List<GrpcCallEvent> events;

  /// 因超限被裁剪丢弃的事件个数。
  final int omittedEventCount;

  /// 当前保留事件占用的总字节数。
  final int retainedByteCount;

  /// 响应头 metadata。
  final Map<String, String> headers;

  /// 响应尾 metadata。
  final Map<String, String> trailers;

  /// 错误消息；成功时为空。
  final String? errorMessage;

  /// 当前调用的脱敏端点。
  final String? endpoint;

  /// 当前调用固定的环境与认证摘要。
  final GrpcSessionContextSnapshot sessionContext;

  /// 请求或环境已变更，当前调用仍使用启动时快照。
  final bool requiresRestart;

  final GrpcRpcShape rpcShape;

  bool get clientStreaming => rpcShape.hasClientStream;
  bool get serverStreaming => rpcShape.hasServerStream;

  /// 客户端发送方向是否仍可写入。
  final bool requestStreamOpen;

  Set<GrpcCallCommand> get availableCommands {
    if (state == GrpcCallState.idle) return const {GrpcCallCommand.start};
    if (state == GrpcCallState.completed ||
        state == GrpcCallState.cancelled ||
        state == GrpcCallState.error) {
      return const {GrpcCallCommand.restart};
    }
    if (state == GrpcCallState.cancelling) return const {};
    final commands = <GrpcCallCommand>{GrpcCallCommand.cancel};
    if (state == GrpcCallState.running && requestStreamOpen) {
      commands
        ..add(GrpcCallCommand.sendNext)
        ..add(GrpcCallCommand.endSending);
    }
    if (requiresRestart) commands.add(GrpcCallCommand.restart);
    return Set.unmodifiable(commands);
  }

  bool can(GrpcCallCommand command) => availableCommands.contains(command);

  /// 基于当前快照生成部分更新的副本。
  GrpcCallSnapshot copyWith({
    GrpcCallState? state,
    List<GrpcCallEvent>? events,
    int? omittedEventCount,
    int? retainedByteCount,
    Map<String, String>? headers,
    Map<String, String>? trailers,
    String? errorMessage,
    bool clearError = false,
    String? endpoint,
    GrpcSessionContextSnapshot? sessionContext,
    bool? requiresRestart,
    bool? requestStreamOpen,
  }) => GrpcCallSnapshot(
    requestId: requestId,
    state: state ?? this.state,
    events: events ?? this.events,
    omittedEventCount: omittedEventCount ?? this.omittedEventCount,
    retainedByteCount: retainedByteCount ?? this.retainedByteCount,
    headers: headers ?? this.headers,
    trailers: trailers ?? this.trailers,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    endpoint: endpoint ?? this.endpoint,
    sessionContext: sessionContext ?? this.sessionContext,
    requiresRestart: requiresRestart ?? this.requiresRestart,
    rpcShape: rpcShape,
    requestStreamOpen: requestStreamOpen ?? this.requestStreamOpen,
  );
}

/// 按请求 ID 隔离管理 gRPC 调用、取消和有界本地事件历史。
