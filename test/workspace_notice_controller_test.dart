import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_user_notice_repository.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/ui/core/application/user_message.dart';
import 'package:sendreq/ui/shell/application/user_notice.dart';

void main() {
  final now = DateTime.utc(2026, 8, 11, 9);
  final request = const ResourceRef(
    kind: ResourceKind.request,
    id: 'request-1',
  );

  WorkspaceNoticeController controller() =>
      WorkspaceNoticeController(clock: () => now);

  test('coalesces repeated non-actionable session notices by typed key', () {
    final notices = controller();
    final projection = SanitizedSessionProjection(
      sessionId: 'session-1',
      requestRef: const RequestRef(id: 'request-1'),
      status: 'reconnecting',
      summary: 'Attempt 1',
    );

    notices.recordSessionProjection(projection);
    notices.recordSessionProjection(
      SanitizedSessionProjection(
        sessionId: projection.sessionId,
        requestRef: projection.requestRef,
        status: projection.status,
        summary: 'Attempt 2',
      ),
    );

    expect(notices.queue.notices, hasLength(1));
    expect(notices.queue.notices.single.arguments['summary'], 'Attempt 2');
  });

  test('actionable failures remain until resolved', () {
    final notices = controller();
    notices.recordOutcome(
      OperationOutcome(
        kind: OperationOutcomeKind.failed,
        code: 'execution.failed',
        resourceRef: request,
        isRecoverable: true,
        recovery: RecoveryCommand(id: RecoveryCommandId.retryExecution),
      ),
    );

    final notice = notices.queue.notices.single;
    expect(notice.expiry, NoticeExpiry.untilResolved);
    notices.queue.resolve(notice.deduplicationKey);
    expect(notices.queue.notices, isEmpty);
  });

  test('coalesces repeated safe session messages with a stable key', () {
    final notices = controller();

    notices.recordSessionMessage(
      UserMessage(message: 'Copied.', severity: UserMessageSeverity.success),
    );
    notices.recordSessionMessage(
      UserMessage(message: 'Copied.', severity: UserMessageSeverity.success),
    );

    expect(notices.queue.notices, hasLength(1));
    expect(notices.queue.notices.single.message, 'Copied.');
    expect(
      notices.queue.notices.single.deduplicationKey,
      startsWith('message:success:'),
    );
  });

  test('records a concrete success without persisting it', () async {
    final repository = InMemoryUserNoticeRepository();
    final notices = WorkspaceNoticeController(
      clock: () => now,
      repository: repository,
    );

    await notices.recordOutcome(
      OperationOutcome(
        kind: OperationOutcomeKind.success,
        code: 'mockServer.saved',
      ),
      message: 'Mock Server saved.',
    );

    expect(notices.queue.notices, hasLength(1));
    expect(notices.queue.notices.single.message, 'Mock Server saved.');
    expect(await repository.listUnread(), isEmpty);
  });

  test(
    'persists actionable outcomes while retaining immediate feedback',
    () async {
      final repository = InMemoryUserNoticeRepository();
      final notices = WorkspaceNoticeController(
        clock: () => now,
        repository: repository,
      );
      final outcome = OperationOutcome(
        kind: OperationOutcomeKind.failed,
        code: 'mockServer.startFailed',
        resourceRef: const ResourceRef(
          kind: ResourceKind.mockServer,
          id: 'mock-1',
        ),
        isRecoverable: true,
        recovery: RecoveryCommand(
          id: RecoveryCommandId.retryMockServerStart,
          resourceRef: const ResourceRef(
            kind: ResourceKind.mockServer,
            id: 'mock-1',
          ),
        ),
      );

      await notices.recordOutcome(outcome);

      expect(notices.queue.notices, hasLength(1));
      final persisted = await repository.listUnread();
      expect(persisted, hasLength(1));
      expect(persisted.single.code, 'mockServer.startFailed');
      expect(
        persisted.single.recovery!.id,
        RecoveryCommandId.retryMockServerStart,
      );

      await notices.acknowledge(persisted.single.deduplicationKey);
      expect(notices.queue.notices, isEmpty);
      expect(await repository.listUnread(), isEmpty);
    },
  );

  test(
    'deduplicates repeated Mock start failures in durable storage',
    () async {
      final repository = InMemoryUserNoticeRepository();
      final notices = WorkspaceNoticeController(
        clock: () => now,
        repository: repository,
      );
      final outcome = OperationOutcome(
        kind: OperationOutcomeKind.failed,
        code: 'mockServer.startFailed',
        resourceRef: const ResourceRef(
          kind: ResourceKind.mockServer,
          id: 'mock-1',
        ),
        isRecoverable: true,
        recovery: RecoveryCommand(
          id: RecoveryCommandId.retryMockServerStart,
          resourceRef: const ResourceRef(
            kind: ResourceKind.mockServer,
            id: 'mock-1',
          ),
        ),
      );

      await notices.recordOutcome(outcome);
      await notices.recordOutcome(outcome);

      final persisted = await repository.listUnread();
      expect(persisted, hasLength(1));
      expect(persisted.single.arguments, isEmpty);
      expect(persisted.single.recovery!.resourceRef!.id, 'mock-1');
    },
  );

  test(
    'restores unread durable notices and does not persist ordinary success',
    () async {
      final repository = InMemoryUserNoticeRepository();
      final original = WorkspaceNoticeController(
        clock: () => now,
        repository: repository,
      );
      await original.recordOutcome(
        OperationOutcome(
          kind: OperationOutcomeKind.partial,
          code: 'mockServer.savePartial',
          resourceRef: const ResourceRef(
            kind: ResourceKind.mockServer,
            id: 'mock-2',
          ),
          isRecoverable: true,
          recovery: RecoveryCommand(
            id: RecoveryCommandId.retryMockServerSave,
            resourceRef: const ResourceRef(
              kind: ResourceKind.mockServer,
              id: 'mock-2',
            ),
          ),
        ),
      );
      await original.recordOutcome(
        OperationOutcome(
          kind: OperationOutcomeKind.success,
          code: 'mockServer.saved',
        ),
      );
      final restored = WorkspaceNoticeController(
        clock: () => now.add(const Duration(minutes: 1)),
        repository: repository,
      );

      await restored.restoreUnread();

      expect(restored.queue.notices, hasLength(1));
      expect(
        restored.queue.notices.single.code,
        NoticeCode.operationPartiallyCompleted,
      );
      expect(
        restored.queue.notices.single.recovery!.id,
        RecoveryCommandId.retryMockServerSave,
      );
      expect(await repository.listUnread(), hasLength(1));
    },
  );

  test(
    'automatic notices expire while acknowledgement clears persistent notices',
    () {
      final queue = WorkspaceNoticeQueue(
        clock: () => now.add(const Duration(seconds: 7)),
      );
      queue.push(
        UserNotice(
          code: NoticeCode.operationSucceeded,
          severity: NoticeSeverity.success,
          deduplicationKey: 'success',
          createdAt: now,
          expiry: NoticeExpiry.automatic,
        ),
      );
      queue.push(
        UserNotice(
          code: NoticeCode.operationFailed,
          severity: NoticeSeverity.error,
          deduplicationKey: 'failed',
          createdAt: now,
          expiry: NoticeExpiry.untilAcknowledged,
        ),
      );

      queue.expireAutomatic();
      expect(queue.notices.map((notice) => notice.deduplicationKey), [
        'failed',
      ]);
      queue.acknowledge('failed');
      expect(queue.notices, isEmpty);
    },
  );

  test('clears durable and visible notices together', () async {
    final repository = InMemoryUserNoticeRepository();
    final notices = WorkspaceNoticeController(
      clock: () => now,
      repository: repository,
    );
    await notices.recordOutcome(
      OperationOutcome(
        kind: OperationOutcomeKind.failed,
        code: 'mockServer.startFailed',
        resourceRef: const ResourceRef(
          kind: ResourceKind.mockServer,
          id: 'mock-1',
        ),
      ),
    );

    expect(await notices.clearAll(), isTrue);
    expect(notices.queue.notices, isEmpty);
    expect(await repository.listUnread(), isEmpty);
  });

  test(
    'rejects secret-bearing notice arguments and never maps cancelled outcomes',
    () {
      expect(
        () => UserNotice(
          code: NoticeCode.operationFailed,
          severity: NoticeSeverity.error,
          deduplicationKey: 'unsafe',
          createdAt: now,
          expiry: NoticeExpiry.untilAcknowledged,
          arguments: const {'authorizationHeader': 'value'},
        ),
        throwsArgumentError,
      );

      final notices = controller();
      notices.recordOutcome(
        OperationOutcome(
          kind: OperationOutcomeKind.cancelled,
          code: 'execution.cancelled',
        ),
      );
      expect(notices.queue.notices, isEmpty);
    },
  );

  test('dispatcher records every non-cancelled operation outcome', () async {
    final repository = InMemoryUserNoticeRepository();
    final notices = WorkspaceNoticeController(
      clock: () => now,
      repository: repository,
    );
    final dispatcher = WorkspaceFeedbackDispatcher(notices);

    await dispatcher.dispatchOutcome(
      OperationOutcome(
        kind: OperationOutcomeKind.failed,
        code: 'request.invalidUrl',
        resourceRef: request,
      ),
      message: 'Could not send request.',
    );

    expect(notices.queue.notices, hasLength(1));
    expect(notices.queue.notices.single.message, 'Could not send request.');
    expect(await repository.listUnread(), hasLength(1));
  });

  test(
    'dispatcher admits durable failures and ignores cancelled outcomes',
    () async {
      final repository = InMemoryUserNoticeRepository();
      final notices = WorkspaceNoticeController(
        clock: () => now,
        repository: repository,
      );
      final dispatcher = WorkspaceFeedbackDispatcher(notices);
      final failed = OperationOutcome(
        kind: OperationOutcomeKind.failed,
        code: 'environment.saveFailed',
        resourceRef: const ResourceRef(
          kind: ResourceKind.environment,
          id: 'environment-1',
        ),
      );

      await dispatcher.dispatchOutcome(failed);
      await dispatcher.dispatchOutcome(
        OperationOutcome(
          kind: OperationOutcomeKind.cancelled,
          code: 'execution.cancelled',
        ),
      );

      expect(notices.queue.notices, hasLength(1));
      expect(await repository.listUnread(), hasLength(1));
    },
  );
}
