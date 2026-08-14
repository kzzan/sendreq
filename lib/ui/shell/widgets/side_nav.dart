import 'package:flutter/material.dart';

import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/l10n/workspace_localizations.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/ui/shell/models/workspace_shell_models.dart';

/// 左侧导航栏：宽屏显示协议工作视图，窄屏折叠为带提示的图标栏。
class SideNav extends StatelessWidget {
  /// 构造左侧导航栏。
  const SideNav({super.key, required this.viewModel, required this.compact});

  /// 工作区视图模型，用于读取当前激活区块并切换区块。
  final WorkspaceViewModel viewModel;

  final bool compact;

  /// 构建导航栏：品牌区 + 各工作区区块的图标导航列表。
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('tool-navigation-rail'),
      width: compact
          ? WorkspaceLayoutMetrics.compactToolRailWidth
          : WorkspaceLayoutMetrics.toolRailWidth,
      decoration: BoxDecoration(
        color: context.chakra.bgSubtle,
        // 右侧描边用于分隔导航栏与主体内容
        border: Border(right: BorderSide(color: context.chakra.border)),
      ),
      child: Column(
        children: [
          _BrandBlock(compact: compact),
          Divider(height: 1, color: context.chakra.border),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  if (!compact)
                    _GroupLabel(label: AppLocalizations.of(context).requests),
                  for (final view in RequestWorkingView.values)
                    _RequestViewButton(
                      view: view,
                      compact: compact,
                      selected:
                          viewModel.activeSection ==
                              WorkspaceSection.requests &&
                          viewModel.requestWorkingView == view,
                      onTap: () => viewModel.selectRequestWorkingView(view),
                    ),
                  const SizedBox(height: 6),
                  Divider(height: 1, color: context.chakra.border),
                  const SizedBox(height: 6),
                  _NavButton(
                    section: WorkspaceSection.mock,
                    compact: compact,
                    selected: viewModel.activeSection == WorkspaceSection.mock,
                    onTap: () => viewModel.selectSection(WorkspaceSection.mock),
                  ),
                  const Spacer(),
                  _NavButton(
                    section: WorkspaceSection.settings,
                    compact: compact,
                    selected:
                        viewModel.activeSection == WorkspaceSection.settings,
                    onTap: () =>
                        viewModel.selectSection(WorkspaceSection.settings),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 品牌区只保留紧凑品牌标识，不提供侧栏尺寸控制。
class _BrandBlock extends StatelessWidget {
  const _BrandBlock({required this.compact});

  final bool compact;

  /// 构建品牌区：固定高度并居中放置品牌标识。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: WorkspaceLayoutMetrics.topBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: compact
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            const _BrandMark(),
            if (!compact) ...[
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'sendreq',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
        borderRadius: ChakraRadii.panel,
        border: Border.all(color: context.chakra.border),
      ),
      child: ClipRRect(
        borderRadius: ChakraRadii.panel,
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
    required this.compact,
    required this.selected,
    required this.onTap,
  });

  /// 按钮对应的工作区区块。
  final WorkspaceSection section;

  final bool compact;

  /// 是否当前激活区块，激活时高亮。
  final bool selected;

  /// 点击切换区块的回调。
  final VoidCallback onTap;

  /// 构建导航按钮：图标 + 选中高亮样式，并以 Tooltip 展示区块名称。
  @override
  Widget build(BuildContext context) {
    final tokens = context.chakra;
    final label = section.localizedLabel(AppLocalizations.of(context));
    final icon = Icon(
      _iconFor(section),
      size: 17,
      color: selected ? tokens.colorPaletteFg : tokens.fgMuted,
    );
    final button = Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: InkWell(
        key: ValueKey('tool-navigation-${section.name}'),
        borderRadius: ChakraRadii.control,
        hoverColor: tokens.bgEmphasized,
        focusColor: tokens.colorPaletteFocusRing.withValues(alpha: 0.16),
        splashColor: context.chakra.transparent,
        onTap: onTap,
        child: Container(
          height: WorkspaceLayoutMetrics.toolRailItemHeight,
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 10),
          decoration: selected
              ? ChakraSlotRecipes.selectedNavigationItem(
                  tokens,
                ).copyWith(borderRadius: ChakraRadii.control)
              : const BoxDecoration(borderRadius: ChakraRadii.control),
          child: Row(
            children: [
              SizedBox(
                width: compact ? 38 : 24,
                child: Center(child: icon),
              ),
              if (!compact) ...[
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? tokens.fg : tokens.fgMuted,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Tooltip(message: label, child: button);
  }

  // 为每个区块映射对应的导航图标
  IconData _iconFor(WorkspaceSection section) {
    switch (section) {
      case WorkspaceSection.requests:
        return Icons.send_outlined;
      case WorkspaceSection.mock:
        return Icons.dns_outlined;
      case WorkspaceSection.settings:
        return Icons.settings_outlined;
    }
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: context.chakra.fgSubtle,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _RequestViewButton extends StatelessWidget {
  const _RequestViewButton({
    required this.view,
    required this.compact,
    required this.selected,
    required this.onTap,
  });

  final RequestWorkingView view;
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.chakra;
    final l10n = AppLocalizations.of(context);
    final label = switch (view) {
      RequestWorkingView.all => l10n.allRequests,
      RequestWorkingView.rest => l10n.restRequests,
      RequestWorkingView.webSocket => l10n.webSocketRequests,
      RequestWorkingView.grpc => l10n.grpcRequests,
    };
    final icon = switch (view) {
      RequestWorkingView.all => Icons.list_alt_outlined,
      RequestWorkingView.rest => Icons.http_outlined,
      RequestWorkingView.webSocket => Icons.swap_horiz_rounded,
      RequestWorkingView.grpc => Icons.hub_outlined,
    };
    final button = Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        key: ValueKey('request-working-view-${view.name}'),
        borderRadius: ChakraRadii.control,
        hoverColor: tokens.bgEmphasized,
        focusColor: tokens.colorPaletteFocusRing.withValues(alpha: 0.16),
        onTap: onTap,
        child: Container(
          height: WorkspaceLayoutMetrics.requestViewItemHeight,
          padding: EdgeInsets.only(
            left: compact ? 0 : 12,
            right: compact ? 0 : 8,
          ),
          decoration: selected
              ? ChakraSlotRecipes.selectedNavigationItem(
                  tokens,
                ).copyWith(borderRadius: ChakraRadii.control)
              : const BoxDecoration(borderRadius: ChakraRadii.control),
          child: Row(
            children: [
              SizedBox(
                width: compact ? 38 : 22,
                child: Icon(
                  icon,
                  size: 16,
                  color: selected ? tokens.colorPaletteFg : tokens.fgMuted,
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? tokens.fg : tokens.fgMuted,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Tooltip(message: label, child: button);
  }
}
