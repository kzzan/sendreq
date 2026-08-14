import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/database/isar_workspace.dart';
import 'package:sendreq/data/database/isar_workspace_models.dart';
import 'package:sendreq/data/repositories/isar_mock_server_repository.dart';
import 'package:sendreq/data/repositories/workspace_document_keys.dart';
import 'package:sendreq/domain/contract_publishing/mock_server.dart';

import 'support/isar_test_core.dart';

void main() {
  setUpAll(initializeIsarForTest);

  test('restores saved Mock Servers in stable update order', () async {
    final directory = await Directory.systemTemp.createTemp('sendreq-mock-');
    addTearDown(() => directory.delete(recursive: true));
    final workspace = await IsarWorkspace.open(directory: directory);
    addTearDown(workspace.close);
    final repository = IsarMockServerRepository(workspace);

    await repository.save(_server('mock-a', DateTime.utc(2026, 8, 11)));
    await repository.save(_server('mock-b', DateTime.utc(2026, 8, 12)));

    final restored = await repository.list();
    expect(restored.map((server) => server.id), ['mock-b', 'mock-a']);
    expect(
      restored.first.endpoints.single.variants.single.body,
      '{"mock":"mock-b"}',
    );
  });

  test('keeps valid entries when one encoded Mock Server is malformed', () async {
    final directory = await Directory.systemTemp.createTemp('sendreq-mock-');
    addTearDown(() => directory.delete(recursive: true));
    final workspace = await IsarWorkspace.open(directory: directory);
    addTearDown(workspace.close);
    await workspace.instance.writeTxn(() async {
      final document = WorkspaceDocument()
        ..key = WorkspaceDocumentKeys.persistentMockServersV1
        ..schemaVersion = IsarWorkspace.currentDocumentSchemaVersion
        ..updatedAt = DateTime.utc(2026, 8, 11)
        ..payloadJson =
            '{"version":1,"servers":[{"id":"broken"},{"id":"mock-ok","name":"OK","lifecycle":"draft","createdAt":"2026-08-11T00:00:00.000Z","updatedAt":"2026-08-11T00:00:00.000Z","source":null,"endpoints":[{"id":"endpoint","enabled":true,"source":null,"matcher":{"method":"GET","path":"/ok","query":{},"headers":{},"bodyEquals":null},"variants":[{"id":"variant","statusCode":200,"headers":{},"body":"{}","delayMs":0,"enabled":true,"source":null,"matcher":{"headers":{},"bodyEquals":null}}]}]}]}';
      await workspace.instance.workspaceDocuments.put(document);
    });

    final restored = await IsarMockServerRepository(workspace).list();
    expect(restored.map((server) => server.id), ['mock-ok']);
  });

  test(
    'rejects over-budget writes without creating a partial document',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-mock-');
      addTearDown(() => directory.delete(recursive: true));
      final workspace = await IsarWorkspace.open(directory: directory);
      addTearDown(workspace.close);
      final repository = IsarMockServerRepository(workspace);
      final body = List.filled(
        IsarMockServerRepository.maxDocumentBytes,
        'x',
      ).join();
      final oversized = MockServer(
        id: 'oversized',
        name: 'oversized',
        createdAt: DateTime.utc(2026, 8, 11),
        updatedAt: DateTime.utc(2026, 8, 11),
        endpoints: [
          MockEndpoint(
            id: 'endpoint',
            matcher: MockRequestMatcher(method: 'GET', path: '/oversized'),
            variants: [
              MockResponseVariant(id: 'variant', statusCode: 200, body: body),
            ],
          ),
        ],
      );

      await expectLater(repository.save(oversized), throwsStateError);
      expect(await repository.list(), isEmpty);
    },
  );
}

MockServer _server(String id, DateTime updatedAt) => MockServer(
  id: id,
  name: id,
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: updatedAt,
  endpoints: [
    MockEndpoint(
      id: 'endpoint-$id',
      matcher: MockRequestMatcher(method: 'GET', path: '/$id'),
      variants: [
        MockResponseVariant(
          id: 'variant-$id',
          statusCode: 200,
          body: '{"mock":"$id"}',
        ),
      ],
    ),
  ],
);
