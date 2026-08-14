import 'package:flutter/material.dart';

import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/l10n/workspace_localizations.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/ui/shell/application/workspace_window_controls.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/ui/shell/models/workspace_shell_models.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/features/requests/environment/environment_context_control.dart';

/// 工作区顶部工具栏：展示当前上下文、环境、通知与桌面窗口控制。
class TopBar extends StatelessWidget {
  /// 构造顶部工具栏。
  const TopBar({
    super.key,
    required this.viewModel,
    required this.windowControls,
    required this.onOpenNotifications,
    this.compact = false,
  });

  /// 工作区视图模型，用于读取当前区块、环境等状态。
  final WorkspaceViewModel viewModel;

  /// 平台层注入的窗口控制端口。
  final WorkspaceWindowControls windowControls;

  /// 打开独立的持久化通知中心。
  final VoidCallback onOpenNotifications;

  /// 紧凑模式：收紧上下文标签，但不隐藏 Environment 语义。
  final bool compact;

  /// 构建工具栏：上下文标题、环境标识、通知与窗口操作按钮。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: WorkspaceLayoutMetrics.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.chakra.bgPanel,
        // 底部描边用于分隔工具栏与主体内容
        border: Border(bottom: BorderSide(color: context.chakra.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 极窄视口保留全部命令，隐藏可从导航得知的上下文标题。
          final iconOnlyChrome = compact && constraints.maxWidth < 340;
          return Row(
            children: [
              if (!iconOnlyChrome)
                _WorkspaceContext(
                  section: viewModel.activeSection == WorkspaceSection.requests
                      ? '${l10n.requests} · ${_requestViewLabel(l10n, viewModel.requestWorkingView)}'
                      : viewModel.activeSection.localizedLabel(l10n),
                ),
              if (viewModel.activeSection == WorkspaceSection.requests) ...[
                const SizedBox(width: 10),
                EnvironmentContextControl(
                  environments: viewModel.environments,
                  activeEnvironmentId: viewModel.activeEnvironment.id,
                  onEnvironmentSelected: viewModel.selectEnvironment,
                  onManage: viewModel.openEnvironmentManager,
                  hasUnsavedChanges: viewModel.hasEnvironmentChanges,
                  compact: compact,
                ),
              ],
              const Spacer(),
              _NotificationButton(
                count: viewModel.notices.length,
                onPressed: onOpenNotifications,
              ),
              const SizedBox(width: 6),
              // 桌面窗口控制：最小化 / 关闭。
              DenseIconButton(
                icon: Icons.minimize,
                tooltip: l10n.minimizeWindow,
                onPressed: windowControls.minimize,
              ),
              DenseIconButton(
                icon: Icons.close,
                tooltip: l10n.closeWindow,
                onPressed: windowControls.close,
              ),
            ],
          );
        },
      ),
    );
  }
}

String _requestViewLabel(AppLocalizations l10n, RequestWorkingView view) =>
    switch (view) {
      RequestWorkingView.all => l10n.allRequests,
      RequestWorkingView.rest => l10n.restRequests,
      RequestWorkingView.webSocket => l10n.webSocketRequests,
      RequestWorkingView.grpc => l10n.grpcRequests,
    };

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: count > 0,
    label: Text('$count'),
    child: DenseIconButton(
      icon: Icons.notifications_none_outlined,
      tooltip: count == 0
          ? AppLocalizations.of(context).notifications
          : AppLocalizations.of(context).notificationsNeedAttention(count),
      onPressed: onPressed,
    ),
  );
}

// 工作区上下文标题：当前区块的直接标识。
class _WorkspaceContext extends StatelessWidget {
  /// 构造工作区上下文标题。
  const _WorkspaceContext({required this.section});

  /// 当前工作区区块的名称文本。
  final String section;

  /// 构建标题：避免重复的系统标签，让当前工作区成为唯一主信息。
  @override
  Widget build(BuildContext context) =>
      Text(section, style: Theme.of(context).textTheme.titleMedium);
}
