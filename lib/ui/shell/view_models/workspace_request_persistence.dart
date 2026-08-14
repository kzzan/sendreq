import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/request_runtime/long_lived_session_context.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 请求草稿转换、变量解析、脱敏快照与历史持久化辅助方法。
extension WorkspacePersistenceOperations on WorkspaceViewModel {
  /// 将请求草稿的修改保存回仓库，并清除对应覆盖草稿。
  void saveRequest(String requestId) {
    final draft = internals.draftOverrides[requestId];
    if (draft == null) {
      return;
    }
    final original = internals.assetRepository.getRequest(requestId);
    // 合并草稿变更与原始请求的固定信息（ID / 归属 / 元数据）。
    internals.assetRepository.updateRequest(
      requestWithDraftInternal(original, draft),
    );
    internals.draftOverrides.remove(requestId);
    internals.recordUserMessage(
      'Request changes saved.',
      deduplicationKey: 'request.saved',
    );
    notifyWorkspace();
  }

  /// 保存活动请求并等待具体仓储完成持久化；桌面生产仓储会等待 Isar 写事务。
  Future<void> saveActiveRequestDurably() async {
    final requestId = internals.activeRequestId;
    if (requestId == null) return;
    saveRequest(requestId);
    await internals.assetRepository.flush();
  }

  /// 将仓库中的请求定义转换为视图层的请求资源。
  RequestResource toRequestResourceInternal(ApiRequestDefinition request) {
    // 树、标签页与编辑器共享草稿优先的请求类型，避免切到 gRPC 后仍显示旧 GET。
    final display = requestWithDraftInternal(request);
    return RequestResource(
      id: display.id,
      method: display.method,
      name: display.name,
      path: _pathFor(display.urlTemplate),
      folder: display.metadata['folderName'] ?? 'Ungrouped',
      protocol: display.protocol,
      isDirty: openRequestTabs.any(
        (tab) => tab.requestId == display.id && isRequestDirty(display.id),
      ),
    );
  }

  /// 将仓库中的请求定义转换为可编辑草稿，并为每行生成稳定 ID。
  RequestDraft toRequestDraftInternal(ApiRequestDefinition request) {
    final urlParts = internals.draftEditor.splitUrl(request.urlTemplate);
    final authentication = _authenticationFor(request);
    final migratesLegacyBearer =
        !request.authentication.usesBearerToken &&
        authentication.usesBearerToken;
    return RequestDraft(
      method: request.method,
      baseUrlToken: urlParts.baseUrlToken,
      path: urlParts.path,
      params: [
        for (final (index, parameter) in urlParts.parameters.indexed)
          KeyValueRow(
            id: '${request.id}:param:url-$index',
            keyName: parameter.key,
            value: parameter.value,
            enabled: true,
          ),
        for (final (index, field) in request.queryParams.indexed)
          KeyValueRow(
            id: '${request.id}:param:$index',
            keyName: field.key,
            value: field.value,
            enabled: field.enabled,
            secret: field.secretReference,
          ),
      ],
      headers: [
        for (final (index, field) in request.headers.indexed)
          if (!migratesLegacyBearer || !_isBearerAuthorizationField(field))
            KeyValueRow(
              id: '${request.id}:header:$index',
              keyName: field.key,
              value: field.value,
              enabled: field.enabled,
              secret: field.secretReference,
            ),
      ],
      body: request.bodyTemplate,
      authentication: authentication,
      authenticationSource: request.authenticationSource,
      protocol: request.protocol,
      webSocket: request.webSocket,
      grpc: request.grpc,
      formUrlEncodedFields: [
        for (final (index, field) in request.formUrlEncodedFields.indexed)
          KeyValueRow(
            id: '${request.id}:urlencoded-field:$index',
            keyName: field.key,
            value: field.value,
            enabled: field.enabled,
            secret: field.secretReference,
          ),
      ],
      multipartFields: [
        for (final (index, field) in request.multipartFields.indexed)
          KeyValueRow(
            id: '${request.id}:multipart-field:$index',
            keyName: field.key,
            value: field.value,
            enabled: field.enabled,
            secret: field.secretReference,
          ),
      ],
      multipartFiles: [
        for (final (index, file) in request.multipartFiles.indexed)
          MultipartFileRow(
            id: '${request.id}:multipart-file:$index',
            keyName: file.key,
            path: file.path,
            fileName: file.fileName,
            sizeBytes: file.sizeBytes,
            enabled: file.enabled,
          ),
      ],
    );
  }

  /// 把旧版 Headers 中的 Bearer 条目提升为独立 Auth 配置。
  RequestAuthentication _authenticationFor(ApiRequestDefinition request) {
    if (request.authentication.type != RequestAuthenticationType.none) {
      return request.authentication;
    }
    for (final header in request.headers) {
      if (_isBearerAuthorizationField(header)) {
        return RequestAuthentication.bearer(
          header.value.trimLeft().substring('Bearer '.length),
        );
      }
    }
    return const RequestAuthentication.none();
  }

  /// 从 URL 模板中提取去掉 baseUrl 标记后的路径部分。
  String _pathFor(String urlTemplate) {
    final tokenEnd = urlTemplate.indexOf('}}');
    return urlTemplate.startsWith('{{') && tokenEnd >= 0
        ? urlTemplate.substring(tokenEnd + 2)
        : urlTemplate;
  }

  /// 将草稿修改合并回请求定义，固定信息（ID / 归属 / 元数据）取自原始请求。
  ApiRequestDefinition requestWithDraftInternal(
    ApiRequestDefinition original, [
    RequestDraft? draft,
  ]) {
    final value = draft ?? internals.draftOverrides[original.id];
    if (value == null) return original;
    return ApiRequestDefinition(
      id: original.id,
      collectionId: original.collectionId,
      folderId: original.folderId,
      name: original.name,
      method: value.method,
      urlTemplate: '${value.baseUrlToken}${value.path}',
      queryParams: _toApiFields(value.params),
      headers: _toApiFields(value.headers),
      bodyTemplate: value.body,
      authentication: value.authentication,
      authenticationSource: value.authenticationSource,
      protocol: value.protocol,
      webSocket: value.webSocket,
      grpc: value.grpc,
      formUrlEncodedFields: _toApiFields(value.formUrlEncodedFields),
      multipartFields: _toApiFields(value.multipartFields),
      multipartFiles: _toApiFileFields(value.multipartFiles),
      metadata: original.metadata,
    );
  }

  /// 组装展示用 URL：基础地址 + 路径，并将启用的 Params（含认证参数）拼为 query。
  String urlWithParamsInternal(RequestDraft draft) {
    final url = '${draft.baseUrlToken}${draft.path}';
    final fragmentIndex = url.indexOf('#');
    final base = fragmentIndex < 0 ? url : url.substring(0, fragmentIndex);
    final fragment = fragmentIndex < 0 ? '' : url.substring(fragmentIndex);
    final query = [
      for (final parameter in paramsWithAuthenticationInternal(draft))
        if (parameter.enabled && parameter.keyName.trim().isNotEmpty)
          '${parameter.keyName}=${parameter.value}',
    ].join('&');
    return query.isEmpty ? '$base$fragment' : '$base?$query$fragment';
  }

  /// 将完整 URL 拆分为 baseUrl 标记、路径与 query 参数，供编辑框同步显示。

  /// 将新草稿写入活动请求的覆盖映射并触发重绘。
  void updateActiveDraftInternal(RequestDraft draft) {
    final previous = activeDraft;
    final next = internals.draftEditor.normalize(draft);
    if (_longLivedConfigurationChanged(previous, next)) {
      if (previous.protocol == ApiRequestProtocol.webSocket) {
        internals.webSocketSessions.markConfigurationChanged(
          RequestRef(id: internals.activeRequestId!),
        );
      }
      if (previous.protocol == ApiRequestProtocol.grpc) {
        internals.grpcCalls.markConfigurationChanged(
          RequestRef(id: internals.activeRequestId!),
        );
      }
    }
    internals.draftOverrides[internals.activeRequestId!] = next;
    notifyWorkspace();
  }

  /// gRPC 正文是流式调用的下一条消息草稿，不属于已启动调用的连接配置；
  /// 其余连接相关草稿变动均需让已有长连接明确显示“重新连接后生效”。
  bool _longLivedConfigurationChanged(
    RequestDraft previous,
    RequestDraft next,
  ) {
    if (previous.protocol != next.protocol) return true;
    if (previous.protocol == ApiRequestProtocol.http) return false;
    if (previous.protocol == ApiRequestProtocol.grpc &&
        _sameGrpcConnectionConfiguration(previous, next)) {
      return false;
    }
    return true;
  }

  /// 比较已启动 gRPC 调用的连接边界。草稿规范化会重新创建认证对象，不能用
  /// 对象身份判断；body 始终是下一条待发送消息，不会改变正在运行的调用。
  bool _sameGrpcConnectionConfiguration(
    RequestDraft previous,
    RequestDraft next,
  ) =>
      previous.method == next.method &&
      previous.baseUrlToken == next.baseUrlToken &&
      previous.path == next.path &&
      _sameKeyValueRows(previous.params, next.params) &&
      _sameKeyValueRows(previous.headers, next.headers) &&
      _sameAuthentication(previous.authentication, next.authentication) &&
      previous.authenticationSource == next.authenticationSource &&
      _sameGrpcConfiguration(previous.grpc, next.grpc);

  bool _sameKeyValueRows(List<KeyValueRow> first, List<KeyValueRow> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      final left = first[index];
      final right = second[index];
      if (left.id != right.id ||
          left.keyName != right.keyName ||
          left.value != right.value ||
          left.enabled != right.enabled ||
          left.secret != right.secret) {
        return false;
      }
    }
    return true;
  }

  bool _sameAuthentication(
    RequestAuthentication first,
    RequestAuthentication second,
  ) =>
      first.type == second.type &&
      first.bearerToken == second.bearerToken &&
      first.username == second.username &&
      first.password == second.password &&
      first.apiKeyName == second.apiKeyName &&
      first.apiKeyValue == second.apiKeyValue &&
      first.apiKeyLocation == second.apiKeyLocation;

  bool _sameGrpcConfiguration(
    GrpcRequestConfiguration first,
    GrpcRequestConfiguration second,
  ) =>
      _sameProtoSchema(first.protoSchema, second.protoSchema) &&
      first.serviceName == second.serviceName &&
      first.methodName == second.methodName &&
      first.useTls == second.useTls &&
      first.rpcShape == second.rpcShape &&
      first.deadlineMs == second.deadlineMs &&
      first.schemaSource == second.schemaSource;

  bool _sameProtoSchema(
    ProtobufSchemaReference? first,
    ProtobufSchemaReference? second,
  ) =>
      first?.path == second?.path &&
      first?.fingerprint == second?.fingerprint &&
      first?.messageType == second?.messageType;

  /// 构造不会包含 Token 或 API Key 明文的会话展示上下文。
  LongLivedSessionContext longLivedSessionContextForInternal(
    RequestDraft draft,
  ) {
    final authentication = effectiveAuthenticationForInternal(draft);
    final scope =
        draft.authenticationSource == RequestAuthenticationSource.environment
        ? 'Environment'
        : 'Request';
    final type = switch (authentication.type) {
      RequestAuthenticationType.none => 'No authentication',
      RequestAuthenticationType.bearer => '$scope Bearer token',
      RequestAuthenticationType.basic => '$scope Basic authentication',
      RequestAuthenticationType.apiKey => '$scope API key',
    };
    return LongLivedSessionContext(
      environmentName: activeEnvironment.name,
      authenticationLabel: type,
      authenticationType: authentication.type,
      authenticationSource: draft.authenticationSource,
    );
  }

  /// 生成参数 / 请求头行（[headers] 为 true 时表示请求头）的新字段 ID。
  String nextDraftFieldIdInternal({required bool headers}) =>
      '${internals.activeRequestId!}:${headers ? 'header' : 'param'}:new-${internals.draftFieldSequence++}';

  /// 生成 multipart 文本字段的新字段 ID。
  String nextMultipartFieldIdInternal() =>
      '${internals.activeRequestId!}:multipart-field:new-${internals.draftFieldSequence++}';

  /// 生成 URL 编码表单字段的新字段 ID。
  String nextFormUrlEncodedFieldIdInternal() =>
      '${internals.activeRequestId!}:urlencoded-field:new-${internals.draftFieldSequence++}';

  /// 生成 multipart 文件条目的新字段 ID。
  String nextMultipartFileIdInternal() =>
      '${internals.activeRequestId!}:multipart-file:new-${internals.draftFieldSequence++}';

  /// 判断 Header 是否为启用的 Bearer Authorization 条目。
  bool _isBearerAuthorizationField(ApiField header) =>
      header.enabled &&
      header.key.toLowerCase() == 'authorization' &&
      header.value.trimLeft().toLowerCase().startsWith('bearer ');

  /// API Key 的 Query 模式由 Auth 单独管理，但仍作为最终 URL 的参数参与执行。
  List<KeyValueRow> paramsWithAuthenticationInternal(RequestDraft draft) {
    final authentication = effectiveAuthenticationForInternal(draft);
    final params = [
      for (final parameter in draft.params)
        if (!authentication.apiKeyInQuery ||
            parameter.keyName.toLowerCase() !=
                authentication.apiKeyName.toLowerCase())
          parameter,
    ];
    if (authentication.apiKeyInQuery &&
        authentication.apiKeyName.trim().isNotEmpty) {
      params.add(
        KeyValueRow(
          id: 'authentication-api-key-query',
          keyName: authentication.apiKeyName,
          value: authentication.apiKeyValue,
          secret: true,
        ),
      );
    }
    return params;
  }

  /// 生成可插入 Params 的环境变量建议，排除已引用或特殊用途的变量。
  List<KeyValueRow> environmentParameterSuggestionsInternal(
    RequestDraft draft,
  ) {
    final requestParameterKeys = {
      for (final parameter in draft.params)
        if (parameter.keyName.trim().isNotEmpty)
          parameter.keyName.trim().toLowerCase(),
    };
    final requestVariableTemplates = [
      draft.baseUrlToken,
      draft.path,
      for (final parameter in draft.params) ...[
        parameter.keyName,
        parameter.value,
      ],
    ];
    return [
      for (final variable in internals.environmentStore.listVariables())
        if (variable.scope != 'Global' &&
            variable.key.trim().isNotEmpty &&
            variable.key.trim().toLowerCase() != 'baseurl' &&
            !variable.isRequired &&
            !variable.isSecret &&
            !variable.isAuthenticationBinding &&
            !requestParameterKeys.contains(variable.key.trim().toLowerCase()) &&
            !requestVariableTemplates.any(
              (template) => referencesVariableInternal(template, variable.key),
            ))
          KeyValueRow(
            id: 'environment-parameter-${variable.id}',
            keyName: variable.key,
            value: '{{${variable.key}}}',
          ),
    ];
  }

  /// 判断模板文本是否以不区分大小写的方式引用了指定环境变量。
  bool referencesVariableInternal(String template, String key) => RegExp(
    '\\{\\{\\s*${RegExp.escape(key)}\\s*\\}\\}',
    caseSensitive: false,
  ).hasMatch(template);

  /// 判断 HTTP 方法是否不携带请求体（GET / HEAD）。
  bool isBodylessHttpMethodInternal(String method) {
    final normalizedMethod = method.trim().toUpperCase();
    return normalizedMethod == 'GET' || normalizedMethod == 'HEAD';
  }

  /// 判断请求头是否声明了 multipart/form-data 类型。
  bool hasMultipartContentTypeInternal(List<KeyValueRow> headers) =>
      headers.any(
        (header) =>
            header.enabled &&
            header.keyName.toLowerCase() == 'content-type' &&
            header.value.toLowerCase().startsWith('multipart/form-data'),
      );

  bool hasFormUrlEncodedContentTypeInternal(List<KeyValueRow> headers) =>
      headers.any(
        (header) =>
            header.enabled &&
            header.keyName.toLowerCase() == 'content-type' &&
            header.value.toLowerCase().startsWith(
              'application/x-www-form-urlencoded',
            ),
      );

  /// 将模板中的环境变量解析为最终执行值。
  String resolveInternal(String template) =>
      internals.environmentStore.resolveTemplate(template).executionValue;

  /// 返回草稿实际使用的认证：环境来源时取活动环境配置，否则取请求自身。
  RequestAuthentication effectiveAuthenticationForInternal(
    RequestDraft draft,
  ) => draft.authenticationSource == RequestAuthenticationSource.environment
      ? internals.environmentStore.activeEnvironment.authentication
      : draft.authentication;

  /// 计算字节内容的 64 位 FNV-1a 哈希，用于识别文件内容变化。
  String fingerprintInternal(List<int> bytes) {
    var value = 0xcbf29ce484222325;
    for (final byte in bytes) {
      value ^= byte;
      value = (value * 0x100000001b3) & 0xffffffffffffffff;
    }
    return value.toRadixString(16).padLeft(16, '0');
  }

  /// 将草稿字段过滤掉空 key 后转换为仓库所需的 [ApiField] 列表。
  List<ApiField> _toApiFields(List<KeyValueRow> fields) => fields
      .where((field) => field.keyName.trim().isNotEmpty)
      .map(
        (field) => ApiField(
          key: field.keyName,
          value: field.value,
          enabled: field.enabled,
          secretReference: field.secret,
        ),
      )
      .toList(growable: false);

  /// 将 multipart 文件条目过滤掉无效项后转换为 [ApiFileField] 列表。
  List<ApiFileField> _toApiFileFields(List<MultipartFileRow> files) => files
      .where((file) => file.keyName.trim().isNotEmpty && file.path.isNotEmpty)
      .map(
        (file) => ApiFileField(
          key: file.keyName,
          path: file.path,
          fileName: file.fileName,
          sizeBytes: file.sizeBytes,
          enabled: file.enabled,
        ),
      )
      .toList(growable: false);
}
