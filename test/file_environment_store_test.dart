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

      store.setActiveEnvironment('reurl-production');
      store.updateVariable(id: 'reurl-token', value: 'test-persisted-token');
      store.updateVariable(id: 'reurl-ip', value: '8.8.8.8');
      store.updateActiveAuthentication(
        const RequestAuthentication.bearer('{{token}}'),
      );
      await store.saveChanges();

      final restored = await FileEnvironmentStore.load(
        configurationDirectory: directory,
      );
      expect(restored.activeEnvironment.id, 'reurl-production');
      expect(
        restored
            .resolveTemplate('https://example.test?ip={{ip}}')
            .executionValue,
        'https://example.test?ip=8.8.8.8',
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
    'malformed persisted environments fall back to safe sample data',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-env-');
      addTearDown(() => directory.delete(recursive: true));
      await File(
        '${directory.path}/environments.json',
      ).writeAsString('invalid');

      final store = await FileEnvironmentStore.load(
        configurationDirectory: directory,
      );

      expect(store.activeEnvironment.id, 'staging');
      expect(store.listEnvironments(), isNotEmpty);
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
