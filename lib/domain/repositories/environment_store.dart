import '../authentication/request_authentication.dart';
import '../environments/environment_models.dart';

/// 环境配置文件及其变量的领域存储契约。
abstract interface class EnvironmentStore {
  List<EnvironmentProfile> listEnvironments();

  EnvironmentProfile get activeEnvironment;

  void updateActiveAuthentication(RequestAuthentication authentication);

  List<EnvironmentVariableView> listVariables();

  List<String> listUnusedAuthenticationVariableNames();

  void removeUnusedAuthenticationVariables();

  bool get hasUnsavedChanges;

  void setActiveEnvironment(String environmentId);

  EnvironmentProfile createEnvironment(String name);

  void renameEnvironment(String environmentId, String name);

  bool deleteEnvironment(String environmentId);

  void updateVariable({
    required String id,
    String? key,
    String? value,
    EnvironmentVariableType? type,
  });

  void addVariable();

  void addGlobalVariable();

  bool removeVariable(String id);

  void toggleSecretVisibility(String id);

  Future<void> saveChanges();

  TemplateResolutionResult resolveTemplate(String template);
}
