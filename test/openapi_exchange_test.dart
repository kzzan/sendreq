import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/data/services/openapi_request_exporter.dart';
import 'package:sendreq/data/services/openapi_request_importer.dart';
import 'package:sendreq/domain/api_assets/openapi_exchange.dart';

void main() {
  const source = '''{
    "openapi":"3.0.3",
    "info":{"title":"Preview API"},
    "components":{"schemas":{"User":{"type":"object"}}},
    "paths":{"/users":{"get":{"summary":"List users"},"head":{}}}
  }''';

  test(
    'OpenAPI import previews without writing and commits only by preview id',
    () {
      final repository = InMemoryApiAssetRepository.demo();
      final service = OpenApiAssetImportService(
        assetRepository: repository,
        transformer: const OpenApiRequestImporter(),
      );
      final initialCount = repository.listCollections().length;

      final preview = service.preview(source);

      expect(repository.listCollections(), hasLength(initialCount));
      expect(preview.additionCount, 1);
      expect(preview.unsupportedCount, 2);
      expect(preview.lossCount, 0);

      final collection = service.commit(preview.id);

      expect(collection.name, 'Preview API');
      expect(repository.listCollections(), hasLength(initialCount + 1));
      expect(() => service.commit(preview.id), throwsStateError);
    },
  );

  test('OpenAPI export port serializes only the supplied asset snapshot', () {
    final repository = InMemoryApiAssetRepository.demo();
    final output = const OpenApiRequestExporter().serialize(
      OpenApiExportSnapshot(
        requests: repository.listRequests(),
        title: 'Export preview',
      ),
    );

    expect(output, contains('"title": "Export preview"'));
    expect(output, contains('"openapi": "3.0.3"'));
  });

  test(
    'preview reports response and reference loss instead of claiming fidelity',
    () {
      const lossAwareSource = '''{
      "openapi":"3.0.3",
      "paths":{"/users":{"get":{"responses":{"200":{"content":{"application/json":{"schema":{"\$ref":"#/components/schemas/User"}}}}}}}},
      "components":{"schemas":{"User":{"type":"object"}}}
    }''';

      final preview = const OpenApiRequestImporter().preview(lossAwareSource);

      expect(
        preview.issues.map((issue) => issue.code),
        containsAll([
          'responsesNotImported',
          'referenceNotResolved',
          'schemaNotImported',
        ]),
      );
      expect(preview.lossCount, 2);
    },
  );
}
