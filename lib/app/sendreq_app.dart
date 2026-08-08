import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/repositories/in_memory_workspace_preference_store.dart';
import '../data/repositories/in_memory_api_asset_repository.dart';
import '../data/repositories/in_memory_environment_store.dart';
import '../data/services/documentation_output_directory.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_colors.dart';
import '../domain/preferences/workspace_preferences.dart';
import '../domain/repositories/workspace_preference_store.dart';
import '../features/workspace/views/workspace_view.dart';
import '../domain/request_runtime/request_execution_runtime.dart';
import '../data/services/local_mock_runtime.dart';
import 'window_spec.dart';
import '../l10n/generated/app_localizations.dart';
import 'desktop_persistence_startup.dart';
import 'desktop_window_controls.dart';
import '../features/workspace/application/workspace_dependencies.dart';
import '../features/workspace/application/workspace_window_controls.dart';

/// 应用根组件：组装 MaterialApp、主题、国际化与工作区主界面。
///
/// 执行运行时与完整的 Workspace 依赖快照均可注入，便于测试与嵌入宿主使用。
class SendreqApp extends StatefulWidget {
  /// 组装应用根组件；持久化依赖只通过完整的 Workspace 快照注入。
  const SendreqApp({
    super.key,
    this.executionRuntime,
    this.mockRuntime,
    this.workspaceDependencies,
    this.startupController,
    this.windowControls,
  });

  /// 真实请求执行运行时；未注入时使用 HTTP 运行时。
  final RequestExecutionRuntime? executionRuntime;

  /// 本地 Mock 运行时，用于离线演示与测试。
  final LocalMockRuntime? mockRuntime;

  /// 工作区持久化依赖快照；桌面入口通常由启动组合根提供。
  final WorkspaceDependencies? workspaceDependencies;

  /// 桌面组合根的迁移状态；存在时由它提供全部持久化依赖与恢复重试。
  final DesktopPersistenceStartupController? startupController;

  /// 桌面窗口控制实现；嵌入宿主和测试可提供替身。
  final WorkspaceWindowControls? windowControls;

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
  WorkspaceFontPreference _fontPreference = WorkspaceFontPreference.inter;
  // 实际使用的偏好存储。
  late WorkspacePreferenceStore _preferenceStore;
  // 加载完成后的偏好快照。
  WorkspacePreferences _preferences = WorkspacePreferences.defaults;
  // 工作区使用的持久化依赖快照；重试成功后整体替换。
  late WorkspaceDependencies _workspaceDependencies;
  // 偏好是否已加载完成（未完成前展示加载屏）。
  bool _preferencesReady = false;

  @override
  /// 初始化状态：注册生命周期观察者并加载偏好。
  void initState() {
    super.initState();
    // 注册生命周期观察者，监听系统亮度变化。
    WidgetsBinding.instance.addObserver(this);
    // 未注入存储时使用内存实现。
    _workspaceDependencies =
        widget.startupController?.result.workspaceDependencies ??
        widget.workspaceDependencies ??
        _defaultWorkspaceDependencies();
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
    // 每次启动均校验已保存的自定义目录；没有配置时使用并创建默认目录。
    final defaultOutputDirectory =
        await _resolveDefaultDocumentationDirectory();
    final outputDirectory =
        loaded.documentationOutputDirectory ?? defaultOutputDirectory;
    _ensureDocumentationOutputDirectory(outputDirectory);
    // 组件可能已销毁，避免在销毁后调用 setState。
    if (!mounted) return;
    setState(() {
      _preferences = loaded;
      _themeMode = _themeModeFor(loaded.appearance);
      _localePreference = loaded.locale;
      _fontPreference = loaded.font;
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

  // 解析当前实际亮度：跟随系统时读取平台亮度。
  Brightness get _activeBrightness {
    if (_themeMode == ThemeMode.light) return Brightness.light;
    if (_themeMode == ThemeMode.dark) return Brightness.dark;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

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

  /// 后台校验输出目录，避免文件系统延迟阻塞工作区首次渲染。
  void _ensureDocumentationOutputDirectory(String path) {
    unawaited(_createDocumentationOutputDirectory(path));
  }

  // 创建输出目录；失败不阻断启动，导出时再向用户展示具体错误。
  Future<void> _createDocumentationOutputDirectory(String path) async {
    try {
      await DocumentationOutputDirectory.ensureExists(path);
    } on FileSystemException {
      // 无法创建时不阻断启动，导出动作会向用户显示具体错误。
    }
  }

  // 依次从桌面组合根、注入目录与测试回退路径解析默认输出目录。
  Future<String> _resolveDefaultDocumentationDirectory() async {
    final configuredDirectory =
        _workspaceDependencies.defaultDocumentationOutputDirectory;
    if (configuredDirectory != null) {
      return configuredDirectory;
    }
    // 正式桌面入口必定注入系统目录；未注入时只用于 Widget 测试或嵌入宿主，
    // 不能等待一个不可用的平台通道而阻塞首次渲染。
    return DocumentationOutputDirectory.testFallbackPath();
  }

  /// 构建应用界面：按偏好组装亮/暗主题与语言，并切换主界面或加载屏。
  @override
  Widget build(BuildContext context) {
    // 构建亮色主题前先切换到亮色色板。
    AppColors.applyBrightness(Brightness.light);
    final lightTheme = SendreqTheme.light(fontFamily: _fontPreference.family);
    // 构建暗色主题前先切换到暗色色板。
    AppColors.applyBrightness(Brightness.dark);
    final darkTheme = SendreqTheme.dark(fontFamily: _fontPreference.family);
    // 恢复当前实际亮度对应的色板，供界面构建期读取。
    AppColors.applyBrightness(_activeBrightness);
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
              executionRuntime: widget.executionRuntime,
              mockRuntime: widget.mockRuntime,
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
