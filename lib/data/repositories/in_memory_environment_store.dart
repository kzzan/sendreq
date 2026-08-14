import 'package:sendreq/data/repositories/in_memory_environment_store_state.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/environments/environment_models.dart';
import 'package:sendreq/domain/repositories/environment_store.dart';

/// 内存环境存储的稳定门面；状态、迁移和变量操作由内部协作器负责。
class InMemoryEnvironmentStore implements EnvironmentStore {
  InMemoryEnvironmentStore._(this._state);

  /// 构造带预置环境的示例存储。
  factory InMemoryEnvironmentStore.sample() =>
      InMemoryEnvironmentStore._(EnvironmentStoreState.sample());

  /// 从持久化快照恢复；非法数据由调用方处理为读取失败。
  factory InMemoryEnvironmentStore.fromJson(Map<String, dynamic> source) =>
      InMemoryEnvironmentStore._(EnvironmentStoreState.fromJson(source));

  final EnvironmentStoreState _state;

  /// 导出完整环境状态，供文件存储在显式保存后写入磁盘。
  Map<String, Object> toJson() => _state.toJson();

  @override
  bool get hasUnsavedChanges => _state.hasUnsavedChanges;

  @override
  EnvironmentProfile get activeEnvironment => _state.activeEnvironment;

  @override
  void updateActiveAuthentication(RequestAuthentication authentication) =>
      _state.updateActiveAuthentication(authentication);

  @override
  void updateEnvironmentAuthentication({
    required String environmentId,
    required RequestAuthentication authentication,
  }) => _state.updateEnvironmentAuthentication(
    environmentId: environmentId,
    authentication: authentication,
  );

  @override
  List<EnvironmentProfile> listEnvironments() => _state.listEnvironments();

  @override
  List<EnvironmentVariableView> listVariables({String? environmentId}) =>
      _state.listVariables(environmentId: environmentId);

  @override
  List<String> listUnusedAuthenticationVariableNames({String? environmentId}) =>
      _state.listUnusedAuthenticationVariableNames(
        environmentId: environmentId,
      );

  @override
  void removeUnusedAuthenticationVariables({String? environmentId}) =>
      _state.removeUnusedAuthenticationVariables(environmentId: environmentId);

  @override
  Future<void> setActiveEnvironment(String environmentId) async =>
      _state.setActiveEnvironment(environmentId);

  @override
  EnvironmentProfile createEnvironment(String name, {bool activate = true}) =>
      _state.createEnvironment(name, activate: activate);

  @override
  void renameEnvironment(String environmentId, String name) =>
      _state.renameEnvironment(environmentId, name);

  @override
  bool deleteEnvironment(String environmentId) =>
      _state.deleteEnvironment(environmentId);

  @override
  void updateVariable({
    required String id,
    String? environmentId,
    String? key,
    String? value,
    EnvironmentVariableType? type,
  }) => _state.updateVariable(
    id: id,
    environmentId: environmentId,
    key: key,
    value: value,
    type: type,
  );

  @override
  void addVariable({String? environmentId}) =>
      _state.addVariable(environmentId: environmentId);

  @override
  void addGlobalVariable() => _state.addGlobalVariable();

  @override
  bool removeVariable(String id) => _state.removeVariable(id);

  @override
  void toggleSecretVisibility(String id) => _state.toggleSecretVisibility(id);

  @override
  Future<void> saveChanges() => _state.saveChanges();

  @override
  void discardChanges() => _state.discardChanges();

  /// 最近一次成功保存的配置，加上当前可持久化的活动环境选择。
  Map<String, Object> savedJsonWithActiveEnvironment() =>
      _state.savedJsonWithActiveEnvironment();

  /// 将已成功写入持久层的精确快照设为基线，不吞掉写入期间产生的新编辑。
  void commitSavedSnapshot(Map<String, Object> snapshot) =>
      _state.commitSavedSnapshot(snapshot);

  @override
  TemplateResolutionResult resolveTemplate(String template) =>
      _state.resolveTemplate(template);
}
