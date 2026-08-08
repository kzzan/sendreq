import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/workspace_models.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/workspace_localizations.dart';
import '../view_models/workspace_view_model.dart';

/// 左侧导航栏：固定为图标导航，保持工作区内容的可用宽度。
class SideNav extends StatelessWidget {
  /// 构造左侧导航栏。
  const SideNav({super.key, required this.viewModel});

  /// 工作区视图模型，用于读取当前激活区块并切换区块。
  final WorkspaceViewModel viewModel;

  /// 构建导航栏：品牌区 + 各工作区区块的图标导航列表。
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        // 右侧描边用于分隔导航栏与主体内容
        border: Border(right: BorderSide(color: AppColors.outline)),
      ),
      child: Column(
        children: [
          const _BrandBlock(),
          Divider(height: 1, color: AppColors.outline),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                // 文档区块不在此处展示，由顶部工具栏进入
                for (final section in WorkspaceSection.values.where(
                  (section) => section != WorkspaceSection.documentation,
                ))
                  _NavButton(
                    section: section,
                    selected: section == viewModel.activeSection,
                    onTap: () => viewModel.selectSection(section),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 品牌区只保留紧凑品牌标识，不提供侧栏尺寸控制。
class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  /// 构建品牌区：固定高度并居中放置品牌标识。
  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 66, child: const Center(child: _BrandMark()));
  }
}

// 品牌图标与 Windows 安装包使用同一套 sendreq 发送请求标记。
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  /// 构建品牌图标方块。
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'sendreq',
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          'assets/branding/sendreq-app-icon.png',
          filterQuality: FilterQuality.medium,
        ),
      ),
    ),
  );
}

// 导航按钮仅展示图标，并以 Tooltip 补充名称提示。
class _NavButton extends StatelessWidget {
  /// 构造导航按钮。
  const _NavButton({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  /// 按钮对应的工作区区块。
  final WorkspaceSection section;

  /// 是否当前激活区块，激活时高亮。
  final bool selected;

  /// 点击切换区块的回调。
  final VoidCallback onTap;

  /// 构建导航按钮：图标 + 选中高亮样式，并以 Tooltip 展示区块名称。
  @override
  Widget build(BuildContext context) {
    final label = section.localizedLabel(AppLocalizations.of(context));
    final icon = Icon(
      _iconFor(section),
      size: 17,
      color: selected ? AppColors.primary : AppColors.textMuted,
    );
    final button = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        hoverColor: AppColors.surfaceHigh,
        focusColor: AppColors.surfaceHigh,
        splashColor: AppColors.primary.withValues(alpha: 0.12),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceHighest : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border(
              left: BorderSide(
                width: 3,
                color: selected ? AppColors.primary : Colors.transparent,
              ),
            ),
          ),
          child: Row(
            children: [Expanded(child: Center(child: icon))],
          ),
        ),
      ),
    );
    return Tooltip(message: label, child: button);
  }

  // 为每个区块映射对应的导航图标
  IconData _iconFor(WorkspaceSection section) {
    switch (section) {
      case WorkspaceSection.dashboard:
        return Icons.dashboard_outlined;
      case WorkspaceSection.collections:
        return Icons.folder_open_outlined;
      case WorkspaceSection.history:
        return Icons.history;
      case WorkspaceSection.environments:
        return Icons.layers_outlined;
      case WorkspaceSection.mockServers:
        return Icons.dns_outlined;
      case WorkspaceSection.documentation:
        return Icons.article_outlined;
      case WorkspaceSection.settings:
        return Icons.settings_outlined;
    }
  }
}
