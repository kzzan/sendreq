import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/workspace_dependencies.dart';
import '../application/workspace_startup_recovery.dart';
import '../application/workspace_window_controls.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/local_mock_runtime.dart';
import '../../../domain/models/workspace_models.dart';
import '../../../domain/preferences/workspace_preferences.dart';
import '../models/workspace_shell_models.dart';
import '../../../domain/request_runtime/request_execution_runtime.dart';
import '../../../domain/websocket/websocket_transport.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/workspace_message_localizations.dart';
import '../../api_assets/widgets/collection_panel.dart';
import '../../dashboard/widgets/dashboard_panel.dart';
import '../../documentation/widgets/documentation_panel.dart';
import '../../environments/widgets/environment_panel.dart';
import '../../history/widgets/history_panel.dart';
import '../../mock_servers/widgets/mock_servers_panel.dart';
import '../../request_editor/widgets/request_editor_panel.dart';
import '../../response_viewer/widgets/response_panel.dart';
import '../../settings/widgets/settings_panel.dart';
import '../../websocket/widgets/websocket_session_panel.dart';
import '../view_models/workspace_view_model.dart';
import '../../../core/widgets/dense_controls.dart';
import '../widgets/side_nav.dart';
import '../widgets/top_bar.dart';

/// 工作区主视图：负责组装侧边导航、顶栏与当前分区内容，
/// 统一注册全局快捷键（命令面板 / 保存 / 发送），并适配窄屏布局。
class WorkspaceView extends StatefulWidget {
  /// 构造工作区视图。持久化依赖由应用组合根统一注入。
  const WorkspaceView({
    super.key,
    this.executionRuntime,
    this.webSocketTransport,
    this.mockRuntime,
    this.onAppearanceChanged,
    this.onLocaleChanged,
    this.onFontChanged,
    required this.workspaceDependencies,
    this.initialPreferences = WorkspacePreferences.defaults,
    this.startupRecovery,
    this.windowControls = const NoopWorkspaceWindowControls(),
  });

  /// 请求执行运行时，为空时由 ViewModel 使用默认实现。
  final RequestExecutionRuntime? executionRuntime;

  /// WebSocket 传输实现；测试可注入替身，生产环境使用桌面默认实现。
  final WebSocketTransport? webSocketTransport;

  /// 本地 Mock 运行时，用于「创建 Mock」功能。
  final LocalMockRuntime? mockRuntime;

  /// 外观偏好变更回调，向上层通知以便持久化。
  final ValueChanged<AppearancePreference>? onAppearanceChanged;

  /// 语言偏好变更回调，向上层通知以便持久化。
  final ValueChanged<LocalePreference>? onLocaleChanged;

  /// 字体偏好变更回调，向应用根部同步全局文字主题。
  final ValueChanged<WorkspaceFontPreference>? onFontChanged;

  /// 由应用组合根提供的工作区持久化依赖。
  final WorkspaceDependencies workspaceDependencies;

  /// 启动时的初始偏好配置。
  final WorkspacePreferences initialPreferences;

  /// 启动迁移出现问题时，在主工作区展示恢复提示并允许重新尝试。
  final WorkspaceStartupRecovery? startupRecovery;

  /// 顶栏使用的窗口控制端口；独立预览时默认不执行平台操作。
  final WorkspaceWindowControls windowControls;

  /// 创建工作区视图状态。
  @override
  State<WorkspaceView> createState() => _WorkspaceViewState();
}

/// 工作区视图状态：持有共享的 ViewModel 并负责其生命周期。
class _WorkspaceViewState extends State<WorkspaceView> {
  // 整个工作区共享的唯一状态源，由本视图负责创建与销毁。
  late final WorkspaceViewModel _viewModel;

  /// 初始化时创建整个工作区共享的 ViewModel。
  @override
  void initState() {
    super.initState();
    _viewModel = WorkspaceViewModel.fromDependencies(
      executionRuntime: widget.executionRuntime,
      webSocketTransport: widget.webSocketTransport,
      mockRuntime: widget.mockRuntime,
      dependencies: widget.workspaceDependencies,
      initialPreferences: widget.initialPreferences,
    );
  }

  /// 销毁时释放 ViewModel 持有的资源。
  @override
  void dispose() {
    // 释放 ViewModel 持有的资源（定时器、流订阅等）。
    _viewModel.dispose();
    super.dispose();
  }

  /// 构建工作区主界面：注册快捷键、分发命令并适配窄屏布局。
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _viewModel,
        if (widget.startupRecovery != null) widget.startupRecovery!,
      ]),
      builder: (context, _) {
        return Shortcuts(
          // 注册固定快捷键：Ctrl/Cmd+K 打开命令面板、Ctrl/Cmd+S 保存当前资源。
          shortcuts: <ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                _OpenCommandIntent(),
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                _OpenCommandIntent(),
            const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                _SaveIntent(),
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
                _SaveIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _OpenCommandIntent: CallbackAction<_OpenCommandIntent>(
                onInvoke: (_) {
                  _handleAction(
                    WorkspaceGlobalAction(
                      type: WorkspaceActionType.openCommand,
                      source: WorkspaceActionSource.shortcut,
                    ),
                  );
                  return null;
                },
              ),
              _SaveIntent: CallbackAction<_SaveIntent>(
                onInvoke: (_) {
                  _handleAction(
                    WorkspaceGlobalAction(
                      type: WorkspaceActionType.save,
                      source: WorkspaceActionSource.shortcut,
                    ),
                  );
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              onKeyEvent: _handleSendShortcut,
              child: Scaffold(
                body: LayoutBuilder(
                  builder: (context, constraints) {
                    // 视口过窄时压缩顶栏，避免工具栏控件互相挤压。
                    final compactChrome = constraints.maxWidth < 1180;
                    // 三栏的固定编辑宽度需要为响应区保留至少约 360px；
                    // 低于该阈值时改为单窗格，避免正文和表格被压缩得不可读。
                    final useSinglePaneRequestWorkspace =
                        constraints.maxWidth < 1240;
                    return Container(
                      color: AppColors.background,
                      child: Row(
                        children: [
                          SideNav(viewModel: _viewModel),
                          Expanded(
                            child: Column(
                              children: [
                                TopBar(
                                  viewModel: _viewModel,
                                  compact: compactChrome,
                                  onAction: _handleAction,
                                  windowControls: widget.windowControls,
                                ),
                                if (widget.startupRecovery?.requiresRecovery ??
                                    false)
                                  _StartupRecoveryBanner(
                                    recovery: widget.startupRecovery!,
                                  ),
                                Expanded(
                                  child: _contentForActiveSection(
                                    useSinglePaneRequestWorkspace,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 根据当前激活分区与屏幕宽度，返回对应的面板内容。
  Widget _contentForActiveSection(bool isNarrow) {
    switch (_viewModel.activeSection) {
      case WorkspaceSection.dashboard:
        return DashboardPanel(viewModel: _viewModel);
      case WorkspaceSection.collections:
        // 尚无活动请求时展示空状态引导创建首个请求。
        if (!_viewModel.hasActiveRequest) {
          return _EmptyCollectionsWorkspace(viewModel: _viewModel);
        }
        // 窄屏退化为单窗格；WebSocket 会话直接独占面板。
        if (isNarrow) {
          if (_viewModel.isActiveWebSocket) {
            return WebSocketSessionPanel(viewModel: _viewModel);
          }
          return _NarrowRequestWorkspace(viewModel: _viewModel);
        }
        // 宽屏三栏布局：集合树 + 请求编辑 + 响应/WebSocket 会话。
        return Row(
          children: [
            CollectionPanel(viewModel: _viewModel),
            RequestEditorPanel(viewModel: _viewModel),
            Expanded(
              child: _viewModel.isActiveWebSocket
                  ? WebSocketSessionPanel(viewModel: _viewModel)
                  : ResponsePanel(viewModel: _viewModel),
            ),
          ],
        );
      case WorkspaceSection.history:
        return HistoryPanel(viewModel: _viewModel);
      case WorkspaceSection.environments:
        // 环境是独立的配置工作区。完整展示列表和变量表，避免与请求编辑器
        // 争夺空间而压缩变量键和值。
        return EnvironmentPanel(viewModel: _viewModel);
      case WorkspaceSection.mockServers:
        return MockServersPanel(viewModel: _viewModel);
      case WorkspaceSection.documentation:
        return DocumentationPanel(viewModel: _viewModel);
      case WorkspaceSection.settings:
        return SettingsPanel(
          viewModel: _viewModel,
          onAppearanceChanged: widget.onAppearanceChanged,
          onLocaleChanged: widget.onLocaleChanged,
          onFontChanged: widget.onFontChanged,
        );
    }
  }

  /// 统一处理全局动作：先交给 ViewModel 分发，
  /// 再针对「命令面板」等需要 UI 弹层的动作做特殊处理，其余动作展示反馈消息。
  void _handleAction(WorkspaceGlobalAction action) {
    _viewModel.dispatch(action);
    // 打开命令面板需由本视图弹出对话框，故在此单独处理。
    if (action.type == WorkspaceActionType.openCommand) {
      _showCommandPalette();
      return;
    }

    // 其余动作（保存/发送等）结束后，展示 ViewModel 产生的本地化反馈。
    final message = _viewModel.lastActionMessage.localized(
      AppLocalizations.of(context),
    );
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// 在工作区根 Focus 的冒泡路径中处理发送键，确保输入控件有焦点时仍可用。
  KeyEventResult _handleSendShortcut(FocusNode _, KeyEvent event) {
    if (!_viewModel.matchesSendShortcut(event)) {
      return KeyEventResult.ignored;
    }
    _handleAction(
      WorkspaceGlobalAction(
        type: WorkspaceActionType.send,
        source: WorkspaceActionSource.shortcut,
      ),
    );
    return KeyEventResult.handled;
  }

  /// 打开命令面板对话框；选中命令后关闭弹层并经由 [_handleAction] 执行。
  Future<void> _showCommandPalette() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CommandPalette(
        viewModel: _viewModel,
        onAction: (action) {
          Navigator.of(context).pop();
          _handleAction(action);
        },
      ),
    );
  }
}

/// 空集合工作区：左侧集合树 + 右侧引导创建首个请求的空状态。
class _EmptyCollectionsWorkspace extends StatelessWidget {
  /// 构造空集合工作区。
  const _EmptyCollectionsWorkspace({required this.viewModel});

  /// 共享的工作区 ViewModel。
  final WorkspaceViewModel viewModel;

  /// 构建空集合引导界面。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        CollectionPanel(viewModel: viewModel),
        Expanded(
          child: Container(
            color: AppColors.background,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 28,
                  color: AppColors.textFaint,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.noRequestsYet,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.createRequestToStart,
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: viewModel.createRequest,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.newRequest),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 「保存」快捷键对应的 Intent。
class _SaveIntent extends Intent {
  /// 保存命令的 Intent。
  const _SaveIntent();
}

/// 「打开命令面板」快捷键对应的 Intent。
class _OpenCommandIntent extends Intent {
  /// 打开命令面板命令的 Intent。
  const _OpenCommandIntent();
}

/// 窄屏（<980px）下的单窗格请求工作区：顶部分页在集合/请求/响应间切换。
class _NarrowRequestWorkspace extends StatelessWidget {
  /// 构造窄屏请求工作区。
  const _NarrowRequestWorkspace({required this.viewModel});

  /// 共享的工作区 ViewModel。
  final WorkspaceViewModel viewModel;

  /// 构建窄屏单窗格工作区界面。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // 三个页签在最窄视口均分可用空间，宽屏则保持稳定的工具型宽度。
            final tabWidth = ((constraints.maxWidth - 36) / 3)
                .clamp(0, 92.0)
                .toDouble();
            return Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.outline)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: tabWidth,
                    child: _NarrowPanelTab(
                      label: l10n.collections,
                      selected:
                          viewModel.narrowWorkspacePanel ==
                          NarrowWorkspacePanel.collections,
                      onTap: () => viewModel.selectNarrowWorkspacePanel(
                        NarrowWorkspacePanel.collections,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: tabWidth,
                    child: _NarrowPanelTab(
                      label: l10n.request,
                      selected:
                          viewModel.narrowWorkspacePanel ==
                          NarrowWorkspacePanel.request,
                      onTap: () => viewModel.selectNarrowWorkspacePanel(
                        NarrowWorkspacePanel.request,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: tabWidth,
                    child: _NarrowPanelTab(
                      label: l10n.response,
                      selected:
                          viewModel.narrowWorkspacePanel ==
                          NarrowWorkspacePanel.response,
                      onTap: () => viewModel.selectNarrowWorkspacePanel(
                        NarrowWorkspacePanel.response,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // 根据当前选中的窄屏页签渲染对应面板；响应页额外允许空状态发送。
        Expanded(
          child: switch (viewModel.narrowWorkspacePanel) {
            NarrowWorkspacePanel.collections => CollectionPanel(
              viewModel: viewModel,
              expandToFill: true,
            ),
            NarrowWorkspacePanel.request => RequestEditorPanel(
              viewModel: viewModel,
              compact: true,
            ),
            NarrowWorkspacePanel.response => ResponsePanel(
              viewModel: viewModel,
              showEmptySendAction: true,
            ),
          },
        ),
      ],
    );
  }
}

/// 窄屏工作区的页签按钮，选中态用主色与描边高亮。
class _NarrowPanelTab extends StatelessWidget {
  /// 构造页签按钮。
  const _NarrowPanelTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// 页签显示文本。
  final String label;

  /// 是否处于选中态。
  final bool selected;

  /// 点击回调。
  final VoidCallback onTap;

  /// 构建页签按钮界面。
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 28),
        foregroundColor: selected ? AppColors.primary : AppColors.textMuted,
        backgroundColor: selected
            ? AppColors.surfaceHighest
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.outline,
          ),
        ),
      ),
      child: Text(label),
    );
  }
}

/// 命令面板对话框：搜索框与可用命令列表（保存 / 发送），
/// 命令是否可用取决于 ViewModel 的 actionAvailability。
class _CommandPalette extends StatefulWidget {
  /// 构造命令面板对话框。
  const _CommandPalette({required this.viewModel, required this.onAction});

  /// 共享的工作区 ViewModel，用于检索资源与判断命令可用性。
  final WorkspaceViewModel viewModel;

  /// 命令选中后的回调，由调用方关闭弹层并执行动作。
  final ValueChanged<WorkspaceGlobalAction> onAction;

  /// 创建命令面板状态。
  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

/// 命令面板状态：维护搜索词并过滤可检索资源。
class _CommandPaletteState extends State<_CommandPalette> {
  /// 当前搜索词。
  var _query = '';

  /// 构建命令面板界面：搜索框、命令列表与可检索资源。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final normalized = _query.trim().toLowerCase();
    final resources = widget.viewModel.searchableResources
        .where((resource) => resource.title.toLowerCase().contains(normalized))
        .toList(growable: false);
    return AlertDialog(
      title: Text(l10n.commandPalette),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchCommands,
              ),
            ),
            const SizedBox(height: 12),
            _CommandRow(
              icon: Icons.save_outlined,
              title: l10n.saveActiveResource,
              enabled: widget.viewModel.actionAvailability.canSave,
              onTap: () => widget.onAction(
                WorkspaceGlobalAction(
                  type: WorkspaceActionType.save,
                  source: WorkspaceActionSource.commandPalette,
                ),
              ),
            ),
            _CommandRow(
              icon: Icons.play_arrow_rounded,
              title: l10n.sendActiveRequest,
              enabled: widget.viewModel.actionAvailability.canSend,
              disabledReason:
                  widget.viewModel.actionAvailability.sendUnavailableReason,
              onTap: () => widget.onAction(
                WorkspaceGlobalAction(
                  type: WorkspaceActionType.send,
                  source: WorkspaceActionSource.commandPalette,
                ),
              ),
              shortcut: widget.viewModel.sendShortcut.label,
            ),
            const SizedBox(height: 8),
            if (resources.isEmpty)
              Text(
                l10n.noMatchingResources,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final resource in resources)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          resource.isRequest
                              ? Icons.http_outlined
                              : Icons.folder_outlined,
                        ),
                        title: Text(resource.title),
                        onTap: () {
                          widget.viewModel.openSearchResource(resource);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 命令面板中的单条命令行：图标、标题、快捷键提示，以及禁用原因（作为悬浮提示）。
class _CommandRow extends StatelessWidget {
  /// 构造命令面板中的一行命令。
  const _CommandRow({
    required this.icon,
    required this.title,
    required this.enabled,
    required this.onTap,
    this.disabledReason,
    this.shortcut,
  });

  /// 命令图标。
  final IconData icon;

  /// 命令标题。
  final String title;

  /// 是否可点击执行。
  final bool enabled;

  /// 禁用原因，作为悬浮提示展示。
  final String? disabledReason;

  /// 快捷键提示文本。
  final String? shortcut;

  /// 点击执行回调。
  final VoidCallback onTap;

  /// 构建命令行界面。
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: disabledReason.localized(AppLocalizations.of(context)) ?? title,
      child: ListTile(
        enabled: enabled,
        leading: Icon(icon),
        title: Text(title),
        trailing: shortcut == null
            ? null
            : MonoText(shortcut!, color: AppColors.textFaint, size: 10),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

/// 顶部恢复带只在启动持久化未完成时出现，保留工作区空间并使恢复动作随时可见。
class _StartupRecoveryBanner extends StatelessWidget {
  /// 构造启动恢复提示带。
  const _StartupRecoveryBanner({required this.recovery});

  /// 启动恢复端口，用于展示状态与触发重试。
  final WorkspaceStartupRecovery recovery;

  /// 构建恢复提示带界面。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border(
          bottom: BorderSide(color: AppColors.warning.withValues(alpha: .42)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.storage_rounded, color: AppColors.warning, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.startupRecoveryTitle,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.startupRecoveryDescription,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          TextButton.icon(
            onPressed: recovery.isRetrying ? null : recovery.retry,
            icon: recovery.isRetrying
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
