import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/api_assets/collection_documentation.dart';
import 'package:sendreq/domain/api_assets/openapi_exchange.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// Read-only API reference derivation commands for Collection assets.
extension WorkspaceDocumentationExportOperations on WorkspaceViewModel {
  Future<MarkdownDocumentationFileResult> exportCollectionDocumentation({
    required String collectionId,
    required String outputDirectory,
    required String languageCode,
  }) async {
    final collection = internals.assetRepository.listCollections().firstWhere(
      (item) => item.id == collectionId,
    );
    final requests = <ApiRequestDefinition>[
      for (final folder in collection.folders)
        for (final request in folder.requests)
          if (request.protocol == ApiRequestProtocol.http)
            requestWithDraftInternal(request),
    ];
    if (requests.isEmpty) {
      throw StateError('Collection has no HTTP requests.');
    }
    final openApi = internals.openApiExporter.serialize(
      OpenApiExportSnapshot(requests: requests, title: collection.name),
    );
    final markdown = internals.openApiMarkdownRenderer.render(
      openApi,
      languageCode: languageCode,
    );
    return internals.markdownDocumentationFile.write(
      MarkdownDocumentationFileRequest(
        outputDirectory: outputDirectory,
        collectionName: collection.name,
        source: markdown,
      ),
    );
  }
}
