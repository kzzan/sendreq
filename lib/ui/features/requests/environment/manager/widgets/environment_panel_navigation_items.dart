import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:sendreq/domain/environments/environment_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/form_control_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/widgets/workspace_navigation_rail.dart';

/// 单条环境导航项：状态点、名称、选中态与右键/更多操作入口。
class EnvironmentNavigationItem extends StatelessWidget {
  /// 构造环境导航项并绑定各交互回调。
  const EnvironmentNavigationItem({
    super.key,
    required this.environment,
    required this.selected,
    required this.active,
    required this.onSelected,
    required this.onSecondaryTapDown,
    required this.onRename,
    required this.onDelete,
    required this.canDelete,
  });

  /// 当前渲染的环境。
  final EnvironmentProfile environment;

  /// 是否为当前激活环境。
  final bool selected;

  /// 是否用于下一次请求。
  final bool active;

  /// 单击选中该环境的回调。
  final VoidCallback onSelected;

  /// 右键按下回调，用于弹出环境上下文菜单。
  final GestureTapDownCallback onSecondaryTapDown;

  /// 重命名回调。
  final VoidCallback onRename;

  /// 删除回调。
  final VoidCallback onDelete;

  /// 是否允许删除（最后一个环境不允许删除）。
  final bool canDelete;

  /// 构建环境导航项。
  @override
  Widget build(BuildContext context) {
    // production/staging 使用警示色标识，其余环境使用成功色
    final markerColor = switch (environment.id) {
      'production' => context.chakra.error,
      'staging' => context.chakra.warning,
      _ => context.chakra.success,
    };
    return Listener(
      key: ValueKey('environment-item-${environment.id}'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        // 桌面端右键按下时触发环境上下文菜单
        if (event.buttons == kSecondaryMouseButton) {
          onSecondaryTapDown(
            TapDownDetails(
              globalPosition: event.position,
              localPosition: event.localPosition,
              kind: event.kind,
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: NavigationRailItem(
          selected: selected,
          onTap: onSelected,
          height: 42,
          child: Row(
            children: [
              const SizedBox(width: 7),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  environment.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? context.chakra.fg
                        : context.chakra.fgMuted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (active)
                Container(
                  key: ValueKey('environment-active-${environment.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.chakra.colorPaletteSubtle,
                    borderRadius: ChakraRadii.pill,
                  ),
                  child: Text(
                    AppLocalizations.of(context).active,
                    style: TextStyle(
                      color: context.chakra.colorPaletteFg,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              PopupMenuButton<EnvironmentMenuAction>(
                key: ValueKey('environment-actions-${environment.id}'),
                tooltip: AppLocalizations.of(context).environmentActions,
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_horiz,
                  size: 17,
                  color: context.chakra.fgMuted,
                ),
                onSelected: (action) {
                  switch (action) {
                    case EnvironmentMenuAction.rename:
                      onRename();
                      break;
                    case EnvironmentMenuAction.delete:
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return [
                    PopupMenuItem(
                      value: EnvironmentMenuAction.rename,
                      child: Text(l10n.renameEnvironment),
                    ),
                    PopupMenuItem(
                      value: EnvironmentMenuAction.delete,
                      enabled: canDelete,
                      child: Text(
                        canDelete
                            ? l10n.deleteEnvironment
                            : l10n.lastEnvironmentRequired,
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 环境上下文菜单可执行的操作类型。
enum EnvironmentMenuAction { rename, delete }

/// 数量计数徽标：固定最小宽度的小圆角标签。
class EnvironmentCountBadge extends StatelessWidget {
  /// 构造计数徽标。
  const EnvironmentCountBadge({super.key, required this.count});

  /// 要显示的数量。
  final int count;

  /// 构建计数徽标。
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 20,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: context.chakra.bgPanel,
        borderRadius: ChakraRadii.pill,
      ),
      child: MonoText('$count', color: context.chakra.fgMuted, size: 10),
    );
  }
}

/// 弹出环境命名对话框，返回输入的名称；取消时返回 null。
Future<String?> showEnvironmentNameDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String initialName = '',
}) async {
  final l10n = AppLocalizations.of(context);
  var name = initialName;
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      void submit() {
        final trimmedName = name.trim();
        if (trimmedName.isEmpty) return;
        Navigator.pop(dialogContext, trimmedName);
      }

      return AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.environmentName,
                style: Theme.of(
                  dialogContext,
                ).textTheme.labelSmall?.copyWith(color: context.chakra.fgMuted),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: FormControlMetrics.standardHeight,
                width: double.infinity,
                child: TextFormField(
                  key: const ValueKey('environment-name-input'),
                  autofocus: true,
                  initialValue: initialName,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(),
                  onChanged: (value) => name = value,
                  onFieldSubmitted: (_) => submit(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(onPressed: submit, child: Text(actionLabel)),
        ],
      );
    },
  );
}
