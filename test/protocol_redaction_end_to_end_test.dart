import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/websocket/websocket_transport.dart';
import 'package:sendreq/ui/features/requests/websocket/widgets/websocket_session_panel.dart';
import 'package:sendreq/ui/shell/application/user_notice.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';

import 'support/module_boundary_fakes.dart';
import 'support/workspace_view_model_test_factory.dart';

void main() {
  testWidgets(
    'server authentication failures stay redacted in copy, notices, and session summaries',
    (tester) async {
      const secret = 'server-issued-secret';
      String? copiedError;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedError =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final transport = _ServerErrorTransport();
      final viewModel = workspaceViewModel(
        environmentResolver: FakeEnvironmentResolver(
          ResolvedExecutionCommand(
            executionId: 'redaction-websocket',
            requestRef: const RequestRef(id: 'demo-rest-list-users'),
            payload: ExecutionPayload(
              method: 'WebSocket',
              resolvedUrl: 'ws://127.0.0.1:8080/ws?token=server-issued-secret',
              draft: RequestDraft(
                method: 'WebSocket',
                baseUrlToken: 'ws://127.0.0.1:8080',
                path: '/ws',
                params: [],
                headers: [],
                body: '',
              ),
            ),
            sanitizedRequestSummary: 'WS 127.0.0.1/ws?token=[redacted]',
            redactionPolicy: RedactionPolicy(const [secret]),
          ),
        ),
        webSocketTransport: transport,
      );
      addTearDown(viewModel.dispose);
      viewModel.updateActiveDraftProtocol(ApiRequestProtocol.webSocket);

      await viewModel.connectActiveWebSocket();
      await tester.pumpWidget(_panelHost(viewModel));
      viewModel.selectSection(WorkspaceSection.settings);
      transport.connection.emit(
        const WebSocketTransportEvent.error(
          'UNAUTHENTICATED: Bearer server-issued-secret',
        ),
      );
      await tester.pump();
      await tester.pump();

      final session = viewModel.activeWebSocketSession;
      expect(session.errorMessage, contains('UNAUTHENTICATED'));
      expect(session.errorMessage, isNot(contains(secret)));
      expect(session.endpoint, contains('••••••••'));
      expect(session.endpoint, isNot(contains(secret)));

      final notice = viewModel.notices.singleWhere(
        (item) => item.code == NoticeCode.sessionFailed,
      );
      expect(notice.arguments.values.join(' '), isNot(contains(secret)));

      await tester.tap(find.byKey(const Key('websocket-copy-error')));
      await tester.pump();
      expect(copiedError, contains('UNAUTHENTICATED'));
      expect(copiedError, isNot(contains(secret)));
    },
  );
}

Widget _panelHost(WorkspaceViewModel viewModel) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: AnimatedBuilder(
    animation: viewModel,
    builder: (_, _) =>
        Scaffold(body: WebSocketSessionPanel(viewModel: viewModel)),
  ),
);

class _ServerErrorTransport implements WebSocketTransport {
  final connection = _ServerErrorConnection();

  @override
  Future<WebSocketConnection> connect(
    WebSocketConnectionConfiguration configuration,
  ) async => connection;
}

class _ServerErrorConnection implements WebSocketConnection {
  final _events = StreamController<WebSocketTransportEvent>.broadcast();

  @override
  Stream<WebSocketTransportEvent> get events => _events.stream;

  void emit(WebSocketTransportEvent event) => _events.add(event);

  @override
  Future<void> close() => _events.close();

  @override
  Future<void> sendBinary(Uint8List value) async {}

  @override
  Future<void> sendText(String value) async {}
}
