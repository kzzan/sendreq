import 'dart:async';
import 'dart:convert';

import '../../domain/authentication/request_authentication.dart';
import '../../domain/environments/environment_models.dart';
import '../../domain/repositories/environment_store.dart';
import '../database/isar_workspace.dart';
import '../database/isar_workspace_models.dart';
import 'file_environment_store.dart';
import 'in_memory_environment_store.dart';

/// 使用 Isar 工作区文档持久化环境、变量与认证配置。
///
/// 领域层继续依赖 [EnvironmentStore]；JSON 文件仅在首次迁移时作为来源和备份。
class IsarEnvironmentStore implements EnvironmentStore {
  IsarEnvironmentStore._(this._workspace, this._delegate);

  static const _workspaceKey = 'environments-v1';

  final IsarWorkspace _workspace;
  final InMemoryEnvironmentStore _delegate;

  /// 串行化保存请求，防止连续点击保存时旧快照覆盖新状态。
  Future<void> _writeQueue = Future<void>.value();

  /// 加载 Isar 环境快照；首次启动时迁移旧 JSON 并保留备份。
  static Future<IsarEnvironmentStore> load({
    required IsarWorkspace workspace,
    FileEnvironmentStore? legacyStore,
  }) async {
    final document = await workspace.instance.workspaceDocuments.getByKey(
      _workspaceKey,
    );
    if (document != null) {
      try {
        final decoded = jsonDecode(document.payloadJson);
        if (decoded is! Map) throw const FormatException('Invalid environment');
        return IsarEnvironmentStore._(
          workspace,
          InMemoryEnvironmentStore.fromJson(Map<String, dynamic>.from(decoded)),
        );
      } on Object {
        throw const FormatException('Stored Isar environments are invalid.');
      }
    }

    final delegate = legacyStore == null
        ? InMemoryEnvironmentStore.sample()
        : InMemoryEnvironmentStore.fromJson(
            Map<String, dynamic>.from(legacyStore.exportSnapshot()),
          );
    if (legacyStore != null) await legacyStore.backupIfPresent();
    final store = IsarEnvironmentStore._(workspace, delegate);
    await store._write();
    return store;
  }

  @override
  List<EnvironmentProfile> listEnvironments() => _delegate.listEnvironments();

  @override
  EnvironmentProfile get activeEnvironment => _delegate.activeEnvironment;

  @override
  void updateActiveAuthentication(RequestAuthentication authentication) =>
      _delegate.updateActiveAuthentication(authentication);

  @override
  List<EnvironmentVariableView> listVariables() => _delegate.listVariables();

  @override
  List<String> listUnusedAuthenticationVariableNames() =>
      _delegate.listUnusedAuthenticationVariableNames();

  @override
  void removeUnusedAuthenticationVariables() =>
      _delegate.removeUnusedAuthenticationVariables();

  @override
  bool get hasUnsavedChanges => _delegate.hasUnsavedChanges;

  @override
  void setActiveEnvironment(String environmentId) =>
      _delegate.setActiveEnvironment(environmentId);

  @override
  EnvironmentProfile createEnvironment(String name) =>
      _delegate.createEnvironment(name);

  @override
  void renameEnvironment(String environmentId, String name) =>
      _delegate.renameEnvironment(environmentId, name);

  @override
  bool deleteEnvironment(String environmentId) =>
      _delegate.deleteEnvironment(environmentId);

  @override
  void updateVariable({
    required String id,
    String? key,
    String? value,
    EnvironmentVariableType? type,
  }) => _delegate.updateVariable(id: id, key: key, value: value, type: type);

  @override
  void addVariable() => _delegate.addVariable();

  @override
  void addGlobalVariable() => _delegate.addGlobalVariable();

  @override
  bool removeVariable(String id) => _delegate.removeVariable(id);

  @override
  void toggleSecretVisibility(String id) =>
      _delegate.toggleSecretVisibility(id);

  /// 显式保存当前环境快照；写入成功后才清除未保存标记。
  @override
  Future<void> saveChanges() {
    _writeQueue = _writeQueue.then((_) async {
      await _write();
      await _delegate.saveChanges();
    });
    return _writeQueue;
  }

  /// 受控退出或测试可等待已排队的环境写入。
  Future<void> flush() => _writeQueue;

  @override
  TemplateResolutionResult resolveTemplate(String template) =>
      _delegate.resolveTemplate(template);

  Future<void> _write() async {
    final existing = await _workspace.instance.workspaceDocuments.getByKey(
      _workspaceKey,
    );
    final document = existing ?? WorkspaceDocument();
    document
      ..key = _workspaceKey
      ..schemaVersion = IsarWorkspace.currentDocumentSchemaVersion
      ..updatedAt = DateTime.now().toUtc()
      ..payloadJson = jsonEncode(_delegate.toJson());
    await _workspace.instance.writeTxn(
      () => _workspace.instance.workspaceDocuments.put(document),
    );
  }
}
