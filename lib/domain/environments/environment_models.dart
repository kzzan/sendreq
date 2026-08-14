import 'package:sendreq/domain/authentication/request_authentication.dart';

/// 环境变量值类型。
enum EnvironmentVariableType {
  /// 字符串。
  string,

  /// 数字。
  number,

  /// 布尔值。
  boolean,

  /// 敏感值（密钥）。
  secret,
}

/// 环境配置文件，作为一组变量的作用域容器。
class EnvironmentProfile {
  /// 构建环境配置。
  const EnvironmentProfile({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.authentication = const RequestAuthentication.none(),
  });

  /// 环境唯一标识。
  final String id;

  /// 所属工作区 id。
  final String workspaceId;

  /// 环境名称。
  final String name;

  /// 此环境的默认认证策略。请求可明确继承它，凭据仍由变量表持有。
  final RequestAuthentication authentication;

  /// 创建同一环境的更新副本。
  EnvironmentProfile copyWith({
    String? name,
    RequestAuthentication? authentication,
  }) => EnvironmentProfile(
    id: id,
    workspaceId: workspaceId,
    name: name ?? this.name,
    authentication: authentication ?? this.authentication,
  );
}

/// 环境变量在编辑器中的展示视图（值可被掩码）。
class EnvironmentVariableView {
  const EnvironmentVariableView({
    required this.id,
    required this.scope,
    required this.key,
    required this.displayValue,
    required this.type,
    required this.isMasked,
    this.isProtected = false,
    this.isRequired = false,
    this.isAuthenticationBinding = false,
  });

  /// 变量唯一标识。
  final String id;

  /// 作用域（环境名）。
  final String scope;

  /// 变量名。
  final String key;

  /// 用于展示的值（敏感值可能被掩码）。
  final String displayValue;

  /// 值类型。
  final EnvironmentVariableType type;

  /// 展示时是否掩码。
  final bool isMasked;

  /// 是否为环境运行所需的受保护变量。
  ///
  /// 受保护变量允许编辑值，但不能删除、改名或改变值类型。
  final bool isProtected;

  /// 是否为环境的必填基础变量（例如 baseUrl）。
  ///
  /// 必填变量的值可编辑，但不能删除、改名或改变类型。
  final bool isRequired;

  /// 此变量正被当前环境认证配置引用。
  ///
  /// 它仍可编辑值，但名称、类型与删除操作会在编辑器中保持稳定，避免
  /// 认证模板在用户无感知的情况下失效。
  final bool isAuthenticationBinding;

  /// 是否为敏感变量。
  bool get isSecret => type == EnvironmentVariableType.secret;
}

/// 模板变量解析的状态。
enum TemplateResolutionStatus {
  /// 解析成功。
  success,

  /// 存在未定义的变量。
  missingVariable,
}

/// 模板变量替换结果，执行值与展示值分离。
class TemplateResolutionResult {
  const TemplateResolutionResult({
    required this.status,
    required this.executionValue,
    required this.displayValue,
    this.missingKeys = const [],
  });

  /// 解析状态。
  final TemplateResolutionStatus status;

  /// 用于实际执行的替换值。
  final String executionValue;

  /// 用于界面展示的替换值。
  final String displayValue;

  /// 缺失的变量键列表。
  final List<String> missingKeys;
}
