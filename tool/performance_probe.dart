import 'dart:io';

import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';

const _collectionCount = 50;
const _foldersPerCollection = 10;
const _requestsPerFolder = 20;
const _readIterations = 100000;

void main() {
  final buildWatch = Stopwatch()..start();
  final repository = InMemoryApiAssetRepository(collections: _fixture());
  buildWatch.stop();

  final coldReadWatch = Stopwatch()..start();
  final collections = repository.listCollections();
  final requests = repository.listRequests();
  coldReadWatch.stop();

  final cachedReadWatch = Stopwatch()..start();
  var checksum = 0;
  for (var index = 0; index < _readIterations; index++) {
    checksum += repository.listCollections().length;
    checksum += repository.listRequests().length;
  }
  cachedReadWatch.stop();

  final lookupWatch = Stopwatch()..start();
  for (var index = 0; index < _readIterations; index++) {
    checksum += repository.getRequest('request-49-9-19').name.length;
  }
  lookupWatch.stop();

  if (!identical(collections, repository.listCollections()) ||
      !identical(requests, repository.listRequests())) {
    throw StateError('Warm repository reads did not reuse cached snapshots.');
  }

  final original = repository.getRequest('request-49-9-19');
  repository.updateRequest(original.copyWith(name: 'Updated request'));
  final invalidationWatch = Stopwatch()..start();
  final rebuiltCollections = repository.listCollections();
  final rebuiltRequests = repository.listRequests();
  invalidationWatch.stop();

  if (identical(collections, rebuiltCollections) ||
      identical(requests, rebuiltRequests) ||
      repository.getRequest(original.id).name != 'Updated request') {
    throw StateError('Mutation did not invalidate and rebuild snapshots.');
  }

  stdout
    ..writeln('sendreq API asset performance probe')
    ..writeln('collections: $_collectionCount')
    ..writeln(
      'requests: ${_collectionCount * _foldersPerCollection * _requestsPerFolder}',
    )
    ..writeln('fixture construction: ${buildWatch.elapsedMicroseconds} us')
    ..writeln('cold snapshot read: ${coldReadWatch.elapsedMicroseconds} us')
    ..writeln(
      '$_readIterations cached hierarchy reads: '
      '${cachedReadWatch.elapsedMicroseconds} us',
    )
    ..writeln(
      '$_readIterations indexed request lookups: '
      '${lookupWatch.elapsedMicroseconds} us',
    )
    ..writeln(
      'mutation snapshot rebuild: ${invalidationWatch.elapsedMicroseconds} us',
    )
    ..writeln('checksum: $checksum');
}

List<ApiCollection> _fixture() => [
  for (
    var collectionIndex = 0;
    collectionIndex < _collectionCount;
    collectionIndex++
  )
    ApiCollection(
      id: 'collection-$collectionIndex',
      name: 'Collection $collectionIndex',
      folders: [
        for (
          var folderIndex = 0;
          folderIndex < _foldersPerCollection;
          folderIndex++
        )
          ApiFolder(
            id: 'folder-$collectionIndex-$folderIndex',
            name: 'Group $folderIndex',
            requests: [
              for (
                var requestIndex = 0;
                requestIndex < _requestsPerFolder;
                requestIndex++
              )
                ApiRequestDefinition(
                  id: 'request-$collectionIndex-$folderIndex-$requestIndex',
                  collectionId: 'collection-$collectionIndex',
                  folderId: 'folder-$collectionIndex-$folderIndex',
                  name: 'Request $requestIndex',
                  method: 'GET',
                  urlTemplate: 'https://api.example.test/items/$requestIndex',
                  queryParams: const [],
                  headers: const [],
                  bodyTemplate: '',
                ),
            ],
          ),
      ],
    ),
];
