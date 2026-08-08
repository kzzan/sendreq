import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/services/api_documentation_generator.dart';
import 'package:sendreq/domain/models/workspace_models.dart';

void main() {
  const generator = ApiDocumentationGenerator();

  // 验证一次典型的请求/响应快照能生成完整的 Markdown 参考文档，
  // 覆盖标题、请求头/体、状态码、响应头/示例等各章节，以及配套的 cURL 命令。
  test(
    'generates a complete Markdown reference from a documentation draft',
    () {
      final result = generator.generate(_draft());

      expect(result.markdown, contains('# API 参考：POST /v1/widgets'));
      expect(
        result.markdown,
        contains('`POST https://api.sendreq.local/v1/widgets`'),
      );
      expect(result.markdown, contains('### 请求头'));
      expect(result.markdown, contains('| x-request-id | request-42 |'));
      expect(result.markdown, contains('### 请求体'));
      expect(result.markdown, contains('{"name":"widget"}'));
      expect(result.markdown, contains('状态：`201`'));
      expect(result.markdown, contains('### 响应头'));
      expect(result.markdown, contains('| x-sendreq-trace | trace-42 |'));
      expect(result.markdown, contains('### 响应示例'));
      expect(result.markdown, contains('"id": "widget-42"'));
      expect(
        result.curl,
        contains("curl -X POST 'https://api.sendreq.local/v1/widgets'"),
      );
    },
  );

  test('formats a JSON response in the generated Markdown document', () {
    final result = generator.generate(_draft());

    expect(result.markdown, contains('{\n  "id": "widget-42"\n}'));
  });

  // 验证标记为 secret 的请求头值在任何输出形式中都不会泄露原始值，
  // Markdown 与 cURL 两处均以掩码占位符呈现。
  test('masks Secret header values in Markdown and cURL output', () {
    final result = generator.generate(_draft());

    expect(result.markdown, isNot(contains('raw-secret-value')));
    expect(result.curl, isNot(contains('raw-secret-value')));
    expect(result.markdown, contains('Authorization | ••••••••••••'));
    expect(result.curl, contains('Authorization: ••••••••••••'));
  });
}

/// 构造一份含密钥请求头与响应元数据的示例快照，供文档生成用例复用。
DocumentationDraft _draft() => const DocumentationDraft(
  requestId: 'request-42',
  request: ExecutionRequestSnapshot(
    method: 'POST',
    resolvedUrl: 'https://api.sendreq.local/v1/widgets',
    headers: [
      KeyValueRow(keyName: 'x-request-id', value: 'request-42'),
      KeyValueRow(
        keyName: 'Authorization',
        value: 'raw-secret-value',
        secret: true,
      ),
    ],
    body: '{"name":"widget"}',
    environmentName: 'Test',
  ),
  response: ResponseSnapshot(
    statusCode: 201,
    timeMs: 12,
    sizeKb: 0.1,
    body: '{"id":"widget-42"}',
    headers: [KeyValueRow(keyName: 'x-sendreq-trace', value: 'trace-42')],
  ),
);
