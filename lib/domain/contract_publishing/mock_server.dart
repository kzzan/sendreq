import 'package:sendreq/domain/module_boundaries/boundary_models.dart';

/// 可持久化 Mock Server 的资产生命周期。运行状态始终是临时投影。
enum MockServerLifecycle { draft, active, disabled, archived }

/// 一个已保存 Server 的当前回环运行时状态，不参与持久化。
enum MockServerRuntimeStatus { stopped, starting, running, stopping, failed }

/// 安全来源引用允许指回的契约资产类型。
enum MockSourceKind { request, responseSnapshot }

/// 指向已脱敏输入的稳定来源引用，不包含原始 URL、Header 或正文。
class MockSourceReference {
  MockSourceReference({
    required this.kind,
    required this.resourceRef,
    this.label,
  }) {
    if (resourceRef.id.trim().isEmpty) {
      throw ArgumentError.value(
        resourceRef.id,
        'resourceRef.id',
        'Cannot be empty.',
      );
    }
    if (!_allows(kind, resourceRef.kind)) {
      throw ArgumentError.value(
        resourceRef.kind,
        'resourceRef.kind',
        'Does not match the declared Mock source kind.',
      );
    }
  }

  final MockSourceKind kind;
  final ResourceRef resourceRef;
  final String? label;

  static bool _allows(MockSourceKind kind, ResourceKind resourceKind) =>
      switch (kind) {
        MockSourceKind.request =>
          resourceKind == ResourceKind.request ||
              resourceKind == ResourceKind.requestTab,
        MockSourceKind.responseSnapshot =>
          resourceKind == ResourceKind.responseSnapshot,
      };
}

/// 一个请求条件仅支持精确、安全的匹配，不支持正则或脚本。
class MockRequestMatcher {
  MockRequestMatcher({
    required String method,
    required String path,
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    this.bodyEquals,
  }) : method = _normalizeMethod(method),
       path = _normalizePath(path),
       query = _immutablePredicateMap(query, fieldName: 'query'),
       headers = _immutableHeaders(headers) {
    if (bodyEquals != null && bodyEquals!.contains('\u0000')) {
      throw ArgumentError.value(
        bodyEquals,
        'bodyEquals',
        'Cannot contain NUL.',
      );
    }
  }

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, String> headers;
  final String? bodyEquals;

  MockRequestMatcher copyWith({
    String? method,
    String? path,
    Map<String, String>? query,
    Map<String, String>? headers,
    String? bodyEquals,
    bool clearBodyEquals = false,
  }) => MockRequestMatcher(
    method: method ?? this.method,
    path: path ?? this.path,
    query: query ?? this.query,
    headers: headers ?? this.headers,
    bodyEquals: clearBodyEquals ? null : bodyEquals ?? this.bodyEquals,
  );

  static String _normalizeMethod(String value) {
    final method = value.trim().toUpperCase();
    if (!const {
      'GET',
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
      'HEAD',
      'OPTIONS',
    }.contains(method)) {
      throw ArgumentError.value(value, 'method', 'Unsupported HTTP method.');
    }
    return method;
  }

  static String _normalizePath(String value) {
    final path = value.trim();
    if (!path.startsWith('/') || path.contains('?') || path.contains('#')) {
      throw ArgumentError.value(
        value,
        'path',
        'Must be an absolute path without query or fragment.',
      );
    }
    final normalized = Uri(path: path).path;
    if (normalized.isEmpty || normalized.contains('//')) {
      throw ArgumentError.value(value, 'path', 'Must be a normalized path.');
    }
    return normalized;
  }

  static Map<String, String> _immutablePredicateMap(
    Map<String, String> source, {
    required String fieldName,
  }) {
    final result = <String, String>{};
    for (final entry in source.entries) {
      final key = entry.key.trim();
      if (key.isEmpty || entry.value.contains('\u0000')) {
        throw ArgumentError.value(
          source,
          fieldName,
          'Contains an invalid predicate.',
        );
      }
      result[key] = entry.value;
    }
    return Map.unmodifiable(result);
  }

  static Map<String, String> _immutableHeaders(Map<String, String> source) {
    final result = <String, String>{};
    for (final entry in source.entries) {
      final key = entry.key.trim().toLowerCase();
      if (key.isEmpty ||
          _unsafeHeaderNames.contains(key) ||
          entry.value.contains('\u0000')) {
        throw ArgumentError.value(
          source,
          'headers',
          'Contains an unsafe header predicate.',
        );
      }
      result[key] = entry.value;
    }
    return Map.unmodifiable(result);
  }
}

/// 响应变体的请求侧精确谓词。空谓词即默认变体。
class MockVariantMatcher {
  MockVariantMatcher({Map<String, String> headers = const {}, this.bodyEquals})
    : headers = MockRequestMatcher._immutableHeaders(headers) {
    if (bodyEquals != null && bodyEquals!.contains('\u0000')) {
      throw ArgumentError.value(
        bodyEquals,
        'bodyEquals',
        'Cannot contain NUL.',
      );
    }
  }

  final Map<String, String> headers;
  final String? bodyEquals;

  bool get isDefault => headers.isEmpty && bodyEquals == null;
}

/// 一个端点的有序响应候选项。第一个默认或匹配的变体被选用。
class MockResponseVariant {
  MockResponseVariant({
    required this.id,
    required this.statusCode,
    Map<String, String> headers = const {},
    this.body = '',
    this.delayMs = 0,
    this.enabled = true,
    MockVariantMatcher? matcher,
    this.source,
  }) : headers = _immutableResponseHeaders(headers),
       matcher = matcher ?? MockVariantMatcher() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Cannot be empty.');
    }
    if (statusCode < 100 || statusCode > 599) {
      throw ArgumentError.value(
        statusCode,
        'statusCode',
        'Must be between 100 and 599.',
      );
    }
    if (delayMs < 0 || delayMs > maxDelayMs) {
      throw ArgumentError.value(
        delayMs,
        'delayMs',
        'Must be between 0 and $maxDelayMs.',
      );
    }
    if (body.contains('\u0000')) {
      throw ArgumentError.value(body, 'body', 'Cannot contain NUL.');
    }
  }

  static const maxDelayMs = 30 * 1000;

  final String id;
  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final int delayMs;
  final bool enabled;
  final MockVariantMatcher matcher;
  final MockSourceReference? source;

  MockResponseVariant copyWith({
    String? id,
    int? statusCode,
    Map<String, String>? headers,
    String? body,
    int? delayMs,
    bool? enabled,
    MockVariantMatcher? matcher,
    MockSourceReference? source,
    bool clearSource = false,
  }) => MockResponseVariant(
    id: id ?? this.id,
    statusCode: statusCode ?? this.statusCode,
    headers: headers ?? this.headers,
    body: body ?? this.body,
    delayMs: delayMs ?? this.delayMs,
    enabled: enabled ?? this.enabled,
    matcher: matcher ?? this.matcher,
    source: clearSource ? null : source ?? this.source,
  );
}

/// Server 内按数组顺序匹配的一个可编辑端点。
class MockEndpoint {
  MockEndpoint({
    required this.id,
    required this.matcher,
    required List<MockResponseVariant> variants,
    this.enabled = true,
    this.source,
  }) : variants = List.unmodifiable(variants) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Cannot be empty.');
    }
    if (variants.isEmpty) {
      throw ArgumentError.value(
        variants,
        'variants',
        'Requires at least one response variant.',
      );
    }
    final ids = variants.map((variant) => variant.id).toSet();
    if (ids.length != variants.length) {
      throw ArgumentError.value(
        variants,
        'variants',
        'Variant identifiers must be unique.',
      );
    }
    final defaultVariants = variants
        .where((variant) => variant.matcher.isDefault)
        .length;
    if (defaultVariants != 1) {
      throw ArgumentError.value(
        variants,
        'variants',
        'Requires exactly one default response variant.',
      );
    }
  }

  final String id;
  final MockRequestMatcher matcher;
  final List<MockResponseVariant> variants;
  final bool enabled;
  final MockSourceReference? source;

  MockEndpoint copyWith({
    String? id,
    MockRequestMatcher? matcher,
    List<MockResponseVariant>? variants,
    bool? enabled,
    MockSourceReference? source,
    bool clearSource = false,
  }) => MockEndpoint(
    id: id ?? this.id,
    matcher: matcher ?? this.matcher,
    variants: variants ?? this.variants,
    enabled: enabled ?? this.enabled,
    source: clearSource ? null : source ?? this.source,
  );
}

/// 可保存、可编辑的本地 Mock Server 定义。端点顺序即稳定匹配优先级。
class MockServer {
  MockServer({
    required this.id,
    required this.name,
    required List<MockEndpoint> endpoints,
    required this.createdAt,
    required this.updatedAt,
    this.lifecycle = MockServerLifecycle.draft,
    this.source,
  }) : endpoints = List.unmodifiable(endpoints) {
    if (id.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('Mock Server id and name cannot be empty.');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError.value(
        updatedAt,
        'updatedAt',
        'Cannot precede createdAt.',
      );
    }
    final ids = endpoints.map((endpoint) => endpoint.id).toSet();
    if (ids.length != endpoints.length) {
      throw ArgumentError.value(
        endpoints,
        'endpoints',
        'Endpoint identifiers must be unique.',
      );
    }
  }

  final String id;
  final String name;
  final List<MockEndpoint> endpoints;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MockServerLifecycle lifecycle;
  final MockSourceReference? source;

  MockServer copyWith({
    String? id,
    String? name,
    List<MockEndpoint>? endpoints,
    DateTime? createdAt,
    DateTime? updatedAt,
    MockServerLifecycle? lifecycle,
    MockSourceReference? source,
    bool clearSource = false,
  }) => MockServer(
    id: id ?? this.id,
    name: name ?? this.name,
    endpoints: endpoints ?? this.endpoints,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lifecycle: lifecycle ?? this.lifecycle,
    source: clearSource ? null : source ?? this.source,
  );
}

/// 给 Shell 渲染的临时运行时状态。地址只在 running 时存在。
class MockServerRuntimeProjection {
  const MockServerRuntimeProjection({required this.status, this.loopbackUrl})
    : assert(
        status == MockServerRuntimeStatus.running || loopbackUrl == null,
        'Only running Mock Servers may expose a loopback URL.',
      );

  final MockServerRuntimeStatus status;
  final String? loopbackUrl;
}

/// 已保存资产和临时运行状态的不可变显示投影。
class MockServerProjection {
  const MockServerProjection({required this.server, required this.runtime});

  final MockServer server;
  final MockServerRuntimeProjection runtime;
}

/// 进入 Mock Server 的已脱敏请求投影。它不包含连接或 transport 状态。
class MockRequestProjection {
  MockRequestProjection({
    required String method,
    required String path,
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    this.body = '',
  }) : method = MockRequestMatcher._normalizeMethod(method),
       path = MockRequestMatcher._normalizePath(path),
       query = MockRequestMatcher._immutablePredicateMap(
         query,
         fieldName: 'query',
       ),
       headers = MockRequestMatcher._immutableHeaders(headers) {
    if (body.contains('\u0000')) {
      throw ArgumentError.value(body, 'body', 'Cannot contain NUL.');
    }
  }

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, String> headers;
  final String body;
}

/// 纯领域匹配器，确保端点与响应变体选择在所有运行时中一致。
abstract final class MockServerMatching {
  static MockEndpoint? firstMatchingEndpoint(
    MockServer server,
    MockRequestProjection request,
  ) {
    for (final endpoint in server.endpoints) {
      if (endpoint.enabled && _matchesEndpoint(endpoint.matcher, request)) {
        return endpoint;
      }
    }
    return null;
  }

  static MockResponseVariant selectVariant(
    MockEndpoint endpoint,
    MockRequestProjection request,
  ) {
    MockResponseVariant? fallback;
    for (final variant in endpoint.variants) {
      if (!variant.enabled) continue;
      if (variant.matcher.isDefault) {
        fallback ??= variant;
        continue;
      }
      if (_matchesVariant(variant.matcher, request)) return variant;
    }
    if (fallback == null) {
      throw StateError(
        'An enabled endpoint requires an enabled default variant.',
      );
    }
    return fallback;
  }

  static bool _matchesEndpoint(
    MockRequestMatcher matcher,
    MockRequestProjection request,
  ) =>
      matcher.method == request.method &&
      matcher.path == request.path &&
      _containsAll(request.query, matcher.query) &&
      _containsAll(request.headers, matcher.headers) &&
      (matcher.bodyEquals == null || matcher.bodyEquals == request.body);

  static bool _matchesVariant(
    MockVariantMatcher matcher,
    MockRequestProjection request,
  ) =>
      _containsAll(request.headers, matcher.headers) &&
      (matcher.bodyEquals == null || matcher.bodyEquals == request.body);

  static bool _containsAll(
    Map<String, String> actual,
    Map<String, String> expected,
  ) {
    for (final entry in expected.entries) {
      if (actual[entry.key] != entry.value) return false;
    }
    return true;
  }
}

/// 已保存资产的可验证状态转换。归档项可显式恢复为草稿。
abstract final class MockServerLifecycleTransitions {
  static bool canTransition(
    MockServerLifecycle from,
    MockServerLifecycle to,
  ) => switch (from) {
    MockServerLifecycle.draft =>
      to == MockServerLifecycle.active ||
          to == MockServerLifecycle.disabled ||
          to == MockServerLifecycle.archived,
    MockServerLifecycle.active =>
      to == MockServerLifecycle.disabled || to == MockServerLifecycle.archived,
    MockServerLifecycle.disabled =>
      to == MockServerLifecycle.active || to == MockServerLifecycle.archived,
    MockServerLifecycle.archived => to == MockServerLifecycle.draft,
  };

  static MockServer transition(
    MockServer server,
    MockServerLifecycle target, {
    required DateTime updatedAt,
  }) {
    if (!canTransition(server.lifecycle, target)) {
      throw StateError('Invalid Mock Server lifecycle transition.');
    }
    return server.copyWith(lifecycle: target, updatedAt: updatedAt.toUtc());
  }
}

/// 本地回环 Mock Server 生命周期的 M5 端口。
///
/// 实现拥有监听器与 socket；调用者只能看到短生命周期的安全投影。
abstract interface class MockServerRuntimePort {
  MockServerRuntimeProjection projectionFor(String mockServerId);

  Future<MockServerRuntimeProjection> start(MockServer server);

  void apply(MockServer server);

  Future<void> stop(String mockServerId);

  Future<void> dispose();
}

const _unsafeHeaderNames = {
  'authorization',
  'cookie',
  'set-cookie',
  'proxy-authorization',
};

Map<String, String> _immutableResponseHeaders(Map<String, String> source) {
  final result = <String, String>{};
  for (final entry in source.entries) {
    final key = entry.key.trim().toLowerCase();
    if (key.isEmpty ||
        _unsafeHeaderNames.contains(key) ||
        entry.value.contains('\u0000')) {
      throw ArgumentError.value(
        source,
        'headers',
        'Contains an unsafe response header.',
      );
    }
    result[key] = entry.value;
  }
  return Map.unmodifiable(result);
}
