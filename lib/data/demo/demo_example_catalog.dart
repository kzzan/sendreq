import '../../domain/api_assets/api_asset_models.dart';

/// 产品随安装包提供的协议示例，不会在加载时覆盖用户已有集合。
abstract final class DemoExampleCatalog {
  /// 示例集合的稳定 ID；重复加载时由仓储生成冲突安全的新 ID。
  static const collectionId = 'collection-sendreq-demo';

  /// REST CRUD、WebSocket、gRPC 请求均为独立请求类型。
  static const collection = ApiCollection(
    id: collectionId,
    name: 'Sendreq Demo Example',
    folders: [
      ApiFolder(
        id: 'folder-demo-rest',
        name: 'REST',
        requests: [
          ApiRequestDefinition(
            id: 'demo-rest-list-users',
            collectionId: collectionId,
            folderId: 'folder-demo-rest',
            name: 'List users',
            method: 'GET',
            urlTemplate: 'http://127.0.0.1:8081/api/v1/users',
            queryParams: [
              ApiField(key: 'page', value: '1'),
              ApiField(key: 'limit', value: '20'),
            ],
            headers: [],
            bodyTemplate: '',
            metadata: {'folderName': 'REST'},
          ),
          ApiRequestDefinition(
            id: 'demo-rest-create-user',
            collectionId: collectionId,
            folderId: 'folder-demo-rest',
            name: 'Create user',
            method: 'POST',
            urlTemplate: 'http://127.0.0.1:8081/api/v1/users',
            queryParams: [],
            headers: [ApiField(key: 'Content-Type', value: 'application/json')],
            bodyTemplate:
                '{"name":"Grace Hopper","email":"grace@example.test"}',
            metadata: {'folderName': 'REST'},
          ),
          ApiRequestDefinition(
            id: 'demo-rest-replace-user',
            collectionId: collectionId,
            folderId: 'folder-demo-rest',
            name: 'Replace user 1',
            method: 'PUT',
            urlTemplate: 'http://127.0.0.1:8081/api/v1/users/1',
            queryParams: [],
            headers: [ApiField(key: 'Content-Type', value: 'application/json')],
            bodyTemplate: '{"name":"Ada Byron","email":"ada@example.test"}',
            metadata: {'folderName': 'REST'},
          ),
          ApiRequestDefinition(
            id: 'demo-rest-patch-user',
            collectionId: collectionId,
            folderId: 'folder-demo-rest',
            name: 'Patch user 1',
            method: 'PATCH',
            urlTemplate: 'http://127.0.0.1:8081/api/v1/users/1',
            queryParams: [],
            headers: [ApiField(key: 'Content-Type', value: 'application/json')],
            bodyTemplate: '{"name":"Ada Lovelace"}',
            metadata: {'folderName': 'REST'},
          ),
          ApiRequestDefinition(
            id: 'demo-rest-delete-user',
            collectionId: collectionId,
            folderId: 'folder-demo-rest',
            name: 'Delete user 1',
            method: 'DELETE',
            urlTemplate: 'http://127.0.0.1:8081/api/v1/users/1',
            queryParams: [],
            headers: [],
            bodyTemplate: '',
            metadata: {'folderName': 'REST'},
          ),
        ],
      ),
      ApiFolder(
        id: 'folder-demo-websocket',
        name: 'WebSocket',
        requests: [
          ApiRequestDefinition(
            id: 'demo-websocket-echo',
            collectionId: collectionId,
            folderId: 'folder-demo-websocket',
            name: 'Local echo',
            method: 'WebSocket',
            urlTemplate: 'ws://127.0.0.1:8080/ws',
            queryParams: [],
            headers: [],
            bodyTemplate: 'sendreq websocket demo',
            protocol: ApiRequestProtocol.webSocket,
            metadata: {'folderName': 'WebSocket'},
          ),
        ],
      ),
      ApiFolder(
        id: 'folder-demo-grpc',
        name: 'gRPC',
        requests: [
          ApiRequestDefinition(
            id: 'demo-grpc-create-order',
            collectionId: collectionId,
            folderId: 'folder-demo-grpc',
            name: 'Create order',
            method: 'gRPC',
            urlTemplate: 'http://127.0.0.1:50051',
            queryParams: [],
            headers: [],
            bodyTemplate:
                '{"user_id":"demo-user","product":"sendreq","quantity":1}',
            protocol: ApiRequestProtocol.grpc,
            grpc: GrpcRequestConfiguration(
              protoSchema: ProtobufSchemaReference(
                path: 'asset://assets/demo/order.proto',
                fingerprint: 'sendreq-demo-order-v1',
              ),
              serviceName: '.order.v1.OrderService',
              methodName: 'CreateOrder',
              useTls: false,
            ),
            metadata: {'folderName': 'gRPC'},
          ),
        ],
      ),
    ],
  );
}
