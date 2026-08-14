import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:sendreq/domain/websocket/websocket_transport.dart';

/// 桌面端 WebSocket 传输实现，底层基于 dart:io 的 WebSocket。
class DesktopWebSocketTransport implements WebSocketTransport {
  /// 创建桌面端 WebSocket 传输实现。
  const DesktopWebSocketTransport();

  /// 建立到服务端的 WebSocket 连接，并包装为统一的连接对象。
  @override
  Future<WebSocketConnection> connect(
    WebSocketConnectionConfiguration configuration,
  ) async {
    final socket = await WebSocket.connect(
      configuration.url.toString(),
      headers: configuration.headers,
      protocols: configuration.subprotocols,
    );
    return _DesktopWebSocketConnection(socket);
  }
}

/// 将 dart:io 的 WebSocket 事件适配为应用统一的传输事件流。
class _DesktopWebSocketConnection implements WebSocketConnection {
  /// 订阅底层 socket，把文本/二进制帧、错误与关闭事件翻译为传输事件。
  _DesktopWebSocketConnection(this._socket) {
    _subscription = _socket.listen(
      (dynamic data) {
        if (data is String) {
          _events.add(WebSocketTransportEvent.text(data));
        } else if (data is List<int>) {
          // 二进制帧统一转换为 Uint8List 后广播，便于上层统一处理。
          _events.add(WebSocketTransportEvent.binary(Uint8List.fromList(data)));
        } else {
          // 未知帧类型同样上报错误，保证事件流能表达底层连接异常。
          _events.add(
            const WebSocketTransportEvent.error('Unsupported WebSocket frame.'),
          );
        }
      },
      onError: (dynamic error) =>
          _events.add(WebSocketTransportEvent.error('$error')),
      onDone: () => _events.add(
        // 保留服务端 close code 与 reason；会话投影在展示或持久化前脱敏。
        WebSocketTransportEvent.closed(_closeMessage(_socket)),
      ),
    );
  }

  /// 底层 dart:io 的 WebSocket 连接。
  final WebSocket _socket;
  // 使用广播流，使多个订阅者（如 UI 与日志面板）能同时监听。
  final StreamController<WebSocketTransportEvent> _events =
      StreamController<WebSocketTransportEvent>.broadcast();

  /// 底层 socket 的事件订阅，close 时需取消。
  late final StreamSubscription<dynamic> _subscription;

  /// 对外暴露的传输事件流。
  @override
  Stream<WebSocketTransportEvent> get events => _events.stream;

  /// 发送二进制帧。
  @override
  Future<void> sendBinary(Uint8List value) async {
    _socket.add(value);
  }

  /// 发送文本帧。
  @override
  Future<void> sendText(String value) async {
    _socket.add(value);
  }

  /// 依次关闭底层连接、取消订阅并关闭事件流。
  @override
  Future<void> close() async {
    await _socket.close();
    await _subscription.cancel();
    await _events.close();
  }

  static String? _closeMessage(WebSocket socket) {
    final code = socket.closeCode;
    final reason = socket.closeReason;
    if (code == null && (reason == null || reason.isEmpty)) return null;
    if (reason == null || reason.isEmpty) return 'Closed ($code).';
    return code == null ? 'Closed: $reason' : 'Closed ($code): $reason';
  }
}
