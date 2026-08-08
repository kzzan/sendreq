import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/demo/workbench_seed.dart';
import 'package:sendreq/data/services/http_request_execution_runtime.dart';
import 'package:sendreq/data/services/local_mock_runtime.dart';
import 'package:sendreq/domain/models/workspace_models.dart';
import 'package:sendreq/features/workspace/view_models/workspace_view_model.dart';

import 'support/workspace_view_model_test_factory.dart';

void main() {
  // 分组测试本地回环 Mock 服务器（LoopbackMockRuntime）的核心生命周期与行为。
  group('LoopbackMockRuntime', () {
    late LoopbackMockRuntime runtime;

    setUp(() {
      runtime = LoopbackMockRuntime();
    });

    // 每个用例结束后关闭服务器，避免端口泄漏影响后续用例。
    tearDown(() => runtime.stop());

    // 验证方法+路径匹配时，Mock 服务器返回预设的响应（状态码、标记头、响应体）。
    test(
      'returns the captured response for the matching method and path',
      () async {
        final info = await runtime.start(_mockDraft());
        final response = await _request(
          info.url.replace(path: '/v1/widgets', query: 'source=fixture'),
          method: 'POST',
        );

        // 服务器应只监听回环地址 127.0.0.1，不对外暴露。
        expect(info.url.host, '127.0.0.1');
        expect(runtime.isRunning, isTrue);
        expect(response.statusCode, 201);
        expect(response.headers.value('x-sendreq-mock'), 'local');
        expect(response.body, '{"created":true}');
      },
    );

    // 验证路径不匹配时返回 JSON 404；同路径但方法不符（GET vs POST）也应 404。
    test('returns a JSON 404 when the method or path does not match', () async {
      final info = await runtime.start(_mockDraft());
      final response = await _request(info.url.replace(path: '/v1/missing'));

      expect(response.statusCode, HttpStatus.notFound);
      expect(response.headers.contentType?.mimeType, ContentType.json.mimeType);
      expect(jsonDecode(response.body), {'error': 'mock endpoint not found'});

      // 注意：这里用默认 GET 请求访问 POST 端点，验证方法不匹配同样返回 404。
      final wrongMethod = await _request(info.url.replace(path: '/v1/widgets'));
      expect(wrongMethod.statusCode, HttpStatus.notFound);
    });

    test('ignores query parameters when method and path match', () async {
      final info = await runtime.start(
        _mockDraft(
          resolvedUrl:
              'https://api.sendreq.local/v1/widgets?tag=stable&tag=beta&page=2',
        ),
      );

      final orderedDifferently = await _request(
        info.url.replace(
          path: '/v1/widgets',
          query: 'page=2&tag=beta&tag=stable',
        ),
        method: 'POST',
      );
      final differentQuery = await _request(
        info.url.replace(path: '/v1/widgets', query: 'tag=stable&page=2'),
        method: 'POST',
      );
      final noQuery = await _request(
        info.url.replace(path: '/v1/widgets'),
        method: 'POST',
      );

      expect(orderedDifferently.statusCode, 201);
      expect(differentQuery.statusCode, 201);
      expect(noQuery.statusCode, 201);
    });

    test('hot-applies enabled response Header changes', () async {
      final info = await runtime.start(_mockDraft());
      final endpoint = info.url.replace(
        path: '/v1/widgets',
        query: 'source=fixture',
      );

      runtime.updateDraft(
        _mockDraft(
          responseHeaders: const [
            KeyValueRow(keyName: 'x-enabled', value: 'fresh'),
            KeyValueRow(keyName: 'x-disabled', value: 'hidden', enabled: false),
          ],
        ),
      );
      final response = await _request(endpoint, method: 'POST');

      expect(response.statusCode, 201);
      expect(response.headers.value('x-enabled'), 'fresh');
      expect(response.headers.value('x-disabled'), isNull);
      expect(response.headers.value('x-sendreq-mock'), isNull);
    });

    // 验证 stop 之后服务器停止监听，再请求会抛出 SocketException（连接被拒）。
    test('stops accepting requests after stop', () async {
      final info = await runtime.start(_mockDraft());
      await runtime.stop();

      expect(runtime.isRunning, isFalse);
      await expectLater(
        _request(info.url.replace(path: '/v1/widgets')),
        throwsA(isA<SocketException>()),
      );
    });
  });

  // 验证端口绑定失败时，视图模型暴露可重试的错误提示而非崩溃或静默失败。
  test(
    'shows a retryable message when the local port cannot be bound',
    () async {
      final viewModel = workspaceViewModel(
        seed: WorkbenchSeed(
          requests: const [],
          drafts: const {},
          variables: const [],
          metrics: const [],
          history: [_executionRecord()],
        ),
        mockRuntime: _FailingMockRuntime(),
      );
      addTearDown(viewModel.dispose);

      viewModel.createMockDraft();
      await viewModel.startMockServer();

      expect(viewModel.isMockRunning, isFalse);
      expect(viewModel.lastActionMessage, 'Could not start Quick Mock. Retry.');
    },
  );

  test(
    'exposes a callable endpoint and applies Mock edits while running',
    () async {
      final runtime = LoopbackMockRuntime();
      final viewModel = workspaceViewModel(
        seed: WorkbenchSeed(
          requests: const [],
          drafts: const {},
          variables: const [],
          metrics: const [],
          history: [_executionRecord()],
        ),
        mockRuntime: runtime,
      );
      addTearDown(() async {
        await runtime.stop();
        viewModel.dispose();
      });

      viewModel.createMockDraft();
      await viewModel.startMockServer();

      final originalEndpoint = viewModel.mockUrl!;
      expect(originalEndpoint.path, '/v1/widgets');
      expect(originalEndpoint.query, 'source=fixture');
      var response = await _request(originalEndpoint, method: 'POST');
      expect(response.statusCode, 201);
      expect(response.body, '{"created":true}');

      viewModel.updateMockMethod('GET');
      viewModel.updateMockRoute('/v2/catalog?preview=true');
      viewModel.updateMockStatusCode(202);
      viewModel.updateMockResponseBody('{"accepted":true}');
      viewModel.updateMockResponseHeader(index: 0, value: 'updated');
      viewModel.addMockResponseHeader();
      viewModel.updateMockResponseHeader(
        index: viewModel.mockDraft!.response.headers.length - 1,
        keyName: 'x-mock-mode',
        value: 'local',
      );

      final editedEndpoint = viewModel.mockUrl!;
      expect(editedEndpoint.path, '/v2/catalog');
      expect(editedEndpoint.query, 'preview=true');
      response = await _request(editedEndpoint);
      expect(response.statusCode, 202);
      expect(response.body, '{"accepted":true}');
      expect(response.headers.value('x-sendreq-mock'), 'updated');
      expect(response.headers.value('x-mock-mode'), 'local');

      viewModel.updateMockStatusCode(600);
      expect(viewModel.mockDraft!.response.statusCode, 202);
    },
  );

  test(
    'creates and serves a manual fake response without execution history',
    () async {
      final runtime = LoopbackMockRuntime();
      final viewModel = workspaceViewModel(
        seed: const WorkbenchSeed(
          requests: [],
          drafts: {},
          variables: [],
          metrics: [],
          history: [],
        ),
        mockRuntime: runtime,
      );
      addTearDown(() async {
        await runtime.stop();
        viewModel.dispose();
      });

      expect(viewModel.canCreateMockFromResponse, isFalse);
      viewModel.createManualMockDraft();

      final draft = viewModel.mockDraft!;
      expect(draft.source, MockDraftSource.manual);
      expect(draft.request.method, 'GET');
      expect(draft.request.resolvedUrl, 'http://mock.sendreq.local/');
      expect(draft.response.statusCode, HttpStatus.ok);
      expect(draft.response.headers.single.keyName, 'Content-Type');
      expect(jsonDecode(draft.response.body), {'message': 'Mock response'});

      await viewModel.startMockServer();
      final response = await _request(viewModel.mockUrl!);

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, ContentType.json.mimeType);
      expect(jsonDecode(response.body), {'message': 'Mock response'});
    },
  );

  test('sendreq HTTP runtime can call a running manual Mock', () async {
    final mockRuntime = LoopbackMockRuntime();
    addTearDown(mockRuntime.stop);
    final viewModel = workspaceViewModel(
      seed: const WorkbenchSeed(
        requests: [],
        drafts: {},
        variables: [],
        metrics: [],
        history: [],
      ),
      mockRuntime: mockRuntime,
    );
    addTearDown(viewModel.dispose);
    viewModel.createManualMockDraft();
    await viewModel.startMockServer();
    final endpoint = viewModel.mockUrl!;
    final request = RequestDraft(
      method: 'GET',
      baseUrlToken: '',
      path: endpoint.toString(),
      params: const [],
      headers: const [],
      body: '',
    );

    final response = await HttpRequestExecutionRuntime().send(
      draft: request,
      resolvedUrl: endpoint.toString(),
    );

    expect(response.statusCode, HttpStatus.ok);
    expect(jsonDecode(response.body), {'message': 'Mock response'});
  });

  test(
    'does not replay captured gzip framing for the decoded response body',
    () async {
      final runtime = LoopbackMockRuntime();
      addTearDown(runtime.stop);
      final viewModel = workspaceViewModel(mockRuntime: runtime);
      addTearDown(viewModel.dispose);
      viewModel.createManualMockDraft();
      viewModel.addMockResponseHeader();
      viewModel.updateMockResponseHeader(
        index: viewModel.mockDraft!.response.headers.length - 1,
        keyName: 'content-encoding',
        value: 'gzip',
      );
      viewModel.addMockResponseHeader();
      viewModel.updateMockResponseHeader(
        index: viewModel.mockDraft!.response.headers.length - 1,
        keyName: 'transfer-encoding',
        value: 'chunked',
      );
      await viewModel.startMockServer();

      final endpoint = viewModel.mockUrl!;
      final response = await HttpRequestExecutionRuntime().send(
        draft: RequestDraft(
          method: 'GET',
          baseUrlToken: '',
          path: endpoint.toString(),
          params: const [],
          headers: const [],
          body: '',
        ),
        resolvedUrl: endpoint.toString(),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(jsonDecode(response.body), {'message': 'Mock response'});
      expect(
        response.headers.any(
          (header) => header.keyName.toLowerCase() == 'content-encoding',
        ),
        isFalse,
      );
    },
  );

  test(
    'an existing request can call a manual Mock with environment auth',
    () async {
      final mockRuntime = LoopbackMockRuntime();
      final viewModel = workspaceViewModel(mockRuntime: mockRuntime);
      addTearDown(() async {
        await mockRuntime.stop();
        viewModel.dispose();
      });
      viewModel.createManualMockDraft();
      await viewModel.startMockServer();

      viewModel.updateActiveDraftUrl(viewModel.mockUrl!.toString());
      viewModel.updateActiveDraftMethod('GET');
      await viewModel.sendActiveRequest();

      expect(viewModel.executionError, isNull);
      expect(viewModel.response?.statusCode, HttpStatus.ok);
      expect(jsonDecode(viewModel.response!.body), {
        'message': 'Mock response',
      });
    },
  );

  test('prevents duplicate Mock starts while a server is binding', () async {
    final runtime = _DelayedMockRuntime();
    final viewModel = workspaceViewModel(
      seed: WorkbenchSeed(
        requests: const [],
        drafts: const {},
        variables: const [],
        metrics: const [],
        history: [_executionRecord()],
      ),
      mockRuntime: runtime,
    );
    addTearDown(viewModel.dispose);

    viewModel.createMockDraft();
    final firstStart = viewModel.startMockServer();
    final secondStart = viewModel.startMockServer();

    expect(viewModel.isMockStarting, isTrue);
    expect(runtime.startCalls, 1);
    runtime.completeStart();
    await Future.wait([firstStart, secondStart]);

    expect(viewModel.isMockStarting, isFalse);
    expect(viewModel.isMockRunning, isTrue);
  });
}

/// 构造一个 POST /v1/widgets 的 Mock 草稿，其预设响应带自定义标记头。
MockDraft _mockDraft({
  String resolvedUrl = 'https://api.sendreq.local/v1/widgets?source=fixture',
  List<KeyValueRow> responseHeaders = const [
    KeyValueRow(keyName: 'x-sendreq-mock', value: 'local'),
  ],
}) => MockDraft(
  request: ExecutionRequestSnapshot(
    method: 'POST',
    resolvedUrl: resolvedUrl,
    headers: [],
    body: '',
    environmentName: 'Test',
  ),
  response: ResponseSnapshot(
    statusCode: 201,
    timeMs: 12,
    sizeKb: 0.1,
    body: '{"created":true}',
    headers: responseHeaders,
  ),
);

/// 构造一条可进入工作台历史记录的示例执行记录，供端口绑定失败用例填充种子数据。
ExecutionRecord _executionRecord() => ExecutionRecord(
  id: 'record-1',
  requestId: 'request-1',
  method: 'POST',
  path: '/v1/widgets',
  timeMs: 12,
  when: 'now',
  requestSnapshot: _mockDraft().request,
  response: _mockDraft().response,
);

/// 向指定 URL 发起一次真实 HTTP 请求，并读取状态码、响应头与响应体。
Future<_Response> _request(Uri url, {String method = 'GET'}) async {
  final client = HttpClient();
  try {
    final response = await (await client.openUrl(method, url)).close();
    return _Response(
      statusCode: response.statusCode,
      headers: response.headers,
      body: await response.transform(utf8.decoder).join(),
    );
  } finally {
    client.close(force: true);
  }
}

/// 精简的 HTTP 响应封装，便于断言请求结果。
class _Response {
  const _Response({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final HttpHeaders headers;
  final String body;
}

/// 注入式失败 Mock 运行时：start 恒抛端口绑定异常，用于验证视图模型的错误提示路径。
class _FailingMockRuntime implements LocalMockRuntime {
  @override
  LocalMockServerInfo? get info => null;

  @override
  bool get isRunning => false;

  @override
  Future<LocalMockServerInfo> start(MockDraft draft) =>
      Future.error(const SocketException('Port binding failed'));

  @override
  void updateDraft(MockDraft draft) {}

  @override
  Future<void> stop() async {}
}

class _DelayedMockRuntime implements LocalMockRuntime {
  final Completer<LocalMockServerInfo> _startCompleter = Completer();
  LocalMockServerInfo? _info;
  int startCalls = 0;

  @override
  LocalMockServerInfo? get info => _info;

  @override
  bool get isRunning => _info != null;

  @override
  Future<LocalMockServerInfo> start(MockDraft draft) {
    startCalls++;
    return _startCompleter.future.then((info) {
      _info = info;
      return info;
    });
  }

  void completeStart() => _startCompleter.complete(
    LocalMockServerInfo(url: Uri.parse('http://127.0.0.1:51234')),
  );

  @override
  Future<void> stop() async => _info = null;

  @override
  void updateDraft(MockDraft draft) {}
}
