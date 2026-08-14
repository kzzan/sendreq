import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/demo/demo_example_catalog.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';

void main() {
  test(
    'installed demo contains independent REST, WebSocket and gRPC requests',
    () {
      final requests = [
        for (final folder in DemoExampleCatalog.collection.folders)
          ...folder.requests,
      ];

      expect(requests, hasLength(15));
      expect(
        requests
            .where((item) => item.protocol == ApiRequestProtocol.http)
            .map((item) => item.method),
        ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'GET'],
      );
      final webSockets = requests
          .where((item) => item.protocol == ApiRequestProtocol.webSocket)
          .toList();
      expect(webSockets.map((item) => item.urlTemplate), [
        'ws://127.0.0.1:8080/ws',
        'ws://127.0.0.1:8080/ws/basic',
        'ws://127.0.0.1:8080/ws/open',
        'ws://127.0.0.1:8080/ws/api-key',
      ]);
      final grpc = requests.firstWhere(
        (item) => item.id == 'demo-grpc-create-order',
      );
      expect(grpc.grpc.protoSchema?.path, 'asset://assets/demo/order.proto');
      expect(grpc.grpc.serviceName, '.order.v1.OrderService');
      expect(grpc.grpc.methodName, 'CreateOrder');
      expect(grpc.grpc.useTls, isFalse);
      expect(grpc.authentication.type.name, 'none');
      final getOrder = requests.firstWhere(
        (item) => item.id == 'demo-grpc-get-order',
      );
      expect(getOrder.grpc.methodName, 'GetOrder');
      expect(getOrder.authentication.type.name, 'apiKey');
      final submitOrders = requests.firstWhere(
        (item) => item.id == 'demo-grpc-submit-orders',
      );
      expect(submitOrders.grpc.methodName, 'SubmitOrders');
      expect(submitOrders.authentication.type.name, 'basic');
      final chat = requests.firstWhere(
        (item) => item.id == 'demo-grpc-order-chat',
      );
      expect(chat.grpc.methodName, 'Chat');
      expect(chat.bodyTemplate, contains('"text":"hello"'));
      final watchOrders = requests.firstWhere(
        (item) => item.id == 'demo-grpc-watch-orders',
      );
      expect(watchOrders.grpc.methodName, 'WatchOrders');
      expect(watchOrders.grpc.serverStreaming, isTrue);
    },
  );
}
