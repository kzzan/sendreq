import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/websocket/websocket_transport.dart';
import 'package:sendreq/features/workspace/view_models/workspace_view_model.dart';
import 'package:sendreq/features/workspace/views/workspace_view.dart';
import 'package:sendreq/features/websocket/widgets/websocket_session_panel.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';

import 'support/workspace_view_model_test_factory.dart';

void main() {
  // 查看历史帧时新消息仍应保留在会话中，并以未读计数提示用户手动返回底部。
  testWidgets(
    'WebSocket timeline preserves reading position and shows unread',
    (tester) async {
      final transport = _TestTransport();
      final viewModel = _connectedWebSocketViewModel(transport);
      await viewModel.connectActiveWebSocket();
      addTearDown(viewModel.dispose);

      await tester.pumpWidget(_panelHost(viewModel));
      for (var index = 0; index < 18; index++) {
        transport.connection.emit(
          WebSocketTransportEvent.text('message $index'),
        );
      }
      await tester.pumpAndSettle();

      final timeline = find.byType(ListView);
      await tester.drag(timeline, const Offset(0, 360));
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: timeline, matching: find.byType(Scrollable)),
      );
      expect(
        scrollable.position.pixels,
        lessThan(scrollable.position.maxScrollExtent - 24),
      );
      transport.connection.emit(const WebSocketTransportEvent.text('latest'));
      await tester.pumpAndSettle();

      expect(find.text('1 new'), findsOneWidget);
      expect(viewModel.activeWebSocketSession.events.last.preview, 'latest');
    },
  );

  // 全局 Ctrl+Enter 在输入框拥有焦点时也应发送当前 WebSocket 草稿。
  testWidgets('Ctrl+Enter sends the active WebSocket message draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = _TestTransport();

    await tester.pumpWidget(
      _workspaceHost(
        WorkspaceView(
          webSocketTransport: transport,
          workspaceDependencies: workspaceTestDependencies(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('request-kind-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('request-kind-option-websocket')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('request-url-input')),
      'ws://localhost/events',
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('request-action-slot')),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, 'ping');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(transport.connection.sentText, ['ping']);
  });
}

/// 在完整工作区以外托管会话面板，聚焦时间线独立交互。
Widget _panelHost(WorkspaceViewModel viewModel) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: AnimatedBuilder(
    animation: viewModel,
    builder: (_, _) =>
        Scaffold(body: WebSocketSessionPanel(viewModel: viewModel)),
  ),
);

/// 为全局快捷键路径提供完整的工作区与本地化上下文。
Widget _workspaceHost(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

/// 构造一个切换到 WebSocket 协议且地址合法的请求草稿。
WorkspaceViewModel _connectedWebSocketViewModel(_TestTransport transport) {
  final viewModel = workspaceViewModel(
    assetRepository: InMemoryApiAssetRepository.demo(),
    webSocketTransport: transport,
  );
  viewModel.updateActiveDraftProtocol(ApiRequestProtocol.webSocket);
  viewModel.updateActiveDraftUrl('ws://localhost/events');
  return viewModel;
}

/// 可驱动连接、收发和关闭状态的 Widget 测试传输替身。
class _TestTransport implements WebSocketTransport {
  final connection = _TestConnection();

  @override
  Future<WebSocketConnection> connect(
    WebSocketConnectionConfiguration configuration,
  ) async => connection;
}

/// 保存发送记录并提供受控入站事件流，避免测试依赖网络时序。
class _TestConnection implements WebSocketConnection {
  final _events = StreamController<WebSocketTransportEvent>.broadcast();
  final sentText = <String>[];

  @override
  Stream<WebSocketTransportEvent> get events => _events.stream;

  void emit(WebSocketTransportEvent event) => _events.add(event);

  @override
  Future<void> close() => _events.close();

  @override
  Future<void> sendBinary(Uint8List value) async {}

  @override
  Future<void> sendText(String value) async {
    sentText.add(value);
  }
}
