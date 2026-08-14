import 'package:flutter/material.dart';

import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/ui/features/requests/collection/widgets/collection_tree_header.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';

/// 文件夹节点行：负责展示文件夹并上抛交互，
/// 树的展开/收起等操作逻辑由调用方统一处理。
/// 展示文件夹节点，并将树的所有操作上抛给调用方统一处理。
class CollectionFolderRow extends StatelessWidget {
  /// 构造文件夹节点行，并绑定单击/右键/长按回调。
  const CollectionFolderRow({
    super.key,
    required this.folder,
    required this.onTap,
    required this.onSecondaryTapDown,
    required this.onLongPressStart,
    required this.onMenuRequested,
    this.expanded,
  });

  /// 当前渲染的文件夹资源。
  final FolderResource folder;

  /// 单击文件夹时的回调（通常用于展开/收起该文件夹）。
  final VoidCallback onTap;

  /// 右键按下时的回调，用于弹出文件夹上下文菜单。
  final GestureTapDownCallback onSecondaryTapDown;

  /// 长按开始时的回调，移动端等效于右键菜单入口。
  final GestureLongPressStartCallback onLongPressStart;

  /// 可见操作按钮请求打开文件夹菜单的位置。
  final ValueChanged<Offset> onMenuRequested;

  /// 搜索期间可临时显示为展开态，不改变文件夹持久状态。
  final bool? expanded;

  /// 构建文件夹节点行：箭头、文件夹图标、名称与请求计数。
  @override
  Widget build(BuildContext context) {
    final isExpanded = expanded ?? folder.isExpanded;
    return GestureDetector(
      key: ValueKey('collection-folder-${folder.id}'),
      onSecondaryTapDown: onSecondaryTapDown,
      onLongPressStart: onLongPressStart,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Material(
          color: context.chakra.transparent,
          child: InkWell(
            borderRadius: ChakraRadii.control,
            onTap: onTap,
            child: Ink(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                // 左侧导轨说明层级，无需再以卡片区分节点。
                border: Border(
                  left: BorderSide(color: context.chakra.border, width: 1),
                ),
                borderRadius: ChakraRadii.control,
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
                    Icons.folder_outlined,
                    size: 16,
                    color: context.chakra.fgMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      folder.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TreeNodeCount(value: folder.requests.length),
                  TreeNodeMenuButton(
                    key: ValueKey('folder-menu-${folder.id}'),
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

/// 请求叶子节点行：展示请求方法、名称，
/// 并保留选中态（高亮）与未保存修改（警示点）反馈。
/// 展示请求叶子节点，同时保留选中态与未保存修改反馈。
class CollectionRequestRow extends StatelessWidget {
  /// 构造请求叶子节点行，并绑定选中态与单击/右键/长按回调。
  const CollectionRequestRow({
    super.key,
    required this.request,
    required this.selected,
    required this.onTap,
    required this.onSecondaryTapDown,
    required this.onLongPressStart,
    required this.onMenuRequested,
  });

  /// 当前渲染的请求资源。
  final RequestResource request;

  /// 是否处于选中（激活）状态，选中时高亮显示。
  final bool selected;

  /// 单击请求时的回调（通常用于激活该请求）。
  final VoidCallback onTap;

  /// 右键按下时的回调，用于弹出请求上下文菜单。
  final GestureTapDownCallback onSecondaryTapDown;

  /// 长按开始时的回调，移动端等效于右键菜单入口。
  final GestureLongPressStartCallback onLongPressStart;

  /// 可见操作按钮请求打开请求菜单的位置。
  final ValueChanged<Offset> onMenuRequested;

  /// 构建请求叶子节点行：方法徽标、名称与选中/未保存反馈。
  @override
  Widget build(BuildContext context) => GestureDetector(
    onSecondaryTapDown: onSecondaryTapDown,
    onLongPressStart: onLongPressStart,
    child: Padding(
      // 固定层级缩进和行高，避免选中与协议切换造成位置抖动。
      padding: const EdgeInsets.only(left: 26, bottom: 3),
      child: Material(
        color: context.chakra.transparent,
        child: InkWell(
          borderRadius: ChakraRadii.control,
          onTap: onTap,
          child: Ink(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            // 选中态只使用主色导轨与底色，避免整行描边显得臃肿。
            decoration: BoxDecoration(
              color: selected
                  ? context.chakra.bgEmphasized
                  : context.chakra.transparent,
              border: Border(
                left: BorderSide(
                  color: selected
                      ? context.chakra.colorPaletteFg
                      : context.chakra.transparent,
                  width: 2,
                ),
              ),
              borderRadius: ChakraRadii.control,
            ),
            child: Row(
              children: [
                RequestKindPill(
                  key: Key('collection-request-kind-${request.id}'),
                  protocol: request.protocol,
                  method: request.method,
                  width: 70,
                  height: 18,
                  fontSize: 9.5,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    request.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected
                          ? context.chakra.fg
                          : context.chakra.fgMuted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                // 有未保存修改时，在行尾显示警示小圆点
                if (request.isDirty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.circle,
                      size: 7,
                      color: context.chakra.warning,
                    ),
                  ),
                TreeNodeMenuButton(
                  key: ValueKey('request-menu-${request.id}'),
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
