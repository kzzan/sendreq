import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:sendreq/data/database/isar_workspace.dart';
import 'package:sendreq/data/database/isar_workspace_models.dart';

import 'support/isar_test_core.dart';

void main() {
  setUpAll(initializeIsarForTest);

  test('upgrades supported workspace documents in one transaction', () async {
    final directory = await Directory.systemTemp.createTemp('sendreq-isar-v1-');
    addTearDown(() => directory.delete(recursive: true));
    final initial = await IsarWorkspace.open(directory: directory);
    await initial.instance.writeTxn(() {
      final document = WorkspaceDocument()
        ..key = 'api-assets-v1'
        ..schemaVersion = 1
        ..payloadJson = '{"version":1,"collections":[],"openTabs":[]}'
        ..updatedAt = DateTime.utc(2026);
      return initial.instance.workspaceDocuments.put(document);
    });
    await initial.close();

    final upgraded = await IsarWorkspace.open(directory: directory);
    addTearDown(upgraded.close);
    final document = await upgraded.instance.workspaceDocuments.getByKey(
      'api-assets-v1',
    );

    expect(document?.schemaVersion, IsarWorkspace.currentDocumentSchemaVersion);
  });

  test(
    'rejects invalid migration input without overwriting the source document',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sendreq-isar-bad-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final initial = await IsarWorkspace.open(directory: directory);
      await initial.instance.writeTxn(() {
        final document = WorkspaceDocument()
          ..key = 'api-assets-v1'
          ..schemaVersion = 1
          ..payloadJson = 'not-json'
          ..updatedAt = DateTime.utc(2026);
        return initial.instance.workspaceDocuments.put(document);
      });
      await initial.close();

      expect(
        () => IsarWorkspace.open(directory: directory),
        throwsA(isA<IsarWorkspaceMigrationException>()),
      );

      final raw = await Isar.open(
        [WorkspaceDocumentSchema],
        directory: directory.path,
        name: 'sendreq_workspace',
      );
      addTearDown(raw.close);
      final document = await raw.workspaceDocuments.getByKey('api-assets-v1');
      expect(document?.schemaVersion, 1);
      expect(document?.payloadJson, 'not-json');
    },
  );
}
