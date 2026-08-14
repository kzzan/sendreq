import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';

import 'support/module_boundary_fakes.dart';

void main() {
  final requestRef = RequestRef(id: 'request-1', workspaceId: 'workspace-1');

  ResolvedExecutionCommand command(String executionId) =>
      ResolvedExecutionCommand(
        executionId: executionId,
        requestRef: requestRef,
        payload: ExecutionPayload(
          method: 'GET',
          resolvedUrl: 'https://api.example.test/private',
          draft: const RequestDraft(
            method: 'GET',
            baseUrlToken: 'https://api.example.test',
            path: '/private',
            params: [],
            headers: [],
            body: '',
          ),
          headers: const {'authorization': 'secret-token'},
        ),
        sanitizedRequestSummary: 'GET api.example.test/private',
        redactionPolicy: RedactionPolicy(const ['secret-token']),
      );

  SanitizedExecutionResult result(String executionId) =>
      SanitizedExecutionResult(
        executionId: executionId,
        requestRef: requestRef,
        status: OperationOutcomeKind.success,
        summary: '200 OK',
        responseSnapshot: SanitizedResponseSnapshot(
          responseSnapshotId: 'response-$executionId',
          executionId: executionId,
          statusCode: 200,
          summary: '200 OK',
          headers: const {'content-type': 'application/json'},
          bodyPreview: '{"ok":true}',
        ),
      );

  test('execution exposes only the sanitized current result', () async {
    final service = FakeExecutionService(result: result('execution-1'));

    final current = await service.execute(command('execution-1'));

    expect(service.commands, hasLength(1));
    expect(current.executionId, 'execution-1');
    expect(
      current.responseSnapshot!.headers,
      isNot(containsPair('authorization', anything)),
    );
  });

  test('recoverable failures carry data-only recovery commands', () {
    final outcome = OperationOutcome(
      kind: OperationOutcomeKind.failed,
      code: 'execution.failed',
      resourceRef: const ResourceRef(
        kind: ResourceKind.execution,
        id: 'execution-1',
      ),
      isRecoverable: true,
      recovery: RecoveryCommand(
        id: RecoveryCommandId.retryExecution,
        arguments: const {'attempt': '1'},
      ),
    );

    expect(outcome.recovery!.id, RecoveryCommandId.retryExecution);
    expect(outcome.recovery!.arguments, const {'attempt': '1'});
    expect(
      () => OperationOutcome(
        kind: OperationOutcomeKind.failed,
        code: 'execution.failed',
        isRecoverable: true,
      ),
      throwsArgumentError,
    );
  });

  test(
    'contract publishing accepts only the current sanitized HTTP snapshot',
    () async {
      final publishing = FakeContractPublishingService();
      final safeResponse = SanitizedResponseSnapshot(
        responseSnapshotId: 'response-1',
        executionId: 'execution-1',
        statusCode: 200,
        summary: '200 OK',
        headers: const {'content-type': 'application/json'},
        bodyPreview: '{"ok":true}',
      );

      final outcome = await publishing.createMockServerFromSnapshot(
        SanitizedMockSourceSnapshot(
          requestRef: requestRef,
          requestSummary: 'GET api.example.test/private',
          response: safeResponse,
        ),
      );

      expect(outcome.code, 'mockServer.created');
      expect(publishing.mockSnapshots, hasLength(1));
      expect(safeResponse.bodyPreview, '{"ok":true}');
    },
  );

  test(
    'environment resolution is explicit and cancellation stays on execution',
    () async {
      final resolver = FakeEnvironmentResolver(command('execution-2'));
      final resolved = await resolver.resolve(
        ResolveExecutionRequest(
          executionId: 'execution-2',
          requestRef: requestRef,
          draft: const RequestDraft(
            method: 'GET',
            baseUrlToken: 'https://api.example.test',
            path: '/private',
            params: [],
            headers: [],
            body: '',
          ),
        ),
      );
      final service = FakeExecutionService(result: result('execution-2'));

      final cancelled = await service.cancel(resolved.executionId);

      expect(resolver.requests.single.requestRef, requestRef);
      expect(cancelled.kind, OperationOutcomeKind.cancelled);
      expect(cancelled.relatedExecutionId, 'execution-2');
    },
  );
}
