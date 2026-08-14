import 'dart:convert';

import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/environments/environment_authentication_policy.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 请求鉴权、参数、正文与 multipart 配置操作。
extension WorkspaceRequestConfigurationOperations on WorkspaceViewModel {
  /// Bearer 认证来自独立配置，而不是 Headers 中的 Authorization 行。
  bool get usesBearerAuthentication => activeAuthentication.usesBearerToken;

  /// 当前请求实际生效的认证配置（请求级或环境级）。
  RequestAuthentication get activeAuthentication =>
      effectiveAuthenticationForInternal(activeDraft);

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
      environmentParameterSuggestionsInternal(activeDraft);

  /// 开启或关闭 Bearer 认证对应的 Authorization 请求头。
  void setActiveBearerAuthentication(bool enabled) {
    updateActiveDraftInternal(
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
    updateActiveDraftInternal(
      activeDraft.copyWith(authenticationSource: source),
    );
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
    updateActiveDraftInternal(
      activeDraft.copyWith(
        authenticationSource: RequestAuthenticationSource.request,
        authentication: authentication,
      ),
    );
  }

  /// 更新 Bearer token，确保以 `Bearer ` 前缀写入 Authorization 头。
  void updateActiveBearerToken(String token) {
    updateActiveDraftInternal(
      activeDraft.copyWith(
        authenticationSource: RequestAuthenticationSource.request,
        authentication: RequestAuthentication.bearer(token),
      ),
    );
  }

  /// 更新 Basic 认证的用户名与密码。
  void updateActiveBasicAuthentication({String? username, String? password}) {
    updateActiveDraftInternal(
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
    updateActiveDraftInternal(
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
    internals.environmentStore.updateActiveAuthentication(authentication);
    invalidateEnvironmentExecutionContextInternal();
    notifyWorkspace();
  }

  /// 更新 Environment 管理器当前编辑目标的认证配置。
  void updateEditingEnvironmentAuthentication(
    RequestAuthentication authentication,
  ) {
    internals.environmentStore.updateEnvironmentAuthentication(
      environmentId: editingEnvironment.id,
      authentication: authentication,
    );
    if (isEditingActiveEnvironment) {
      invalidateEnvironmentExecutionContextInternal();
    }
    notifyWorkspace();
  }

  /// 切换活动环境的认证方式，未填写的字段保留原值或填入变量模板默认值。
  void updateActiveEnvironmentAuthenticationType(
    RequestAuthenticationType type,
  ) {
    final authentication = EnvironmentAuthenticationPolicy.forType(
      activeEnvironment.authentication,
      type,
    );
    updateActiveEnvironmentAuthentication(authentication);
  }

  /// 切换管理器编辑目标的认证方式，不隐式切换活动环境。
  void updateEditingEnvironmentAuthenticationType(
    RequestAuthenticationType type,
  ) {
    final authentication = EnvironmentAuthenticationPolicy.forType(
      editingEnvironment.authentication,
      type,
    );
    updateEditingEnvironmentAuthentication(authentication);
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
          (template) => referencesVariableInternal(template, key),
        )) {
      return;
    }
    final fields = List<KeyValueRow>.of(activeDraft.params)
      ..add(
        KeyValueRow(
          id: nextDraftFieldIdInternal(headers: false),
          keyName: queryKey,
          value: '{{$key}}',
        ),
      );
    updateActiveDraftInternal(activeDraft.copyWith(params: fields));
  }

  /// 格式化活动请求的 JSON 请求体；无效 JSON 时返回错误说明。
  String? formatActiveDraftJson() {
    final source = activeDraft.body.trim();
    if (source.isEmpty) return 'Enter a JSON request body before formatting.';
    try {
      final formatted = const JsonEncoder.withIndent(
        '  ',
      ).convert(jsonDecode(source));
      updateActiveDraftInternal(activeDraft.copyWith(body: formatted));
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
  bool get usesMultipartBody =>
      hasMultipartContentTypeInternal(activeDraft.headers);

  /// 当前请求体是否使用 application/x-www-form-urlencoded。
  bool get usesFormUrlEncodedBody =>
      hasFormUrlEncodedContentTypeInternal(activeDraft.headers);

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
        id: index >= 0
            ? headers[index].id
            : nextDraftFieldIdInternal(headers: true),
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
    updateActiveDraftInternal(activeDraft.copyWith(headers: headers));
  }

  /// 更新 URL 编码表单字段中的某一行。
  void updateActiveFormUrlEncodedField({
    required int index,
    String? keyName,
    String? value,
    bool? enabled,
  }) {
    final fields = List<KeyValueRow>.of(activeDraft.formUrlEncodedFields);
    fields[index] = fields[index].copyWith(
      keyName: keyName,
      value: value,
      enabled: enabled,
    );
    updateActiveDraftInternal(
      activeDraft.copyWith(formUrlEncodedFields: fields),
    );
  }

  /// 向 URL 编码表单追加一行空文本字段。
  void addActiveFormUrlEncodedField() {
    final fields = List<KeyValueRow>.of(activeDraft.formUrlEncodedFields)
      ..add(
        KeyValueRow(
          id: nextFormUrlEncodedFieldIdInternal(),
          keyName: '',
          value: '',
        ),
      );
    updateActiveDraftInternal(
      activeDraft.copyWith(formUrlEncodedFields: fields),
    );
  }

  /// 移除指定 URL 编码表单字段。
  void removeActiveFormUrlEncodedField(int index) {
    final fields = List<KeyValueRow>.of(activeDraft.formUrlEncodedFields);
    fields.removeAt(index);
    updateActiveDraftInternal(
      activeDraft.copyWith(formUrlEncodedFields: fields),
    );
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
    updateActiveDraftInternal(activeDraft.copyWith(multipartFields: fields));
  }

  /// 向 multipart 表单追加一行空文本字段。
  void addActiveMultipartField() {
    final fields = List<KeyValueRow>.of(activeDraft.multipartFields)
      ..add(
        KeyValueRow(id: nextMultipartFieldIdInternal(), keyName: '', value: ''),
      );
    updateActiveDraftInternal(activeDraft.copyWith(multipartFields: fields));
  }

  /// 移除 multipart 表单中的指定文本字段。
  void removeActiveMultipartField(int index) {
    final fields = List<KeyValueRow>.of(activeDraft.multipartFields);
    fields.removeAt(index);
    updateActiveDraftInternal(activeDraft.copyWith(multipartFields: fields));
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
          id: nextMultipartFileIdInternal(),
          keyName: keyName,
          path: path,
          fileName: fileName,
          sizeBytes: sizeBytes,
        ),
      );
    updateActiveDraftInternal(activeDraft.copyWith(multipartFiles: files));
  }

  /// 更新 multipart 文件条目中的某个字段。
  void updateActiveMultipartFile({
    required int index,
    String? keyName,
    bool? enabled,
  }) {
    final files = List<MultipartFileRow>.of(activeDraft.multipartFiles);
    files[index] = files[index].copyWith(keyName: keyName, enabled: enabled);
    updateActiveDraftInternal(activeDraft.copyWith(multipartFiles: files));
  }

  /// 将所有 multipart 文件条目的 key 统一改为指定值。
  void updateAllActiveMultipartFileKeyNames(String keyName) {
    final files = [
      for (final file in activeDraft.multipartFiles)
        file.copyWith(keyName: keyName),
    ];
    updateActiveDraftInternal(activeDraft.copyWith(multipartFiles: files));
  }

  /// 移除 multipart 表单中的指定文件条目。
  void removeActiveMultipartFile(int index) {
    final files = List<MultipartFileRow>.of(activeDraft.multipartFiles);
    files.removeAt(index);
    updateActiveDraftInternal(activeDraft.copyWith(multipartFiles: files));
  }

  /// 指定草稿字段当前是否已展开显示明文。
  bool isActiveDraftFieldRevealed(String fieldId) =>
      internals.revealedDraftFieldIds.contains(fieldId);

  /// 切换草稿字段的明文 / 掩码显示。
  void toggleActiveDraftFieldVisibility(String fieldId) {
    if (fieldId.isEmpty) return;
    // 先尝试移除；失败说明此前未展开，则标记为展开。
    if (!internals.revealedDraftFieldIds.remove(fieldId)) {
      internals.revealedDraftFieldIds.add(fieldId);
    }
    notifyWorkspace();
  }

  /// 丢弃指定请求的全部未保存草稿修改，并清理其字段可见性状态。
  void discardRequestDraft(String requestId) {
    internals.draftOverrides.remove(requestId);
    internals.revealedDraftFieldIds.removeWhere(
      (id) => id.startsWith('$requestId:'),
    );
    notifyWorkspace();
  }
}
