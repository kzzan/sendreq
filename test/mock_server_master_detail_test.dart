import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/domain/contract_publishing/mock_server.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/features/mock/widgets/mock_servers_panel.dart';

void main() {
  testWidgets(
    'empty state has one primary creation action and conditional alternate',
    (tester) async {
      await _pump(
        tester,
        MockServersPanelState(
          canCreateFromResponse: false,
          createManual: () {},
          createFromResponse: () {},
        ),
      );

      expect(
        find.byKey(const Key('mock-create-manual-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mock-create-from-response-action')),
        findsNothing,
      );
      expect(find.byKey(const Key('mock-create-menu')), findsNothing);

      await _pump(
        tester,
        MockServersPanelState(
          canCreateFromResponse: true,
          createManual: () {},
          createFromResponse: () {},
        ),
      );
      expect(
        find.byKey(const Key('mock-create-from-response-action')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'saved server keeps creation in list and switches Save/Start/Stop',
    (tester) async {
      var startCount = 0;
      var stopCount = 0;
      final server = _server();
      await _pump(
        tester,
        MockServersPanelState(
          savedMockServers: [
            MockServerProjection(
              server: server,
              runtime: const MockServerRuntimeProjection(
                status: MockServerRuntimeStatus.stopped,
              ),
            ),
          ],
          canCreateFromResponse: false,
          createManual: () {},
          createFromResponse: () {},
          startSaved: (_) async => startCount++,
          stopSaved: (_) async => stopCount++,
          saveSaved: (_) async {},
        ),
      );

      expect(find.byKey(const Key('mock-create-menu')), findsOneWidget);
      expect(find.byKey(const Key('saved-mock-save-button')), findsNothing);
      expect(find.text('Start server'), findsOneWidget);
      await tester.tap(find.byKey(const Key('saved-mock-lifecycle-button')));
      await tester.pump();
      expect(startCount, 1);

      await tester.enterText(
        find.byKey(const Key('saved-mock-name-input')),
        'Edited server',
      );
      await tester.pump();
      expect(find.byKey(const Key('saved-mock-save-button')), findsOneWidget);
      expect(
        find.byKey(const Key('saved-mock-lifecycle-button')),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(
        tester,
        MockServersPanelState(
          savedMockServers: [
            MockServerProjection(
              server: server,
              runtime: const MockServerRuntimeProjection(
                status: MockServerRuntimeStatus.running,
                loopbackUrl: 'http://127.0.0.1:9090',
              ),
            ),
          ],
          canCreateFromResponse: false,
          createManual: () {},
          createFromResponse: () {},
          startSaved: (_) async => startCount++,
          stopSaved: (_) async => stopCount++,
          saveSaved: (_) async {},
        ),
      );
      expect(find.text('Stop server'), findsOneWidget);
      await tester.tap(find.byKey(const Key('saved-mock-lifecycle-button')));
      await tester.pump();
      expect(stopCount, 1);
    },
  );
}

Future<void> _pump(WidgetTester tester, MockServersPanelState state) =>
    tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MockServersPanel(state: state)),
      ),
    );

MockServer _server() => MockServer(
  id: 'server',
  name: 'Server',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  endpoints: [
    MockEndpoint(
      id: 'endpoint',
      matcher: MockRequestMatcher(method: 'GET', path: '/'),
      variants: [MockResponseVariant(id: 'default', statusCode: 200)],
    ),
  ],
);
