import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/data/repositories/in_memory_environment_store.dart';
import 'package:sendreq/data/repositories/in_memory_user_notice_repository.dart';
import 'package:sendreq/data/repositories/in_memory_workspace_preference_store.dart';
import 'package:sendreq/data/demo/demo_example_catalog.dart';
import 'package:sendreq/data/services/desktop_grpc_transport.dart';
import 'package:sendreq/data/services/desktop_websocket_transport.dart';
import 'package:sendreq/domain/grpc/protobuf_dynamic_codec.dart';
import 'package:sendreq/data/services/http_request_execution_runtime.dart';
import 'package:sendreq/data/services/openapi_request_importer.dart';
import 'package:sendreq/data/services/openapi_request_exporter.dart';
import 'package:sendreq/data/services/openapi_file_exporter.dart';
import 'package:sendreq/data/services/local_workspace_file_ports.dart';
import 'package:sendreq/data/services/openapi_output_directory.dart';
import 'package:sendreq/data/services/openapi_markdown_documentation_renderer.dart';
import 'package:sendreq/data/services/markdown_documentation_file_exporter.dart';
import 'package:sendreq/data/services/proto_source_parser.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/grpc/grpc_transport.dart';
import 'package:sendreq/domain/request_runtime/grpc_execution_service.dart';
import 'package:sendreq/domain/request_runtime/request_execution_runtime.dart';
import 'package:sendreq/domain/request_runtime/websocket_execution_service.dart';
import 'package:sendreq/domain/request_runtime/http_execution_service.dart';
import 'package:sendreq/domain/environments/environment_execution_resolver.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/domain/websocket/websocket_transport.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

import 'support/module_boundary_fakes.dart';

/// 真实的 Go 互操作测试为可选启用，因为它们会启动本地 Go 进程。
///
/// 在各桌面操作系统上通过以下命令运行：
/// `SENDREQ_GO_INTEROP=1 flutter test test/go_protocol_interop_test.dart`
final _enabled =
    Platform.environment['SENDREQ_GO_INTEROP'] == '1' ||
    const bool.fromEnvironment('SENDREQ_GO_INTEROP');
final _liveFixturesEnabled =
    Platform.environment['SENDREQ_LIVE_PROTOCOL_SERVICES'] == '1' ||
    const bool.fromEnvironment('SENDREQ_LIVE_PROTOCOL_SERVICES');

const _testToken = 'reurl_fca7a7c2b59c650b51de801789108dc7dc2abb7bbd58ff7f';
const _configuredProtocolToken = _testToken;

WorkspaceViewModel _workspaceViewModel() {
  final environmentStore = InMemoryEnvironmentStore.sample();
  final authenticated = environmentStore.createEnvironment('Local Protocol');
  environmentStore.updateActiveAuthentication(
    const RequestAuthentication.bearer('{{token}}'),
  );
  environmentStore.updateVariable(
    id: 'authentication-${authenticated.id}-token',
    value: _configuredProtocolToken,
  );
  final open = environmentStore.createEnvironment('Local Protocol Open');
  final snapshot = environmentStore.toJson();
  for (final profile in snapshot['profiles'] as List) {
    final map = profile as Map;
    if (map['id'] == authenticated.id) map['id'] = 'local-protocol';
    if (map['id'] == open.id) map['id'] = 'local-protocol-open';
  }
  final variables = snapshot['variablesByEnvironment'] as Map;
  variables['local-protocol'] = variables.remove(authenticated.id);
  variables['local-protocol-open'] = variables.remove(open.id);
  snapshot['activeEnvironmentId'] = 'staging';
  final configuredEnvironmentStore = InMemoryEnvironmentStore.fromJson(
    Map<String, dynamic>.from(snapshot),
  );
  return WorkspaceViewModel(
    assetRepository: InMemoryApiAssetRepository.demo(),
    environmentStore: configuredEnvironmentStore,
    environmentResolver: EnvironmentExecutionResolver(
      configuredEnvironmentStore,
    ),
    executionService: HttpExecutionService(
      runtime: HttpRequestExecutionRuntime(),
    ),
    openApiImporter: const OpenApiRequestImporter(),
    openApiExporter: const OpenApiRequestExporter(),
    openApiFileExporter: const OpenApiFileExporter(),
    openApiFileReader: const LocalOpenApiFileReader(),
    openApiOutputDirectory: const LocalOpenApiOutputDirectory(),
    openApiMarkdownRenderer: const OpenApiMarkdownDocumentationRenderer(),
    markdownDocumentationFile: const MarkdownDocumentationFileExporter(),
    protobufSource: const LocalProtobufSourcePort(),
    responseBodyDownload: const LocalResponseBodyDownload(),
    preferenceStore: InMemoryWorkspacePreferenceStore(),
    webSocketExecutionService: WebSocketExecutionService(
      const DesktopWebSocketTransport(),
    ),
    grpcExecutionService: GrpcExecutionService(const DesktopGrpcTransport()),
    contractPublishingService: FakeContractPublishingService(),
    userNoticeRepository: InMemoryUserNoticeRepository(),
    demoCollection: DemoExampleCatalog.protocolTestCollection,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final skipReason = _enabled
      ? false
      : 'Set SENDREQ_GO_INTEROP=1 to run local Go protocol interop tests.';

  test(
    'Workspace sends public, Basic, Bearer, and API Key REST requests to go-rest',
    () async {
      await _requireGo();
      final service = await _GoService.start('go-rest');
      addTearDown(service.stop);
      await service.waitForPort();

      await HttpOverrides.runZoned(() async {
        final viewModel = _workspaceViewModel();
        addTearDown(viewModel.dispose);

        final endpoint = 'http://127.0.0.1:${service.port}';
        viewModel.selectRequest('demo-rest-list-users');
        viewModel.updateActiveDraftUrl('$endpoint/api/v1/users');
        final resolved =
            await EnvironmentExecutionResolver(
              InMemoryEnvironmentStore.sample(),
            ).resolve(
              ResolveExecutionRequest(
                executionId: 'rest-probe',
                requestRef: const RequestRef(id: 'demo-rest-list-users'),
                draft: viewModel.activeDraft,
              ),
            );
        expect(resolved.payload.resolvedUrl, '$endpoint/api/v1/users');
        final runtimeResponse = await HttpRequestExecutionRuntime().send(
          draft: resolved.payload.draft,
          resolvedUrl: resolved.payload.resolvedUrl,
        );
        expect(runtimeResponse.statusCode, 200);
        final direct = await HttpExecutionService(
          runtime: HttpRequestExecutionRuntime(),
        ).execute(resolved);
        expect(
          direct.responseSnapshot?.statusCode,
          200,
          reason: direct.summary,
        );

        for (final request in <({String id, String path, int status})>[
          (id: 'demo-rest-list-users', path: '/api/v1/users', status: 200),
          (
            id: 'demo-rest-create-user',
            path: '/api/v1/basic/users',
            status: 201,
          ),
          (
            id: 'demo-rest-replace-user',
            path: '/api/v1/bearer/users/1',
            status: 200,
          ),
          (
            id: 'demo-rest-patch-user',
            path: '/api/v1/basic/users/1',
            status: 200,
          ),
          (
            id: 'demo-rest-api-key-users',
            path: '/api/v1/api-key/users',
            status: 200,
          ),
          (
            id: 'demo-rest-delete-user',
            path: '/api/v1/bearer/users/1',
            status: 204,
          ),
        ]) {
          viewModel.selectRequest(request.id);
          viewModel.updateActiveDraftUrl('$endpoint${request.path}');
          await viewModel.sendActiveRequest();
          expect(
            viewModel.response?.statusCode,
            request.status,
            reason: viewModel.executionError,
          );
        }

        const rejectedToken = 'invalid-rest-token';
        final rejectedCommand =
            await EnvironmentExecutionResolver(
              InMemoryEnvironmentStore.sample(),
            ).resolve(
              ResolveExecutionRequest(
                executionId: 'rest-auth-rejected',
                requestRef: const RequestRef(id: 'demo-rest-replace-user'),
                draft: RequestDraft(
                  method: 'GET',
                  baseUrlToken: endpoint,
                  path: '/api/v1/bearer/users/1',
                  params: const [],
                  headers: const [],
                  body: '',
                  authentication: const RequestAuthentication.bearer(
                    rejectedToken,
                  ),
                  authenticationSource: RequestAuthenticationSource.request,
                ),
              ),
            );
        final rejected = await HttpExecutionService(
          runtime: HttpRequestExecutionRuntime(),
        ).execute(rejectedCommand);
        expect(rejected.status, OperationOutcomeKind.success);
        expect(rejected.responseSnapshot?.statusCode, 401);
        expect(
          rejected.requestSnapshot!.headers.single.value,
          isNot(contains(rejectedToken)),
        );
        expect(
          rejected.responseSnapshot!.bodyPreview,
          isNot(contains(rejectedToken)),
        );
      }, createHttpClient: _RealHttpOverrides().createHttpClient);
    },
    skip: skipReason,
  );

  test('REST loopback network failures are safe and retryable', () async {
    final unavailablePort = await _freeLoopbackPort();
    await HttpOverrides.runZoned(() async {
      const secret = 'unreachable-secret';
      final result =
          await HttpExecutionService(
            runtime: HttpRequestExecutionRuntime(),
          ).execute(
            ResolvedExecutionCommand(
              executionId: 'rest-network-failure',
              requestRef: const RequestRef(id: 'demo-rest-list-users'),
              payload: ExecutionPayload(
                method: 'GET',
                resolvedUrl: 'http://127.0.0.1:$unavailablePort/api/v1/$secret',
                draft: const RequestDraft(
                  method: 'GET',
                  baseUrlToken: '',
                  path: '',
                  params: [],
                  headers: [],
                  body: '',
                ),
              ),
              sanitizedRequestSummary:
                  'GET http://127.0.0.1:[redacted]/api/v1/[redacted]',
              redactionPolicy: RedactionPolicy([secret]),
            ),
          );

      expect(result.status, OperationOutcomeKind.failed);
      expect(result.errorCategory, RuntimeErrorCategory.network.name);
      expect(result.responseSnapshot, isNull);
      expect(result.summary, isNot(contains(secret)));
      expect(result.requestSnapshot!.resolvedUrl, isNot(contains(secret)));
    }, createHttpClient: _RealHttpOverrides().createHttpClient);
  });

  test(
    'go-ws echoes text and binary Protobuf WebSocket frames unchanged',
    () async {
      await _requireGo();
      final service = await _GoService.start('go-ws');
      addTearDown(service.stop);
      await service.waitForPort();

      final descriptors = await _orderDescriptors();
      final codec = ProtobufDynamicCodec(descriptors);
      final request = codec.encodeJson(
        '.order.v1.CreateOrderRequest',
        '{"user_id":"interop-user","product":"sendreq","quantity":2}',
      );
      final connection = await const DesktopWebSocketTransport().connect(
        WebSocketConnectionConfiguration(
          url: Uri.parse('ws://127.0.0.1:${service.port}/ws'),
          headers: const {'Authorization': 'Bearer $_testToken'},
          redactedValues: const [_testToken],
        ),
      );
      addTearDown(connection.close);

      await connection.sendText('sendreq text interop');
      final textEvent = await connection.events.firstWhere(
        (event) => event.kind == WebSocketFrameKind.text,
      );
      expect(textEvent.text, 'sendreq text interop');

      await connection.sendBinary(request);
      final binaryEvent = await connection.events.firstWhere(
        (event) => event.kind == WebSocketFrameKind.binary,
      );
      expect(binaryEvent.binary, request);
      expect(
        jsonDecode(
          codec.decodeJson('.order.v1.CreateOrderRequest', binaryEvent.binary!),
        ),
        {'user_id': 'interop-user', 'product': 'sendreq', 'quantity': 2},
      );
    },
    skip: skipReason,
  );

  test(
    'go-ws rejects missing tokens before upgrading the connection',
    () async {
      await _requireGo();
      final service = await _GoService.start('go-ws');
      addTearDown(service.stop);
      await service.waitForPort();

      await expectLater(
        const DesktopWebSocketTransport().connect(
          WebSocketConnectionConfiguration(
            url: Uri.parse('ws://127.0.0.1:${service.port}/ws'),
          ),
        ),
        throwsA(isA<Object>()),
      );
    },
    skip: skipReason,
  );

  test(
    'go-ws public route accepts connections without an Authorization header',
    () async {
      await _requireGo();
      final service = await _GoService.start('go-ws');
      addTearDown(service.stop);
      await service.waitForPort();

      final connection = await const DesktopWebSocketTransport().connect(
        WebSocketConnectionConfiguration(
          url: Uri.parse('ws://127.0.0.1:${service.port}/ws/open'),
        ),
      );
      addTearDown(connection.close);
      await connection.sendText('public route echo');
      expect(
        (await connection.events.firstWhere(
          (event) => event.kind == WebSocketFrameKind.text,
        )).text,
        'public route echo',
      );
    },
    skip: skipReason,
  );

  test('go-ws accepts the API Key protected handshake', () async {
    await _requireGo();
    final service = await _GoService.start('go-ws');
    addTearDown(service.stop);
    await service.waitForPort();

    final connection = await const DesktopWebSocketTransport().connect(
      WebSocketConnectionConfiguration(
        url: Uri.parse('ws://127.0.0.1:${service.port}/ws/api-key'),
        headers: const {'X-API-Key': 'sendreq-local-api-key'},
        redactedValues: const ['sendreq-local-api-key'],
      ),
    );
    addTearDown(connection.close);
    await connection.sendText('api key service echo');
    expect(
      (await connection.events.firstWhere(
        (event) => event.kind == WebSocketFrameKind.text,
      )).text,
      'api key service echo',
    );
  }, skip: skipReason);

  test(
    'go-ws rejects invalid credentials for every protected route',
    () async {
      await _requireGo();
      final service = await _GoService.start('go-ws');
      addTearDown(service.stop);
      await service.waitForPort();

      for (final handshake in <({String path, Map<String, String> headers})>[
        (path: '/ws', headers: const {'Authorization': 'Bearer invalid-token'}),
        (
          path: '/ws/basic',
          headers: const {'Authorization': 'Basic aW52YWxpZDppbnZhbGlk'},
        ),
        (path: '/ws/api-key', headers: const {'X-API-Key': 'invalid-key'}),
      ]) {
        await expectLater(
          const DesktopWebSocketTransport().connect(
            WebSocketConnectionConfiguration(
              url: Uri.parse('ws://127.0.0.1:${service.port}${handshake.path}'),
              headers: handshake.headers,
              redactedValues: handshake.headers.values.toList(growable: false),
            ),
          ),
          throwsA(isA<Object>()),
        );
      }
    },
    skip: skipReason,
  );

  test('Workspace connects the Basic WebSocket demo to go-ws', () async {
    await _requireGo();
    final service = await _GoService.start('go-ws');
    addTearDown(service.stop);
    await service.waitForPort();

    final viewModel = _workspaceViewModel();
    addTearDown(viewModel.dispose);
    viewModel.selectRequest('demo-websocket-basic-echo');
    viewModel.updateActiveDraftUrl('ws://127.0.0.1:${service.port}/ws/basic');

    await viewModel.connectActiveWebSocket();
    expect(
      viewModel.activeWebSocketSession.state,
      WebSocketConnectionState.connected,
    );
    viewModel.updateActiveWebSocketMessage('workspace Basic echo');
    await viewModel.sendActiveWebSocketMessage();
    await _waitUntil(
      'Basic WebSocket echo',
      () => viewModel.activeWebSocketSession.events.any(
        (event) => event.textPayload == 'workspace Basic echo',
      ),
    );
    await viewModel.disconnectActiveWebSocket();
  }, skip: skipReason);

  test(
    'go-grpc accepts and returns dynamically encoded Protobuf messages',
    () async {
      await _requireGo();
      final service = await _GoService.start('go-grpc');
      addTearDown(service.stop);
      await service.waitForPort();

      final descriptors = await _orderDescriptors();
      final codec = ProtobufDynamicCodec(descriptors);
      final call = await const DesktopGrpcTransport().start(
        GrpcCallConfiguration(
          endpoint: Uri.parse('http://127.0.0.1:${service.port}'),
          serviceName: '.order.v1.OrderService',
          methodName: 'CreateOrder',
          requestType: '.order.v1.CreateOrderRequest',
          responseType: '.order.v1.CreateOrderResponse',
          requestBytes: codec.encodeJson(
            '.order.v1.CreateOrderRequest',
            '{"user_id":"interop-user","product":"sendreq","quantity":2,"priority":"ORDER_PRIORITY_HIGH","customer":{"customer_id":"customer-interop","contact":{"email":"interop@example.test","phone":"+86-010-00000000"},"tags":["desktop","interop"],"attributes":{"tier":"gold"}},"items":[{"sku":"sendreq-license","name":"Sendreq license","quantity":2,"unit_price":{"currency_code":"USD","units":49},"labels":["interop"]}],"attributes":{"channel":"desktop"},"shipping_address":{"line1":"1 Interop Road","city":"Beijing","region":"Beijing","postal_code":"100000","country_code":"CN"}}',
          ),
          metadata: const {'authorization': 'Bearer $_testToken'},
          useTls: false,
          redactedValues: const [_testToken],
        ),
      );
      addTearDown(call.cancel);

      final events = await call.events.toList();
      final response = events.singleWhere(
        (event) => event.kind == GrpcTransportEventKind.message,
      );
      final decoded =
          jsonDecode(
                codec.decodeJson(
                  '.order.v1.CreateOrderResponse',
                  response.message!,
                ),
              )
              as Map<String, dynamic>;
      final order = decoded['order'] as Map<String, dynamic>;

      expect(order['order_id'], startsWith('ORD-'));
      expect(order['user_id'], 'interop-user');
      expect(order['product'], 'sendreq');
      expect(order['quantity'], 2);
      expect(order['priority'], 'ORDER_PRIORITY_HIGH');
      expect(order['customer'], {
        'customer_id': 'customer-interop',
        'contact': {
          'email': 'interop@example.test',
          'phone': '+86-010-00000000',
        },
        'tags': ['desktop', 'interop'],
        'attributes': {'tier': 'gold'},
      });
      expect(order['items'], [
        {
          'sku': 'sendreq-license',
          'name': 'Sendreq license',
          'quantity': 2,
          'unit_price': {'currency_code': 'USD', 'units': 49},
          'labels': ['interop'],
        },
      ]);
      expect(order['attributes'], {'channel': 'desktop'});
      expect(order['shipping_address'], {
        'line1': '1 Interop Road',
        'city': 'Beijing',
        'region': 'Beijing',
        'postal_code': '100000',
        'country_code': 'CN',
      });
      expect(
        events.where((event) => event.kind == GrpcTransportEventKind.status),
        contains(
          predicate<GrpcTransportEvent>((event) => event.statusCode == 0),
        ),
      );
    },
    skip: skipReason,
  );

  test(
    'go-grpc open service accepts calls without authorization metadata',
    () async {
      await _requireGo();
      final service = await _GoService.start(
        'go-grpc',
        requireAuthentication: false,
      );
      addTearDown(service.stop);
      await service.waitForPort();

      final descriptors = await _orderDescriptors();
      final codec = ProtobufDynamicCodec(descriptors);
      final call = await const DesktopGrpcTransport().start(
        GrpcCallConfiguration(
          endpoint: Uri.parse('http://127.0.0.1:${service.port}'),
          serviceName: '.order.v1.OrderService',
          methodName: 'CreateOrder',
          requestType: '.order.v1.CreateOrderRequest',
          responseType: '.order.v1.CreateOrderResponse',
          requestBytes: codec.encodeJson(
            '.order.v1.CreateOrderRequest',
            '{"user_id":"open-user","product":"sendreq","quantity":1}',
          ),
          useTls: false,
        ),
      );
      addTearDown(call.cancel);
      expect(
        await call.events.toList(),
        contains(
          predicate<GrpcTransportEvent>((event) => event.statusCode == 0),
        ),
      );
    },
    skip: skipReason,
  );

  test(
    'go-grpc accepts API Key metadata after HTTP/2 name normalization',
    () async {
      await _requireGo();
      final service = await _GoService.start('go-grpc');
      addTearDown(service.stop);
      await service.waitForPort();

      final descriptors = await _orderDescriptors();
      final codec = ProtobufDynamicCodec(descriptors);
      final call = await const DesktopGrpcTransport().start(
        GrpcCallConfiguration(
          endpoint: Uri.parse('http://127.0.0.1:${service.port}'),
          serviceName: '.order.v1.OrderService',
          methodName: 'GetOrder',
          requestType: '.order.v1.GetOrderRequest',
          responseType: '.order.v1.GetOrderResponse',
          requestBytes: codec.encodeJson(
            '.order.v1.GetOrderRequest',
            '{"order_id":"ORD-INTEROP-API-KEY"}',
          ),
          metadata: const {'X-API-Key': 'sendreq-local-api-key'},
          useTls: false,
          redactedValues: const ['sendreq-local-api-key'],
        ),
      );
      addTearDown(call.cancel);
      final events = await call.events.toList();
      final response = events.singleWhere(
        (event) => event.kind == GrpcTransportEventKind.message,
      );
      final decoded =
          jsonDecode(
                codec.decodeJson(
                  '.order.v1.GetOrderResponse',
                  response.message!,
                ),
              )
              as Map<String, dynamic>;
      expect(
        (decoded['order'] as Map<String, dynamic>)['order_id'],
        'ORD-INTEROP-API-KEY',
      );
      expect(
        events.where((event) => event.kind == GrpcTransportEventKind.status),
        contains(
          predicate<GrpcTransportEvent>((event) => event.statusCode == 0),
        ),
      );
    },
    skip: skipReason,
  );

  test(
    'go-grpc rejects invalid metadata and streams authenticated order events',
    () async {
      await _requireGo();
      final service = await _GoService.start('go-grpc');
      addTearDown(service.stop);
      await service.waitForPort();

      final descriptors = await _orderDescriptors();
      final codec = ProtobufDynamicCodec(descriptors);
      final invalidCall = await const DesktopGrpcTransport().start(
        GrpcCallConfiguration(
          endpoint: Uri.parse('http://127.0.0.1:${service.port}'),
          serviceName: '.order.v1.OrderService',
          methodName: 'WatchOrders',
          requestType: '.order.v1.WatchOrdersRequest',
          responseType: '.order.v1.OrderEvent',
          requestBytes: Uint8List(0),
          metadata: const {'authorization': 'Bearer wrong-token'},
          useTls: false,
          serverStreaming: true,
          redactedValues: const ['wrong-token'],
        ),
      );
      addTearDown(invalidCall.cancel);
      expect(
        await invalidCall.events.toList(),
        contains(
          predicate<GrpcTransportEvent>(
            (event) =>
                event.statusCode == 16 ||
                event.statusMessage?.contains('UNAUTHENTICATED') == true,
          ),
        ),
      );

      final streamCall = await const DesktopGrpcTransport().start(
        GrpcCallConfiguration(
          endpoint: Uri.parse('http://127.0.0.1:${service.port}'),
          serviceName: '.order.v1.OrderService',
          methodName: 'WatchOrders',
          requestType: '.order.v1.WatchOrdersRequest',
          responseType: '.order.v1.OrderEvent',
          requestBytes: codec.encodeJson(
            '.order.v1.WatchOrdersRequest',
            '{"user_id":"interop-user","limit":3}',
          ),
          metadata: const {'authorization': 'Bearer $_testToken'},
          useTls: false,
          serverStreaming: true,
          redactedValues: const [_testToken],
        ),
      );
      addTearDown(streamCall.cancel);
      final events = await streamCall.events.toList();
      final orderEvents = events
          .where((event) => event.kind == GrpcTransportEventKind.message)
          .map(
            (event) => jsonDecode(
              codec.decodeJson('.order.v1.OrderEvent', event.message!),
            )['status'],
          )
          .toList();
      expect(orderEvents, ['created', 'processing', 'completed']);
      expect(
        events
            .where((event) => event.kind == GrpcTransportEventKind.message)
            .map(
              (event) => jsonDecode(
                codec.decodeJson('.order.v1.OrderEvent', event.message!),
              )['sequence'],
            )
            .toList(),
        [1, 2, 3],
      );
      expect(
        events.where((event) => event.kind == GrpcTransportEventKind.status),
        contains(
          predicate<GrpcTransportEvent>((event) => event.statusCode == 0),
        ),
      );
    },
    skip: skipReason,
  );

  test('go-grpc enforces the per-method authentication matrix', () async {
    await _requireGo();
    final service = await _GoService.start('go-grpc');
    addTearDown(service.stop);
    await service.waitForPort();

    final descriptors = await _orderDescriptors();
    final codec = ProtobufDynamicCodec(descriptors);
    final endpoint = Uri.parse('http://127.0.0.1:${service.port}');

    final publicCall = await const DesktopGrpcTransport().start(
      GrpcCallConfiguration(
        endpoint: endpoint,
        serviceName: '.order.v1.OrderService',
        methodName: 'CreateOrder',
        requestType: '.order.v1.CreateOrderRequest',
        responseType: '.order.v1.CreateOrderResponse',
        requestBytes: codec.encodeJson(
          '.order.v1.CreateOrderRequest',
          '{"user_id":"public-user","product":"sendreq","quantity":1}',
        ),
        useTls: false,
      ),
    );
    addTearDown(publicCall.cancel);
    expect(
      await publicCall.events.toList(),
      contains(predicate<GrpcTransportEvent>((event) => event.statusCode == 0)),
      reason: 'CreateOrder must remain public.',
    );

    final protectedMethods =
        <
          ({
            String method,
            String requestType,
            String responseType,
            Uint8List requestBytes,
            Map<String, String> wrongMetadata,
            bool clientStreaming,
            bool serverStreaming,
          })
        >[
          (
            method: 'GetOrder',
            requestType: '.order.v1.GetOrderRequest',
            responseType: '.order.v1.GetOrderResponse',
            requestBytes: codec.encodeJson(
              '.order.v1.GetOrderRequest',
              '{"order_id":"ORD-AUTH-PROBE"}',
            ),
            wrongMetadata: const {'x-api-key': 'wrong-api-key'},
            clientStreaming: false,
            serverStreaming: false,
          ),
          (
            method: 'SubmitOrders',
            requestType: '.order.v1.CreateOrderRequest',
            responseType: '.order.v1.SubmitOrdersResponse',
            requestBytes: Uint8List(0),
            wrongMetadata: const {'authorization': 'Basic d3Jvbmc6d3Jvbmc='},
            clientStreaming: true,
            serverStreaming: false,
          ),
          (
            method: 'Chat',
            requestType: '.order.v1.OrderChatMessage',
            responseType: '.order.v1.OrderChatMessage',
            requestBytes: Uint8List(0),
            wrongMetadata: const {'authorization': 'Bearer wrong-token'},
            clientStreaming: true,
            serverStreaming: true,
          ),
          (
            method: 'WatchOrders',
            requestType: '.order.v1.WatchOrdersRequest',
            responseType: '.order.v1.OrderEvent',
            requestBytes: codec.encodeJson(
              '.order.v1.WatchOrdersRequest',
              '{"user_id":"auth-probe","limit":1}',
            ),
            wrongMetadata: const {'authorization': 'Bearer wrong-token'},
            clientStreaming: false,
            serverStreaming: true,
          ),
        ];

    for (final method in protectedMethods) {
      for (final metadata in <Map<String, String>>[
        const {},
        method.wrongMetadata,
      ]) {
        final call = await const DesktopGrpcTransport().start(
          GrpcCallConfiguration(
            endpoint: endpoint,
            serviceName: '.order.v1.OrderService',
            methodName: method.method,
            requestType: method.requestType,
            responseType: method.responseType,
            requestBytes: method.requestBytes,
            metadata: metadata,
            useTls: false,
            clientStreaming: method.clientStreaming,
            serverStreaming: method.serverStreaming,
            redactedValues: metadata.values.toList(growable: false),
          ),
        );
        addTearDown(call.cancel);
        if (method.clientStreaming) await call.closeRequestStream();
        final events = await call.events.toList();
        expect(
          events,
          contains(predicate<GrpcTransportEvent>(_isUnauthenticatedEvent)),
          reason:
              '${method.method} must reject ${metadata.isEmpty ? 'missing' : 'wrong'} credentials with status 16. Events: $events',
        );
      }
    }
  }, skip: skipReason);

  test(
    'go-grpc bidirectional Chat receives each client message and replies',
    () async {
      await _requireGo();
      final service = await _GoService.start('go-grpc');
      addTearDown(service.stop);
      await service.waitForPort();

      final descriptors = await _orderDescriptors();
      final codec = ProtobufDynamicCodec(descriptors);
      final call = await const DesktopGrpcTransport().start(
        GrpcCallConfiguration(
          endpoint: Uri.parse('http://127.0.0.1:${service.port}'),
          serviceName: '.order.v1.OrderService',
          methodName: 'Chat',
          requestType: '.order.v1.OrderChatMessage',
          responseType: '.order.v1.OrderChatMessage',
          requestBytes: Uint8List(0),
          metadata: const {'authorization': 'Bearer $_testToken'},
          useTls: false,
          clientStreaming: true,
          serverStreaming: true,
          redactedValues: const [_testToken],
        ),
      );
      addTearDown(call.cancel);

      await call.send(
        codec.encodeJson(
          '.order.v1.OrderChatMessage',
          '{"sender":"sendreq","text":"first","sequence":1}',
        ),
      );
      await call.send(
        codec.encodeJson(
          '.order.v1.OrderChatMessage',
          '{"sender":"sendreq","text":"second","sequence":2}',
        ),
      );
      await call.closeRequestStream();
      final events = await call.events.toList();
      final replies = events
          .where((event) => event.kind == GrpcTransportEventKind.message)
          .map(
            (event) => jsonDecode(
              codec.decodeJson('.order.v1.OrderChatMessage', event.message!),
            ),
          )
          .toList();

      expect(replies, [
        {'sender': 'order-service', 'text': 'ack: first', 'sequence': 1},
        {'sender': 'order-service', 'text': 'ack: second', 'sequence': 2},
      ]);
      expect(
        events.where((event) => event.kind == GrpcTransportEventKind.status),
        contains(
          predicate<GrpcTransportEvent>((event) => event.statusCode == 0),
        ),
      );
    },
    skip: skipReason,
  );

  test(
    'Workspace submits the Basic client-streaming demo to go-grpc',
    () async {
      await _requireGo();
      final service = await _GoService.start('go-grpc');
      addTearDown(service.stop);
      await service.waitForPort();

      final viewModel = _workspaceViewModel();
      addTearDown(viewModel.dispose);
      viewModel.selectRequest('demo-grpc-submit-orders');
      await _waitUntil(
        'SubmitOrders schema',
        () => viewModel.activeGrpcMethod != null,
      );
      viewModel.updateActiveDraftUrl('http://127.0.0.1:${service.port}');
      await viewModel.sendActiveGrpcRequest();

      viewModel.updateActiveDraftBody(
        '{"user_id":"stream-user","product":"first","quantity":2}',
      );
      await viewModel.sendActiveGrpcMessage();
      viewModel.updateActiveDraftBody(
        '{"user_id":"stream-user","product":"second","quantity":3}',
      );
      await viewModel.sendActiveGrpcMessage();
      await viewModel.closeActiveGrpcRequestStream();
      await _waitUntil(
        'SubmitOrders completion',
        () => viewModel.activeGrpcCall.state == GrpcCallState.completed,
      );

      final response = viewModel.activeGrpcCall.events.singleWhere(
        (event) => event.kind == GrpcTransportEventKind.message,
      );
      final decoded = viewModel.decodeActiveGrpcEvent(response);
      expect(decoded?.isSuccess, isTrue);
      expect(jsonDecode(decoded!.formattedJson!), {
        'accepted_count': 2,
        'total_quantity': 5,
      });
    },
    skip: skipReason,
  );

  test(
    'Workspace applies Local Protocol authentication through live WS and gRPC sessions',
    () async {
      await _requireGo();
      final webSocketService = await _GoService.start(
        'go-ws',
        protocolToken: _configuredProtocolToken,
      );
      final grpcService = await _GoService.start(
        'go-grpc',
        protocolToken: _configuredProtocolToken,
      );
      addTearDown(webSocketService.stop);
      addTearDown(grpcService.stop);
      await webSocketService.waitForPort();
      await grpcService.waitForPort();

      final viewModel = _workspaceViewModel();
      addTearDown(viewModel.dispose);
      viewModel.selectEnvironment('local-protocol');
      final tokenVariable = viewModel.variables.singleWhere(
        (variable) => variable.key == 'token',
      );
      viewModel.updateEnvironmentVariable(
        id: tokenVariable.id,
        value: _configuredProtocolToken,
      );

      viewModel.selectRequest('demo-websocket-echo');
      viewModel.updateActiveDraftUrl(
        'ws://127.0.0.1:${webSocketService.port}/ws',
      );
      await viewModel.connectActiveWebSocket();
      expect(
        viewModel.activeWebSocketSession.state,
        WebSocketConnectionState.connected,
      );
      expect(
        viewModel.activeWebSocketSession.sessionContext.environmentName,
        'Local Protocol',
      );

      viewModel.updateActiveWebSocketMessage('workspace echo');
      await viewModel.sendActiveWebSocketMessage();
      await _waitUntil(
        'WebSocket echo',
        () => viewModel.activeWebSocketSession.events.any(
          (event) =>
              event.direction == WebSocketFrameDirection.inbound &&
              event.textPayload == 'workspace echo',
        ),
      );
      await _triggerWebSocketPush(webSocketService.port, 'workspace-push');
      await _waitUntil(
        'WebSocket push',
        () => viewModel.activeWebSocketSession.events.any(
          (event) => event.textPayload == 'server: workspace-push',
        ),
      );
      await _triggerWebSocketBurst(webSocketService.port, 3);
      await _waitUntil(
        'ordered WebSocket burst',
        () =>
            viewModel.activeWebSocketSession.events
                .where(
                  (event) =>
                      event.textPayload?.startsWith('server: burst-') ?? false,
                )
                .length ==
            3,
      );
      expect(
        viewModel.activeWebSocketSession.events
            .where(
              (event) =>
                  event.textPayload?.startsWith('server: burst-') ?? false,
            )
            .map((event) => event.textPayload),
        ['server: burst-1', 'server: burst-2', 'server: burst-3'],
      );
      await _triggerWebSocketClose(
        webSocketService.port,
        reason: 'server requested close',
      );
      await _waitUntil(
        'remote WebSocket close',
        () =>
            viewModel.activeWebSocketSession.state ==
            WebSocketConnectionState.disconnected,
      );
      expect(viewModel.activeWebSocketSession.canSend, isFalse);
      expect(
        viewModel.activeWebSocketSession.events.last.preview,
        contains('server requested close'),
      );

      viewModel.selectRequest('demo-websocket-api-key-echo');
      viewModel.updateActiveDraftUrl(
        'ws://127.0.0.1:${webSocketService.port}/ws/api-key',
      );
      await viewModel.connectActiveWebSocket();
      expect(
        viewModel.activeWebSocketSession.state,
        WebSocketConnectionState.connected,
      );
      await viewModel.disconnectActiveWebSocket();

      viewModel.selectRequest('demo-grpc-create-order');
      await _waitUntil(
        'CreateOrder schema',
        () => viewModel.activeGrpcMethod != null,
      );
      viewModel.updateActiveDraftUrl('http://127.0.0.1:${grpcService.port}');
      await viewModel.sendActiveGrpcRequest();
      await _waitUntil(
        'CreateOrder completion',
        () => viewModel.activeGrpcCall.state == GrpcCallState.completed,
      );
      expect(
        viewModel.activeGrpcCall.sessionContext.environmentName,
        'Local Protocol',
      );
      expect(
        viewModel.activeGrpcCall.events.any(
          (event) => event.kind == GrpcTransportEventKind.message,
        ),
        isTrue,
      );

      viewModel.selectRequest('demo-grpc-get-order');
      await _waitUntil(
        'GetOrder schema',
        () => viewModel.activeGrpcMethod != null,
      );
      viewModel.updateActiveDraftUrl('http://127.0.0.1:${grpcService.port}');
      await viewModel.sendActiveGrpcRequest();
      await _waitUntil(
        'GetOrder completion',
        () => viewModel.activeGrpcCall.state == GrpcCallState.completed,
      );
      expect(
        viewModel.activeGrpcCall.events.any(
          (event) =>
              event.kind == GrpcTransportEventKind.status &&
              event.statusCode == 0,
        ),
        isTrue,
      );

      viewModel.selectRequest('demo-grpc-watch-orders');
      await _waitUntil(
        'WatchOrders schema',
        () => viewModel.activeGrpcMethod != null,
      );
      viewModel.updateActiveDraftUrl('http://127.0.0.1:${grpcService.port}');
      await viewModel.sendActiveGrpcRequest();
      await _waitUntil(
        'WatchOrders completion',
        () => viewModel.activeGrpcCall.state == GrpcCallState.completed,
      );
      expect(
        viewModel.activeGrpcCall.events.where(
          (event) => event.kind == GrpcTransportEventKind.message,
        ),
        hasLength(3),
      );

      viewModel.selectRequest('demo-grpc-order-chat');
      await _waitUntil('Chat schema', () => viewModel.activeGrpcMethod != null);
      viewModel.updateActiveDraftUrl('http://127.0.0.1:${grpcService.port}');
      await viewModel.sendActiveGrpcRequest();
      viewModel.updateActiveDraftBody(
        '{"sender":"sendreq","text":"workspace chat","sequence":1}',
      );
      await viewModel.sendActiveGrpcMessage();
      await viewModel.closeActiveGrpcRequestStream();
      await _waitUntil(
        'Chat completion',
        () => viewModel.activeGrpcCall.state == GrpcCallState.completed,
      );
      expect(
        viewModel.activeGrpcCall.events.any(
          (event) => event.kind == GrpcTransportEventKind.message,
        ),
        isTrue,
      );
    },
    skip: skipReason,
  );

  test(
    'desktop client accepts every running go-ws route and control behavior',
    () async {
      const transport = DesktopWebSocketTransport();
      final endpoint = 'ws://127.0.0.1:8080';
      final routes = <({String path, Map<String, String> headers})>[
        (path: '/ws', headers: const {'Authorization': 'Bearer $_testToken'}),
        (
          path: '/ws/basic',
          headers: const {
            'Authorization': 'Basic c2VuZHJlcTpiYXNpYy1kZW1vLXBhc3N3b3Jk',
          },
        ),
        (
          path: '/ws/api-key',
          headers: const {'X-API-Key': 'sendreq-local-api-key'},
        ),
        (path: '/ws/open', headers: const {}),
      ];

      for (final route in routes) {
        final connection = await transport.connect(
          WebSocketConnectionConfiguration(
            url: Uri.parse('$endpoint${route.path}'),
            headers: route.headers,
            redactedValues: route.headers.values.toList(growable: false),
          ),
        );
        addTearDown(connection.close);
        final echoed = connection.events.firstWhere(
          (event) => event.kind == WebSocketFrameKind.text,
        );
        await connection.sendText('live route ${route.path}');
        expect((await echoed).text, 'live route ${route.path}');
        await connection.close();
      }

      final connection = await transport.connect(
        WebSocketConnectionConfiguration(
          url: Uri.parse('$endpoint/ws'),
          headers: const {'Authorization': 'Bearer $_testToken'},
          redactedValues: const [_testToken],
        ),
      );
      addTearDown(connection.close);
      final events = connection.events.asBroadcastStream();
      final pushed = events.firstWhere(
        (event) => event.text == 'server: live-service-push',
      );
      await _triggerWebSocketPush(8080, 'live-service-push');
      expect((await pushed).text, 'server: live-service-push');
      final burst = events
          .where((event) => event.text?.startsWith('server: burst-') ?? false)
          .take(3)
          .toList();
      await _triggerWebSocketBurst(8080, 3);
      expect((await burst).map((event) => event.text), [
        'server: burst-1',
        'server: burst-2',
        'server: burst-3',
      ]);
      final close = events.firstWhere(
        (event) => event.kind == WebSocketFrameKind.close,
      );
      await _triggerWebSocketClose(8080, reason: 'live service close');
      expect((await close).message, contains('live service close'));
    },
    skip: _liveFixturesEnabled
        ? false
        : 'Set SENDREQ_LIVE_PROTOCOL_SERVICES=1 to test the running local services.',
  );

  test(
    'desktop client sends a public unary CreateOrder request to the service',
    () async {
      final viewModel = _workspaceViewModel();
      addTearDown(viewModel.dispose);

      viewModel.selectEnvironment('local-protocol');
      viewModel.selectRequest('demo-grpc-create-order');
      await _waitUntil(
        'CreateOrder schema',
        () => viewModel.activeGrpcMethod != null,
      );
      viewModel.updateActiveDraftUrl('http://127.0.0.1:50051');

      await viewModel.sendActiveGrpcRequest();
      await _waitUntil(
        'CreateOrder completion',
        () => viewModel.activeGrpcCall.state == GrpcCallState.completed,
      );

      expect(
        viewModel.activeGrpcCall.sessionContext.environmentName,
        'Local Protocol',
      );
      expect(
        viewModel.activeGrpcCall.sessionContext.authenticationLabel,
        'No authentication',
      );
      expect(
        viewModel.activeGrpcCall.events.any(
          (event) => event.kind == GrpcTransportEventKind.message,
        ),
        isTrue,
      );
      expect(
        viewModel.activeGrpcCall.events.any(
          (event) =>
              event.kind == GrpcTransportEventKind.status &&
              event.statusCode == 0,
        ),
        isTrue,
      );
    },
    skip: _liveFixturesEnabled
        ? false
        : 'Set SENDREQ_LIVE_PROTOCOL_SERVICES=1 to test the running local services.',
  );

  test(
    'desktop client streams orders to the authenticated service before half-closing',
    () async {
      final viewModel = _workspaceViewModel();
      addTearDown(viewModel.dispose);

      viewModel.selectEnvironment('local-protocol');
      viewModel.selectRequest('demo-grpc-submit-orders');
      await _waitUntil(
        'SubmitOrders schema',
        () => viewModel.activeGrpcMethod != null,
      );
      viewModel.updateActiveDraftUrl('http://127.0.0.1:50051');
      await viewModel.sendActiveGrpcRequest();

      viewModel.updateActiveDraftBody(
        '{"user_id":"stream-user","product":"first","quantity":2}',
      );
      await viewModel.sendActiveGrpcMessage();
      viewModel.updateActiveDraftBody(
        '{"user_id":"stream-user","product":"second","quantity":3}',
      );
      await viewModel.sendActiveGrpcMessage();
      await viewModel.closeActiveGrpcRequestStream();
      await _waitUntil(
        'SubmitOrders completion',
        () => viewModel.activeGrpcCall.state == GrpcCallState.completed,
      );

      final response = viewModel.activeGrpcCall.events.singleWhere(
        (event) => event.kind == GrpcTransportEventKind.message,
      );
      final decoded = viewModel.decodeActiveGrpcEvent(response);
      expect(decoded?.isSuccess, isTrue);
      expect(jsonDecode(decoded!.formattedJson!), {
        'accepted_count': 2,
        'total_quantity': 5,
      });
      expect(
        viewModel.activeGrpcCall.events.any(
          (event) =>
              event.kind == GrpcTransportEventKind.status &&
              event.statusCode == 0,
        ),
        isTrue,
      );
    },
    skip: _liveFixturesEnabled
        ? false
        : 'Set SENDREQ_LIVE_PROTOCOL_SERVICES=1 to test the running local services.',
  );

  test(
    'desktop client applies API Key and Local Protocol Bearer to the local gRPC service',
    () async {
      final viewModel = _workspaceViewModel();
      addTearDown(viewModel.dispose);
      viewModel.selectEnvironment('local-protocol');

      viewModel.selectRequest('demo-grpc-get-order');
      await _waitUntil(
        'GetOrder schema',
        () => viewModel.activeGrpcMethod != null,
      );
      viewModel.updateActiveDraftUrl('http://127.0.0.1:50051');
      await viewModel.sendActiveGrpcRequest();
      await _waitUntil(
        'GetOrder completion',
        () => viewModel.activeGrpcCall.state == GrpcCallState.completed,
      );
      expect(
        viewModel.activeGrpcCall.sessionContext.authenticationLabel,
        'Request API key',
      );
      expect(
        viewModel.activeGrpcCall.events,
        contains(predicate<GrpcCallEvent>((event) => event.statusCode == 0)),
      );

      viewModel.selectRequest('demo-grpc-watch-orders');
      await _waitUntil(
        'WatchOrders schema',
        () => viewModel.activeGrpcMethod != null,
      );
      viewModel.updateActiveDraftUrl('http://127.0.0.1:50051');
      await viewModel.sendActiveGrpcRequest();
      await _waitUntil(
        'WatchOrders completion',
        () => viewModel.activeGrpcCall.state == GrpcCallState.completed,
      );
      expect(
        viewModel.activeGrpcCall.sessionContext.environmentName,
        'Local Protocol',
      );
      expect(
        viewModel.activeGrpcCall.sessionContext.authenticationLabel,
        'Environment Bearer token',
      );
      expect(
        viewModel.activeGrpcCall.events.where(
          (event) => event.kind == GrpcTransportEventKind.message,
        ),
        hasLength(3),
      );

      viewModel.selectRequest('demo-grpc-order-chat');
      await _waitUntil('Chat schema', () => viewModel.activeGrpcMethod != null);
      viewModel.updateActiveDraftUrl('http://127.0.0.1:50051');
      await viewModel.sendActiveGrpcRequest();
      viewModel.updateActiveDraftBody(
        '{"sender":"sendreq","text":"local service chat","sequence":1}',
      );
      await viewModel.sendActiveGrpcMessage();
      await viewModel.closeActiveGrpcRequestStream();
      await _waitUntil(
        'Chat completion',
        () => viewModel.activeGrpcCall.state == GrpcCallState.completed,
      );
      expect(
        viewModel.activeGrpcCall.sessionContext.environmentName,
        'Local Protocol',
      );
      expect(
        viewModel.activeGrpcCall.sessionContext.authenticationLabel,
        'Environment Bearer token',
      );
      expect(
        viewModel.activeGrpcCall.events,
        contains(
          predicate<GrpcCallEvent>(
            (event) => event.kind == GrpcTransportEventKind.message,
          ),
        ),
      );
    },
    skip: _liveFixturesEnabled
        ? false
        : 'Set SENDREQ_LIVE_PROTOCOL_SERVICES=1 to test the running local services.',
  );

  test(
    'desktop client identifies the wrong Bearer environment before a successful retry',
    () async {
      final viewModel = _workspaceViewModel();
      addTearDown(viewModel.dispose);

      viewModel.selectEnvironment('production');
      viewModel.selectRequest('demo-grpc-watch-orders');
      await _waitUntil(
        'WatchOrders schema',
        () => viewModel.activeGrpcMethod != null,
      );
      viewModel.updateActiveDraftUrl('http://127.0.0.1:50051');
      await viewModel.sendActiveGrpcRequest();
      await _waitUntil(
        'Production Bearer rejection',
        () => viewModel.activeGrpcCall.state == GrpcCallState.error,
      );
      expect(
        viewModel.activeGrpcCall.errorMessage,
        'Bearer authentication failed. This call uses the Environment Bearer token from Production. Switch to the intended environment or update its Bearer token, then restart the call.',
      );
      expect(
        viewModel.activeGrpcCall.sessionContext.environmentName,
        'Production',
      );

      viewModel.selectEnvironment('local-protocol');
      await viewModel.sendActiveGrpcRequest();
      await _waitUntil(
        'Local Protocol Bearer retry',
        () => viewModel.activeGrpcCall.state == GrpcCallState.completed,
      );
      expect(
        viewModel.activeGrpcCall.sessionContext.environmentName,
        'Local Protocol',
      );
      expect(
        viewModel.activeGrpcCall.events.where(
          (event) => event.kind == GrpcTransportEventKind.message,
        ),
        hasLength(3),
      );
    },
    skip: _liveFixturesEnabled
        ? false
        : 'Set SENDREQ_LIVE_PROTOCOL_SERVICES=1 to test the running local services.',
  );

  test(
    'desktop client uses the authenticated and open local protocol services',
    () async {
      final viewModel = _workspaceViewModel();
      addTearDown(viewModel.dispose);

      viewModel.selectEnvironment('local-protocol');
      viewModel.selectRequest('demo-websocket-echo');
      viewModel.updateActiveDraftUrl('ws://127.0.0.1:8080/ws');
      await viewModel.connectActiveWebSocket();
      expect(
        viewModel.activeWebSocketSession.state,
        WebSocketConnectionState.connected,
      );
      expect(
        viewModel.activeWebSocketSession.sessionContext.environmentName,
        'Local Protocol',
      );
      expect(
        viewModel.activeWebSocketSession.sessionContext.authenticationLabel,
        'Environment Bearer token',
      );
      viewModel.updateActiveWebSocketMessage('authenticated client probe');
      await viewModel.sendActiveWebSocketMessage();
      await _waitUntil(
        'authenticated WebSocket echo',
        () => viewModel.activeWebSocketSession.events.any(
          (event) => event.textPayload == 'authenticated client probe',
        ),
      );
      await viewModel.disconnectActiveWebSocket();

      viewModel.selectRequest('demo-grpc-create-order');
      await _waitUntil(
        'authenticated CreateOrder schema',
        () => viewModel.activeGrpcMethod != null,
      );
      viewModel.updateActiveDraftUrl('http://127.0.0.1:50051');
      await viewModel.sendActiveGrpcRequest();
      await _waitUntil(
        'authenticated CreateOrder completion',
        () => viewModel.activeGrpcCall.state == GrpcCallState.completed,
      );
      expect(
        viewModel.activeGrpcCall.events.any(
          (event) =>
              event.kind == GrpcTransportEventKind.status &&
              event.statusCode == 0,
        ),
        isTrue,
      );

      viewModel.selectRequest('demo-grpc-get-order');
      await _waitUntil(
        'GetOrder schema',
        () => viewModel.activeGrpcMethod != null,
      );
      viewModel.updateActiveDraftUrl('http://127.0.0.1:50051');
      await viewModel.sendActiveGrpcRequest();
      await _waitUntil(
        'authenticated GetOrder completion',
        () => viewModel.activeGrpcCall.state == GrpcCallState.completed,
      );
      expect(
        viewModel.activeGrpcCall.events.any(
          (event) =>
              event.kind == GrpcTransportEventKind.status &&
              event.statusCode == 0,
        ),
        isTrue,
      );

      viewModel.selectRequest('demo-grpc-watch-orders');
      await _waitUntil(
        'WatchOrders schema',
        () => viewModel.activeGrpcMethod != null,
      );
      viewModel.updateActiveDraftUrl('http://127.0.0.1:50051');
      await viewModel.sendActiveGrpcRequest();
      await _waitUntil(
        'authenticated WatchOrders completion',
        () => viewModel.activeGrpcCall.state == GrpcCallState.completed,
      );
      expect(
        viewModel.activeGrpcCall.events.where(
          (event) => event.kind == GrpcTransportEventKind.message,
        ),
        hasLength(3),
      );

      viewModel.selectRequest('demo-grpc-order-chat');
      await _waitUntil('Chat schema', () => viewModel.activeGrpcMethod != null);
      viewModel.updateActiveDraftUrl('http://127.0.0.1:50051');
      await viewModel.sendActiveGrpcRequest();
      viewModel.updateActiveDraftBody(
        '{"sender":"sendreq","text":"live chat","sequence":1}',
      );
      await viewModel.sendActiveGrpcMessage();
      await viewModel.closeActiveGrpcRequestStream();
      await _waitUntil(
        'authenticated Chat completion',
        () => viewModel.activeGrpcCall.state == GrpcCallState.completed,
      );
      expect(
        viewModel.activeGrpcCall.events.any(
          (event) => event.kind == GrpcTransportEventKind.message,
        ),
        isTrue,
      );

      viewModel.selectEnvironment('local-protocol-open');
      viewModel.selectRequest('demo-websocket-echo');
      viewModel.updateActiveDraftUrl('ws://127.0.0.1:8082/ws');
      await viewModel.connectActiveWebSocket();
      expect(
        viewModel.activeWebSocketSession.state,
        WebSocketConnectionState.connected,
      );
      expect(
        viewModel.activeWebSocketSession.sessionContext.environmentName,
        'Local Protocol Open',
      );
      expect(
        viewModel.activeWebSocketSession.sessionContext.authenticationLabel,
        'No authentication',
      );
      viewModel.updateActiveWebSocketMessage('open client probe');
      await viewModel.sendActiveWebSocketMessage();
      await _waitUntil(
        'open WebSocket echo',
        () => viewModel.activeWebSocketSession.events.any(
          (event) => event.textPayload == 'open client probe',
        ),
      );
      await viewModel.disconnectActiveWebSocket();

      viewModel.selectRequest('demo-grpc-create-order');
      await _waitUntil(
        'open CreateOrder schema',
        () => viewModel.activeGrpcMethod != null,
      );
      viewModel.updateActiveDraftUrl('http://127.0.0.1:50052');
      await viewModel.sendActiveGrpcRequest();
      await _waitUntil(
        'open CreateOrder completion',
        () => viewModel.activeGrpcCall.state == GrpcCallState.completed,
      );
      expect(
        viewModel.activeGrpcCall.events.any(
          (event) =>
              event.kind == GrpcTransportEventKind.status &&
              event.statusCode == 0,
        ),
        isTrue,
      );
    },
    skip: _liveFixturesEnabled
        ? false
        : 'Set SENDREQ_LIVE_PROTOCOL_SERVICES=1 to test the running local services.',
  );

  test(
    'live gRPC services reject unsafe credentials and honor client cancellation',
    () async {
      final descriptors = await _orderDescriptors();
      final codec = ProtobufDynamicCodec(descriptors);
      const transport = DesktopGrpcTransport();

      for (final metadata in <Map<String, String>>[
        const {},
        const {'authorization': 'Bearer live-invalid-token'},
      ]) {
        final rejected = await transport.start(
          GrpcCallConfiguration(
            endpoint: Uri.parse('http://127.0.0.1:50051'),
            serviceName: '.order.v1.OrderService',
            methodName: 'WatchOrders',
            requestType: '.order.v1.WatchOrdersRequest',
            responseType: '.order.v1.OrderEvent',
            requestBytes: codec.encodeJson(
              '.order.v1.WatchOrdersRequest',
              '{"user_id":"live-user","limit":3}',
            ),
            metadata: metadata,
            useTls: false,
            serverStreaming: true,
            redactedValues: metadata.values.toList(growable: false),
          ),
        );
        addTearDown(rejected.cancel);
        final events = await rejected.events.toList();
        expect(
          events.any(
            (event) =>
                event.statusCode == 16 ||
                event.statusMessage?.contains('UNAUTHENTICATED') == true,
          ),
          isTrue,
        );
        expect(
          events.map((event) => event.statusMessage).join(),
          isNot(contains('live-invalid-token')),
        );
      }

      final viewModel = _workspaceViewModel();
      addTearDown(viewModel.dispose);
      viewModel.selectEnvironment('local-protocol');
      viewModel.selectRequest('demo-grpc-watch-orders');
      await _waitUntil(
        'WatchOrders schema',
        () => viewModel.activeGrpcMethod != null,
      );
      viewModel.updateActiveDraftUrl('http://127.0.0.1:50051');
      await viewModel.sendActiveGrpcRequest();
      viewModel.cancelActiveRequest();
      await _waitUntil(
        'WatchOrders cancellation',
        () => viewModel.activeGrpcCall.state == GrpcCallState.cancelled,
      );
    },
    skip: _liveFixturesEnabled
        ? false
        : 'Set SENDREQ_LIVE_PROTOCOL_SERVICES=1 to test the running local services.',
  );
}

Future<void> _waitUntil(String label, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Timed out waiting for $label.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<void> _triggerWebSocketPush(int port, String message) async {
  await _sendWebSocketControlRequest(
    port,
    Uri(path: '/push', queryParameters: {'msg': message}),
  );
}

Future<void> _triggerWebSocketBurst(int port, int count) async {
  await _sendWebSocketControlRequest(
    port,
    Uri(path: '/burst', queryParameters: {'count': '$count'}),
  );
}

Future<void> _triggerWebSocketClose(int port, {required String reason}) async {
  await _sendWebSocketControlRequest(
    port,
    Uri(path: '/close', queryParameters: {'code': '1000', 'reason': reason}),
  );
}

Future<void> _sendWebSocketControlRequest(int port, Uri uri) async {
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
  socket.write(
    'GET ${uri.toString()} HTTP/1.1\r\n'
    'Host: 127.0.0.1:$port\r\n'
    'Connection: close\r\n\r\n',
  );
  await socket.flush();
  final response = await utf8.decoder.bind(socket).join();
  expect(response, startsWith('HTTP/1.1 200'));
}

Future<void> _requireGo() async {
  final result = await Process.run('go', ['version']);
  if (result.exitCode != 0) {
    throw StateError(
      'Go is required for protocol interop tests: ${result.stderr}',
    );
  }
}

Future<dynamic> _orderDescriptors() => const ProtoSourceParser().parseFile(
  '${Directory.current.parent.path}${Platform.pathSeparator}go-grpc'
  '${Platform.pathSeparator}proto${Platform.pathSeparator}order.proto',
);

bool _isUnauthenticatedEvent(GrpcTransportEvent event) {
  if (event.statusCode == 16) return true;
  final message = event.statusMessage?.toLowerCase() ?? '';
  return message.contains('unauthenticated') || message.contains('code: 16');
}

/// 管理一个 `go run .` 服务进程，并确保测试端口不固定。
class _GoService {
  _GoService._(this._process, this.port, this._logs, this._buildDirectory);

  final Process _process;
  final int port;
  final StringBuffer _logs;
  final Directory _buildDirectory;

  bool _stopped = false;

  static Future<_GoService> start(
    String directoryName, {
    String? protocolToken,
    bool requireAuthentication = true,
  }) async {
    final port = await _freeLoopbackPort();
    final logs = StringBuffer();
    final projectDirectory = Directory(
      '${Directory.current.parent.path}${Platform.pathSeparator}$directoryName',
    );
    final buildDirectory = await Directory.systemTemp.createTemp(
      'sendreq-go-interop-',
    );
    final executable = File(
      '${buildDirectory.path}${Platform.pathSeparator}$directoryName'
      '${Platform.isWindows ? '.exe' : ''}',
    );
    try {
      // 为当前平台编译源码，而不是依赖仓库中仅限 Linux 的示例二进制，
      // 也避免遗留 go run 的子进程。
      final build = await Process.run('go', [
        'build',
        '-buildvcs=false',
        '-o',
        executable.path,
        '.',
      ], workingDirectory: projectDirectory.path);
      if (build.exitCode != 0) {
        throw StateError('Unable to build $directoryName: ${build.stderr}');
      }
      final process = await Process.start(
        executable.path,
        const [],
        environment: {
          ...Platform.environment,
          'PORT': '$port',
          if (!requireAuthentication) 'SENDREQ_REQUIRE_AUTH': '0',
          ...?protocolToken == null
              ? null
              : {'SENDREQ_PROTOCOL_TOKEN': protocolToken},
        },
      );
      unawaited(
        process.stdout.transform(utf8.decoder).listen(logs.write).asFuture(),
      );
      unawaited(
        process.stderr.transform(utf8.decoder).listen(logs.write).asFuture(),
      );
      return _GoService._(process, port, logs, buildDirectory);
    } on Object {
      await buildDirectory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> waitForPort() async {
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      try {
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(milliseconds: 250),
        );
        await socket.close();
        return;
      } on Object catch (error) {
        lastError = error;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    throw StateError('Go service did not listen on $port: $lastError\n$_logs');
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _process.kill();
    await _process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _process.kill();
        return -1;
      },
    );
    await _buildDirectory.delete(recursive: true);
  }
}

Future<int> _freeLoopbackPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

/// 真实协议联调绕过 Widget 测试绑定的固定 HTTP 400 响应。
class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.autoUncompress = true;
    return client;
  }
}
