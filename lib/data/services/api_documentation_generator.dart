import 'dart:convert';

import '../../domain/api_assets/api_asset_models.dart';
import '../../domain/models/workspace_models.dart';

/// 生成的 API 参考文档结果：包含 Markdown 正文与可复制的 cURL 命令。
class GeneratedApiDocumentation {
  /// 创建包含 Markdown 正文与 cURL 命令的结果对象。
  const GeneratedApiDocumentation({required this.markdown, required this.curl});

  /// Markdown 格式的文档正文。
  final String markdown;

  /// 与本次请求等价的 cURL 命令文本。
  final String curl;
}

/// 将一次请求/响应快照（文档草稿）渲染为可阅读的 API 参考文档。
class ApiDocumentationGenerator {
  /// 创建 API 参考文档生成器。
  const ApiDocumentationGenerator();

  /// 依据草稿生成 Markdown 文档与等价的 cURL 命令。
  GeneratedApiDocumentation generate(DocumentationDraft draft) {
    final request = draft.request;
    final response = draft.response;
    final curl = _curlFor(draft);
    // 从解析后的 URL 中提取路径部分作为标题；解析失败时退回使用完整 URL。
    final endpoint = Uri.tryParse(request.resolvedUrl)?.path;
    final title = endpoint == null || endpoint.isEmpty
        ? request.resolvedUrl
        : endpoint;
    final markdown = [
      '# API 参考：${_requestTypeLabel(request)} $title',
      '',
      '## 端点',
      '',
      '`${_requestTypeLabel(request)} ${request.resolvedUrl}`',
      '',
      '## 请求',
      '',
      _headersSection('请求头', request.headers),
      if (request.body.isNotEmpty) ...[
        '',
        '### 请求体',
        '',
        '```json',
        request.body,
        '```',
      ],
      '',
      '### cURL',
      '',
      '```bash',
      curl,
      '```',
      '',
      '## 响应',
      '',
      '状态：`${response.statusCode}`',
      '',
      _headersSection('响应头', response.headers),
      '',
      '### 响应示例',
      '',
      '```json',
      _formatJson(response.body),
      '```',
    ].join('\n');
    return GeneratedApiDocumentation(markdown: markdown, curl: curl);
  }

  /// 生成 shell 可执行的 cURL 命令；非 HTTP 请求不会伪装成 cURL。
  String _curlFor(DocumentationDraft draft) {
    if (draft.request.protocol != ApiRequestProtocol.http) {
      return '# ${_requestTypeLabel(draft.request)} requests cannot be represented as cURL.';
    }
    final lines = <String>[
      "curl -X ${draft.request.method} '${_shellEscape(draft.request.resolvedUrl)}'",
      for (final header in draft.request.headers)
        "  -H '${_shellEscape('${header.keyName}: ${_valueFor(header)}')}'",
      if (draft.request.body.isNotEmpty)
        "  --data '${_shellEscape(draft.request.body)}'",
    ];
    // 以反斜杠续行拼接多行命令，便于直接复制到终端执行。
    return lines.join(' \\\n');
  }

  /// 根据请求协议生成对应的类型标签。
  String _requestTypeLabel(ExecutionRequestSnapshot request) =>
      switch (request.protocol) {
        ApiRequestProtocol.http => request.method,
        ApiRequestProtocol.webSocket => 'WebSocket',
        ApiRequestProtocol.grpc => 'gRPC',
      };

  /// 将请求头/响应头渲染为 Markdown 表格章节；无头部时输出占位文案。
  String _headersSection(String title, List<KeyValueRow> headers) {
    if (headers.isEmpty) {
      return '### $title\n\n无';
    }
    return [
      '### $title',
      '',
      '| 名称 | 值 |',
      '| --- | --- |',
      for (final header in headers)
        '| ${_tableValue(header.keyName)} | ${_tableValue(_valueFor(header))} |',
    ].join('\n');
  }

  /// 机密值一律脱敏为圆点占位符，避免密钥泄露进文档。
  String _valueFor(KeyValueRow value) =>
      value.secret ? '••••••••••••' : value.value;

  /// 转义 Markdown 表格中的特殊字符：竖线转义、换行替换为 <br>。
  String _tableValue(String value) =>
      value.replaceAll('|', '\\|').replaceAll('\n', '<br>');

  /// 转义单引号，保证 URL/头部值在 shell 单引号包裹下安全传递。
  String _shellEscape(String value) => value.replaceAll("'", "'\\''");

  /// 文档中的 JSON 响应统一缩进，非 JSON 原样保留以避免篡改文本响应。
  String _formatJson(String source) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(source));
    } on FormatException {
      return source;
    }
  }
}
