import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/data/repositories/in_memory_environment_store.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/grpc/grpc_transport.dart';
import 'package:sendreq/domain/models/workspace_models.dart';
import 'package:sendreq/domain/request_runtime/request_execution_runtime.dart';
import 'package:sendreq/domain/websocket/websocket_transport.dart';
import 'package:sendreq/features/workspace/view_models/workspace_view_model.dart';

import 'support/workspace_view_model_test_factory.dart';

// WorkspaceViewModel 的状态机单元测试：不依赖真实运行时与 UI，
// 覆盖发送/取消、删除保护、草稿编辑与授权/上传等数据行为。
void main() {
  // 场景：删除正在发送的请求时，应取消底层运行时并丢弃迟到的响应；
  // 用受控运行时手动完成响应，验证删除后结果不会污染当前视图。
  test(
    'deleting a sending request cancels and discards its late response',
    () async {
      final runtime = _ControlledRuntime();
      final viewModel = workspaceViewModel(
        assetRepository: InMemoryApiAssetRepository.demo(),
        executionRuntime: runtime,
      );

      final send = viewModel.sendActiveRequest();
      viewModel.deleteRequest('demo-rest-list-users');
      // 在删除请求之后才完成响应，验证迟到的响应被丢弃而不会生效。
      runtime.response.complete(_response());
      await send;

      expect(runtime.cancelCount, 1);
      expect(viewModel.isSending, isFalse);
      expect(viewModel.response, isNull);
      // 删除首个 REST 请求后，活动请求应回落到同一示例集合中的下一个请求。
      expect(viewModel.activeRequest.name, 'Create user');
    },
  );

  // 场景：已删除请求的历史与文档草稿入口应保持不可用，并提示原请求已被删除。
  test(
    'deleted history and documentation requests remain unavailable',
    () async {
      final repository = InMemoryApiAssetRepository.demo();
      final viewModel = workspaceViewModel(
        assetRepository: repository,
        executionRuntime: _ImmediateRuntime(),
      );

      await viewModel.sendActiveRequest();
      // 记录删除前生成的历史 ID，随后验证删除后打开该历史的行为。
      final historyId = viewModel.history.first.id;
      viewModel.createDocumentationDraft();
      viewModel.deleteRequest('demo-rest-list-users');

      viewModel.openHistoryRecord(historyId);
      viewModel.openSelectedHistoryRequest();
      expect(viewModel.lastActionMessage, 'The original request was deleted.');

      viewModel.tryDocumentationDraft();
      expect(viewModel.lastActionMessage, 'The original request was deleted.');
      expect(viewModel.canTryDocumentationDraft, isFalse);
    },
  );

  // 场景：查询参数允许重名，解析出的 URL 应保留重复键（如两个 tag）。
  test('query parameters retain duplicate keys in the resolved URL', () {
    final viewModel = workspaceViewModel(
      assetRepository: InMemoryApiAssetRepository.demo(),
    );

    viewModel.addActiveDraftField(headers: false);
    viewModel.updateActiveDraftField(
      headers: false,
      index: 2,
      keyName: 'tag',
      value: 'alpha',
    );
    viewModel.addActiveDraftField(headers: false);
    viewModel.updateActiveDraftField(
      headers: false,
      index: 3,
      keyName: 'tag',
      value: 'beta',
    );

    expect(Uri.parse(viewModel.resolvedUrl).queryParametersAll['tag'], [
      'alpha',
      'beta',
    ]);
  });

  test('URL query parameters and Params rows stay in sync', () {
    final viewModel = workspaceViewModel(
      assetRepository: InMemoryApiAssetRepository.demo(),
    );

    viewModel.updateActiveDraftUrl(
      '{{baseUrl}}/api/v1/users?limit=10&tag=alpha&tag=beta',
    );

    expect(viewModel.activeDraft.path, '/api/v1/users');
    expect(
      viewModel.activeDraft.params.map((row) => (row.keyName, row.value)),
      [('limit', '10'), ('tag', 'alpha'), ('tag', 'beta')],
    );
    expect(
      viewModel.activeDraftUrl,
      '{{baseUrl}}/api/v1/users?limit=10&tag=alpha&tag=beta',
    );

    viewModel.updateActiveDraftField(
      headers: false,
      index: 1,
      value: 'release',
    );
    expect(
      viewModel.activeDraftUrl,
      '{{baseUrl}}/api/v1/users?limit=10&tag=release&tag=beta',
    );

    viewModel.removeActiveDraftField(headers: false, index: 2);
    expect(
      viewModel.activeDraftUrl,
      '{{baseUrl}}/api/v1/users?limit=10&tag=release',
    );
  });

  test(
    'GET keeps entity data for later editing but reports it will be ignored',
    () {
      final viewModel = workspaceViewModel(
        assetRepository: InMemoryApiAssetRepository.demo(),
      );

      viewModel.updateActiveDraftMethod('POST');
      viewModel.updateActiveDraftBody('{"name":"Ada"}');
      viewModel.updateActiveContentType('application/json');
      viewModel.updateActiveDraftMethod('GET');

      expect(viewModel.activeRequestSupportsBody, isFalse);
      expect(viewModel.activeRequestHasIgnoredEntityData, isTrue);
      expect(viewModel.activeDraft.body, '{"name":"Ada"}');
    },
  );

  test('Reurl URL normalizes single-brace environment query references', () {
    final environmentStore = InMemoryEnvironmentStore.sample();
    final viewModel = workspaceViewModel(
      assetRepository: InMemoryApiAssetRepository.demo(),
      environmentStore: environmentStore,
    );
    environmentStore.setActiveEnvironment('reurl-production');

    viewModel.updateActiveDraftUrl(
      '{{baseUrl}}/geoip/country?ip={ip}&lang={lang}',
    );

    expect(
      viewModel.activeDraftUrl,
      '{{baseUrl}}/geoip/country?ip={{ip}}&lang={{lang}}',
    );
    expect(
      viewModel.resolvedUrl,
      'https://api.reurl.to/geoip/country?ip=1.1.1.1&lang=en',
    );
  });

  test(
    'missing Reurl environment variables block a single-brace URL request',
    () {
      final viewModel = workspaceViewModel(
        assetRepository: InMemoryApiAssetRepository.demo(),
      );

      viewModel.updateActiveDraftUrl(
        '{{baseUrl}}/geoip/country?ip={ip}&lang={lang}',
      );

      expect(
        viewModel.activeDraftUrl,
        '{{baseUrl}}/geoip/country?ip={{ip}}&lang={{lang}}',
      );
      expect(viewModel.activeMissingVariableKeys, containsAll(['ip', 'lang']));
      expect(viewModel.actionAvailability.canSend, isFalse);
    },
  );

  test(
    'Collection environment switch keeps the request definition and renews its execution context',
    () async {
      final runtime = _CapturingRuntime();
      final viewModel = workspaceViewModel(
        assetRepository: InMemoryApiAssetRepository.demo(),
        executionRuntime: runtime,
      );
      final draftUrl = viewModel.activeDraftUrl;

      await viewModel.sendActiveRequest();
      expect(viewModel.response, isNotNull);
      expect(
        runtime.resolvedUrls.single,
        'http://127.0.0.1:8081/api/v1/users?page=1&limit=20',
      );

      // Collection 的环境选择只改变变量解析上下文，不改变请求定义。
      viewModel.selectEnvironment('production');

      expect(viewModel.activeEnvironment.name, 'Production');
      expect(viewModel.activeDraftUrl, draftUrl);
      expect(viewModel.response, isNull);
      expect(viewModel.executionError, isNull);
      expect(viewModel.openedHistoryRecord, isNull);
      expect(
        viewModel.resolvedUrl,
        'http://127.0.0.1:8081/api/v1/users?page=1&limit=20',
      );

      await viewModel.sendActiveRequest();
      expect(runtime.resolvedUrls, [
        'http://127.0.0.1:8081/api/v1/users?page=1&limit=20',
        'http://127.0.0.1:8081/api/v1/users?page=1&limit=20',
      ]);
      expect(
        viewModel.history.first.requestSnapshot!.environmentName,
        'Production',
      );
    },
  );

  test(
    'switching Collection environment cancels an in-flight request',
    () async {
      final runtime = _ControlledRuntime();
      final viewModel = workspaceViewModel(
        assetRepository: InMemoryApiAssetRepository.demo(),
        executionRuntime: runtime,
      );

      final send = viewModel.sendActiveRequest();
      viewModel.selectEnvironment('production');
      runtime.response.complete(_response());
      await send;

      expect(runtime.cancelCount, 1);
      expect(viewModel.isSending, isFalse);
      expect(viewModel.response, isNull);
      expect(viewModel.activeEnvironment.name, 'Production');
    },
  );

  // Reurl Production 的三个 GeoIP 端点共享环境地址、查询变量和 Bearer
  // 认证。执行边界才解析 secret，草稿中始终保留 `{{token}}` 模板。
  test(
    'Reurl GeoIP requests resolve environment parameters and Bearer token',
    () async {
      final environmentStore = InMemoryEnvironmentStore.sample();
      final runtime = _CapturingRuntime();
      final repository = InMemoryApiAssetRepository.demo();
      repository.addRequests([
        for (final endpoint in ['country', 'asn', 'city'])
          ApiRequestDefinition(
            id: 'test-reurl-geoip-$endpoint',
            collectionId: 'collection-sendreq-demo',
            folderId: 'folder-demo-rest',
            name: 'Lookup $endpoint',
            method: 'GET',
            urlTemplate:
                '{{baseUrl}}/geoip/$endpoint?ip={{ip}}&lang={{lang}}',
            queryParams: const [],
            headers: const [],
            bodyTemplate: '',
            authentication: const RequestAuthentication.bearer('{{token}}'),
            authenticationSource: RequestAuthenticationSource.environment,
          ),
      ]);
      final viewModel = workspaceViewModel(
        assetRepository: repository,
        environmentStore: environmentStore,
        executionRuntime: runtime,
      );
      environmentStore.setActiveEnvironment('reurl-production');
      environmentStore.updateVariable(
        id: 'reurl-token',
        value: 'test-reurl-token',
      );
      for (final requestId in [
        'test-reurl-geoip-country',
        'test-reurl-geoip-asn',
        'test-reurl-geoip-city',
      ]) {
        viewModel.selectRequest(requestId);
        await viewModel.sendActiveRequest();
      }

      expect(runtime.resolvedUrls, [
        'https://api.reurl.to/geoip/country?ip=1.1.1.1&lang=en',
        'https://api.reurl.to/geoip/asn?ip=1.1.1.1&lang=en',
        'https://api.reurl.to/geoip/city?ip=1.1.1.1&lang=en',
      ]);
      for (final draft in runtime.drafts) {
        final authorization = draft.headers.singleWhere(
          (header) => header.keyName.toLowerCase() == 'authorization',
        );
        expect(authorization.value, 'Bearer test-reurl-token');
        expect(authorization.value, isNot(contains('{{token}}')));
        expect(draft.body, isEmpty);
      }
      expect(viewModel.activeDraft.headers, isEmpty);
      expect(
        viewModel.activeDraft.authenticationSource,
        RequestAuthenticationSource.environment,
      );
      expect(viewModel.activeDraft.authentication.bearerToken, '{{token}}');
    },
  );

  test(
    'Basic authentication resolves credentials before generating Authorization',
    () async {
      final runtime = _CapturingRuntime();
      final viewModel = workspaceViewModel(
        assetRepository: InMemoryApiAssetRepository.demo(),
        executionRuntime: runtime,
      );

      viewModel.setActiveAuthenticationType(RequestAuthenticationType.basic);
      viewModel.updateActiveBasicAuthentication(
        username: 'alice',
        password: 'secret',
      );
      await viewModel.sendActiveRequest();

      expect(
        runtime.drafts.single.headers
            .singleWhere(
              (header) => header.keyName.toLowerCase() == 'authorization',
            )
            .value,
        'Basic YWxpY2U6c2VjcmV0',
      );
    },
  );

  test(
    'API Key query authentication resolves its standard environment value into URL',
    () async {
      final runtime = _CapturingRuntime();
      final viewModel = workspaceViewModel(
        assetRepository: InMemoryApiAssetRepository.demo(),
        executionRuntime: runtime,
      );

      viewModel.updateActiveEnvironmentAuthenticationType(
        RequestAuthenticationType.apiKey,
      );
      final apiKey = viewModel.variables.singleWhere(
        (variable) => variable.key == 'apiKey',
      );
      viewModel.updateEnvironmentVariable(
        id: apiKey.id,
        value: 'staging-api-key-value',
      );
      viewModel.setActiveAuthenticationType(RequestAuthenticationType.apiKey);
      viewModel.updateActiveApiKeyAuthentication(
        name: 'api_key',
        value: '{{apiKey}}',
        location: ApiKeyLocation.query,
      );
      await viewModel.sendActiveRequest();

      expect(
        Uri.parse(runtime.resolvedUrls.single).queryParameters['api_key'],
        'staging-api-key-value',
      );
    },
  );

  test(
    'environment variables can be inserted as editable Params templates',
    () {
      final viewModel = workspaceViewModel(
        assetRepository: InMemoryApiAssetRepository.demo(),
      );

      viewModel.addActiveEnvironmentVariableParameter('token');
      final parameter = viewModel.activeDraft.params.last;
      expect(parameter.keyName, 'token');
      expect(parameter.value, '{{token}}');
    },
  );

  test('ordinary environment variables can be explicitly added as Params', () {
    final environmentStore = InMemoryEnvironmentStore.sample();
    final viewModel = workspaceViewModel(
      assetRepository: InMemoryApiAssetRepository.demo(),
      environmentStore: environmentStore,
    );
    environmentStore.addVariable();
    final variable = environmentStore.listVariables().singleWhere(
      (item) => item.id == 'variable-1',
    );
    environmentStore.updateVariable(
      id: variable.id,
      key: 'region',
      value: 'cn-north-1',
    );

    expect(
      viewModel.activeAvailableEnvironmentParameters.map(
        (parameter) => (parameter.keyName, parameter.value),
      ),
      [('region', '{{region}}')],
    );
    expect(
      viewModel.activeDraft.params.any((item) => item.keyName == 'region'),
      isFalse,
    );
    expect(viewModel.activeDraftUrl, isNot(contains('region={{region}}')));

    viewModel.addActiveEnvironmentVariableParameter(
      'region',
      parameterKey: 'location',
    );
    expect(viewModel.activeDraftUrl, contains('location={{region}}'));
    expect(
      Uri.parse(viewModel.resolvedUrl).queryParameters['location'],
      'cn-north-1',
    );
  });

  test(
    'an environment variable already referenced by a Param is not injected twice',
    () {
      final environmentStore = InMemoryEnvironmentStore.sample();
      final viewModel = workspaceViewModel(
        assetRepository: InMemoryApiAssetRepository.demo(),
        environmentStore: environmentStore,
      );
      environmentStore.setActiveEnvironment('geoip-lookup');

      viewModel.updateActiveDraftUrl(
        '{{baseUrl}}/tools/geoip/lookup?input={{domain}}',
      );

      expect(viewModel.activeAvailableEnvironmentParameters, isEmpty);
      expect(
        viewModel.activeDraftUrl,
        '{{baseUrl}}/tools/geoip/lookup?input={{domain}}',
      );
      expect(
        viewModel.resolvedUrl,
        'https://www.reurl.to/tools/geoip/lookup?input=qq.com',
      );
    },
  );

  test(
    'bulk tab close keeps the requested tab and settles active state once',
    () {
      final viewModel = workspaceViewModel(
        assetRepository: InMemoryApiAssetRepository.demo(),
      );
      viewModel.selectRequest('demo-rest-create-user');
      viewModel.selectRequest('demo-rest-replace-user');
      final target = viewModel.openRequestTabs[1];

      viewModel.closeRequestTabs([
        for (final tab in viewModel.openRequestTabs)
          if (tab.id != target.id) tab.id,
      ]);

      expect(viewModel.openRequestTabs, hasLength(1));
      expect(viewModel.openRequestTabs.single.id, target.id);
      expect(viewModel.activeRequest.id, target.requestId);
    },
  );

  // 场景：独立 Auth 不会侵入 Headers，关闭认证后业务请求头保持原样。
  test('Bearer authentication does not mutate request headers', () {
    final viewModel = workspaceViewModel(
      assetRepository: InMemoryApiAssetRepository.demo(),
    );

    viewModel.addActiveDraftField(headers: true);
    viewModel.updateActiveDraftField(
      headers: true,
      index: 0,
      keyName: 'X-Workspace',
      value: 'sendreq.desktop',
    );
    viewModel.setActiveBearerAuthentication(false);

    expect(viewModel.usesBearerAuthentication, isFalse);
    expect(viewModel.activeDraft.headers.single.keyName, 'X-Workspace');
  });

  // 场景：Headers 中的自定义 Authorization 与独立 Auth 配置互不改写。
  test(
    'custom authorization is never removed by bearer authentication controls',
    () {
    final viewModel = workspaceViewModel(
      assetRepository: InMemoryApiAssetRepository.demo(),
    );

      viewModel.addActiveDraftField(headers: true);
      viewModel.updateActiveDraftField(
        headers: true,
        index: 0,
        keyName: 'Authorization',
        value: 'Basic ZGVtbzpwYXNz',
      );
      viewModel.setActiveBearerAuthentication(false);

      expect(viewModel.usesBearerAuthentication, isFalse);
      expect(viewModel.activeDraft.headers.first.value, 'Basic ZGVtbzpwYXNz');
    },
  );

  // 场景：正文是否提供 JSON 编辑能力应跟随当前启用的 Content-Type。
  test('body JSON affordances follow the enabled Content-Type header', () {
    final viewModel = workspaceViewModel(
      assetRepository: InMemoryApiAssetRepository.demo(),
    );

    expect(viewModel.usesJsonBody, isFalse);
    viewModel.updateActiveContentType('application/json');
    expect(viewModel.usesJsonBody, isTrue);
    viewModel.updateActiveContentType(null);
    expect(viewModel.usesJsonBody, isFalse);
  });

  // WebSocket 会话绑定请求标签而非可见页面：切换到历史后仍接收服务端帧。
  test(
    'WebSocket stays connected and records frames while viewing history',
    () async {
      final transport = _TestWebSocketTransport();
      final viewModel = _webSocketViewModel(transport);
      await viewModel.connectActiveWebSocket();

      viewModel.selectSection(WorkspaceSection.history);
      transport.connection.emit(const WebSocketTransportEvent.text('update'));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.activeSection, WorkspaceSection.history);
      expect(viewModel.activeWebSocketSession.canSend, isTrue);
      expect(viewModel.activeWebSocketSession.events.single.preview, 'update');
    },
  );

  // 关闭承载会话的请求标签必须释放底层连接，不能继续在后台接收帧。
  test('closing a WebSocket request tab disconnects its session', () async {
    final transport = _TestWebSocketTransport();
    final viewModel = _webSocketViewModel(transport);
    await viewModel.connectActiveWebSocket();
    final tabId = viewModel.openRequestTabs.single.id;

    viewModel.closeRequestTab(tabId);
    await Future<void>.delayed(Duration.zero);

    expect(transport.connection.closed, isTrue);
    expect(viewModel.openRequestTabs, isEmpty);
    expect(viewModel.activeSection, WorkspaceSection.dashboard);
  });

  test(
    'WebSocket termination adds one redacted session summary to history',
    () async {
      final transport = _TestWebSocketTransport();
      final viewModel = _webSocketViewModel(transport);
      viewModel.updateActiveDraftUrl('ws://localhost/events?token=token-value');
      viewModel.updateActiveDraftField(headers: false, index: 0, secret: true);

      await viewModel.connectActiveWebSocket();
      transport.connection.emit(const WebSocketTransportEvent.text('inbound'));
      await Future<void>.delayed(Duration.zero);
      await viewModel.sendActiveWebSocketMessage();
      await viewModel.disconnectActiveWebSocket();

      final record = viewModel.history.first;
      final summary = record.webSocketSummary;
      expect(record.method, 'WS');
      expect(summary?.terminalStatus, 'closed');
      expect(summary?.inboundMessageCount, 1);
      expect(summary?.outboundMessageCount, 1);
      expect(summary?.endpoint, contains('••••••••'));
      expect(summary?.endpoint, isNot(contains('token-value')));
      expect(record.requestSnapshot, isNull);
      expect(record.response, isNull);
    },
  );

  // 草稿可在未连接状态持续编辑，但发送操作不得触达 transport。
  test(
    'unconnected WebSocket message remains a draft and is not sent',
    () async {
      final transport = _TestWebSocketTransport();
      final viewModel = _webSocketViewModel(transport);
      viewModel.updateActiveWebSocketMessage('{"event":"ping"}');

      await viewModel.sendActiveWebSocketMessage();

      expect(viewModel.activeWebSocketMessageDraft.payload, '{"event":"ping"}');
      expect(transport.connection.sentText, isEmpty);
      expect(viewModel.lastActionMessage, 'Connect before sending a message.');
    },
  );

  test(
    'WebSocket sends the supported text and MessagePack formats in their required frames',
    () async {
      final transport = _TestWebSocketTransport();
      final viewModel = _webSocketViewModel(transport);
      await viewModel.connectActiveWebSocket();

      viewModel.updateActiveWebSocketMessage('ready');
      await viewModel.sendActiveWebSocketMessage();

      viewModel.updateActiveWebSocketMessageMode(WebSocketComposerMode.json);
      viewModel.updateActiveWebSocketMessage('{"event":"ready"}');
      await viewModel.sendActiveWebSocketMessage();

      viewModel.updateActiveWebSocketMessageMode(WebSocketComposerMode.xml);
      viewModel.updateActiveWebSocketMessage('<event>ready</event>');
      await viewModel.sendActiveWebSocketMessage();

      viewModel.updateActiveWebSocketMessageMode(
        WebSocketComposerMode.messagePack,
      );
      viewModel.updateActiveWebSocketMessage('AQI=');
      await viewModel.sendActiveWebSocketMessage();

      expect(transport.connection.sentText, [
        'ready',
        '{"event":"ready"}',
        '<event>ready</event>',
      ]);
      expect(transport.connection.sentBinary, hasLength(1));
      expect(
        transport.connection.sentBinary.single,
        Uint8List.fromList([1, 2]),
      );
      expect(
        viewModel.activeWebSocketSession.events.map((event) => event.preview),
        containsAll([
          'JSON: {"event":"ready"}',
          'XML: <event>ready</event>',
          'MessagePack (2 bytes)',
        ]),
      );
    },
  );

  test(
    'failed gRPC proto import preserves the existing schema association',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-grpc-');
      addTearDown(() => directory.delete(recursive: true));
      final validProto = File('${directory.path}/known-good.proto');
      await validProto.writeAsString(
        'syntax = "proto3"; message CheckRequest { string name = 1; }',
      );
      final invalidProto = File('${directory.path}/health.proto');
      await invalidProto.writeAsString(
        'syntax = "proto3"; import "missing.proto";',
      );
      final viewModel = workspaceViewModel(
        assetRepository: InMemoryApiAssetRepository.demo(),
      );
      viewModel.updateActiveDraftProtocol(ApiRequestProtocol.grpc);
      expect(await viewModel.importActiveGrpcProto(validProto.path), isNull);
      final existingSchema = viewModel.activeDraft.grpc.protoSchema!;

      final error = await viewModel.importActiveGrpcProto(invalidProto.path);

      expect(error, contains('missing.proto'));
      expect(viewModel.activeDraft.grpc.protoSchema?.path, existingSchema.path);
      expect(
        viewModel.activeDraft.grpc.protoSchema?.fingerprint,
        existingSchema.fingerprint,
      );
    },
  );

  test(
    'gRPC JSON drafts show protobuf encoding previews and field errors',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-grpc-');
      addTearDown(() => directory.delete(recursive: true));
      final proto = File('${directory.path}/health.proto');
      await proto.writeAsString(
        'syntax = "proto3"; package sendreq; message Check { string host = 1; } service Health { rpc Check (Check) returns (Check); }',
      );
      final viewModel = workspaceViewModel(
        assetRepository: InMemoryApiAssetRepository.demo(),
      );
      viewModel.updateActiveDraftProtocol(ApiRequestProtocol.grpc);
      expect(await viewModel.importActiveGrpcProto(proto.path), isNull);
      viewModel.selectActiveGrpcService('.sendreq.Health');
      viewModel.selectActiveGrpcMethod('Check');
      viewModel.updateActiveDraftBody('{"host":"api.sendreq.io"}');

      expect(viewModel.activeRequestSupportsBody, isTrue);
      expect(viewModel.activeGrpcRequestPreview?.byteLength, 16);

      viewModel.updateActiveDraftBody('{"unknown":true}');
      expect(
        viewModel.activeGrpcRequestPreview?.error,
        'Unknown field: unknown',
      );
    },
  );

  test('gRPC send uses its transport and decodes timeline messages', () async {
    final directory = await Directory.systemTemp.createTemp('sendreq-grpc-');
    addTearDown(() => directory.delete(recursive: true));
    final proto = File('${directory.path}/health.proto');
    await proto.writeAsString(
      'syntax = "proto3"; package sendreq; message Check { string host = 1; } service Health { rpc Check (Check) returns (Check); }',
    );
    final transport = _TestGrpcTransport();
    final viewModel = workspaceViewModel(
      assetRepository: InMemoryApiAssetRepository.demo(),
      grpcTransport: transport,
    );
    viewModel.updateActiveDraftProtocol(ApiRequestProtocol.grpc);
    viewModel.updateActiveDraftUrl('http://127.0.0.1:8080');
    await viewModel.importActiveGrpcProto(proto.path);
    viewModel.selectActiveGrpcService('.sendreq.Health');
    viewModel.selectActiveGrpcMethod('Check');
    viewModel.updateActiveDraftBody('{"host":"api"}');

    await viewModel.sendActiveRequest();
    transport.call.emit(
      GrpcTransportEvent.message(Uint8List.fromList([10, 3, 97, 112, 105])),
    );
    transport.call.emit(const GrpcTransportEvent.status(0, 'OK'));
    await Future<void>.delayed(Duration.zero);

    expect(transport.configurations, hasLength(1));
    expect(viewModel.activeGrpcCall.state, GrpcCallState.completed);
    expect(
      viewModel
          .decodeActiveGrpcEvent(viewModel.activeGrpcCall.events.first)
          ?.formattedJson,
      contains('"host": "api"'),
    );
  });

  test(
    'gRPC streams survive page changes and close with their request tab',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-grpc-');
      addTearDown(() => directory.delete(recursive: true));
      final proto = File('${directory.path}/health.proto');
      await proto.writeAsString(
        'syntax = "proto3"; package sendreq; message Check { string host = 1; } service Health { rpc Watch (Check) returns (stream Check); }',
      );
      final transport = _TestGrpcTransport();
      final viewModel = workspaceViewModel(
        assetRepository: InMemoryApiAssetRepository.demo(),
        grpcTransport: transport,
      );
      viewModel.updateActiveDraftProtocol(ApiRequestProtocol.grpc);
      viewModel.updateActiveDraftUrl('http://127.0.0.1:8080');
      await viewModel.importActiveGrpcProto(proto.path);
      viewModel.selectActiveGrpcService('.sendreq.Health');
      viewModel.selectActiveGrpcMethod('Watch');
      viewModel.updateActiveDraftBody('{"host":"api"}');
      await viewModel.sendActiveGrpcRequest();

      viewModel.selectSection(WorkspaceSection.history);
      transport.call.emit(
        GrpcTransportEvent.message(Uint8List.fromList([10, 3, 97, 112, 105])),
      );
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.activeGrpcCall.events, hasLength(1));

      final tab = viewModel.openRequestTabs.singleWhere(
        (item) => item.requestId == 'demo-rest-list-users',
      );
      viewModel.closeRequestTab(tab.id);
      await Future<void>.delayed(Duration.zero);
      expect(transport.call.cancelled, isTrue);
    },
  );

  // 场景：保存请求时，multipart 的表单字段、批量文件名与文件大小等信息应完整保留。
  test('multipart file selections survive saving the request', () {
    final repository = InMemoryApiAssetRepository.demo();
    final viewModel = workspaceViewModel(assetRepository: repository);

    viewModel.updateActiveContentType('multipart/form-data');
    viewModel.addActiveMultipartField();
    viewModel.updateActiveMultipartField(
      index: 0,
      keyName: 'description',
      value: 'avatar',
    );
    viewModel.addActiveMultipartFile(
      path: '/tmp/avatar.png',
      fileName: 'avatar.png',
      sizeBytes: 2048,
      keyName: 'files[]',
    );
    viewModel.addActiveMultipartFile(
      path: '/tmp/banner.png',
      fileName: 'banner.png',
      sizeBytes: 4096,
      keyName: 'files[]',
    );
    viewModel.updateAllActiveMultipartFileKeyNames('attachments');
    viewModel.saveRequest('demo-rest-list-users');

    final saved = repository.getRequest('demo-rest-list-users');
    expect(
      saved.headers
          .singleWhere((header) => header.key.toLowerCase() == 'content-type')
          .value,
      'multipart/form-data',
    );
    expect(saved.multipartFields.single.key, 'description');
    expect(saved.multipartFiles, hasLength(2));
    expect(
      saved.multipartFiles.map((file) => file.key),
      everyElement('attachments'),
    );
    expect(saved.multipartFiles.first.sizeBytes, 2048);
  });
}

/// 可手动控制完成时机的运行时：由测试显式完成响应，并统计 cancel 调用次数。
class _TestGrpcTransport implements GrpcTransport {
  final call = _TestGrpcCall();
  final configurations = <GrpcCallConfiguration>[];

  @override
  Future<GrpcCall> start(GrpcCallConfiguration configuration) async {
    configurations.add(configuration);
    return call;
  }
}

class _TestGrpcCall implements GrpcCall {
  final _events = StreamController<GrpcTransportEvent>.broadcast();
  bool cancelled = false;

  @override
  Stream<GrpcTransportEvent> get events => _events.stream;

  void emit(GrpcTransportEvent event) => _events.add(event);

  @override
  Future<void> cancel() async {
    cancelled = true;
    await _events.close();
  }
}

class _ControlledRuntime implements RequestExecutionRuntime {
  final response = Completer<RuntimeResponse>();
  int cancelCount = 0;

  @override
  void cancel() => cancelCount++;

  @override
  Future<RuntimeResponse> send({
    required RequestDraft draft,
    required String resolvedUrl,
  }) => response.future;
}

/// 立即返回固定成功响应的运行时，供多数同步场景使用。
class _ImmediateRuntime implements RequestExecutionRuntime {
  @override
  void cancel() {}

  @override
  Future<RuntimeResponse> send({
    required RequestDraft draft,
    required String resolvedUrl,
  }) async => _response();
}

/// 捕获 ViewModel 交给运行时的最终草稿，用于验证执行前的变量解析。
class _CapturingRuntime implements RequestExecutionRuntime {
  final List<RequestDraft> drafts = [];
  final List<String> resolvedUrls = [];

  @override
  void cancel() {}

  @override
  Future<RuntimeResponse> send({
    required RequestDraft draft,
    required String resolvedUrl,
  }) async {
    drafts.add(draft);
    resolvedUrls.add(resolvedUrl);
    return _response();
  }
}

/// 构造一个固定的最小化成功响应（200、空对象体）。
RuntimeResponse _response() => const RuntimeResponse(
  statusCode: 200,
  timeMs: 1,
  sizeKb: 0.1,
  body: '{}',
  headers: [],
);

/// 为 WebSocket 工作区测试创建已配置但尚未连接的请求。
WorkspaceViewModel _webSocketViewModel(_TestWebSocketTransport transport) {
  final viewModel = workspaceViewModel(
    assetRepository: InMemoryApiAssetRepository.demo(),
    webSocketTransport: transport,
  );
  viewModel.updateActiveDraftProtocol(ApiRequestProtocol.webSocket);
  viewModel.updateActiveDraftUrl('ws://localhost/events');
  return viewModel;
}

/// 可观察握手配置并手动推送入站帧的传输替身。
class _TestWebSocketTransport implements WebSocketTransport {
  final connection = _TestWebSocketConnection();
  final configurations = <WebSocketConnectionConfiguration>[];

  @override
  Future<WebSocketConnection> connect(
    WebSocketConnectionConfiguration configuration,
  ) async {
    configurations.add(configuration);
    return connection;
  }
}

/// 记录发送结果与关闭状态，避免工作区测试访问真实网络。
class _TestWebSocketConnection implements WebSocketConnection {
  final _events = StreamController<WebSocketTransportEvent>.broadcast();
  final sentText = <String>[];
  final sentBinary = <Uint8List>[];
  bool closed = false;

  @override
  Stream<WebSocketTransportEvent> get events => _events.stream;

  void emit(WebSocketTransportEvent event) => _events.add(event);

  @override
  Future<void> close() async {
    closed = true;
    await _events.close();
  }

  @override
  Future<void> sendBinary(Uint8List value) async {
    sentBinary.add(Uint8List.fromList(value));
  }

  @override
  Future<void> sendText(String value) async {
    sentText.add(value);
  }
}
