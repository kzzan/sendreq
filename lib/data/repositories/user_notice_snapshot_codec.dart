import 'dart:convert';

import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/notifications/user_notice_repository.dart';

/// `user-notices-v1` 的当前唯一 JSON 格式。
abstract final class UserNoticeSnapshotCodec {
  static const version = 1;

  static String encodeDocument(Iterable<PersistentUserNotice> notices) =>
      jsonEncode({
        'version': version,
        'notices': [for (final notice in notices) _notice(notice)],
      });

  static List<PersistentUserNotice> decodeDocument(String source) {
    final root = Map<String, dynamic>.from(jsonDecode(source) as Map);
    if (root['version'] != version || root['notices'] is! List) {
      throw const FormatException('Unsupported user notice snapshot.');
    }
    final notices = <PersistentUserNotice>[];
    for (final notice in root['notices'] as List) {
      try {
        notices.add(_decodeNotice(Map<String, dynamic>.from(notice as Map)));
      } on Object {
        // 单条损坏通知不会阻止其它可恢复通知被显示。
      }
    }
    return notices;
  }

  static Map<String, Object?> _notice(PersistentUserNotice value) => {
    'deduplicationKey': value.deduplicationKey,
    'code': value.code,
    'severity': value.severity.name,
    'createdAt': value.createdAt.toUtc().toIso8601String(),
    'updatedAt': value.updatedAt.toUtc().toIso8601String(),
    'readAt': value.readAt?.toUtc().toIso8601String(),
    'arguments': value.arguments,
    'resource': _resource(value.resourceRef),
    'recovery': value.recovery == null
        ? null
        : {
            'id': value.recovery!.id.name,
            'arguments': value.recovery!.arguments,
            'resource': _resource(value.recovery!.resourceRef),
          },
  };

  static PersistentUserNotice _decodeNotice(Map<String, dynamic> value) {
    final recovery = value['recovery'];
    final recoveryValue = recovery == null
        ? null
        : Map<String, dynamic>.from(recovery as Map);
    return PersistentUserNotice(
      deduplicationKey: value['deduplicationKey'] as String,
      code: value['code'] as String,
      severity: DurableNoticeSeverity.values.byName(
        value['severity'] as String,
      ),
      createdAt: DateTime.parse(value['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(value['updatedAt'] as String).toUtc(),
      readAt: value['readAt'] == null
          ? null
          : DateTime.parse(value['readAt'] as String).toUtc(),
      arguments: _strings(value['arguments']),
      resourceRef: _decodeResource(value['resource']),
      recovery: recoveryValue == null
          ? null
          : RecoveryCommand(
              id: RecoveryCommandId.values.byName(
                recoveryValue['id'] as String,
              ),
              arguments: _strings(recoveryValue['arguments']),
              resourceRef: _decodeResource(recoveryValue['resource']),
            ),
    );
  }

  static Map<String, Object?>? _resource(ResourceRef? value) =>
      value == null ? null : {'kind': value.kind.name, 'id': value.id};

  static ResourceRef? _decodeResource(Object? source) {
    if (source == null) return null;
    final value = Map<String, dynamic>.from(source as Map);
    return ResourceRef(
      kind: ResourceKind.values.byName(value['kind'] as String),
      id: value['id'] as String,
    );
  }

  static Map<String, String> _strings(Object? value) => {
    for (final entry in Map<String, dynamic>.from(
      value as Map? ?? const {},
    ).entries)
      entry.key: entry.value as String,
  };
}
