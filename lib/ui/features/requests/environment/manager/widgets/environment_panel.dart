import 'package:flutter/material.dart';

import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/features/requests/environment/manager/widgets/environment_panel_navigation.dart';
import 'package:sendreq/ui/features/requests/environment/manager/widgets/environment_panel_variables.dart';
import 'package:sendreq/ui/shell/models/workspace_shell_models.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 环境变量面板：查看/编辑环境变量，支持切换当前环境并保存变更。
class EnvironmentPanel extends StatelessWidget {
  /// 构造环境变量面板。
  const EnvironmentPanel({
    super.key,
    required this.viewModel,
    this.onCloseRequested,
  });

  /// 工作区视图模型，提供环境变量数据与操作。
  final WorkspaceViewModel viewModel;

  /// 请求关闭局部管理层；由 Workspace 统一处理未应用配置。
  final VoidCallback? onCloseRequested;

  /// 构建环境面板：页头 + 环境导航与变量工作区。
  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.chakra.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EnvironmentHeader(
            viewModel: viewModel,
            onCloseRequested: onCloseRequested,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Environment drawers need the full width for the variable
                // table. Keep navigation above the editor until both panes
                // can remain comfortably usable side by side.
                if (constraints.maxWidth < 960) {
                  return Column(
                    children: [
                      SizedBox(
                        height: 230,
                        child: EnvironmentNavigation(viewModel: viewModel),
                      ),
                      Expanded(
                        child: EnvironmentVariablesWorkspace(
                          viewModel: viewModel,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    SizedBox(
                      width: WorkspacePaneWidths.secondary,
                      child: EnvironmentNavigation(viewModel: viewModel),
                    ),
                    Expanded(
                      child: EnvironmentVariablesWorkspace(
                        viewModel: viewModel,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 环境页标题；配置提交动作位于变量编辑工作区内。
class _EnvironmentHeader extends StatelessWidget {
  /// 构造环境页头部。
  const _EnvironmentHeader({
    required this.viewModel,
    required this.onCloseRequested,
  });

  /// 工作区视图模型，提供环境状态与保存能力。
  final WorkspaceViewModel viewModel;

  final VoidCallback? onCloseRequested;

  /// 构建环境页头部：标题、当前环境与保存按钮。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 56),
      padding: WorkspaceLayoutMetrics.panelPadding,
      decoration: BoxDecoration(
        color: context.chakra.bgPanel,
        border: Border(bottom: BorderSide(color: context.chakra.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 25,
                    height: 25,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.chakra.colorPaletteSolid.withValues(
                        alpha: 0.35,
                      ),
                      borderRadius: ChakraRadii.control,
                    ),
                    child: Icon(
                      Icons.tune_outlined,
                      size: 15,
                      color: context.chakra.colorPaletteFg,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    l10n.environments,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.chakra.fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: context.chakra.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: MonoText(
                        '${l10n.currentEnvironment}: ${viewModel.activeEnvironment.name}',
                        color: context.chakra.fgMuted,
                        size: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (viewModel.canReturnFromEnvironment) ...[
                OutlinedButton.icon(
                  onPressed:
                      onCloseRequested ?? viewModel.returnFromEnvironment,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: Text(l10n.returnToRequest),
                ),
                const SizedBox(width: 6),
              ],
            ],
          );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: WorkspaceLayoutMetrics.sectionGap),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: WorkspaceLayoutMetrics.sectionGap),
              actions,
            ],
          );
        },
      ),
    );
  }
}

/// 左侧环境资源列表，提供新建、切换和每个环境的重命名/删除入口。
