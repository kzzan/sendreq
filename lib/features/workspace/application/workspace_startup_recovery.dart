import 'package:flutter/foundation.dart';

/// Workspace 在启动持久化不完整时所需的最小恢复能力。
///
/// 应用启动层负责实现此端口；Workspace 只观察状态并发起重试，不依赖具体
/// 的 Isar、文件迁移或桌面启动控制器。
abstract interface class WorkspaceStartupRecovery implements Listenable {
  /// 是否仍有启动阶段需要恢复。
  bool get requiresRecovery;

  /// 当前是否正在重试启动流程。
  bool get isRetrying;

  /// 重新执行启动恢复流程。
  Future<void> retry();
}
