import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/features/requests/collection/widgets/collection_resource_browser.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

import 'support/workspace_view_model_test_factory.dart';

void main() {
  test('deleting one group preserves its collection and sibling groups', () {
    final repository = InMemoryApiAssetRepository(
      collections: [_collection('primary'), _collection('secondary')],
      activeRequestId: 'primary-a-1',
    );
    final viewModel = workspaceViewModel(assetRepository: repository);
    addTearDown(viewModel.dispose);

    viewModel.deleteFolder(collectionId: 'primary', folderId: 'primary-a');

    expect(repository.listCollections().map((item) => item.id), [
      'primary',
      'secondary',
    ]);
    final primary = repository.listCollections().first;
    expect(primary.folders.map((item) => item.id), ['primary-b']);
    expect(primary.folders.single.requests, hasLength(2));
    expect(viewModel.activeRequest.id, 'primary-b-1');
  });

  test('deleting one request preserves its collection and group', () {
    final repository = InMemoryApiAssetRepository(
      collections: [_collection('primary'), _collection('secondary')],
      activeRequestId: 'primary-a-1',
    );
    final viewModel = workspaceViewModel(assetRepository: repository);
    addTearDown(viewModel.dispose);

    viewModel.deleteRequest('primary-a-1');

    final primary = repository.listCollections().first;
    expect(primary.id, 'primary');
    expect(primary.folders.map((item) => item.id), ['primary-a', 'primary-b']);
    expect(primary.folders.first.requests.map((item) => item.id), [
      'primary-a-2',
    ]);
    expect(viewModel.activeRequest.id, 'primary-a-2');
  });

  testWidgets('protocol filtering never hides collection or group containers', (
    tester,
  ) async {
    const collection = CollectionResource(
      id: 'collection',
      name: 'Visible collection',
      folders: [
        FolderResource(id: 'empty-group', name: 'Empty group', requests: []),
        FolderResource(
          id: 'websocket-group',
          name: 'WebSocket group',
          requests: [
            RequestResource(
              id: 'socket',
              method: 'WS',
              name: 'Socket request',
              path: '/socket',
              folder: 'WebSocket group',
              protocol: ApiRequestProtocol.webSocket,
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionResourceBrowser(
            collections: const [collection],
            activeRequestId: null,
            protocolFilter: ApiRequestProtocol.http,
            onToggleCollection: (_) {},
            onToggleFolder: (_) {},
            onSelectRequest: (_) {},
            onCollectionMenu: (_, _) {},
            onFolderMenu: (_, _, _) {},
            onRequestMenu: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('Visible collection'), findsOneWidget);
    expect(find.text('Empty group'), findsOneWidget);
    expect(find.text('WebSocket group'), findsOneWidget);
    expect(find.text('Socket request'), findsNothing);
  });
}

ApiCollection _collection(String id) => ApiCollection(
  id: id,
  name: '$id collection',
  folders: [
    _group(collectionId: id, id: '$id-a'),
    _group(collectionId: id, id: '$id-b'),
  ],
);

ApiFolder _group({required String collectionId, required String id}) =>
    ApiFolder(
      id: id,
      name: '$id group',
      requests: [
        _request(collectionId: collectionId, folderId: id, suffix: '1'),
        _request(collectionId: collectionId, folderId: id, suffix: '2'),
      ],
    );

ApiRequestDefinition _request({
  required String collectionId,
  required String folderId,
  required String suffix,
}) => ApiRequestDefinition(
  id: '$folderId-$suffix',
  collectionId: collectionId,
  folderId: folderId,
  name: '$folderId request $suffix',
  method: 'GET',
  urlTemplate: 'https://example.test/$folderId/$suffix',
  queryParams: const [],
  headers: const [],
  bodyTemplate: '',
);
