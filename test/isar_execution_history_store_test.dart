import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/database/isar_workspace.dart';
import 'package:sendreq/data/database/isar_workspace_models.dart';
import 'package:sendreq/data/repositories/isar_execution_history_store.dart';
import 'package:sendreq/domain/models/workspace_models.dart';

import 'support/isar_test_core.dart';

void main() {
  setUpAll(initializeIsarForTest);

  test('Isar history restores records and clears them', () async {
    final directory = await Directory.systemTemp.createTemp('sendreq-history-');
    addTearDown(() => directory.delete(recursive: true));
    final workspace = await IsarWorkspace.open(directory: directory);
    addTearDown(workspace.close);
    final store = IsarExecutionHistoryStore(workspace);
    const record = ExecutionRecord(
      id: 'execution-1',
      requestId: 'request-1',
      method: 'GET',
      path: '/v1/users',
      status: 200,
      timeMs: 42,
      when: 'now',
      requestSnapshot: ExecutionRequestSnapshot(
        method: 'GET',
        resolvedUrl: 'https://api.sendreq.local/v1/users',
        headers: [
          KeyValueRow(keyName: 'Authorization', value: 'token', secret: true),
        ],
        body: '',
        environmentName: 'Test',
      ),
      response: ResponseSnapshot(
        statusCode: 200,
        timeMs: 42,
        sizeKb: 0.1,
        body: '{"ok":true}',
        headers: [],
      ),
    );

    await store.append(record);
    final restored = await store.loadRecent();
    expect(restored, hasLength(1));
    expect(restored.single.response?.body, '{"ok":true}');
    expect(
      restored.single.requestSnapshot?.headers.single.value,
      '••••••••••••',
    );

    await store.clear();
    expect(await store.loadRecent(), isEmpty);
  });

  test('Isar history bounds body size and masks sensitive headers', () async {
    final directory = await Directory.systemTemp.createTemp('sendreq-history-');
    addTearDown(() => directory.delete(recursive: true));
    final workspace = await IsarWorkspace.open(directory: directory);
    addTearDown(workspace.close);
    final store = IsarExecutionHistoryStore(workspace);
    final longBody = List.filled(40 * 1024, 'x').join();

    await store.append(
      ExecutionRecord(
        id: 'execution-large',
        requestId: 'request-large',
        method: 'GET',
        path: '/large',
        status: 200,
        timeMs: 1,
        when: 'now',
        requestSnapshot: ExecutionRequestSnapshot(
          method: 'GET',
          resolvedUrl: 'https://api.sendreq.local/large',
          headers: const [
            KeyValueRow(keyName: 'Authorization', value: 'raw-token'),
          ],
          body: longBody,
          environmentName: 'Test',
        ),
        response: ResponseSnapshot(
          statusCode: 200,
          timeMs: 1,
          sizeKb: 40,
          body: longBody,
          headers: const [],
        ),
      ),
    );

    final restored = await store.loadRecent();
    expect(restored, hasLength(1));
    expect(restored.single.response!.body, endsWith('...[truncated]'));
    expect(restored.single.response!.body.length, lessThan(longBody.length));
    expect(
      restored.single.requestSnapshot!.headers.single.value,
      '••••••••••••',
    );
  });

  test('Isar history retains the newest 200 small records', () async {
    final directory = await Directory.systemTemp.createTemp('sendreq-history-');
    addTearDown(() => directory.delete(recursive: true));
    final workspace = await IsarWorkspace.open(directory: directory);
    addTearDown(workspace.close);
    final store = IsarExecutionHistoryStore(workspace);

    for (var index = 0; index < 205; index++) {
      await store.append(
        ExecutionRecord(
          id: 'execution-$index',
          requestId: 'request-$index',
          method: 'GET',
          path: '/$index',
          status: 200,
          timeMs: index,
          when: 'now',
          response: const ResponseSnapshot(
            statusCode: 200,
            timeMs: 1,
            sizeKb: 0,
            body: '{}',
            headers: [],
          ),
        ),
      );
    }

    final restored = await store.loadRecent();
    expect(restored, hasLength(200));
    expect(restored.first.id, 'execution-204');
  });

  test('Isar history persists only WebSocket session metadata', () async {
    final directory = await Directory.systemTemp.createTemp('sendreq-history-');
    addTearDown(() => directory.delete(recursive: true));
    final workspace = await IsarWorkspace.open(directory: directory);
    addTearDown(workspace.close);
    final store = IsarExecutionHistoryStore(workspace);
    const secret = 'token-value';
    await store.append(
      ExecutionRecord(
        id: 'websocket-1',
        requestId: 'stream',
        method: 'WS',
        path: 'wss://socket.sendreq.io/events?token=••••••••',
        status: null,
        timeMs: 250,
        when: 'now',
        errorCategory: 'websocket',
        errorMessage: 'Handshake failed: ••••••••',
        webSocketSummary: WebSocketSessionHistorySummary(
          endpoint: 'wss://socket.sendreq.io/events?token=••••••••',
          startedAt: DateTime.utc(2026, 1, 1),
          endedAt: DateTime.utc(2026, 1, 1, 0, 0, 0, 250),
          terminalStatus: 'error',
          inboundMessageCount: 3,
          outboundMessageCount: 2,
          errorMessage: 'Handshake failed: ••••••••',
        ),
      ),
    );

    final restored = await store.loadRecent();
    final summary = restored.single.webSocketSummary;
    expect(summary?.terminalStatus, 'error');
    expect(summary?.inboundMessageCount, 3);
    expect(summary?.outboundMessageCount, 2);
    expect(restored.single.requestSnapshot, isNull);
    expect(restored.single.response, isNull);

    final document = await workspace.instance.workspaceDocuments.getByKey(
      'execution-history-v1',
    );
    expect(document?.payloadJson, contains('"webSocket"'));
    expect(document?.payloadJson, isNot(contains(secret)));
    expect(document?.payloadJson, isNot(contains('binaryPayload')));
  });
}
