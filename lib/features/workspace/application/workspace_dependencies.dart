import '../../../domain/models/workspace_models.dart';
import '../../../domain/repositories/api_asset_repository.dart';
import '../../../domain/repositories/environment_store.dart';
import '../../../domain/repositories/execution_history_store.dart';
import '../../../domain/repositories/workspace_preference_store.dart';

/// Workspace feature 的依赖契约与启动快照。
///
/// 它只依赖领域仓储接口，不暴露 Isar、文件或 SharedPreferences 等具体
/// 实现。应用入口负责选择实现并构造该对象，Workspace 只消费这个契约。
class WorkspaceDependencies {
  /// 组装工作区持久化依赖。
  const WorkspaceDependencies({
    required this.preferenceStore,
    required this.assetRepository,
    required this.environmentStore,
    this.historyStore,
    this.initialHistory = const [],
    this.defaultDocumentationOutputDirectory,
  });

  /// 工作区外观、语言与快捷键偏好存储。
  final WorkspacePreferenceStore preferenceStore;

  /// 集合、文件夹、请求及打开标签页的仓储。
  final ApiAssetRepository assetRepository;

  /// 环境与变量配置的仓储。
  final EnvironmentStore environmentStore;

  /// 执行历史仓储；持久化后端不可用时允许为空。
  final ExecutionHistoryStore? historyStore;

  /// 启动时已恢复的近期执行记录。
  final List<ExecutionRecord> initialHistory;

  /// 平台解析出的默认 API 文档导出目录。
  final String? defaultDocumentationOutputDirectory;
}
