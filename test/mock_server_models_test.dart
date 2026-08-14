import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/domain/contract_publishing/mock_server.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';

void main() {
  final source = MockSourceReference(
    kind: MockSourceKind.responseSnapshot,
    resourceRef: const ResourceRef(
      kind: ResourceKind.responseSnapshot,
      id: 'response-1',
    ),
  );

  test('Mock Server preserves explicit endpoint and variant priority', () {
    final first = MockEndpoint(
      id: 'endpoint-first',
      matcher: MockRequestMatcher(method: 'get', path: '/v1/widgets'),
      variants: [
        MockResponseVariant(
          id: 'variant-first',
          statusCode: 200,
          source: source,
        ),
        MockResponseVariant(
          id: 'variant-second',
          statusCode: 202,
          matcher: MockVariantMatcher(headers: const {'x-mode': 'async'}),
        ),
      ],
      source: source,
    );
    final second = MockEndpoint(
      id: 'endpoint-second',
      matcher: MockRequestMatcher(method: 'GET', path: '/v1/widgets'),
      variants: [MockResponseVariant(id: 'variant-third', statusCode: 200)],
    );
    final server = MockServer(
      id: 'mock-1',
      name: 'Widgets',
      endpoints: [first, second],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      source: source,
    );

    expect(server.endpoints.map((endpoint) => endpoint.id), [
      'endpoint-first',
      'endpoint-second',
    ]);
    expect(server.endpoints.first.variants.map((variant) => variant.id), [
      'variant-first',
      'variant-second',
    ]);
    expect(() => server.endpoints.add(first), throwsUnsupportedError);
    expect(
      () => first.variants.add(first.variants.first),
      throwsUnsupportedError,
    );
  });

  test(
    'Matchers normalize supported method, path and header predicate names',
    () {
      final matcher = MockRequestMatcher(
        method: ' post ',
        path: '/v1/widgets',
        query: const {'preview': 'true'},
        headers: const {'X-Mode': 'test'},
        bodyEquals: '{"draft":true}',
      );

      expect(matcher.method, 'POST');
      expect(matcher.path, '/v1/widgets');
      expect(matcher.headers, {'x-mode': 'test'});
      expect(matcher.query, {'preview': 'true'});
    },
  );

  test('Mock models reject unsafe, ambiguous and invalid persisted values', () {
    expect(
      () => MockRequestMatcher(method: 'TRACE', path: '/safe'),
      throwsArgumentError,
    );
    expect(
      () => MockRequestMatcher(method: 'GET', path: 'relative'),
      throwsArgumentError,
    );
    expect(
      () => MockRequestMatcher(
        method: 'GET',
        path: '/safe',
        headers: const {'Authorization': 'secret'},
      ),
      throwsArgumentError,
    );
    expect(
      () => MockResponseVariant(id: 'variant', statusCode: 700),
      throwsArgumentError,
    );
    expect(
      () => MockResponseVariant(
        id: 'variant',
        statusCode: 200,
        delayMs: MockResponseVariant.maxDelayMs + 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => MockEndpoint(
        id: 'endpoint',
        matcher: MockRequestMatcher(method: 'GET', path: '/safe'),
        variants: const [],
      ),
      throwsArgumentError,
    );
  });

  test('Safe source references only point to the declared asset type', () {
    expect(
      () => MockSourceReference(
        kind: MockSourceKind.responseSnapshot,
        resourceRef: const ResourceRef(
          kind: ResourceKind.request,
          id: 'request-1',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => MockServerRuntimeProjection(
        status: MockServerRuntimeStatus.stopped,
        loopbackUrl: 'http://127.0.0.1:50000',
      ),
      throwsAssertionError,
    );
  });

  test('selects the first endpoint and an explicit variant before default', () {
    final server = MockServer(
      id: 'mock-1',
      name: 'Users',
      endpoints: [
        MockEndpoint(
          id: 'first',
          matcher: MockRequestMatcher(method: 'GET', path: '/users'),
          variants: [MockResponseVariant(id: 'first-default', statusCode: 200)],
        ),
        MockEndpoint(
          id: 'second',
          matcher: MockRequestMatcher(method: 'GET', path: '/users'),
          variants: [
            MockResponseVariant(id: 'second-default', statusCode: 201),
          ],
        ),
      ],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final request = MockRequestProjection(
      method: 'GET',
      path: '/users',
      headers: const {'x-mode': 'async'},
    );

    final endpoint = MockServerMatching.firstMatchingEndpoint(server, request);
    expect(endpoint!.id, 'first');
    expect(
      MockServerMatching.selectVariant(endpoint, request).id,
      'first-default',
    );

    final explicit = endpoint.copyWith(
      variants: [
        endpoint.variants.single,
        MockResponseVariant(
          id: 'first-async',
          statusCode: 202,
          matcher: MockVariantMatcher(headers: const {'x-mode': 'async'}),
        ),
      ],
    );
    expect(
      MockServerMatching.selectVariant(explicit, request).id,
      'first-async',
    );
  });

  test('validates default variants and lifecycle transitions', () {
    expect(
      () => MockEndpoint(
        id: 'ambiguous',
        matcher: MockRequestMatcher(method: 'GET', path: '/users'),
        variants: [
          MockResponseVariant(id: 'one', statusCode: 200),
          MockResponseVariant(id: 'two', statusCode: 201),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      MockServerLifecycleTransitions.canTransition(
        MockServerLifecycle.archived,
        MockServerLifecycle.draft,
      ),
      isTrue,
    );
    expect(
      MockServerLifecycleTransitions.canTransition(
        MockServerLifecycle.active,
        MockServerLifecycle.draft,
      ),
      isFalse,
    );
  });
}
