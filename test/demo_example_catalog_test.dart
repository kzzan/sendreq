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

      expect(requests, hasLength(7));
      expect(
        requests
            .where((item) => item.protocol == ApiRequestProtocol.http)
            .map((item) => item.method),
        ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
      );
      expect(
        requests
            .singleWhere(
              (item) => item.protocol == ApiRequestProtocol.webSocket,
            )
            .urlTemplate,
        'ws://127.0.0.1:8080/ws',
      );
      final grpc = requests.singleWhere(
        (item) => item.protocol == ApiRequestProtocol.grpc,
      );
      expect(grpc.grpc.protoSchema?.path, 'asset://assets/demo/order.proto');
      expect(grpc.grpc.serviceName, '.order.v1.OrderService');
      expect(grpc.grpc.methodName, 'CreateOrder');
      expect(grpc.grpc.useTls, isFalse);
    },
  );
}
