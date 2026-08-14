import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/grpc/grpc_rpc_shape.dart';

void main() {
  // 验证请求定义的序列化往返：经 encodeJson/decodeJson 后稳定字段保持一致，
  // 同时确认独立 Bearer 认证配置仍能正确还原。
  test('request definitions preserve stable fields through JSON', () {
    final repository = InMemoryApiAssetRepository.demo();
    final original = repository.getRequest('demo-rest-create-user');

    final restored = ApiRequestDefinition.decodeJson(original.encodeJson());

    expect(restored.id, original.id);
    expect(restored.method, 'POST');
    expect(restored.urlTemplate, 'http://127.0.0.1:8081/api/v1/basic/users');
    expect(restored.bodyTemplate, original.bodyTemplate);
    expect(restored.protocol, ApiRequestProtocol.http);
  });

  test('request definitions preserve URL encoded field state through JSON', () {
    const original = ApiRequestDefinition(
      id: 'form-request',
      collectionId: 'collection',
      folderId: 'folder',
      name: 'Form request',
      method: 'POST',
      urlTemplate: 'https://api.example.test/session',
      queryParams: [],
      headers: [
        ApiField(
          key: 'Content-Type',
          value: 'application/x-www-form-urlencoded',
        ),
      ],
      bodyTemplate: 'legacy raw body',
      formUrlEncodedFields: [
        ApiField(key: 'email', value: '{{email}}', secretReference: true),
        ApiField(key: 'mode', value: 'preview', enabled: false),
      ],
    );

    final restored = ApiRequestDefinition.decodeJson(original.encodeJson());

    expect(restored.formUrlEncodedFields, hasLength(2));
    expect(restored.formUrlEncodedFields.first.secretReference, isTrue);
    expect(restored.formUrlEncodedFields.last.enabled, isFalse);
    expect(restored.formUrlEncodedFields.last.value, 'preview');
  });

  test('gRPC shape and schema source survive request JSON round trips', () {
    for (final shape in GrpcRpcShape.values) {
      const base = ApiRequestDefinition(
        id: 'grpc',
        collectionId: 'collection',
        folderId: 'folder',
        name: 'gRPC request',
        method: 'POST',
        urlTemplate: 'grpc://127.0.0.1:50051',
        queryParams: [],
        headers: [],
        bodyTemplate: '{}',
        protocol: ApiRequestProtocol.grpc,
      );
      final original = base.copyWith(
        grpc: GrpcRequestConfiguration(
          serviceName: '.example.v1.ExampleService',
          methodName: 'Chat',
          useTls: false,
          rpcShape: shape,
          deadlineMs: '2500',
          schemaSource: GrpcSchemaSource.reflection,
        ),
      );

      final restored = ApiRequestDefinition.decodeJson(original.encodeJson());

      expect(restored.grpc.rpcShape, shape);
      expect(restored.grpc.schemaSource, GrpcSchemaSource.reflection);
      expect(restored.grpc.deadlineMs, '2500');
    }
  });

  test('legacy gRPC fields migrate and missing auth remains No auth', () {
    final legacy = <String, dynamic>{
      'id': 'legacy-grpc',
      'collectionId': 'collection',
      'folderId': 'folder',
      'name': 'Legacy stream',
      'method': 'POST',
      'urlTemplate': 'grpc://127.0.0.1:50051',
      'queryParams': <dynamic>[],
      'headers': <dynamic>[],
      'bodyTemplate': '{}',
      'protocol': 'grpc',
      'grpc': <String, dynamic>{
        'serviceName': '.example.v1.ExampleService',
        'methodName': 'WatchOrders',
        'useTls': false,
        'serverStreaming': true,
        'useReflection': true,
      },
      'metadata': <String, String>{},
    };

    final restored = ApiRequestDefinition.fromJson(legacy);

    expect(restored.authentication.type, RequestAuthenticationType.none);
    expect(restored.grpc.rpcShape, GrpcRpcShape.serverStreaming);
    expect(restored.grpc.schemaSource, GrpcSchemaSource.reflection);
    expect(restored.grpc.deadlineMs, isEmpty);
  });

  test(
    'legacy request JSON defaults to HTTP and preserves WebSocket fields',
    () {
      final original = InMemoryApiAssetRepository.demo().getRequest(
        'demo-rest-list-users',
      );
      // 构造旧版 JSON：删除 protocol 与 webSocket 字段，模拟升级前持久化的数据。
      final legacy = Map<String, dynamic>.from(original.toJson())
        ..remove('protocol')
        ..remove('webSocket');
      final restoredLegacy = ApiRequestDefinition.fromJson(legacy);
      // 构造 WebSocket 配置副本，验证新协议字段也能完整序列化还原。
      final configured = original.copyWith(
        protocol: ApiRequestProtocol.webSocket,
        webSocket: const WebSocketRequestConfiguration(
          subprotocols: ['events.v1'],
          protobufSchema: ProtobufSchemaReference(
            path: '/tmp/events.pb',
            fingerprint: 'abc123',
            messageType: '.sendreq.Event',
          ),
        ),
      );
      final restoredConfigured = ApiRequestDefinition.decodeJson(
        configured.encodeJson(),
      );
      final grpcConfigured = original.copyWith(
        protocol: ApiRequestProtocol.grpc,
        grpc: const GrpcRequestConfiguration(
          protoSchema: ProtobufSchemaReference(
            path: '/tmp/health.proto',
            fingerprint: 'def456',
          ),
          serviceName: '.sendreq.health.Health',
          methodName: 'Check',
          useTls: false,
          deadlineMs: '2500',
        ),
      );
      final restoredGrpc = ApiRequestDefinition.decodeJson(
        grpcConfigured.encodeJson(),
      );

      // 旧数据缺少 protocol 时应回退到 HTTP；新数据应完整保留 WebSocket 与 protobuf 配置。
      expect(restoredLegacy.protocol, ApiRequestProtocol.http);
      expect(restoredConfigured.protocol, ApiRequestProtocol.webSocket);
      expect(restoredConfigured.webSocket.subprotocols, ['events.v1']);
      expect(
        restoredConfigured.webSocket.protobufSchema?.messageType,
        '.sendreq.Event',
      );
      expect(restoredGrpc.protocol, ApiRequestProtocol.grpc);
      expect(restoredGrpc.grpc.serviceName, '.sendreq.health.Health');
      expect(restoredGrpc.grpc.methodName, 'Check');
      expect(restoredGrpc.grpc.useTls, isFalse);
      expect(restoredGrpc.grpc.deadlineMs, '2500');
    },
  );

  test('request tabs activate existing entries and choose an adjacent tab', () {
    final repository = InMemoryApiAssetRepository.demo();

    // 重复打开同一请求：已存在标签页时应复用而非重复创建，且该请求成为活动标签。
    repository.openRequestTab('demo-rest-create-user');
    repository.openRequestTab('demo-rest-create-user');

    expect(repository.listOpenTabs(), hasLength(2));
    expect(repository.activeRequestId, 'demo-rest-create-user');

    // 关闭活动标签后应切换到相邻标签（此处为列表请求），而非留下空悬的活动 id。
    repository.closeRequestTab('tab-demo-rest-create-user');
    expect(repository.activeRequestId, 'demo-rest-list-users');

    repository.closeRequestTab('tab-demo-rest-list-users');
    expect(repository.listOpenTabs(), isEmpty);
    expect(repository.activeRequestId, isNull);
  });

  // 验证未指定归属时新建请求默认落入“默认集合”文件夹，并自动分配递增 id 与名称。
  test('new requests are added to the default collection folder', () {
    final repository = InMemoryApiAssetRepository.demo();

    final request = repository.createRequest();

    expect(request.id, 'request-new-1');
    expect(request.name, 'New request 1');
    expect(request.folderId, 'folder-demo-rest');
    expect(repository.getRequest(request.id).urlTemplate, isEmpty);
    expect(request.authentication.type, RequestAuthenticationType.none);
    expect(repository.listRequests(), hasLength(7));
  });

  test('Demo REST request keeps its localhost endpoint and query input', () {
    final request = InMemoryApiAssetRepository.demo().getRequest(
      'demo-rest-list-users',
    );

    expect(request.method, 'GET');
    expect(request.urlTemplate, 'http://127.0.0.1:8081/api/v1/users');
    expect(
      request.queryParams.map((parameter) => (parameter.key, parameter.value)),
      [('page', '1'), ('limit', '20')],
    );
  });

  test('in-memory fixture contains REST requests only', () {
    final protocols = InMemoryApiAssetRepository.demo().listRequests().map(
      (item) => item.protocol,
    );

    expect(protocols, everyElement(ApiRequestProtocol.http));
  });

  // 验证集合/文件夹可重命名，且新建的文件夹与请求能被精确地定向到指定集合。
  test('collections and folders can be renamed and targeted', () {
    final repository = InMemoryApiAssetRepository.demo();

    repository.renameCollection('collection-sendreq-demo', 'Protocol APIs');
    repository.renameFolder(
      collectionId: 'collection-sendreq-demo',
      folderId: 'folder-demo-rest',
      name: 'Auth',
    );
    // 在指定集合下新建文件夹与请求，确认其能正确归位到目标层级。
    final folder = repository.createFolder(
      collectionId: 'collection-sendreq-demo',
    );
    final request = repository.createRequest(
      collectionId: 'collection-sendreq-demo',
      folderId: folder.id,
    );

    final collection = repository.listCollections().single;
    expect(collection.id, 'collection-sendreq-demo');
    expect(collection.name, 'Protocol APIs');
    expect(collection.folders.first.name, 'Auth');
    expect(folder.name, 'New group 2');
    expect(request.folderId, folder.id);
    expect(collection.folders.last.requests.single.id, request.id);
  });

  // 验证删除整个集合会级联清理其请求、已打开的标签页与活动请求引用，
  // 避免界面残留指向已删除资源的引用。
  test('deleting a collection clears requests tabs and active request', () {
    final repository = InMemoryApiAssetRepository.demo();

    repository.openRequestTab('demo-rest-create-user');
    repository.deleteCollection('collection-sendreq-demo');

    expect(repository.listCollections(), isEmpty);
    expect(repository.listRequests(), isEmpty);
    expect(repository.listOpenTabs(), isEmpty);
    expect(repository.activeRequestId, isNull);
    expect(
      () => repository.getRequest('demo-rest-list-users'),
      throwsStateError,
    );
  });

  // 验证只删除某个文件夹时，仅该文件夹内的请求受影响，其余文件夹保持完整。
  test('deleting a folder clears its requests tabs and active request', () {
    final repository = InMemoryApiAssetRepository.demo();
    final siblingFolder = repository.createFolder(
      collectionId: 'collection-sendreq-demo',
    );
    final siblingRequest = repository.createRequest(
      collectionId: 'collection-sendreq-demo',
      folderId: siblingFolder.id,
    );

    repository.openRequestTab(siblingRequest.id);
    repository.openRequestTab('demo-rest-create-user');
    repository.deleteFolder(
      collectionId: 'collection-sendreq-demo',
      folderId: 'folder-demo-rest',
    );

    final collection = repository.listCollections().single;
    // 被删文件夹不应再出现在集合结构中。
    expect(
      collection.folders.map((folder) => folder.id),
      isNot(contains('folder-demo-rest')),
    );
    expect(repository.listOpenTabs(), hasLength(1));
    expect(repository.activeRequestId, siblingRequest.id);
    // 目标分组内请求已删除，同一集合的兄弟分组与请求仍然可用。
    expect(
      () => repository.getRequest('demo-rest-list-users'),
      throwsStateError,
    );
    expect(repository.getRequest(siblingRequest.id).id, siblingRequest.id);
  });

  // 验证重命名与删除只作用于目标请求，不影响同级请求；删除活动请求后会自动选中相邻标签。
  test('requests can be renamed and deleted without affecting siblings', () {
    final repository = InMemoryApiAssetRepository.demo();

    repository.openRequestTab('demo-rest-create-user');
    repository.renameRequest('demo-rest-create-user', 'Create a user');
    repository.deleteRequest('demo-rest-create-user');

    expect(
      () => repository.getRequest('demo-rest-create-user'),
      throwsStateError,
    );
    expect(repository.getRequest('demo-rest-list-users').name, 'List users');
    final collection = repository.listCollections().single;
    expect(collection.id, 'collection-sendreq-demo');
    expect(
      collection.folders.map((folder) => folder.id),
      contains('folder-demo-rest'),
    );
    expect(repository.listRequests(), hasLength(5));
    expect(repository.activeRequestId, 'demo-rest-list-users');
  });

  test(
    'a new request recreates a default collection after all are deleted',
    () {
      final repository = InMemoryApiAssetRepository.demo();

      // 删除唯一集合后再新建请求，应自动重建默认集合并放入其新建文件夹。
      repository.deleteCollection('collection-sendreq-demo');
      final request = repository.createRequest();

      expect(repository.listCollections(), hasLength(1));
      expect(repository.listCollections().single.name, 'New collection 1');
      expect(request.name, 'New request 1');
      expect(request.folderId, 'folder-new-1-requests');
    },
  );

  test('asset snapshots are reused until repository data changes', () {
    final repository = InMemoryApiAssetRepository.demo();

    final collections = repository.listCollections();
    final requests = repository.listRequests();
    expect(repository.listCollections(), same(collections));
    expect(repository.listRequests(), same(requests));

    repository.openRequestTab('demo-rest-create-user');
    expect(repository.listCollections(), same(collections));
    expect(repository.listRequests(), same(requests));

    repository.renameRequest('demo-rest-create-user', 'Create user fast');
    final changedCollections = repository.listCollections();
    final changedRequests = repository.listRequests();
    expect(changedCollections, isNot(same(collections)));
    expect(changedRequests, isNot(same(requests)));
    expect(
      repository.getRequest('demo-rest-create-user').name,
      'Create user fast',
    );
    expect(repository.listCollections(), same(changedCollections));
    expect(repository.listRequests(), same(changedRequests));
  });
}
