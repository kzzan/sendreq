import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/services/local_mock_server_runtime.dart';
import 'package:sendreq/domain/contract_publishing/mock_server.dart';

void main() {
  test(
    'runs saved multi-endpoint Servers only on loopback and stops explicitly',
    () async {
      final runtime = LocalMockServerRuntime();
      addTearDown(runtime.dispose);
      final server = MockServer(
        id: 'mock-1',
        name: 'Users',
        createdAt: DateTime.utc(2026, 8, 11),
        updatedAt: DateTime.utc(2026, 8, 11),
        endpoints: [
          _endpoint('users', '/users', '{"users":[]}'),
          _endpoint('health', '/health', '{"ok":true}'),
        ],
      );

      final projection = await runtime.start(server);
      final client = HttpClient();
      addTearDown(client.close);
      final base = Uri.parse(projection.loopbackUrl!);
      final response = await (await client.getUrl(
        base.replace(path: '/health'),
      )).close();
      expect(response.statusCode, 200);
      expect(
        await response.transform(const Utf8Decoder()).join(),
        '{"ok":true}',
      );

      await runtime.stop(server.id);
      expect(
        runtime.projectionFor(server.id).status,
        MockServerRuntimeStatus.stopped,
      );
      expect(runtime.projectionFor(server.id).loopbackUrl, isNull);
    },
  );

  test(
    'matches ordered endpoints and request predicates deterministically',
    () async {
      final runtime = LocalMockServerRuntime();
      addTearDown(runtime.dispose);
      final server = _server(
        endpoints: [
          MockEndpoint(
            id: 'specific',
            matcher: MockRequestMatcher(
              method: 'POST',
              path: '/v1/items',
              query: const {'scope': 'private'},
              headers: const {'x-tenant': 'acme'},
              bodyEquals: '{"id":7}',
            ),
            variants: [
              MockResponseVariant(
                id: 'specific-default',
                statusCode: 201,
                body: '{"matched":"specific"}',
              ),
            ],
          ),
          MockEndpoint(
            id: 'fallback',
            matcher: MockRequestMatcher(method: 'POST', path: '/v1/items'),
            variants: [
              MockResponseVariant(
                id: 'fallback-default',
                statusCode: 200,
                body: '{"matched":"fallback"}',
              ),
            ],
          ),
        ],
      );
      final base = Uri.parse((await runtime.start(server)).loopbackUrl!);

      final specific = await _request(
        base.replace(
          path: '/v1/items',
          queryParameters: const {'scope': 'private'},
        ),
        method: 'POST',
        headers: const {'x-tenant': 'acme'},
        body: '{"id":7}',
      );
      final fallback = await _request(
        base.replace(path: '/v1/items'),
        method: 'POST',
        body: '{"id":8}',
      );

      expect(specific.statusCode, HttpStatus.created);
      expect(specific.body, '{"matched":"specific"}');
      expect(fallback.statusCode, HttpStatus.ok);
      expect(fallback.body, '{"matched":"fallback"}');
    },
  );

  test(
    'selects matching response variants before its default fallback',
    () async {
      final runtime = LocalMockServerRuntime();
      addTearDown(runtime.dispose);
      final server = _server(
        endpoints: [
          MockEndpoint(
            id: 'items',
            matcher: MockRequestMatcher(method: 'POST', path: '/items'),
            variants: [
              MockResponseVariant(
                id: 'default',
                statusCode: 200,
                body: '{"mode":"default"}',
              ),
              MockResponseVariant(
                id: 'preview',
                statusCode: 202,
                headers: const {'x-mock-variant': 'preview'},
                body: '{"mode":"preview"}',
                matcher: MockVariantMatcher(
                  headers: const {'x-mode': 'preview'},
                  bodyEquals: '{"preview":true}',
                ),
              ),
            ],
          ),
        ],
      );
      final base = Uri.parse((await runtime.start(server)).loopbackUrl!);

      final selected = await _request(
        base.replace(path: '/items'),
        method: 'POST',
        headers: const {'x-mode': 'preview'},
        body: '{"preview":true}',
      );
      final fallback = await _request(
        base.replace(path: '/items'),
        method: 'POST',
        headers: const {'x-mode': 'preview'},
        body: '{"preview":false}',
      );

      expect(selected.statusCode, HttpStatus.accepted);
      expect(selected.headers['x-mock-variant'], 'preview');
      expect(selected.body, '{"mode":"preview"}');
      expect(fallback.statusCode, HttpStatus.ok);
      expect(fallback.body, '{"mode":"default"}');
    },
  );

  test(
    'returns a sanitized JSON 404 and applies bounded response delay',
    () async {
      final runtime = LocalMockServerRuntime();
      addTearDown(runtime.dispose);
      final server = _server(
        endpoints: [
          MockEndpoint(
            id: 'slow',
            matcher: MockRequestMatcher(method: 'GET', path: '/slow'),
            variants: [
              MockResponseVariant(
                id: 'slow-default',
                statusCode: 200,
                body: '{"ready":true}',
                delayMs: 60,
              ),
            ],
          ),
        ],
      );
      final base = Uri.parse((await runtime.start(server)).loopbackUrl!);

      final stopwatch = Stopwatch()..start();
      final delayed = await _request(base.replace(path: '/slow'));
      stopwatch.stop();
      final missing = await _request(base.replace(path: '/not-present'));

      expect(delayed.statusCode, HttpStatus.ok);
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(45));
      expect(missing.statusCode, HttpStatus.notFound);
      expect(missing.headers['content-type'], startsWith('application/json'));
      expect(jsonDecode(missing.body), {'error': 'mock endpoint not found'});
      expect(missing.body, isNot(contains('authorization')));
    },
  );

  test(
    'reuses an existing start, applies edits, and clears its URL on stop',
    () async {
      final runtime = LocalMockServerRuntime();
      addTearDown(runtime.dispose);
      final initial = _server(
        endpoints: [_endpoint('health', '/health', 'old')],
      );

      final first = runtime.start(initial);
      final second = runtime.start(initial);
      expect(identical(first, second), isTrue);
      final projection = await first;
      runtime.apply(
        initial.copyWith(
          endpoints: [_endpoint('health', '/health', 'new')],
          updatedAt: initial.updatedAt.add(const Duration(seconds: 1)),
        ),
      );
      final reply = await _request(
        Uri.parse(projection.loopbackUrl!).replace(path: '/health'),
      );

      expect(reply.body, 'new');
      await runtime.stop(initial.id);
      expect(runtime.projectionFor(initial.id).loopbackUrl, isNull);
      expect(
        runtime.projectionFor(initial.id).status,
        MockServerRuntimeStatus.stopped,
      );
    },
  );

  test('leaves no URL when the loopback listener cannot bind', () async {
    final runtime = LocalMockServerRuntime(
      bind: () =>
          Future<HttpServer>.error(const SocketException('unavailable')),
    );
    addTearDown(runtime.dispose);
    final server = _server(endpoints: [_endpoint('health', '/health', 'ok')]);

    await expectLater(runtime.start(server), throwsA(isA<SocketException>()));
    expect(
      runtime.projectionFor(server.id).status,
      MockServerRuntimeStatus.failed,
    );
    expect(runtime.projectionFor(server.id).loopbackUrl, isNull);

    await runtime.stop(server.id);
    expect(
      runtime.projectionFor(server.id).status,
      MockServerRuntimeStatus.stopped,
    );
  });

  test(
    'a recreated runtime presents saved Servers as stopped until started',
    () {
      final saved = _server(endpoints: [_endpoint('health', '/health', 'ok')]);
      final runtime = LocalMockServerRuntime();
      addTearDown(runtime.dispose);

      final projection = runtime.projectionFor(saved.id);

      expect(projection.status, MockServerRuntimeStatus.stopped);
      expect(projection.loopbackUrl, isNull);
    },
  );
}

MockEndpoint _endpoint(String id, String path, String body) => MockEndpoint(
  id: id,
  matcher: MockRequestMatcher(method: 'GET', path: path),
  variants: [
    MockResponseVariant(id: '$id-default', statusCode: 200, body: body),
  ],
);

MockServer _server({required List<MockEndpoint> endpoints}) => MockServer(
  id: 'mock-1',
  name: 'Test server',
  createdAt: DateTime.utc(2026, 8, 11),
  updatedAt: DateTime.utc(2026, 8, 11),
  endpoints: endpoints,
);

class _Response {
  const _Response({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String body;
}

Future<_Response> _request(
  Uri uri, {
  String method = 'GET',
  Map<String, String> headers = const {},
  String body = '',
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    headers.forEach(request.headers.set);
    if (body.isNotEmpty) request.write(body);
    final response = await request.close();
    final responseHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      responseHeaders[name] = values.join(',');
    });
    return _Response(
      statusCode: response.statusCode,
      headers: responseHeaders,
      body: await response.transform(utf8.decoder).join(),
    );
  } finally {
    client.close(force: true);
  }
}
