import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_user_notice_repository.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/data/repositories/in_memory_environment_store.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/grpc/grpc_transport.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/domain/request_runtime/request_execution_runtime.dart';
import 'package:sendreq/domain/websocket/websocket_transport.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/ui/shell/models/workspace_shell_models.dart';

import 'support/workspace_view_model_test_factory.dart';
import 'support/module_boundary_fakes.dart';

const _grpcFlowProto = '''
syntax = "proto3";
package sendreq;
message FlowMessage { string value = 1; }
service Flow {
  rpc Unary (FlowMessage) returns (FlowMessage);
  rpc Client (stream FlowMessage) returns (FlowMessage);
  rpc Server (FlowMessage) returns (stream FlowMessage);
  rpc Bidi (stream FlowMessage) returns (stream FlowMessage);
}
''';

// WorkspaceViewModel 的状态机单元测试：不依赖真实运行时与 UI，
// 覆盖发送/取消、删除保护、草稿编辑与授权/上传等数据行为。
void main() {
  test('request working views are transient and default new protocol', () {
    final viewModel = workspaceViewModel();
    addTearDown(viewModel.dispose);
    final initialRequestId = viewModel.activeRequest.id;

    viewModel.selectRequestWorkingView(RequestWorkingView.grpc);

    expect(viewModel.requestWorkingView, RequestWorkingView.grpc);
    expect(viewModel.activeRequest.id, initialRequestId);
    expect(viewModel.grpcCalls, isEmpty);
    expect(viewModel.webSocketSessions, isEmpty);

    viewModel.createRequest();

    expect(viewModel.activeDraft.protocol, ApiRequestProtocol.grpc);
    expect(viewModel.requestWorkingView, RequestWorkingView.grpc);
  });

  test(
    'restores and acknowledges durable notices through Workspace startup',
    () async {
      final repository = InMemoryUserNoticeRepository();
      await repository.upsertUnread(
        PersistentUserNotice(
          deduplicationKey: 'outcome:mockServer.startFailed:mockServer:mock-1',
          code: 'mockServer.startFailed',
          severity: DurableNoticeSeverity.error,
          createdAt: DateTime.utc(2026, 8, 11),
          updatedAt: DateTime.utc(2026, 8, 11),
          resourceRef: const ResourceRef(
            kind: ResourceKind.mockServer,
            id: 'mock-1',
          ),
          recovery: RecoveryCommand(
            id: RecoveryCommandId.retryMockServerStart,
            resourceRef: const ResourceRef(
              kind: ResourceKind.mockServer,
              id: 'mock-1',
            ),
          ),
        ),
      );
      final viewModel = workspaceViewModel(userNoticeRepository: repository);
      addTearDown(viewModel.dispose);

      await Future<void>.delayed(Duration.zero);

      expect(viewModel.notices, hasLength(1));
      expect(
        viewModel.notices.single.recovery!.id,
        RecoveryCommandId.retryMockServerStart,
      );
      await viewModel.acknowledgeNotice(
        viewModel.notices.single.deduplicationKey,
      );
      expect(viewModel.notices, isEmpty);
      expect(await repository.listUnread(), isEmpty);
    },
  );

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

  test('cancellation forwards the Environment-owned execution id', () async {
    const executionId = 'environment-owned-execution';
    final service = _PendingExecutionService();
    final viewModel = workspaceViewModel(
      environmentResolver: FakeEnvironmentResolver(
        ResolvedExecutionCommand(
          executionId: executionId,
          requestRef: const RequestRef(id: 'demo-rest-list-users'),
          payload: ExecutionPayload(
            method: 'GET',
            resolvedUrl: 'https://api.example.test/users',
            draft: const RequestDraft(
              method: 'GET',
              baseUrlToken: 'https://api.example.test',
              path: '/users',
              params: [],
              headers: [],
              body: '',
            ),
          ),
          sanitizedRequestSummary: 'GET api.example.test/users',
          redactionPolicy: RedactionPolicy(const []),
        ),
      ),
      executionService: service,
    );
    addTearDown(viewModel.dispose);

    final send = viewModel.sendActiveRequest();
    await service.started.future;
    viewModel.cancelActiveRequest();

    expect(service.cancelledExecutionIds, [executionId]);
    service.result.complete(
      const SanitizedExecutionResult(
        executionId: executionId,
        requestRef: RequestRef(id: 'demo-rest-list-users'),
        status: OperationOutcomeKind.cancelled,
        summary: 'Cancelled',
      ),
    );
    await send;
  });

  test('response-derived Mock opens with predictable selection', () async {
    final publishing = FakeContractPublishingService();
    final viewModel = workspaceViewModel(
      contractPublishingService: publishing,
      executionRuntime: _ImmediateRuntime(),
    );
    addTearDown(viewModel.dispose);

    await viewModel.sendActiveRequest();
    viewModel.createMockServerFromResponse();
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.activeSection, WorkspaceSection.mock);
    expect(viewModel.activeMockServerId, 'mock-1');
    expect(publishing.mockSnapshots, hasLength(1));
  });

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
      expect(
        viewModel.resolvedUrl,
        'http://127.0.0.1:8081/api/v1/users?page=1&limit=20',
      );

      await viewModel.sendActiveRequest();
      expect(runtime.resolvedUrls, [
        'http://127.0.0.1:8081/api/v1/users?page=1&limit=20',
        'http://127.0.0.1:8081/api/v1/users?page=1&limit=20',
      ]);
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
            urlTemplate: '{{baseUrl}}/geoip/$endpoint?ip={{ip}}&lang={{lang}}',
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

  // WebSocket 会话绑定请求标签而非可见页面：切换页面后仍接收服务端帧。
  test(
    'WebSocket stays connected and records frames while viewing Settings',
    () async {
      final transport = _TestWebSocketTransport();
      final viewModel = _webSocketViewModel(transport);
      await viewModel.connectActiveWebSocket();

      viewModel.selectSection(WorkspaceSection.settings);
      transport.connection.emit(const WebSocketTransportEvent.text('update'));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.activeSection, WorkspaceSection.settings);
      expect(viewModel.activeWebSocketSession.canSend, isTrue);
      expect(viewModel.activeWebSocketSession.events.single.preview, 'update');
    },
  );

  test(
    'WebSocket keeps its environment snapshot when the active environment changes',
    () async {
      final transport = _TestWebSocketTransport();
      final viewModel = _webSocketViewModel(transport);

      await viewModel.connectActiveWebSocket();
      final before = viewModel.activeWebSocketSession;

      viewModel.selectEnvironment('production');

      final after = viewModel.activeWebSocketSession;
      expect(after.state, WebSocketConnectionState.connected);
      expect(after.endpoint, before.endpoint);
      expect(after.sessionContext.environmentName, 'Staging');
      expect(
        after.sessionContext.authenticationLabel,
        'Environment Bearer token',
      );
      expect(after.requiresReconnect, isTrue);
      expect(transport.configurations, hasLength(1));
      expect(transport.connection.closed, isFalse);
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
    expect(viewModel.activeSection, WorkspaceSection.requests);
  });

  test('disposing the Workspace releases active WebSocket sessions', () async {
    final transport = _TestWebSocketTransport();
    final viewModel = _webSocketViewModel(transport);

    await viewModel.connectActiveWebSocket();
    viewModel.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(transport.connection.closed, isTrue);
  });

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
        '{\n  "event": "ready"\n}',
        '<event>ready</event>',
      ]);
      expect(transport.connection.sentBinary, hasLength(1));
      expect(
        transport.connection.sentBinary.single,
        Uint8List.fromList([1, 2]),
      );
      expect(viewModel.activeWebSocketMessageDraft.payload, isEmpty);
      expect(
        viewModel.activeWebSocketSession.events.map((event) => event.preview),
        containsAll([
          'JSON: {\n  "event": "ready"\n}',
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

      expect(
        error,
        'Could not import proto source. Review the file and try again.',
      );
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

    viewModel.dispatch(
      WorkspaceGlobalAction(
        type: WorkspaceActionType.send,
        source: WorkspaceActionSource.keyboard,
      ),
    );
    await Future<void>.delayed(Duration.zero);
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

      viewModel.selectSection(WorkspaceSection.settings);
      transport.call.emit(
        GrpcTransportEvent.message(Uint8List.fromList([10, 3, 97, 112, 105])),
      );
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.activeGrpcCall.events.map((event) => event.kind), [
        GrpcTransportEventKind.request,
        GrpcTransportEventKind.message,
      ]);

      final tab = viewModel.openRequestTabs.singleWhere(
        (item) => item.requestId == 'demo-rest-list-users',
      );
      viewModel.closeRequestTab(tab.id);
      await Future<void>.delayed(Duration.zero);
      expect(transport.call.cancelled, isTrue);
    },
  );

  test(
    'gRPC client streams send messages and retain outbound timeline data',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-grpc-');
      addTearDown(() => directory.delete(recursive: true));
      final proto = File('${directory.path}/health.proto');
      await proto.writeAsString(
        'syntax = "proto3"; package sendreq; message Check { string host = 1; } service Health { rpc Chat (stream Check) returns (stream Check); }',
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
      viewModel.selectActiveGrpcMethod('Chat');
      expect(viewModel.activeRequestTab, 'Body');
      viewModel.updateActiveDraftBody('{"host":"api"}');

      await viewModel.sendActiveGrpcRequest();
      expect(transport.configurations.single.clientStreaming, isTrue);
      expect(transport.call.sentMessages, isEmpty);
      expect(viewModel.canSendActiveGrpcMessage, isTrue);

      await viewModel.sendActiveGrpcMessage();
      final requestEvent = viewModel.activeGrpcCall.events.single;
      expect(transport.call.sentMessages, [
        Uint8List.fromList([10, 3, 97, 112, 105]),
      ]);
      expect(requestEvent.kind, GrpcTransportEventKind.request);
      expect(
        viewModel.decodeActiveGrpcEvent(requestEvent)?.formattedJson,
        contains('"host": "api"'),
      );

      await viewModel.closeActiveGrpcRequestStream();
      expect(transport.call.requestStreamClosed, isTrue);
      expect(viewModel.canSendActiveGrpcMessage, isFalse);
    },
  );

  test(
    'request-only No auth does not inherit environment Bearer metadata for gRPC',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-grpc-');
      addTearDown(() => directory.delete(recursive: true));
      final proto = File('${directory.path}/health.proto');
      await proto.writeAsString(
        'syntax = "proto3"; package sendreq; message Check { string host = 1; } service Health { rpc Check (Check) returns (Check); }',
      );
      final transport = _TestGrpcTransport();
      final viewModel = workspaceViewModel(
        assetRepository: InMemoryApiAssetRepository.demo(),
        environmentStore: InMemoryEnvironmentStore.sample(),
        grpcTransport: transport,
      );
      viewModel.updateActiveDraftProtocol(ApiRequestProtocol.grpc);
      viewModel.updateActiveDraftUrl('http://127.0.0.1:50051');
      await viewModel.importActiveGrpcProto(proto.path);
      viewModel.selectActiveGrpcService('.sendreq.Health');
      viewModel.selectActiveGrpcMethod('Check');
      viewModel.updateActiveDraftBody('{"host":"api"}');
      viewModel.setActiveAuthenticationSource(
        RequestAuthenticationSource.request,
      );
      viewModel.setActiveAuthenticationType(RequestAuthenticationType.none);

      await viewModel.sendActiveGrpcRequest();

      expect(
        transport.configurations.single.metadata,
        isNot(contains('authorization')),
      );
      expect(
        viewModel.activeGrpcCall.sessionContext.authenticationLabel,
        'No authentication',
      );
    },
  );

  test(
    'gRPC keeps its snapshot across environment changes but not message draft edits',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-grpc-');
      addTearDown(() => directory.delete(recursive: true));
      final proto = File('${directory.path}/chat.proto');
      await proto.writeAsString(
        'syntax = "proto3"; package sendreq; message Check { string host = 1; } service Health { rpc Chat (stream Check) returns (stream Check); }',
      );
      final transport = _TestGrpcTransport();
      final viewModel = workspaceViewModel(
        assetRepository: InMemoryApiAssetRepository.demo(),
        grpcTransport: transport,
      );
      viewModel.updateActiveDraftProtocol(ApiRequestProtocol.grpc);
      viewModel.updateActiveDraftUrl('{{baseUrl}}');
      viewModel.setActiveAuthenticationSource(
        RequestAuthenticationSource.environment,
      );
      await viewModel.importActiveGrpcProto(proto.path);
      viewModel.selectActiveGrpcService('.sendreq.Health');
      viewModel.selectActiveGrpcMethod('Chat');
      viewModel.updateActiveDraftBody('{"host":"before"}');

      await viewModel.sendActiveGrpcRequest();
      viewModel.updateActiveDraftBody('{"host":"after"}');

      expect(viewModel.activeGrpcCall.requiresRestart, isFalse);
      expect(
        viewModel.activeGrpcCall.sessionContext.environmentName,
        'Staging',
      );
      expect(transport.call.cancelled, isFalse);

      viewModel.selectEnvironment('production');

      expect(viewModel.activeGrpcCall.state, GrpcCallState.running);
      expect(
        viewModel.activeGrpcCall.sessionContext.environmentName,
        'Staging',
      );
      expect(
        viewModel.activeGrpcCall.sessionContext.authenticationLabel,
        'Environment Bearer token',
      );
      expect(viewModel.activeGrpcCall.requiresRestart, isTrue);
      expect(transport.configurations, hasLength(1));
      expect(transport.call.cancelled, isFalse);

      await viewModel.restartActiveGrpcCall();

      expect(transport.configurations, hasLength(2));
      expect(
        transport.configurations.last.effectiveSessionContext.environmentName,
        'Production',
      );
      expect(
        transport.configurations.last.effectiveSessionContext.environmentId,
        'production',
      );
      expect(
        transport.configurations.last.effectiveSessionContext.rpcShape,
        GrpcRpcShape.bidirectionalStreaming,
      );
      expect(viewModel.activeGrpcCall.requiresRestart, isFalse);
    },
  );

  test(
    'every gRPC shape freezes its environment across unsaved token changes',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-grpc-');
      addTearDown(() => directory.delete(recursive: true));
      final proto = File('${directory.path}/flow.proto');
      await proto.writeAsString(_grpcFlowProto);
      final cases = <String, GrpcRpcShape>{
        'Unary': GrpcRpcShape.unary,
        'Client': GrpcRpcShape.clientStreaming,
        'Server': GrpcRpcShape.serverStreaming,
        'Bidi': GrpcRpcShape.bidirectionalStreaming,
      };

      for (final entry in cases.entries) {
        final environments = InMemoryEnvironmentStore.sample();
        final transport = _TestGrpcTransport();
        final viewModel = workspaceViewModel(
          assetRepository: InMemoryApiAssetRepository.demo(),
          environmentStore: environments,
          grpcTransport: transport,
        );
        viewModel.updateActiveDraftProtocol(ApiRequestProtocol.grpc);
        viewModel.updateActiveDraftUrl('{{baseUrl}}');
        viewModel.setActiveAuthenticationSource(
          RequestAuthenticationSource.environment,
        );
        expect(await viewModel.importActiveGrpcProto(proto.path), isNull);
        viewModel.selectActiveGrpcService('.sendreq.Flow');
        viewModel.selectActiveGrpcMethod(entry.key);
        viewModel.updateActiveDraftBody('{"value":"before"}');

        await viewModel.sendActiveGrpcRequest();
        expect(
          viewModel.activeGrpcCall.rpcShape,
          entry.value,
          reason: entry.key,
        );
        expect(
          viewModel.activeGrpcCall.sessionContext.environmentName,
          'Staging',
          reason: entry.key,
        );

        viewModel.updateEnvironmentVariable(
          id: 'staging-token',
          value: 'unsaved-${entry.value.name}-token',
        );

        expect(viewModel.hasEnvironmentChanges, isTrue, reason: entry.key);
        expect(viewModel.activeGrpcCall.requiresRestart, isTrue);
        expect(viewModel.activeGrpcCall.state, GrpcCallState.running);
        expect(
          viewModel.activeGrpcCall.sessionContext.environmentName,
          'Staging',
        );
        expect(transport.call.cancelled, isFalse);

        viewModel.selectEnvironment('production');
        expect(viewModel.hasEnvironmentChanges, isTrue, reason: entry.key);
        expect(
          viewModel.activeGrpcCall.sessionContext.environmentName,
          'Staging',
        );

        await viewModel.restartActiveGrpcCall();
        expect(
          transport.configurations.last.effectiveSessionContext.rpcShape,
          entry.value,
        );
        expect(
          transport.configurations.last.effectiveSessionContext.environmentName,
          'Production',
        );
        expect(viewModel.activeGrpcCall.requiresRestart, isFalse);
        viewModel.dispose();
      }
    },
  );

  test('opening a gRPC request starts on the message composer', () {
    final viewModel = workspaceViewModel(
      assetRepository: InMemoryApiAssetRepository.demo(),
    );

    viewModel.selectRequest('demo-grpc-order-chat');

    expect(viewModel.activeRequestTab, 'Body');
  });

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

class _PendingExecutionService implements ExecutionService {
  final started = Completer<void>();
  final result = Completer<SanitizedExecutionResult>();
  final List<String> cancelledExecutionIds = [];

  @override
  Future<void> disposeRequestSessions(RequestRef requestRef) async {}

  @override
  Future<SanitizedExecutionResult> execute(ResolvedExecutionCommand command) {
    started.complete();
    return result.future;
  }

  @override
  Future<OperationOutcome> cancel(String executionId) async {
    cancelledExecutionIds.add(executionId);
    return OperationOutcome(
      kind: OperationOutcomeKind.cancelled,
      code: 'execution.cancelRequested',
      relatedExecutionId: executionId,
    );
  }

  @override
  Future<SanitizedSessionProjection?> session(String sessionId) async => null;
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
  bool requestStreamClosed = false;
  final sentMessages = <Uint8List>[];

  @override
  Stream<GrpcTransportEvent> get events => _events.stream;

  void emit(GrpcTransportEvent event) => _events.add(event);

  @override
  Future<void> send(Uint8List message) async {
    sentMessages.add(Uint8List.fromList(message));
  }

  @override
  Future<void> closeRequestStream() async {
    requestStreamClosed = true;
  }

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
WorkspaceViewModel _webSocketViewModel(
  _TestWebSocketTransport transport, {
  ContractPublishingService? contractPublishingService,
}) {
  final viewModel = workspaceViewModel(
    assetRepository: InMemoryApiAssetRepository.demo(),
    webSocketTransport: transport,
    contractPublishingService: contractPublishingService,
  );
  viewModel.updateActiveDraftProtocol(ApiRequestProtocol.webSocket);
  viewModel.updateActiveDraftUrl('ws://localhost/events');
  viewModel.setActiveAuthenticationSource(
    RequestAuthenticationSource.environment,
  );
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
