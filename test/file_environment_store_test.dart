import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/file_environment_store.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';

void main() {
  test(
    'saved environments survive a restart with variables and auth intact',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-env-');
      addTearDown(() => directory.delete(recursive: true));
      final store = await FileEnvironmentStore.load(
        configurationDirectory: directory,
      );

      final production = store.createEnvironment('Production');
      final baseUrl = store.listVariables().singleWhere(
        (variable) => variable.key == 'baseUrl',
      );
      store.updateVariable(id: baseUrl.id, value: 'https://api.example.test');
      store.updateActiveAuthentication(
        const RequestAuthentication.bearer('{{token}}'),
      );
      final token = store.listVariables().singleWhere(
        (variable) => variable.key == 'token',
      );
      store.updateVariable(id: token.id, value: 'test-persisted-token');
      await store.saveChanges();

      final restored = await FileEnvironmentStore.load(
        configurationDirectory: directory,
      );
      expect(restored.activeEnvironment.id, production.id);
      expect(
        restored.resolveTemplate('{{baseUrl}}').executionValue,
        'https://api.example.test',
      );
      expect(
        restored.resolveTemplate('Bearer {{token}}').executionValue,
        'Bearer test-persisted-token',
      );
      expect(restored.activeEnvironment.authentication.usesBearerToken, isTrue);
      expect(restored.hasUnsavedChanges, isFalse);
    },
  );

  test(
    'malformed persisted environments fall back to clean default data',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-env-');
      addTearDown(() => directory.delete(recursive: true));
      await File(
        '${directory.path}/environments.json',
      ).writeAsString('invalid');

      final store = await FileEnvironmentStore.load(
        configurationDirectory: directory,
      );

      expect(store.activeEnvironment.id, 'default');
      expect(store.listEnvironments(), hasLength(1));
      expect(
        store
            .listVariables()
            .singleWhere((item) => item.key == 'baseUrl')
            .displayValue,
        isEmpty,
      );
    },
  );

  test(
    'environment selection persists without committing configuration drafts',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-env-');
      addTearDown(() => directory.delete(recursive: true));
      final store = await FileEnvironmentStore.load(
        configurationDirectory: directory,
      );
      final defaultBaseUrl = store.listVariables().singleWhere(
        (variable) => variable.key == 'baseUrl',
      );
      final production = store.createEnvironment('Production');
      await store.saveChanges();
      await store.setActiveEnvironment('default');
      store.updateVariable(
        id: defaultBaseUrl.id,
        value: 'https://unsaved.test',
      );

      await store.setActiveEnvironment(production.id);

      final restored = await FileEnvironmentStore.load(
        configurationDirectory: directory,
      );
      expect(restored.activeEnvironment.id, production.id);
      await restored.setActiveEnvironment('default');
      expect(
        restored
            .listVariables()
            .singleWhere((item) => item.key == 'baseUrl')
            .displayValue,
        isEmpty,
      );
      expect(store.hasUnsavedChanges, isTrue);
    },
  );

  test(
    'strict environment migration leaves malformed JSON recoverable',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-env-');
      addTearDown(() => directory.delete(recursive: true));
      final source = File('${directory.path}/environments.json');
      await source.writeAsString('invalid');

      await expectLater(
        FileEnvironmentStore.loadForMigration(
          configurationDirectory: directory,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await source.readAsString(), 'invalid');
    },
  );
}
