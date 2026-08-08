import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/demo/workbench_seed.dart';
import 'package:sendreq/domain/models/workspace_models.dart';
import 'package:sendreq/features/workspace/view_models/workspace_view_model.dart';
import 'package:sendreq/features/history/widgets/history_panel.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';

import 'support/workspace_view_model_test_factory.dart';

void main() {
  testWidgets('history workspace selects, searches, and filters snapshots', (
    tester,
  ) async {
    final viewModel = workspaceViewModel(
      seed: WorkbenchSeed(
        requests: const [],
        drafts: const {},
        variables: const [],
        metrics: const [],
        history: [
          _record('failed', '/v1/exports', status: 502),
          _record('ok', '/v1/users'),
        ],
      ),
    );
    addTearDown(viewModel.dispose);
    viewModel.selectSection(WorkspaceSection.history);

    await tester.pumpWidget(_host(viewModel));
    await tester.pumpAndSettle();

    expect(viewModel.openedHistoryRecord?.id, 'failed');
    expect(find.byKey(const Key('history-entry-failed')), findsOneWidget);
    expect(find.byKey(const Key('history-entry-ok')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('history-search-input')),
      'users',
    );
    await tester.pump();
    expect(find.byKey(const Key('history-entry-failed')), findsNothing);
    expect(find.byKey(const Key('history-entry-ok')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('history-search-input')), '');
    await tester.pump();
    await tester.tap(find.text('Failed'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-entry-failed')), findsOneWidget);
    expect(find.byKey(const Key('history-entry-ok')), findsNothing);
  });

  testWidgets(
    'history workspace stacks its timeline and details on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(375, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final viewModel = workspaceViewModel(
        seed: WorkbenchSeed(
          requests: const [],
          drafts: const {},
          variables: const [],
          metrics: const [],
          history: [_record('ok', '/v1/users')],
        ),
      );
      addTearDown(viewModel.dispose);
      viewModel.selectSection(WorkspaceSection.history);

      await tester.pumpWidget(_host(viewModel));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-search-input')), findsOneWidget);
      expect(find.text('Execution snapshot · Test'), findsOneWidget);
    },
  );

  testWidgets('history workspace confirms before clearing all executions', (
    tester,
  ) async {
    final viewModel = workspaceViewModel(
      seed: WorkbenchSeed(
        requests: const [],
        drafts: const {},
        variables: const [],
        metrics: const [],
        history: [_record('ok', '/v1/users')],
      ),
    );
    addTearDown(viewModel.dispose);
    viewModel.selectSection(WorkspaceSection.history);

    await tester.pumpWidget(_host(viewModel));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear history'));
    await tester.pumpAndSettle();
    expect(find.text('Clear execution history?'), findsOneWidget);

    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    expect(viewModel.history, isEmpty);
    expect(viewModel.openedHistoryRecord, isNull);
    expect(find.text('No executions yet.'), findsOneWidget);
  });
}

Widget _host(WorkspaceViewModel viewModel) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: AnimatedBuilder(
    animation: viewModel,
    builder: (context, _) => Scaffold(body: HistoryPanel(viewModel: viewModel)),
  ),
);

ExecutionRecord _record(String id, String path, {int status = 200}) =>
    ExecutionRecord(
      id: id,
      requestId: id,
      method: 'GET',
      path: path,
      status: status,
      timeMs: 42,
      when: 'now',
      requestSnapshot: ExecutionRequestSnapshot(
        method: 'GET',
        resolvedUrl: 'https://api.sendreq.local$path',
        headers: const [],
        body: '',
        environmentName: 'Test',
      ),
      response: ResponseSnapshot(
        statusCode: status,
        timeMs: 42,
        sizeKb: 0.1,
        body: '{"ok":true}',
        headers: const [],
      ),
    );
