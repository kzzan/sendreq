import 'package:sendreq/domain/module_boundaries/boundary_models.dart';

/// 可持久化通知的展示严重级别，独立于 Shell 的临时展示表面。
enum DurableNoticeSeverity { warning, error }

/// 本地通知记录的有界保留策略。
class UserNoticeRetentionPolicy {
  const UserNoticeRetentionPolicy({this.maxUnread = 50, this.maxRead = 200})
    : assert(maxUnread > 0),
      assert(maxRead >= 0);

  final int maxUnread;
  final int maxRead;
}

/// 可在重启后显示的已脱敏通知。恢复命令只包含数据，不包含回调。
class PersistentUserNotice {
  PersistentUserNotice({
    required this.deduplicationKey,
    required this.code,
    required this.severity,
    required this.createdAt,
    required this.updatedAt,
    this.resourceRef,
    Map<String, String> arguments = const {},
    this.recovery,
    this.readAt,
  }) : arguments = Map.unmodifiable(arguments) {
    if (deduplicationKey.trim().isEmpty || code.trim().isEmpty) {
      throw ArgumentError('Notice deduplication key and code cannot be empty.');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError.value(
        updatedAt,
        'updatedAt',
        'Cannot precede createdAt.',
      );
    }
    if (readAt != null && readAt!.isBefore(createdAt)) {
      throw ArgumentError.value(readAt, 'readAt', 'Cannot precede createdAt.');
    }
    _assertSafeArguments(this.arguments);
    if (recovery != null) _assertSafeRecovery(recovery!);
  }

  final String deduplicationKey;
  final String code;
  final DurableNoticeSeverity severity;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ResourceRef? resourceRef;
  final Map<String, String> arguments;
  final RecoveryCommand? recovery;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  bool get isActionable => recovery != null;

  PersistentUserNotice copyWith({
    String? code,
    DurableNoticeSeverity? severity,
    DateTime? createdAt,
    DateTime? updatedAt,
    ResourceRef? resourceRef,
    Map<String, String>? arguments,
    RecoveryCommand? recovery,
    DateTime? readAt,
    bool clearRecovery = false,
    bool clearReadAt = false,
  }) => PersistentUserNotice(
    deduplicationKey: deduplicationKey,
    code: code ?? this.code,
    severity: severity ?? this.severity,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    resourceRef: resourceRef ?? this.resourceRef,
    arguments: arguments ?? this.arguments,
    recovery: clearRecovery ? null : recovery ?? this.recovery,
    readAt: clearReadAt ? null : readAt ?? this.readAt,
  );

  static void _assertSafeArguments(Map<String, String> arguments) {
    const unsafeFragments = {
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
      final name = entry.key.toLowerCase();
      if (unsafeFragments.any(name.contains) || entry.value.contains('://')) {
        throw ArgumentError.value(
          entry.key,
          'arguments',
          'Must not contain raw request or secret-bearing data.',
        );
      }
    }
  }

  static void _assertSafeRecovery(RecoveryCommand recovery) {
    _assertSafeArguments(recovery.arguments);
    switch (recovery.id) {
      case RecoveryCommandId.retryMockServerSave:
      case RecoveryCommandId.retryMockServerStart:
      case RecoveryCommandId.retryMockServerStop:
        if (recovery.resourceRef?.kind != ResourceKind.mockServer) {
          throw ArgumentError.value(
            recovery.resourceRef,
            'recovery.resourceRef',
            'Mock Server recovery requires a Mock Server reference.',
          );
        }
      case RecoveryCommandId.retry:
      case RecoveryCommandId.retryExecution:
      case RecoveryCommandId.openResource:
      case RecoveryCommandId.openEnvironment:
      case RecoveryCommandId.copySafeError:
      case RecoveryCommandId.dismiss:
        break;
    }
  }
}

/// 持久化、未读去重与已读确认的通知边界。
abstract interface class UserNoticeRepository {
  Future<List<PersistentUserNotice>> listUnread();

  /// 相同 key 的未读记录必须合并为一条最新记录。
  Future<void> upsertUnread(PersistentUserNotice notice);

  Future<void> markRead(String deduplicationKey, DateTime readAt);

  /// 清空当前通知记录，不执行记录所引用的恢复命令或资源操作。
  Future<void> clearAll();

  /// 仅允许按保留策略删除已读或非操作记录。
  Future<void> prune(UserNoticeRetentionPolicy policy);
}
