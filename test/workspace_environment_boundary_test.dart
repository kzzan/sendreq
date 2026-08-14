import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

import 'support/module_boundary_fakes.dart';
import 'support/workspace_view_model_test_factory.dart';

void main() {
  test(
    'Workspace delegates HTTP resolution and consumes a sanitized port result',
    () async {
      const resolvedDraft = RequestDraft(
        method: 'GET',
        baseUrlToken: 'https://api.example.test',
        path: '/secret-token',
        params: [],
        headers: [],
        body: '',
      );
      final resolver = FakeEnvironmentResolver(
        ResolvedExecutionCommand(
          executionId: 'environment-owned-id',
          requestRef: const RequestRef(id: 'demo-rest-list-users'),
          payload: ExecutionPayload(
            method: 'GET',
            resolvedUrl: 'https://api.example.test/secret-token',
            draft: resolvedDraft,
          ),
          sanitizedRequestSummary: 'GET https://api.example.test/[redacted]',
          redactionPolicy: RedactionPolicy(const ['secret-token']),
        ),
      );
      final execution = FakeExecutionService(
        result: const SanitizedExecutionResult(
          executionId: 'environment-owned-id',
          requestRef: RequestRef(id: 'demo-rest-list-users'),
          status: OperationOutcomeKind.failed,
          summary: 'Connection rejected [redacted]',
          errorCategory: 'network',
        ),
      );
      final viewModel = workspaceViewModel(
        environmentResolver: resolver,
        executionService: execution,
      );

      await viewModel.sendActiveRequest();

      expect(resolver.requests, hasLength(1));
      expect(resolver.requests.single.requestRef.id, 'demo-rest-list-users');
      expect(execution.commands.single.payload.draft, same(resolvedDraft));
      expect(
        execution.commands.single.payload.resolvedUrl,
        'https://api.example.test/secret-token',
      );
      expect(viewModel.executionError, isNot(contains('secret-token')));
    },
  );

  test('Workspace retains only the active Request HTTP result', () async {
    final execution = FakeExecutionService(
      result: SanitizedExecutionResult(
        executionId: 'safe-execution',
        requestRef: const RequestRef(id: 'demo-rest-list-users'),
        status: OperationOutcomeKind.success,
        summary: '200 OK',
        method: 'GET',
        displayPath: '/users',
        durationMs: 1,
        requestSnapshot: const ExecutionRequestSnapshot(
          method: 'GET',
          resolvedUrl: 'https://api.example.test/users',
          headers: [],
          body: '',
          environmentName: 'Staging',
        ),
        responseSnapshot: SanitizedResponseSnapshot(
          responseSnapshotId: 'safe-response',
          executionId: 'safe-execution',
          statusCode: 200,
          summary: '200 OK',
        ),
      ),
    );
    final viewModel = workspaceViewModel(executionService: execution);

    await viewModel.sendActiveRequest();

    expect(viewModel.response?.statusCode, 200);
    expect(viewModel.canCreateMockFromResponse, isTrue);
  });
}
