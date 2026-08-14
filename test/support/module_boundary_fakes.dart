import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';

class FakeEnvironmentResolver implements EnvironmentResolver {
  FakeEnvironmentResolver(this.command);

  ResolvedExecutionCommand command;
  final List<ResolveExecutionRequest> requests = [];

  @override
  Future<ResolvedExecutionCommand> resolve(
    ResolveExecutionRequest request,
  ) async {
    requests.add(request);
    return command;
  }
}

class FakeExecutionService implements ExecutionService {
  FakeExecutionService({required this.result});

  SanitizedExecutionResult result;
  final List<ResolvedExecutionCommand> commands = [];
  final List<RequestRef> disposedRequests = [];

  @override
  Future<SanitizedExecutionResult> execute(
    ResolvedExecutionCommand command,
  ) async {
    commands.add(command);
    return result;
  }

  @override
  Future<OperationOutcome> cancel(String executionId) async => OperationOutcome(
    kind: OperationOutcomeKind.cancelled,
    code: 'execution.cancelled',
    relatedExecutionId: executionId,
  );

  @override
  Future<void> disposeRequestSessions(RequestRef requestRef) async {
    disposedRequests.add(requestRef);
  }

  @override
  Future<SanitizedSessionProjection?> session(String sessionId) async => null;
}

class FakeContractPublishingService implements ContractPublishingService {
  final List<MockServerProjection> mockServerProjections = [];
  final List<SanitizedMockSourceSnapshot> mockSnapshots = [];

  @override
  Future<OperationOutcome> createMockServerFromSnapshot(
    SanitizedMockSourceSnapshot snapshot,
  ) async {
    mockSnapshots.add(snapshot);
    return OperationOutcome(
      kind: OperationOutcomeKind.success,
      code: 'mockServer.created',
      resourceRef: const ResourceRef(
        kind: ResourceKind.mockServer,
        id: 'mock-1',
      ),
    );
  }

  @override
  List<MockServerProjection> get mockServers => mockServerProjections;

  @override
  Future<OperationOutcome> archiveMockServer(ResourceRef mockServerRef) async =>
      _mockServerOutcome('mockServer.archived', mockServerRef);

  @override
  Future<OperationOutcome> deleteMockServer(ResourceRef mockServerRef) async =>
      _mockServerOutcome('mockServer.deleted', mockServerRef);

  @override
  Future<OperationOutcome> loadMockServers() async => OperationOutcome(
    kind: OperationOutcomeKind.success,
    code: 'mockServer.loaded',
  );

  @override
  Future<OperationOutcome> saveMockServer(MockServer server) async =>
      _mockServerOutcome(
        'mockServer.saved',
        ResourceRef(kind: ResourceKind.mockServer, id: server.id),
      );

  @override
  Future<OperationOutcome> startMockServer(ResourceRef mockServerRef) async =>
      _mockServerOutcome('mockServer.started', mockServerRef);

  @override
  Future<OperationOutcome> stopMockServer(ResourceRef mockServerRef) async =>
      _mockServerOutcome('mockServer.stopped', mockServerRef);

  @override
  Future<void> disposeSession() async {}

  OperationOutcome _mockServerOutcome(String code, ResourceRef ref) =>
      OperationOutcome(
        kind: OperationOutcomeKind.success,
        code: code,
        resourceRef: ref,
      );
}
