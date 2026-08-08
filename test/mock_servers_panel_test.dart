import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/demo/workbench_seed.dart';
import 'package:sendreq/domain/models/workspace_models.dart';
import 'package:sendreq/features/workspace/view_models/workspace_view_model.dart';
import 'package:sendreq/features/mock_servers/widgets/mock_servers_panel.dart';
import 'package:sendreq/features/response_viewer/widgets/response_panel.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';

import 'support/workspace_view_model_test_factory.dart';

void main() {
  testWidgets('creates a manual Mock from the empty Mock panel', (
    tester,
  ) async {
    final viewModel = workspaceViewModel(
      seed: const WorkbenchSeed(
        requests: [],
        drafts: {},
        variables: [],
        metrics: [],
        history: [],
      ),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnimatedBuilder(
          animation: viewModel,
          builder: (context, _) =>
              Scaffold(body: MockServersPanel(viewModel: viewModel)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('new-manual-mock-button')), findsOneWidget);
    final capturedResponseButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('create-mock-from-response-button')),
    );
    expect(capturedResponseButton.onPressed, isNull);
    expect(
      find.text(
        'Available for this session only. Removed when sendreq closes.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('new-manual-mock-button')));
    await tester.pump();

    expect(viewModel.mockDraft, isNotNull);
    expect(find.text('Manually configured response'), findsOneWidget);
    expect(find.text('QUICK MOCK RESPONSE'), findsOneWidget);
    expect(
      find.byKey(const Key('replace-with-new-mock-button')),
      findsOneWidget,
    );

    viewModel.updateMockResponseBody('{"current":true}');
    await tester.tap(find.byKey(const Key('replace-with-new-mock-button')));
    await tester.pumpAndSettle();

    expect(find.text('Replace Quick Mock?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(viewModel.mockDraft!.response.body, '{"current":true}');

    await tester.tap(find.byKey(const Key('replace-with-new-mock-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(viewModel.mockDraft!.response.body, contains('Mock response'));
  });

  testWidgets('confirms before a response replaces the current Quick Mock', (
    tester,
  ) async {
    final viewModel = workspaceViewModel(
      seed: WorkbenchSeed(
        requests: const [],
        drafts: const {},
        variables: const [],
        metrics: const [],
        history: [_responseRecord()],
      ),
    );
    addTearDown(viewModel.dispose);
    viewModel.createManualMockDraft();
    viewModel.openHistoryRecord('response-record');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnimatedBuilder(
          animation: viewModel,
          builder: (context, _) =>
              Scaffold(body: ResponsePanel(viewModel: viewModel)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Use response for Quick Mock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(viewModel.mockDraft!.source, MockDraftSource.manual);

    await tester.tap(find.byTooltip('Use response for Quick Mock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(viewModel.mockDraft!.source, MockDraftSource.response);
  });

  testWidgets('keeps the Quick Mock workflow usable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final viewModel = workspaceViewModel(
      seed: const WorkbenchSeed(
        requests: [],
        drafts: {},
        variables: [],
        metrics: [],
        history: [],
      ),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnimatedBuilder(
          animation: viewModel,
          builder: (context, _) =>
              Scaffold(body: MockServersPanel(viewModel: viewModel)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('new-manual-mock-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mock-route-input')), findsOneWidget);
    expect(find.byKey(const Key('mock-response-body-input')), findsOneWidget);
  });
}

ExecutionRecord _responseRecord() => ExecutionRecord(
  id: 'response-record',
  requestId: 'request-1',
  method: 'GET',
  path: '/status',
  timeMs: 5,
  when: 'now',
  requestSnapshot: const ExecutionRequestSnapshot(
    method: 'GET',
    resolvedUrl: 'https://api.sendreq.local/status',
    headers: [],
    body: '',
    environmentName: 'Test',
  ),
  response: const ResponseSnapshot(
    statusCode: 200,
    timeMs: 5,
    sizeKb: 0.1,
    body: '{"ok":true}',
    headers: [],
  ),
);
