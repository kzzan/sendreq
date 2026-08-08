import 'dart:async';
import '../../domain/models/workspace_models.dart';
import '../database/isar_workspace.dart';
import '../database/isar_workspace_models.dart';
import '../../domain/repositories/execution_history_store.dart';
import 'execution_history_snapshot_codec.dart';

/// Isar 执行历史文档。保留最近 200 条已脱敏 UI 快照。
class IsarExecutionHistoryStore implements ExecutionHistoryStore {
  /// 以工作区数据库构造历史存储。
  IsarExecutionHistoryStore(this._workspace);

  /// 最多保留的历史记录条数。
  static const _retentionLimit = 200;

  /// 历史文档编码后的最大字节预算，超出时淘汰旧记录。
  static const _maxDocumentBytes = 2 * 1024 * 1024;

  /// 存储执行历史所用的工作区文档 key。
  static const _historyKey = 'execution-history-v1';

  /// 承载历史文档的工作区数据库。
  final IsarWorkspace _workspace;

  /// 串行写盘队列，保证追加与清空按顺序执行。
  Future<void> _writeQueue = Future.value();

  /// 加载最近 [limit] 条执行记录；单条损坏的记录会被跳过。
  @override
  Future<List<ExecutionRecord>> loadRecent({
    int limit = _retentionLimit,
  }) async {
    final document = await _workspace.instance.workspaceDocuments.getByKey(
      _historyKey,
    );
    if (document == null) return const [];
    final records = <ExecutionRecord>[];
    for (final stored in ExecutionHistorySnapshotCodec.decodeEntries(
      document.payloadJson,
    ).take(limit)) {
      try {
        records.add(ExecutionHistorySnapshotCodec.decodeRecord(stored));
      } on Object {
        // 损坏的单条记录不会阻断历史页。
      }
    }
    return records;
  }

  /// 追加一条执行记录，超出保留条数或字节预算时淘汰旧记录。
  @override
  Future<void> append(ExecutionRecord record) {
    _writeQueue = _writeQueue.then((_) async {
      final existing = await _workspace.instance.workspaceDocuments.getByKey(
        _historyKey,
      );
      // 新记录放在最前，仅保留最近 [retentionLimit] 条。
      final candidates = <Map<String, Object?>>[
        ExecutionHistorySnapshotCodec.entry(record, DateTime.now()),
        ...ExecutionHistorySnapshotCodec.decodeEntries(existing?.payloadJson),
      ].take(_retentionLimit);
      // 仍超出字节预算则进一步截断，避免历史文档无限膨胀。
      final stored = ExecutionHistorySnapshotCodec.retainWithinByteBudget(
        candidates,
        maxBytes: _maxDocumentBytes,
      );
      final document = existing ?? WorkspaceDocument();
      document
        ..key = _historyKey
        ..schemaVersion = IsarWorkspace.currentDocumentSchemaVersion
        ..updatedAt = DateTime.now().toUtc()
        ..payloadJson = ExecutionHistorySnapshotCodec.encodeDocument(stored);
      await _workspace.instance.writeTxn(
        () => _workspace.instance.workspaceDocuments.put(document),
      );
    });
    return _writeQueue;
  }

  /// 清空全部执行历史。
  @override
  Future<void> clear() {
    _writeQueue = _writeQueue.then((_) async {
      final document = await _workspace.instance.workspaceDocuments.getByKey(
        _historyKey,
      );
      if (document == null) return;
      await _workspace.instance.writeTxn(
        () => _workspace.instance.workspaceDocuments.delete(document.id),
      );
    });
    return _writeQueue;
  }

  /// 等待所有排队的写入完成。
  @override
  Future<void> flush() => _writeQueue;
}
