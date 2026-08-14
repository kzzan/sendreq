import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/environments/environment_models.dart';

/// 环境配置文件及其变量的领域存储契约。
abstract interface class EnvironmentStore {
  List<EnvironmentProfile> listEnvironments();

  EnvironmentProfile get activeEnvironment;

  void updateActiveAuthentication(RequestAuthentication authentication);

  void updateEnvironmentAuthentication({
    required String environmentId,
    required RequestAuthentication authentication,
  });

  List<EnvironmentVariableView> listVariables({String? environmentId});

  List<String> listUnusedAuthenticationVariableNames({String? environmentId});

  void removeUnusedAuthenticationVariables({String? environmentId});

  bool get hasUnsavedChanges;

  Future<void> setActiveEnvironment(String environmentId);

  EnvironmentProfile createEnvironment(String name, {bool activate = true});

  void renameEnvironment(String environmentId, String name);

  bool deleteEnvironment(String environmentId);

  void updateVariable({
    required String id,
    String? environmentId,
    String? key,
    String? value,
    EnvironmentVariableType? type,
  });

  void addVariable({String? environmentId});

  void addGlobalVariable();

  bool removeVariable(String id);

  void toggleSecretVisibility(String id);

  Future<void> saveChanges();

  void discardChanges();

  TemplateResolutionResult resolveTemplate(String template);
}
