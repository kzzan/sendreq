import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/app/desktop_persistence_startup.dart';
import 'package:sendreq/data/database/isar_workspace.dart';
import 'package:sendreq/data/repositories/file_api_asset_repository.dart';
import 'package:sendreq/data/repositories/in_memory_environment_store.dart';
import 'package:sendreq/data/repositories/in_memory_workspace_preference_store.dart';
import 'package:sendreq/data/repositories/isar_api_asset_repository.dart';
import 'package:sendreq/data/repositories/isar_environment_store.dart';
import 'package:sendreq/data/repositories/isar_mock_server_repository.dart';
import 'package:sendreq/data/repositories/isar_user_notice_repository.dart';

import 'support/isar_test_core.dart';

void main() {
  setUpAll(initializeIsarForTest);

  test(
    'keeps legacy workspace files out of the active runtime when Isar fails',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-start-');
      addTearDown(() => directory.delete(recursive: true));
      final legacy = await FileApiAssetRepository.loadForMigration(
        configurationDirectory: directory,
      );
      final startup = _startup(
        loadLegacyAssets: () async => legacy,
        openWorkspace: () =>
            Future<IsarWorkspace>.error(StateError('database unavailable')),
      );

      final result = await startup.initialize();

      expect(result.requiresRecovery, isTrue);
      expect(
        result.stageStatuses[PersistenceStartupStage.workspace]?.succeeded,
        isFalse,
      );
      expect(
        result.workspaceDependencies.assetRepository.listCollections(),
        isEmpty,
      );
      expect(
        identical(result.workspaceDependencies.assetRepository, legacy),
        isFalse,
      );
    },
  );

  test(
    'invalid legacy JSON remains untouched and is reported for recovery',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sendreq-bad-json-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = File(
        '${directory.path}${Platform.pathSeparator}api-assets.json',
      );
      await source.writeAsString('{ invalid json');
      final startup = _startup(
        loadLegacyAssets: () => FileApiAssetRepository.loadForMigration(
          configurationDirectory: directory,
        ),
        openWorkspace: () => Future<IsarWorkspace>.error(
          StateError('must not open after invalid legacy source'),
        ),
      );

      final result = await startup.initialize();

      expect(result.requiresRecovery, isTrue);
      expect(await source.readAsString(), '{ invalid json');
      expect(
        result.workspaceDependencies.assetRepository.listCollections(),
        isEmpty,
      );
    },
  );

  test(
    'retry replaces fallback data with the completed Isar startup result',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-retry-');
      addTearDown(() => directory.delete(recursive: true));
      var attempts = 0;
      final startup = _startup(
        loadLegacyAssets: () => FileApiAssetRepository.loadForMigration(
          configurationDirectory: directory,
        ),
        openWorkspace: () async {
          attempts += 1;
          if (attempts == 1) {
            throw StateError('database temporarily unavailable');
          }
          return IsarWorkspace.open(directory: directory);
        },
      );
      final controller = await DesktopPersistenceStartupController.start(
        startup,
      );
      addTearDown(controller.dispose);

      expect(controller.result.requiresRecovery, isTrue);
      await controller.retry();

      expect(controller.isRetrying, isFalse);
      expect(controller.result.requiresRecovery, isFalse);
      expect(controller.result.workspace, isNotNull);
      expect(
        controller.result.workspaceDependencies.mockServerRepository,
        isA<IsarMockServerRepository>(),
      );
      expect(
        controller.result.workspaceDependencies.userNoticeRepository,
        isA<IsarUserNoticeRepository>(),
      );
    },
  );
}

DesktopPersistenceStartup _startup({
  required Future<FileApiAssetRepository> Function() loadLegacyAssets,
  required Future<IsarWorkspace> Function() openWorkspace,
}) => DesktopPersistenceStartup(
  createPreferenceStore: () async => InMemoryWorkspacePreferenceStore(),
  loadLegacyAssets: loadLegacyAssets,
  openWorkspace: openWorkspace,
  loadIsarAssets: (workspace, legacy) => IsarApiAssetRepository.load(
    workspace: workspace,
    legacyRepository: legacy,
  ),
  loadIsarEnvironmentStore: (workspace) =>
      IsarEnvironmentStore.load(workspace: workspace),
  loadEnvironmentStore: () async => InMemoryEnvironmentStore.sample(),
);
