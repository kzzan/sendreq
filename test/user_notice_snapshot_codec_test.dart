import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/user_notice_snapshot_codec.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/notifications/user_notice_repository.dart';

void main() {
  test('round-trips safe durable notices and data-only recovery commands', () {
    final notice = PersistentUserNotice(
      deduplicationKey: 'mock-start:mock-1',
      code: 'mockServer.startFailed',
      severity: DurableNoticeSeverity.error,
      createdAt: DateTime.utc(2026, 8, 11),
      updatedAt: DateTime.utc(2026, 8, 11, 1),
      resourceRef: const ResourceRef(
        kind: ResourceKind.mockServer,
        id: 'mock-1',
      ),
      arguments: const {'reason': 'portUnavailable'},
      recovery: RecoveryCommand(
        id: RecoveryCommandId.retryMockServerStart,
        resourceRef: const ResourceRef(
          kind: ResourceKind.mockServer,
          id: 'mock-1',
        ),
      ),
    );

    final payload = UserNoticeSnapshotCodec.encodeDocument([notice]);
    final restored = UserNoticeSnapshotCodec.decodeDocument(payload).single;

    expect(restored.deduplicationKey, notice.deduplicationKey);
    expect(restored.recovery!.id, RecoveryCommandId.retryMockServerStart);
    expect(payload, isNot(contains('callback')));
    expect(payload, isNot(contains('://')));
  });
}
