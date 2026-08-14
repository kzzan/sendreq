import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/websocket/websocket_session_registry.dart';
import 'package:sendreq/domain/websocket/websocket_transport.dart';
import 'package:sendreq/domain/request_runtime/long_lived_session_context.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';

void main() {
  // 端到端验证会话注册中心：连接建立（含子协议、请求头与脱敏规则配置）、
  // 帧记录、密钥值脱敏、文本发送，以及断开时关闭底层连接。
  test('connects, records frames, redacts secrets, and disconnects', () async {
    final connection = _FakeConnection();
    final transport = _FakeTransport(connection);
    final registry = WebSocketSessionRegistry(transport);

    await registry.connect(
      requestId: 'stream',
      configuration: WebSocketConnectionConfiguration(
        url: Uri.parse('wss://socket.sendreq.io/events'),
        headers: const {'Authorization': 'Bearer token-value'},
        subprotocols: const ['events.v1'],
        redactionPolicy: RedactionPolicy(const ['token-value']),
      ),
    );
    // 注入一条含密钥明文的入站帧，验证会话记录时被脱敏。
    connection.emit(const WebSocketTransportEvent.text('token-value received'));
    await Future<void>.delayed(Duration.zero);
    await registry.sendText('stream', 'token-value sent');

    final session = registry.sessionFor('stream');
    expect(session.state, WebSocketConnectionState.connected);
    // 连接配置（scheme 与子协议）应原样透传给底层传输层。
    expect(transport.configurations.single.url.scheme, 'wss');
    expect(transport.configurations.single.headers, {
      'Authorization': 'Bearer token-value',
    });
    expect(transport.configurations.single.subprotocols, ['events.v1']);
    expect(session.events, hasLength(2));
    // 入站预览中密钥已被掩码替换，明文不应出现。
    expect(session.events.first.preview, '•••••••• received');
    expect(connection.sentText, ['token-value sent']);

    await registry.disconnect('stream');
    expect(
      registry.sessionFor('stream').state,
      WebSocketConnectionState.disconnected,
    );
    expect(connection.closed, isTrue);
  });

  // 验证消息缓冲区上限：超出上限的早期帧被丢弃，但通过计数器保留“被省略条数”。
  test('keeps a bounded message buffer and counts omitted events', () async {
    final connection = _FakeConnection();
    // 将单会话上限压到 2 条，便于验证缓冲区裁剪行为。
    final registry = WebSocketSessionRegistry(
      _FakeTransport(connection),
      maxEventsPerSession: 2,
    );
    await registry.connect(
      requestId: 'stream',
      configuration: WebSocketConnectionConfiguration(
        url: Uri.parse('ws://localhost/events'),
      ),
    );

    connection.emit(const WebSocketTransportEvent.text('one'));
    connection.emit(const WebSocketTransportEvent.text('two'));
    connection.emit(const WebSocketTransportEvent.text('three'));
    await Future<void>.delayed(Duration.zero);

    final session = registry.sessionFor('stream');
    // 仅保留最新的两条，最旧的 'one' 被裁掉并计入 omittedEventCount。
    expect(session.events.map((event) => event.preview), ['two', 'three']);
    expect(session.omittedEventCount, 1);
  });

  // 验证非 WebSocket 协议的端点（https）应在发起连接前被拒绝，底层传输层不被调用。
  test('rejects a non-WebSocket endpoint without invoking transport', () async {
    final transport = _FakeTransport(_FakeConnection());
    final registry = WebSocketSessionRegistry(transport);

    await registry.connect(
      requestId: 'stream',
      configuration: WebSocketConnectionConfiguration(
        url: Uri.parse('https://api.sendreq.io/events'),
      ),
    );

    expect(transport.configurations, isEmpty);
    expect(registry.sessionFor('stream').state, WebSocketConnectionState.error);
  });

  // 二进制帧应按出站方向记录；未连接时禁止发送，避免把草稿误当作已发送。
  test('records binary sends and rejects sends without a connection', () async {
    final connection = _FakeConnection();
    final registry = WebSocketSessionRegistry(_FakeTransport(connection));

    await expectLater(
      registry.sendText('stream', 'draft'),
      throwsA(isA<WebSocketSessionException>()),
    );

    await registry.connect(
      requestId: 'stream',
      configuration: WebSocketConnectionConfiguration(
        url: Uri.parse('ws://localhost/events'),
      ),
    );
    await registry.sendBinary('stream', Uint8List.fromList([1, 2, 3]));

    final event = registry.sessionFor('stream').events.single;
    expect(connection.sentBinary.single, Uint8List.fromList([1, 2, 3]));
    expect(event.direction, WebSocketFrameDirection.outbound);
    expect(event.kind, WebSocketFrameKind.binary);
    expect(event.byteLength, 3);
  });

  // Protobuf 模式发送二进制帧时，应保留消息类型元数据，供时间线展示和后续解码使用。
  test('records Protobuf binary message metadata', () async {
    final connection = _FakeConnection();
    final registry = WebSocketSessionRegistry(_FakeTransport(connection));
    await registry.connect(
      requestId: 'stream',
      configuration: WebSocketConnectionConfiguration(
        url: Uri.parse('ws://localhost/events'),
      ),
    );

    await registry.sendBinary(
      'stream',
      Uint8List.fromList([1, 2, 3]),
      protobufMessageType: '.sendreq.Event',
    );

    final event = registry.sessionFor('stream').events.single;
    expect(event.protobufMessageType, '.sendreq.Event');
    expect(event.preview, 'Protobuf .sendreq.Event (3 bytes)');
  });

  // 传输层关闭或错误必须转为可见状态，同时确保错误文本不暴露请求头中的密钥。
  test('transitions on close and redacts transport errors', () async {
    final connection = _FakeConnection();
    final registry = WebSocketSessionRegistry(_FakeTransport(connection));
    await registry.connect(
      requestId: 'stream',
      configuration: WebSocketConnectionConfiguration(
        url: Uri.parse('ws://localhost/events'),
        headers: const {'Authorization': 'Bearer token-value'},
        redactedValues: const ['token-value'],
      ),
    );

    connection.emit(
      const WebSocketTransportEvent.closed(
        'Closed (1000): service requested close token-value',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final closedSession = registry.sessionFor('stream');
    expect(closedSession.state, WebSocketConnectionState.disconnected);
    expect(closedSession.events.last.kind, WebSocketFrameKind.close);
    expect(closedSession.events.last.preview, contains('Closed (1000)'));
    expect(closedSession.events.last.preview, isNot(contains('token-value')));

    await registry.connect(
      requestId: 'stream',
      configuration: WebSocketConnectionConfiguration(
        url: Uri.parse('ws://localhost/events'),
        redactedValues: const ['token-value'],
      ),
    );
    connection.emit(
      const WebSocketTransportEvent.error('Handshake failed: token-value'),
    );
    await Future<void>.delayed(Duration.zero);

    final session = registry.sessionFor('stream');
    expect(session.state, WebSocketConnectionState.error);
    expect(session.errorMessage, 'Handshake failed: ••••••••');
    expect(session.events.last.error, 'Handshake failed: ••••••••');
  });

  test(
    'keeps a redacted endpoint and frame counts for a finished session',
    () async {
      final connection = _FakeConnection();
      final registry = WebSocketSessionRegistry(_FakeTransport(connection));
      await registry.connect(
        requestId: 'stream',
        configuration: WebSocketConnectionConfiguration(
          url: Uri.parse('ws://localhost/events?token=token-value'),
          redactedValues: const ['token-value'],
        ),
      );
      connection.emit(const WebSocketTransportEvent.text('one'));
      await Future<void>.delayed(Duration.zero);
      await registry.sendText('stream', 'two');
      await registry.disconnect('stream');

      final session = registry.sessionFor('stream');
      expect(session.endpoint, 'ws://localhost/events?token=••••••••');
      expect(session.inboundMessageCount, 1);
      expect(session.outboundMessageCount, 1);
      expect(session.sessionStartedAt, isNotNull);
      expect(session.sessionEndedAt, isNotNull);
      expect(
        session.sessionEndedAt!.isBefore(session.sessionStartedAt!),
        isFalse,
      );
    },
  );

  // 断开连接会作废未完成的握手；晚到的连接必须立即关闭，不能复活会话。
  test('cancels an in-flight connection when disconnected', () async {
    final pendingConnection = Completer<WebSocketConnection>();
    final connection = _FakeConnection();
    final registry = WebSocketSessionRegistry(
      _PendingTransport(pendingConnection.future),
    );

    final connecting = registry.connect(
      requestId: 'stream',
      configuration: WebSocketConnectionConfiguration(
        url: Uri.parse('ws://localhost/events'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      registry.sessionFor('stream').state,
      WebSocketConnectionState.connecting,
    );

    await registry.disconnect('stream');
    pendingConnection.complete(connection);
    await connecting;

    expect(connection.closed, isTrue);
    expect(
      registry.sessionFor('stream').state,
      WebSocketConnectionState.disconnected,
    );
  });

  test('bounds and redacts oversized transport errors', () async {
    final connection = _FakeConnection();
    final registry = WebSocketSessionRegistry(_FakeTransport(connection));
    await registry.connect(
      requestId: 'stream',
      configuration: WebSocketConnectionConfiguration(
        url: Uri.parse('ws://localhost/events'),
        redactedValues: const ['token-value'],
      ),
    );
    final oversized = '${List.filled(5000, 'x').join()} token-value';
    connection.emit(WebSocketTransportEvent.error(oversized));
    await Future<void>.delayed(Duration.zero);

    final error = registry.sessionFor('stream').errorMessage!;
    expect(error, isNot(contains('token-value')));
    expect(error, endsWith('...[truncated]'));
    expect(
      error.length,
      lessThanOrEqualTo(
        WebSocketSessionRegistry.maxErrorMessageCharacters +
            '...[truncated]'.length,
      ),
    );
  });

  // 握手超过限定时间会显示错误；随后到达的底层连接必须立刻关闭。
  test(
    'times out a stalled handshake and closes its late connection',
    () async {
      final pendingConnection = Completer<WebSocketConnection>();
      final connection = _FakeConnection();
      final registry = WebSocketSessionRegistry(
        _PendingTransport(pendingConnection.future),
        connectTimeout: Duration.zero,
      );

      await registry.connect(
        requestId: 'stream',
        configuration: WebSocketConnectionConfiguration(
          url: Uri.parse('ws://localhost/events'),
        ),
      );
      expect(
        registry.sessionFor('stream').state,
        WebSocketConnectionState.error,
      );
      expect(
        registry.sessionFor('stream').errorMessage,
        'WebSocket connection timed out.',
      );

      pendingConnection.complete(connection);
      await Future<void>.delayed(Duration.zero);
      expect(connection.closed, isTrue);
    },
  );

  test(
    'keeps a sanitized session context and marks configuration changes',
    () async {
      final registry = WebSocketSessionRegistry(
        _FakeTransport(_FakeConnection()),
      );
      await registry.connect(
        requestId: 'stream',
        configuration: WebSocketConnectionConfiguration(
          url: Uri.parse('ws://localhost/events'),
          sessionContext: const LongLivedSessionContext(
            environmentName: 'Local Protocol',
            authenticationLabel: 'Environment Bearer token',
            authenticationType: RequestAuthenticationType.bearer,
            authenticationSource: RequestAuthenticationSource.environment,
          ),
        ),
      );

      registry.markConfigurationChanged('stream');

      final session = registry.sessionFor('stream');
      expect(session.sessionContext.environmentName, 'Local Protocol');
      expect(
        session.sessionContext.authenticationLabel,
        'Environment Bearer token',
      );
      expect(session.requiresReconnect, isTrue);
    },
  );
}

/// 伪传输层：记录每次连接请求的配置，并回放给定的伪连接，避免发起真实网络连接。
class _FakeTransport implements WebSocketTransport {
  _FakeTransport(this.connection);

  final _FakeConnection connection;
  final List<WebSocketConnectionConfiguration> configurations = [];

  @override
  Future<WebSocketConnection> connect(
    WebSocketConnectionConfiguration configuration,
  ) async {
    configurations.add(configuration);
    return connection;
  }
}

/// 让测试控制握手何时完成，用来验证取消期间的迟到连接处理。
class _PendingTransport implements WebSocketTransport {
  const _PendingTransport(this.connection);

  final Future<WebSocketConnection> connection;

  @override
  Future<WebSocketConnection> connect(
    WebSocketConnectionConfiguration configuration,
  ) => connection;
}

/// 伪连接：广播模拟的入站事件，并记录发出的文本/二进制消息与关闭状态。
class _FakeConnection implements WebSocketConnection {
  final StreamController<WebSocketTransportEvent> _events =
      StreamController<WebSocketTransportEvent>.broadcast();
  final List<String> sentText = [];
  final List<Uint8List> sentBinary = [];
  bool closed = false;

  @override
  Stream<WebSocketTransportEvent> get events => _events.stream;

  // 测试辅助方法：向事件流推送一条模拟的入站帧。
  void emit(WebSocketTransportEvent event) => _events.add(event);

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<void> sendBinary(Uint8List value) async {
    sentBinary.add(Uint8List.fromList(value));
  }

  @override
  Future<void> sendText(String value) async {
    sentText.add(value);
  }
}
