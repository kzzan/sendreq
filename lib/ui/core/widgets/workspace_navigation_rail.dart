import 'package:flutter/material.dart';

import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';

/// 资源型工作区共用的左侧导航表面。
class WorkspaceNavigationRail extends StatelessWidget {
  const WorkspaceNavigationRail({
    super.key,
    required this.child,
    this.showTrailingDivider = true,
  });

  final Widget child;
  final bool showTrailingDivider;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.chakra.bgSubtle,
      border: showTrailingDivider
          ? Border(right: BorderSide(color: context.chakra.border))
          : null,
    ),
    child: child,
  );
}

/// 资源轨道的标题与可选工具区，使用固定的高密度空间基线。
class NavigationRailHeader extends StatelessWidget {
  const NavigationRailHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 56),
    padding: WorkspaceLayoutMetrics.panelPadding,
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: context.chakra.border)),
    ),
    child: Row(
      children: [
        ?leading,
        if (leading != null) const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (subtitle case final subtitle? when subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.chakra.fgSubtle,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// 共用的可选择资源行：选择态只使用轨道和低对比表面，不改变内容几何。
class NavigationRailItem extends StatefulWidget {
  const NavigationRailItem({
    super.key,
    required this.child,
    required this.selected,
    this.onTap,
    this.height = WorkspaceLayoutMetrics.resourceRowHeight,
  });

  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final double height;

  @override
  State<NavigationRailItem> createState() => _NavigationRailItemState();
}

class _NavigationRailItemState extends State<NavigationRailItem> {
  var _focused = false;

  @override
  Widget build(BuildContext context) => Material(
    color: context.chakra.transparent,
    child: SizedBox(
      height: widget.height,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (focused) => setState(() => _focused = focused),
        hoverColor: context.chakra.bgEmphasized,
        focusColor: context.chakra.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: widget.selected
                  ? ChakraSlotRecipes.selectedNavigationItem(
                      context.chakra,
                    ).copyWith(
                      border: Border(
                        left: BorderSide(
                          color: context.chakra.colorPaletteSolid,
                          width: 3,
                        ),
                        bottom: BorderSide(color: context.chakra.border),
                      ),
                    )
                  : BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: context.chakra.border),
                      ),
                    ),
              child: widget.child,
            ),
            if (_focused)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: context.chakra.colorPaletteFocusRing,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
