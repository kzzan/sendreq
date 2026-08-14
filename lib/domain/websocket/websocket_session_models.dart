import 'dart:typed_data';

import 'package:sendreq/domain/request_runtime/long_lived_session_context.dart';
import 'package:sendreq/domain/websocket/websocket_transport.dart';

/// 一次 WebSocket 会话中记录到的单个消息事件。
class WebSocketMessageEvent {
  /// 构建一条消息事件记录。
  const WebSocketMessageEvent({
    required this.direction,
    required this.kind,
    required this.timestamp,
    required this.byteLength,
    required this.preview,
    this.textPayload,
    this.binaryPayload,
    this.protobufMessageType,
    this.error,
  });

  /// 消息方向（入站 / 出站 / 系统）。
  final WebSocketFrameDirection direction;

  /// 帧类型，决定负载放在哪个字段。
  final WebSocketFrameKind kind;

  /// 事件发生的时间戳。
  final DateTime timestamp;

  /// 负载字节长度，用于统计与内存配额控制。
  final int byteLength;

  /// 供列表展示的简短预览，文本帧截断至 512 字符。
  final String preview;

  /// 文本消息原文，仅当 [kind] 为文本时非空。
  final String? textPayload;

  /// 二进制消息原文，仅当 [kind] 为二进制时非空。
  final Uint8List? binaryPayload;

  /// Protobuf 模式发送时记录的完整消息类型；普通二进制帧为空。
  final String? protobufMessageType;

  /// 系统事件的错误信息（连接失败等）。
  final String? error;
}

/// 单个请求对应的 WebSocket 会话快照，供 UI 只读展示。
class WebSocketSession {
  /// 构建会话快照。
  const WebSocketSession({
    required this.requestId,
    required this.state,
    required this.events,
    required this.omittedEventCount,
    required this.retainedByteCount,
    this.endpoint,
    this.sessionContext = const LongLivedSessionContext.unbound(),
    this.errorMessage,
    this.connectedAt,
    this.sessionStartedAt,
    this.sessionEndedAt,
    this.inboundMessageCount = 0,
    this.outboundMessageCount = 0,
    this.requiresReconnect = false,
  });

  /// 所属请求的唯一标识。
  final String requestId;

  /// 当前连接状态。
  final WebSocketConnectionState state;

  /// 已保留的消息事件列表（不可变），受配额限制。
  final List<WebSocketMessageEvent> events;

  /// 因配额被丢弃的事件数量，用于提示用户消息被省略。
  final int omittedEventCount;

  /// 当前保留事件占用的字节总数。
  final int retainedByteCount;

  /// 已脱敏的连接端点，仅用于本地会话摘要与界面展示。
  final String? endpoint;

  /// 当前握手固定的环境与认证摘要。
  final LongLivedSessionContext sessionContext;

  /// 请求或环境已变更，当前会话仍使用原握手快照。
  final bool requiresReconnect;

  /// 最近一次连接错误信息。
  final String? errorMessage;

  /// 连接成功建立的时间。
  final DateTime? connectedAt;

  /// 本次连接尝试开始的时间，连接失败时同样保留以计算持续时间。
  final DateTime? sessionStartedAt;

  /// 本次会话结束的时间；会话尚未终止时为空。
  final DateTime? sessionEndedAt;

  /// 本次会话已收到的数据帧数量，不受内存事件缓冲裁剪影响。
  final int inboundMessageCount;

  /// 本次会话已发送的数据帧数量，不受内存事件缓冲裁剪影响。
  final int outboundMessageCount;

  /// 连接已建立时才能发送消息。
  bool get canSend => state == WebSocketConnectionState.connected;

  /// 返回应用部分变更后的新会话快照。
  ///
  /// [clearError] 为 true 时清空 [errorMessage]，[clearConnectedAt] 为 true 时
  /// 清空 [connectedAt]。
  WebSocketSession copyWith({
    WebSocketConnectionState? state,
    List<WebSocketMessageEvent>? events,
    int? omittedEventCount,
    int? retainedByteCount,
    String? endpoint,
    LongLivedSessionContext? sessionContext,
    bool? requiresReconnect,
    String? errorMessage,
    bool clearError = false,
    DateTime? connectedAt,
    bool clearConnectedAt = false,
    DateTime? sessionStartedAt,
    bool clearSessionStartedAt = false,
    DateTime? sessionEndedAt,
    bool clearSessionEndedAt = false,
    int? inboundMessageCount,
    int? outboundMessageCount,
  }) => WebSocketSession(
    requestId: requestId,
    state: state ?? this.state,
    events: events ?? this.events,
    omittedEventCount: omittedEventCount ?? this.omittedEventCount,
    retainedByteCount: retainedByteCount ?? this.retainedByteCount,
    endpoint: endpoint ?? this.endpoint,
    sessionContext: sessionContext ?? this.sessionContext,
    requiresReconnect: requiresReconnect ?? this.requiresReconnect,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    connectedAt: clearConnectedAt ? null : connectedAt ?? this.connectedAt,
    sessionStartedAt: clearSessionStartedAt
        ? null
        : sessionStartedAt ?? this.sessionStartedAt,
    sessionEndedAt: clearSessionEndedAt
        ? null
        : sessionEndedAt ?? this.sessionEndedAt,
    inboundMessageCount: inboundMessageCount ?? this.inboundMessageCount,
    outboundMessageCount: outboundMessageCount ?? this.outboundMessageCount,
  );
}

/// 会话操作不合法时抛出的异常，例如在未连接状态下发送消息。
class WebSocketSessionException implements Exception {
  /// 用 [message] 构造异常。
  const WebSocketSessionException(this.message);

  /// 面向用户的错误说明。
  final String message;

  @override
  String toString() => message;
}
