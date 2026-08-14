import 'dart:async';
import 'dart:convert';

import 'package:sendreq/domain/notifications/user_notice_repository.dart';
import 'package:sendreq/data/database/isar_workspace.dart';
import 'package:sendreq/data/database/isar_workspace_models.dart';
import 'package:sendreq/data/repositories/user_notice_snapshot_codec.dart';
import 'package:sendreq/data/repositories/workspace_document_keys.dart';

/// 使用 `user-notices-v1` 的有界、可恢复通知仓储。
class IsarUserNoticeRepository implements UserNoticeRepository {
  IsarUserNoticeRepository(this._workspace);

  static const maxDocumentBytes = 1024 * 1024;
  final IsarWorkspace _workspace;
  Future<void> _writes = Future.value();

  @override
  Future<List<PersistentUserNotice>> listUnread() async => List.unmodifiable(
    (await _read()).where((notice) => !notice.isRead).toList()
      ..sort(_byUpdated),
  );

  @override
  Future<void> markRead(String deduplicationKey, DateTime readAt) => _enqueue(
    (notices) => [
      for (final notice in notices)
        notice.deduplicationKey == deduplicationKey
            ? notice.copyWith(readAt: readAt.toUtc(), updatedAt: readAt.toUtc())
            : notice,
    ],
  );

  @override
  Future<void> clearAll() => _enqueue((_) => <PersistentUserNotice>[]);

  @override
  Future<void> prune(UserNoticeRetentionPolicy policy) => _enqueue((notices) {
    final unread = notices.where((notice) => !notice.isRead).toList()
      ..sort(_byUpdated);
    final keep = <String>{
      ...unread.take(policy.maxUnread).map((notice) => notice.deduplicationKey),
      ...unread
          .where((notice) => notice.isActionable)
          .map((notice) => notice.deduplicationKey),
    };
    final read = notices.where((notice) => notice.isRead).toList()
      ..sort(_byUpdated);
    keep.addAll(
      read.take(policy.maxRead).map((notice) => notice.deduplicationKey),
    );
    return notices
        .where((notice) => keep.contains(notice.deduplicationKey))
        .toList();
  });

  @override
  Future<void> upsertUnread(PersistentUserNotice notice) {
    if (notice.isRead) {
      throw ArgumentError.value(
        notice,
        'notice',
        'Cannot upsert a read notice.',
      );
    }
    return _enqueue((notices) {
      final existing = notices
          .where((item) => item.deduplicationKey == notice.deduplicationKey)
          .firstOrNull;
      return [
        ...notices.where(
          (item) => item.deduplicationKey != notice.deduplicationKey,
        ),
        existing == null
            ? notice
            : notice.copyWith(createdAt: existing.createdAt, clearReadAt: true),
      ];
    });
  }

  Future<List<PersistentUserNotice>> _read() async {
    final document = await _workspace.instance.workspaceDocuments.getByKey(
      WorkspaceDocumentKeys.userNoticesV1,
    );
    if (document == null) return const [];
    try {
      return UserNoticeSnapshotCodec.decodeDocument(document.payloadJson);
    } on Object {
      return const [];
    }
  }

  Future<void> _enqueue(
    List<PersistentUserNotice> Function(List<PersistentUserNotice>) change,
  ) {
    _writes = _writes.then((_) async {
      final document = await _workspace.instance.workspaceDocuments.getByKey(
        WorkspaceDocumentKeys.userNoticesV1,
      );
      final current = document == null
          ? <PersistentUserNotice>[]
          : UserNoticeSnapshotCodec.decodeDocument(document.payloadJson);
      final next = change(current)..sort(_byUpdated);
      final payload = UserNoticeSnapshotCodec.encodeDocument(next);
      if (utf8.encode(payload).length > maxDocumentBytes) {
        throw StateError('User notice document exceeds the local byte budget.');
      }
      final target = document ?? WorkspaceDocument();
      target
        ..key = WorkspaceDocumentKeys.userNoticesV1
        ..schemaVersion = IsarWorkspace.currentDocumentSchemaVersion
        ..updatedAt = DateTime.now().toUtc()
        ..payloadJson = payload;
      await _workspace.instance.writeTxn(
        () => _workspace.instance.workspaceDocuments.put(target),
      );
    });
    return _writes;
  }

  static int _byUpdated(
    PersistentUserNotice left,
    PersistentUserNotice right,
  ) => right.updatedAt.compareTo(left.updatedAt);
}
