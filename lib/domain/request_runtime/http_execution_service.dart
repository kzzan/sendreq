import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/request_runtime/request_execution_runtime.dart';

/// M3 HTTP 应用服务。它返回 Request 作用域的安全结果，传输细节封装在
/// [RequestExecutionRuntime] 之后。
class HttpExecutionService implements ExecutionService {
  factory HttpExecutionService({required RequestExecutionRuntime runtime}) =>
      HttpExecutionService._(runtime);

  HttpExecutionService._(this._runtime);

  final RequestExecutionRuntime _runtime;
  final Map<String, SanitizedExecutionResult> _terminalResults = {};

  @override
  Future<SanitizedExecutionResult> execute(
    ResolvedExecutionCommand command,
  ) async {
    final completed = _terminalResults[command.executionId];
    if (completed != null) return completed;

    final stopwatch = Stopwatch()..start();
    late final SanitizedExecutionResult result;
    try {
      final response = await _runtime.send(
        draft: command.payload.draft,
        resolvedUrl: command.payload.resolvedUrl,
      );
      stopwatch.stop();
      final snapshot = SanitizedResponseSnapshot(
        responseSnapshotId: 'response-${command.executionId}',
        executionId: command.executionId,
        statusCode: response.statusCode,
        summary: 'HTTP ${response.statusCode}',
        headers: {
          for (final header in response.headers)
            header.keyName: command.redactionPolicy.redact(header.value),
        },
        bodyPreview: command.redactionPolicy.redact(response.body),
      );
      result = SanitizedExecutionResult(
        executionId: command.executionId,
        requestRef: command.requestRef,
        status: OperationOutcomeKind.success,
        summary: snapshot.summary,
        responseSnapshot: snapshot,
        method: command.payload.method,
        displayPath: _displayPath(command),
        durationMs: response.timeMs,
        requestSnapshot: _requestSnapshot(command),
      );
    } on RuntimeRequestException catch (error) {
      stopwatch.stop();
      result = SanitizedExecutionResult(
        executionId: command.executionId,
        requestRef: command.requestRef,
        status: error.category == RuntimeErrorCategory.cancelled
            ? OperationOutcomeKind.cancelled
            : OperationOutcomeKind.failed,
        summary: command.redactionPolicy.redact(error.message),
        method: command.payload.method,
        displayPath: _displayPath(command),
        durationMs: stopwatch.elapsedMilliseconds,
        errorCategory: error.category.name,
        requestSnapshot: _requestSnapshot(command),
      );
    } on Object {
      stopwatch.stop();
      result = SanitizedExecutionResult(
        executionId: command.executionId,
        requestRef: command.requestRef,
        status: OperationOutcomeKind.failed,
        summary: 'Request failed.',
        method: command.payload.method,
        displayPath: _displayPath(command),
        durationMs: stopwatch.elapsedMilliseconds,
        errorCategory: RuntimeErrorCategory.unknown.name,
        requestSnapshot: _requestSnapshot(command),
      );
    }

    _terminalResults[command.executionId] = result;
    return result;
  }

  @override
  Future<OperationOutcome> cancel(String executionId) async {
    _runtime.cancel();
    return OperationOutcome(
      kind: OperationOutcomeKind.cancelled,
      code: 'execution.cancelRequested',
      resourceRef: ResourceRef(kind: ResourceKind.execution, id: executionId),
      relatedExecutionId: executionId,
    );
  }

  @override
  Future<void> disposeRequestSessions(RequestRef requestRef) async {}

  @override
  Future<SanitizedSessionProjection?> session(String sessionId) async => null;

  String _displayPath(ResolvedExecutionCommand command) {
    final uri = Uri.tryParse(command.payload.resolvedUrl);
    final path = uri == null ? command.payload.resolvedUrl : uri.path;
    return command.redactionPolicy.redact(path);
  }

  ExecutionRequestSnapshot _requestSnapshot(ResolvedExecutionCommand command) =>
      ExecutionRequestSnapshot(
        method: command.payload.method,
        resolvedUrl: command.redactionPolicy.redact(
          command.payload.resolvedUrl,
        ),
        headers: [
          for (final entry in command.payload.headers.entries)
            KeyValueRow(
              keyName: entry.key,
              value: command.redactionPolicy.redact(entry.value),
            ),
        ],
        body: command.redactionPolicy.redact(command.payload.body),
        environmentName:
            command.environmentName ??
            command.environmentRef?.id ??
            'Resolved environment',
      );
}
