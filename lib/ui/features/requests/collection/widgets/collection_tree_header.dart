import 'package:flutter/material.dart';

import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';

/// 集合树节点头部：仅负责集合的展示与展开/收起态，
/// 树的各类操作回调由调用方传入，因此本组件不直接耦合集合的增删改逻辑。
/// 渲染集合节点，不直接耦合集合的增删改逻辑。
class CollectionTreeHeader extends StatelessWidget {
  /// 构造集合节点头部，并绑定单击/右键/长按回调。
  const CollectionTreeHeader({
    super.key,
    required this.collection,
    required this.onTap,
    required this.onSecondaryTapDown,
    required this.onLongPressStart,
    required this.onMenuRequested,
    this.expanded,
  });

  /// 当前渲染的集合资源。
  final CollectionResource collection;

  /// 单击集合时的回调（通常用于展开/收起该集合）。
  final VoidCallback onTap;

  /// 右键按下时的回调，用于弹出集合上下文菜单。
  final GestureTapDownCallback onSecondaryTapDown;

  /// 长按开始时的回调，移动端等效于右键菜单入口。
  final GestureLongPressStartCallback onLongPressStart;

  /// 可见的操作按钮入口，与右键菜单共享同一套命令。
  final ValueChanged<Offset> onMenuRequested;

  /// 可由搜索视图临时覆盖展开样式，不写回资源本身的展开状态。
  final bool? expanded;

  /// 构建集合节点头部：箭头、文件夹图标、名称与请求计数。
  @override
  Widget build(BuildContext context) {
    final isExpanded = expanded ?? collection.isExpanded;
    return GestureDetector(
      onSecondaryTapDown: onSecondaryTapDown,
      onLongPressStart: onLongPressStart,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: context.chakra.transparent,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: context.chakra.bgMuted,
                border: Border(
                  left: BorderSide(
                    color: context.chakra.borderEmphasized,
                    width: 2,
                  ),
                  bottom: BorderSide(color: context.chakra.border),
                ),
              ),
              child: Row(
                children: [
                  // 展开态显示向下箭头，收起态显示向右箭头
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 16,
                    color: context.chakra.fgSubtle,
                  ),
                  Icon(
                    Icons.folder_special_outlined,
                    size: 16,
                    color: context.chakra.fgMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      collection.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TreeNodeCount(value: collection.requestCount),
                  TreeNodeMenuButton(
                    key: ValueKey('collection-menu-${collection.id}'),
                    onMenuRequested: onMenuRequested,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 为树节点提供可发现的操作入口，并把按钮位置转换为上下文菜单锚点。
class TreeNodeMenuButton extends StatelessWidget {
  const TreeNodeMenuButton({super.key, required this.onMenuRequested});

  final ValueChanged<Offset> onMenuRequested;

  @override
  Widget build(BuildContext context) => DenseIconButton(
    icon: Icons.more_horiz,
    tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
    size: 24,
    onPressed: () {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      onMenuRequested(box.localToGlobal(Offset(0, box.size.height)));
    },
  );
}

/// 集合/文件夹的计数徽标：固定最小宽度以保持数值变化时布局稳定。
/// 数值变化时保持树节点徽标的视觉稳定。
class TreeNodeCount extends StatelessWidget {
  /// 构造节点计数徽标。
  const TreeNodeCount({super.key, required this.value});

  /// 要显示的节点数量（如集合内的请求总数）。
  final int value;

  /// 构建计数徽标。
  @override
  Widget build(BuildContext context) => SizedBox(
    // 固定宽度，避免数字位数变化推动名称列。
    width: 24,
    child: Align(
      alignment: Alignment.centerRight,
      child: MonoText('$value', color: context.chakra.fgSubtle, size: 10),
    ),
  );
}
