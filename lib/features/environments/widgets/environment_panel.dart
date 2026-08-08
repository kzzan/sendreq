import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/form_control_metrics.dart';
import '../../../domain/environments/environment_models.dart';
import '../../../domain/authentication/request_authentication.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/workspace_message_localizations.dart';
import '../../../l10n/workspace_localizations.dart';
import '../../workspace/models/workspace_shell_models.dart';
import '../../workspace/view_models/workspace_view_model.dart';
import '../../../core/widgets/dense_controls.dart';

part 'environment_panel_navigation.dart';
part 'environment_panel_variables.dart';

/// 环境变量面板：查看/编辑环境变量，支持切换当前环境并保存变更。
class EnvironmentPanel extends StatelessWidget {
  /// 构造环境变量面板。
  const EnvironmentPanel({super.key, required this.viewModel});

  /// 工作区视图模型，提供环境变量数据与操作。
  final WorkspaceViewModel viewModel;

  /// 构建环境面板：页头 + 环境导航与变量工作区。
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EnvironmentHeader(viewModel: viewModel),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 840) {
                  return Column(
                    children: [
                      SizedBox(
                        height: 230,
                        child: _EnvironmentNavigation(viewModel: viewModel),
                      ),
                      Expanded(
                        child: _VariablesWorkspace(viewModel: viewModel),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    SizedBox(
                      width: WorkspacePaneWidths.secondary,
                      child: _EnvironmentNavigation(viewModel: viewModel),
                    ),
                    Expanded(child: _VariablesWorkspace(viewModel: viewModel)),
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

/// 环境页标题和唯一全局主动作：保存未持久化的变量修改。
class _EnvironmentHeader extends StatelessWidget {
  /// 构造环境页头部。
  const _EnvironmentHeader({required this.viewModel});

  /// 工作区视图模型，提供环境状态与保存能力。
  final WorkspaceViewModel viewModel;

  /// 构建环境页头部：标题、当前环境与保存按钮。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.fromLTRB(18, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outline)),
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
                      color: AppColors.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.tune_outlined,
                      size: 15,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    l10n.environments,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    MonoText(
                      '${l10n.currentEnvironment}: ${viewModel.activeEnvironment.name}',
                      color: AppColors.textMuted,
                      size: 10,
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
                  onPressed: viewModel.returnFromEnvironment,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: Text(l10n.returnToRequest),
                ),
                const SizedBox(width: 6),
              ],
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(122, 34),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  disabledBackgroundColor: AppColors.surfaceHigh,
                  disabledForegroundColor: AppColors.textFaint,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                onPressed: viewModel.hasEnvironmentChanges
                    ? () async {
                        await viewModel.saveEnvironmentChanges();
                        if (!context.mounted) return;
                        final message = viewModel.lastActionMessage.localized(
                          AppLocalizations.of(context),
                        );
                        if (message != null) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(message)));
                        }
                      }
                    : null,
                icon: Icon(
                  viewModel.hasEnvironmentChanges
                      ? Icons.save_outlined
                      : Icons.check_circle_outline,
                  size: 16,
                ),
                label: Text(
                  viewModel.hasEnvironmentChanges
                      ? l10n.saveChanges
                      : l10n.noChanges,
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }
}

/// 左侧环境资源列表，提供新建、切换和每个环境的重命名/删除入口。
