import 'package:flutter/foundation.dart';

import 'package:sendreq/data/database/isar_workspace.dart';
import 'package:sendreq/data/repositories/file_api_asset_repository.dart';
import 'package:sendreq/data/repositories/file_environment_store.dart';
import 'package:sendreq/data/repositories/file_workspace_preference_store.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/data/repositories/in_memory_environment_store.dart';
import 'package:sendreq/data/repositories/in_memory_mock_server_repository.dart';
import 'package:sendreq/data/repositories/in_memory_user_notice_repository.dart';
import 'package:sendreq/data/repositories/in_memory_workspace_preference_store.dart';
import 'package:sendreq/data/repositories/isar_api_asset_repository.dart';
import 'package:sendreq/data/repositories/isar_environment_store.dart';
import 'package:sendreq/data/repositories/isar_mock_server_repository.dart';
import 'package:sendreq/data/repositories/isar_user_notice_repository.dart';
import 'package:sendreq/data/repositories/shared_preferences_workspace_preference_store.dart';
import 'package:sendreq/domain/repositories/api_asset_repository.dart';
import 'package:sendreq/domain/repositories/environment_store.dart';
import 'package:sendreq/domain/repositories/mock_server_repository.dart';
import 'package:sendreq/domain/notifications/user_notice_repository.dart';
import 'package:sendreq/domain/repositories/workspace_preference_store.dart';
import 'package:sendreq/ui/shell/application/workspace_dependencies.dart';
import 'package:sendreq/data/demo/demo_example_catalog.dart';
import 'package:sendreq/ui/shell/application/workspace_startup_recovery.dart';

/// 启动迁移的可观察阶段。阶段顺序反映依赖关系：偏好完成后，才读取工作区。
enum PersistenceStartupStage {
  /// 偏好存储的加载与迁移。
  preferences,

  /// 工作区数据库的打开与资产迁移。
  workspace,

  /// 环境配置的加载。
  environments,
}

/// 某个启动阶段的结果。失败不会删除或覆盖旧文件。
class PersistenceStartupStageStatus {
  /// 构造成功状态：不携带错误。
  const PersistenceStartupStageStatus.success(this.stage) : error = null;

  /// 构造失败状态：携带导致失败的错误对象。
  const PersistenceStartupStageStatus.failure(this.stage, this.error);

  /// 该阶段标识。
  final PersistenceStartupStage stage;

  /// 失败原因；成功时为 null。
  final Object? error;

  /// 阶段是否执行成功（无错误）。
  bool get succeeded => error == null;
}

/// 一次启动完成后供应用根消费的持久化依赖与恢复状态。
class DesktopPersistenceStartupResult {
  /// 组装一次启动完成的全部持久化依赖与恢复状态。
  const DesktopPersistenceStartupResult({
    required this.workspaceDependencies,
    required this.stageStatuses,
    this.workspace,
  });

  /// 工作区所需的完整持久化依赖快照。
  ///
  /// 视图和 ViewModel 通过这个快照依赖领域接口，无需了解具体数据后端。
  final WorkspaceDependencies workspaceDependencies;

  /// 各启动阶段的结果映射，供恢复提示界面使用。
  final Map<PersistenceStartupStage, PersistenceStartupStageStatus>
  stageStatuses;

  /// 已打开的 Isar 工作区；未打开或失败时为 null。
  final IsarWorkspace? workspace;

  /// 所有未成功阶段的状态列表。
  List<PersistenceStartupStageStatus> get failures => stageStatuses.values
      .where((status) => !status.succeeded)
      .toList(growable: false);

  /// 是否存在需要恢复提示的失败阶段。
  bool get requiresRecovery => failures.isNotEmpty;

  /// 仅在应用被新的启动组合替换前关闭旧数据库。
  Future<void> dispose() async {
    if (workspace != null && workspace!.instance.isOpen) {
      await workspace!.close();
    }
  }
}

/// 将桌面持久化初始化集中在组合根：每个阶段都记录状态，并保留可读旧数据。
class DesktopPersistenceStartup {
  /// 注入各阶段依赖工厂，便于组合根按运行环境替换实现。
  DesktopPersistenceStartup({
    required this.createPreferenceStore,
    required this.loadLegacyAssets,
    required this.openWorkspace,
    required this.loadIsarAssets,
    required this.loadIsarEnvironmentStore,
    required this.loadEnvironmentStore,
  });

  /// 构建生产环境的启动组合：SharedPreferences 偏好 + 文件/Isar 持久化。
  factory DesktopPersistenceStartup.production() => DesktopPersistenceStartup(
    createPreferenceStore: () =>
        SharedPreferencesWorkspacePreferenceStore.create(
          legacyStore: FileWorkspacePreferenceStore(),
        ),
    loadLegacyAssets: FileApiAssetRepository.loadForMigration,
    openWorkspace: IsarWorkspace.open,
    loadIsarAssets: (workspace, legacy) => IsarApiAssetRepository.load(
      workspace: workspace,
      legacyRepository: legacy,
    ),
    loadIsarEnvironmentStore: (workspace) async => IsarEnvironmentStore.load(
      workspace: workspace,
      legacyStore: await FileEnvironmentStore.loadForMigration(),
    ),
    // Isar 不可用时使用内存回退；旧 JSON 仅作为 Isar 首次迁移来源，
    // 不再成为跨平台运行时的第二套可写存储。
    loadEnvironmentStore: () async => InMemoryEnvironmentStore.defaults(),
  );

  /// 创建偏好存储的工厂。
  final Future<WorkspacePreferenceStore> Function() createPreferenceStore;

  /// 加载旧版文件资产仓库（作为 Isar 迁移来源）。
  final Future<FileApiAssetRepository> Function() loadLegacyAssets;

  /// 打开 Isar 工作区的工厂。
  final Future<IsarWorkspace> Function() openWorkspace;

  /// 从工作区加载 Isar 资产，并可选迁移旧版数据。
  final Future<ApiAssetRepository> Function(
    IsarWorkspace workspace,
    FileApiAssetRepository? legacy,
  )
  loadIsarAssets;

  /// 从 Isar 工作区加载环境；仅在数据库不可用时才使用文件回退。
  final Future<EnvironmentStore> Function(IsarWorkspace workspace)
  loadIsarEnvironmentStore;

  /// 加载环境存储的工厂。
  final Future<EnvironmentStore> Function() loadEnvironmentStore;

  /// 按依赖顺序执行全部启动阶段；单阶段失败不阻断其余阶段。
  Future<DesktopPersistenceStartupResult> initialize() async {
    final statuses = <PersistenceStartupStage, PersistenceStartupStageStatus>{};
    WorkspacePreferenceStore preferences = InMemoryWorkspacePreferenceStore();
    // 第一阶段：加载偏好存储；失败时回退到内存实现。
    try {
      final candidate = await createPreferenceStore();
      await candidate.load();
      preferences = candidate;
      final migrationIssue =
          candidate is SharedPreferencesWorkspacePreferenceStore
          ? candidate.migrationIssue
          : null;
      // 迁移遗留问题不算异常，单独记入失败状态供恢复提示展示。
      statuses[PersistenceStartupStage.preferences] = migrationIssue == null
          ? const PersistenceStartupStageStatus.success(
              PersistenceStartupStage.preferences,
            )
          : PersistenceStartupStageStatus.failure(
              PersistenceStartupStage.preferences,
              migrationIssue,
            );
    } on Object catch (error) {
      // 偏好加载异常时保留内存回退并记录失败状态。
      statuses[PersistenceStartupStage.preferences] =
          PersistenceStartupStageStatus.failure(
            PersistenceStartupStage.preferences,
            error,
          );
    }

    FileApiAssetRepository? legacyAssets;
    ApiAssetRepository assets = InMemoryApiAssetRepository(
      collections: const [],
    );
    // 第二阶段：加载旧版文件资产，仅作为 Isar 迁移来源。
    try {
      legacyAssets = await loadLegacyAssets();
    } on Object catch (error) {
      // 旧资产不可用时记入 workspace 阶段，并跳过后续工作区打开。
      statuses[PersistenceStartupStage.workspace] =
          PersistenceStartupStageStatus.failure(
            PersistenceStartupStage.workspace,
            error,
          );
    }

    IsarWorkspace? workspace;
    MockServerRepository mockServerRepository = InMemoryMockServerRepository();
    UserNoticeRepository userNoticeRepository = InMemoryUserNoticeRepository();
    // 第三阶段：旧资产可用时才打开 Isar 工作区并迁移资产。
    if (!statuses.containsKey(PersistenceStartupStage.workspace)) {
      try {
        workspace = await openWorkspace();
        assets = await loadIsarAssets(workspace, legacyAssets);
        mockServerRepository = IsarMockServerRepository(workspace);
        userNoticeRepository = IsarUserNoticeRepository(workspace);
        statuses[PersistenceStartupStage.workspace] =
            const PersistenceStartupStageStatus.success(
              PersistenceStartupStage.workspace,
            );
      } on Object catch (error) {
        // 工作区打开失败时关闭已打开的连接并使用内存仓库。旧文件保持
        // 不变，恢复提示可引导用户重试迁移，避免恢复到已废弃的可写后端。
        await workspace?.close();
        workspace = null;
        statuses[PersistenceStartupStage.workspace] =
            PersistenceStartupStageStatus.failure(
              PersistenceStartupStage.workspace,
              error,
            );
      }
    }

    // 第四阶段：优先从 Isar 加载环境，数据库不可用时保留文件回退。
    EnvironmentStore environments;
    try {
      environments = workspace == null
          ? await loadEnvironmentStore()
          : await loadIsarEnvironmentStore(workspace);
      statuses[PersistenceStartupStage.environments] =
          const PersistenceStartupStageStatus.success(
            PersistenceStartupStage.environments,
          );
    } on Object catch (error) {
      // 环境也统一走注入的内存回退，避免故障时恢复旧 JSON 写入路径。
      environments = await loadEnvironmentStore();
      statuses[PersistenceStartupStage.environments] =
          PersistenceStartupStageStatus.failure(
            PersistenceStartupStage.environments,
            error,
          );
    }

    return DesktopPersistenceStartupResult(
      workspaceDependencies: WorkspaceDependencies(
        preferenceStore: preferences,
        assetRepository: assets,
        environmentStore: environments,
        mockServerRepository: mockServerRepository,
        userNoticeRepository: userNoticeRepository,
        demoCollection: DemoExampleCatalog.collection,
      ),
      stageStatuses: Map.unmodifiable(statuses),
      workspace: workspace,
    );
  }
}

/// 为恢复提示提供状态与重试。重试会替换整个启动组合，避免旧后端读取半迁移数据。
class DesktopPersistenceStartupController extends ChangeNotifier
    implements WorkspaceStartupRecovery {
  /// 私有构造：仅通过 [start] 创建。
  DesktopPersistenceStartupController._(this._startup, this._result);

  /// 运行一次启动组合并返回对应的控制器。
  static Future<DesktopPersistenceStartupController> start(
    DesktopPersistenceStartup startup,
  ) async => DesktopPersistenceStartupController._(
    startup,
    await startup.initialize(),
  );

  /// 底层启动组合（供重试复用）。
  final DesktopPersistenceStartup _startup;

  /// 最近一次启动的结果。
  DesktopPersistenceStartupResult _result;

  /// 是否正在进行重试。
  bool _isRetrying = false;

  /// 最近一次启动的结果。
  DesktopPersistenceStartupResult get result => _result;

  /// 当前是否处于重试中。
  @override
  bool get isRetrying => _isRetrying;

  /// 最近一次启动是否仍有失败阶段需要恢复。
  @override
  bool get requiresRecovery => _result.requiresRecovery;

  /// 重新执行整个启动组合；重试期间忽略重复调用并通知监听者。
  @override
  Future<void> retry() async {
    if (_isRetrying) return;
    _isRetrying = true;
    notifyListeners();
    // 失败启动不会保留 Isar 连接；若其它阶段失败但数据库已打开，先关闭它，
    // 再重新执行完整依赖序列，避免新的导入与旧连接并行。
    await _result.dispose();
    _result = await _startup.initialize();
    _isRetrying = false;
    notifyListeners();
  }

  @override
  /// 释放当前启动结果。
  void dispose() {
    _result.dispose();
    super.dispose();
  }
}
