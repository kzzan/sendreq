import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/mock_server_snapshot_codec.dart';
import 'package:sendreq/domain/contract_publishing/mock_server.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';

void main() {
  test('round-trips ordered Mock definitions without runtime state', () {
    final server = MockServer(
      id: 'mock-1',
      name: 'Users',
      lifecycle: MockServerLifecycle.active,
      createdAt: DateTime.utc(2026, 8, 11),
      updatedAt: DateTime.utc(2026, 8, 11, 1),
      source: MockSourceReference(
        kind: MockSourceKind.responseSnapshot,
        resourceRef: const ResourceRef(
          kind: ResourceKind.responseSnapshot,
          id: 'response-1',
        ),
      ),
      endpoints: [
        MockEndpoint(
          id: 'users',
          matcher: MockRequestMatcher(method: 'GET', path: '/users'),
          variants: [
            MockResponseVariant(
              id: 'default',
              statusCode: 200,
              body: '{"ok":true}',
            ),
            MockResponseVariant(
              id: 'accepted',
              statusCode: 202,
              matcher: MockVariantMatcher(headers: const {'x-mode': 'async'}),
            ),
          ],
        ),
      ],
    );

    final payload = MockServerSnapshotCodec.encodeDocument([server]);
    final restored = MockServerSnapshotCodec.decodeDocument(payload).single;

    expect(restored.id, server.id);
    expect(restored.endpoints.single.variants.map((item) => item.id), [
      'default',
      'accepted',
    ]);
    expect(payload, isNot(contains('loopbackUrl')));
    expect(payload, isNot(contains('running')));
  });
}
