/// Workspace 顶栏所需的最小窗口控制端口。
///
/// 平台层负责实现最小化和关闭；Workspace 不直接依赖窗口插件或桌面会话逻辑。
abstract interface class WorkspaceWindowControls {
  /// 最小化当前窗口。
  Future<void> minimize();

  /// 关闭当前窗口。
  Future<void> close();
}

/// 供预览和独立 Widget 测试使用的无操作窗口控制。
class NoopWorkspaceWindowControls implements WorkspaceWindowControls {
  /// 创建无操作窗口控制实例。
  const NoopWorkspaceWindowControls();

  @override
  Future<void> close() async {}

  @override
  Future<void> minimize() async {}
}
