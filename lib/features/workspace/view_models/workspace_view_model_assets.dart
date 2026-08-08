part of 'workspace_view_model.dart';

/// 集合、文件夹、标签页与 HTTP 请求基础编辑操作。
extension WorkspaceAssetOperations on WorkspaceViewModel {
  /// 打开并选中指定请求，复位编辑与响应面板状态。
  void selectRequest(String requestId) {
    final request = _assetRepository.getRequest(requestId);
    _assetRepository.openRequestTab(requestId);
    _activeSection = WorkspaceSection.collections;
    _activeRequestId = requestId;
    _activeRequestTab = RequestEditorSection.params;
    _narrowWorkspacePanel = NarrowWorkspacePanel.request;
    _response = null;
    _openedHistoryRecord = null;
    _notify();
    unawaited(_restoreGrpcSchema(request));
  }

  /// 新建请求；未指定归属时沿用当前活动请求的集合与文件夹。
  void createRequest({String? collectionId, String? folderId}) {
    if (collectionId == null && folderId == null && _activeRequestId != null) {
      final active = _assetRepository.getRequest(_activeRequestId!);
      collectionId = active.collectionId;
      folderId = active.folderId;
    }
    final request = _assetRepository.createRequest(
      collectionId: collectionId,
      folderId: folderId,
    );
    _collapsedCollectionIds.remove(request.collectionId);
    _collapsedFolderIds.remove(request.folderId);
    _openRequestDraft(request);
  }

  /// 新建集合并附带创建一个请求，随后打开该请求的草稿。
  void createCollection() {
    final collection = _assetRepository.createCollection();
    final request = _assetRepository.createRequest(collectionId: collection.id);
    _collapsedCollectionIds.remove(collection.id);
    _lastActionMessage = '${collection.name} created.';
    _openRequestDraft(request);
  }

  /// 追加安装包内置的协议示例，不修改或替换已有集合。
  void loadDemoExample() {
    final collection = _assetRepository.addCollection(
      DemoExampleCatalog.collection,
    );
    final request = collection.folders.first.requests.first;
    _collapsedCollectionIds.remove(collection.id);
    _collapsedFolderIds.remove(request.folderId);
    _lastActionMessage = 'Demo example loaded.';
    _openRequestDraft(request);
  }

  /// 在指定集合下新建文件夹。
  void createFolder(String collectionId) {
    final folder = _assetRepository.createFolder(collectionId: collectionId);
    _collapsedCollectionIds.remove(collectionId);
    _collapsedFolderIds.remove(folder.id);
    _lastActionMessage = '${folder.name} created.';
    _notify();
  }

  /// 删除整个集合及其下所有请求。
  void deleteCollection(String collectionId) {
    // 先收集待删除的文件夹与请求 ID，便于后续清理相关状态。
    final removedCollection = _assetRepository
        .listCollections()
        .where((collection) => collection.id == collectionId)
        .first;
    final removedFolderIds = removedCollection.folders
        .map((folder) => folder.id)
        .toSet();
    final removedRequestIds = {
      for (final folder in removedCollection.folders)
        for (final request in folder.requests) request.id,
    };
    final activeRequestWasRemoved =
        _activeRequestId != null &&
        removedRequestIds.contains(_activeRequestId);
    // 取消正在进行的执行，并异步释放相关 WebSocket 会话。
    _cancelExecutionFor(removedRequestIds);
    for (final requestId in removedRequestIds) {
      unawaited(_webSocketSessions.disposeRequest(requestId));
      unawaited(_grpcCalls.disposeRequest(requestId));
    }
    _assetRepository.deleteCollection(collectionId);
    _collapsedCollectionIds.remove(collectionId);
    _collapsedFolderIds.removeAll(removedFolderIds);
    for (final requestId in removedRequestIds) {
      _draftOverrides.remove(requestId);
    }
    // 删除后若活动请求被移除，则自动切到仓库中的剩余请求。
    _activeRequestId = _assetRepository.activeRequestId;
    _selectRemainingRequestIfNeeded();
    if (activeRequestWasRemoved) {
      _response = null;
      _executionError = null;
      _openedHistoryRecord = null;
    }
    _activeSection = WorkspaceSection.collections;
    _lastActionMessage = 'Collection deleted.';
    _notify();
  }

  /// 删除指定文件夹及其下所有请求。
  void deleteFolder({required String collectionId, required String folderId}) {
    final removedFolder = _assetRepository
        .listCollections()
        .where((collection) => collection.id == collectionId)
        .expand((collection) => collection.folders)
        .where((folder) => folder.id == folderId)
        .first;
    final removedRequestIds = {
      for (final request in removedFolder.requests) request.id,
    };
    final activeRequestWasRemoved =
        _activeRequestId != null &&
        removedRequestIds.contains(_activeRequestId);
    _cancelExecutionFor(removedRequestIds);
    for (final requestId in removedRequestIds) {
      unawaited(_webSocketSessions.disposeRequest(requestId));
      unawaited(_grpcCalls.disposeRequest(requestId));
    }
    _assetRepository.deleteFolder(
      collectionId: collectionId,
      folderId: folderId,
    );
    _collapsedFolderIds.remove(folderId);
    for (final requestId in removedRequestIds) {
      _draftOverrides.remove(requestId);
    }
    _activeRequestId = _assetRepository.activeRequestId;
    _selectRemainingRequestIfNeeded();
    if (activeRequestWasRemoved) {
      _response = null;
      _executionError = null;
      _openedHistoryRecord = null;
    }
    _activeSection = WorkspaceSection.collections;
    _lastActionMessage = 'Folder deleted.';
    _notify();
  }

  /// 重命名请求，空名称会被忽略。
  void renameRequest(String requestId, String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    _assetRepository.renameRequest(requestId, normalized);
    _lastActionMessage = 'Request renamed.';
    _notify();
  }

  /// 删除单个请求，若为活动请求则切换选中并复位相关状态。
  void deleteRequest(String requestId) {
    final activeRequestWasRemoved = _activeRequestId == requestId;
    _cancelExecutionFor({requestId});
    unawaited(_webSocketSessions.disposeRequest(requestId));
    unawaited(_grpcCalls.disposeRequest(requestId));
    _assetRepository.deleteRequest(requestId);
    _draftOverrides.remove(requestId);
    _activeRequestId = _assetRepository.activeRequestId;
    _selectRemainingRequestIfNeeded();
    if (activeRequestWasRemoved) {
      _response = null;
      _executionError = null;
      _openedHistoryRecord = null;
    }
    _activeSection = WorkspaceSection.collections;
    _lastActionMessage = 'Request deleted.';
    _notify();
  }

  /// 重命名集合，空名称会被忽略。
  void renameCollection(String collectionId, String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    _assetRepository.renameCollection(collectionId, normalized);
    _lastActionMessage = 'Collection renamed.';
    _notify();
  }

  /// 重命名文件夹，空名称会被忽略。
  void renameFolder({
    required String collectionId,
    required String folderId,
    required String name,
  }) {
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    _assetRepository.renameFolder(
      collectionId: collectionId,
      folderId: folderId,
      name: normalized,
    );
    _lastActionMessage = 'Folder renamed.';
    _notify();
  }

  /// 打开新请求的编辑草稿：打开标签页、以仓库定义初始化覆盖草稿并复位面板。
  void _openRequestDraft(ApiRequestDefinition request) {
    _assetRepository.openRequestTab(request.id);
    // 以可编辑草稿形式打开，保存前不写回仓库。
    _draftOverrides[request.id] = _toRequestDraft(request);
    _activeSection = WorkspaceSection.collections;
    _activeRequestId = request.id;
    _activeRequestTab = RequestEditorSection.params;
    _activeResponseTab = ResponseTab.body;
    _narrowWorkspacePanel = NarrowWorkspacePanel.request;
    _response = null;
    _executionError = null;
    _openedHistoryRecord = null;
    _notify();
    unawaited(_restoreGrpcSchema(request));
  }

  /// 若当前没有活动请求，则自动选中仓库中的第一个剩余请求。
  void _selectRemainingRequestIfNeeded() {
    if (_activeRequestId != null) return;
    final remainingRequests = _assetRepository.listRequests();
    if (remainingRequests.isEmpty) return;
    final request = remainingRequests.first;
    _assetRepository.openRequestTab(request.id);
    _activeRequestId = request.id;
  }

  /// 切换到指定请求标签页并打开对应请求。
  void selectRequestTab(String tabId) {
    _assetRepository.activateRequestTab(tabId);
    _activeRequestId = _assetRepository.activeRequestId;
    _activeSection = WorkspaceSection.collections;
    _activeRequestTab = RequestEditorSection.params;
    _narrowWorkspacePanel = NarrowWorkspacePanel.request;
    _openedHistoryRecord = null;
    _notify();
    final requestId = _activeRequestId;
    if (requestId != null) {
      unawaited(_restoreGrpcSchema(_assetRepository.getRequest(requestId)));
    }
  }

  /// 关闭单个请求标签页。
  void closeRequestTab(String tabId) {
    _closeRequestTabs({tabId});
  }

  /// 批量关闭请求标签页，一次重绘完成全部关闭操作。
  void closeRequestTabs(Iterable<String> tabIds) {
    _closeRequestTabs(tabIds.toSet());
  }

  /// 关闭标签页的公共实现，同时释放对应 WebSocket 会话。
  void _closeRequestTabs(Set<String> tabIds) {
    if (tabIds.isEmpty) return;
    final tabs = openRequestTabs.where((tab) => tabIds.contains(tab.id));
    for (final tab in tabs) {
      unawaited(_webSocketSessions.disposeRequest(tab.requestId));
      unawaited(_grpcCalls.disposeRequest(tab.requestId));
      _assetRepository.closeRequestTab(tab.id);
    }
    // 关闭后重新定位活动请求；全部关闭时回到仪表盘。
    _activeRequestId = _assetRepository.activeRequestId;
    if (_activeRequestId == null) {
      _activeSection = WorkspaceSection.dashboard;
    }
    _notify();
  }

  /// 选择请求编辑器的子标签页（参数 / 请求头 / 请求体等）。
  void selectRequestEditorTab(String tab) {
    // 未知的标签 ID 回退到默认的参数页。
    final section = RequestEditorSection.values.firstWhere(
      (section) => section.id == tab,
      orElse: () => RequestEditorSection.params,
    );
    if (_activeRequestTab == section) {
      return;
    }
    _activeRequestTab = section;
    _notify();
  }

  /// 更新活动请求的 URL，拆分基础地址、路径与 query 参数以保持 Params 同步。
  void updateActiveDraftUrl(String url) {
    final parts = _splitDraftUrl(url);
    _updateActiveDraft(
      activeDraft.copyWith(
        baseUrlToken: parts.baseUrlToken,
        path: parts.path,
        params: [
          for (final (index, parameter) in parts.parameters.indexed)
            KeyValueRow(
              id: '${_activeRequestId!}:param:url-$index-${_draftFieldSequence++}',
              keyName: parameter.key,
              value: _normalizeEnvironmentParameterReference(parameter.value),
              enabled: true,
            ),
        ],
      ),
    );
  }

  /// 更新活动请求的 HTTP 方法。
  ///
  /// GET / HEAD 没有请求体语义。已有正文先保存在草稿中，以便用户切回
  /// POST 等方法时继续编辑，但不会再显示或发送。
  void updateActiveDraftMethod(String method) {
    final normalizedMethod = method.toUpperCase();
    _updateActiveDraft(activeDraft.copyWith(method: normalizedMethod));
    if (_isBodylessHttpMethod(normalizedMethod) &&
        _activeRequestTab == RequestEditorSection.body) {
      _activeRequestTab = RequestEditorSection.params;
      _notify();
    }
  }
}
