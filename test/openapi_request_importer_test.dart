import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/services/openapi_request_importer.dart';

void main() {
  // 验证导入器能把 OpenAPI 3.0 的 GET/POST 操作映射为可编辑请求：
  // 摘要、server URL、query 参数与请求体示例都应落入对应的可编辑字段。
  test('maps supported OpenAPI operations to editable requests', () {
    // 内联的最小 OpenAPI 文档：/users 同时定义 GET（带 query 参数）与 POST（带示例请求体）。
    const source = '''{
      "openapi":"3.0.3",
      "servers":[{"url":"https://api.sendreq.io"}],
      "paths":{"/users":{"get":{"summary":"List users","parameters":[{"name":"limit","in":"query"}]},"post":{"requestBody":{"content":{"application/json":{"example":{"name":"Mary"}}}}}}}
    }''';

    final requests = const OpenApiRequestImporter().parse(source);

    expect(requests, hasLength(2));
    expect(requests.first.name, 'List users');
    // URL 应为 server URL 拼接路径，而非占位符模板。
    expect(requests.first.urlTemplate, 'https://api.sendreq.io/users');
    expect(requests.first.queryParams.single.key, 'limit');
    expect(requests.last.method, 'POST');
    // 请求体示例应作为带两空格缩进的 JSON 模板预填到可编辑请求中。
    expect(requests.last.bodyTemplate, '{\n  "name": "Mary"\n}');
    expect(requests.last.headers.single.key, 'Content-Type');
    expect(requests.last.headers.single.value, 'application/json');
  });

  // 验证不满足 OpenAPI 3.x 要求的文档（此处为 2.0）会被明确拒绝并抛出导入异常。
  test('rejects documents without OpenAPI 3.x paths', () {
    expect(
      () => const OpenApiRequestImporter().parse('{"openapi":"2.0"}'),
      throwsA(isA<OpenApiImportException>()),
    );
  });

  test('imports URL encoded and multipart text field examples', () {
    const source = '''{
      "openapi":"3.0.3",
      "paths":{
        "/session":{"post":{"requestBody":{"content":{
          "application/x-www-form-urlencoded":{"example":{"email":"mary@example.test","scope":"read"}},
          "multipart/form-data":{"example":{"title":"Profile","visibility":"private"}}
        }}}}
      }
    }''';

    final urlEncoded = const OpenApiRequestImporter().parse(source).single;
    expect(
      urlEncoded.headers.single.value,
      'application/x-www-form-urlencoded',
    );
    expect(
      urlEncoded.formUrlEncodedFields.map((field) => (field.key, field.value)),
      [('email', 'mary@example.test'), ('scope', 'read')],
    );
    expect(urlEncoded.multipartFields, isEmpty);

    const multipartOnly = '''{
      "openapi":"3.0.3",
      "paths":{"/upload":{"post":{"requestBody":{"content":{
        "multipart/form-data":{"examples":{"default":{"value":{"title":"Profile","visibility":"private"}}}}
      }}}}}
    }''';
    final multipart = const OpenApiRequestImporter()
        .parse(multipartOnly)
        .single;
    expect(multipart.headers.single.value, 'multipart/form-data');
    expect(multipart.multipartFields.map((field) => (field.key, field.value)), [
      ('title', 'Profile'),
      ('visibility', 'private'),
    ]);
  });
}
