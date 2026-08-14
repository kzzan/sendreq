import 'dart:convert';

import 'package:sendreq/domain/api_assets/collection_documentation.dart';

/// Structured renderer for normalized OpenAPI 3.0.3 JSON.
class OpenApiMarkdownDocumentationRenderer
    implements OpenApiMarkdownDocumentationPort {
  const OpenApiMarkdownDocumentationRenderer();

  @override
  String render(String normalizedOpenApiJson, {required String languageCode}) {
    final labels = _DocumentationLabels.forLanguage(languageCode);
    final decoded = jsonDecode(normalizedOpenApiJson);
    if (decoded is! Map) {
      throw const FormatException('OpenAPI document must be an object.');
    }
    final document = Map<String, dynamic>.from(decoded);
    if (document['openapi'] != '3.0.3') {
      throw const FormatException('Expected normalized OpenAPI 3.0.3 JSON.');
    }
    final info = _map(document['info']);
    final paths = _map(document['paths']);
    if (paths.isEmpty) {
      throw const FormatException('OpenAPI document has no HTTP operations.');
    }

    final title = _text(info['title'], fallback: labels.apiReference);
    final version = _text(info['version'], fallback: '1.0.0');
    final output = StringBuffer()
      ..writeln('# ${_heading(title)}')
      ..writeln()
      ..writeln('## ${labels.overview}')
      ..writeln()
      ..writeln('| ${labels.field} | ${labels.value} |')
      ..writeln('| --- | --- |')
      ..writeln('| ${labels.title} | ${_cell(title)} |')
      ..writeln('| ${labels.version} | ${_cell(version)} |')
      ..writeln('| OpenAPI | 3.0.3 |');
    final description = _text(info['description']);
    if (description.isNotEmpty) {
      output
        ..writeln()
        ..writeln(description);
    }

    _writeServers(output, _list(document['servers']), labels);
    _writeAuthentication(output, document, labels);
    _writeTags(output, document, paths, labels);
    _writeEndpoints(output, paths, labels);
    output
      ..writeln('## ${labels.openApiSource}')
      ..writeln()
      ..writeln('```json')
      ..writeln(const JsonEncoder.withIndent('  ').convert(document))
      ..writeln('```');
    return output.toString();
  }

  void _writeServers(
    StringBuffer output,
    List<dynamic> servers,
    _DocumentationLabels labels,
  ) {
    output
      ..writeln()
      ..writeln('## ${labels.servers}')
      ..writeln();
    if (servers.isEmpty) {
      output.writeln('_${labels.noGlobalServers}_');
      return;
    }
    output
      ..writeln('| URL | ${labels.description} |')
      ..writeln('| --- | --- |');
    for (final value in servers) {
      final server = _map(value);
      output.writeln(
        '| ${_cell(_text(server['url']))} | ${_cell(_text(server['description']))} |',
      );
    }
  }

  void _writeAuthentication(
    StringBuffer output,
    Map<String, dynamic> document,
    _DocumentationLabels labels,
  ) {
    final schemes = _map(_map(_map(document['components']))['securitySchemes']);
    output
      ..writeln()
      ..writeln('## ${labels.authentication}')
      ..writeln();
    if (schemes.isEmpty) {
      output.writeln('_${labels.noAuthenticationSchemes}_');
      return;
    }
    output
      ..writeln('| ${labels.scheme} | ${labels.type} | ${labels.details} |')
      ..writeln('| --- | --- | --- |');
    for (final entry in schemes.entries) {
      final scheme = _map(entry.value);
      final details = [
        if (_text(scheme['scheme']).isNotEmpty)
          'scheme=${_text(scheme['scheme'])}',
        if (_text(scheme['name']).isNotEmpty) 'name=${_text(scheme['name'])}',
        if (_text(scheme['in']).isNotEmpty) 'in=${_text(scheme['in'])}',
      ].join(', ');
      output.writeln(
        '| ${_cell(entry.key)} | ${_cell(_text(scheme['type']))} | ${_cell(details)} |',
      );
    }
  }

  void _writeTags(
    StringBuffer output,
    Map<String, dynamic> document,
    Map<String, dynamic> paths,
    _DocumentationLabels labels,
  ) {
    final declared = <String, String>{};
    for (final value in _list(document['tags'])) {
      final tag = _map(value);
      final name = _text(tag['name']);
      if (name.isNotEmpty) declared[name] = _text(tag['description']);
    }
    for (final pathValue in paths.values) {
      for (final operation in _operations(_map(pathValue)).values) {
        for (final tag in _list(operation['tags'])) {
          declared.putIfAbsent(_text(tag), () => '');
        }
      }
    }
    output
      ..writeln()
      ..writeln('## ${labels.tags}')
      ..writeln();
    if (declared.isEmpty) {
      output.writeln('_${labels.noTags}_');
      return;
    }
    output
      ..writeln('| ${labels.name} | ${labels.description} |')
      ..writeln('| --- | --- |');
    for (final entry in declared.entries) {
      output.writeln('| ${_cell(entry.key)} | ${_cell(entry.value)} |');
    }
  }

  void _writeEndpoints(
    StringBuffer output,
    Map<String, dynamic> paths,
    _DocumentationLabels labels,
  ) {
    output
      ..writeln()
      ..writeln('## ${labels.endpoints}')
      ..writeln();
    for (final pathEntry in paths.entries) {
      final pathItem = _map(pathEntry.value);
      for (final operationEntry in _operations(pathItem).entries) {
        final method = operationEntry.key.toUpperCase();
        final operation = operationEntry.value;
        output
          ..writeln('### `$method ${_inline(pathEntry.key)}`')
          ..writeln()
          ..writeln(
            '**${labels.summary}:** ${_inline(_text(operation['summary'], fallback: labels.none))}',
          )
          ..writeln()
          ..writeln(
            '**${labels.tags}:** ${_joined(_list(operation['tags']), labels)}',
          )
          ..writeln()
          ..writeln(
            '**${labels.security}:** ${_security(_list(operation['security']), labels)}',
          )
          ..writeln();
        _writeParameters(output, [
          ..._list(pathItem['parameters']),
          ..._list(operation['parameters']),
        ], labels);
        _writeRequestBody(output, _map(operation['requestBody']), labels);
        _writeResponses(output, _map(operation['responses']), labels);
      }
    }
  }

  void _writeParameters(
    StringBuffer output,
    List<dynamic> parameters,
    _DocumentationLabels labels,
  ) {
    output
      ..writeln('#### ${labels.parameters}')
      ..writeln();
    if (parameters.isEmpty) {
      output
        ..writeln('_${labels.none}._')
        ..writeln();
      return;
    }
    output
      ..writeln(
        '| ${labels.name} | ${labels.location} | ${labels.required} | ${labels.schema} | ${labels.example} | ${labels.description} |',
      )
      ..writeln('| --- | --- | --- | --- | --- | --- |');
    for (final value in parameters) {
      final parameter = _map(value);
      final schema = _map(parameter['schema']);
      output.writeln(
        '| ${_cell(_text(parameter['name']))} | ${_cell(_text(parameter['in']))} | '
        '${parameter['required'] == true ? labels.yes : labels.no} | ${_cell(_schema(schema))} | '
        '${_cell(_display(parameter['example']))} | ${_cell(_text(parameter['description']))} |',
      );
    }
    output.writeln();
  }

  void _writeRequestBody(
    StringBuffer output,
    Map<String, dynamic> requestBody,
    _DocumentationLabels labels,
  ) {
    output
      ..writeln('#### ${labels.requestBody}')
      ..writeln();
    final content = _map(requestBody['content']);
    if (content.isEmpty) {
      output
        ..writeln('_${labels.none}._')
        ..writeln();
      return;
    }
    output.writeln(
      '**${labels.required}:** ${requestBody['required'] == true ? labels.yes : labels.no}',
    );
    for (final entry in content.entries) {
      final media = _map(entry.value);
      output
        ..writeln()
        ..writeln('**${labels.contentType}:** `${_inline(entry.key)}`');
      if (media.containsKey('example')) {
        _writeJsonExample(output, media['example']);
      } else if (_map(media['examples']).isNotEmpty) {
        for (final example in _map(media['examples']).entries) {
          output
            ..writeln()
            ..writeln('*${_inline(example.key)}*');
          final value = _map(example.value)['value'] ?? example.value;
          _writeJsonExample(output, value);
        }
      }
    }
    output.writeln();
  }

  void _writeResponses(
    StringBuffer output,
    Map<String, dynamic> responses,
    _DocumentationLabels labels,
  ) {
    output
      ..writeln('#### ${labels.responses}')
      ..writeln();
    if (responses.isEmpty) {
      output
        ..writeln('_${labels.noneDeclared}_')
        ..writeln();
      return;
    }
    output
      ..writeln(
        '| ${labels.status} | ${labels.description} | ${labels.contentTypes} |',
      )
      ..writeln('| --- | --- | --- |');
    for (final entry in responses.entries) {
      final response = _map(entry.value);
      output.writeln(
        '| ${_cell(entry.key)} | ${_cell(_text(response['description']))} | '
        '${_cell(_map(response['content']).keys.join(', '))} |',
      );
    }
    for (final entry in responses.entries) {
      final content = _map(_map(entry.value)['content']);
      for (final mediaEntry in content.entries) {
        final media = _map(mediaEntry.value);
        if (!media.containsKey('example')) continue;
        output
          ..writeln()
          ..writeln(
            '**${_inline(entry.key)} `${_inline(mediaEntry.key)}` ${labels.example}:**',
          );
        _writeJsonExample(output, media['example']);
      }
    }
    output.writeln();
  }

  void _writeJsonExample(StringBuffer output, Object? value) {
    output
      ..writeln()
      ..writeln('```json')
      ..writeln(const JsonEncoder.withIndent('  ').convert(value))
      ..writeln('```');
  }

  Map<String, Map<String, dynamic>> _operations(
    Map<String, dynamic> pathItem,
  ) => {
    for (final entry in pathItem.entries)
      if (const {
        'get',
        'post',
        'put',
        'patch',
        'delete',
        'head',
        'options',
        'trace',
      }.contains(entry.key.toLowerCase()))
        entry.key.toLowerCase(): _map(entry.value),
  };

  String _security(List<dynamic> security, _DocumentationLabels labels) {
    if (security.isEmpty) return labels.none;
    return security
        .map((value) => _map(value).keys.join(' + '))
        .where((value) => value.isNotEmpty)
        .join(labels.orSeparator);
  }

  String _schema(Map<String, dynamic> schema) {
    final type = _text(schema['type'], fallback: _text(schema[r'$ref']));
    final format = _text(schema['format']);
    return format.isEmpty ? type : '$type ($format)';
  }

  String _joined(List<dynamic> values, _DocumentationLabels labels) {
    final joined = values
        .map(_text)
        .where((value) => value.isNotEmpty)
        .join(', ');
    return joined.isEmpty ? labels.none : _inline(joined);
  }

  String _display(Object? value) {
    if (value == null) return '';
    if (value is String) return value;
    return jsonEncode(value);
  }

  static Map<String, dynamic> _map(Object? value) => switch (value) {
    final Map value => Map<String, dynamic>.from(value),
    _ => <String, dynamic>{},
  };

  static List<dynamic> _list(Object? value) => switch (value) {
    final List value => value,
    _ => const [],
  };

  static String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _cell(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll('|', r'\|')
      .replaceAll('`', '&#96;')
      .replaceAll(RegExp(r'\r?\n'), '<br>');

  static String _inline(String value) => value.replaceAll('`', '&#96;');

  static String _heading(String value) =>
      value.replaceAll(RegExp(r'[\r\n]+'), ' ');
}

class _DocumentationLabels {
  const _DocumentationLabels({required this.chinese});

  factory _DocumentationLabels.forLanguage(String languageCode) =>
      _DocumentationLabels(chinese: languageCode.toLowerCase() == 'zh');

  final bool chinese;

  String get apiReference => chinese ? 'API 接口文档' : 'API reference';
  String get overview => chinese ? '概览' : 'Overview';
  String get field => chinese ? '字段' : 'Field';
  String get value => chinese ? '值' : 'Value';
  String get title => chinese ? '标题' : 'Title';
  String get version => chinese ? '版本' : 'Version';
  String get servers => chinese ? '服务器' : 'Servers';
  String get description => chinese ? '说明' : 'Description';
  String get noGlobalServers =>
      chinese ? '未声明全局服务器。' : 'No global servers declared.';
  String get authentication => chinese ? '认证' : 'Authentication';
  String get noAuthenticationSchemes =>
      chinese ? '未声明认证方案。' : 'No authentication schemes declared.';
  String get scheme => chinese ? '方案' : 'Scheme';
  String get type => chinese ? '类型' : 'Type';
  String get details => chinese ? '详情' : 'Details';
  String get tags => chinese ? '标签' : 'Tags';
  String get noTags => chinese ? '未声明标签。' : 'No tags declared.';
  String get name => chinese ? '名称' : 'Name';
  String get endpoints => chinese ? '接口' : 'Endpoints';
  String get summary => chinese ? '摘要' : 'Summary';
  String get security => chinese ? '安全要求' : 'Security';
  String get parameters => chinese ? '参数' : 'Parameters';
  String get location => chinese ? '位置' : 'In';
  String get required => chinese ? '必填' : 'Required';
  String get schema => chinese ? '结构' : 'Schema';
  String get example => chinese ? '示例' : 'Example';
  String get requestBody => chinese ? '请求体' : 'Request body';
  String get contentType => chinese ? '内容类型' : 'Content type';
  String get responses => chinese ? '响应' : 'Responses';
  String get status => chinese ? '状态码' : 'Status';
  String get contentTypes => chinese ? '内容类型' : 'Content types';
  String get openApiSource => chinese ? 'OpenAPI 源文档' : 'OpenAPI source';
  String get none => chinese ? '无' : 'None';
  String get noneDeclared => chinese ? '未声明。' : 'None declared.';
  String get yes => chinese ? '是' : 'Yes';
  String get no => chinese ? '否' : 'No';
  String get orSeparator => chinese ? ' 或 ' : ' or ';
}
