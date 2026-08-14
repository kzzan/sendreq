import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/database/isar_workspace.dart';
import 'package:sendreq/data/database/isar_workspace_models.dart';
import 'package:sendreq/data/repositories/isar_user_notice_repository.dart';
import 'package:sendreq/data/repositories/workspace_document_keys.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/notifications/user_notice_repository.dart';

import 'support/isar_test_core.dart';

void main() {
  setUpAll(initializeIsarForTest);

  test(
    'merges unread notices and restores their data-only recovery command',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sendreq-notice-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final workspace = await IsarWorkspace.open(directory: directory);
      addTearDown(workspace.close);
      final repository = IsarUserNoticeRepository(workspace);

      await repository.upsertUnread(_notice(DateTime.utc(2026, 8, 11)));
      await repository.upsertUnread(_notice(DateTime.utc(2026, 8, 11, 1)));

      final restored = await repository.listUnread();
      expect(restored, hasLength(1));
      expect(restored.single.createdAt, DateTime.utc(2026, 8, 11));
      expect(
        restored.single.recovery!.id,
        RecoveryCommandId.retryMockServerStart,
      );
    },
  );

  test('acknowledges notices and retains actionable unread records', () async {
    final directory = await Directory.systemTemp.createTemp('sendreq-notice-');
    addTearDown(() => directory.delete(recursive: true));
    final workspace = await IsarWorkspace.open(directory: directory);
    addTearDown(workspace.close);
    final repository = IsarUserNoticeRepository(workspace);
    final now = DateTime.utc(2026, 8, 11);
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
  });

  test('isolates malformed entries and never writes Secret values', () async {
    final directory = await Directory.systemTemp.createTemp('sendreq-notice-');
    addTearDown(() => directory.delete(recursive: true));
    final workspace = await IsarWorkspace.open(directory: directory);
    addTearDown(workspace.close);
    final repository = IsarUserNoticeRepository(workspace);
    await repository.upsertUnread(_notice(DateTime.utc(2026, 8, 11)));
    final document = await workspace.instance.workspaceDocuments.getByKey(
      WorkspaceDocumentKeys.userNoticesV1,
    );
    final payload = document!.payloadJson.replaceFirst(
      '"notices":[',
      '"notices":[{"invalid":true},',
    );
    await workspace.instance.writeTxn(() async {
      document.payloadJson = payload;
      await workspace.instance.workspaceDocuments.put(document);
    });

    final restored = await repository.listUnread();

    expect(restored.map((notice) => notice.deduplicationKey), [
      'mock-start:mock-1',
    ]);
    expect(payload, isNot(contains('secret-value')));
    expect(payload, isNot(contains('authorization')));
  });

  test('clears all persisted notification records', () async {
    final directory = await Directory.systemTemp.createTemp('sendreq-notice-');
    addTearDown(() => directory.delete(recursive: true));
    final workspace = await IsarWorkspace.open(directory: directory);
    addTearDown(workspace.close);
    final repository = IsarUserNoticeRepository(workspace);
    await repository.upsertUnread(_notice(DateTime.utc(2026, 8, 13)));

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
