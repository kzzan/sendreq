import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/api_assets/collection_documentation.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

import 'support/workspace_view_model_test_factory.dart';

void main() {
  test(
    'exports only one Collection HTTP snapshot and includes its current draft',
    () async {
      final repository = InMemoryApiAssetRepository.demo();
      repository.addCollection(
        const ApiCollection(
          id: 'other',
          name: 'Other API',
          folders: [
            ApiFolder(
              id: 'other-group',
              name: 'Other',
              requests: [
                ApiRequestDefinition(
                  id: 'other-request',
                  collectionId: 'other',
                  folderId: 'other-group',
                  name: 'Other request',
                  method: 'GET',
                  urlTemplate: 'https://other.example.test/private',
                  queryParams: [],
                  headers: [],
                  bodyTemplate: '',
                ),
              ],
            ),
          ],
        ),
      );
      final renderer = _RecordingRenderer();
      final file = _RecordingMarkdownFile();
      final viewModel = workspaceViewModel(
        assetRepository: repository,
        openApiMarkdownRenderer: renderer,
        markdownDocumentationFile: file,
      );
      addTearDown(viewModel.dispose);
      viewModel.updateActiveDraftUrl('https://draft.example.test/current');

      final result = await viewModel.exportCollectionDocumentation(
        collectionId: 'collection-sendreq-demo',
        outputDirectory: '/chosen/directory',
        languageCode: 'zh',
      );

      final openApi = jsonDecode(renderer.source!) as Map<String, dynamic>;
      final encoded = jsonEncode(openApi);
      expect(openApi['openapi'], '3.0.3');
      expect((openApi['info'] as Map)['title'], 'Sendreq REST Example');
      expect(encoded, contains('/current'));
      expect(encoded, isNot(contains('other.example.test')));
      expect(file.request!.outputDirectory, '/chosen/directory');
      expect(file.request!.collectionName, 'Sendreq REST Example');
      expect(file.request!.source, '# rendered');
      expect(renderer.languageCode, 'zh');
      expect(result.fileName, 'safe-name.md');
    },
  );

  test('does not render or write a Collection with no HTTP requests', () async {
    final repository = InMemoryApiAssetRepository(
      collections: const [
        ApiCollection(
          id: 'socket-only',
          name: 'Socket API',
          folders: [
            ApiFolder(
              id: 'socket-group',
              name: 'Sockets',
              requests: [
                ApiRequestDefinition(
                  id: 'socket-request',
                  collectionId: 'socket-only',
                  folderId: 'socket-group',
                  name: 'Socket',
                  method: 'GET',
                  urlTemplate: 'wss://example.test/socket',
                  queryParams: [],
                  headers: [],
                  bodyTemplate: '',
                  protocol: ApiRequestProtocol.webSocket,
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final renderer = _RecordingRenderer();
    final file = _RecordingMarkdownFile();
    final viewModel = workspaceViewModel(
      assetRepository: repository,
      openApiMarkdownRenderer: renderer,
      markdownDocumentationFile: file,
    );
    addTearDown(viewModel.dispose);

    expect(
      () => viewModel.exportCollectionDocumentation(
        collectionId: 'socket-only',
        outputDirectory: '/chosen/directory',
        languageCode: 'en',
      ),
      throwsStateError,
    );
    expect(renderer.source, isNull);
    expect(file.request, isNull);
  });

  test('inherits OpenAPI secret and local multipart path filtering', () async {
    final repository = InMemoryApiAssetRepository(
      collections: [
        ApiCollection(
          id: 'secure',
          name: 'Secure API',
          folders: [
            ApiFolder(
              id: 'secure-group',
              name: 'Secure',
              requests: [
                ApiRequestDefinition(
                  id: 'secure-request',
                  collectionId: 'secure',
                  folderId: 'secure-group',
                  name: 'Upload',
                  method: 'POST',
                  urlTemplate: 'https://api.example.test/upload',
                  queryParams: const [],
                  headers: const [
                    ApiField(key: 'Content-Type', value: 'multipart/form-data'),
                    ApiField(
                      key: 'X-Secret',
                      value: 'plain-secret-value',
                      secretReference: true,
                    ),
                  ],
                  bodyTemplate: '',
                  authentication: const RequestAuthentication.bearer(
                    'bearer-secret-value',
                  ),
                  multipartFields: const [
                    ApiField(key: 'title', value: 'Profile'),
                  ],
                  multipartFiles: const [
                    ApiFileField(
                      key: 'file',
                      path: '/private/local/avatar.png',
                      fileName: 'avatar.png',
                      sizeBytes: 42,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final file = _RecordingMarkdownFile();
    final viewModel = workspaceViewModel(
      assetRepository: repository,
      markdownDocumentationFile: file,
    );
    addTearDown(viewModel.dispose);

    await viewModel.exportCollectionDocumentation(
      collectionId: 'secure',
      outputDirectory: '/chosen/directory',
      languageCode: 'en',
    );

    expect(file.request!.source, contains('bearerAuth'));
    expect(file.request!.source, contains('Profile'));
    expect(file.request!.source, isNot(contains('plain-secret-value')));
    expect(file.request!.source, isNot(contains('bearer-secret-value')));
    expect(file.request!.source, isNot(contains('/private/local/avatar.png')));
  });
}

class _RecordingRenderer implements OpenApiMarkdownDocumentationPort {
  String? source;
  String? languageCode;

  @override
  String render(String normalizedOpenApiJson, {required String languageCode}) {
    source = normalizedOpenApiJson;
    this.languageCode = languageCode;
    return '# rendered';
  }
}

class _RecordingMarkdownFile implements MarkdownDocumentationFilePort {
  MarkdownDocumentationFileRequest? request;

  @override
  Future<MarkdownDocumentationFileResult> write(
    MarkdownDocumentationFileRequest request,
  ) async {
    this.request = request;
    return const MarkdownDocumentationFileResult(fileName: 'safe-name.md');
  }
}
