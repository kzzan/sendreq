/// 工作区横向布局的固定栏宽度。
///
/// 所有主导航后的第二栏共享同一宽度，避免在不同工作区切换时产生横向跳动。
abstract final class WorkspacePaneWidths {
  /// 环境工作区定义的第二栏标准宽度。
  static const double secondary = 286;
}

/// 工作区资源类型，用于侧栏与命令面板导航。
enum WorkspaceResourceType {
  /// 仪表盘。
  dashboard,

  /// 请求集合。
  collection,

  /// 单个请求。
  request,

  /// 环境。
  environment,

  /// Mock 服务器。
  mockServer,

  /// 文档。
  documentation,

  /// 设置。
  settings,

  /// 历史。
  history,
}

/// 工作区资源引用，用于跨区域导航（如命令面板）。
class WorkspaceResourceRef {
  /// 构造资源引用。
  const WorkspaceResourceRef({
    required this.type,
    required this.workspaceId,
    required this.id,
    required this.title,
  });

  /// 资源类型。
  final WorkspaceResourceType type;

  /// 所属工作区 id。
  final String workspaceId;

  /// 资源 id。
  final String id;

  /// 展示标题。
  final String title;

  /// 是否为请求资源。
  bool get isRequest => type == WorkspaceResourceType.request;
}

/// 全局动作类型。
enum WorkspaceActionType {
  /// 保存。
  save,

  /// 发送。
  send,

  /// 打开命令面板。
  openCommand,
}

/// 全局动作的触发来源。
enum WorkspaceActionSource {
  /// 工具栏。
  toolbar,

  /// 快捷键。
  shortcut,

  /// 命令面板。
  commandPalette,
}

/// 一次全局动作事件，统一各触发来源发出的请求。
class WorkspaceGlobalAction {
  /// 构造一次全局动作，未指定时间时取当前时间。
  WorkspaceGlobalAction({
    required this.type,
    required this.source,
    DateTime? requestedAt,
  }) : requestedAt = requestedAt ?? DateTime.now();

  /// 动作类型。
  final WorkspaceActionType type;

  /// 触发来源。
  final WorkspaceActionSource source;

  /// 请求时间。
  final DateTime requestedAt;
}

/// 全局动作当前是否可用的状态。
class WorkspaceActionAvailability {
  /// 构造全局动作可用性状态。
  const WorkspaceActionAvailability({
    required this.canSave,
    required this.canSend,
    required this.sendUnavailableReason,
  });

  /// 是否可保存。
  final bool canSave;

  /// 是否可发送。
  final bool canSend;

  /// 不可发送的原因说明。
  final String? sendUnavailableReason;
}

/// 窄窗口模式下可见的侧栏面板。
enum NarrowWorkspacePanel {
  /// 集合列表。
  collections,

  /// 请求编辑区。
  request,

  /// 响应区。
  response,
}
