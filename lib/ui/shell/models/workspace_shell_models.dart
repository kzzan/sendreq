import 'package:sendreq/domain/api_assets/api_asset_models.dart';

/// 工作区横向布局的固定栏宽度。
///
/// 所有主导航后的第二栏共享同一宽度，避免在不同工作区切换时产生横向跳动。
abstract final class WorkspacePaneWidths {
  /// 环境工作区定义的第二栏标准宽度。
  static const double secondary = 286;
}

/// 全局动作类型。
enum WorkspaceActionType {
  /// 发送。
  send,
}

/// 全局动作的触发来源。
enum WorkspaceActionSource {
  /// 直接页面操作。
  toolbar,

  /// 键盘快捷键。
  keyboard,
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
    required this.canSend,
    required this.sendUnavailableReason,
  });

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

/// Requests 内的协议工作视图，只改变资源可见投影和新建默认类型。
enum RequestWorkingView {
  all,
  rest,
  webSocket,
  grpc;

  ApiRequestProtocol? get protocol => switch (this) {
    RequestWorkingView.all => null,
    RequestWorkingView.rest => ApiRequestProtocol.http,
    RequestWorkingView.webSocket => ApiRequestProtocol.webSocket,
    RequestWorkingView.grpc => ApiRequestProtocol.grpc,
  };
}
