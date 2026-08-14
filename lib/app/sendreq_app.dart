import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sendreq/data/repositories/in_memory_workspace_preference_store.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/data/repositories/in_memory_environment_store.dart';
import 'package:sendreq/data/repositories/in_memory_mock_server_repository.dart';
import 'package:sendreq/data/repositories/in_memory_user_notice_repository.dart';
import 'package:sendreq/data/services/openapi_output_directory.dart';
import 'package:sendreq/data/services/github_release_update_checker.dart';
import 'package:sendreq/data/services/proto_source_parser.dart';
import 'package:sendreq/ui/core/theme/app_theme.dart';
import 'package:sendreq/domain/preferences/workspace_preferences.dart';
import 'package:sendreq/domain/repositories/workspace_preference_store.dart';
import 'package:sendreq/ui/shell/views/workspace_view.dart';
import 'package:sendreq/domain/request_runtime/request_execution_runtime.dart';
import 'package:sendreq/domain/request_runtime/http_execution_service.dart';
import 'package:sendreq/domain/environments/environment_execution_resolver.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/data/services/http_request_execution_runtime.dart';
import 'package:sendreq/data/services/openapi_request_importer.dart';
import 'package:sendreq/data/services/openapi_request_exporter.dart';
import 'package:sendreq/data/services/openapi_file_exporter.dart';
import 'package:sendreq/data/services/openapi_markdown_documentation_renderer.dart';
import 'package:sendreq/data/services/markdown_documentation_file_exporter.dart';
import 'package:sendreq/data/services/local_workspace_file_ports.dart';
import 'package:sendreq/domain/api_assets/openapi_exchange.dart';
import 'package:sendreq/domain/api_assets/collection_documentation.dart';
import 'package:sendreq/domain/app_updates/app_update.dart';
import 'package:sendreq/domain/request_runtime/grpc_execution_service.dart';
import 'package:sendreq/domain/request_runtime/websocket_execution_service.dart';
import 'package:sendreq/data/services/desktop_grpc_transport.dart';
import 'package:sendreq/data/services/desktop_websocket_transport.dart';
import 'package:sendreq/data/services/local_mock_server_runtime.dart';
import 'package:sendreq/data/demo/demo_example_catalog.dart';
import 'package:sendreq/domain/contract_publishing/session_contract_publishing_service.dart';
import 'package:sendreq/app/window_spec.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/app/desktop_persistence_startup.dart';
import 'package:sendreq/app/desktop_window_controls.dart';
import 'package:sendreq/ui/shell/application/workspace_dependencies.dart';
import 'package:sendreq/ui/shell/application/workspace_window_controls.dart';

/// 应用根组件：组装 MaterialApp、主题、国际化与工作区主界面。
///
/// 执行运行时与完整的 Workspace 依赖快照均可注入，便于测试与嵌入宿主使用。
class SendreqApp extends StatefulWidget {
  /// 组装应用根组件；持久化依赖只通过完整的 Workspace 快照注入。
  const SendreqApp({
    super.key,
    this.executionRuntime,
    this.workspaceDependencies,
    this.startupController,
    this.windowControls,
    this.appReleaseRepository,
    this.installedAppVersionProvider,
    this.externalReleaseLauncher,
  });

  /// 真实请求执行运行时；未注入时使用 HTTP 运行时。
  final RequestExecutionRuntime? executionRuntime;

  /// 工作区持久化依赖快照；桌面入口通常由启动组合根提供。
  final WorkspaceDependencies? workspaceDependencies;

  /// 桌面组合根的迁移状态；存在时由它提供全部持久化依赖与恢复重试。
  final DesktopPersistenceStartupController? startupController;

  /// 桌面窗口控制实现；嵌入宿主和测试可提供替身。
  final WorkspaceWindowControls? windowControls;
  final AppReleaseRepository? appReleaseRepository;
  final InstalledAppVersionProvider? installedAppVersionProvider;
  final ExternalReleaseLauncher? externalReleaseLauncher;

  @override
  /// 创建应用状态。
  State<SendreqApp> createState() => _SendreqAppState();
}

/// 应用状态：负责加载偏好并据此驱动主题、语言与主界面。
class _SendreqAppState extends State<SendreqApp> with WidgetsBindingObserver {
  // 当前主题模式，默认深色。
  ThemeMode _themeMode = ThemeMode.dark;
  // 语言偏好，默认跟随系统。
  LocalePreference _localePreference = LocalePreference.system;
  // 界面字体偏好；代码与数据区域仍由组件保留等宽字体。
  WorkspaceFontPreference _fontPreference = WorkspacePreferences.defaults.font;
  CodeFontPreference _codeFontPreference =
      WorkspacePreferences.defaults.codeFont;
  double _codeFontSize = 12;
  // 实际使用的偏好存储。
  late WorkspacePreferenceStore _preferenceStore;
  // 加载完成后的偏好快照。
  WorkspacePreferences _preferences = WorkspacePreferences.defaults;
  // 工作区使用的持久化依赖快照；重试成功后整体替换。
  late WorkspaceDependencies _workspaceDependencies;
  // 偏好是否已加载完成（未完成前展示加载屏）。
  bool _preferencesReady = false;
  late final GrpcExecutionService _grpcExecutionService;
  late final WebSocketExecutionService _webSocketExecutionService;
  late final SessionContractPublishingService _contractPublishingService;
  late final EnvironmentExecutionResolver _environmentResolver;
  late final HttpExecutionService _executionService;
  late final OpenApiImportTransformer _openApiImporter;
  late final OpenApiExportPort _openApiExporter;
  late final OpenApiFileExportPort _openApiFileExporter;
  late final OpenApiFileReadPort _openApiFileReader;
  late final LocalOpenApiOutputDirectory _openApiOutputDirectory;
  late final OpenApiMarkdownDocumentationPort _openApiMarkdownRenderer;
  late final MarkdownDocumentationFilePort _markdownDocumentationFile;
  late final LocalProtobufSourcePort _protobufSource;
  late final ResponseBodyDownloadPort _responseBodyDownload;

  @override
  /// 初始化状态：注册生命周期观察者并加载偏好。
  void initState() {
    super.initState();
    // 注册生命周期观察者，监听系统亮度变化。
    WidgetsBinding.instance.addObserver(this);
    _grpcExecutionService = GrpcExecutionService(const DesktopGrpcTransport());
    _webSocketExecutionService = WebSocketExecutionService(
      const DesktopWebSocketTransport(),
    );
    // 未注入存储时使用内存实现。
    _workspaceDependencies =
        widget.startupController?.result.workspaceDependencies ??
        widget.workspaceDependencies ??
        _defaultWorkspaceDependencies();
    _contractPublishingService = SessionContractPublishingService(
      mockServerRepository: _workspaceDependencies.mockServerRepository,
      mockServerRuntime: LocalMockServerRuntime(),
    );
    _environmentResolver = EnvironmentExecutionResolver(
      _workspaceDependencies.environmentStore,
    );
    _executionService = HttpExecutionService(
      runtime: widget.executionRuntime ?? HttpRequestExecutionRuntime(),
    );
    _openApiImporter = const OpenApiRequestImporter();
    _openApiExporter = const OpenApiRequestExporter();
    _openApiFileExporter = const OpenApiFileExporter();
    _openApiFileReader = const LocalOpenApiFileReader();
    _openApiOutputDirectory = const LocalOpenApiOutputDirectory();
    _openApiMarkdownRenderer = const OpenApiMarkdownDocumentationRenderer();
    _markdownDocumentationFile = const MarkdownDocumentationFileExporter();
    _protobufSource = const LocalProtobufSourcePort();
    _responseBodyDownload = const LocalResponseBodyDownload();
    _preferenceStore = _workspaceDependencies.preferenceStore;
    widget.startupController?.addListener(_handleStartupStateChanged);
    _loadWorkspace();
  }

  @override
  /// 释放状态：注销观察者与监听器。
  void dispose() {
    // 移除生命周期观察者。
    WidgetsBinding.instance.removeObserver(this);
    widget.startupController?.removeListener(_handleStartupStateChanged);
    _grpcExecutionService.dispose();
    _webSocketExecutionService.dispose();
    _contractPublishingService.disposeSession();
    super.dispose();
  }

  // 桌面组合根状态变化（如重试完成）时，切换到新结果并重新加载偏好。
  void _handleStartupStateChanged() {
    final controller = widget.startupController;
    if (!mounted || controller == null || controller.isRetrying) return;
    setState(() {
      _preferenceStore =
          controller.result.workspaceDependencies.preferenceStore;
      _workspaceDependencies = controller.result.workspaceDependencies;
      _preferencesReady = false;
    });
    _loadWorkspace();
  }

  // 系统亮度变化时重建界面以同步外观。
  @override
  void didChangePlatformBrightness() => setState(() {});

  // 仅在主题实际变化时触发重建。
  void _setThemeMode(ThemeMode value) {
    if (_themeMode == value) return;
    setState(() => _themeMode = value);
  }

  // 从存储异步加载偏好，读取失败时回退到默认值。
  Future<void> _loadWorkspace() async {
    WorkspacePreferences loaded;
    try {
      loaded = await _preferenceStore.load();
    } on Object {
      loaded = WorkspacePreferences.defaults;
    }
    // 组件可能已销毁，避免在销毁后调用 setState。
    if (!mounted) return;
    setState(() {
      _preferences = loaded;
      _themeMode = _themeModeFor(loaded.appearance);
      _localePreference = loaded.locale;
      _fontPreference = loaded.font;
      _codeFontPreference = loaded.codeFont;
      _codeFontSize = loaded.codeFontSize;
      _preferencesReady = true;
    });
  }

  // 将外观偏好映射为 ThemeMode。
  ThemeMode _themeModeFor(AppearancePreference appearance) =>
      switch (appearance) {
        AppearancePreference.light => ThemeMode.light,
        AppearancePreference.dark => ThemeMode.dark,
        AppearancePreference.system => ThemeMode.system,
      };

  // 将语言偏好映射为 Locale，跟随系统时返回 null。
  Locale? get _locale => switch (_localePreference) {
    LocalePreference.system => null,
    LocalePreference.english => const Locale('en'),
    LocalePreference.simplifiedChinese => const Locale('zh'),
  };

  // 仅在语言偏好实际变化时触发重建。
  void _setLocale(LocalePreference preference) {
    if (_localePreference == preference) return;
    setState(() => _localePreference = preference);
  }

  // 仅在字体偏好实际变化时触发重建。
  void _setFont(WorkspaceFontPreference preference) {
    if (_fontPreference == preference) return;
    setState(() => _fontPreference = preference);
  }

  void _setCodeFont(CodeFontPreference preference) {
    if (_codeFontPreference == preference) return;
    setState(() => _codeFontPreference = preference);
  }

  void _setCodeFontSize(double size) {
    if (_codeFontSize == size) return;
    setState(() => _codeFontSize = size);
  }

  /// 构建应用界面：按偏好组装亮/暗主题与语言，并切换主界面或加载屏。
  @override
  Widget build(BuildContext context) {
    final lightTheme = SendreqTheme.light(
      fontFamily: _fontPreference.family,
      codeFontFamily: _codeFontPreference.family,
      codeFontSize: _codeFontSize,
    );
    final darkTheme = SendreqTheme.dark(
      fontFamily: _fontPreference.family,
      codeFontFamily: _codeFontPreference.family,
      codeFontSize: _codeFontSize,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: DesktopWindowSpec.title,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // 偏好就绪后进入主界面，否则展示加载屏。
      home: _preferencesReady
          ? WorkspaceView(
              environmentResolver: _environmentResolver,
              executionService: _executionService,
              openApiImporter: _openApiImporter,
              openApiExporter: _openApiExporter,
              openApiFileExporter: _openApiFileExporter,
              openApiFileReader: _openApiFileReader,
              openApiOutputDirectory: _openApiOutputDirectory,
              openApiMarkdownRenderer: _openApiMarkdownRenderer,
              markdownDocumentationFile: _markdownDocumentationFile,
              protobufSource: _protobufSource,
              responseBodyDownload: _responseBodyDownload,
              webSocketExecutionService: _webSocketExecutionService,
              grpcExecutionService: _grpcExecutionService,
              contractPublishingService: _contractPublishingService,
              appReleaseRepository:
                  widget.appReleaseRepository ??
                  const GitHubReleaseRepository(),
              installedAppVersionProvider:
                  widget.installedAppVersionProvider ??
                  const PackageInfoInstalledVersionProvider(),
              externalReleaseLauncher:
                  widget.externalReleaseLauncher ??
                  const SystemExternalReleaseLauncher(),
              workspaceDependencies: _workspaceDependencies,
              initialPreferences: _preferences,
              startupRecovery: widget.startupController,
              windowControls:
                  widget.windowControls ??
                  const DesktopWorkspaceWindowControls(),
              key: ValueKey(widget.startupController?.result),
              onAppearanceChanged: (appearance) =>
                  _setThemeMode(_themeModeFor(appearance)),
              onLocaleChanged: _setLocale,
              onFontChanged: _setFont,
              onCodeFontChanged: _setCodeFont,
              onCodeFontSizeChanged: _setCodeFontSize,
            )
          : const _PreferenceLoadingScreen(),
    );
  }

  // 独立渲染与 Widget 测试的完整内存组合；生产桌面入口始终注入启动快照。
  WorkspaceDependencies _defaultWorkspaceDependencies() =>
      WorkspaceDependencies(
        preferenceStore: InMemoryWorkspacePreferenceStore(),
        assetRepository: InMemoryApiAssetRepository.demo(),
        environmentStore: InMemoryEnvironmentStore.sample(),
        mockServerRepository: InMemoryMockServerRepository(),
        userNoticeRepository: InMemoryUserNoticeRepository(),
        demoCollection: DemoExampleCatalog.collection,
      );
}

/// 偏好加载完成前的全屏加载指示器。
class _PreferenceLoadingScreen extends StatelessWidget {
  const _PreferenceLoadingScreen();

  /// 构建全屏加载指示界面。
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
