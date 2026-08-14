import 'dart:async';
import 'dart:typed_data';

import 'package:sendreq/domain/request_runtime/long_lived_session_context.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/domain/websocket/websocket_session_registry.dart';
import 'package:sendreq/domain/websocket/websocket_transport.dart';

/// 执行层拥有的全部 WebSocket 生命周期操作门面。
class WebSocketExecutionService implements WebSocketExecutionPort {
  WebSocketExecutionService(WebSocketTransport transport) {
    _registry = WebSocketSessionRegistry(transport, onChanged: _emitChange);
  }

  late final WebSocketSessionRegistry _registry;
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  @override
  Stream<void> get changes => _changes.stream;

  void _emitChange() => _changes.add(null);

  @override
  WebSocketSession session(RequestRef requestRef) =>
      _registry.sessionFor(requestRef.id);

  @override
  Iterable<WebSocketSession> get sessions => _registry.sessions;

  @override
  Future<void> connect({
    required RequestRef requestRef,
    required Uri url,
    required Map<String, String> headers,
    required List<String> subprotocols,
    required RedactionPolicy redactionPolicy,
    required LongLivedSessionContext sessionContext,
  }) => _registry.connect(
    requestId: requestRef.id,
    configuration: WebSocketConnectionConfiguration(
      url: url,
      headers: headers,
      subprotocols: subprotocols,
      redactionPolicy: redactionPolicy,
      sessionContext: sessionContext,
    ),
  );

  @override
  Future<void> sendText(
    RequestRef requestRef,
    String value, {
    String? formatLabel,
  }) => _registry.sendText(requestRef.id, value, formatLabel: formatLabel);

  @override
  Future<void> sendBinary(
    RequestRef requestRef,
    Uint8List value, {
    String? protobufMessageType,
    String? formatLabel,
  }) => _registry.sendBinary(
    requestRef.id,
    value,
    protobufMessageType: protobufMessageType,
    formatLabel: formatLabel,
  );

  @override
  Future<void> disconnect(RequestRef requestRef) =>
      _registry.disconnect(requestRef.id);

  @override
  void markConfigurationChanged([RequestRef? requestRef]) =>
      _registry.markConfigurationChanged(requestRef?.id);

  @override
  Future<void> disposeRequest(RequestRef requestRef) =>
      _registry.disposeRequest(requestRef.id);

  @override
  Future<void> dispose() async {
    await _registry.dispose();
    await _changes.close();
  }
}
