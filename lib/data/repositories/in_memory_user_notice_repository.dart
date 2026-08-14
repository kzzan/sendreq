import 'package:sendreq/domain/notifications/user_notice_repository.dart';

/// 用于测试与无磁盘组合的持久化通知语义实现。
class InMemoryUserNoticeRepository implements UserNoticeRepository {
  final Map<String, PersistentUserNotice> _notices = {};

  @override
  Future<List<PersistentUserNotice>> listUnread() async => List.unmodifiable(
    _notices.values.where((notice) => !notice.isRead).toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt)),
  );

  @override
  Future<void> markRead(String deduplicationKey, DateTime readAt) async {
    final current = _notices[deduplicationKey];
    if (current == null) return;
    _notices[deduplicationKey] = current.copyWith(
      readAt: readAt.toUtc(),
      updatedAt: readAt.toUtc(),
    );
  }

  @override
  Future<void> clearAll() async => _notices.clear();

  @override
  Future<void> prune(UserNoticeRetentionPolicy policy) async {
    final unread = _notices.values.where((notice) => !notice.isRead).toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    for (final notice in unread.skip(policy.maxUnread)) {
      if (!notice.isActionable) _notices.remove(notice.deduplicationKey);
    }
    final read = _notices.values.where((notice) => notice.isRead).toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    for (final notice in read.skip(policy.maxRead)) {
      _notices.remove(notice.deduplicationKey);
    }
  }

  @override
  Future<void> upsertUnread(PersistentUserNotice notice) async {
    if (notice.isRead) {
      throw ArgumentError.value(
        notice,
        'notice',
        'Cannot upsert a read notice as unread.',
      );
    }
    final existing = _notices[notice.deduplicationKey];
    _notices[notice.deduplicationKey] = existing == null
        ? notice
        : notice.copyWith(createdAt: existing.createdAt, clearReadAt: true);
  }
}
