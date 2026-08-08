part of 'workspace_view_model.dart';

/// 请求鉴权、参数、正文与 multipart 配置操作。
extension WorkspaceRequestConfigurationOperations on WorkspaceViewModel {
  /// Bearer 认证来自独立配置，而不是 Headers 中的 Authorization 行。
  bool get usesBearerAuthentication => activeAuthentication.usesBearerToken;

  /// 当前请求实际生效的认证配置（请求级或环境级）。
  RequestAuthentication get activeAuthentication =>
      _effectiveAuthenticationFor(activeDraft);

  /// 当前请求认证的来源（请求自身或活动环境）。
  RequestAuthenticationSource get activeAuthenticationSource =>
      activeDraft.authenticationSource;

  /// 当前请求采用的独立认证类型。
  RequestAuthenticationType get activeAuthenticationType =>
      activeAuthentication.type;

  /// Bearer token 可为固定值或环境变量模板，编辑器中不附加 `Bearer ` 前缀。
  String get activeBearerToken => activeAuthentication.bearerToken;

  /// Basic 认证的用户名。
  String get activeBasicUsername => activeAuthentication.username;

  /// Basic 认证的密码。
  String get activeBasicPassword => activeAuthentication.password;

  /// API Key 认证的键名。
  String get activeApiKeyName => activeAuthentication.apiKeyName;

  /// API Key 认证的键值。
  String get activeApiKeyValue => activeAuthentication.apiKeyValue;

  /// API Key 的注入位置（Header / Query）。
  ApiKeyLocation get activeApiKeyLocation =>
      activeAuthentication.apiKeyLocation;

  /// API Key 选择 Query 时在 Params 中展示的只读认证行。
  KeyValueRow? get activeManagedApiKeyQueryParameter {
    final authentication = activeAuthentication;
    if (!authentication.apiKeyInQuery ||
        authentication.apiKeyName.trim().isEmpty) {
      return null;
    }
    return KeyValueRow(
      id: 'authentication-api-key-query',
      keyName: authentication.apiKeyName,
      value: authentication.apiKeyValue,
      secret: true,
    );
  }

  /// 可插入当前请求 Params 的环境变量。
  ///
  /// 环境只提供值，不能从变量名推断 API 的 query key。选择变量后由用户
  /// 指定参数名，例如将 `domain` 映射为 `input={{domain}}`。
  List<KeyValueRow> get activeAvailableEnvironmentParameters =>
      _environmentParameterSuggestions(activeDraft);

  /// 开启或关闭 Bearer 认证对应的 Authorization 请求头。
  void setActiveBearerAuthentication(bool enabled) {
    _updateActiveDraft(
      activeDraft.copyWith(
        authenticationSource: RequestAuthenticationSource.request,
        authentication: enabled
            ? RequestAuthentication.bearer(
                activeBearerToken.isNotEmpty
                    ? activeBearerToken
                    : '{{${AuthenticationVariableNames.bearerToken}}}',
              )
            : const RequestAuthentication.none(),
      ),
    );
  }

  /// 切换当前请求认证的引用来源（请求配置 / 活动环境配置）。
  void setActiveAuthenticationSource(RequestAuthenticationSource source) {
    _updateActiveDraft(activeDraft.copyWith(authenticationSource: source));
  }

  /// 切换认证方式，并为新的方式保留合理、可引用环境变量的默认字段。
  void setActiveAuthenticationType(RequestAuthenticationType type) {
    final current = activeDraft.authentication;
    final authentication = switch (type) {
      RequestAuthenticationType.none => const RequestAuthentication.none(),
      RequestAuthenticationType.bearer => RequestAuthentication.bearer(
        current.bearerToken.isNotEmpty
            ? current.bearerToken
            : '{{${AuthenticationVariableNames.bearerToken}}}',
      ),
      RequestAuthenticationType.basic => RequestAuthentication.basic(
        username: current.username.isNotEmpty
            ? current.username
            : '{{${AuthenticationVariableNames.basicUsername}}}',
        password: current.password.isNotEmpty
            ? current.password
            : '{{${AuthenticationVariableNames.basicPassword}}}',
      ),
      RequestAuthenticationType.apiKey => RequestAuthentication.apiKey(
        apiKeyName: current.apiKeyName.isNotEmpty
            ? current.apiKeyName
            : AuthenticationVariableNames.defaultApiKeyHeader,
        apiKeyValue: current.apiKeyValue.isNotEmpty
            ? current.apiKeyValue
            : '{{${AuthenticationVariableNames.apiKey}}}',
        apiKeyLocation: current.apiKeyLocation,
      ),
    };
    _updateActiveDraft(
      activeDraft.copyWith(
        authenticationSource: RequestAuthenticationSource.request,
        authentication: authentication,
      ),
    );
  }

  /// 更新 Bearer token，确保以 `Bearer ` 前缀写入 Authorization 头。
  void updateActiveBearerToken(String token) {
    _updateActiveDraft(
      activeDraft.copyWith(
        authenticationSource: RequestAuthenticationSource.request,
        authentication: RequestAuthentication.bearer(token),
      ),
    );
  }

  /// 更新 Basic 认证的用户名与密码。
  void updateActiveBasicAuthentication({String? username, String? password}) {
    _updateActiveDraft(
      activeDraft.copyWith(
        authenticationSource: RequestAuthenticationSource.request,
        authentication: activeDraft.authentication.copyWith(
          type: RequestAuthenticationType.basic,
          username: username,
          password: password,
        ),
      ),
    );
  }

  /// 更新 API Key 认证的键名、键值与注入位置。
  void updateActiveApiKeyAuthentication({
    String? name,
    String? value,
    ApiKeyLocation? location,
  }) {
    _updateActiveDraft(
      activeDraft.copyWith(
        authenticationSource: RequestAuthenticationSource.request,
        authentication: activeDraft.authentication.copyWith(
          type: RequestAuthenticationType.apiKey,
          apiKeyName: name,
          apiKeyValue: value,
          apiKeyLocation: location,
        ),
      ),
    );
  }

  /// 更新活动环境的认证配置，并清理受影响的执行上下文。
  void updateActiveEnvironmentAuthentication(
    RequestAuthentication authentication,
  ) {
    _environmentStore.updateActiveAuthentication(authentication);
    _invalidateEnvironmentExecutionContext();
    _notify();
  }

  /// 切换活动环境的认证方式，未填写的字段保留原值或填入变量模板默认值。
  void updateActiveEnvironmentAuthenticationType(
    RequestAuthenticationType type,
  ) {
    final current = activeEnvironment.authentication;
    final authentication = switch (type) {
      RequestAuthenticationType.none => const RequestAuthentication.none(),
      RequestAuthenticationType.bearer => RequestAuthentication.bearer(
        current.bearerToken.isNotEmpty
            ? current.bearerToken
            : '{{${AuthenticationVariableNames.bearerToken}}}',
      ),
      RequestAuthenticationType.basic => RequestAuthentication.basic(
        username: current.username.isNotEmpty
            ? current.username
            : '{{${AuthenticationVariableNames.basicUsername}}}',
        password: current.password.isNotEmpty
            ? current.password
            : '{{${AuthenticationVariableNames.basicPassword}}}',
      ),
      RequestAuthenticationType.apiKey => RequestAuthentication.apiKey(
        apiKeyName: current.apiKeyName.isNotEmpty
            ? current.apiKeyName
            : AuthenticationVariableNames.defaultApiKeyHeader,
        apiKeyValue: current.apiKeyValue.isNotEmpty
            ? current.apiKeyValue
            : '{{${AuthenticationVariableNames.apiKey}}}',
        apiKeyLocation: current.apiKeyLocation,
      ),
    };
    updateActiveEnvironmentAuthentication(authentication);
  }

  /// 将当前环境变量作为一个可编辑的 Params 模板行插入请求。
  ///
  /// [parameterKey] 是 API 定义的 query 参数名，允许与环境变量名不同。
  /// 例如将 `domain` 映射为 `input={{domain}}`。
  void addActiveEnvironmentVariableParameter(
    String key, {
    String? parameterKey,
  }) {
    if (key.trim().isEmpty) return;
    final queryKey = parameterKey?.trim().isNotEmpty == true
        ? parameterKey!.trim()
        : key.trim();
    final normalizedKey = queryKey.toLowerCase();
    final existingTemplates = [
      activeDraft.baseUrlToken,
      activeDraft.path,
      for (final parameter in activeDraft.params) ...[
        parameter.keyName,
        parameter.value,
      ],
    ];
    if (activeDraft.params.any(
          (parameter) =>
              parameter.keyName.trim().toLowerCase() == normalizedKey,
        ) ||
        existingTemplates.any(
          (template) => _referencesVariable(template, key),
        )) {
      return;
    }
    final fields = List<KeyValueRow>.of(activeDraft.params)
      ..add(
        KeyValueRow(
          id: _nextDraftFieldId(headers: false),
          keyName: queryKey,
          value: '{{$key}}',
        ),
      );
    _updateActiveDraft(activeDraft.copyWith(params: fields));
  }

  /// 格式化活动请求的 JSON 请求体；无效 JSON 时返回错误说明。
  String? formatActiveDraftJson() {
    final source = activeDraft.body.trim();
    if (source.isEmpty) return 'Enter a JSON request body before formatting.';
    try {
      final formatted = const JsonEncoder.withIndent(
        '  ',
      ).convert(jsonDecode(source));
      _updateActiveDraft(activeDraft.copyWith(body: formatted));
      return null;
    } on FormatException {
      return 'The request body is not valid JSON.';
    }
  }

  /// 活动请求当前启用的 Content-Type 头值，未设置时为空。
  String? get activeContentType {
    for (final header in activeDraft.headers) {
      if (header.enabled && header.keyName.toLowerCase() == 'content-type') {
        return header.value;
      }
    }
    return null;
  }

  /// 当前请求体是否使用 JSON 类型。
  bool get usesJsonBody =>
      activeContentType?.toLowerCase().contains('json') ?? false;

  /// 当前请求体是否使用 multipart/form-data。
  bool get usesMultipartBody => _hasMultipartContentType(activeDraft.headers);

  /// 更新 Content-Type 头；传 null 表示移除该头。
  void updateActiveContentType(String? contentType) {
    final headers = List<KeyValueRow>.of(activeDraft.headers);
    final index = headers.indexWhere(
      (header) => header.keyName.toLowerCase() == 'content-type',
    );
    if (contentType == null) {
      if (index >= 0) headers.removeAt(index);
    } else {
      // 已有 Content-Type 则改写，否则新增一条。
      final header = KeyValueRow(
        id: index >= 0 ? headers[index].id : _nextDraftFieldId(headers: true),
        keyName: 'Content-Type',
        value: contentType,
        enabled: true,
        secret: false,
      );
      if (index >= 0) {
        headers[index] = header;
      } else {
        headers.add(header);
      }
    }
    _updateActiveDraft(activeDraft.copyWith(headers: headers));
  }

  /// 更新 multipart 文本字段中的某一行。
  void updateActiveMultipartField({
    required int index,
    String? keyName,
    String? value,
    bool? enabled,
  }) {
    final fields = List<KeyValueRow>.of(activeDraft.multipartFields);
    fields[index] = fields[index].copyWith(
      keyName: keyName,
      value: value,
      enabled: enabled,
    );
    _updateActiveDraft(activeDraft.copyWith(multipartFields: fields));
  }

  /// 向 multipart 表单追加一行空文本字段。
  void addActiveMultipartField() {
    final fields = List<KeyValueRow>.of(activeDraft.multipartFields)
      ..add(KeyValueRow(id: _nextMultipartFieldId(), keyName: '', value: ''));
    _updateActiveDraft(activeDraft.copyWith(multipartFields: fields));
  }

  /// 移除 multipart 表单中的指定文本字段。
  void removeActiveMultipartField(int index) {
    final fields = List<KeyValueRow>.of(activeDraft.multipartFields);
    fields.removeAt(index);
    _updateActiveDraft(activeDraft.copyWith(multipartFields: fields));
  }

  /// 向 multipart 表单追加一个文件条目。
  void addActiveMultipartFile({
    required String path,
    required String fileName,
    required int sizeBytes,
    required String keyName,
  }) {
    final files = List<MultipartFileRow>.of(activeDraft.multipartFiles)
      ..add(
        MultipartFileRow(
          id: _nextMultipartFileId(),
          keyName: keyName,
          path: path,
          fileName: fileName,
          sizeBytes: sizeBytes,
        ),
      );
    _updateActiveDraft(activeDraft.copyWith(multipartFiles: files));
  }

  /// 更新 multipart 文件条目中的某个字段。
  void updateActiveMultipartFile({
    required int index,
    String? keyName,
    bool? enabled,
  }) {
    final files = List<MultipartFileRow>.of(activeDraft.multipartFiles);
    files[index] = files[index].copyWith(keyName: keyName, enabled: enabled);
    _updateActiveDraft(activeDraft.copyWith(multipartFiles: files));
  }

  /// 将所有 multipart 文件条目的 key 统一改为指定值。
  void updateAllActiveMultipartFileKeyNames(String keyName) {
    final files = [
      for (final file in activeDraft.multipartFiles)
        file.copyWith(keyName: keyName),
    ];
    _updateActiveDraft(activeDraft.copyWith(multipartFiles: files));
  }

  /// 移除 multipart 表单中的指定文件条目。
  void removeActiveMultipartFile(int index) {
    final files = List<MultipartFileRow>.of(activeDraft.multipartFiles);
    files.removeAt(index);
    _updateActiveDraft(activeDraft.copyWith(multipartFiles: files));
  }

  /// 指定草稿字段当前是否已展开显示明文。
  bool isActiveDraftFieldRevealed(String fieldId) =>
      _revealedDraftFieldIds.contains(fieldId);

  /// 切换草稿字段的明文 / 掩码显示。
  void toggleActiveDraftFieldVisibility(String fieldId) {
    if (fieldId.isEmpty) return;
    // 先尝试移除；失败说明此前未展开，则标记为展开。
    if (!_revealedDraftFieldIds.remove(fieldId)) {
      _revealedDraftFieldIds.add(fieldId);
    }
    _notify();
  }

  /// 丢弃指定请求的全部未保存草稿修改，并清理其字段可见性状态。
  void discardRequestDraft(String requestId) {
    _draftOverrides.remove(requestId);
    _revealedDraftFieldIds.removeWhere((id) => id.startsWith('$requestId:'));
    _notify();
  }
}
