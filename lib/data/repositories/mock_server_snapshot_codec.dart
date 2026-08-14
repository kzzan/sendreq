import 'dart:convert';

import 'package:sendreq/domain/contract_publishing/mock_server.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';

/// `persistent-mock-servers-v1` 的当前唯一 JSON 格式。
abstract final class MockServerSnapshotCodec {
  static const version = 1;

  static String encodeDocument(Iterable<MockServer> servers) => jsonEncode({
    'version': version,
    'servers': [for (final server in servers) _server(server)],
  });

  static List<MockServer> decodeDocument(String source) {
    final root = Map<String, dynamic>.from(jsonDecode(source) as Map);
    if (root['version'] != version || root['servers'] is! List) {
      throw const FormatException('Unsupported Mock Server snapshot.');
    }
    final servers = <MockServer>[];
    for (final value in root['servers'] as List) {
      try {
        servers.add(_decodeServer(Map<String, dynamic>.from(value as Map)));
      } on Object {
        // 单条损坏不阻止其它已保存 Server 被恢复。
      }
    }
    return servers;
  }

  static Map<String, Object?> _server(MockServer value) => {
    'id': value.id,
    'name': value.name,
    'lifecycle': value.lifecycle.name,
    'createdAt': value.createdAt.toUtc().toIso8601String(),
    'updatedAt': value.updatedAt.toUtc().toIso8601String(),
    'source': _source(value.source),
    'endpoints': [for (final endpoint in value.endpoints) _endpoint(endpoint)],
  };

  static Map<String, Object?> _endpoint(MockEndpoint value) => {
    'id': value.id,
    'enabled': value.enabled,
    'source': _source(value.source),
    'matcher': _requestMatcher(value.matcher),
    'variants': [for (final variant in value.variants) _variant(variant)],
  };

  static Map<String, Object?> _variant(MockResponseVariant value) => {
    'id': value.id,
    'statusCode': value.statusCode,
    'headers': value.headers,
    'body': value.body,
    'delayMs': value.delayMs,
    'enabled': value.enabled,
    'source': _source(value.source),
    'matcher': {
      'headers': value.matcher.headers,
      'bodyEquals': value.matcher.bodyEquals,
    },
  };

  static Map<String, Object?> _requestMatcher(MockRequestMatcher value) => {
    'method': value.method,
    'path': value.path,
    'query': value.query,
    'headers': value.headers,
    'bodyEquals': value.bodyEquals,
  };

  static Map<String, Object?>? _source(MockSourceReference? value) =>
      value == null
      ? null
      : {
          'kind': value.kind.name,
          'resourceKind': value.resourceRef.kind.name,
          'resourceId': value.resourceRef.id,
          'label': value.label,
        };

  static MockServer _decodeServer(Map<String, dynamic> value) => MockServer(
    id: value['id'] as String,
    name: value['name'] as String,
    lifecycle: MockServerLifecycle.values.byName(value['lifecycle'] as String),
    createdAt: DateTime.parse(value['createdAt'] as String).toUtc(),
    updatedAt: DateTime.parse(value['updatedAt'] as String).toUtc(),
    source: _decodeSource(value['source']),
    endpoints: [
      for (final endpoint in value['endpoints'] as List)
        _decodeEndpoint(Map<String, dynamic>.from(endpoint as Map)),
    ],
  );

  static MockEndpoint _decodeEndpoint(Map<String, dynamic> value) =>
      MockEndpoint(
        id: value['id'] as String,
        enabled: value['enabled'] as bool,
        source: _decodeSource(value['source']),
        matcher: _decodeRequestMatcher(
          Map<String, dynamic>.from(value['matcher'] as Map),
        ),
        variants: [
          for (final variant in value['variants'] as List)
            _decodeVariant(Map<String, dynamic>.from(variant as Map)),
        ],
      );

  static MockResponseVariant _decodeVariant(Map<String, dynamic> value) {
    final matcher = Map<String, dynamic>.from(value['matcher'] as Map);
    return MockResponseVariant(
      id: value['id'] as String,
      statusCode: value['statusCode'] as int,
      headers: _strings(value['headers']),
      body: value['body'] as String,
      delayMs: value['delayMs'] as int,
      enabled: value['enabled'] as bool,
      source: _decodeSource(value['source']),
      matcher: MockVariantMatcher(
        headers: _strings(matcher['headers']),
        bodyEquals: matcher['bodyEquals'] as String?,
      ),
    );
  }

  static MockRequestMatcher _decodeRequestMatcher(Map<String, dynamic> value) =>
      MockRequestMatcher(
        method: value['method'] as String,
        path: value['path'] as String,
        query: _strings(value['query']),
        headers: _strings(value['headers']),
        bodyEquals: value['bodyEquals'] as String?,
      );

  static MockSourceReference? _decodeSource(Object? source) {
    if (source == null) return null;
    final value = Map<String, dynamic>.from(source as Map);
    final kindName = value['kind'] as String;
    if (!MockSourceKind.values.any((kind) => kind.name == kindName)) {
      return null;
    }
    final resourceKindName = value['resourceKind'] as String;
    if (!ResourceKind.values.any((kind) => kind.name == resourceKindName)) {
      return null;
    }
    return MockSourceReference(
      kind: MockSourceKind.values.byName(kindName),
      resourceRef: ResourceRef(
        kind: ResourceKind.values.byName(resourceKindName),
        id: value['resourceId'] as String,
      ),
      label: value['label'] as String?,
    );
  }

  static Map<String, String> _strings(Object? value) => {
    for (final entry in Map<String, dynamic>.from(
      value as Map? ?? const {},
    ).entries)
      entry.key: entry.value as String,
  };
}
