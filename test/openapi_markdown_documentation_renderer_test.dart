import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/services/openapi_markdown_documentation_renderer.dart';

void main() {
  const renderer = OpenApiMarkdownDocumentationRenderer();

  test('renders complete stable sections and escapes Markdown table cells', () {
    const source = r'''{
  "openapi": "3.0.3",
  "info": {"title": "Orders | API", "version": "2.1.0"},
  "servers": [{"url": "https://api.example.test", "description": "Primary"}],
  "tags": [{"name": "orders", "description": "Order `flows`"}],
  "components": {"securitySchemes": {
    "bearerAuth": {"type": "http", "scheme": "bearer"},
    "apiKeyHeader": {"type": "apiKey", "name": "X-API-Key", "in": "header"}
  }},
  "paths": {"/orders": {"post": {
    "summary": "Create | order",
    "tags": ["orders"],
    "security": [{"bearerAuth": []}],
    "parameters": [{"name": "X-Trace|Id", "in": "header", "required": true, "schema": {"type": "string"}, "example": "a`b"}],
    "requestBody": {"required": true, "content": {"application/json": {"example": {"name": "Mary", "lines": [1, 2]}}}},
    "responses": {"201": {"description": "Created", "content": {"application/json": {"example": {"id": 7}}}}}
  }}}
}''';

    final markdown = renderer.render(source, languageCode: 'en');

    expect(
      markdown.indexOf('## Overview'),
      lessThan(markdown.indexOf('## Servers')),
    );
    expect(
      markdown.indexOf('## Authentication'),
      lessThan(markdown.indexOf('## Endpoints')),
    );
    expect(markdown, contains('### `POST /orders`'));
    expect(markdown, contains('**Summary:** Create | order'));
    expect(markdown, contains('X-Trace\\|Id'));
    expect(markdown, contains('a&#96;b'));
    expect(markdown, contains('#### Parameters'));
    expect(markdown, contains('#### Request body'));
    expect(markdown, contains('#### Responses'));
    expect(markdown, contains('## OpenAPI source'));
    expect(markdown, contains('"openapi": "3.0.3"'));
    expect(
      RegExp(r'```json').allMatches(markdown).length,
      greaterThanOrEqualTo(3),
    );

    final chinese = renderer.render(source, languageCode: 'zh');
    expect(chinese, contains('## 概览'));
    expect(chinese, contains('## 认证'));
    expect(chinese, contains('## 接口'));
    expect(chinese, contains('#### 请求体'));
    expect(chinese, contains('#### 响应'));
    expect(chinese, contains('## OpenAPI 源文档'));
  });

  test('rejects non-normalized or empty OpenAPI documents', () {
    expect(
      () => renderer.render(
        '{"openapi":"3.1.0","paths":{"/x":{}}}',
        languageCode: 'en',
      ),
      throwsFormatException,
    );
    expect(
      () => renderer.render(
        '{"openapi":"3.0.3","info":{},"paths":{}}',
        languageCode: 'en',
      ),
      throwsFormatException,
    );
  });
}
