import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/data/repositories/in_memory_environment_store.dart';
import 'package:sendreq/data/repositories/in_memory_mock_server_repository.dart';
import 'package:sendreq/data/services/local_mock_server_runtime.dart';
import 'package:sendreq/data/services/http_request_execution_runtime.dart';
import 'package:sendreq/data/services/openapi_request_importer.dart';
import 'package:sendreq/data/services/openapi_request_exporter.dart';
import 'package:sendreq/data/services/openapi_file_exporter.dart';
import 'package:sendreq/data/services/local_workspace_file_ports.dart';
import 'package:sendreq/data/services/openapi_output_directory.dart';
import 'package:sendreq/data/services/openapi_markdown_documentation_renderer.dart';
import 'package:sendreq/data/services/markdown_documentation_file_exporter.dart';
import 'package:sendreq/data/services/proto_source_parser.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/environments/environment_execution_resolver.dart';
import 'package:sendreq/domain/request_runtime/http_execution_service.dart';
import 'package:sendreq/domain/contract_publishing/session_contract_publishing_service.dart';
import 'package:sendreq/domain/grpc/grpc_transport.dart';
import 'package:sendreq/domain/request_runtime/grpc_execution_service.dart';
import 'package:sendreq/domain/request_runtime/websocket_execution_service.dart';
import 'package:sendreq/domain/websocket/websocket_transport.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/ui/shell/views/workspace_view.dart';
import 'package:sendreq/ui/features/requests/websocket/widgets/websocket_session_panel.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';

import 'support/workspace_view_model_test_factory.dart';
import 'support/app_update_fakes.dart';

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

  // 连接后，Enter 应通过统一快捷键发送当前 WebSocket 草稿。
  testWidgets('Enter sends the active WebSocket message draft', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = _TestTransport();
    await tester.pumpWidget(
      _workspaceHost(
        WorkspaceView(
          environmentResolver: EnvironmentExecutionResolver(
            InMemoryEnvironmentStore.sample(),
          ),
          executionService: HttpExecutionService(
            runtime: HttpRequestExecutionRuntime(),
          ),
          openApiImporter: const OpenApiRequestImporter(),
          openApiExporter: const OpenApiRequestExporter(),
          openApiFileExporter: const OpenApiFileExporter(),
          openApiFileReader: const LocalOpenApiFileReader(),
          openApiOutputDirectory: const LocalOpenApiOutputDirectory(),
          openApiMarkdownRenderer: const OpenApiMarkdownDocumentationRenderer(),
          markdownDocumentationFile: const MarkdownDocumentationFileExporter(),
          protobufSource: const LocalProtobufSourcePort(),
          responseBodyDownload: const LocalResponseBodyDownload(),
          webSocketExecutionService: WebSocketExecutionService(transport),
          grpcExecutionService: GrpcExecutionService(
            const _UnusedGrpcTransport(),
          ),
          contractPublishingService: SessionContractPublishingService(
            mockServerRepository: InMemoryMockServerRepository(),
            mockServerRuntime: LocalMockServerRuntime(),
          ),
          appReleaseRepository: FakeAppReleaseRepository(),
          installedAppVersionProvider: const FakeInstalledAppVersionProvider(),
          externalReleaseLauncher: FakeExternalReleaseLauncher(),
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
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(transport.connection.sentText, ['ping']);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).last)
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('WebSocket JSON timeline is formatted and collapsible', (
    tester,
  ) async {
    final transport = _TestTransport();
    final viewModel = _connectedWebSocketViewModel(transport);
    await viewModel.connectActiveWebSocket();
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(_panelHost(viewModel));
    transport.connection.emit(
      const WebSocketTransportEvent.text('{"n":1,"as":111}'),
    );
    await tester.pumpAndSettle();

    final jsonTree = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'websocket-event-json-',
          ) &&
          (widget.key! as ValueKey<String>).value.endsWith('-tree'),
    );
    expect(jsonTree, findsOneWidget);
    expect(find.text('"n": 1,'), findsOneWidget);
    expect(find.text('"as": 111'), findsOneWidget);

    final rootToggle = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'websocket-event-json-',
          ) &&
          (widget.key! as ValueKey<String>).value.endsWith('-toggle-root'),
    );
    await tester.tap(rootToggle);
    await tester.pumpAndSettle();
    expect(find.text('{...}'), findsOneWidget);
    await tester.tap(rootToggle);
    await tester.pumpAndSettle();
    expect(find.text('"n": 1,'), findsOneWidget);

    final payload = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'websocket-event-payload-',
          ),
    );
    expect(payload, findsOneWidget);
    await tester.tap(payload);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
  });

  testWidgets('WebSocket message opens in a selectable detail dialog', (
    tester,
  ) async {
    final transport = _TestTransport();
    final viewModel = _connectedWebSocketViewModel(transport);
    await viewModel.connectActiveWebSocket();
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(_panelHost(viewModel));
    transport.connection.emit(
      const WebSocketTransportEvent.text('a long message to inspect'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.open_in_full));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.widgetWithText(SelectableText, 'a long message to inspect'),
      findsOneWidget,
    );
  });

  testWidgets('WebSocket event remains usable in a narrow panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = _TestTransport();
    final viewModel = _connectedWebSocketViewModel(transport);
    await viewModel.connectActiveWebSocket();
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(_panelHost(viewModel));
    transport.connection.emit(
      const WebSocketTransportEvent.text(
        '{"event":"status","message":"a deliberately long message"}',
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.open_in_full), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
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

/// 为工作区组件测试提供完整的工作区与本地化上下文。
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

class _UnusedGrpcTransport implements GrpcTransport {
  const _UnusedGrpcTransport();

  @override
  Future<GrpcCall> start(GrpcCallConfiguration configuration) =>
      throw UnsupportedError('This test does not start gRPC calls.');
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
