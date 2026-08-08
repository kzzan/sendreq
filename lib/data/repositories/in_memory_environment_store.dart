import '../../domain/environments/environment_models.dart';
import '../../domain/authentication/request_authentication.dart';
import '../../domain/repositories/environment_store.dart';

/// 基于内存实现的环境存储。
///
/// 预置了 Staging / Production / GeoIP Lookup / Reurl Production 环境及各环境的示例变量，数据仅存于
/// 进程内，适合原型演示；密钥变量默认隐藏，可通过显式操作揭示。每个
/// 环境都持有不可删除、不可改名的 `baseUrl`，认证凭据由当前认证方式决定。
class InMemoryEnvironmentStore implements EnvironmentStore {
  /// 私有构造：预置示例环境与变量，并补齐各环境必填项。
  InMemoryEnvironmentStore._()
    : _global = [
        // 全局变量：不随环境切换而变化，各环境通用。
        const _StoredVariable(
          'global-timeout',
          'Global',
          'timeout',
          '8000',
          EnvironmentVariableType.number,
        ),
      ],
      _byEnvironment = {
        // 预置 Staging 环境的 baseUrl 与 token。
        'staging': [
          const _StoredVariable(
            'staging-base-url',
            'Staging',
            'baseUrl',
            'https://staging.sendreq.io',
            EnvironmentVariableType.string,
            isRequired: true,
          ),
          const _StoredVariable(
            'staging-token',
            'Staging',
            'token',
            'staging-token-value',
            EnvironmentVariableType.secret,
            isProtected: true,
          ),
        ],
        // 预置 Production 环境的 baseUrl 与 token。
        'production': [
          const _StoredVariable(
            'production-base-url',
            'Production',
            'baseUrl',
            'https://api.sendreq.io',
            EnvironmentVariableType.string,
            isRequired: true,
          ),
          const _StoredVariable(
            'production-token',
            'Production',
            'token',
            'production-token-value',
            EnvironmentVariableType.secret,
            isProtected: true,
          ),
        ],
        // 公共 GeoIP 查询示例：请求与参数均通过环境变量组装。
        'geoip-lookup': [
          const _StoredVariable(
            'geoip-base-url',
            'GeoIP Lookup',
            'baseUrl',
            'https://www.reurl.to',
            EnvironmentVariableType.string,
            isRequired: true,
          ),
          const _StoredVariable(
            'geoip-domain',
            'GeoIP Lookup',
            'domain',
            'qq.com',
            EnvironmentVariableType.string,
          ),
          const _StoredVariable(
            'geoip-token',
            'GeoIP Lookup',
            'token',
            '',
            EnvironmentVariableType.secret,
            isProtected: true,
          ),
        ],
        // Reurl 生产接口示例：凭据作为 Secret，地址与查询参数可独立修改。
        'reurl-production': [
          const _StoredVariable(
            'reurl-base-url',
            'Reurl Production',
            'baseUrl',
            'https://api.reurl.to',
            EnvironmentVariableType.string,
            isRequired: true,
          ),
          const _StoredVariable(
            'reurl-token',
            'Reurl Production',
            'token',
            '',
            EnvironmentVariableType.secret,
            isProtected: true,
          ),
          const _StoredVariable(
            'reurl-ip',
            'Reurl Production',
            'ip',
            '1.1.1.1',
            EnvironmentVariableType.string,
          ),
          const _StoredVariable(
            'reurl-lang',
            'Reurl Production',
            'lang',
            'en',
            EnvironmentVariableType.string,
          ),
        ],
      } {
    _ensureRequiredBaseUrls();
  }

  /// 构造一份带预置环境的示例存储。
  factory InMemoryEnvironmentStore.sample() => InMemoryEnvironmentStore._();

  /// 从磁盘快照恢复环境。非法快照由调用方视为读取失败并回退到示例数据。
  factory InMemoryEnvironmentStore.fromJson(Map<String, dynamic> source) {
    final profilesSource = source['profiles'];
    final globalSource = source['globalVariables'];
    final variablesSource = source['variablesByEnvironment'];
    final activeId = source['activeEnvironmentId'];
    if (profilesSource is! List ||
        globalSource is! List ||
        variablesSource is! Map ||
        activeId is! String) {
      throw const FormatException('Invalid environment store data.');
    }
    final profiles = profilesSource
        .map((value) {
          if (value is! Map) throw const FormatException('Invalid profile.');
          final json = Map<String, dynamic>.from(value);
          final id = json['id'];
          final workspaceId = json['workspaceId'];
          final name = json['name'];
          if (id is! String || workspaceId is! String || name is! String) {
            throw const FormatException('Invalid profile fields.');
          }
          final authentication = json['authentication'];
          return EnvironmentProfile(
            id: id,
            workspaceId: workspaceId,
            name: name,
            authentication: authentication is Map
                ? RequestAuthentication.fromJson(
                    Map<String, dynamic>.from(authentication),
                  )
                : const RequestAuthentication.none(),
          );
        })
        .toList(growable: false);
    if (profiles.isEmpty ||
        !profiles.any((profile) => profile.id == activeId)) {
      throw const FormatException('Missing active environment.');
    }
    final globals = globalSource
        .map((value) => _StoredVariable.fromJson(value))
        .toList();
    final variables = <String, List<_StoredVariable>>{};
    for (final entry in variablesSource.entries) {
      if (entry.key is! String || entry.value is! List) {
        throw const FormatException('Invalid environment variables.');
      }
      variables[entry.key as String] = (entry.value as List)
          .map((value) => _StoredVariable.fromJson(value))
          .toList();
    }
    final store = InMemoryEnvironmentStore._();
    store._profiles
      ..clear()
      ..addAll(profiles);
    store._global
      ..clear()
      ..addAll(globals);
    store._byEnvironment
      ..clear()
      ..addAll(variables);
    store._activeId = activeId;
    store._nextVariableId = _nextId([
      ...globals,
      ...variables.values.expand((items) => items),
    ], 'variable-');
    store._nextEnvironmentId = _nextIdForStrings(
      profiles.map((profile) => profile.id),
      'environment-',
    );
    store._ensureRequiredBaseUrls();
    store._ensureAuthenticationVariables(
      store.activeEnvironment.authentication,
    );
    return store;
  }

  /// 环境配置列表；可由用户在工作区中新增、重命名或删除。
  final List<EnvironmentProfile> _profiles = [
    EnvironmentProfile(
      id: 'staging',
      workspaceId: 'workspace-main',
      name: 'Staging',
      authentication: const RequestAuthentication.bearer('{{token}}'),
    ),
    EnvironmentProfile(
      id: 'production',
      workspaceId: 'workspace-main',
      name: 'Production',
      authentication: const RequestAuthentication.bearer('{{token}}'),
    ),
    EnvironmentProfile(
      id: 'geoip-lookup',
      workspaceId: 'workspace-main',
      name: 'GeoIP Lookup',
    ),
    EnvironmentProfile(
      id: 'reurl-production',
      workspaceId: 'workspace-main',
      name: 'Reurl Production',
      authentication: const RequestAuthentication.bearer('{{token}}'),
    ),
  ];

  /// 当前活动环境的 ID，初始为 staging。
  String _activeId = 'staging';

  /// 全局变量列表。
  final List<_StoredVariable> _global;

  /// 按环境 ID 索引的变量列表。
  final Map<String, List<_StoredVariable>> _byEnvironment;

  /// 已揭示内容的密钥变量 ID 集合。
  final Set<String> _revealedSecretIds = {};

  /// 是否存在未保存的修改标记。
  bool _hasUnsavedChanges = false;

  /// 用于生成新增变量的自增序号。
  int _nextVariableId = 1;

  /// 用于生成环境 ID 的自增序号。
  int _nextEnvironmentId = 1;

  /// 是否存在尚未保存的修改。
  @override
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  /// 当前激活的环境配置。
  @override
  EnvironmentProfile get activeEnvironment =>
      _profiles.firstWhere((item) => item.id == _activeId);

  /// 更新当前环境的认证策略，并同步删除/创建对应的认证变量。
  @override
  void updateActiveAuthentication(RequestAuthentication authentication) {
    final index = _profiles.indexWhere((item) => item.id == _activeId);
    final normalizedAuthentication = _normalizeEnvironmentAuthentication(
      authentication,
    );
    _removeInactiveAuthenticationVariables(normalizedAuthentication);
    _profiles[index] = _profiles[index].copyWith(
      authentication: normalizedAuthentication,
    );
    _ensureAuthenticationVariables(normalizedAuthentication);
    _hasUnsavedChanges = true;
  }

  /// 列出全部环境配置（只读快照）。
  @override
  List<EnvironmentProfile> listEnvironments() => List.unmodifiable(_profiles);

  /// 列出当前环境的变量与全局变量，密钥按揭示状态脱敏。
  @override
  List<EnvironmentVariableView> listVariables() {
    final authenticationKeys = _authenticationVariableKeys(
      activeEnvironment.authentication,
    );
    return [
      // 先列当前环境的变量，再列全局变量；密钥按揭示状态决定是否脱敏。
      // 认证只绑定当前环境中的变量：它们会覆盖同名全局变量。
      for (final variable in _byEnvironment[_activeId]!)
        if (!_isHiddenInactiveAuthenticationVariable(
          variable,
          authenticationKeys,
        ))
          variable.toView(
            revealSecret: _revealedSecretIds.contains(variable.id),
            isAuthenticationBinding: authenticationKeys.contains(variable.key),
          ),
      for (final variable in _global)
        variable.toView(revealSecret: _revealedSecretIds.contains(variable.id)),
    ];
  }

  /// 列出当前认证不再使用、可安全删除的凭据变量名。
  @override
  List<String> listUnusedAuthenticationVariableNames() {
    final activeKeys = _authenticationVariableKeys(
      activeEnvironment.authentication,
    );
    return [
      for (final variable in _byEnvironment[_activeId]!)
        if (_removableAuthenticationVariableKeys.contains(variable.key) &&
            !activeKeys.contains(variable.key))
          variable.key,
    ];
  }

  /// 删除当前认证不再使用的凭据变量。
  @override
  void removeUnusedAuthenticationVariables() {
    final unused = listUnusedAuthenticationVariableNames().toSet();
    if (unused.isEmpty) return;
    final variables = _byEnvironment[_activeId]!;
    final removedIds = <String>[];
    variables.removeWhere((variable) {
      final shouldRemove = unused.contains(variable.key);
      if (shouldRemove) removedIds.add(variable.id);
      return shouldRemove;
    });
    _revealedSecretIds.removeAll(removedIds);
    _hasUnsavedChanges = true;
  }

  /// 切换认证方式时，严格只保留当前认证所需的凭据字段。
  void _removeInactiveAuthenticationVariables(
    RequestAuthentication authentication,
  ) {
    final activeKeys = _authenticationVariableKeys(authentication);
    final variables = _byEnvironment[_activeId]!;
    final removedIds = <String>[];
    variables.removeWhere((variable) {
      final shouldRemove =
          _allAuthenticationVariableKeys.contains(variable.key) &&
          !activeKeys.contains(variable.key);
      if (shouldRemove) removedIds.add(variable.id);
      return shouldRemove;
    });
    _revealedSecretIds.removeAll(removedIds);
  }

  /// 切换当前激活环境，并同步维护该环境的认证变量。
  @override
  void setActiveEnvironment(String environmentId) {
    // 先校验环境存在，再切换活动环境。
    _profiles.firstWhere((item) => item.id == environmentId);
    if (_activeId == environmentId) return;
    _activeId = environmentId;
    _removeInactiveAuthenticationVariables(activeEnvironment.authentication);
    _ensureAuthenticationVariables(activeEnvironment.authentication);
    _hasUnsavedChanges = true;
  }

  /// 创建环境（校验名称唯一）并设为当前环境。
  @override
  EnvironmentProfile createEnvironment(String name) {
    final normalized = _validateEnvironmentName(name);
    final profile = EnvironmentProfile(
      id: 'environment-${_nextEnvironmentId++}',
      workspaceId: 'workspace-main',
      name: normalized,
    );
    _profiles.add(profile);
    _byEnvironment[profile.id] = [_requiredBaseUrl(profile)];
    _activeId = profile.id;
    _hasUnsavedChanges = true;
    return profile;
  }

  /// 重命名环境并同步更新其变量作用域。
  @override
  void renameEnvironment(String environmentId, String name) {
    final normalized = _validateEnvironmentName(
      name,
      excludingId: environmentId,
    );
    final index = _profiles.indexWhere(
      (profile) => profile.id == environmentId,
    );
    if (index < 0) throw StateError('Unknown environment: $environmentId');
    _profiles[index] = _profiles[index].copyWith(name: normalized);
    _byEnvironment[environmentId] = [
      for (final variable in _byEnvironment[environmentId]!)
        variable.copyWith(scope: normalized),
    ];
    _hasUnsavedChanges = true;
  }

  /// 删除环境及其变量；至少保留一个环境，无法删除时返回 false。
  @override
  bool deleteEnvironment(String environmentId) {
    if (_profiles.length <= 1) return false;
    final index = _profiles.indexWhere(
      (profile) => profile.id == environmentId,
    );
    if (index < 0) throw StateError('Unknown environment: $environmentId');
    final removed = _profiles.removeAt(index);
    final variables = _byEnvironment.remove(removed.id)!;
    _revealedSecretIds.removeAll(variables.map((variable) => variable.id));
    if (_activeId == removed.id) {
      _activeId = _profiles.first.id;
    }
    _hasUnsavedChanges = true;
    return true;
  }

  /// 更新指定变量的键、值或类型（字段为 null 表示保持不变）。
  @override
  void updateVariable({
    required String id,
    String? key,
    String? value,
    EnvironmentVariableType? type,
  }) {
    final location = _findVariable(id);
    final current = location.variables[location.index];
    final isManagedAuthenticationVariable =
        identical(location.variables, _byEnvironment[_activeId]) &&
        _allAuthenticationVariableKeys.contains(current.key);
    final valueOnly =
        current.isProtected ||
        current.isRequired ||
        isManagedAuthenticationVariable;
    if (valueOnly) {
      // 必填字段和认证字段只允许修改值，名称和类型是稳定契约。
      final normalizedValue = value == null
          ? null
          : _normalizeValueForType(value, current.type);
      if (normalizedValue == null || normalizedValue == current.value) return;
      location.variables[location.index] = current.copyWith(
        value: normalizedValue,
      );
      _hasUnsavedChanges = true;
      return;
    }
    final nextType = type ?? current.type;
    final nextValue = value == null && type == null
        ? null
        : _normalizeValueForType(value ?? current.value, nextType);
    // 不可变更新：仅替换被修改的字段，其余保持原值。
    location.variables[location.index] = current.copyWith(
      key: key?.trim(),
      value: nextValue,
      type: type,
    );
    _hasUnsavedChanges = true;
  }

  /// 在当前环境新增一个空变量。
  @override
  void addVariable() {
    final environment = activeEnvironment;
    // 新增变量挂到当前环境，初始为空字符串。
    _byEnvironment[_activeId]!.add(
      _StoredVariable(
        'variable-${_nextVariableId++}',
        environment.name,
        '',
        '',
        EnvironmentVariableType.string,
      ),
    );
    _hasUnsavedChanges = true;
  }

  /// 在全局范围新增一个空变量。
  @override
  void addGlobalVariable() {
    _global.add(
      _StoredVariable(
        'variable-${_nextVariableId++}',
        'Global',
        '',
        '',
        EnvironmentVariableType.string,
      ),
    );
    _hasUnsavedChanges = true;
  }

  /// 移除指定变量；受保护或认证绑定的变量不可移除。
  @override
  bool removeVariable(String id) {
    final location = _findVariable(id);
    final variable = location.variables[location.index];
    final isManagedAuthenticationVariable =
        identical(location.variables, _byEnvironment[_activeId]) &&
        _allAuthenticationVariableKeys.contains(variable.key);
    if (variable.isProtected ||
        variable.isRequired ||
        isManagedAuthenticationVariable) {
      return false;
    }
    location.variables.removeAt(location.index);
    // 删除后同步移除其密钥揭示状态，避免残留。
    _revealedSecretIds.remove(id);
    _hasUnsavedChanges = true;
    return true;
  }

  /// 切换密钥变量的可见/隐藏状态。
  @override
  void toggleSecretVisibility(String id) {
    // 集合中已有则移除（隐藏），否则加入（揭示）。
    if (!_revealedSecretIds.add(id)) {
      _revealedSecretIds.remove(id);
    }
  }

  /// 清除未保存标记（内存版无需真正持久化）。
  @override
  Future<void> saveChanges() async => _hasUnsavedChanges = false;

  /// 导出完整环境状态，供文件存储在用户显式保存后写入磁盘。
  Map<String, Object> toJson() => {
    'profiles': [
      for (final profile in _profiles)
        {
          'id': profile.id,
          'workspaceId': profile.workspaceId,
          'name': profile.name,
          'authentication': profile.authentication.toJson(),
        },
    ],
    'activeEnvironmentId': _activeId,
    'globalVariables': [for (final variable in _global) variable.toJson()],
    'variablesByEnvironment': {
      for (final entry in _byEnvironment.entries)
        entry.key: [for (final variable in entry.value) variable.toJson()],
    },
  };

  /// 根据现有变量 ID 的数字序号，计算下一个可用的自增序号。
  static int _nextId(Iterable<_StoredVariable> variables, String prefix) {
    final highest = variables.fold<int>(0, (value, variable) {
      final suffix = variable.id.startsWith(prefix)
          ? int.tryParse(variable.id.substring(prefix.length))
          : null;
      return suffix != null && suffix >= value ? suffix : value;
    });
    return highest + 1;
  }

  /// 根据现有字符串 ID 的数字序号，计算下一个可用的自增序号。
  static int _nextIdForStrings(Iterable<String> values, String prefix) {
    final highest = values.fold<int>(0, (value, item) {
      final suffix = item.startsWith(prefix)
          ? int.tryParse(item.substring(prefix.length))
          : null;
      return suffix != null && suffix >= value ? suffix : value;
    });
    return highest + 1;
  }

  /// 解析模板字符串中的 `{{变量名}}` 占位符，未定义变量保留并记录。
  @override
  TemplateResolutionResult resolveTemplate(String template) {
    // 合并全局变量与当前环境变量；同名时环境变量覆盖全局变量。
    final values = {
      for (final value in _global) value.key: value.value,
      for (final value in _byEnvironment[_activeId]!) value.key: value.value,
    };
    final missing = <String>[];
    // 逐一替换 `{{key}}` 占位符；找不到的变量保持原样并记录下来。
    final resolved = template.replaceAllMapped(RegExp(r'\{\{([^}]+)\}\}'), (
      match,
    ) {
      final key = match.group(1)!;
      final value = values[key];
      // 未定义或只含空白的变量都不能生成可执行请求；保留占位符并
      // 交由调用方阻止发送，避免把空 token、空地址静默发到运行时。
      if (value == null || value.trim().isEmpty) {
        missing.add(key);
        return match.group(0)!;
      }
      return value;
    });
    return TemplateResolutionResult(
      status: missing.isEmpty
          ? TemplateResolutionStatus.success
          : TemplateResolutionStatus.missingVariable,
      executionValue: resolved,
      displayValue: template,
      missingKeys: missing,
    );
  }

  /// 在全局或某个环境中查找变量，返回其所在列表与下标。
  _VariableLocation _findVariable(String id) {
    final globalIndex = _global.indexWhere((variable) => variable.id == id);
    if (globalIndex >= 0) return _VariableLocation(_global, globalIndex);
    for (final variables in _byEnvironment.values) {
      final index = variables.indexWhere((variable) => variable.id == id);
      if (index >= 0) return _VariableLocation(variables, index);
    }
    throw StateError('Unknown environment variable: $id');
  }

  /// 为所有环境补齐必填 baseUrl，并修复旧内存数据中的错误类型。
  void _ensureRequiredBaseUrls() {
    for (final profile in _profiles) {
      final variables = _byEnvironment.putIfAbsent(profile.id, () => []);
      final baseUrlIndex = variables.indexWhere(
        (variable) => variable.key == 'baseUrl',
      );
      if (baseUrlIndex < 0) {
        variables.add(_requiredBaseUrl(profile));
        continue;
      }
      final baseUrl = variables[baseUrlIndex];
      variables[baseUrlIndex] = baseUrl.copyWith(
        key: 'baseUrl',
        type: EnvironmentVariableType.string,
        isRequired: true,
      );
    }
  }

  /// 当切换环境认证时，立即显示当前认证需要的标准变量。
  ///
  /// 每个环境认证字段严格互斥。切换认证并确认后，上一认证方式的
  /// 所有专用凭据都会被删除，当前类型再创建自己的固定字段。
  void _ensureAuthenticationVariables(RequestAuthentication authentication) {
    final variables = _byEnvironment[_activeId]!;
    final environment = activeEnvironment;
    switch (authentication.type) {
      case RequestAuthenticationType.none:
        return;
      case RequestAuthenticationType.bearer:
        _ensureEnvironmentVariable(
          variables: variables,
          environment: environment,
          key: AuthenticationVariableNames.bearerToken,
          type: EnvironmentVariableType.secret,
          isProtected: true,
        );
        return;
      case RequestAuthenticationType.basic:
        _ensureEnvironmentVariable(
          variables: variables,
          environment: environment,
          key: AuthenticationVariableNames.basicUsername,
          type: EnvironmentVariableType.string,
        );
        _ensureEnvironmentVariable(
          variables: variables,
          environment: environment,
          key: AuthenticationVariableNames.basicPassword,
          type: EnvironmentVariableType.secret,
        );
      case RequestAuthenticationType.apiKey:
        _ensureEnvironmentVariable(
          variables: variables,
          environment: environment,
          key: AuthenticationVariableNames.apiKey,
          type: EnvironmentVariableType.secret,
        );
    }
  }

  /// 确保指定变量存在：缺失则创建，已存在则更新其类型与保护标记。
  void _ensureEnvironmentVariable({
    required List<_StoredVariable> variables,
    required EnvironmentProfile environment,
    required String key,
    required EnvironmentVariableType type,
    bool isProtected = false,
    String value = '',
  }) {
    final index = variables.indexWhere((variable) => variable.key == key);
    if (index < 0) {
      variables.add(
        _StoredVariable(
          'authentication-${environment.id}-$key',
          environment.name,
          key,
          value,
          type,
          isProtected: isProtected,
        ),
      );
      return;
    }
    final current = variables[index];
    variables[index] = current.copyWith(type: type, isProtected: isProtected);
  }

  /// 认证变量名是环境模型的固定契约，不能由调用者覆盖。
  RequestAuthentication _normalizeEnvironmentAuthentication(
    RequestAuthentication authentication,
  ) => switch (authentication.type) {
    RequestAuthenticationType.none => const RequestAuthentication.none(),
    RequestAuthenticationType.bearer => const RequestAuthentication.bearer(
      '{{${AuthenticationVariableNames.bearerToken}}}',
    ),
    RequestAuthenticationType.basic => const RequestAuthentication.basic(
      username: '{{${AuthenticationVariableNames.basicUsername}}}',
      password: '{{${AuthenticationVariableNames.basicPassword}}}',
    ),
    RequestAuthenticationType.apiKey => RequestAuthentication.apiKey(
      apiKeyName: authentication.apiKeyName.trim().isEmpty
          ? AuthenticationVariableNames.defaultApiKeyHeader
          : authentication.apiKeyName,
      apiKeyValue: '{{${AuthenticationVariableNames.apiKey}}}',
      apiKeyLocation: authentication.apiKeyLocation,
    ),
  };

  /// 判断变量是否为当前认证已不使用的旧凭据变量（应隐藏）。
  bool _isHiddenInactiveAuthenticationVariable(
    _StoredVariable variable,
    Set<String> activeKeys,
  ) =>
      _removableAuthenticationVariableKeys.contains(variable.key) &&
      !activeKeys.contains(variable.key);

  /// 可由用户删除的认证凭据变量名（固定 token 不在此列）。
  static const _removableAuthenticationVariableKeys = {
    AuthenticationVariableNames.basicUsername,
    AuthenticationVariableNames.basicPassword,
    AuthenticationVariableNames.apiKey,
  };

  /// 全部认证模板可能引用的变量名集合。
  static const _allAuthenticationVariableKeys = {
    AuthenticationVariableNames.bearerToken,
    ..._removableAuthenticationVariableKeys,
  };

  /// 提取认证模板中引用的全部变量名。
  Set<String> _authenticationVariableKeys(
    RequestAuthentication authentication,
  ) => {
    for (final template in authentication.templateValues)
      ...RegExp(
        r'\{\{\s*([^}]+?)\s*\}\}',
      ).allMatches(template).map((match) => match.group(1)!.trim()),
  };

  /// 为指定环境构造一个必填的空 baseUrl 变量。
  _StoredVariable _requiredBaseUrl(EnvironmentProfile profile) =>
      _StoredVariable(
        '${profile.id}-base-url',
        profile.name,
        'baseUrl',
        '',
        EnvironmentVariableType.string,
        isRequired: true,
      );

  /// 规范化名称并确保同一工作区的环境名称不重复。
  String _validateEnvironmentName(String name, {String? excludingId}) {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Environment name is required.');
    }
    final duplicate = _profiles.any(
      (profile) =>
          profile.id != excludingId &&
          profile.name.toLowerCase() == normalized.toLowerCase(),
    );
    if (duplicate) {
      throw ArgumentError.value(
        name,
        'name',
        'Environment name already exists.',
      );
    }
    return normalized;
  }

  /// 按变量类型规范化输入值，统一移除所有可编辑值的首尾空白。
  String _normalizeValueForType(String value, EnvironmentVariableType type) {
    final normalized = value.trim();
    switch (type) {
      case EnvironmentVariableType.string:
      case EnvironmentVariableType.secret:
        return normalized;
      case EnvironmentVariableType.number:
        return num.tryParse(normalized) == null ? '0' : normalized;
      case EnvironmentVariableType.boolean:
        return switch (normalized.toLowerCase()) {
          'true' || '1' || 'yes' || 'on' => 'true',
          _ => 'false',
        };
    }
  }
}

/// 变量定位信息：所在列表及其中下标，用于就地更新/删除。
class _VariableLocation {
  const _VariableLocation(this.variables, this.index);

  /// 变量所在的存储列表。
  final List<_StoredVariable> variables;

  /// 变量在列表中的下标。
  final int index;
}

/// 变量的内部存储表示（不可变），含作用域与类型信息。
class _StoredVariable {
  const _StoredVariable(
    this.id,
    this.scope,
    this.key,
    this.value,
    this.type, {
    this.isProtected = false,
    this.isRequired = false,
  });

  /// 变量唯一 ID。
  final String id;

  /// 变量所属作用域名（环境名或 Global）。
  final String scope;

  /// 变量名（用于模板引用）。
  final String key;

  /// 变量值（密钥为明文存储，展示时再脱敏）。
  final String value;

  /// 变量类型（字符串/数字/密钥）。
  final EnvironmentVariableType type;

  /// token 这类环境必需变量不可删除、改名或改类型。
  final bool isProtected;

  /// baseUrl 这类必填变量不可删除、改名，也不可为空。
  final bool isRequired;

  /// 复制并仅替换给定字段的变量，其余字段保持原值。
  _StoredVariable copyWith({
    String? scope,
    String? key,
    String? value,
    EnvironmentVariableType? type,
    bool? isProtected,
    bool? isRequired,
  }) => _StoredVariable(
    id,
    scope ?? this.scope,
    key ?? this.key,
    value ?? this.value,
    type ?? this.type,
    isProtected: isProtected ?? this.isProtected,
    isRequired: isRequired ?? this.isRequired,
  );

  /// 序列化为存储 Map，供文件持久化。
  Map<String, Object> toJson() => {
    'id': id,
    'scope': scope,
    'key': key,
    'value': value,
    'type': type.name,
    'isProtected': isProtected,
    'isRequired': isRequired,
  };

  /// 从存储 Map 恢复变量；字段缺失或类型不符时抛出异常。
  factory _StoredVariable.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Invalid variable.');
    final json = Map<String, dynamic>.from(value);
    final id = json['id'];
    final scope = json['scope'];
    final key = json['key'];
    final storedValue = json['value'];
    final typeName = json['type'];
    final type = switch (typeName) {
      'string' => EnvironmentVariableType.string,
      'number' => EnvironmentVariableType.number,
      'boolean' => EnvironmentVariableType.boolean,
      'secret' => EnvironmentVariableType.secret,
      _ => null,
    };
    if (id is! String ||
        scope is! String ||
        key is! String ||
        storedValue is! String ||
        type == null) {
      throw const FormatException('Invalid variable fields.');
    }
    return _StoredVariable(
      id,
      scope,
      key,
      storedValue,
      type,
      isProtected: json['isProtected'] == true,
      isRequired: json['isRequired'] == true,
    );
  }

  /// 转成可供 UI 展示的视图；密钥未揭示时用圆点占位并标记脱敏。
  EnvironmentVariableView toView({
    required bool revealSecret,
    bool isAuthenticationBinding = false,
  }) => EnvironmentVariableView(
    id: id,
    scope: scope,
    key: key,
    displayValue: type == EnvironmentVariableType.secret && !revealSecret
        ? '••••••••••••••••'
        : value,
    type: type,
    isMasked: type == EnvironmentVariableType.secret && !revealSecret,
    isProtected: isProtected,
    isRequired: isRequired,
    isAuthenticationBinding: isAuthenticationBinding,
  );
}
