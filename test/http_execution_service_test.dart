import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/request_runtime/http_execution_service.dart';
import 'package:sendreq/domain/request_runtime/request_execution_runtime.dart';

void main() {
  ResolvedExecutionCommand command(String id) => ResolvedExecutionCommand(
    executionId: id,
    requestRef: const RequestRef(id: 'request-1'),
    payload: ExecutionPayload(
      method: 'GET',
      resolvedUrl: 'https://api.example.test/private/secret-value',
      draft: const RequestDraft(
        method: 'GET',
        baseUrlToken: 'https://api.example.test',
        path: '/private/secret-value',
        params: [],
        headers: [],
        body: '',
      ),
    ),
    sanitizedRequestSummary: 'GET https://api.example.test/private/[redacted]',
    redactionPolicy: RedactionPolicy(const ['secret-value']),
  );

  test('executes once per id and returns a redacted current result', () async {
    final runtime = _Runtime(
      response: const RuntimeResponse(
        statusCode: 200,
        timeMs: 13,
        sizeKb: 0.1,
        body: '{"token":"secret-value"}',
        headers: [KeyValueRow(keyName: 'x-token', value: 'secret-value')],
      ),
    );
    final service = HttpExecutionService(runtime: runtime);

    final first = await service.execute(command('execution-1'));
    final second = await service.execute(command('execution-1'));

    expect(runtime.sendCount, 1);
    expect(first, same(second));
    expect(
      first.responseSnapshot!.bodyPreview,
      isNot(contains('secret-value')),
    );
    expect(first.responseSnapshot!.headers['x-token'], '[redacted]');
    expect(first.displayPath, isNot(contains('secret-value')));
  });

  test(
    'redacts runtime errors and cancellation remains on the execution port',
    () async {
      final runtime = _Runtime(
        error: const RuntimeRequestException(
          RuntimeErrorCategory.network,
          'Could not reach secret-value',
        ),
      );
      final service = HttpExecutionService(runtime: runtime);

      final result = await service.execute(command('execution-2'));
      final cancellation = await service.cancel('execution-2');

      expect(result.status, OperationOutcomeKind.failed);
      expect(result.summary, isNot(contains('secret-value')));
      expect(result.errorCategory, RuntimeErrorCategory.network.name);
      expect(runtime.cancelled, isTrue);
      expect(cancellation.code, 'execution.cancelRequested');
    },
  );
}

class _Runtime implements RequestExecutionRuntime {
  _Runtime({this.response, this.error});

  final RuntimeResponse? response;
  final RuntimeRequestException? error;
  int sendCount = 0;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  Future<RuntimeResponse> send({
    required RequestDraft draft,
    required String resolvedUrl,
  }) async {
    sendCount += 1;
    if (error != null) throw error!;
    return response!;
  }
}
