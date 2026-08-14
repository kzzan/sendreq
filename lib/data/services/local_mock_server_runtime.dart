import 'dart:convert';
import 'dart:io';

import 'package:sendreq/domain/contract_publishing/mock_server.dart';

/// 已保存 Mock Server 的显式回环运行时；运行状态仅保留在内存。
class LocalMockServerRuntime implements MockServerRuntimePort {
  LocalMockServerRuntime({MockServerBinder? bind})
    : _bind = bind ?? _bindLoopback;

  final MockServerBinder _bind;
  final Map<String, _RunningMockServer> _running = {};
  final Map<String, Future<MockServerRuntimeProjection>> _starting = {};
  final Map<String, MockServerRuntimeStatus> _statuses = {};

  @override
  MockServerRuntimeProjection projectionFor(String mockServerId) {
    final running = _running[mockServerId];
    return MockServerRuntimeProjection(
      status: _statuses[mockServerId] ?? MockServerRuntimeStatus.stopped,
      loopbackUrl: running == null
          ? null
          : 'http://127.0.0.1:${running.server.port}',
    );
  }

  @override
  void apply(MockServer server) {
    final running = _running[server.id];
    if (running != null) running.definition = server;
  }

  @override
  Future<void> dispose() async {
    for (final id in _running.keys.toList()) {
      await stop(id);
    }
  }

  @override
  Future<MockServerRuntimeProjection> start(MockServer server) {
    if (_running.containsKey(server.id)) {
      return Future.value(projectionFor(server.id));
    }
    final starting = _starting[server.id];
    if (starting != null) return starting;
    _statuses[server.id] = MockServerRuntimeStatus.starting;
    final start = _start(server);
    _starting[server.id] = start;
    return start;
  }

  @override
  Future<void> stop(String mockServerId) async {
    final starting = _starting[mockServerId];
    if (starting != null) {
      try {
        await starting;
      } on Object {
        // The failed start has already set a safe status below.
      }
    }
    final running = _running.remove(mockServerId);
    if (running == null) {
      _statuses[mockServerId] = MockServerRuntimeStatus.stopped;
      return;
    }
    _statuses[mockServerId] = MockServerRuntimeStatus.stopping;
    try {
      await running.server.close(force: true);
      _statuses[mockServerId] = MockServerRuntimeStatus.stopped;
    } on Object {
      _statuses[mockServerId] = MockServerRuntimeStatus.failed;
      rethrow;
    }
  }

  Future<MockServerRuntimeProjection> _start(MockServer server) async {
    try {
      final httpServer = await _bind();
      final running = _RunningMockServer(httpServer, server);
      _running[server.id] = running;
      httpServer.listen((request) => _handle(running, request));
      _statuses[server.id] = MockServerRuntimeStatus.running;
      return projectionFor(server.id);
    } on Object {
      _statuses[server.id] = MockServerRuntimeStatus.failed;
      rethrow;
    } finally {
      _starting.remove(server.id);
    }
  }

  Future<void> _handle(_RunningMockServer running, HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final headers = <String, String>{};
    request.headers.forEach((name, values) {
      headers[name] = values.join(',');
    });
    final input = MockRequestProjection(
      method: request.method,
      path: request.uri.path,
      query: request.uri.queryParameters,
      headers: headers,
      body: body,
    );
    final endpoint = MockServerMatching.firstMatchingEndpoint(
      running.definition,
      input,
    );
    if (endpoint == null) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': 'mock endpoint not found'}));
      await request.response.close();
      return;
    }
    final variant = MockServerMatching.selectVariant(endpoint, input);
    if (variant.delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: variant.delayMs));
    }
    request.response.statusCode = variant.statusCode;
    for (final entry in variant.headers.entries) {
      try {
        request.response.headers.set(entry.key, entry.value);
      } on HttpException {
        // 忽略不允许由 dart:io 设置的响应头。
      } on FormatException {
        // 模型已校验；额外防御平台响应头限制。
      }
    }
    if (request.response.headers.value(HttpHeaders.contentTypeHeader) == null) {
      request.response.headers.contentType = ContentType.json;
    }
    request.response.write(variant.body);
    await request.response.close();
  }
}

typedef MockServerBinder = Future<HttpServer> Function();

Future<HttpServer> _bindLoopback() =>
    HttpServer.bind(InternetAddress.loopbackIPv4, 0);

class _RunningMockServer {
  _RunningMockServer(this.server, this.definition);

  final HttpServer server;
  MockServer definition;
}
