import '../models/workspace_models.dart';

/// 可持久化执行历史的领域仓储契约。
abstract interface class ExecutionHistoryStore {
  Future<List<ExecutionRecord>> loadRecent({int limit = 200});

  Future<void> append(ExecutionRecord record);

  Future<void> clear();

  Future<void> flush();
}
