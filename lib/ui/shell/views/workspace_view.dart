import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sendreq/ui/shell/application/workspace_dependencies.dart';
import 'package:sendreq/ui/shell/application/workspace_startup_recovery.dart';
import 'package:sendreq/ui/shell/application/workspace_window_controls.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/listenable_selector.dart';
import 'package:sendreq/ui/core/widgets/user_message_scope.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/preferences/workspace_preferences.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/domain/api_assets/openapi_exchange.dart';
import 'package:sendreq/domain/api_assets/collection_documentation.dart';
import 'package:sendreq/domain/app_updates/app_update.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/features/requests/collection/widgets/collection_panel.dart';
import 'package:sendreq/ui/features/requests/environment/manager/widgets/environment_panel.dart';
import 'package:sendreq/ui/features/mock/widgets/mock_servers_panel.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_panel.dart';
import 'package:sendreq/ui/features/requests/output/widgets/response_panel.dart';
import 'package:sendreq/ui/features/settings/widgets/settings_panel.dart';
import 'package:sendreq/ui/features/settings/view_models/settings_view_model.dart';
import 'package:sendreq/ui/features/settings/view_models/app_update_controller.dart';
import 'package:sendreq/ui/features/requests/websocket/widgets/websocket_session_panel.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/ui/shell/models/workspace_shell_models.dart';
import 'package:sendreq/ui/shell/widgets/side_nav.dart';
import 'package:sendreq/ui/shell/widgets/top_bar.dart';
import 'package:sendreq/ui/shell/widgets/notification_center.dart';
import 'package:sendreq/ui/shell/views/workspace_view_request_layouts.dart';
import 'package:sendreq/ui/shell/views/workspace_view_projections.dart';

/// 工作区主视图：负责组装侧边导航、顶栏与当前分区内容，并适配窄屏布局。
class WorkspaceView extends StatefulWidget {
  /// 构造工作区视图。持久化依赖由应用组合根统一注入。
  const WorkspaceView({
    super.key,
    required this.environmentResolver,
    required this.executionService,
    required this.openApiImporter,
    required this.openApiExporter,
    required this.openApiFileExporter,
    required this.openApiFileReader,
    required this.openApiOutputDirectory,
    required this.openApiMarkdownRenderer,
    required this.markdownDocumentationFile,
    required this.protobufSource,
    required this.responseBodyDownload,
    required this.webSocketExecutionService,
    required this.grpcExecutionService,
    required this.contractPublishingService,
    required this.appReleaseRepository,
    required this.installedAppVersionProvider,
    required this.externalReleaseLauncher,
    this.onAppearanceChanged,
    this.onLocaleChanged,
    this.onFontChanged,
    this.onCodeFontChanged,
    this.onCodeFontSizeChanged,
    required this.workspaceDependencies,
    this.initialPreferences = WorkspacePreferences.defaults,
    this.startupRecovery,
    this.windowControls = const NoopWorkspaceWindowControls(),
  });

  final EnvironmentResolver environmentResolver;
  final ExecutionService executionService;
  final OpenApiImportTransformer openApiImporter;
  final OpenApiExportPort openApiExporter;
  final OpenApiFileExportPort openApiFileExporter;
  final OpenApiFileReadPort openApiFileReader;
  final OpenApiOutputDirectoryPort openApiOutputDirectory;
  final OpenApiMarkdownDocumentationPort openApiMarkdownRenderer;
  final MarkdownDocumentationFilePort markdownDocumentationFile;
  final ProtobufSourcePort protobufSource;
  final ResponseBodyDownloadPort responseBodyDownload;

  /// 由组合根提供的长生命周期协议执行端口。
  final WebSocketExecutionPort webSocketExecutionService;
  final GrpcExecutionPort grpcExecutionService;

  /// Contract Publishing 端口由组合根选择实现。
  final ContractPublishingService contractPublishingService;
  final AppReleaseRepository appReleaseRepository;
  final InstalledAppVersionProvider installedAppVersionProvider;
  final ExternalReleaseLauncher externalReleaseLauncher;

  /// 外观偏好变更回调，向上层通知以便持久化。
  final ValueChanged<AppearancePreference>? onAppearanceChanged;

  /// 语言偏好变更回调，向上层通知以便持久化。
  final ValueChanged<LocalePreference>? onLocaleChanged;

  /// 字体偏好变更回调，向应用根部同步全局文字主题。
  final ValueChanged<WorkspaceFontPreference>? onFontChanged;
  final ValueChanged<CodeFontPreference>? onCodeFontChanged;
  final ValueChanged<double>? onCodeFontSizeChanged;

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
  late final AppUpdateController _appUpdateController;

  /// 初始化时创建整个工作区共享的 ViewModel。
  @override
  void initState() {
    super.initState();
    _viewModel = WorkspaceViewModel.fromDependencies(
      environmentResolver: widget.environmentResolver,
      executionService: widget.executionService,
      openApiImporter: widget.openApiImporter,
      openApiExporter: widget.openApiExporter,
      openApiFileExporter: widget.openApiFileExporter,
      openApiFileReader: widget.openApiFileReader,
      openApiOutputDirectory: widget.openApiOutputDirectory,
      openApiMarkdownRenderer: widget.openApiMarkdownRenderer,
      markdownDocumentationFile: widget.markdownDocumentationFile,
      protobufSource: widget.protobufSource,
      responseBodyDownload: widget.responseBodyDownload,
      webSocketExecutionService: widget.webSocketExecutionService,
      grpcExecutionService: widget.grpcExecutionService,
      contractPublishingService: widget.contractPublishingService,
      dependencies: widget.workspaceDependencies,
      initialPreferences: widget.initialPreferences,
    );
    _appUpdateController = AppUpdateController(
      releaseRepository: widget.appReleaseRepository,
      installedVersionProvider: widget.installedAppVersionProvider,
      releaseLauncher: widget.externalReleaseLauncher,
    );
  }

  /// 销毁时释放 ViewModel 持有的资源。
  @override
  void dispose() {
    // 释放 ViewModel 持有的资源（定时器、流订阅等）。
    _viewModel.dispose();
    _appUpdateController.dispose();
    super.dispose();
  }

  /// 构建工作区主界面并适配窄屏布局。
  @override
  Widget build(BuildContext context) {
    return UserMessageScope(
      publish: _viewModel.publishUserMessage,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): _sendActiveRequest,
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              _saveActiveRequest,
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
              _saveActiveRequest,
          const SingleActivator(LogicalKeyboardKey.escape):
              _closeEnvironmentManager,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                // 视口过窄时压缩顶栏，避免工具栏控件互相挤压。
                final compactChrome = constraints.maxWidth < 1180;
                // 三栏的固定编辑宽度需要为响应区保留至少约 360px；
                // 低于该阈值时改为单窗格，避免正文和表格被压缩得不可读。
                final useSinglePaneRequestWorkspace =
                    constraints.maxWidth < 1240;
                final compactNavigation = constraints.maxWidth < 900;
                return Container(
                  color: context.chakra.bg,
                  child: Row(
                    children: [
                      ListenableSelector<
                        ({
                          WorkspaceSection section,
                          RequestWorkingView requestView,
                        })
                      >(
                        listenable: _viewModel,
                        select: () => (
                          section: _viewModel.activeSection,
                          requestView: _viewModel.requestWorkingView,
                        ),
                        builder: (context, selection, child) => SideNav(
                          viewModel: _viewModel,
                          compact: compactNavigation,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            ListenableSelector<WorkspaceTopBarProjection>(
                              listenable: _viewModel,
                              select: () =>
                                  WorkspaceTopBarProjection.fromViewModel(
                                    _viewModel,
                                  ),
                              builder: (context, selection, child) => TopBar(
                                viewModel: _viewModel,
                                compact: compactChrome,
                                windowControls: widget.windowControls,
                                onOpenNotifications: _showNotificationCenter,
                              ),
                            ),
                            _startupRecoveryBanner(),
                            Expanded(
                              child: ListenableBuilder(
                                listenable: _viewModel,
                                builder: (context, child) =>
                                    _contentForActiveSection(
                                      useSinglePaneRequestWorkspace,
                                    ),
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
  }

  Widget _startupRecoveryBanner() {
    final recovery = widget.startupRecovery;
    if (recovery == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: recovery,
      builder: (context, child) => recovery.requiresRecovery
          ? StartupRecoveryBanner(recovery: recovery)
          : const SizedBox.shrink(),
    );
  }

  void _sendActiveRequest() {
    if (_viewModel.activeSection != WorkspaceSection.requests ||
        _viewModel.environmentManagerOpen ||
        !_viewModel.hasActiveRequest) {
      return;
    }
    _viewModel.dispatch(
      WorkspaceGlobalAction(
        type: WorkspaceActionType.send,
        source: WorkspaceActionSource.keyboard,
      ),
    );
  }

  void _saveActiveRequest() {
    if (_viewModel.activeSection != WorkspaceSection.requests ||
        _viewModel.environmentManagerOpen ||
        !_viewModel.hasActiveRequest) {
      return;
    }
    unawaited(_viewModel.saveActiveRequestDurably());
  }

  void _closeEnvironmentManager() {
    if (_viewModel.environmentManagerOpen) {
      unawaited(_requestCloseEnvironmentManager());
    }
  }

  /// 根据当前激活分区与屏幕宽度，返回对应的面板内容。
  Widget _contentForActiveSection(bool isNarrow) {
    switch (_viewModel.activeSection) {
      case WorkspaceSection.requests:
        if (_viewModel.environmentManagerOpen) {
          if (isNarrow) {
            return KeyedSubtree(
              key: const Key('environment-manage-stage'),
              child: EnvironmentPanel(
                viewModel: _viewModel,
                onCloseRequested: _requestCloseEnvironmentManager,
              ),
            );
          }
          return RequestWorkspaceWithEnvironmentDrawer(
            viewModel: _viewModel,
            onCloseEnvironment: _requestCloseEnvironmentManager,
          );
        }
        // 尚无活动请求时展示空状态引导创建首个请求。
        if (!_viewModel.hasActiveRequest) {
          return EmptyCollectionsWorkspace(viewModel: _viewModel);
        }
        // 窄屏退化为单窗格；WebSocket 会话直接独占面板。
        if (isNarrow) {
          if (_viewModel.isActiveWebSocket) {
            return WebSocketSessionPanel(viewModel: _viewModel);
          }
          return NarrowRequestWorkspace(viewModel: _viewModel);
        }
        // 宽屏三栏布局：集合树 + 请求编辑 + 响应/WebSocket 会话。
        return Row(
          key: const Key('collection-desktop-workspace'),
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
      case WorkspaceSection.mock:
        return MockServersPanel(
          state: MockServersPanelState(
            savedMockServers: _viewModel.savedMockServers,
            selectedMockServerId: _viewModel.activeMockServerId,
            selectMockServer: _viewModel.selectMockServer,
            canCreateFromResponse: _viewModel.canCreateMockFromResponse,
            createManual: _viewModel.createManualMockServer,
            createFromResponse: _viewModel.createMockServerFromResponse,
            startSaved: _viewModel.startSavedMockServer,
            stopSaved: _viewModel.stopSavedMockServer,
            saveSaved: _viewModel.saveSavedMockServer,
            archiveSaved: _viewModel.archiveSavedMockServer,
            deleteSaved: _viewModel.deleteSavedMockServer,
            openSource: _viewModel.openMockSource,
            sourceUnavailableReason: _viewModel.mockSourceUnavailableReason,
          ),
        );
      case WorkspaceSection.settings:
        return SettingsPanel(
          viewModel: _settingsViewModel,
          onAppearanceChanged: widget.onAppearanceChanged,
          onLocaleChanged: widget.onLocaleChanged,
          onFontChanged: widget.onFontChanged,
          onCodeFontChanged: widget.onCodeFontChanged,
          onCodeFontSizeChanged: widget.onCodeFontSizeChanged,
        );
    }
  }

  SettingsViewModel get _settingsViewModel => SettingsViewModel(
    appearance: _viewModel.appearance,
    locale: _viewModel.locale,
    font: _viewModel.font,
    codeFont: _viewModel.codeFont,
    codeFontSize: _viewModel.codeFontSize,
    persistenceState: _viewModel.preferencePersistenceState,
    updateAppearance: _viewModel.updateAppearance,
    updateLocale: _viewModel.updateLocale,
    updateFont: _viewModel.updateFont,
    updateCodeFont: _viewModel.updateCodeFont,
    updateCodeFontSize: _viewModel.updateCodeFontSize,
    resetPreferences: _viewModel.resetPreferences,
    retryPreferenceSave: _viewModel.retryPreferenceSave,
    appUpdateController: _appUpdateController,
  );

  Future<void> _showNotificationCenter() => showDialog<void>(
    context: context,
    builder: (context) => AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) => NotificationCenter(
        notices: _viewModel.notices,
        acknowledge: _viewModel.acknowledgeNotice,
        recover: _viewModel.recoverNotice,
        clearAll: _viewModel.clearNotices,
      ),
    ),
  );

  /// 所有 Environment 管理层退出方式共用此协调器，避免静默丢失配置。
  Future<void> _requestCloseEnvironmentManager() async {
    if (!_viewModel.environmentManagerOpen) return;
    if (!_viewModel.hasEnvironmentChanges) {
      _viewModel.returnFromEnvironment();
      return;
    }

    final l10n = AppLocalizations.of(context);
    final decision = await showDialog<_EnvironmentCloseDecision>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.closeEnvironmentManagerTitle),
        content: Text(l10n.closeEnvironmentManagerMessage),
        actions: [
          TextButton(
            key: const Key('environment-close-keep-editing'),
            onPressed: () => Navigator.pop(
              dialogContext,
              _EnvironmentCloseDecision.keepEditing,
            ),
            child: Text(l10n.continueEditing),
          ),
          OutlinedButton(
            key: const Key('environment-close-discard'),
            onPressed: () =>
                Navigator.pop(dialogContext, _EnvironmentCloseDecision.discard),
            child: Text(l10n.discardChanges),
          ),
          FilledButton(
            key: const Key('environment-close-apply'),
            onPressed: () =>
                Navigator.pop(dialogContext, _EnvironmentCloseDecision.apply),
            child: Text(l10n.apply),
          ),
        ],
      ),
    );
    if (!mounted || decision == null) return;
    switch (decision) {
      case _EnvironmentCloseDecision.keepEditing:
        return;
      case _EnvironmentCloseDecision.discard:
        _viewModel.discardEnvironmentChanges();
      case _EnvironmentCloseDecision.apply:
        await _viewModel.saveEnvironmentChanges();
        if (_viewModel.hasEnvironmentChanges) return;
    }
    _viewModel.returnFromEnvironment();
  }
}

enum _EnvironmentCloseDecision { apply, discard, keepEditing }

/// Request workspace responsive layouts live in workspace_view_request_layouts.dart.
