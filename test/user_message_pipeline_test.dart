import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/domain/api_assets/openapi_exchange.dart';
import 'package:sendreq/domain/notifications/user_notice_repository.dart';
import 'package:sendreq/ui/core/application/user_message.dart';
import 'package:sendreq/ui/core/theme/app_theme.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/widgets/user_message_scope.dart';
import 'package:sendreq/ui/features/requests/collection/widgets/openapi_export_actions.dart';
import 'package:sendreq/ui/shell/application/workspace_window_controls.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/ui/shell/widgets/notification_center.dart';
import 'package:sendreq/ui/shell/widgets/top_bar.dart';

import 'support/workspace_view_model_test_factory.dart';

void main() {
  test('clear failure remains visible without recursive persistence', () async {
    final repository = _FailingClearNoticeRepository();
    final viewModel = workspaceViewModel(userNoticeRepository: repository);
    addTearDown(viewModel.dispose);
    viewModel.publishUserMessage(UserMessage(message: 'Existing message.'));

    expect(await viewModel.clearNotices(), isFalse);

    expect(viewModel.notices, hasLength(2));
    expect(
      viewModel.notices.last.message,
      'Could not clear notifications. Retry.',
    );
    expect(repository.upsertCount, 0);
  });

  testWidgets('shared clipboard feedback publishes through the Shell scope', (
    tester,
  ) async {
    UserMessage? published;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: UserMessageScope(
          publish: (message) => published = message,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => copyToClipboard(
                context,
                'safe output',
                'Response body copied.',
              ),
              child: const Text('Copy'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(published?.message, 'Response body copied.');
    expect(published?.severity, UserMessageSeverity.success);
    expect(published?.deduplicationKey, 'clipboard.copied');
  });

  testWidgets('top bar badge updates from the unified message queue', (
    tester,
  ) async {
    final viewModel = workspaceViewModel();
    addTearDown(viewModel.dispose);
    viewModel.publishUserMessage(
      UserMessage(
        message: 'Request changes saved.',
        severity: UserMessageSeverity.success,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: SendreqTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            child: TopBar(
              viewModel: viewModel,
              windowControls: const NoopWorkspaceWindowControls(),
              onOpenNotifications: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.byTooltip('1 notifications need attention'), findsOneWidget);
  });

  testWidgets(
    'OpenAPI export success flows from command to badge and notification center',
    (tester) async {
      const exportedPath = '/private/workspace/sendreq-openapi/openapi.json';
      final exporter = _RecordingOpenApiFileExporter(exportedPath);
      final directory = _RecordingOpenApiOutputDirectory();
      final repository = _FailingClearNoticeRepository();
      final viewModel = workspaceViewModel(
        openApiFileExporter: exporter,
        openApiOutputDirectory: directory,
        userNoticeRepository: repository,
      );
      addTearDown(viewModel.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: SendreqTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _ExportNotificationHarness(viewModel: viewModel),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(directory.directories, ['sendreq-openapi']);
      expect(exporter.requests, hasLength(1));
      expect(exporter.requests.single.outputDirectory, 'sendreq-openapi');
      expect(exporter.requests.single.source, contains('"openapi"'));
      expect(find.byTooltip('1 notifications need attention'), findsOneWidget);

      await tester.tap(find.byTooltip('1 notifications need attention'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationCenter), findsOneWidget);
      expect(find.text('OpenAPI exported.'), findsOneWidget);
      expect(find.textContaining(exportedPath), findsNothing);
      expect(repository.upsertCount, 0);
    },
  );
}

class _ExportNotificationHarness extends StatelessWidget {
  const _ExportNotificationHarness({required this.viewModel});

  final WorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: viewModel,
    builder: (context, _) => UserMessageScope(
      publish: viewModel.publishUserMessage,
      child: Scaffold(
        body: Column(
          children: [
            TopBar(
              viewModel: viewModel,
              windowControls: const NoopWorkspaceWindowControls(),
              onOpenNotifications: () => showDialog<void>(
                context: context,
                builder: (context) => NotificationCenter(
                  notices: viewModel.notices,
                  acknowledge: viewModel.acknowledgeNotice,
                  recover: viewModel.recoverNotice,
                  clearAll: viewModel.clearNotices,
                ),
              ),
            ),
            Builder(
              builder: (context) => FilledButton(
                onPressed: () => exportOpenApiToFile(context, viewModel),
                child: const Text('Export'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RecordingOpenApiFileExporter implements OpenApiFileExportPort {
  _RecordingOpenApiFileExporter(this.path);

  final String path;
  final List<OpenApiFileExportRequest> requests = [];

  @override
  Future<OpenApiFileExportResult> write(
    OpenApiFileExportRequest request,
  ) async {
    requests.add(request);
    return OpenApiFileExportResult(path: path);
  }
}

class _RecordingOpenApiOutputDirectory implements OpenApiOutputDirectoryPort {
  final List<String> directories = [];

  @override
  Future<void> ensureExists(String directory) async {
    directories.add(directory);
  }
}

class _FailingClearNoticeRepository implements UserNoticeRepository {
  int upsertCount = 0;

  @override
  Future<void> clearAll() => Future<void>.error(StateError('unavailable'));

  @override
  Future<List<PersistentUserNotice>> listUnread() async => const [];

  @override
  Future<void> markRead(String deduplicationKey, DateTime readAt) async {}

  @override
  Future<void> prune(UserNoticeRetentionPolicy policy) async {}

  @override
  Future<void> upsertUnread(PersistentUserNotice notice) async {
    upsertCount += 1;
  }
}
