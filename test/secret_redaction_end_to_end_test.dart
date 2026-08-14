import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_environment_store.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/request_runtime/request_execution_runtime.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

import 'support/workspace_view_model_test_factory.dart';

void main() {
  test(
    'environment secrets are redacted in the current response and Mock',
    () async {
      const secret = 'e2e-secret-token';
      final environments = InMemoryEnvironmentStore.sample();
      environments.updateVariable(id: 'staging-token', value: secret);
      final viewModel = workspaceViewModel(
        environmentStore: environments,
        executionRuntime: _EchoSecretRuntime(secret),
      );
      addTearDown(viewModel.dispose);

      await viewModel.sendActiveRequest();
      expect(viewModel.response!.body, contains('[redacted]'));
      expect(viewModel.response!.body, isNot(contains(secret)));

      viewModel.createMockServerFromResponse();
      await Future<void>.delayed(Duration.zero);
      final mock = viewModel.savedMockServers.single.server;
      final response = mock.endpoints.single.variants.single;
      expect(response.body, contains('[redacted]'));
      expect(response.body, isNot(contains(secret)));
      expect(response.headers.values.join(' '), isNot(contains(secret)));
    },
  );
}

class _EchoSecretRuntime implements RequestExecutionRuntime {
  const _EchoSecretRuntime(this.secret);

  final String secret;

  @override
  void cancel() {}

  @override
  Future<RuntimeResponse> send({
    required RequestDraft draft,
    required String resolvedUrl,
  }) async => RuntimeResponse(
    statusCode: 200,
    timeMs: 1,
    sizeKb: 0.1,
    body: '{"token":"$secret"}',
    headers: [KeyValueRow(keyName: 'x-token', value: secret)],
  );
}
