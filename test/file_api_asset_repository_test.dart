import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/file_api_asset_repository.dart';

void main() {
  test(
    'file API asset repository restores mutated assets and active tab',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sendreq-assets-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = await FileApiAssetRepository.load(
        configurationDirectory: directory,
      );

      final collection = repository.createCollection();
      final request = repository.createRequest(collectionId: collection.id);
      repository.renameRequest(request.id, 'Persisted request');
      repository.openRequestTab(request.id);
      await repository.flush();

      final restored = await FileApiAssetRepository.load(
        configurationDirectory: directory,
      );
      expect(restored.getRequest(request.id).name, 'Persisted request');
      expect(restored.activeRequestId, request.id);
      expect(
        restored.listOpenTabs().any((tab) => tab.requestId == request.id),
        isTrue,
      );
    },
  );

  test('file API asset repository falls back for malformed data', () async {
    final directory = await Directory.systemTemp.createTemp('sendreq-assets-');
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}/api-assets.json').writeAsString('not json');

    final repository = await FileApiAssetRepository.load(
      configurationDirectory: directory,
    );
    expect(repository.listRequests(), isNotEmpty);
  });
}
