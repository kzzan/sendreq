import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/demo/demo_example_catalog.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';

void main() {
  test('user-loadable demo contains one REST request only', () {
    final collection = DemoExampleCatalog.collection;
    final requests = [
      for (final folder in collection.folders) ...folder.requests,
    ];

    expect(collection.name, 'Sendreq REST Example');
    expect(collection.folders, hasLength(1));
    expect(requests, hasLength(1));
    expect(requests.single.protocol, ApiRequestProtocol.http);
    expect(requests.single.method, 'GET');
    expect(requests.single.grpc.protoSchema, isNull);
  });
}
