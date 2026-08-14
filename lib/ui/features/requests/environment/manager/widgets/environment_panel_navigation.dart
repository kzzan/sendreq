import 'package:flutter/material.dart';

import 'package:sendreq/domain/environments/environment_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/application/user_message.dart';
import 'package:sendreq/ui/core/widgets/user_message_scope.dart';
import 'package:sendreq/ui/core/widgets/workspace_navigation_rail.dart';
import 'package:sendreq/ui/features/requests/environment/manager/widgets/environment_panel_navigation_items.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

class EnvironmentNavigation extends StatefulWidget {
  /// 构造环境导航列表。
  const EnvironmentNavigation({super.key, required this.viewModel});

  /// 工作区视图模型，提供环境列表与增删改操作。
  final WorkspaceViewModel viewModel;

  @override
  State<EnvironmentNavigation> createState() => _EnvironmentNavigationState();
}

class _EnvironmentNavigationState extends State<EnvironmentNavigation> {
  final ScrollController _scrollController = ScrollController();
  String? _lastVisibleEnvironmentId;

  WorkspaceViewModel get viewModel => widget.viewModel;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _revealEditingEnvironment() {
    final editingId = viewModel.editingEnvironment.id;
    if (_lastVisibleEnvironmentId == editingId) return;
    _lastVisibleEnvironmentId = editingId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final index = viewModel.environments.indexWhere(
        (environment) => environment.id == editingId,
      );
      if (index < 0) return;
      final target = (index * 46.0).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// 构建环境导航：列表头部、环境项与全局变量区。
  @override
  Widget build(BuildContext context) {
    _revealEditingEnvironment();
    final l10n = AppLocalizations.of(context);
    return WorkspaceNavigationRail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NavigationRailHeader(
            title: l10n.environments,
            subtitle: l10n.selectEnvironmentToEdit,
            leading: Icon(
              Icons.layers_outlined,
              size: 17,
              color: context.chakra.colorPaletteFg,
            ),
            trailing: Tooltip(
              message: l10n.newEnvironment,
              child: IconButton(
                key: const ValueKey('new-environment-button'),
                style: ChakraRecipes.iconSelectableFor(context, selected: true),
                onPressed: () => _createEnvironment(context),
                icon: const Icon(Icons.add, size: 17),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                vertical: WorkspaceLayoutMetrics.groupGap,
              ),
              children: [
                for (final environment in viewModel.environments)
                  EnvironmentNavigationItem(
                    environment: environment,
                    selected: environment.id == viewModel.editingEnvironment.id,
                    active: environment.id == viewModel.activeEnvironment.id,
                    onSelected: () =>
                        viewModel.selectEnvironmentForEditing(environment.id),
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
            padding: WorkspaceLayoutMetrics.panelPadding,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.chakra.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.chakra.bgEmphasized,
                    borderRadius: ChakraRadii.control,
                  ),
                  child: Icon(
                    Icons.public_outlined,
                    size: 14,
                    color: context.chakra.fgMuted,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonoText('GLOBAL', color: context.chakra.fg, size: 10),
                      const SizedBox(height: 2),
                      Text(
                        l10n.scope,
                        style: TextStyle(
                          color: context.chakra.fgMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                EnvironmentCountBadge(
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
    final name = await showEnvironmentNameDialog(
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
    final name = await showEnvironmentNameDialog(
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
    final action = await showMenu<EnvironmentMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: [
        PopupMenuItem(
          value: EnvironmentMenuAction.rename,
          child: Text(l10n.renameEnvironment),
        ),
        PopupMenuItem(
          value: EnvironmentMenuAction.delete,
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
      case EnvironmentMenuAction.rename:
        await _renameEnvironment(context, environment);
        break;
      case EnvironmentMenuAction.delete:
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
            style: ChakraRecipes.destructiveFor(dialogContext),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (!viewModel.deleteEnvironment(environment.id)) {
      publishUserMessage(
        context,
        l10n.lastEnvironmentRequired,
        severity: UserMessageSeverity.warning,
        deduplicationKey: 'environment.last.required',
      );
    }
  }

  /// 通过统一消息通知提示环境名称必须唯一。
  void _showNameError(BuildContext context) {
    publishUserMessage(
      context,
      AppLocalizations.of(context).environmentNameMustBeUnique,
      severity: UserMessageSeverity.warning,
      deduplicationKey: 'environment.name.duplicate',
    );
  }
}

/// 变量编辑工作区。标题、表头、数据区和计数 footer 保持为一块连续工具面。
