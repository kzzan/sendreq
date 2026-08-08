part of 'environment_panel.dart';

class _EnvironmentNavigation extends StatelessWidget {
  /// 构造环境导航列表。
  const _EnvironmentNavigation({required this.viewModel});

  /// 工作区视图模型，提供环境列表与增删改操作。
  final WorkspaceViewModel viewModel;

  /// 构建环境导航：列表头部、环境项与全局变量区。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border(right: BorderSide(color: AppColors.outline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonoText(
                        l10n.environments.toUpperCase(),
                        color: AppColors.textMuted,
                        size: 10,
                        weight: FontWeight.w700,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.selectCurrentEnvironment,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: l10n.newEnvironment,
                  child: IconButton(
                    key: const ValueKey('new-environment-button'),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      backgroundColor: AppColors.primaryContainer.withValues(
                        alpha: 0.28,
                      ),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: () => _createEnvironment(context),
                    icon: const Icon(Icons.add, size: 17),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.outline),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final environment in viewModel.environments)
                  _EnvironmentNavigationItem(
                    environment: environment,
                    selected: environment.id == viewModel.activeEnvironment.id,
                    onSelected: () =>
                        viewModel.selectEnvironment(environment.id),
                    onSecondaryTapDown: (details) =>
                        _showEnvironmentContextMenu(
                          context,
                          details,
                          environment,
                        ),
                    onRename: () => _renameEnvironment(context, environment),
                    onDelete: () => _deleteEnvironment(context, environment),
                    canDelete: viewModel.canDeleteEnvironment(environment.id),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.outline)),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.public_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonoText('GLOBAL', color: AppColors.text, size: 10),
                      const SizedBox(height: 2),
                      Text(
                        l10n.scope,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _CountBadge(
                  count: viewModel.variables
                      .where((item) => item.scope == 'Global')
                      .length,
                ),
                const SizedBox(width: 4),
                DenseIconButton(
                  key: const ValueKey('add-global-variable-button'),
                  icon: Icons.add,
                  tooltip: l10n.addVariable,
                  onPressed: viewModel.addGlobalEnvironmentVariable,
                  size: 28,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 弹出命名对话框创建新环境，名称重复时给出提示。
  Future<void> _createEnvironment(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final name = await _showEnvironmentNameDialog(
      context,
      title: l10n.createEnvironment,
      actionLabel: l10n.createEnvironment,
    );
    if (name == null || !context.mounted) return;
    if (!viewModel.createEnvironment(name)) {
      _showNameError(context);
    }
  }

  /// 弹出命名对话框重命名环境，名称重复时给出提示。
  Future<void> _renameEnvironment(
    BuildContext context,
    EnvironmentProfile environment,
  ) async {
    final l10n = AppLocalizations.of(context);
    final name = await _showEnvironmentNameDialog(
      context,
      title: l10n.renameEnvironment,
      actionLabel: l10n.rename,
      initialName: environment.name,
    );
    if (name == null || !context.mounted) return;
    if (!viewModel.renameEnvironment(environment.id, name)) {
      _showNameError(context);
    }
  }

  /// 展示环境右键菜单：重命名或删除。
  Future<void> _showEnvironmentContextMenu(
    BuildContext context,
    TapDownDetails details,
    EnvironmentProfile environment,
  ) async {
    final l10n = AppLocalizations.of(context);
    final action = await showMenu<_EnvironmentMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: [
        PopupMenuItem(
          value: _EnvironmentMenuAction.rename,
          child: Text(l10n.renameEnvironment),
        ),
        PopupMenuItem(
          value: _EnvironmentMenuAction.delete,
          enabled: viewModel.canDeleteEnvironment(environment.id),
          child: Text(
            viewModel.canDeleteEnvironment(environment.id)
                ? l10n.deleteEnvironment
                : l10n.lastEnvironmentRequired,
          ),
        ),
      ],
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case _EnvironmentMenuAction.rename:
        await _renameEnvironment(context, environment);
        break;
      case _EnvironmentMenuAction.delete:
        await _deleteEnvironment(context, environment);
        break;
    }
  }

  /// 二次确认后删除环境；删除失败（如最后一个环境）时给出提示。
  Future<void> _deleteEnvironment(
    BuildContext context,
    EnvironmentProfile environment,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteEnvironment),
        content: Text(l10n.deleteEnvironmentConfirmation(environment.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.background,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (!viewModel.deleteEnvironment(environment.id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.lastEnvironmentRequired)));
    }
  }

  /// 以 SnackBar 提示环境名称必须唯一。
  void _showNameError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).environmentNameMustBeUnique),
      ),
    );
  }
}

/// 单条环境导航项：状态点、名称、选中态与右键/更多操作入口。
class _EnvironmentNavigationItem extends StatelessWidget {
  /// 构造环境导航项并绑定各交互回调。
  const _EnvironmentNavigationItem({
    required this.environment,
    required this.selected,
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
      'production' => AppColors.danger,
      'staging' => AppColors.warning,
      _ => AppColors.success,
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
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryContainer.withValues(alpha: 0.26)
                : null,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: onSelected,
                    child: SizedBox(
                      height: 42,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
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
                                      ? AppColors.text
                                      : AppColors.textMuted,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (selected)
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              PopupMenuButton<_EnvironmentMenuAction>(
                key: ValueKey('environment-actions-${environment.id}'),
                tooltip: AppLocalizations.of(context).environmentActions,
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_horiz,
                  size: 17,
                  color: AppColors.textMuted,
                ),
                onSelected: (action) {
                  switch (action) {
                    case _EnvironmentMenuAction.rename:
                      onRename();
                      break;
                    case _EnvironmentMenuAction.delete:
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return [
                    PopupMenuItem(
                      value: _EnvironmentMenuAction.rename,
                      child: Text(l10n.renameEnvironment),
                    ),
                    PopupMenuItem(
                      value: _EnvironmentMenuAction.delete,
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
enum _EnvironmentMenuAction { rename, delete }

/// 数量计数徽标：固定最小宽度的小圆角标签。
class _CountBadge extends StatelessWidget {
  /// 构造计数徽标。
  const _CountBadge({required this.count});

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
        color: AppColors.surfaceHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: MonoText('$count', color: AppColors.textMuted, size: 10),
    );
  }
}

/// 弹出环境命名对话框，返回输入的名称；取消时返回 null。
Future<String?> _showEnvironmentNameDialog(
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
                ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
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

/// 变量编辑工作区。标题、表头、数据区和计数 footer 保持为一块连续工具面。
