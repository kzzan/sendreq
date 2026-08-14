import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/database/isar_workspace.dart';
import 'package:sendreq/data/repositories/isar_mock_server_repository.dart';
import 'package:sendreq/data/services/local_mock_server_runtime.dart';
import 'package:sendreq/domain/contract_publishing/mock_server.dart';
import 'package:sendreq/domain/contract_publishing/session_contract_publishing_service.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';

import 'support/isar_test_core.dart';

void main() {
  setUpAll(initializeIsarForTest);

  test(
    'saved multi-endpoint Mock replays only after explicit restart-time start',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-e2e-');
      addTearDown(() => directory.delete(recursive: true));
      final workspace = await IsarWorkspace.open(directory: directory);
      addTearDown(workspace.close);
      final repository = IsarMockServerRepository(workspace);
      final original = _service(repository, LocalMockServerRuntime());
      await original.saveMockServer(_server());
      await original.disposeSession();

      var bindCount = 0;
      final restoredRuntime = LocalMockServerRuntime(
        bind: () {
          bindCount++;
          return HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        },
      );
      final restored = _service(repository, restoredRuntime);
      addTearDown(restored.disposeSession);

      expect(
        (await restored.loadMockServers()).kind,
        OperationOutcomeKind.success,
      );
      final stopped = restored.mockServers.single;
      expect(stopped.server.endpoints, hasLength(2));
      expect(stopped.runtime.status, MockServerRuntimeStatus.stopped);
      expect(stopped.runtime.loopbackUrl, isNull);
      expect(bindCount, 0);

      var realServiceRequests = 0;
      final realService = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => realService.close(force: true));
      realService.listen((request) async {
        realServiceRequests++;
        request.response
          ..statusCode = HttpStatus.ok
          ..write('{"service":"real"}');
        await request.response.close();
      });

      final start = await restored.startMockServer(
        const ResourceRef(kind: ResourceKind.mockServer, id: 'multi-endpoint'),
      );
      expect(start.kind, OperationOutcomeKind.success);
      expect(bindCount, 1);
      final running = restored.mockServers.single.runtime;
      expect(running.status, MockServerRuntimeStatus.running);
      final base = Uri.parse(running.loopbackUrl!);

      expect(await _get(base.replace(path: '/users')), '{"users":[]}');
      expect(await _get(base.replace(path: '/health')), '{"ok":true}');
      expect(
        await _get(
          Uri(scheme: 'http', host: '127.0.0.1', port: realService.port),
        ),
        '{"service":"real"}',
      );
      expect(realServiceRequests, 1);

      await restored.stopMockServer(
        const ResourceRef(kind: ResourceKind.mockServer, id: 'multi-endpoint'),
      );
      expect(
        restored.mockServers.single.runtime.status,
        MockServerRuntimeStatus.stopped,
      );
      expect(restored.mockServers.single.runtime.loopbackUrl, isNull);
    },
  );
}

SessionContractPublishingService _service(
  IsarMockServerRepository repository,
  LocalMockServerRuntime runtime,
) => SessionContractPublishingService(
  mockServerRepository: repository,
  mockServerRuntime: runtime,
);

MockServer _server() => MockServer(
  id: 'multi-endpoint',
  name: 'Multi endpoint',
  createdAt: DateTime.utc(2026, 8, 11),
  updatedAt: DateTime.utc(2026, 8, 11),
  endpoints: [
    MockEndpoint(
      id: 'users',
      matcher: MockRequestMatcher(method: 'GET', path: '/users'),
      variants: [
        MockResponseVariant(
          id: 'users-default',
          statusCode: HttpStatus.ok,
          body: '{"users":[]}',
        ),
      ],
    ),
    MockEndpoint(
      id: 'health',
      matcher: MockRequestMatcher(method: 'GET', path: '/health'),
      variants: [
        MockResponseVariant(
          id: 'health-default',
          statusCode: HttpStatus.ok,
          body: '{"ok":true}',
        ),
      ],
    ),
  ],
);

Future<String> _get(Uri uri) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(uri)).close();
    expect(response.statusCode, HttpStatus.ok);
    return response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}
