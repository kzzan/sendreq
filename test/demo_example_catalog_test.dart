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

  test('protocol fixture keeps independent WebSocket and gRPC coverage', () {
    final requests = [
      for (final folder in DemoExampleCatalog.protocolTestCollection.folders)
        ...folder.requests,
    ];

    expect(requests, hasLength(15));
    final webSockets = requests
        .where((item) => item.protocol == ApiRequestProtocol.webSocket)
        .toList();
    expect(webSockets, hasLength(4));
    final grpc = requests.firstWhere(
      (item) => item.id == 'demo-grpc-create-order',
    );
    expect(grpc.grpc.protoSchema?.path, 'assets/demo/order.proto');
    expect(grpc.grpc.serviceName, '.order.v1.OrderService');
    expect(grpc.grpc.methodName, 'CreateOrder');
    final chat = requests.firstWhere(
      (item) => item.id == 'demo-grpc-order-chat',
    );
    expect(chat.grpc.methodName, 'Chat');
    expect(chat.bodyTemplate, contains('"text":"hello"'));
    final watchOrders = requests.firstWhere(
      (item) => item.id == 'demo-grpc-watch-orders',
    );
    expect(watchOrders.grpc.serverStreaming, isTrue);
  });
}
