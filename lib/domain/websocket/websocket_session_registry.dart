import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/websocket/websocket_session_models.dart';
import 'package:sendreq/domain/websocket/websocket_transport.dart';

export 'package:sendreq/domain/websocket/websocket_session_models.dart';

/// 按请求维度管理所有 WebSocket 连接及其消息记录。
///
/// 负责连接生命周期（连接 / 断开 / 释放）、消息发送、事件记录、配额裁剪与
/// 敏感值脱敏，并通过 [onChanged] 通知 UI 刷新。
class WebSocketSessionRegistry {
  /// 构建注册表，[maxEventsPerSession] 与 [maxRetainedBytesPerSession]
  /// 分别限制每个会话保留的最大事件数与最大字节数。
  WebSocketSessionRegistry(
    this._transport, {
    this.maxEventsPerSession = 500,
    this.maxRetainedBytesPerSession = 1024 * 1024,
    this.connectTimeout = const Duration(seconds: 20),
    this.onChanged,
  });

  /// 会话与历史中单条系统错误的最大字符数，避免异常信息突破内存预算。
  static const maxErrorMessageCharacters = 4096;

  /// 底层传输实现，负责真正建立连接与收发数据。
  final WebSocketTransport _transport;

  /// 每个会话最多保留的消息事件数。
  final int maxEventsPerSession;

  /// 每个会话最多保留的字节数。
  final int maxRetainedBytesPerSession;

  /// 单次 WebSocket 握手允许的最长等待时间。
  final Duration connectTimeout;

  /// 状态变化时的通知回调。
  final void Function()? onChanged;

  /// 请求 ID 到会话条目的映射。
  final Map<String, _SessionEntry> _entries = {};

  /// 返回指定请求的会话快照；若从未连接过则返回默认的断开状态快照。
  WebSocketSession sessionFor(String requestId) =>
      _entries[requestId]?.session ??
      WebSocketSession(
        requestId: requestId,
        state: WebSocketConnectionState.disconnected,
        events: const [],
        omittedEventCount: 0,
        retainedByteCount: 0,
      );

  /// 当前受注册表管理的全部会话快照；用于在终止时写入安全摘要。
  Iterable<WebSocketSession> get sessions =>
      _entries.values.map((entry) => entry.session);

  /// 为指定请求发起 WebSocket 连接。
  ///
  /// 先校验协议前缀与当前状态，再异步等待握手完成；期间通过 [generation]
  /// 判断连接是否仍有效，避免过期连接的异步回调污染当前状态。
  Future<void> connect({
    required String requestId,
    required WebSocketConnectionConfiguration configuration,
  }) async {
    final entry = _entryFor(requestId);
    // 每次重连使用最新策略，保证后续记录按当前配置脱敏。
    entry.redactionPolicy = configuration.redactionPolicy;
    entry.redactedValues = configuration.redactedValues;
    // 端点仅以脱敏形式留在会话中，避免将 URL 查询参数里的 Secret 写入历史。
    final endpoint =
        configuration.redactedEndpoint ??
        _redact(configuration.url.toString(), entry);
    // 仅允许 ws:// 或 wss://，否则直接记录错误而不发起连接。
    if (configuration.url.scheme != 'ws' && configuration.url.scheme != 'wss') {
      entry.session = entry.session.copyWith(
        endpoint: endpoint,
        sessionContext: configuration.sessionContext,
        requiresReconnect: false,
        sessionStartedAt: DateTime.now(),
        clearSessionEndedAt: true,
        inboundMessageCount: 0,
        outboundMessageCount: 0,
      );
      _setError(requestId, 'WebSocket URL must use ws:// or wss://.');
      return;
    }
    // 连接中 / 已连接 / 关闭中均视为“正在忙”，直接忽略重复的连接请求。
    if (entry.session.state == WebSocketConnectionState.connecting ||
        entry.session.state == WebSocketConnectionState.connected ||
        entry.session.state == WebSocketConnectionState.closing) {
      return;
    }
    // 递增代数，使此前发起的任何异步连接尝试自动过期。
    entry.generation += 1;
    final generation = entry.generation;
    entry.session = entry.session.copyWith(
      state: WebSocketConnectionState.connecting,
      endpoint: endpoint,
      sessionContext: configuration.sessionContext,
      requiresReconnect: false,
      clearError: true,
      sessionStartedAt: DateTime.now(),
      clearSessionEndedAt: true,
      inboundMessageCount: 0,
      outboundMessageCount: 0,
    );
    _changed();
    try {
      final connectionFuture = _transport.connect(configuration);
      // 超时后底层连接仍可能晚到；监听它并在当前代次已失效时主动释放。
      _closeLateConnection(connectionFuture, entry, generation);
      final connection = await connectionFuture.timeout(connectTimeout);
      // 握手期间请求被断开或重新连接，则丢弃这条过期连接。
      if (!_isCurrent(entry, generation)) {
        await connection.close();
        return;
      }
      entry.connection = connection;
      // 订阅传输事件，将入站帧与系统事件统一落进会话记录。
      entry.subscription = connection.events.listen(
        (event) => _handleTransportEvent(entry, generation, event),
        onError: (Object error) =>
            _setError(requestId, _redact('$error', entry)),
      );
      entry.session = entry.session.copyWith(
        state: WebSocketConnectionState.connected,
        connectedAt: DateTime.now(),
        clearError: true,
      );
      _changed();
    } on TimeoutException {
      // 作废本次握手，使任何在超时后返回的连接不会再次激活会话。
      if (_isCurrent(entry, generation)) {
        entry.generation += 1;
        _setError(requestId, 'WebSocket connection timed out.');
      }
    } on Object catch (error) {
      // 只有最新一代次的连接失败才记录错误，忽略已过期的失败。
      if (_isCurrent(entry, generation)) {
        _setError(requestId, _redact('$error', entry));
      }
    }
  }

  /// 通过指定请求的连接发送一条文本消息，并记录为出站事件。
  Future<void> sendText(
    String requestId,
    String value, {
    String? formatLabel,
  }) async {
    final entry = _requireConnected(requestId);
    await entry.connection!.sendText(value);
    // 记录前对敏感值脱敏，避免密钥残留在会话记录中。
    _append(
      entry,
      WebSocketMessageEvent(
        direction: WebSocketFrameDirection.outbound,
        kind: WebSocketFrameKind.text,
        timestamp: DateTime.now(),
        byteLength: utf8.encode(value).length,
        preview: formatLabel == null
            ? _preview(_redact(value, entry))
            : '$formatLabel: ${_preview(_redact(value, entry))}',
        textPayload: _redact(value, entry),
      ),
    );
    entry.session = entry.session.copyWith(
      outboundMessageCount: entry.session.outboundMessageCount + 1,
    );
  }

  /// 通过指定请求的连接发送一条二进制消息，并记录为出站事件。
  Future<void> sendBinary(
    String requestId,
    Uint8List value, {
    String? protobufMessageType,
    String? formatLabel,
  }) async {
    final entry = _requireConnected(requestId);
    await entry.connection!.sendBinary(value);
    _append(
      entry,
      WebSocketMessageEvent(
        direction: WebSocketFrameDirection.outbound,
        kind: WebSocketFrameKind.binary,
        timestamp: DateTime.now(),
        byteLength: value.length,
        preview: protobufMessageType != null
            ? 'Protobuf $protobufMessageType (${value.length} bytes)'
            : formatLabel == null
            ? 'Binary frame (${value.length} bytes)'
            : '$formatLabel (${value.length} bytes)',
        // 复制负载，保证记录内容不被外部后续修改影响。
        binaryPayload: Uint8List.fromList(value),
        protobufMessageType: protobufMessageType,
      ),
    );
    entry.session = entry.session.copyWith(
      outboundMessageCount: entry.session.outboundMessageCount + 1,
    );
  }

  /// 主动断开指定请求的 WebSocket 连接。
  Future<void> disconnect(String requestId) async {
    final entry = _entries[requestId];
    if (entry == null ||
        entry.session.state == WebSocketConnectionState.disconnected) {
      return;
    }
    // 递增代数使在途事件全部过期，避免断线期间混入旧连接的回调。
    entry.generation += 1;
    entry.session = entry.session.copyWith(
      state: WebSocketConnectionState.closing,
    );
    _changed();
    await entry.subscription?.cancel();
    entry.subscription = null;
    final connection = entry.connection;
    entry.connection = null;
    try {
      await connection?.close();
    } on Object catch (error) {
      _setError(requestId, _redact('$error', entry));
      return;
    }
    entry.session = entry.session.copyWith(
      state: WebSocketConnectionState.disconnected,
      clearConnectedAt: true,
      sessionEndedAt: DateTime.now(),
    );
    _changed();
  }

  /// 标记仍在运行的指定会话（或全部会话）需要用户显式重连。
  void markConfigurationChanged([String? requestId]) {
    for (final item in _entries.entries) {
      if (requestId != null && item.key != requestId) continue;
      final state = item.value.session.state;
      if (state == WebSocketConnectionState.connecting ||
          state == WebSocketConnectionState.connected ||
          state == WebSocketConnectionState.closing) {
        item.value.session = item.value.session.copyWith(
          requiresReconnect: true,
        );
      }
    }
    _changed();
  }

  /// 释放指定请求的会话：先断开连接，再移除全部记录。
  Future<void> disposeRequest(String requestId) async {
    await disconnect(requestId);
    _entries.remove(requestId);
    _changed();
  }

  /// 释放全部会话，用于 ViewModel 销毁时清理所有连接。
  Future<void> dispose() async {
    // 先复制 key 列表，避免遍历过程中修改映射导致并发问题。
    for (final requestId in _entries.keys.toList(growable: false)) {
      await disposeRequest(requestId);
    }
  }

  /// 获取指定请求的会话条目，不存在时创建默认的断开状态条目。
  _SessionEntry _entryFor(String requestId) => _entries.putIfAbsent(
    requestId,
    () => _SessionEntry(
      WebSocketSession(
        requestId: requestId,
        state: WebSocketConnectionState.disconnected,
        events: const [],
        omittedEventCount: 0,
        retainedByteCount: 0,
      ),
    ),
  );

  /// 返回已连接且持有底层连接的条目，否则抛出异常。
  _SessionEntry _requireConnected(String requestId) {
    final entry = _entries[requestId];
    if (entry == null || !entry.session.canSend || entry.connection == null) {
      throw const WebSocketSessionException(
        'Connect before sending a message.',
      );
    }
    return entry;
  }

  /// 判断条目的代数是否仍是最新，用于忽略过期连接的异步回调。
  bool _isCurrent(_SessionEntry entry, int generation) =>
      entry.generation == generation;

  /// 关闭超时、取消或重连后才返回的底层连接，避免后台资源泄漏。
  void _closeLateConnection(
    Future<WebSocketConnection> connectionFuture,
    _SessionEntry entry,
    int generation,
  ) {
    unawaited(
      connectionFuture.then((connection) async {
        if (!_isCurrent(entry, generation)) {
          try {
            await connection.close();
          } on Object {
            // 迟到连接仅用于清理，关闭失败不能覆盖当前会话状态。
          }
        }
      }, onError: (error, stackTrace) {}),
    );
  }

  /// 处理底层传输事件：文本 / 二进制入站帧记入会话，关闭与错误事件更新状态。
  void _handleTransportEvent(
    _SessionEntry entry,
    int generation,
    WebSocketTransportEvent event,
  ) {
    // 忽略来自过期连接的迟到事件。
    if (!_isCurrent(entry, generation)) return;
    switch (event.kind) {
      case WebSocketFrameKind.text:
        // 入站文本同样需要脱敏，防止服务端回显密钥。
        final text = _redact(event.text ?? '', entry);
        _append(
          entry,
          WebSocketMessageEvent(
            direction: WebSocketFrameDirection.inbound,
            kind: WebSocketFrameKind.text,
            timestamp: DateTime.now(),
            byteLength: utf8.encode(event.text ?? '').length,
            preview: _preview(text),
            textPayload: text,
          ),
        );
        entry.session = entry.session.copyWith(
          inboundMessageCount: entry.session.inboundMessageCount + 1,
        );
      case WebSocketFrameKind.binary:
        final bytes = event.binary ?? Uint8List(0);
        _append(
          entry,
          WebSocketMessageEvent(
            direction: WebSocketFrameDirection.inbound,
            kind: WebSocketFrameKind.binary,
            timestamp: DateTime.now(),
            byteLength: bytes.length,
            preview: 'Binary frame (${bytes.length} bytes)',
            // 复制负载，保持记录与底层缓冲区相互独立。
            binaryPayload: Uint8List.fromList(bytes),
          ),
        );
        entry.session = entry.session.copyWith(
          inboundMessageCount: entry.session.inboundMessageCount + 1,
        );
      case WebSocketFrameKind.close:
        // 服务端关闭连接：清空底层连接引用并将状态复位为断开。
        entry.connection = null;
        entry.session = entry.session.copyWith(
          state: WebSocketConnectionState.disconnected,
          clearConnectedAt: true,
          sessionEndedAt: DateTime.now(),
        );
        _append(
          entry,
          WebSocketMessageEvent(
            direction: WebSocketFrameDirection.system,
            kind: WebSocketFrameKind.close,
            timestamp: DateTime.now(),
            byteLength: 0,
            preview: _boundedSystemMessage(
              _redact(event.message ?? 'Connection closed.', entry),
            ),
          ),
        );
      case WebSocketFrameKind.error:
        _setError(
          entry.session.requestId,
          _redact(event.message ?? 'Connection failed.', entry),
        );
    }
  }

  /// 将指定请求置为错误状态，并追加一条系统错误事件。
  void _setError(String requestId, String message) {
    final entry = _entryFor(requestId);
    final safeMessage = _boundedSystemMessage(
      _actionableAuthenticationFailure(_redact(message, entry)),
    );
    entry.connection = null;
    entry.session = entry.session.copyWith(
      state: WebSocketConnectionState.error,
      errorMessage: safeMessage,
      clearConnectedAt: true,
      sessionEndedAt: DateTime.now(),
    );
    _append(
      entry,
      WebSocketMessageEvent(
        direction: WebSocketFrameDirection.system,
        kind: WebSocketFrameKind.error,
        timestamp: DateTime.now(),
        byteLength: 0,
        preview: safeMessage,
        error: safeMessage,
      ),
    );
  }

  /// 追加一条消息事件，并在超出事件数或字节配额时从队首丢弃旧事件。
  void _append(_SessionEntry entry, WebSocketMessageEvent event) {
    final events = Queue<WebSocketMessageEvent>.from(entry.session.events)
      ..add(event);
    var bytes = entry.session.retainedByteCount + event.byteLength;
    var omitted = entry.session.omittedEventCount;
    // 允许用字节数配额提前淘汰旧事件，但至少保留最新一条。
    while (events.length > maxEventsPerSession ||
        (bytes > maxRetainedBytesPerSession && events.length > 1)) {
      final removed = events.removeFirst();
      bytes -= removed.byteLength;
      omitted += 1;
    }
    entry.session = entry.session.copyWith(
      events: List.unmodifiable(events),
      retainedByteCount: bytes,
      omittedEventCount: omitted,
    );
    _changed();
  }

  /// 将 [value] 中命中的敏感值替换为掩码字符。
  String _redact(String value, _SessionEntry entry) {
    final policy = entry.redactionPolicy;
    if (policy != null) {
      return policy.redact(value).replaceAll('[redacted]', '••••••••');
    }
    var result = value;
    for (final secret in entry.redactedValues) {
      if (secret.isNotEmpty) result = result.replaceAll(secret, '••••••••');
    }
    return result;
  }

  String _actionableAuthenticationFailure(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('401') ||
        normalized.contains('unauthorized') ||
        normalized.contains('authorization')) {
      return 'Authentication failed. Update the active environment token and reconnect.';
    }
    return value;
  }

  /// 生成列表预览，超过 512 字符时截断并追加省略号。
  String _preview(String value) =>
      value.length <= 512 ? value : '${value.substring(0, 512)}…';

  /// 限制系统消息，避免服务端提供的错误或关闭原因无限增长。
  String _boundedSystemMessage(String value) =>
      value.length <= maxErrorMessageCharacters
      ? value
      : '${value.substring(0, maxErrorMessageCharacters)}...[truncated]';

  /// 通知外部会话状态已变化。
  void _changed() => onChanged?.call();
}

/// 注册表内部使用的可变会话条目，持有连接、订阅与代数计数。
class _SessionEntry {
  /// 构建一个空的会话条目。
  _SessionEntry(this.session);

  /// 当前会话快照。
  WebSocketSession session;

  /// 底层连接，未连接时为空。
  WebSocketConnection? connection;

  /// 事件流订阅，断开时需要取消。
  StreamSubscription<WebSocketTransportEvent>? subscription;

  /// 连接代数，每次发起新连接时递增，用于作废旧连接的异步回调。
  int generation = 0;

  /// 由 Environment 持有的策略，用于所有后续会话投影。
  RedactionPolicy? redactionPolicy;

  /// 为现有调用方与测试提供的遗留兼容输入。
  List<String> redactedValues = const [];
}
