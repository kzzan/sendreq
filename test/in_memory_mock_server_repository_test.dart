import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_mock_server_repository.dart';
import 'package:sendreq/domain/contract_publishing/mock_server.dart';

void main() {
  test(
    'stores ordered endpoints and variants without exposing mutable lists',
    () async {
      final repository = InMemoryMockServerRepository();
      final server = _server(
        id: 'mock-1',
        updatedAt: DateTime.utc(2026, 8, 11, 12),
        endpointIds: const ['users', 'users-fallback'],
      );

      await repository.save(server);
      final restored = await repository.findById('mock-1');

      expect(restored, same(server));
      expect(restored!.endpoints.map((endpoint) => endpoint.id), [
        'users',
        'users-fallback',
      ]);
      expect(restored.endpoints.first.variants.map((variant) => variant.id), [
        'users-default',
        'users-accepted',
      ]);
      expect(
        () => restored.endpoints.add(restored.endpoints.first),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'lists Servers in stable recent-update order and saves updates by id',
    () async {
      final repository = InMemoryMockServerRepository(
        initial: [
          _server(id: 'mock-b', updatedAt: DateTime.utc(2026, 8, 11)),
          _server(id: 'mock-a', updatedAt: DateTime.utc(2026, 8, 11)),
          _server(id: 'mock-new', updatedAt: DateTime.utc(2026, 8, 12)),
        ],
      );

      expect((await repository.list()).map((server) => server.id), [
        'mock-new',
        'mock-a',
        'mock-b',
      ]);

      final updated = _server(
        id: 'mock-a',
        updatedAt: DateTime.utc(2026, 8, 13),
        endpointIds: const ['changed'],
      );
      await repository.save(updated);

      expect((await repository.list()).first, same(updated));
      expect(
        (await repository.findById('mock-a'))!.endpoints.single.id,
        'changed',
      );
    },
  );

  test(
    'deletes a Mock Server definition without affecting other assets',
    () async {
      final repository = InMemoryMockServerRepository(
        initial: [
          _server(id: 'mock-1', updatedAt: DateTime.utc(2026, 8, 11)),
          _server(id: 'mock-2', updatedAt: DateTime.utc(2026, 8, 11)),
        ],
      );

      await repository.delete('mock-1');

      expect(await repository.findById('mock-1'), isNull);
      expect((await repository.list()).single.id, 'mock-2');
    },
  );
}

MockServer _server({
  required String id,
  required DateTime updatedAt,
  List<String> endpointIds = const ['endpoint'],
}) => MockServer(
  id: id,
  name: id,
  endpoints: [
    for (final endpointId in endpointIds)
      MockEndpoint(
        id: endpointId,
        matcher: MockRequestMatcher(method: 'GET', path: '/$endpointId'),
        variants: [
          MockResponseVariant(id: '$endpointId-default', statusCode: 200),
          MockResponseVariant(
            id: '$endpointId-accepted',
            statusCode: 202,
            matcher: MockVariantMatcher(headers: const {'x-mode': 'async'}),
          ),
        ],
      ),
  ],
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: updatedAt,
);
