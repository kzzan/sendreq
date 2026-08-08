part of 'workspace_view_model.dart';

/// 工作区导航、偏好与环境变量操作；不包含请求资产或网络执行逻辑。
extension WorkspaceNavigationOperations on WorkspaceViewModel {
  /// 切换当前工作区区块。
  void selectSection(WorkspaceSection section) {
    if (_activeSection == section) {
      return;
    }
    _activeSection = section;
    // 首次进入历史区块时自动打开最近一条带快照的执行记录。
    if (section == WorkspaceSection.history && _openedHistoryRecord == null) {
      final latestSnapshot = _history
          .where((item) => item.hasSnapshot)
          .firstOrNull;
      if (latestSnapshot != null) {
        _openedHistoryRecord = latestSnapshot;
        _response = latestSnapshot.response;
        _executionError = latestSnapshot.errorMessage;
        _activeResponseTab = ResponseTab.body;
      }
    }
    _notify();
  }

  /// 切换到指定环境作为活动环境。
  void selectEnvironment(String environmentId) {
    if (_environmentStore.activeEnvironment.id == environmentId) return;
    _environmentStore.setActiveEnvironment(environmentId);
    _invalidateEnvironmentExecutionContext();
    _notify();
  }

  /// 新建环境并切换到它；无效或重复名称保留当前环境不变。
  bool createEnvironment(String name) {
    try {
      _environmentStore.createEnvironment(name);
      _invalidateEnvironmentExecutionContext();
      _lastActionMessage = 'Environment created.';
      _notify();
      return true;
    } on ArgumentError {
      _lastActionMessage = 'Enter a unique environment name.';
      _notify();
      return false;
    }
  }

  /// 重命名环境；无效或重复名称不会覆盖原名称。
  bool renameEnvironment(String environmentId, String name) {
    try {
      _environmentStore.renameEnvironment(environmentId, name);
      _lastActionMessage = 'Environment renamed.';
      _notify();
      return true;
    } on ArgumentError {
      _lastActionMessage = 'Enter a unique environment name.';
      _notify();
      return false;
    }
  }

  /// 删除环境，系统始终保留至少一个环境用于变量解析。
  bool deleteEnvironment(String environmentId) {
    final activeEnvironmentId = _environmentStore.activeEnvironment.id;
    final deleted = _environmentStore.deleteEnvironment(environmentId);
    if (deleted && activeEnvironmentId == environmentId) {
      _invalidateEnvironmentExecutionContext();
    }
    _lastActionMessage = deleted
        ? 'Environment deleted.'
        : 'At least one environment is required.';
    _notify();
    return deleted;
  }

  /// 指定环境是否可以删除。
  bool canDeleteEnvironment(String environmentId) =>
      _environmentStore.listEnvironments().length > 1 &&
      _environmentStore.listEnvironments().any(
        (item) => item.id == environmentId,
      );

  /// 为活动请求临时跳转到环境区块，记录来源区块以便返回。
  void openEnvironmentForActiveRequest() {
    if (!hasActiveRequest) return;
    _environmentReturnSection = _activeSection;
    _activeSection = WorkspaceSection.environments;
    _notify();
  }

  /// 从环境区块返回跳转前的来源区块。
  void returnFromEnvironment() {
    final section = _environmentReturnSection;
    _environmentReturnSection = null;
    if (section == null || !hasActiveRequest) {
      return;
    }
    _activeSection = section;
    _narrowWorkspacePanel = NarrowWorkspacePanel.request;
    _notify();
  }

  /// 选择仪表盘的时间范围。
  void selectDashboardRange(String range) {
    if (_dashboardRange == range) return;
    _dashboardRange = range;
    _notify();
  }

  /// 更新发送快捷键偏好并标记存在未保存变更。
  void updateSendShortcut(SendShortcutPreference shortcut) {
    if (_sendShortcut == shortcut) return;
    _sendShortcut = shortcut;
    _markPreferencesChanged();
  }

  /// 更新录入的发送快捷键；必须带修饰键，且不能覆盖命令面板或保存操作。
  bool updateCustomSendShortcut(ShortcutBinding binding) {
    if (!binding.hasModifier || binding.conflictsWithReservedAction()) {
      return false;
    }
    if (_sendShortcut == SendShortcutPreference.custom &&
        _customSendShortcut == binding) {
      return true;
    }
    _customSendShortcut = binding;
    _sendShortcut = SendShortcutPreference.custom;
    _markPreferencesChanged();
    return true;
  }

  /// 更新外观偏好并标记存在未保存变更。
  void updateAppearance(AppearancePreference appearance) {
    if (_appearance == appearance) return;
    _appearance = appearance;
    _markPreferencesChanged();
  }

  /// 更新语言偏好并标记存在未保存变更。
  void updateLocale(LocalePreference locale) {
    if (_locale == locale) return;
    _locale = locale;
    _markPreferencesChanged();
  }

  /// 更新应用字体偏好并标记存在未保存变更。
  void updateFont(WorkspaceFontPreference font) {
    if (_font == font) return;
    _font = font;
    _markPreferencesChanged();
  }

  /// 设置 Markdown 接口文档的输出目录；空白值恢复系统默认 Documents/sendreq。
  void updateDocumentationOutputDirectory(String? directory) {
    final normalized = directory?.trim();
    final value = normalized == null || normalized.isEmpty
        ? _defaultDocumentationOutputDirectory
        : normalized;
    if (_documentationOutputDirectory == value) {
      unawaited(_ensureInitialDocumentationOutputDirectory());
      return;
    }
    _documentationOutputDirectory = value;
    _markPreferencesChanged();
  }

  /// 从 OpenAPI JSON 文本导入整个集合，并打开其中的第一个请求。
  void importOpenApi(String source) {
    try {
      final result = const OpenApiRequestImporter().parseCollection(source);
      final collection = _assetRepository.addCollection(result.collection);
      final requests = [
        for (final folder in collection.folders)
          for (final request in folder.requests) request,
      ];
      // 新导入的集合与文件夹默认展开显示。
      _collapsedCollectionIds.remove(collection.id);
      for (final folder in collection.folders) {
        _collapsedFolderIds.remove(folder.id);
      }
      // 直接打开首个请求并复位各面板状态。
      _assetRepository.openRequestTab(requests.first.id);
      _activeRequestId = requests.first.id;
      _activeSection = WorkspaceSection.collections;
      _activeRequestTab = RequestEditorSection.params;
      _activeResponseTab = ResponseTab.body;
      _narrowWorkspacePanel = NarrowWorkspacePanel.request;
      _response = null;
      _executionError = null;
      _openedHistoryRecord = null;
      _lastActionMessage =
          '${requests.length} OpenAPI requests imported into ${collection.name}.';
    } on FormatException {
      _lastActionMessage = 'Paste valid OpenAPI JSON.';
    } on OpenApiImportException catch (error) {
      _lastActionMessage = error.message;
    }
    _notify();
  }

  /// 导出当前工作区的全部 HTTP 请求，并包含活动请求尚未保存的草稿修改。
  String exportOpenApi() => const OpenApiRequestExporter().export(
    requests: [
      for (final request in _assetRepository.listRequests())
        _requestWithDraft(request),
    ],
  );

  /// 将所有偏好重置为默认值并标记存在未保存变更。
  void resetPreferences() {
    _sendShortcut = SendShortcutPreference.controlEnter;
    _customSendShortcut = ShortcutBinding.controlEnter;
    _appearance = AppearancePreference.dark;
    _locale = LocalePreference.system;
    _font = WorkspaceFontPreference.inter;
    _documentationOutputDirectory = _defaultDocumentationOutputDirectory;
    _markPreferencesChanged();
  }

  /// 将当前偏好持久化，并向用户显示保存结果。
  ///
  /// 所有偏好改动都先在当前会话中预览；只有本操作才会写入本地存储。
  Future<void> savePreferences() async {
    try {
      await ensureDocumentationOutputDirectory();
    } on Object {
      if (_isDisposed) return;
      _hasPreferenceChanges = true;
      _lastActionMessage = 'Could not prepare documentation output folder.';
      _notify();
      return;
    }
    await _enqueuePreferenceSave(showMessage: true);
  }

  /// 等待已入队的偏好写入完成，可供受控退出流程和测试使用。
  Future<void> waitForPendingPreferenceWrites() => _preferenceSaveQueue;

  /// 标记当前会话中的预览设置尚未写入本地存储。
  void _markPreferencesChanged() {
    _hasPreferenceChanges = true;
    _lastActionMessage = null;
    _notify();
  }

  /// 确保当前文档目录存在，并返回可以交给导出器的路径。
  ///
  /// 空目录配置始终回退到默认目录。文件夹被删除时会递归创建；无权限或
  /// 路径冲突则向调用方抛出异常，以便保存和导出操作显示明确错误。
  Future<String> ensureDocumentationOutputDirectory() async {
    final normalized = _documentationOutputDirectory.trim();
    if (normalized.isEmpty) {
      _documentationOutputDirectory = _defaultDocumentationOutputDirectory;
      _hasPreferenceChanges = true;
    }
    await DocumentationOutputDirectory.ensureExists(
      _documentationOutputDirectory,
    );
    return _documentationOutputDirectory;
  }

  /// 启动时尽力恢复已保存目录，不让文件系统失败阻断工作区首次渲染。
  Future<void> _ensureInitialDocumentationOutputDirectory() async {
    try {
      await ensureDocumentationOutputDirectory();
    } on FileSystemException {
      // 保存和导出会再次等待校验，并向用户展示具体失败。
    }
  }

  /// 按变更时的快照串行写入，保证较新的配置最终覆盖较旧配置。
  Future<void> _enqueuePreferenceSave({bool showMessage = false}) {
    final snapshot = WorkspacePreferences(
      appearance: _appearance,
      sendShortcut: _sendShortcut,
      locale: _locale,
      font: _font,
      customSendShortcut: _customSendShortcut,
      documentationOutputDirectory: _documentationOutputDirectory,
    );
    final version = ++_preferenceSaveVersion;
    _preferenceSaveQueue = _preferenceSaveQueue.then((_) async {
      try {
        await _preferenceStore.save(snapshot);
        if (_isDisposed || version != _preferenceSaveVersion) return;
        _hasPreferenceChanges = false;
        if (showMessage) _lastActionMessage = 'Preferences saved.';
      } on Object {
        if (_isDisposed || version != _preferenceSaveVersion) return;
        _hasPreferenceChanges = true;
        _lastActionMessage = 'Could not save preferences. Retry.';
      }
      _notify();
    });
    return _preferenceSaveQueue;
  }

  /// 更新指定环境变量的某个字段。
  void updateEnvironmentVariable({
    required String id,
    String? key,
    String? value,
    EnvironmentVariableType? type,
  }) {
    _environmentStore.updateVariable(
      id: id,
      key: key,
      value: value,
      type: type,
    );
    _invalidateEnvironmentExecutionContext();
    _notify();
  }

  /// 新增一条环境变量。
  void addEnvironmentVariable() {
    _environmentStore.addVariable();
    _invalidateEnvironmentExecutionContext();
    _notify();
  }

  /// 新增一条全局变量。
  void addGlobalEnvironmentVariable() {
    _environmentStore.addGlobalVariable();
    _invalidateEnvironmentExecutionContext();
    _notify();
  }

  /// 删除指定环境变量。
  bool removeEnvironmentVariable(String id) {
    final removed = _environmentStore.removeVariable(id);
    if (removed) _invalidateEnvironmentExecutionContext();
    _notify();
    return removed;
  }

  /// 清理环境中未被当前认证使用、由用户确认保留的凭据变量。
  void removeUnusedEnvironmentAuthenticationVariables() {
    _environmentStore.removeUnusedAuthenticationVariables();
    _invalidateEnvironmentExecutionContext();
    _notify();
  }

  /// 切换环境变量值的可见性（明文 / 掩码）。
  void toggleEnvironmentSecretVisibility(String id) {
    _environmentStore.toggleSecretVisibility(id);
    _notify();
  }

  /// 保存当前环境的全部修改；写盘失败时保留脏状态供用户重试。
  Future<void> saveEnvironmentChanges() async {
    try {
      await _environmentStore.saveChanges();
      _lastActionMessage = 'Environment changes saved.';
    } on Object {
      _lastActionMessage = 'Could not save environment changes. Retry.';
    }
    _notify();
  }
}
