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
      title: 'Core Platform API',
    );
    final document = jsonDecode(source) as Map<String, dynamic>;
    final paths = document['paths'] as Map<String, dynamic>;
    final getUsers = paths['/api/v1/users'] as Map<String, dynamic>;
    final operation = getUsers['get'] as Map<String, dynamic>;
    final geoIp = paths['/tools/geoip/lookup'] as Map<String, dynamic>;
    final geoIpOperation = geoIp['get'] as Map<String, dynamic>;

    expect(document['openapi'], '3.0.3');
    expect(
      (document['info'] as Map<String, dynamic>)['title'],
      'Core Platform API',
    );
    expect((document['servers'] as List).single, {'url': '{{baseUrl}}'});
    expect(operation['summary'], 'List users');
    expect(operation['tags'], ['Identity']);
    expect(
      (operation['parameters'] as List).any(
        (item) => item['name'] == 'limit' && item['in'] == 'query',
      ),
      isTrue,
    );
    expect(operation['security'], [
      {'bearerAuth': []},
    ]);
    expect(
      ((document['components'] as Map)['securitySchemes'] as Map)['bearerAuth'],
      {'type': 'http', 'scheme': 'bearer'},
    );
    expect(geoIpOperation['summary'], 'Lookup qq.com');
    expect(
      (geoIpOperation['parameters'] as List).any(
        (parameter) =>
            parameter['name'] == 'input' &&
            parameter['in'] == 'query' &&
            parameter['example'] == '{{domain}}',
      ),
      isTrue,
    );

    final roundTripped = const OpenApiRequestImporter().parse(source);
    expect(roundTripped, hasLength(8));
    expect(roundTripped.first.urlTemplate, '{{baseUrl}}/api/v1/users');
    expect(roundTripped.first.queryParams.first.key, 'limit');
    expect(roundTripped.first.authentication.bearerToken, '{{token}}');
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
}
