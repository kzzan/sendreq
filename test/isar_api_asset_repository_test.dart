import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/database/isar_workspace.dart';
import 'package:sendreq/data/repositories/isar_api_asset_repository.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';

import 'support/isar_test_core.dart';

void main() {
  setUpAll(initializeIsarForTest);

  test(
    'Isar repository restores assets, tabs and the active request',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-isar-');
      addTearDown(() => directory.delete(recursive: true));
      final firstWorkspace = await IsarWorkspace.open(directory: directory);
      final first = await IsarApiAssetRepository.load(
        workspace: firstWorkspace,
      );
      final collection = first.createCollection();
      final request = first.createRequest(collectionId: collection.id);
      first.renameRequest(request.id, 'Persisted through Isar');
      first.openRequestTab(request.id);
      await first.flush();
      await firstWorkspace.close();

      final secondWorkspace = await IsarWorkspace.open(directory: directory);
      addTearDown(secondWorkspace.close);
      final restored = await IsarApiAssetRepository.load(
        workspace: secondWorkspace,
      );

      expect(restored.getRequest(request.id).name, 'Persisted through Isar');
      expect(restored.activeRequestId, request.id);
      expect(
        restored.listOpenTabs().any((tab) => tab.requestId == request.id),
        isTrue,
      );
    },
  );

  test('Isar workspace restores the gRPC proto association', () async {
    final directory = await Directory.systemTemp.createTemp('sendreq-grpc-');
    addTearDown(() => directory.delete(recursive: true));
    final firstWorkspace = await IsarWorkspace.open(directory: directory);
    final first = await IsarApiAssetRepository.load(workspace: firstWorkspace);
    final collection = first.createCollection();
    final request = first.createRequest(collectionId: collection.id);
    first.updateRequest(
      request.copyWith(
        protocol: ApiRequestProtocol.grpc,
        grpc: const GrpcRequestConfiguration(
          protoSchema: ProtobufSchemaReference(
            path: '/tmp/health.proto',
            fingerprint: 'known-good',
          ),
          serviceName: '.sendreq.Health',
          methodName: 'Check',
          useTls: true,
        ),
      ),
    );
    await first.flush();
    await firstWorkspace.close();
    final restoredWorkspace = await IsarWorkspace.open(directory: directory);
    addTearDown(restoredWorkspace.close);
    final restored = await IsarApiAssetRepository.load(
      workspace: restoredWorkspace,
    );
    final grpc = restored.getRequest(request.id);
    expect(grpc.protocol, ApiRequestProtocol.grpc);
    expect(grpc.grpc.protoSchema?.fingerprint, 'known-good');
    expect(grpc.grpc.serviceName, '.sendreq.Health');
    expect(grpc.grpc.methodName, 'Check');
  });
}
