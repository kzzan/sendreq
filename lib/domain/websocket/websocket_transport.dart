import 'dart:typed_data';

/// WebSocket 连接的生命周期状态机。
enum WebSocketConnectionState {
  /// 尚未建立连接或连接已正常断开。
  disconnected,

  /// 正在发起连接握手，尚未成功。
  connecting,

  /// 连接已建立，可以收发消息。
  connected,

  /// 正在主动关闭连接。
  closing,

  /// 连接过程中发生错误，连接不可用。
  error,
}

/// WebSocket 帧的传输方向，用于区分入站、出站与系统事件。
enum WebSocketFrameDirection {
  /// 服务端发往客户端的数据帧。
  inbound,

  /// 客户端发往服务端的数据帧。
  outbound,

  /// 与数据无关的系统事件（如连接关闭、错误）。
  system,
}

/// WebSocket 帧的类型，决定事件携带的负载字段。
enum WebSocketFrameKind {
  /// 文本帧，负载在 [WebSocketTransportEvent.text]。
  text,

  /// 二进制帧，负载在 [WebSocketTransportEvent.binary]。
  binary,

  /// 连接关闭帧，原因在 [WebSocketTransportEvent.message]。
  close,

  /// 错误事件，说明在 [WebSocketTransportEvent.message]。
  error,
}

/// 建立一次 WebSocket 连接所需的全部配置。
class WebSocketConnectionConfiguration {
  /// 构建连接配置。
  ///
  /// [redactedValues] 中的敏感值在记录时会被脱敏，避免密钥泄漏到界面或历史中。
  const WebSocketConnectionConfiguration({
    required this.url,
    this.headers = const {},
    this.subprotocols = const [],
    this.redactedValues = const [],
    this.redactedEndpoint,
  });

  /// 目标 WebSocket 地址（ws:// 或 wss://）。
  final Uri url;

  /// 连接握手时携带的 HTTP 请求头。
  final Map<String, String> headers;

  /// 客户端声明的子协议列表。
  final List<String> subprotocols;

  /// 需要在记录与展示时被掩码脱敏的敏感值列表。
  final List<String> redactedValues;

  /// 已脱敏的端点展示值；为空时由 session registry 依据 [redactedValues] 生成。
  final String? redactedEndpoint;
}

/// 一次连接过程中产生的传输事件，统一封装文本、二进制与系统事件。
class WebSocketTransportEvent {
  /// 构造文本帧事件。
  const WebSocketTransportEvent.text(this.text)
    : kind = WebSocketFrameKind.text,
      binary = null,
      message = null;

  /// 构造二进制帧事件。
  const WebSocketTransportEvent.binary(this.binary)
    : kind = WebSocketFrameKind.binary,
      text = null,
      message = null;

  /// 构造连接关闭事件，[message] 为关闭原因。
  const WebSocketTransportEvent.closed([this.message])
    : kind = WebSocketFrameKind.close,
      text = null,
      binary = null;

  /// 构造错误事件，[message] 为错误描述。
  const WebSocketTransportEvent.error(this.message)
    : kind = WebSocketFrameKind.error,
      text = null,
      binary = null;

  /// 该事件的帧类型。
  final WebSocketFrameKind kind;

  /// 文本帧负载，仅当 [kind] 为 [WebSocketFrameKind.text] 时非空。
  final String? text;

  /// 二进制帧负载，仅当 [kind] 为 [WebSocketFrameKind.binary] 时非空。
  final Uint8List? binary;

  /// 关闭原因或错误描述，仅对 close / error 事件非空。
  final String? message;
}

/// 一条已建立的 WebSocket 连接，向调用方暴露事件流与发送接口。
abstract interface class WebSocketConnection {
  /// 该连接上产生的传输事件流。
  Stream<WebSocketTransportEvent> get events;

  /// 发送一条文本消息。
  Future<void> sendText(String value);

  /// 发送一条二进制消息。
  Future<void> sendBinary(Uint8List value);

  /// 主动关闭连接。
  Future<void> close();
}

/// WebSocket 传输层抽象，负责根据配置建立连接。
///
/// 具体实现决定底层使用桌面原生通道还是其它方式。
abstract interface class WebSocketTransport {
  /// 根据 [configuration] 发起连接，成功返回可用的 [WebSocketConnection]。
  Future<WebSocketConnection> connect(
    WebSocketConnectionConfiguration configuration,
  );
}
