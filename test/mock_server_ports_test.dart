import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_mock_server_repository.dart';
import 'package:sendreq/domain/contract_publishing/mock_server.dart';
import 'package:sendreq/domain/contract_publishing/session_contract_publishing_service.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';

void main() {
  test(
    'Contract Publishing exposes persistent Mock commands by safe references',
    () async {
      final service = SessionContractPublishingService(
        mockServerRepository: InMemoryMockServerRepository(),
        mockServerRuntime: _StoppedMockServerRuntime(),
      );
      final server = MockServer(
        id: 'mock-1',
        name: 'Users',
        endpoints: [
          MockEndpoint(
            id: 'endpoint-1',
            matcher: MockRequestMatcher(method: 'GET', path: '/users'),
            variants: [MockResponseVariant(id: 'variant-1', statusCode: 200)],
          ),
        ],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      final save = await service.saveMockServer(server);

      expect(ResourceKind.mockServer.name, 'mockServer');
      expect(RecoveryCommandId.retryMockServerSave.name, 'retryMockServerSave');
      expect(service.mockServers.single.server, same(server));
      expect(save.kind, OperationOutcomeKind.success);
      expect(save.code, 'mockServer.saved');
      expect(
        save.resourceRef,
        const ResourceRef(kind: ResourceKind.mockServer, id: 'mock-1'),
      );
    },
  );
}

class _StoppedMockServerRuntime implements MockServerRuntimePort {
  @override
  void apply(MockServer server) {}

  @override
  Future<void> dispose() async {}

  @override
  MockServerRuntimeProjection projectionFor(String mockServerId) =>
      const MockServerRuntimeProjection(
        status: MockServerRuntimeStatus.stopped,
      );

  @override
  Future<MockServerRuntimeProjection> start(MockServer server) async =>
      projectionFor(server.id);

  @override
  Future<void> stop(String mockServerId) async {}
}
