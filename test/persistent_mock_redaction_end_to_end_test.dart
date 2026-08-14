import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/database/isar_workspace.dart';
import 'package:sendreq/data/database/isar_workspace_models.dart';
import 'package:sendreq/data/repositories/in_memory_environment_store.dart';
import 'package:sendreq/data/repositories/isar_mock_server_repository.dart';
import 'package:sendreq/data/repositories/isar_user_notice_repository.dart';
import 'package:sendreq/data/repositories/workspace_document_keys.dart';
import 'package:sendreq/domain/contract_publishing/mock_server.dart';
import 'package:sendreq/domain/contract_publishing/session_contract_publishing_service.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/request_runtime/request_execution_runtime.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

import 'support/isar_test_core.dart';
import 'support/workspace_view_model_test_factory.dart';

void main() {
  setUpAll(initializeIsarForTest);

  test(
    'response-derived Mock and durable notice stay redacted after restart',
    () async {
      const secret = 'e2e-secret-token';
      final directory = await Directory.systemTemp.createTemp('sendreq-e2e-');
      addTearDown(() => directory.delete(recursive: true));
      final workspace = await IsarWorkspace.open(directory: directory);
      addTearDown(workspace.close);
      final mockRepository = IsarMockServerRepository(workspace);
      final noticeRepository = IsarUserNoticeRepository(workspace);
      final environments = InMemoryEnvironmentStore.sample();
      environments.updateVariable(id: 'staging-token', value: secret);

      final initial = workspaceViewModel(
        environmentStore: environments,
        executionRuntime: _EchoSecretRuntime(secret),
        mockServerRepository: mockRepository,
        userNoticeRepository: noticeRepository,
        contractPublishingService: _contractPublishing(
          mockRepository,
          _FailingMockServerRuntime(),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      await initial.sendActiveRequest();
      initial.createMockServerFromResponse();
      await _waitForMockServer(initial);
      final savedServer = initial.savedMockServers.single.server;
      await initial.startSavedMockServer(
        ResourceRef(kind: ResourceKind.mockServer, id: savedServer.id),
      );

      expect(
        initial
            .savedMockServers
            .single
            .server
            .endpoints
            .single
            .variants
            .single
            .body,
        contains('[redacted]'),
      );
      expect(initial.actionableNotices.single.recovery, isNotNull);
      initial.dispose();
      await Future<void>.delayed(Duration.zero);

      final restored = workspaceViewModel(
        environmentStore: environments,
        mockServerRepository: mockRepository,
        userNoticeRepository: noticeRepository,
        contractPublishingService: _contractPublishing(
          mockRepository,
          _FailingMockServerRuntime(),
        ),
      );
      addTearDown(restored.dispose);
      await _waitForRestore(restored);

      final restoredMock = restored.savedMockServers.single.server;
      expect(
        restoredMock.endpoints.single.variants.single.body,
        contains('[redacted]'),
      );
      expect(
        restoredMock.endpoints.single.variants.single.body,
        isNot(contains(secret)),
      );
      expect(restored.actionableNotices, hasLength(1));
      expect(restored.actionableNotices.single.recovery, isNotNull);

      for (final key in [
        WorkspaceDocumentKeys.persistentMockServersV1,
        WorkspaceDocumentKeys.userNoticesV1,
      ]) {
        final document = await workspace.instance.workspaceDocuments.getByKey(
          key,
        );
        expect(document, isNotNull);
        expect(document!.payloadJson, isNot(contains(secret)));
      }
    },
  );
}

Future<void> _waitForRestore(WorkspaceViewModel viewModel) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (viewModel.savedMockServers.isNotEmpty &&
        viewModel.actionableNotices.isNotEmpty) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out while restoring persisted Mock Servers and notices.');
}

Future<void> _waitForMockServer(WorkspaceViewModel viewModel) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (viewModel.savedMockServers.isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out while creating the saved Mock Server.');
}

SessionContractPublishingService _contractPublishing(
  IsarMockServerRepository repository,
  MockServerRuntimePort runtime,
) => SessionContractPublishingService(
  mockServerRepository: repository,
  mockServerRuntime: runtime,
  createMockServerId: () => 'redacted-mock',
);

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

class _FailingMockServerRuntime implements MockServerRuntimePort {
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
  Future<MockServerRuntimeProjection> start(MockServer server) =>
      Future.error(StateError('loopback bind unavailable'));

  @override
  Future<void> stop(String mockServerId) async {}
}
