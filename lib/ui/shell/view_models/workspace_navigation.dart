import 'dart:async';

import 'package:sendreq/domain/api_assets/openapi_exchange.dart';
import 'package:sendreq/domain/environments/environment_models.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/ui/features/requests/editor/models/request_editor_models.dart';
import 'package:sendreq/ui/features/requests/output/models/response_viewer_models.dart';
import 'package:sendreq/ui/shell/models/workspace_shell_models.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 工作区导航、偏好与环境变量操作；不包含请求资产或网络执行逻辑。
extension WorkspaceNavigationOperations on WorkspaceViewModel {
  /// 打开 Collection 工作区。
  void openCollections() {
    if (internals.activeSection == WorkspaceSection.requests) return;
    internals.activeSection = WorkspaceSection.requests;
    notifyWorkspace();
  }

  /// 切换当前工作区区块。
  void selectSection(WorkspaceSection section) {
    if (internals.activeSection == section) {
      return;
    }
    internals.activeSection = section;
    notifyWorkspace();
  }

  /// 切换 Requests 的协议工作视图，不改变当前请求或活动会话。
  void selectRequestWorkingView(RequestWorkingView view) {
    final changed = internals.requestWorkingView != view;
    final sectionChanged = internals.activeSection != WorkspaceSection.requests;
    if (!changed && !sectionChanged) return;
    internals.requestWorkingView = view;
    internals.activeSection = WorkspaceSection.requests;
    notifyWorkspace();
  }

  /// 切换到指定环境作为活动环境。
  void selectEnvironment(String environmentId) {
    if (internals.environmentStore.activeEnvironment.id == environmentId) {
      return;
    }
    unawaited(internals.environmentStore.setActiveEnvironment(environmentId));
    invalidateEnvironmentExecutionContextInternal();
    notifyWorkspace();
  }

  /// 只改变管理器编辑目标，不改变下一次请求使用的环境。
  void selectEnvironmentForEditing(String environmentId) {
    internals.environmentStore.listEnvironments().firstWhere(
      (environment) => environment.id == environmentId,
    );
    if (internals.editingEnvironmentId == environmentId) return;
    internals.editingEnvironmentId = environmentId;
    notifyWorkspace();
  }

  /// 将当前编辑目标显式设为下一次请求使用的环境。
  void useEditingEnvironmentForRequests() {
    selectEnvironment(editingEnvironment.id);
  }

  /// 新建环境并切换到它；无效或重复名称保留当前环境不变。
  bool createEnvironment(String name) {
    try {
      final environment = internals.environmentStore.createEnvironment(
        name,
        activate: false,
      );
      internals.editingEnvironmentId = environment.id;
      internals.recordUserMessage(
        'Environment created.',
        deduplicationKey: 'environment.created',
      );
      notifyWorkspace();
      return true;
    } on ArgumentError {
      internals.lastActionMessage = 'Enter a unique environment name.';
      notifyWorkspace();
      return false;
    }
  }

  /// 重命名环境；无效或重复名称不会覆盖原名称。
  bool renameEnvironment(String environmentId, String name) {
    try {
      internals.environmentStore.renameEnvironment(environmentId, name);
      internals.recordUserMessage(
        'Environment renamed.',
        deduplicationKey: 'environment.renamed',
      );
      notifyWorkspace();
      return true;
    } on ArgumentError {
      internals.lastActionMessage = 'Enter a unique environment name.';
      notifyWorkspace();
      return false;
    }
  }

  /// 删除环境，系统始终保留至少一个环境用于变量解析。
  bool deleteEnvironment(String environmentId) {
    final activeEnvironmentId = internals.environmentStore.activeEnvironment.id;
    final deleted = internals.environmentStore.deleteEnvironment(environmentId);
    if (deleted && activeEnvironmentId == environmentId) {
      invalidateEnvironmentExecutionContextInternal();
    }
    if (deleted && internals.editingEnvironmentId == environmentId) {
      internals.editingEnvironmentId =
          internals.environmentStore.activeEnvironment.id;
    }
    if (deleted) {
      internals.recordUserMessage(
        'Environment deleted.',
        deduplicationKey: 'environment.deleted',
      );
    } else {
      internals.lastActionMessage = 'At least one environment is required.';
    }
    notifyWorkspace();
    return deleted;
  }

  /// 指定环境是否可以删除。
  bool canDeleteEnvironment(String environmentId) =>
      internals.environmentStore.listEnvironments().length > 1 &&
      internals.environmentStore.listEnvironments().any(
        (item) => item.id == environmentId,
      );

  /// 打开 Requests 局部 Environment 管理层。
  void openEnvironmentManager() {
    internals.editingEnvironmentId =
        internals.environmentStore.activeEnvironment.id;
    internals.environmentManagerOpen = true;
    notifyWorkspace();
  }

  /// 关闭 Environment 管理层并返回原 Request。
  void returnFromEnvironment() {
    if (!internals.environmentManagerOpen) return;
    internals.environmentManagerOpen = false;
    internals.editingEnvironmentId = null;
    internals.narrowWorkspacePanel = NarrowWorkspacePanel.request;
    notifyWorkspace();
  }

  /// 从 OpenAPI JSON 文本导入整个集合，并打开其中的第一个请求。
  void importOpenApi(String source) {
    try {
      final preview = internals.openApiImporter.preview(source);
      final collection = internals.assetRepository.addCollection(
        preview.collection,
      );
      final requests = [
        for (final folder in collection.folders)
          for (final request in folder.requests) request,
      ];
      // 新导入的集合与文件夹默认展开显示。
      internals.collapsedCollectionIds.remove(collection.id);
      for (final folder in collection.folders) {
        internals.collapsedFolderIds.remove(folder.id);
      }
      // 直接打开首个请求并复位各面板状态。
      internals.assetRepository.openRequestTab(requests.first.id);
      internals.activeRequestId = requests.first.id;
      internals.activeSection = WorkspaceSection.requests;
      internals.activeRequestTab = RequestEditorSection.params;
      internals.activeResponseTab = ResponseTab.body;
      internals.narrowWorkspacePanel = NarrowWorkspacePanel.request;
      internals.response = null;
      internals.currentExecutionResult = null;
      internals.executionError = null;
      internals.recordUserMessage(
        '${requests.length} OpenAPI requests imported into ${collection.name}.',
        deduplicationKey: 'openapi.import.succeeded',
      );
    } on FormatException {
      internals.lastActionMessage = 'Paste valid OpenAPI JSON.';
    } on Object {
      internals.lastActionMessage = 'Could not import OpenAPI. Retry.';
      unawaited(
        internals.feedbackDispatcher.dispatchOutcome(
          OperationOutcome(
            kind: OperationOutcomeKind.failed,
            code: 'collection.importFailed',
            resourceRef: const ResourceRef(
              kind: ResourceKind.collection,
              id: 'openapi-import',
            ),
          ),
          message: internals.lastActionMessage,
        ),
      );
    }
    notifyWorkspace();
  }

  /// 导出当前工作区的全部 HTTP 请求，并包含活动请求尚未保存的草稿修改。
  String exportOpenApi() => internals.openApiExporter.serialize(
    OpenApiExportSnapshot(
      requests: [
        for (final request in internals.assetRepository.listRequests())
          requestWithDraftInternal(request),
      ],
    ),
  );

  /// 通过组合根注入的端口写入 OpenAPI；Widget 只消费返回的显示路径。
  Future<String> exportOpenApiToDefaultDirectory() async {
    final result = await internals.openApiFileExporter.write(
      OpenApiFileExportRequest(
        outputDirectory: await ensureOpenApiOutputDirectory(),
        source: exportOpenApi(),
      ),
    );
    return result.path;
  }

  Future<String> readOpenApiFile(String path) =>
      internals.openApiFileReader.read(path);

  Future<String> downloadResponseBody(String body) =>
      internals.responseBodyDownload.save(body);

  /// 更新指定环境变量的某个字段。
  void updateEnvironmentVariable({
    required String id,
    String? key,
    String? value,
    EnvironmentVariableType? type,
  }) {
    internals.environmentStore.updateVariable(
      id: id,
      environmentId: editingEnvironment.id,
      key: key,
      value: value,
      type: type,
    );
    if (isEditingActiveEnvironment) {
      invalidateEnvironmentExecutionContextInternal();
    }
    notifyWorkspace();
  }

  /// 新增一条环境变量。
  void addEnvironmentVariable() {
    internals.environmentStore.addVariable(
      environmentId: editingEnvironment.id,
    );
    if (isEditingActiveEnvironment) {
      invalidateEnvironmentExecutionContextInternal();
    }
    notifyWorkspace();
  }

  /// 新增一条全局变量。
  void addGlobalEnvironmentVariable() {
    internals.environmentStore.addGlobalVariable();
    invalidateEnvironmentExecutionContextInternal();
    notifyWorkspace();
  }

  /// 删除指定环境变量。
  bool removeEnvironmentVariable(String id) {
    final removed = internals.environmentStore.removeVariable(id);
    if (removed && isEditingActiveEnvironment) {
      invalidateEnvironmentExecutionContextInternal();
    }
    notifyWorkspace();
    return removed;
  }

  /// 清理环境中未被当前认证使用、由用户确认保留的凭据变量。
  void removeUnusedEnvironmentAuthenticationVariables() {
    internals.environmentStore.removeUnusedAuthenticationVariables(
      environmentId: editingEnvironment.id,
    );
    if (isEditingActiveEnvironment) {
      invalidateEnvironmentExecutionContextInternal();
    }
    notifyWorkspace();
  }

  /// 切换环境变量值的可见性（明文 / 掩码）。
  void toggleEnvironmentSecretVisibility(String id) {
    internals.environmentStore.toggleSecretVisibility(id);
    notifyWorkspace();
  }

  /// 保存当前环境的全部修改；写盘失败时保留脏状态供用户重试。
  Future<void> saveEnvironmentChanges() async {
    late final OperationOutcome outcome;
    try {
      await internals.environmentStore.saveChanges();
      internals.lastActionMessage = 'Environment changes saved.';
      outcome = OperationOutcome(
        kind: OperationOutcomeKind.success,
        code: 'environment.saved',
        resourceRef: ResourceRef(
          kind: ResourceKind.environment,
          id: editingEnvironment.id,
        ),
      );
    } on Object {
      internals.lastActionMessage =
          'Could not save environment changes. Retry.';
      outcome = OperationOutcome(
        kind: OperationOutcomeKind.failed,
        code: 'environment.saveFailed',
        resourceRef: ResourceRef(
          kind: ResourceKind.environment,
          id: editingEnvironment.id,
        ),
      );
    }
    await internals.feedbackDispatcher.dispatchOutcome(
      outcome,
      message: internals.lastActionMessage,
    );
    notifyWorkspace();
  }

  /// 放弃未提交的环境配置编辑，同时保留仍然有效的活动环境选择。
  void discardEnvironmentChanges() {
    if (!internals.environmentStore.hasUnsavedChanges) return;
    internals.environmentStore.discardChanges();
    invalidateEnvironmentExecutionContextInternal();
    internals.recordUserMessage(
      'Environment changes discarded.',
      deduplicationKey: 'environment.changes.discarded',
    );
    notifyWorkspace();
  }
}
