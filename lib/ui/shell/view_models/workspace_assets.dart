import 'dart:async';

import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/ui/features/requests/editor/models/request_editor_models.dart';
import 'package:sendreq/ui/features/requests/output/models/response_viewer_models.dart';
import 'package:sendreq/ui/shell/models/workspace_shell_models.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 集合、文件夹、标签页与 HTTP 请求基础编辑操作。
extension WorkspaceAssetOperations on WorkspaceViewModel {
  /// 打开并选中指定请求，复位编辑与响应面板状态。
  void selectRequest(String requestId) {
    final request = internals.assetRepository.getRequest(requestId);
    internals.assetRepository.openRequestTab(requestId);
    internals.activeSection = WorkspaceSection.requests;
    internals.activeRequestId = requestId;
    internals.activeRequestTab = _initialEditorTab(request.protocol);
    internals.narrowWorkspacePanel = NarrowWorkspacePanel.request;
    internals.response = null;
    internals.currentExecutionResult = null;
    notifyWorkspace();
    unawaited(restoreGrpcSchemaInternal(request));
  }

  /// 新建请求；未指定归属时沿用当前活动请求的集合与文件夹。
  void createRequest({
    String? collectionId,
    String? folderId,
    ApiRequestProtocol? protocol,
  }) {
    if (collectionId == null &&
        folderId == null &&
        internals.activeRequestId != null) {
      final active = internals.assetRepository.getRequest(
        internals.activeRequestId!,
      );
      collectionId = active.collectionId;
      folderId = active.folderId;
    }
    final request = internals.assetRepository.createRequest(
      collectionId: collectionId,
      folderId: folderId,
      protocol:
          protocol ??
          internals.requestWorkingView.protocol ??
          ApiRequestProtocol.http,
    );
    internals.collapsedCollectionIds.remove(request.collectionId);
    internals.collapsedFolderIds.remove(request.folderId);
    _openRequestDraft(request);
  }

  /// 新建集合并附带创建一个请求，随后打开该请求的草稿。
  void createCollection() {
    final collection = internals.assetRepository.createCollection();
    final request = internals.assetRepository.createRequest(
      collectionId: collection.id,
    );
    internals.collapsedCollectionIds.remove(collection.id);
    internals.recordUserMessage(
      '${collection.name} created.',
      deduplicationKey: 'collection.created',
    );
    _openRequestDraft(request);
  }

  /// 追加安装包内置的协议示例，不修改或替换已有集合。
  void loadDemoExample() {
    final collection = internals.assetRepository.addCollection(
      internals.demoCollection,
    );
    final request = collection.folders.first.requests.first;
    internals.collapsedCollectionIds.remove(collection.id);
    internals.collapsedFolderIds.remove(request.folderId);
    internals.recordUserMessage(
      'Demo example loaded.',
      deduplicationKey: 'collection.demo.loaded',
    );
    _openRequestDraft(request);
  }

  /// 在指定集合下新建文件夹。
  void createFolder(String collectionId) {
    final folder = internals.assetRepository.createFolder(
      collectionId: collectionId,
    );
    internals.collapsedCollectionIds.remove(collectionId);
    internals.collapsedFolderIds.remove(folder.id);
    internals.recordUserMessage(
      '${folder.name} created.',
      deduplicationKey: 'folder.created',
    );
    notifyWorkspace();
  }

  /// 删除整个集合及其下所有请求。
  void deleteCollection(String collectionId) {
    // 先收集待删除的文件夹与请求 ID，便于后续清理相关状态。
    final removedCollection = internals.assetRepository
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
        internals.activeRequestId != null &&
        removedRequestIds.contains(internals.activeRequestId);
    // 取消正在进行的执行，并异步释放相关 WebSocket 会话。
    cancelExecutionForInternal(removedRequestIds);
    for (final requestId in removedRequestIds) {
      unawaited(
        internals.webSocketSessions.disposeRequest(RequestRef(id: requestId)),
      );
      unawaited(internals.grpcCalls.disposeRequest(RequestRef(id: requestId)));
    }
    internals.assetRepository.deleteCollection(collectionId);
    internals.collapsedCollectionIds.remove(collectionId);
    internals.collapsedFolderIds.removeAll(removedFolderIds);
    for (final requestId in removedRequestIds) {
      internals.draftOverrides.remove(requestId);
    }
    // 删除后若活动请求被移除，则自动切到仓库中的剩余请求。
    internals.activeRequestId = internals.assetRepository.activeRequestId;
    _selectRemainingRequestIfNeeded();
    if (activeRequestWasRemoved) {
      internals.response = null;
      internals.executionError = null;
      internals.currentExecutionResult = null;
    }
    internals.activeSection = WorkspaceSection.requests;
    internals.recordUserMessage(
      'Collection deleted.',
      deduplicationKey: 'collection.deleted',
    );
    notifyWorkspace();
  }

  /// 删除指定文件夹及其下所有请求。
  void deleteFolder({required String collectionId, required String folderId}) {
    final removedFolder = internals.assetRepository
        .listCollections()
        .where((collection) => collection.id == collectionId)
        .expand((collection) => collection.folders)
        .where((folder) => folder.id == folderId)
        .first;
    final removedRequestIds = {
      for (final request in removedFolder.requests) request.id,
    };
    final activeRequestWasRemoved =
        internals.activeRequestId != null &&
        removedRequestIds.contains(internals.activeRequestId);
    cancelExecutionForInternal(removedRequestIds);
    for (final requestId in removedRequestIds) {
      unawaited(
        internals.webSocketSessions.disposeRequest(RequestRef(id: requestId)),
      );
      unawaited(internals.grpcCalls.disposeRequest(RequestRef(id: requestId)));
    }
    internals.assetRepository.deleteFolder(
      collectionId: collectionId,
      folderId: folderId,
    );
    internals.collapsedFolderIds.remove(folderId);
    for (final requestId in removedRequestIds) {
      internals.draftOverrides.remove(requestId);
    }
    internals.activeRequestId = activeRequestWasRemoved
        ? null
        : internals.assetRepository.activeRequestId;
    _selectRemainingRequestIfNeeded(preferredCollectionId: collectionId);
    if (activeRequestWasRemoved) {
      internals.response = null;
      internals.executionError = null;
      internals.currentExecutionResult = null;
    }
    internals.activeSection = WorkspaceSection.requests;
    internals.recordUserMessage(
      'Folder deleted.',
      deduplicationKey: 'folder.deleted',
    );
    notifyWorkspace();
  }

  /// 重命名请求，空名称会被忽略。
  void renameRequest(String requestId, String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    internals.assetRepository.renameRequest(requestId, normalized);
    internals.recordUserMessage(
      'Request renamed.',
      deduplicationKey: 'request.renamed',
    );
    notifyWorkspace();
  }

  /// 删除单个请求，若为活动请求则切换选中并复位相关状态。
  void deleteRequest(String requestId) {
    final removedRequest = internals.assetRepository.getRequest(requestId);
    final activeRequestWasRemoved = internals.activeRequestId == requestId;
    cancelExecutionForInternal({requestId});
    unawaited(
      internals.webSocketSessions.disposeRequest(RequestRef(id: requestId)),
    );
    unawaited(internals.grpcCalls.disposeRequest(RequestRef(id: requestId)));
    internals.assetRepository.deleteRequest(requestId);
    internals.draftOverrides.remove(requestId);
    internals.activeRequestId = activeRequestWasRemoved
        ? null
        : internals.assetRepository.activeRequestId;
    _selectRemainingRequestIfNeeded(
      preferredCollectionId: removedRequest.collectionId,
    );
    if (activeRequestWasRemoved) {
      internals.response = null;
      internals.executionError = null;
      internals.currentExecutionResult = null;
    }
    internals.activeSection = WorkspaceSection.requests;
    internals.recordUserMessage(
      'Request deleted.',
      deduplicationKey: 'request.deleted',
    );
    notifyWorkspace();
  }

  /// 重命名集合，空名称会被忽略。
  void renameCollection(String collectionId, String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    internals.assetRepository.renameCollection(collectionId, normalized);
    internals.recordUserMessage(
      'Collection renamed.',
      deduplicationKey: 'collection.renamed',
    );
    notifyWorkspace();
  }

  /// 重命名文件夹，空名称会被忽略。
  void renameFolder({
    required String collectionId,
    required String folderId,
    required String name,
  }) {
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    internals.assetRepository.renameFolder(
      collectionId: collectionId,
      folderId: folderId,
      name: normalized,
    );
    internals.recordUserMessage(
      'Folder renamed.',
      deduplicationKey: 'folder.renamed',
    );
    notifyWorkspace();
  }

  /// 打开新请求的编辑草稿：打开标签页、以仓库定义初始化覆盖草稿并复位面板。
  void _openRequestDraft(ApiRequestDefinition request) {
    internals.assetRepository.openRequestTab(request.id);
    // 以可编辑草稿形式打开，保存前不写回仓库。
    internals.draftOverrides[request.id] = toRequestDraftInternal(request);
    internals.activeSection = WorkspaceSection.requests;
    internals.activeRequestId = request.id;
    internals.activeRequestTab = _initialEditorTab(request.protocol);
    internals.activeResponseTab = ResponseTab.body;
    internals.narrowWorkspacePanel = NarrowWorkspacePanel.request;
    internals.response = null;
    internals.executionError = null;
    internals.currentExecutionResult = null;
    notifyWorkspace();
    unawaited(restoreGrpcSchemaInternal(request));
  }

  /// 若当前没有活动请求，则自动选中仓库中的第一个剩余请求。
  void _selectRemainingRequestIfNeeded({String? preferredCollectionId}) {
    if (internals.activeRequestId != null) return;
    final remainingRequests = internals.assetRepository.listRequests();
    if (remainingRequests.isEmpty) return;
    final request = preferredCollectionId == null
        ? remainingRequests.first
        : remainingRequests.firstWhere(
            (request) => request.collectionId == preferredCollectionId,
            orElse: () => remainingRequests.first,
          );
    internals.assetRepository.openRequestTab(request.id);
    internals.activeRequestId = request.id;
  }

  /// 切换到指定请求标签页并打开对应请求。
  void selectRequestTab(String tabId) {
    internals.assetRepository.activateRequestTab(tabId);
    internals.activeRequestId = internals.assetRepository.activeRequestId;
    internals.activeSection = WorkspaceSection.requests;
    final requestId = internals.activeRequestId;
    internals.activeRequestTab = requestId == null
        ? RequestEditorSection.params
        : _initialEditorTab(
            internals.assetRepository.getRequest(requestId).protocol,
          );
    internals.narrowWorkspacePanel = NarrowWorkspacePanel.request;
    internals.currentExecutionResult = null;
    notifyWorkspace();
    if (requestId != null) {
      unawaited(
        restoreGrpcSchemaInternal(
          internals.assetRepository.getRequest(requestId),
        ),
      );
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
      unawaited(
        internals.webSocketSessions.disposeRequest(
          RequestRef(id: tab.requestId),
        ),
      );
      unawaited(
        internals.grpcCalls.disposeRequest(RequestRef(id: tab.requestId)),
      );
      internals.assetRepository.closeRequestTab(tab.id);
    }
    // 关闭后重新定位活动请求；全部关闭时保留 Requests 空状态。
    internals.activeRequestId = internals.assetRepository.activeRequestId;
    internals.activeSection = WorkspaceSection.requests;
    notifyWorkspace();
  }

  /// 选择请求编辑器的子标签页（参数 / 请求头 / 请求体等）。
  void selectRequestEditorTab(String tab) {
    // 未知的标签 ID 回退到默认的参数页。
    final section = RequestEditorSection.values.firstWhere(
      (section) => section.id == tab,
      orElse: () => RequestEditorSection.params,
    );
    if (internals.activeRequestTab == section) {
      return;
    }
    internals.activeRequestTab = section;
    notifyWorkspace();
  }

  /// 更新活动请求的 URL，拆分基础地址、路径与 query 参数以保持 Params 同步。
  void updateActiveDraftUrl(String url) {
    updateActiveDraftInternal(
      internals.draftEditor.replaceUrl(
        draft: activeDraft,
        url: url,
        nextParameterId: () =>
            '${internals.activeRequestId!}:param:url-${internals.draftFieldSequence++}',
        environmentVariableKeys: internals.environmentStore.listVariables().map(
          (variable) => variable.key,
        ),
      ),
    );
  }

  /// 更新活动请求的 HTTP 方法。
  ///
  /// GET / HEAD 没有请求体语义。已有正文先保存在草稿中，以便用户切回
  /// POST 等方法时继续编辑，但不会再显示或发送。
  void updateActiveDraftMethod(String method) {
    final normalizedMethod = method.toUpperCase();
    updateActiveDraftInternal(activeDraft.copyWith(method: normalizedMethod));
    if (isBodylessHttpMethodInternal(normalizedMethod) &&
        internals.activeRequestTab == RequestEditorSection.body) {
      internals.activeRequestTab = RequestEditorSection.params;
      notifyWorkspace();
    }
  }
}

/// 根据协议选择第一个有意义的编辑面，避免 gRPC 停留在 HTTP Params。
RequestEditorSection _initialEditorTab(ApiRequestProtocol protocol) =>
    switch (protocol) {
      ApiRequestProtocol.http => RequestEditorSection.params,
      ApiRequestProtocol.webSocket => RequestEditorSection.protocol,
      ApiRequestProtocol.grpc => RequestEditorSection.body,
    };
