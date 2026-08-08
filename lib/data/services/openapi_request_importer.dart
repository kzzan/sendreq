import 'dart:convert';

import '../../domain/api_assets/api_asset_models.dart';
import '../../domain/authentication/request_authentication.dart';

/// 解析 OpenAPI 文档失败时抛出的异常，携带面向用户的错误信息。
class OpenApiImportException implements Exception {
  /// 创建携带错误信息的导入异常。
  const OpenApiImportException(this.message);

  /// 面向用户的错误说明。
  final String message;
}

/// 导入结果：包含生成的集合，以及摊平后的请求定义列表。
class OpenApiImportResult {
  /// 创建导入结果。
  const OpenApiImportResult({required this.collection});

  /// 导入得到的请求集合。
  final ApiCollection collection;

  /// 遍历所有文件夹，返回集合内全部请求定义。
  List<ApiRequestDefinition> get requests => [
    for (final folder in collection.folders)
      for (final request in folder.requests) request,
  ];
}

/// 将 OpenAPI 3.x JSON 文档解析为请求集合与文件夹结构的导入器。
class OpenApiRequestImporter {
  /// 创建 OpenAPI 导入器。
  const OpenApiRequestImporter();

  /// 解析源码，仅返回全部请求定义（不保留文件夹层级）。
  List<ApiRequestDefinition> parse(String source) =>
      parseCollection(source).requests;

  /// 解析源码为包含集合与文件夹结构的结果对象。
  OpenApiImportResult parseCollection(String source) {
    final root = _map(jsonDecode(source));
    final version = root['openapi'];
    final paths = root['paths'];
    // 仅支持 OpenAPI 3.x：校验版本前缀，并要求存在 paths 对象。
    if (version is! String || !version.startsWith('3.') || paths is! Map) {
      throw const OpenApiImportException(
        'Paste an OpenAPI 3.x JSON document with a paths object.',
      );
    }

    final collectionName = _collectionName(root['info']);
    final collectionId = 'collection-openapi-${_slug(collectionName)}';
    final server = _serverUrl(root['servers']);
    final authenticationSchemes = _authenticationSchemes(root['components']);
    final folders = <_FolderImportBuilder>[];

    // 遍历每个路径，为每个受支持的 HTTP 方法生成一个请求定义。
    for (final entry in paths.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      final path = entry.key as String;
      final pathItem = _map(entry.value);
      // 路径级参数先解析，随后与操作级参数合并（操作级优先级更高）。
      final pathParameters = _parameters(pathItem['parameters'], null);
      final folder = _folderFor(folders, path);

      for (final method in const ['get', 'post', 'put', 'patch', 'delete']) {
        final operation = pathItem[method];
        if (operation is! Map) continue;
        final map = _map(operation);
        final index = folder.requests.length + 1;
        final operationParameters = [
          ...pathParameters,
          ..._parameters(map['parameters'], null),
        ];
        final bodyTemplate = _body(map['requestBody']);
        final headers = _parametersFor(operationParameters, 'header');
        final hasContentType = headers.any(
          (header) => header.key.toLowerCase() == 'content-type',
        );
        final authentication = _authenticationFor(
          map.containsKey('security') ? map['security'] : root['security'],
          authenticationSchemes,
        );
        final request = ApiRequestDefinition(
          // 由方法、路径与序号组成 id，保证同一集合内唯一。
          id: 'openapi-$method-${_slug(path)}-$index',
          collectionId: collectionId,
          folderId: folder.id,
          name: _requestName(map, method, path),
          method: method.toUpperCase(),
          urlTemplate: _joinServerPath(server, path),
          queryParams: _parametersFor(operationParameters, 'query'),
          headers: [
            ...headers,
            if (bodyTemplate.isNotEmpty && !hasContentType)
              const ApiField(key: 'Content-Type', value: 'application/json'),
          ],
          bodyTemplate: bodyTemplate,
          authentication: authentication,
          authenticationSource: RequestAuthenticationSource.request,
          metadata: {
            'collectionName': collectionName,
            'folderName': folder.name,
            'source': 'openapi',
          },
        );
        folder.requests.add(request);
      }
    }

    // 只保留至少包含一个请求的文件夹，避免生成空目录。
    final apiFolders = [
      for (final folder in folders)
        if (folder.requests.isNotEmpty)
          ApiFolder(
            id: folder.id,
            name: folder.name,
            requests: List.unmodifiable(folder.requests),
          ),
    ];

    if (apiFolders.isEmpty) {
      throw const OpenApiImportException('No supported HTTP operations found.');
    }

    return OpenApiImportResult(
      collection: ApiCollection(
        id: collectionId,
        name: collectionName,
        folders: apiFolders,
      ),
    );
  }

  /// 将任意对象安全转换为 `Map<String, dynamic>`。
  Map<String, dynamic> _map(Object? value) =>
      Map<String, dynamic>.from(value as Map);

  /// 从 info.title 提取集合名称，缺失或为空时使用默认名。
  String _collectionName(Object? info) {
    if (info is Map) {
      final title = _map(info)['title'];
      if (title is String && title.trim().isNotEmpty) return title.trim();
    }
    return 'Imported OpenAPI';
  }

  /// 请求命名优先级：优先 summary，其次 operationId，最后回退到"方法 + 路径"。
  String _requestName(
    Map<String, dynamic> operation,
    String method,
    String path,
  ) {
    final summary = operation['summary'];
    if (summary is String && summary.trim().isNotEmpty) {
      return summary.trim();
    }
    final operationId = operation['operationId'];
    if (operationId is String && operationId.trim().isNotEmpty) {
      return operationId.trim();
    }
    return '${method.toUpperCase()} $path';
  }

  /// 按路径首段决定所属文件夹；同一首段的路径归入同一个文件夹。
  _FolderImportBuilder _folderFor(
    List<_FolderImportBuilder> folders,
    String path,
  ) {
    // 取路径中第一个非空、且非路径参数的段作为文件夹名候选。
    final segment = path
        .split('/')
        .where((part) => part.isNotEmpty && !part.startsWith('{'))
        .firstOrNull;
    final name = segment == null ? 'Root' : _titleCase(segment);
    final id = 'folder-openapi-${_slug(name)}';
    // 已存在同名文件夹则复用，避免重复创建。
    final existing = folders.where((item) => item.id == id);
    if (existing.isNotEmpty) return existing.first;
    final folder = _FolderImportBuilder(id: id, name: name);
    folders.add(folder);
    return folder;
  }

  /// 取 servers[0].url 作为基础地址，缺失时退回占位符 {{baseUrl}}。
  String _serverUrl(Object? servers) =>
      servers is List && servers.isNotEmpty && servers.first is Map
      ? (_map(servers.first)['url'] as String? ?? '{{baseUrl}}')
      : '{{baseUrl}}';

  /// 解析 components.securitySchemes 为认证方案映射。
  Map<String, _OpenApiAuthenticationScheme> _authenticationSchemes(
    Object? components,
  ) {
    if (components is! Map) return const {};
    final securitySchemes = _map(components)['securitySchemes'];
    if (securitySchemes is! Map) return const {};
    return {
      for (final entry in securitySchemes.entries)
        if (entry.key is String && entry.value is Map)
          entry.key as String: _OpenApiAuthenticationScheme.fromJson(
            _map(entry.value),
          ),
    };
  }

  /// 解析 security 需求并匹配为对应的请求认证配置。
  RequestAuthentication _authenticationFor(
    Object? security,
    Map<String, _OpenApiAuthenticationScheme> schemes,
  ) {
    if (security is! List) return const RequestAuthentication.none();
    for (final requirement in security.whereType<Map>()) {
      for (final name in _map(requirement).keys) {
        final scheme = schemes[name];
        if (scheme == null) continue;
        switch (scheme.type) {
          case RequestAuthenticationType.bearer:
            return const RequestAuthentication.bearer(
              '{{${AuthenticationVariableNames.bearerToken}}}',
            );
          case RequestAuthenticationType.basic:
            return const RequestAuthentication.basic(
              username: '{{${AuthenticationVariableNames.basicUsername}}}',
              password: '{{${AuthenticationVariableNames.basicPassword}}}',
            );
          case RequestAuthenticationType.apiKey:
            return RequestAuthentication.apiKey(
              apiKeyName: scheme.apiKeyName,
              apiKeyValue: '{{${AuthenticationVariableNames.apiKey}}}',
              apiKeyLocation: scheme.apiKeyLocation,
            );
          case RequestAuthenticationType.none:
            continue;
        }
      }
    }
    return const RequestAuthentication.none();
  }

  /// 拼接服务端基础地址与路径，避免出现双斜杠或缺失斜杠。
  String _joinServerPath(String server, String path) {
    if (server.endsWith('/') && path.startsWith('/')) {
      return '${server.substring(0, server.length - 1)}$path';
    }
    if (!server.endsWith('/') && !path.startsWith('/')) return '$server/$path';
    return '$server$path';
  }

  /// 过滤参数列表：[location] 为空表示不过滤位置，否则只保留该位置的参数。
  List<Map<String, dynamic>> _parameters(Object? input, String? location) =>
      input is! List
      ? const []
      : [
          for (final value in input.whereType<Map>())
            if (location == null || _map(value)['in'] == location) _map(value),
        ];

  /// 把位于指定位置（query/header 等）的参数转换为字段列表。
  List<ApiField> _parametersFor(
    List<Map<String, dynamic>> parameters,
    String location,
  ) => [
    for (final parameter in parameters)
      if (parameter['in'] == location && parameter['name'] is String)
        ApiField(
          key: parameter['name'] as String,
          value: _parameterValue(parameter),
        ),
  ];

  /// 提取参数示例值：优先取 example，其次取 schema 下的 default/example。
  String _parameterValue(Map<String, dynamic> parameter) {
    final example = parameter['example'];
    if (example != null) return '$example';
    final schema = parameter['schema'];
    if (schema is Map) {
      final map = _map(schema);
      if (map['default'] != null) return '${map['default']}';
      if (map['example'] != null) return '${map['example']}';
    }
    return '';
  }

  /// 从 requestBody 中提取 application/json 的示例，作为请求体模板。
  String _body(Object? input) {
    if (input is! Map) return '';
    final content = _map(input)['content'];
    if (content is! Map || content['application/json'] is! Map) return '';
    final media = _map(content['application/json']);
    final example = _jsonExample(media);
    return example == null
        ? ''
        : const JsonEncoder.withIndent('  ').convert(example);
  }

  /// 从 media type 对象中寻找示例：优先级为 example > examples > schema.example。
  Object? _jsonExample(Map<String, dynamic> media) {
    if (media.containsKey('example')) return media['example'];
    final examples = media['examples'];
    if (examples is Map && examples.isNotEmpty) {
      // 只取第一个命名示例，保证输出简洁。
      final first = examples.values.first;
      if (first is Map && _map(first).containsKey('value')) {
        return _map(first)['value'];
      }
      return first;
    }
    final schema = media['schema'];
    if (schema is Map && _map(schema).containsKey('example')) {
      return _map(schema)['example'];
    }
    return null;
  }

  /// 将字符串转为 URL/ID 安全的 slug：小写、非字母数字替换为连字符。
  String _slug(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'root' : slug;
  }

  /// 将下划线/连字符分隔的标识符转为标题形式（每个单词首字母大写）。
  String _titleCase(String value) {
    final words = value
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(' ')
        .where((part) => part.isNotEmpty);
    return words
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

/// 解析后的 OpenAPI 认证方案描述。
class _OpenApiAuthenticationScheme {
  /// 创建认证方案描述。
  const _OpenApiAuthenticationScheme({
    required this.type,
    this.apiKeyName = 'X-API-Key',
    this.apiKeyLocation = ApiKeyLocation.header,
  });

  /// 从 securitySchemes 条目解析认证方案，无法识别时回退为 none。
  factory _OpenApiAuthenticationScheme.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString();
    final httpScheme = json['scheme']?.toString().toLowerCase();
    if (type == 'http' && httpScheme == 'bearer') {
      return const _OpenApiAuthenticationScheme(
        type: RequestAuthenticationType.bearer,
      );
    }
    if (type == 'http' && httpScheme == 'basic') {
      return const _OpenApiAuthenticationScheme(
        type: RequestAuthenticationType.basic,
      );
    }
    if (type == 'apiKey') {
      return _OpenApiAuthenticationScheme(
        type: RequestAuthenticationType.apiKey,
        apiKeyName: json['name'] as String? ?? 'X-API-Key',
        apiKeyLocation: json['in'] == 'query'
            ? ApiKeyLocation.query
            : ApiKeyLocation.header,
      );
    }
    return const _OpenApiAuthenticationScheme(
      type: RequestAuthenticationType.none,
    );
  }

  /// 认证类型。
  final RequestAuthenticationType type;

  /// apiKey 认证使用的参数名。
  final String apiKeyName;

  /// apiKey 认证的传递位置（header 或 query）。
  final ApiKeyLocation apiKeyLocation;
}

/// 导入过程中使用的文件夹构建器，暂存请求直到最终汇总。
class _FolderImportBuilder {
  /// 创建文件夹构建器。
  _FolderImportBuilder({required this.id, required this.name});

  /// 文件夹唯一标识。
  final String id;

  /// 文件夹显示名称。
  final String name;

  /// 暂存的请求定义列表。
  final List<ApiRequestDefinition> requests = [];
}
