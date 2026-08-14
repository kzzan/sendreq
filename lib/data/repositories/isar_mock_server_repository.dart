import 'dart:async';
import 'dart:convert';

import 'package:sendreq/domain/contract_publishing/mock_server.dart';
import 'package:sendreq/domain/repositories/mock_server_repository.dart';
import 'package:sendreq/data/database/isar_workspace.dart';
import 'package:sendreq/data/database/isar_workspace_models.dart';
import 'package:sendreq/data/repositories/mock_server_snapshot_codec.dart';
import 'package:sendreq/data/repositories/workspace_document_keys.dart';

/// 使用单一版本化 WorkspaceDocument 的本地 Mock Server 仓储。
class IsarMockServerRepository implements MockServerRepository {
  IsarMockServerRepository(this._workspace);

  static const maxDocumentBytes = 2 * 1024 * 1024;
  final IsarWorkspace _workspace;
  Future<void> _writes = Future.value();

  @override
  Future<void> delete(String id) => _enqueue((servers) {
    servers.removeWhere((server) => server.id == id);
    return servers;
  });

  @override
  Future<MockServer?> findById(String id) async {
    final servers = await list();
    for (final server in servers) {
      if (server.id == id) return server;
    }
    return null;
  }

  @override
  Future<List<MockServer>> list() async {
    final document = await _workspace.instance.workspaceDocuments.getByKey(
      WorkspaceDocumentKeys.persistentMockServersV1,
    );
    if (document == null) return const [];
    try {
      return List.unmodifiable(
        _sort(MockServerSnapshotCodec.decodeDocument(document.payloadJson)),
      );
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> save(MockServer server) => _enqueue(
    (servers) => [...servers.where((item) => item.id != server.id), server],
  );

  Future<void> _enqueue(List<MockServer> Function(List<MockServer>) change) {
    _writes = _writes.then((_) async {
      final document = await _workspace.instance.workspaceDocuments.getByKey(
        WorkspaceDocumentKeys.persistentMockServersV1,
      );
      final current = document == null
          ? <MockServer>[]
          : MockServerSnapshotCodec.decodeDocument(document.payloadJson);
      final next = _sort(change(current));
      final payload = MockServerSnapshotCodec.encodeDocument(next);
      if (utf8.encode(payload).length > maxDocumentBytes) {
        throw StateError('Mock Server document exceeds the local byte budget.');
      }
      final target = document ?? WorkspaceDocument();
      target
        ..key = WorkspaceDocumentKeys.persistentMockServersV1
        ..schemaVersion = IsarWorkspace.currentDocumentSchemaVersion
        ..updatedAt = DateTime.now().toUtc()
        ..payloadJson = payload;
      await _workspace.instance.writeTxn(
        () => _workspace.instance.workspaceDocuments.put(target),
      );
    });
    return _writes;
  }

  List<MockServer> _sort(Iterable<MockServer> servers) =>
      servers.toList()..sort((left, right) {
        final updated = right.updatedAt.compareTo(left.updatedAt);
        return updated == 0 ? left.id.compareTo(right.id) : updated;
      });
}
