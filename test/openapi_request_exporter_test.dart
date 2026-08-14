import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/data/services/openapi_request_exporter.dart';
import 'package:sendreq/data/services/openapi_request_importer.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';

void main() {
  test('exports HTTP requests as a round-trippable OpenAPI 3 document', () {
    final requests = InMemoryApiAssetRepository.demo().listRequests();
    final source = const OpenApiRequestExporter().export(
      requests: requests,
      title: 'Sendreq Demo Example API',
    );
    final document = jsonDecode(source) as Map<String, dynamic>;
    final paths = document['paths'] as Map<String, dynamic>;
    final getUsers = paths['/api/v1/users'] as Map<String, dynamic>;
    final operation = getUsers['get'] as Map<String, dynamic>;

    expect(document['openapi'], '3.0.3');
    expect(
      (document['info'] as Map<String, dynamic>)['title'],
      'Sendreq Demo Example API',
    );
    expect((document['servers'] as List).single, {
      'url': 'http://127.0.0.1:8081',
    });
    expect(operation['summary'], 'List users');
    expect(operation['tags'], ['REST']);
    expect(
      (operation['parameters'] as List).any(
        (item) => item['name'] == 'limit' && item['in'] == 'query',
      ),
      isTrue,
    );

    final roundTripped = const OpenApiRequestImporter().parse(source);
    expect(roundTripped, hasLength(6));
    expect(
      roundTripped.first.urlTemplate,
      'http://127.0.0.1:8081/api/v1/users',
    );
    expect(roundTripped.first.queryParams.first.key, 'page');
    expect(
      roundTripped
          .singleWhere((request) => request.name == 'API key users')
          .authentication
          .usesApiKey,
      isTrue,
    );
  });

  test('exports and imports Basic and API Key security schemes', () {
    const base = ApiRequestDefinition(
      id: 'id',
      collectionId: 'collection',
      folderId: 'folder',
      name: 'Secure endpoint',
      method: 'GET',
      urlTemplate: 'https://api.example.com/secure',
      queryParams: [],
      headers: [],
      bodyTemplate: '',
    );
    final source = const OpenApiRequestExporter().export(
      requests: [
        base.copyWith(
          id: 'basic',
          authentication: const RequestAuthentication.basic(
            username: '{{username}}',
            password: '{{password}}',
          ),
        ),
        base.copyWith(
          id: 'key',
          urlTemplate: 'https://api.example.com/key',
          authentication: const RequestAuthentication.apiKey(
            apiKeyName: AuthenticationVariableNames.defaultApiKeyHeader,
            apiKeyValue: '{{${AuthenticationVariableNames.apiKey}}}',
            apiKeyLocation: ApiKeyLocation.header,
          ),
        ),
      ],
    );
    final document = jsonDecode(source) as Map<String, dynamic>;
    final schemes = (document['components'] as Map)['securitySchemes'] as Map;
    expect(schemes['basicAuth'], {'type': 'http', 'scheme': 'basic'});
    expect(schemes['apiKeyHeader_X_API_Key'], {
      'type': 'apiKey',
      'name': 'X-API-Key',
      'in': 'header',
    });

    final imported = const OpenApiRequestImporter().parse(source);
    expect(imported.first.authentication.usesBasicAuthentication, isTrue);
    expect(imported.last.authentication.usesApiKey, isTrue);
    expect(imported.last.authentication.apiKeyName, 'X-API-Key');
  });

  test(
    'exports structured form examples and excludes multipart local files',
    () {
      const base = ApiRequestDefinition(
        id: 'form',
        collectionId: 'collection',
        folderId: 'folder',
        name: 'Submit form',
        method: 'POST',
        urlTemplate: 'https://api.example.test/forms',
        queryParams: [],
        headers: [
          ApiField(
            key: 'Content-Type',
            value: 'application/x-www-form-urlencoded',
          ),
        ],
        bodyTemplate: 'stale=raw',
        formUrlEncodedFields: [
          ApiField(key: 'name', value: 'Mary Jane'),
          ApiField(key: 'disabled', value: 'no', enabled: false),
          ApiField(key: 'token', value: '{{token}}', secretReference: true),
        ],
      );
      final multipart = base.copyWith(
        id: 'multipart',
        urlTemplate: 'https://api.example.test/files',
        headers: const [
          ApiField(key: 'Content-Type', value: 'multipart/form-data'),
        ],
        multipartFields: const [ApiField(key: 'title', value: 'Profile')],
        multipartFiles: const [
          ApiFileField(
            key: 'file',
            path: '/private/local/avatar.png',
            fileName: 'avatar.png',
            sizeBytes: 42,
          ),
        ],
      );

      final document = const OpenApiRequestExporter().toJson(
        requests: [base, multipart],
      );
      final paths = document['paths'] as Map<String, Object?>;
      final formBody =
          (((paths['/forms'] as Map)['post'] as Map)['requestBody']
                  as Map)['content']
              as Map;
      final multipartBody =
          (((paths['/files'] as Map)['post'] as Map)['requestBody']
                  as Map)['content']
              as Map;

      expect(formBody['application/x-www-form-urlencoded'], {
        'example': {'name': 'Mary Jane'},
      });
      expect(multipartBody['multipart/form-data'], {
        'example': {'title': 'Profile'},
      });
      expect(
        jsonEncode(document),
        isNot(contains('/private/local/avatar.png')),
      );
    },
  );
}
