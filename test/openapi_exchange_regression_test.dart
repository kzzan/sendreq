import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/services/openapi_request_importer.dart';
import 'package:sendreq/domain/api_assets/collection_documentation.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

import 'support/workspace_view_model_test_factory.dart';

void main() {
  test(
    'OpenAPI 3.x fixture keeps supported mappings and explicit loss codes',
    () {
      final source = File(
        'test/fixtures/openapi_exchange_regression.json',
      ).readAsStringSync();

      final preview = const OpenApiRequestImporter().preview(source);
      final requests = const OpenApiRequestImporter().parse(source);

      expect(requests, hasLength(2));
      expect(requests.first.urlTemplate, 'https://api.example.test/users');
      expect(requests.first.queryParams.single.key, 'limit');
      expect(requests.last.formUrlEncodedFields, hasLength(2));
      expect(
        preview.issues.map((issue) => issue.code),
        containsAll([
          'responsesNotImported',
          'referenceNotResolved',
          'schemaNotImported',
        ]),
      );
    },
  );

  test(
    'workspace OpenAPI JSON export remains independent from Markdown ports',
    () {
      final viewModel = workspaceViewModel(
        openApiMarkdownRenderer: const _FailingRenderer(),
        markdownDocumentationFile: const _FailingFilePort(),
      );
      addTearDown(viewModel.dispose);

      final source = viewModel.exportOpenApi();

      expect(source, contains('"openapi": "3.0.3"'));
      expect(source, contains('"summary": "List users"'));
      expect(source, isNot(contains('demo-websocket-echo')));
    },
  );
}

class _FailingRenderer implements OpenApiMarkdownDocumentationPort {
  const _FailingRenderer();

  @override
  String render(String normalizedOpenApiJson, {required String languageCode}) =>
      throw StateError('Markdown renderer must not be called.');
}

class _FailingFilePort implements MarkdownDocumentationFilePort {
  const _FailingFilePort();

  @override
  Future<MarkdownDocumentationFileResult> write(
    MarkdownDocumentationFileRequest request,
  ) => throw StateError('Markdown file port must not be called.');
}
