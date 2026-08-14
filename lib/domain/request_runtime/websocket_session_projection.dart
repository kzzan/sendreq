// 由执行边界暴露的安全、只读 WebSocket 会话值。
// 注册表仍是执行运行时的实现细节；消费者
// 导入此投影契约，而非其可变的生命周期所有者。
export 'package:sendreq/domain/websocket/websocket_session_registry.dart'
    show WebSocketMessageEvent, WebSocketSession, WebSocketSessionException;
export 'package:sendreq/domain/websocket/websocket_transport.dart'
    show WebSocketConnectionState, WebSocketFrameDirection, WebSocketFrameKind;
