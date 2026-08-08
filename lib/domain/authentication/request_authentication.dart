/// 请求认证的固定类型。
enum RequestAuthenticationType {
  /// 无认证。
  none('none'),

  /// Bearer Token 认证。
  bearer('bearer'),

  /// HTTP Basic 认证。
  basic('basic'),

  /// API Key 认证。
  apiKey('apiKey');

  /// 构造并绑定持久化值。
  const RequestAuthenticationType(this.storageValue);

  /// 持久化时使用的字符串值。
  final String storageValue;

  /// 从存储值还原类型，未知值回退为无认证。
  static RequestAuthenticationType fromStorageValue(Object? value) =>
      switch (value) {
        'bearer' => RequestAuthenticationType.bearer,
        'basic' => RequestAuthenticationType.basic,
        'apiKey' => RequestAuthenticationType.apiKey,
        _ => RequestAuthenticationType.none,
      };
}

/// 环境认证使用的固定变量名。
///
/// 这是工作区对外承诺的通用凭据契约：Bearer 使用 `token`，HTTP Basic
/// 使用 `username` / `password`，API Key 使用 `apiKey`。API Key 的 HTTP
/// 字段名属于请求配置，不能伪装成环境变量。
abstract final class AuthenticationVariableNames {
  /// Bearer 认证使用的令牌变量名。
  static const bearerToken = 'token';

  /// HTTP Basic 认证使用的用户名变量名。
  static const basicUsername = 'username';

  /// HTTP Basic 认证使用的密码变量名。
  static const basicPassword = 'password';

  /// API Key 认证使用的密钥变量名。
  static const apiKey = 'apiKey';

  /// API Key 未在请求中显式指定时使用的默认请求头名。
  static const defaultApiKeyHeader = 'X-API-Key';
}

/// API Key 在 HTTP 请求中的传递位置。
enum ApiKeyLocation {
  /// 随请求头发送。
  header('header'),

  /// 附加到查询参数。
  query('query');

  /// 构造并绑定持久化值。
  const ApiKeyLocation(this.storageValue);

  /// 持久化时使用的字符串值。
  final String storageValue;

  /// 从存储值还原位置，未知值回退为请求头。
  static ApiKeyLocation fromStorageValue(Object? value) =>
      value == 'query' ? ApiKeyLocation.query : ApiKeyLocation.header;
}

/// 请求认证配置的归属。一次请求只会解析其中一个来源。
enum RequestAuthenticationSource {
  /// 继承当前环境的认证配置。
  environment('environment'),

  /// 使用请求自身的认证配置。
  request('request');

  /// 构造并绑定持久化值。
  const RequestAuthenticationSource(this.storageValue);

  /// 持久化时使用的字符串值。
  final String storageValue;

  /// 从存储值还原来源，未知值回退为环境。
  static RequestAuthenticationSource fromStorageValue(Object? value) =>
      value == 'request'
      ? RequestAuthenticationSource.request
      : RequestAuthenticationSource.environment;
}

/// 独立于用户自定义 Headers 的请求认证配置。
///
/// 请求运行时才把它合成为 Authorization 头、API Key 头或查询参数，避免
/// 同一凭据同时在 Auth、Headers、Params 三处被编辑。
class RequestAuthentication {
  /// 无认证配置。
  const RequestAuthentication.none()
    : type = RequestAuthenticationType.none,
      bearerToken = '',
      username = '',
      password = '',
      apiKeyName = '',
      apiKeyValue = '',
      apiKeyLocation = ApiKeyLocation.header;

  /// Bearer Token 认证配置。
  const RequestAuthentication.bearer(this.bearerToken)
    : type = RequestAuthenticationType.bearer,
      username = '',
      password = '',
      apiKeyName = '',
      apiKeyValue = '',
      apiKeyLocation = ApiKeyLocation.header;

  /// HTTP Basic 认证配置。
  const RequestAuthentication.basic({
    required this.username,
    required this.password,
  }) : type = RequestAuthenticationType.basic,
       bearerToken = '',
       apiKeyName = '',
       apiKeyValue = '',
       apiKeyLocation = ApiKeyLocation.header;

  /// API Key 认证配置。
  const RequestAuthentication.apiKey({
    required this.apiKeyName,
    required this.apiKeyValue,
    required this.apiKeyLocation,
  }) : type = RequestAuthenticationType.apiKey,
       bearerToken = '',
       username = '',
       password = '';

  /// 认证类型。
  final RequestAuthenticationType type;

  /// Bearer 令牌值。
  final String bearerToken;

  /// Basic 用户名。
  final String username;

  /// Basic 密码。
  final String password;

  /// API Key 名称（请求头名或查询参数名）。
  final String apiKeyName;

  /// API Key 值。
  final String apiKeyValue;

  /// API Key 的传递位置。
  final ApiKeyLocation apiKeyLocation;

  /// 是否为 Bearer 认证。
  bool get usesBearerToken => type == RequestAuthenticationType.bearer;

  /// 是否为 HTTP Basic 认证。
  bool get usesBasicAuthentication => type == RequestAuthenticationType.basic;

  /// 是否为 API Key 认证。
  bool get usesApiKey => type == RequestAuthenticationType.apiKey;

  /// API Key 是否随请求头发送。
  bool get apiKeyInHeader =>
      usesApiKey && apiKeyLocation == ApiKeyLocation.header;

  /// API Key 是否附加到查询参数。
  bool get apiKeyInQuery =>
      usesApiKey && apiKeyLocation == ApiKeyLocation.query;

  /// 是否需要合成 Authorization 请求头。
  bool get usesAuthorizationHeader =>
      usesBearerToken || usesBasicAuthentication;

  /// 所有可引用环境变量的认证字段，用于发送前缺失变量校验。
  List<String> get templateValues => switch (type) {
    RequestAuthenticationType.bearer => [bearerToken],
    RequestAuthenticationType.basic => [username, password],
    RequestAuthenticationType.apiKey => [apiKeyName, apiKeyValue],
    RequestAuthenticationType.none => const [],
  };

  /// 复制并更新认证配置；切换 [type] 时按目标类型重建对应构造器。
  RequestAuthentication copyWith({
    RequestAuthenticationType? type,
    String? bearerToken,
    String? username,
    String? password,
    String? apiKeyName,
    String? apiKeyValue,
    ApiKeyLocation? apiKeyLocation,
  }) {
    final nextType = type ?? this.type;
    // 按类型重建命名构造器，避免跨类型保留其它认证字段。
    return switch (nextType) {
      RequestAuthenticationType.bearer => RequestAuthentication.bearer(
        bearerToken ?? this.bearerToken,
      ),
      RequestAuthenticationType.basic => RequestAuthentication.basic(
        username: username ?? this.username,
        password: password ?? this.password,
      ),
      RequestAuthenticationType.apiKey => RequestAuthentication.apiKey(
        apiKeyName: apiKeyName ?? this.apiKeyName,
        apiKeyValue: apiKeyValue ?? this.apiKeyValue,
        apiKeyLocation: apiKeyLocation ?? this.apiKeyLocation,
      ),
      RequestAuthenticationType.none => const RequestAuthentication.none(),
    };
  }

  /// 序列化为 JSON；仅写入当前认证类型对应的字段。
  Map<String, Object> toJson() => {
    'type': type.storageValue,
    if (usesBearerToken) 'bearerToken': bearerToken,
    if (usesBasicAuthentication) ...{
      'username': username,
      'password': password,
    },
    if (usesApiKey) ...{
      'apiKeyName': apiKeyName,
      'apiKeyValue': apiKeyValue,
      'apiKeyLocation': apiKeyLocation.storageValue,
    },
  };

  /// 从 JSON 还原认证配置；缺失字段回退到安全默认值。
  factory RequestAuthentication.fromJson(Map<String, dynamic> json) {
    final type = RequestAuthenticationType.fromStorageValue(json['type']);
    return switch (type) {
      RequestAuthenticationType.bearer => RequestAuthentication.bearer(
        json['bearerToken'] as String? ?? '',
      ),
      RequestAuthenticationType.basic => RequestAuthentication.basic(
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
      ),
      RequestAuthenticationType.apiKey => RequestAuthentication.apiKey(
        apiKeyName: json['apiKeyName'] as String? ?? 'X-API-Key',
        apiKeyValue: json['apiKeyValue'] as String? ?? '',
        apiKeyLocation: ApiKeyLocation.fromStorageValue(json['apiKeyLocation']),
      ),
      RequestAuthenticationType.none => const RequestAuthentication.none(),
    };
  }
}
