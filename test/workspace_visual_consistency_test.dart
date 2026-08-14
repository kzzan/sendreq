import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/domain/contract_publishing/mock_server.dart';
import 'package:sendreq/ui/features/requests/environment/manager/widgets/environment_panel.dart';
import 'package:sendreq/ui/features/mock/widgets/mock_servers_panel.dart';
import 'package:sendreq/ui/features/settings/widgets/settings_panel.dart';
import 'package:sendreq/ui/features/settings/view_models/settings_view_model.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';

import 'support/workspace_view_model_test_factory.dart';
import 'support/app_update_fakes.dart';

void main() {
  testWidgets('Settings remains usable across target viewports and themes', (
    tester,
  ) async {
    await _verifyAcrossViewports(
      tester,
      title: 'Settings',
      panel: (viewModel) => SettingsPanel(
        viewModel: SettingsViewModel(
          appearance: viewModel.appearance,
          locale: viewModel.locale,
          font: viewModel.font,
          codeFont: viewModel.codeFont,
          codeFontSize: viewModel.codeFontSize,
          persistenceState: viewModel.preferencePersistenceState,
          updateAppearance: viewModel.updateAppearance,
          updateLocale: viewModel.updateLocale,
          updateFont: viewModel.updateFont,
          updateCodeFont: viewModel.updateCodeFont,
          updateCodeFontSize: viewModel.updateCodeFontSize,
          resetPreferences: viewModel.resetPreferences,
          retryPreferenceSave: viewModel.retryPreferenceSave,
          appUpdateController: fakeAppUpdateController(),
        ),
      ),
    );
  });

  testWidgets('Environment remains usable across target viewports and themes', (
    tester,
  ) async {
    await _verifyAcrossViewports(
      tester,
      title: 'Environments',
      panel: (viewModel) => EnvironmentPanel(viewModel: viewModel),
    );
  });

  testWidgets('Mock remains usable across target viewports and themes', (
    tester,
  ) async {
    for (final width in _targetWidths) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        _setViewport(tester, width);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness, useMaterial3: true),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MockServersPanel(
                key: ValueKey('mock-$width-$brightness'),
                state: MockServersPanelState(
                  savedMockServers: [_savedMockServer()],
                  canCreateFromResponse: false,
                  createManual: () {},
                  createFromResponse: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Saved mock servers'), findsOneWidget);
        expect(find.text('Orders service'), findsWidgets);
        expect(find.byKey(const Key('mock-create-menu')), findsOneWidget);
        expect(
          find.byKey(const Key('mock-create-manual-action')),
          findsNothing,
        );
        await tester.tap(find.byKey(const Key('mock-create-menu')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('mock-create-manual-action')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('mock-create-from-response-action')),
          findsOneWidget,
        );
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
        if (width < 760) {
          await tester.tap(find.text('Orders service').last);
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        expect(
          tester.getRect(find.text('Saved mock servers')).right,
          lessThanOrEqualTo(width),
        );
        expect(
          find.byKey(const Key('saved-mock-secondary-actions')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('saved-mock-lifecycle-button')),
          findsOneWidget,
        );
        final endpointChoice = find.byKey(
          const Key('saved-mock-endpoint-orders-endpoint'),
        );
        expect(tester.getSize(endpointChoice).height, 30);
        expect(
          tester
              .getSize(
                find.byKey(
                  const ValueKey('compact-selection-indicator-orders-endpoint'),
                ),
              )
              .longestSide,
          lessThanOrEqualTo(18),
        );
        await tester.tap(find.byKey(const Key('saved-mock-secondary-actions')));
        await tester.pumpAndSettle();
        expect(find.text('Archive server'), findsOneWidget);
        expect(find.text('Delete server'), findsOneWidget);
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
      }
    }
  });
}

MockServerProjection _savedMockServer() {
  final server = MockServer(
    id: 'orders-server',
    name: 'Orders service',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    endpoints: [
      MockEndpoint(
        id: 'orders-endpoint',
        matcher: MockRequestMatcher(method: 'GET', path: '/orders'),
        variants: [
          MockResponseVariant(id: 'orders-default', statusCode: 200),
          MockResponseVariant(
            id: 'orders-preview',
            statusCode: 202,
            matcher: MockVariantMatcher(headers: {'x-preview': 'true'}),
          ),
        ],
      ),
    ],
  );
  return MockServerProjection(
    server: server,
    runtime: const MockServerRuntimeProjection(
      status: MockServerRuntimeStatus.stopped,
    ),
  );
}

const _targetWidths = [375.0, 768.0, 1024.0, 1440.0];

Future<void> _verifyAcrossViewports(
  WidgetTester tester, {
  required String title,
  required Widget Function(WorkspaceViewModel viewModel) panel,
}) async {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  for (final width in _targetWidths) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      _setViewport(tester, width);
      final viewModel = workspaceViewModel();
      addTearDown(viewModel.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness, useMaterial3: true),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AnimatedBuilder(
              animation: viewModel,
              builder: (context, _) => panel(viewModel),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(title), findsWidgets);
      if (title == 'Settings') {
        expect(
          find.byKey(const Key('settings-single-surface')),
          findsOneWidget,
        );
        expect(find.text('Save preferences'), findsNothing);
      }
      expect(
        tester.getRect(find.text(title).first).right,
        lessThanOrEqualTo(width),
      );
    }
  }
}

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
}
