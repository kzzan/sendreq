import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/database/isar_workspace.dart';
import 'package:sendreq/data/database/isar_workspace_models.dart';
import 'package:sendreq/data/repositories/file_environment_store.dart';
import 'package:sendreq/data/repositories/isar_environment_store.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';

import 'support/isar_test_core.dart';

void main() {
  setUpAll(initializeIsarForTest);

  test(
    'Isar environment store persists environment CRUD across restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sendreq-env-isar-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final firstWorkspace = await IsarWorkspace.open(directory: directory);
      final first = await IsarEnvironmentStore.load(workspace: firstWorkspace);

      final created = first.createEnvironment('Preview');
      final baseUrl = first.listVariables().firstWhere(
        (variable) => variable.key == 'baseUrl',
      );
      first.updateVariable(id: baseUrl.id, value: 'https://preview.test');
      first.updateActiveAuthentication(
        const RequestAuthentication.bearer('{{token}}'),
      );
      await first.saveChanges();
      await firstWorkspace.close();

      final restoredWorkspace = await IsarWorkspace.open(directory: directory);
      addTearDown(restoredWorkspace.close);
      final restored = await IsarEnvironmentStore.load(
        workspace: restoredWorkspace,
      );

      expect(restored.activeEnvironment.id, created.id);
      expect(
        restored.resolveTemplate('{{baseUrl}}').executionValue,
        'https://preview.test',
      );
      expect(restored.activeEnvironment.authentication.usesBearerToken, isTrue);
      expect(restored.hasUnsavedChanges, isFalse);
    },
  );

  test('Isar keeps environment values isolated after a restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sendreq-env-isolation-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final firstWorkspace = await IsarWorkspace.open(directory: directory);
    final first = await IsarEnvironmentStore.load(workspace: firstWorkspace);

    final staging = first.listVariables().singleWhere(
      (variable) => variable.id == 'staging-base-url',
    );
    first.updateVariable(id: staging.id, value: ' https://staging.isolated ');
    await first.setActiveEnvironment('production');
    final production = first.listVariables().singleWhere(
      (variable) => variable.id == 'production-base-url',
    );
    first.updateVariable(
      id: production.id,
      value: ' https://production.isolated ',
    );
    await first.saveChanges();
    await firstWorkspace.close();

    final restoredWorkspace = await IsarWorkspace.open(directory: directory);
    addTearDown(restoredWorkspace.close);
    final restored = await IsarEnvironmentStore.load(
      workspace: restoredWorkspace,
    );

    expect(
      restored.resolveTemplate('{{baseUrl}}').executionValue,
      'https://production.isolated',
    );
    await restored.setActiveEnvironment('staging');
    expect(
      restored.resolveTemplate('{{baseUrl}}').executionValue,
      'https://staging.isolated',
    );
  });

  test(
    'Isar persists selection without committing configuration drafts',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sendreq-env-selection-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final firstWorkspace = await IsarWorkspace.open(directory: directory);
      final first = await IsarEnvironmentStore.load(workspace: firstWorkspace);
      first.updateVariable(
        id: 'staging-base-url',
        value: 'https://unsaved.test',
      );
      await first.setActiveEnvironment('production');
      await firstWorkspace.close();

      final restoredWorkspace = await IsarWorkspace.open(directory: directory);
      addTearDown(restoredWorkspace.close);
      final restored = await IsarEnvironmentStore.load(
        workspace: restoredWorkspace,
      );
      expect(restored.activeEnvironment.id, 'production');
      await restored.setActiveEnvironment('staging');
      expect(
        restored.resolveTemplate('{{baseUrl}}').executionValue,
        'https://staging.sendreq.io',
      );
    },
  );

  test(
    'Isar environment store imports the legacy JSON once and keeps a backup',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sendreq-env-legacy-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final legacy = await FileEnvironmentStore.load(
        configurationDirectory: directory,
      );
      await legacy.setActiveEnvironment('reurl-production');
      legacy.updateVariable(id: 'reurl-ip', value: '8.8.8.8');
      await legacy.saveChanges();

      final workspace = await IsarWorkspace.open(directory: directory);
      addTearDown(workspace.close);
      final migrated = await IsarEnvironmentStore.load(
        workspace: workspace,
        legacyStore: legacy,
      );

      expect(migrated.activeEnvironment.id, 'reurl-production');
      expect(migrated.resolveTemplate('{{ip}}').executionValue, '8.8.8.8');
      expect(
        await directory.list().any((item) => item.path.endsWith('.bak')),
        isTrue,
      );
      expect(
        await workspace.instance.workspaceDocuments.getByKey('environments-v1'),
        isNotNull,
      );
    },
  );
}
