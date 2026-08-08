import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/workspace_models.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/workspace_localizations.dart';
import '../application/workspace_window_controls.dart';
import '../models/workspace_shell_models.dart';
import '../view_models/workspace_view_model.dart';
import '../../../core/widgets/dense_controls.dart';

/// 工作区顶部工具栏：展示当前上下文与环境、命令面板搜索入口，
/// 并提供保存、文档与桌面窗口控制等全局操作。
class TopBar extends StatelessWidget {
  /// 构造顶部工具栏。
  const TopBar({
    super.key,
    required this.viewModel,
    required this.onAction,
    required this.windowControls,
    this.compact = false,
  });

  /// 工作区视图模型，用于读取当前区块、环境等状态。
  final WorkspaceViewModel viewModel;

  /// 全局动作回调（打开命令面板、保存等），由外部统一分发处理。
  final ValueChanged<WorkspaceGlobalAction> onAction;

  /// 平台层注入的窗口控制端口。
  final WorkspaceWindowControls windowControls;

  /// 紧凑模式：隐藏环境信息与搜索框，仅保留图标按钮（窄窗口用）。
  final bool compact;

  /// 构建工具栏：上下文标题、环境标识、搜索入口与全局操作按钮。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        // 底部描边用于分隔工具栏与主体内容
        border: Border(bottom: BorderSide(color: AppColors.outline)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 极窄视口保留全部命令，隐藏可从导航得知的上下文标题。
          final iconOnlyChrome = compact && constraints.maxWidth < 340;
          return Row(
            children: [
              if (!iconOnlyChrome)
                _WorkspaceContext(
                  section: viewModel.activeSection.localizedLabel(l10n),
                ),
              // 非紧凑模式下额外展示当前环境信息。
              if (!compact) ...[
                const SizedBox(width: 16),
                _EnvironmentChip(name: viewModel.activeEnvironment.name),
              ],
              const Spacer(),
              // 宽窗口用仿搜索框承载命令面板入口，窄窗口退化为搜索图标按钮。
              if (!compact)
                _SearchBox(
                  placeholder: viewModel.activeSection.localizedCommandHint(
                    l10n,
                  ),
                  onTap: () => _dispatch(WorkspaceActionType.openCommand),
                )
              else
                DenseIconButton(
                  icon: Icons.search,
                  tooltip: l10n.openCommandPalette,
                  onPressed: () => _dispatch(WorkspaceActionType.openCommand),
                ),
              const SizedBox(width: 8),
              DenseIconButton(
                icon: Icons.article_outlined,
                tooltip: l10n.openDocumentation,
                onPressed: () =>
                    viewModel.selectSection(WorkspaceSection.documentation),
              ),
              DenseIconButton(
                icon: Icons.save_outlined,
                tooltip: viewModel.actionAvailability.canSave
                    ? l10n.saveActiveResource
                    : l10n.noSaveableChanges,
                onPressed: () => _dispatch(WorkspaceActionType.save),
              ),
              const SizedBox(width: 8),
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

  // 将工具栏动作包装为"来源=工具栏"的全局动作，转发给外部处理器。
  void _dispatch(WorkspaceActionType type) {
    onAction(
      WorkspaceGlobalAction(type: type, source: WorkspaceActionSource.toolbar),
    );
  }
}

// 工作区上下文标题：上方小号 "WORKSPACE" 标签，下方当前区块名称。
class _WorkspaceContext extends StatelessWidget {
  /// 构造工作区上下文标题。
  const _WorkspaceContext({required this.section});

  /// 当前工作区区块的名称文本。
  final String section;

  /// 构建标题：上方小号 WORKSPACE 标签 + 下方区块名称。
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoText(
          AppLocalizations.of(context).workspace.toUpperCase(),
          color: AppColors.textFaint,
          size: 9,
        ),
        Text(section, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

// 当前环境标识：绿色胶囊样式，提示当前生效的环境名称。
class _EnvironmentChip extends StatelessWidget {
  /// 构造环境标识。
  const _EnvironmentChip({required this.name});

  /// 当前环境名称。
  final String name;

  /// 构建绿色胶囊样式的环境标识。
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppLocalizations.of(context).activeEnvironment,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.10),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            MonoText(name, color: AppColors.success, size: 11),
          ],
        ),
      ),
    );
  }
}

// 仿搜索框：仅作命令面板入口展示，点击即触发 onTap，不承载真实输入。
class _SearchBox extends StatelessWidget {
  /// 构造仿搜索框。
  const _SearchBox({required this.placeholder, required this.onTap});

  /// 占位提示文本，随当前区块的命令提示切换。
  final String placeholder;

  /// 点击搜索框时的回调（通常用于打开命令面板）。
  final VoidCallback onTap;

  /// 构建仿搜索框：搜索图标 + 占位文本 + 快捷键徽标。
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      hoverColor: AppColors.surfaceHighest,
      focusColor: AppColors.surfaceHighest,
      splashColor: AppColors.primary.withValues(alpha: 0.12),
      onTap: onTap,
      child: Container(
        width: 280,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          border: Border.all(color: AppColors.outline),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 16, color: AppColors.textFaint),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                placeholder,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textFaint, fontSize: 12),
              ),
            ),
            // 右侧快捷键徽标，提示用户可用 Ctrl K 打开命令面板
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outline),
                borderRadius: BorderRadius.circular(3),
              ),
              child: MonoText('Ctrl K', color: AppColors.textFaint, size: 10),
            ),
          ],
        ),
      ),
    );
  }
}
