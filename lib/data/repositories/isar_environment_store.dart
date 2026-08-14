import 'dart:async';
import 'dart:convert';

import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/environments/environment_models.dart';
import 'package:sendreq/domain/repositories/environment_store.dart';
import 'package:sendreq/data/database/isar_workspace.dart';
import 'package:sendreq/data/database/isar_workspace_models.dart';
import 'package:sendreq/data/repositories/file_environment_store.dart';
import 'package:sendreq/data/repositories/in_memory_environment_store.dart';

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
        ? InMemoryEnvironmentStore.defaults()
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
  void updateEnvironmentAuthentication({
    required String environmentId,
    required RequestAuthentication authentication,
  }) => _delegate.updateEnvironmentAuthentication(
    environmentId: environmentId,
    authentication: authentication,
  );

  @override
  List<EnvironmentVariableView> listVariables({String? environmentId}) =>
      _delegate.listVariables(environmentId: environmentId);

  @override
  List<String> listUnusedAuthenticationVariableNames({String? environmentId}) =>
      _delegate.listUnusedAuthenticationVariableNames(
        environmentId: environmentId,
      );

  @override
  void removeUnusedAuthenticationVariables({String? environmentId}) => _delegate
      .removeUnusedAuthenticationVariables(environmentId: environmentId);

  @override
  bool get hasUnsavedChanges => _delegate.hasUnsavedChanges;

  @override
  Future<void> setActiveEnvironment(String environmentId) async {
    await _delegate.setActiveEnvironment(environmentId);
    final snapshot = _delegate.savedJsonWithActiveEnvironment();
    _writeQueue = _writeQueue.then((_) => _write(snapshot));
    await _writeQueue;
  }

  @override
  EnvironmentProfile createEnvironment(String name, {bool activate = true}) =>
      _delegate.createEnvironment(name, activate: activate);

  @override
  void renameEnvironment(String environmentId, String name) =>
      _delegate.renameEnvironment(environmentId, name);

  @override
  bool deleteEnvironment(String environmentId) =>
      _delegate.deleteEnvironment(environmentId);

  @override
  void updateVariable({
    required String id,
    String? environmentId,
    String? key,
    String? value,
    EnvironmentVariableType? type,
  }) => _delegate.updateVariable(
    id: id,
    environmentId: environmentId,
    key: key,
    value: value,
    type: type,
  );

  @override
  void addVariable({String? environmentId}) =>
      _delegate.addVariable(environmentId: environmentId);

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
    final snapshot = _delegate.toJson();
    _writeQueue = _writeQueue.then((_) async {
      await _write(snapshot);
      _delegate.commitSavedSnapshot(snapshot);
    });
    return _writeQueue;
  }

  /// 受控退出或测试可等待已排队的环境写入。
  Future<void> flush() => _writeQueue;

  @override
  void discardChanges() => _delegate.discardChanges();

  @override
  TemplateResolutionResult resolveTemplate(String template) =>
      _delegate.resolveTemplate(template);

  Future<void> _write([Map<String, Object>? snapshot]) async {
    final existing = await _workspace.instance.workspaceDocuments.getByKey(
      _workspaceKey,
    );
    final document = existing ?? WorkspaceDocument();
    document
      ..key = _workspaceKey
      ..schemaVersion = IsarWorkspace.currentDocumentSchemaVersion
      ..updatedAt = DateTime.now().toUtc()
      ..payloadJson = jsonEncode(snapshot ?? _delegate.toJson());
    await _workspace.instance.writeTxn(
      () => _workspace.instance.workspaceDocuments.put(document),
    );
  }
}
