import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/ui/shell/application/user_notice.dart';
import 'package:sendreq/ui/shell/widgets/notification_center.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
    'shows actionable notices with separate recovery and acknowledgement',
    (tester) async {
      final notice = UserNotice(
        code: NoticeCode.operationFailed,
        severity: NoticeSeverity.error,
        deduplicationKey: 'mock-start-failed',
        createdAt: DateTime.utc(2026, 8, 11),
        expiry: NoticeExpiry.untilResolved,
        recovery: RecoveryCommand(
          id: RecoveryCommandId.retryMockServerStart,
          resourceRef: const ResourceRef(
            kind: ResourceKind.mockServer,
            id: 'orders-mock',
          ),
        ),
      );
      String? acknowledged;
      UserNotice? recovered;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NotificationCenter(
              notices: [notice],
              acknowledge: (key) async => acknowledged = key,
              recover: (item) async => recovered = item,
              clearAll: () async => true,
            ),
          ),
        ),
      );

      expect(find.text('Action failed'), findsOneWidget);
      expect(find.text('Retry start'), findsOneWidget);
      await tester.tap(find.text('Retry start'));
      await tester.pump();
      expect(recovered, same(notice));

      await tester.tap(find.byTooltip('Acknowledge notification'));
      await tester.pump();
      expect(acknowledged, notice.deduplicationKey);
    },
  );

  testWidgets('explains when there are no actionable notices', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NotificationCenter(
            notices: const [],
            acknowledge: (_) async {},
            recover: (_) async {},
            clearAll: () async => true,
          ),
        ),
      ),
    );

    expect(find.text('No notifications'), findsOneWidget);
  });

  testWidgets('renders the concrete safe message for a session notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NotificationCenter(
            notices: [
              UserNotice(
                code: NoticeCode.operationSucceeded,
                severity: NoticeSeverity.success,
                deduplicationKey: 'request.saved',
                createdAt: DateTime.utc(2026, 8, 14),
                expiry: NoticeExpiry.untilAcknowledged,
                message: 'Request changes saved.',
              ),
            ],
            acknowledge: (_) async {},
            recover: (_) async {},
            clearAll: () async => true,
          ),
        ),
      ),
    );

    expect(find.text('Request changes saved.'), findsOneWidget);
  });

  testWidgets('clears ordinary notifications without confirmation', (
    tester,
  ) async {
    var cleared = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NotificationCenter(
            notices: [
              UserNotice(
                code: NoticeCode.operationFailed,
                severity: NoticeSeverity.error,
                deduplicationKey: 'save-failed',
                createdAt: DateTime.utc(2026, 8, 13),
                expiry: NoticeExpiry.untilAcknowledged,
              ),
            ],
            acknowledge: (_) async {},
            recover: (_) async {},
            clearAll: () async {
              cleared = true;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Clear notifications'));
    await tester.pumpAndSettle();
    expect(cleared, isTrue);
    expect(find.text('Clear notifications?'), findsNothing);
  });

  testWidgets('confirms before clearing notifications with recovery', (
    tester,
  ) async {
    var cleared = false;
    final notice = UserNotice(
      code: NoticeCode.operationFailed,
      severity: NoticeSeverity.error,
      deduplicationKey: 'mock-start-failed',
      createdAt: DateTime.utc(2026, 8, 13),
      expiry: NoticeExpiry.untilResolved,
      recovery: RecoveryCommand(
        id: RecoveryCommandId.retryMockServerStart,
        resourceRef: const ResourceRef(
          kind: ResourceKind.mockServer,
          id: 'orders-mock',
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NotificationCenter(
            notices: [notice],
            acknowledge: (_) async {},
            recover: (_) async {},
            clearAll: () async {
              cleared = true;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Clear notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Clear notifications?'), findsOneWidget);
    expect(cleared, isFalse);
    await tester.tap(find.text('Clear notifications').last);
    await tester.pumpAndSettle();
    expect(cleared, isTrue);
  });
}
