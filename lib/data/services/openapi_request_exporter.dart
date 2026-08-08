import 'dart:convert';

import '../../domain/api_assets/api_asset_models.dart';
import '../../domain/authentication/request_authentication.dart';

/// 将工作区中的 HTTP 请求导出为 OpenAPI 3.0 JSON 文档。
class OpenApiRequestExporter {
  /// 创建 OpenAPI 请求导出器。
  const OpenApiRequestExporter();

  /// 生成格式化的 OpenAPI 3.0.3 JSON。
  ///
  /// 仅 OpenAPI 可表达的 HTTP 请求会被导出；WebSocket 与 gRPC 请求会保留
  /// 在工作区中，但不会混入 HTTP API 定义。
  String export({
    required List<ApiRequestDefinition> requests,
    String title = 'sendreq API',
  }) => const JsonEncoder.withIndent(
    '  ',
  ).convert(toJson(requests: requests, title: title));

  /// 生成可供测试或进一步处理的 OpenAPI JSON 对象。
  Map<String, Object?> toJson({
    required List<ApiRequestDefinition> requests,
    String title = 'sendreq API',
  }) {
    final httpRequests = requests
        .where((request) => request.protocol == ApiRequestProtocol.http)
        .toList(growable: false);
    if (httpRequests.isEmpty) {
      throw StateError('No HTTP requests are available to export.');
    }

    final endpoints = [
      for (final request in httpRequests) _endpointFor(request),
    ];
    final commonServer = _commonServer(endpoints);
    final paths = <String, Object?>{};
    final tagNames = <String>{};

    for (final endpoint in endpoints) {
      final request = endpoint.request;
      final pathItem =
          (paths[endpoint.path] ?? <String, Object?>{}) as Map<String, Object?>;
      final folder = request.metadata['folderName'];
      if (folder != null && folder.isNotEmpty) tagNames.add(folder);
      // 与全局 servers 一致时省略 per-operation 覆盖，保持输出简洁。
      pathItem[request.method.toLowerCase()] = _operationFor(
        request,
        folder: folder,
        server: commonServer == endpoint.server ? null : endpoint.server,
      );
      paths[endpoint.path] = pathItem;
    }

    return {
      'openapi': '3.0.3',
      'info': {'title': title, 'version': '1.0.0'},
      if (commonServer != null) 'servers': [_server(commonServer)],
      if (httpRequests.any(
        (request) =>
            request.authentication.type != RequestAuthenticationType.none,
      ))
        'components': {'securitySchemes': _securitySchemes(httpRequests)},
      if (tagNames.isNotEmpty)
        'tags': [
          for (final name in tagNames) {'name': name},
        ],
      'paths': paths,
    };
  }

  /// 为单个请求生成 OpenAPI operation 定义。
  Map<String, Object?> _operationFor(
    ApiRequestDefinition request, {
    required String? folder,
    required String? server,
  }) {
    final parameters = <Object?>[
      for (final parameter in request.queryParams)
        if (parameter.enabled && parameter.key.trim().isNotEmpty)
          _parameter(parameter, 'query'),
      for (final header in request.headers)
        if (header.enabled &&
            header.key.trim().isNotEmpty &&
            header.key.toLowerCase() != 'content-type')
          _parameter(header, 'header'),
    ];
    final contentType = _contentType(request.headers);
    return {
      'summary': request.name,
      if (folder != null && folder.isNotEmpty) 'tags': [folder],
      if (server != null) 'servers': [_server(server)],
      if (request.authentication.type != RequestAuthenticationType.none)
        'security': [_securityRequirement(request.authentication)],
      if (parameters.isNotEmpty) 'parameters': parameters,
      if (request.bodyTemplate.trim().isNotEmpty)
        'requestBody': {
          'content': {
            contentType: {
              'example': _bodyExample(request.bodyTemplate, contentType),
            },
          },
        },
      'responses': {
        '200': {'description': 'Successful response'},
      },
    };
  }

  /// 将字段转换为 query/header 位置的参数定义。
  Map<String, Object?> _parameter(ApiField field, String location) => {
    'name': field.key,
    'in': location,
    'required': false,
    'schema': {'type': 'string'},
    if (!field.secretReference && field.value.isNotEmpty)
      'example': field.value,
  };

  /// 汇总全部请求用到的认证方式为安全方案定义。
  Map<String, Object?> _securitySchemes(List<ApiRequestDefinition> requests) =>
      {
        if (requests.any((request) => request.authentication.usesBearerToken))
          'bearerAuth': {'type': 'http', 'scheme': 'bearer'},
        if (requests.any(
          (request) => request.authentication.usesBasicAuthentication,
        ))
          'basicAuth': {'type': 'http', 'scheme': 'basic'},
        for (final authentication in requests.map(
          (request) => request.authentication,
        ))
          if (authentication.usesApiKey)
            _apiKeySchemeName(authentication): {
              'type': 'apiKey',
              'name': authentication.apiKeyName,
              'in': authentication.apiKeyLocation.storageValue,
            },
      };

  /// 生成唯一且符合 OpenAPI 命名规则的 apiKey 方案名。
  String _apiKeySchemeName(RequestAuthentication authentication) {
    final location = authentication.apiKeyLocation == ApiKeyLocation.header
        ? 'Header'
        : 'Query';
    final normalized = authentication.apiKeyName.replaceAll(
      RegExp(r'[^A-Za-z0-9_]'),
      '_',
    );
    return 'apiKey${location}_${normalized.isEmpty ? 'value' : normalized}';
  }

  /// 将请求认证映射为 operation 的 security 声明。
  Map<String, Object?> _securityRequirement(
    RequestAuthentication authentication,
  ) {
    final scheme = switch (authentication.type) {
      RequestAuthenticationType.bearer => 'bearerAuth',
      RequestAuthenticationType.basic => 'basicAuth',
      RequestAuthenticationType.apiKey => _apiKeySchemeName(authentication),
      RequestAuthenticationType.none => 'none',
    };
    return {scheme: <Object?>[]};
  }

  /// 构造 OpenAPI servers 条目。
  Map<String, String> _server(String url) => {'url': url};

  /// 提取请求声明的 Content-Type，未声明时回退为 application/json。
  String _contentType(List<ApiField> headers) {
    for (final header in headers) {
      if (header.enabled &&
          header.key.toLowerCase() == 'content-type' &&
          header.value.trim().isNotEmpty) {
        return header.value.trim();
      }
    }
    return 'application/json';
  }

  /// 将请求体按内容类型转为示例对象；JSON 优先解析为结构化值。
  Object _bodyExample(String body, String contentType) {
    if (contentType.toLowerCase().contains('json')) {
      try {
        return jsonDecode(body);
      } on FormatException {
        // 无效 JSON 仍作为字符串示例导出，避免丢弃草稿内容。
      }
    }
    return body;
  }

  /// 所有端点服务地址一致时返回公共 servers 项，否则返回 null。
  String? _commonServer(List<_OpenApiEndpoint> endpoints) {
    final first = endpoints.first.server;
    return endpoints.every((endpoint) => endpoint.server == first)
        ? first
        : null;
  }

  /// 从 URL 模板中拆分出服务端地址与请求路径。
  _OpenApiEndpoint _endpointFor(ApiRequestDefinition request) {
    final template = request.urlTemplate;
    final tokenEnd = template.startsWith('{{') ? template.indexOf('}}') : -1;
    if (tokenEnd >= 0) {
      return _OpenApiEndpoint(
        request: request,
        server: template.substring(0, tokenEnd + 2),
        path: _pathOnly(template.substring(tokenEnd + 2)),
      );
    }

    final match = RegExp(
      r'^(https?://[^/?#]+)(/[^?#]*)?(?:[?#].*)?$',
    ).firstMatch(template);
    return _OpenApiEndpoint(
      request: request,
      server: match?.group(1),
      path: _pathOnly(match?.group(2) ?? template),
    );
  }

  /// 剥离查询串与片段，返回以 / 开头的规范化路径。
  String _pathOnly(String value) {
    final queryStart = value.indexOf('?');
    final fragmentStart = value.indexOf('#');
    final end = [queryStart, fragmentStart]
        .where((index) => index >= 0)
        .fold(value.length, (end, index) => index < end ? index : end);
    final path = value.substring(0, end);
    if (path.isEmpty) return '/';
    return path.startsWith('/') ? path : '/$path';
  }
}

/// 内部端点表示：请求及其拆分出的服务端地址与路径。
class _OpenApiEndpoint {
  /// 创建端点描述。
  const _OpenApiEndpoint({
    required this.request,
    required this.server,
    required this.path,
  });

  /// 对应的请求定义。
  final ApiRequestDefinition request;

  /// 服务端基础地址；null 表示继承全局 servers。
  final String? server;

  /// 请求路径（以 / 开头）。
  final String path;
}
