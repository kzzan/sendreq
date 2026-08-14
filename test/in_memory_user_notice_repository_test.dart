import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_user_notice_repository.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/notifications/user_notice_repository.dart';

void main() {
  final now = DateTime.utc(2026, 8, 11, 12);

  test(
    'merges repeated unread notices and restores only unread records',
    () async {
      final repository = InMemoryUserNoticeRepository();
      await repository.upsertUnread(_notice(now));
      await repository.upsertUnread(
        _notice(now.add(const Duration(minutes: 1))),
      );

      final notices = await repository.listUnread();
      expect(notices, hasLength(1));
      expect(notices.single.createdAt, now);
      expect(notices.single.updatedAt, now.add(const Duration(minutes: 1)));

      await repository.markRead(
        'mock-start:mock-1',
        now.add(const Duration(minutes: 2)),
      );
      expect(await repository.listUnread(), isEmpty);
    },
  );

  test(
    'retention keeps actionable unread records and bounds read records',
    () async {
      final repository = InMemoryUserNoticeRepository();
      await repository.upsertUnread(_notice(now));
      await repository.upsertUnread(
        PersistentUserNotice(
          deduplicationKey: 'non-actionable',
          code: 'mockServer.failed',
          severity: DurableNoticeSeverity.error,
          createdAt: now.add(const Duration(minutes: 1)),
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );
      await repository.markRead(
        'non-actionable',
        now.add(const Duration(minutes: 2)),
      );
      await repository.prune(
        const UserNoticeRetentionPolicy(maxUnread: 1, maxRead: 0),
      );

      expect(
        (await repository.listUnread()).single.deduplicationKey,
        'mock-start:mock-1',
      );
    },
  );

  test(
    'rejects unsafe values and recovery commands without the correct reference',
    () {
      expect(
        () => PersistentUserNotice(
          deduplicationKey: 'unsafe',
          code: 'mockServer.failed',
          severity: DurableNoticeSeverity.error,
          createdAt: now,
          updatedAt: now,
          arguments: const {'url': 'http://127.0.0.1:50000'},
        ),
        throwsArgumentError,
      );
      expect(
        () => PersistentUserNotice(
          deduplicationKey: 'wrong-ref',
          code: 'mockServer.failed',
          severity: DurableNoticeSeverity.error,
          createdAt: now,
          updatedAt: now,
          recovery: RecoveryCommand(
            id: RecoveryCommandId.retryMockServerStart,
            resourceRef: const ResourceRef(
              kind: ResourceKind.request,
              id: 'request-1',
            ),
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test('clears all notification records', () async {
    final repository = InMemoryUserNoticeRepository();
    await repository.upsertUnread(_notice(now));

    await repository.clearAll();

    expect(await repository.listUnread(), isEmpty);
  });
}

PersistentUserNotice _notice(DateTime updatedAt) => PersistentUserNotice(
  deduplicationKey: 'mock-start:mock-1',
  code: 'mockServer.startFailed',
  severity: DurableNoticeSeverity.error,
  createdAt: updatedAt,
  updatedAt: updatedAt,
  resourceRef: const ResourceRef(kind: ResourceKind.mockServer, id: 'mock-1'),
  recovery: RecoveryCommand(
    id: RecoveryCommandId.retryMockServerStart,
    resourceRef: const ResourceRef(kind: ResourceKind.mockServer, id: 'mock-1'),
  ),
);
