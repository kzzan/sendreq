import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/notifications/user_notice_repository.dart';
import 'package:sendreq/ui/core/application/user_message.dart';

/// 供 Shell 本地化与展示层理解的稳定标识符。
enum NoticeCode {
  operationSucceeded,
  operationFailed,
  operationPartiallyCompleted,
  sessionFailed,
  sessionReconnecting,
  sessionDisconnected,
}

/// 由 Workspace Shell 选择的视觉严重级别。
enum NoticeSeverity { info, success, warning, error }

/// 由 Shell 通知队列拥有的生命周期。
enum NoticeExpiry { automatic, untilAcknowledged, untilResolved }

/// 一种安全、短生命周期的用户可见通知。这不是领域事件。
class UserNotice {
  UserNotice({
    required this.code,
    required this.severity,
    required this.deduplicationKey,
    required this.createdAt,
    required this.expiry,
    this.resourceRef,
    Map<String, String> arguments = const {},
    this.recovery,
    this.message,
  }) : arguments = Map.unmodifiable(arguments) {
    _assertSafeArguments(this.arguments);
  }

  final NoticeCode code;
  final NoticeSeverity severity;
  final String deduplicationKey;
  final DateTime createdAt;
  final NoticeExpiry expiry;
  final ResourceRef? resourceRef;
  final Map<String, String> arguments;
  final RecoveryCommand? recovery;
  final String? message;

  bool get isActionable => recovery != null;

  static void _assertSafeArguments(Map<String, String> arguments) {
    const disallowedNames = {
      'authorization',
      'body',
      'cookie',
      'header',
      'password',
      'secret',
      'token',
      'url',
    };
    for (final entry in arguments.entries) {
      final normalized = entry.key.toLowerCase();
      if (disallowedNames.any(normalized.contains)) {
        throw ArgumentError.value(
          entry.key,
          'arguments',
          'Notice arguments must not contain secret-bearing request data.',
        );
      }
    }
  }
}

/// 负责队列变更、合并、确认与过期。
class WorkspaceNoticeQueue {
  WorkspaceNoticeQueue({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final List<UserNotice> _notices = [];

  List<UserNotice> get notices => List.unmodifiable(_notices);

  /// 不可操作的通知会替换具有相同 key 的最新通知。
  void push(UserNotice notice) {
    if (!notice.isActionable) {
      final existing = _notices.indexWhere(
        (item) =>
            !item.isActionable &&
            item.deduplicationKey == notice.deduplicationKey,
      );
      if (existing >= 0) {
        _notices[existing] = notice;
        return;
      }
    }
    _notices.add(notice);
  }

  void acknowledge(String deduplicationKey) {
    _notices.removeWhere((item) => item.deduplicationKey == deduplicationKey);
  }

  void resolve(String deduplicationKey) => acknowledge(deduplicationKey);

  void clear() => _notices.clear();

  void expireAutomatic({Duration after = const Duration(seconds: 6)}) {
    final threshold = _clock().subtract(after);
    _notices.removeWhere(
      (item) =>
          item.expiry == NoticeExpiry.automatic &&
          item.createdAt.isBefore(threshold),
    );
  }
}

/// 将清洗后的模块结果映射为 Shell 持有的通知状态。
class WorkspaceNoticeController {
  WorkspaceNoticeController({
    WorkspaceNoticeQueue? queue,
    DateTime Function()? clock,
    this.repository,
    this.retentionPolicy = const UserNoticeRetentionPolicy(),
  }) : queue = queue ?? WorkspaceNoticeQueue(clock: clock),
       _clock = clock ?? DateTime.now;

  final WorkspaceNoticeQueue queue;
  final DateTime Function() _clock;
  final UserNoticeRepository? repository;
  final UserNoticeRetentionPolicy retentionPolicy;

  /// 立即更新瞬时队列；持久化失败不能影响本次可见反馈。
  Future<void> recordOutcome(OperationOutcome outcome, {String? message}) {
    final notice = switch (outcome.kind) {
      OperationOutcomeKind.success => UserNotice(
        code: NoticeCode.operationSucceeded,
        severity: NoticeSeverity.success,
        deduplicationKey: _key('outcome', outcome.code, outcome.resourceRef),
        createdAt: _clock(),
        expiry: NoticeExpiry.automatic,
        resourceRef: outcome.resourceRef,
        arguments: outcome.arguments,
        recovery: outcome.recovery,
        message: message,
      ),
      OperationOutcomeKind.cancelled => null,
      OperationOutcomeKind.failed || OperationOutcomeKind.partial => UserNotice(
        code: outcome.kind == OperationOutcomeKind.partial
            ? NoticeCode.operationPartiallyCompleted
            : NoticeCode.operationFailed,
        severity: outcome.kind == OperationOutcomeKind.partial
            ? NoticeSeverity.warning
            : NoticeSeverity.error,
        deduplicationKey: _key('outcome', outcome.code, outcome.resourceRef),
        createdAt: _clock(),
        expiry: outcome.recovery == null
            ? NoticeExpiry.untilAcknowledged
            : NoticeExpiry.untilResolved,
        resourceRef: outcome.resourceRef,
        arguments: outcome.arguments,
        recovery: outcome.recovery,
        message: message,
      ),
    };
    if (notice == null) return Future<void>.value();
    queue.push(notice);
    if (!_shouldPersist(outcome)) return Future<void>.value();
    return _persistOutcome(outcome, notice);
  }

  /// 记录应用自有的当前会话消息，不写入持久化通知仓库。
  void recordSessionMessage(UserMessage message) {
    final notice = UserNotice(
      code: switch (message.severity) {
        UserMessageSeverity.info ||
        UserMessageSeverity.success => NoticeCode.operationSucceeded,
        UserMessageSeverity.warning => NoticeCode.operationPartiallyCompleted,
        UserMessageSeverity.error => NoticeCode.operationFailed,
      },
      severity: switch (message.severity) {
        UserMessageSeverity.info => NoticeSeverity.info,
        UserMessageSeverity.success => NoticeSeverity.success,
        UserMessageSeverity.warning => NoticeSeverity.warning,
        UserMessageSeverity.error => NoticeSeverity.error,
      },
      deduplicationKey: message.deduplicationKey ?? _sessionMessageKey(message),
      createdAt: _clock(),
      expiry: NoticeExpiry.untilAcknowledged,
      message: message.message,
    );
    queue.push(notice);
  }

  /// 恢复重启前留下的未读可操作结果，保留瞬时队列中的当前状态。
  Future<void> restoreUnread() async {
    final noticeRepository = repository;
    if (noticeRepository == null) return;
    try {
      final notices = await noticeRepository.listUnread();
      for (final notice in notices) {
        queue.push(
          UserNotice(
            code: _noticeCodeFor(notice.code, notice.severity),
            severity: _severityFor(notice.severity),
            deduplicationKey: notice.deduplicationKey,
            createdAt: notice.updatedAt,
            expiry: notice.recovery == null
                ? NoticeExpiry.untilAcknowledged
                : NoticeExpiry.untilResolved,
            resourceRef: notice.resourceRef,
            arguments: notice.arguments,
            recovery: notice.recovery,
          ),
        );
      }
    } on Object {
      // 读取失败时保留当前队列；调用方无需暴露原始存储异常。
    }
  }

  /// 确认即时通知，同时尽力将对应持久化记录标记为已读。
  Future<void> acknowledge(String deduplicationKey) async {
    queue.acknowledge(deduplicationKey);
    final noticeRepository = repository;
    if (noticeRepository == null) return;
    try {
      await noticeRepository.markRead(deduplicationKey, _clock().toUtc());
    } on Object {
      // 当前会话已确认；下次恢复时仍可能显示该记录，避免丢失可操作失败。
    }
  }

  /// 先清持久化记录，成功后才更新可见队列。
  Future<bool> clearAll() async {
    final noticeRepository = repository;
    if (noticeRepository != null) {
      try {
        await noticeRepository.clearAll();
      } on Object {
        return false;
      }
    }
    queue.clear();
    return true;
  }

  /// 只有值得用户关注的状态转换才会成为通知。
  Future<void> recordSessionProjection(
    SanitizedSessionProjection projection,
  ) async {
    final normalizedStatus = projection.status.toLowerCase();
    final code = switch (normalizedStatus) {
      'failed' => NoticeCode.sessionFailed,
      'reconnecting' => NoticeCode.sessionReconnecting,
      'disconnected' => NoticeCode.sessionDisconnected,
      _ => null,
    };
    if (code == null) return;
    final now = _clock().toUtc();
    final notice = UserNotice(
      code: code,
      severity: code == NoticeCode.sessionFailed
          ? NoticeSeverity.error
          : NoticeSeverity.warning,
      deduplicationKey: 'session:${projection.sessionId}:$normalizedStatus',
      createdAt: now,
      expiry: NoticeExpiry.untilAcknowledged,
      resourceRef: ResourceRef(
        kind: ResourceKind.request,
        id: projection.requestRef.id,
      ),
      arguments: {'summary': projection.summary},
    );
    queue.push(notice);
    final noticeRepository = repository;
    if (noticeRepository == null) return;
    try {
      await noticeRepository.upsertUnread(
        PersistentUserNotice(
          deduplicationKey: notice.deduplicationKey,
          code: 'session.$normalizedStatus',
          severity: code == NoticeCode.sessionFailed
              ? DurableNoticeSeverity.error
              : DurableNoticeSeverity.warning,
          createdAt: now,
          updatedAt: now,
          resourceRef: notice.resourceRef,
          arguments: notice.arguments,
        ),
      );
      await noticeRepository.prune(retentionPolicy);
    } on Object {
      // 会话失败仍留在当前队列，存储异常不暴露 transport 或原始错误。
    }
  }

  String _key(String category, String code, ResourceRef? resourceRef) =>
      '$category:$code:${resourceRef?.kind.name ?? 'global'}:${resourceRef?.id ?? ''}';

  String _sessionMessageKey(UserMessage message) {
    var hash = 0x811c9dc5;
    for (final codeUnit in message.message.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7fffffff;
    }
    return 'message:${message.severity.name}:$hash';
  }

  bool _shouldPersist(OperationOutcome outcome) =>
      outcome.kind == OperationOutcomeKind.failed ||
      outcome.kind == OperationOutcomeKind.partial ||
      outcome.recovery != null;

  Future<void> _persistOutcome(
    OperationOutcome outcome,
    UserNotice notice,
  ) async {
    final noticeRepository = repository;
    if (noticeRepository == null) return;
    try {
      final now = _clock().toUtc();
      await noticeRepository.upsertUnread(
        PersistentUserNotice(
          deduplicationKey: notice.deduplicationKey,
          code: outcome.code,
          severity: outcome.kind == OperationOutcomeKind.partial
              ? DurableNoticeSeverity.warning
              : DurableNoticeSeverity.error,
          createdAt: now,
          updatedAt: now,
          resourceRef: outcome.resourceRef,
          arguments: outcome.arguments,
          recovery: outcome.recovery,
        ),
      );
      await noticeRepository.prune(retentionPolicy);
    } on Object {
      // 通知持久化是附加能力，不能回滚已经展示的即时通知。
    }
  }

  NoticeCode _noticeCodeFor(String code, DurableNoticeSeverity severity) =>
      severity == DurableNoticeSeverity.warning
      ? NoticeCode.operationPartiallyCompleted
      : NoticeCode.operationFailed;

  NoticeSeverity _severityFor(DurableNoticeSeverity severity) =>
      severity == DurableNoticeSeverity.warning
      ? NoticeSeverity.warning
      : NoticeSeverity.error;
}

/// Workspace Shell 的统一反馈分发器。
///
/// 它只接受已经脱敏的领域结果；controller 负责统一队列与持久化准入。
class WorkspaceFeedbackDispatcher {
  WorkspaceFeedbackDispatcher(this._notices);

  final WorkspaceNoticeController _notices;

  Future<void> dispatchOutcome(
    OperationOutcome outcome, {
    String? message,
  }) async {
    if (outcome.kind != OperationOutcomeKind.cancelled) {
      await _notices.recordOutcome(outcome, message: message);
    }
  }

  Future<void> dispatchSession(SanitizedSessionProjection projection) =>
      _notices.recordSessionProjection(projection);
}
