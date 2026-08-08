part of 'workspace_view_model.dart';

/// 请求草稿转换、变量解析、脱敏快照与历史持久化辅助方法。
extension WorkspacePersistenceOperations on WorkspaceViewModel {
  /// 将请求草稿的修改保存回仓库，并清除对应覆盖草稿。
  void saveRequest(String requestId) {
    final draft = _draftOverrides[requestId];
    if (draft == null) {
      return;
    }
    final original = _assetRepository.getRequest(requestId);
    // 合并草稿变更与原始请求的固定信息（ID / 归属 / 元数据）。
    _assetRepository.updateRequest(_requestWithDraft(original, draft));
    _draftOverrides.remove(requestId);
    _lastActionMessage = 'Request changes saved.';
    _notify();
  }

  /// 将仓库中的请求定义转换为视图层的请求资源。
  RequestResource _toRequestResource(ApiRequestDefinition request) {
    // 树、标签页与编辑器共享草稿优先的请求类型，避免切到 gRPC 后仍显示旧 GET。
    final display = _requestWithDraft(request);
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
  RequestDraft _toRequestDraft(ApiRequestDefinition request) {
    final urlParts = _splitDraftUrl(request.urlTemplate);
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
    if (request.authentication.usesBearerToken) return request.authentication;
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
  ApiRequestDefinition _requestWithDraft(
    ApiRequestDefinition original, [
    RequestDraft? draft,
  ]) {
    final value = draft ?? _draftOverrides[original.id];
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
      multipartFields: _toApiFields(value.multipartFields),
      multipartFiles: _toApiFileFields(value.multipartFiles),
      metadata: original.metadata,
    );
  }

  /// 组装展示用 URL：基础地址 + 路径，并将启用的 Params（含认证参数）拼为 query。
  String _urlWithParams(RequestDraft draft) {
    final url = '${draft.baseUrlToken}${draft.path}';
    final fragmentIndex = url.indexOf('#');
    final base = fragmentIndex < 0 ? url : url.substring(0, fragmentIndex);
    final fragment = fragmentIndex < 0 ? '' : url.substring(fragmentIndex);
    final query = [
      for (final parameter in _paramsWithAuthentication(draft))
        if (parameter.enabled && parameter.keyName.trim().isNotEmpty)
          '${parameter.keyName}=${parameter.value}',
    ].join('&');
    return query.isEmpty ? '$base$fragment' : '$base?$query$fragment';
  }

  /// 将完整 URL 拆分为 baseUrl 标记、路径与 query 参数，供编辑框同步显示。
  _DraftUrlParts _splitDraftUrl(String url) {
    final fragmentIndex = url.indexOf('#');
    final fragment = fragmentIndex < 0 ? '' : url.substring(fragmentIndex);
    final withoutFragment = fragmentIndex < 0
        ? url
        : url.substring(0, fragmentIndex);
    final queryIndex = withoutFragment.indexOf('?');
    final location = queryIndex < 0
        ? withoutFragment
        : withoutFragment.substring(0, queryIndex);
    final rawQuery = queryIndex < 0
        ? ''
        : withoutFragment.substring(queryIndex + 1);
    final tokenEnd = location.startsWith('{{') ? location.indexOf('}}') : -1;
    return _DraftUrlParts(
      baseUrlToken: tokenEnd < 0 ? '' : location.substring(0, tokenEnd + 2),
      path:
          '${tokenEnd < 0 ? location : location.substring(tokenEnd + 2)}$fragment',
      parameters: _queryParameters(rawQuery),
    );
  }

  /// 解析 query string 为键值对列表，跳过空段。
  List<_UrlQueryParameter> _queryParameters(String query) => [
    for (final entry in query.split('&'))
      if (entry.isNotEmpty)
        _UrlQueryParameter(
          key: Uri.decodeQueryComponent(entry.split('=').first),
          value: entry.contains('=')
              ? Uri.decodeQueryComponent(
                  entry.substring(entry.indexOf('=') + 1),
                )
              : '',
        ),
  ];

  /// URL 查询参数中常见的 `{name}` 写法会被规范为环境模板 `{{name}}`。
  /// 即使当前环境没有该变量，也保留标准模板，让发送前校验给出明确
  /// 的缺失变量提示；路径参数和普通文本均不会被改写。
  String _normalizeEnvironmentParameterReference(String value) {
    final match = RegExp(
      r'^\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}$',
    ).firstMatch(value);
    if (match == null) return value;
    final inputKey = match.group(1)!;
    for (final variable in _environmentStore.listVariables()) {
      if (variable.key.toLowerCase() == inputKey.toLowerCase()) {
        return '{{${variable.key}}}';
      }
    }
    return '{{$inputKey}}';
  }

  /// 将新草稿写入活动请求的覆盖映射并触发重绘。
  void _updateActiveDraft(RequestDraft draft) {
    _draftOverrides[_activeRequestId!] = _trimDraft(draft);
    _notify();
  }

  /// 对全部可编辑请求文本做首尾空白规范化，避免不同输入入口产生差异。
  RequestDraft _trimDraft(RequestDraft draft) {
    final schema = draft.grpc.protoSchema;
    return draft.copyWith(
      method: draft.method.trim(),
      baseUrlToken: draft.baseUrlToken.trim(),
      path: draft.path.trim(),
      body: draft.body.trim(),
      params: _trimRows(draft.params),
      headers: _trimRows(draft.headers),
      multipartFields: _trimRows(draft.multipartFields),
      multipartFiles: [
        for (final file in draft.multipartFiles)
          file.copyWith(keyName: file.keyName.trim()),
      ],
      authentication: _trimAuthentication(draft.authentication),
      webSocket: draft.webSocket.copyWith(
        subprotocols: [
          for (final value in draft.webSocket.subprotocols)
            if (value.trim().isNotEmpty) value.trim(),
        ],
      ),
      grpc: draft.grpc.copyWith(
        protoSchema: schema?.copyWith(
          path: schema.path.trim(),
          fingerprint: schema.fingerprint.trim(),
          messageType: schema.messageType?.trim(),
        ),
        serviceName: draft.grpc.serviceName?.trim(),
        methodName: draft.grpc.methodName?.trim(),
      ),
    );
  }

  List<KeyValueRow> _trimRows(List<KeyValueRow> rows) => [
    for (final row in rows)
      row.copyWith(keyName: row.keyName.trim(), value: row.value.trim()),
  ];

  RequestAuthentication _trimAuthentication(RequestAuthentication value) =>
      switch (value.type) {
        RequestAuthenticationType.none => const RequestAuthentication.none(),
        RequestAuthenticationType.bearer => RequestAuthentication.bearer(
          value.bearerToken.trim(),
        ),
        RequestAuthenticationType.basic => RequestAuthentication.basic(
          username: value.username.trim(),
          password: value.password.trim(),
        ),
        RequestAuthenticationType.apiKey => RequestAuthentication.apiKey(
          apiKeyName: value.apiKeyName.trim(),
          apiKeyValue: value.apiKeyValue.trim(),
          apiKeyLocation: value.apiKeyLocation,
        ),
      };

  /// 生成参数 / 请求头行（[headers] 为 true 时表示请求头）的新字段 ID。
  String _nextDraftFieldId({required bool headers}) =>
      '${_activeRequestId!}:${headers ? 'header' : 'param'}:new-${_draftFieldSequence++}';

  /// 生成 multipart 文本字段的新字段 ID。
  String _nextMultipartFieldId() =>
      '${_activeRequestId!}:multipart-field:new-${_draftFieldSequence++}';

  /// 生成 multipart 文件条目的新字段 ID。
  String _nextMultipartFileId() =>
      '${_activeRequestId!}:multipart-file:new-${_draftFieldSequence++}';

  /// 判断 Header 是否为启用的 Bearer Authorization 条目。
  bool _isBearerAuthorizationField(ApiField header) =>
      header.enabled &&
      header.key.toLowerCase() == 'authorization' &&
      header.value.trimLeft().toLowerCase().startsWith('bearer ');

  /// 合成最终请求头；独立 Auth 不与同名 Header 重复。
  List<KeyValueRow> _headersWithAuthentication(RequestDraft draft) {
    final authentication = _effectiveAuthenticationFor(draft);
    final headers = [
      for (final header in draft.headers)
        if (!authentication.usesAuthorizationHeader ||
            header.keyName.toLowerCase() != 'authorization')
          if (!authentication.apiKeyInHeader ||
              header.keyName.toLowerCase() !=
                  authentication.apiKeyName.toLowerCase())
            header,
    ];
    if (authentication.usesBearerToken) {
      headers.add(
        KeyValueRow(
          id: 'authentication-bearer',
          keyName: 'Authorization',
          value: 'Bearer ${authentication.bearerToken}',
          secret: true,
        ),
      );
    }
    if (authentication.usesBasicAuthentication) {
      headers.add(
        KeyValueRow(
          id: 'authentication-basic',
          keyName: 'Authorization',
          value:
              'Basic ${base64Encode(utf8.encode('${authentication.username}:${authentication.password}'))}',
          secret: true,
        ),
      );
    }
    if (authentication.apiKeyInHeader &&
        authentication.apiKeyName.trim().isNotEmpty) {
      headers.add(
        KeyValueRow(
          id: 'authentication-api-key-header',
          keyName: authentication.apiKeyName,
          value: authentication.apiKeyValue,
          secret: true,
        ),
      );
    }
    return headers;
  }

  /// API Key 的 Query 模式由 Auth 单独管理，但仍作为最终 URL 的参数参与执行。
  List<KeyValueRow> _paramsWithAuthentication(RequestDraft draft) {
    final authentication = _effectiveAuthenticationFor(draft);
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
  List<KeyValueRow> _environmentParameterSuggestions(RequestDraft draft) {
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
      for (final variable in _environmentStore.listVariables())
        if (variable.scope != 'Global' &&
            variable.key.trim().isNotEmpty &&
            variable.key.trim().toLowerCase() != 'baseurl' &&
            !variable.isRequired &&
            !variable.isSecret &&
            !variable.isAuthenticationBinding &&
            !requestParameterKeys.contains(variable.key.trim().toLowerCase()) &&
            !requestVariableTemplates.any(
              (template) => _referencesVariable(template, variable.key),
            ))
          KeyValueRow(
            id: 'environment-parameter-${variable.id}',
            keyName: variable.key,
            value: '{{${variable.key}}}',
          ),
    ];
  }

  /// 判断模板文本是否以不区分大小写的方式引用了指定环境变量。
  bool _referencesVariable(String template, String key) => RegExp(
    '\\{\\{\\s*${RegExp.escape(key)}\\s*\\}\\}',
    caseSensitive: false,
  ).hasMatch(template);

  /// 判断 HTTP 方法是否不携带请求体（GET / HEAD）。
  bool _isBodylessHttpMethod(String method) {
    final normalizedMethod = method.trim().toUpperCase();
    return normalizedMethod == 'GET' || normalizedMethod == 'HEAD';
  }

  /// 判断请求头是否声明了 multipart/form-data 类型。
  bool _hasMultipartContentType(List<KeyValueRow> headers) => headers.any(
    (header) =>
        header.enabled &&
        header.keyName.toLowerCase() == 'content-type' &&
        header.value.toLowerCase().startsWith('multipart/form-data'),
  );

  /// 将模板中的环境变量解析为最终执行值。
  String _resolve(String template) =>
      _environmentStore.resolveTemplate(template).executionValue;

  /// 返回当前环境中所有已解析的 Secret 值，供 WebSocket 运行时与历史统一脱敏。
  List<String> _resolvedEnvironmentSecretValues() => [
    for (final variable in _environmentStore.listVariables())
      if (variable.isSecret)
        _environmentStore.resolveTemplate('{{${variable.key}}}').executionValue,
  ];

  /// 生成永不含 Secret 明文的 WebSocket 历史端点；实际连接继续使用 [url]。
  String _redactWebSocketEndpoint(String url, Iterable<String> secrets) {
    var result = url;
    for (final secret in secrets) {
      if (secret.isNotEmpty) result = result.replaceAll(secret, '••••••••');
    }
    return result;
  }

  /// 为网络运行时生成已解析的执行草稿。
  ///
  /// 编辑器和持久化资源始终保留 `{{token}}` 这类模板；只有离开
  /// ViewModel、即将交给 HTTP 客户端时才替换。此前 URL 已解析而 headers
  /// 仍为原始模板，导致 Bearer token 被字面量发送并得到 401。
  RequestDraft _resolvedExecutionDraft(RequestDraft draft) {
    final authentication = _resolvedAuthentication(
      _effectiveAuthenticationFor(draft),
    );
    final executionDraft = draft.copyWith(
      authentication: authentication,
      authenticationSource: RequestAuthenticationSource.request,
    );
    return executionDraft.copyWith(
      baseUrlToken: _resolve(draft.baseUrlToken),
      path: _resolve(draft.path),
      params: [
        for (final item in _paramsWithAuthentication(executionDraft))
          item.copyWith(
            keyName: _resolve(item.keyName),
            value: _resolve(item.value),
          ),
      ],
      headers: [
        for (final header in _headersWithAuthentication(executionDraft))
          header.copyWith(
            keyName: _resolve(header.keyName),
            value: _resolve(header.value),
          ),
      ],
      body: _resolve(draft.body),
      multipartFields: [
        for (final field in draft.multipartFields)
          field.copyWith(
            keyName: _resolve(field.keyName),
            value: _resolve(field.value),
          ),
      ],
      multipartFiles: [
        for (final file in draft.multipartFiles)
          file.copyWith(keyName: _resolve(file.keyName)),
      ],
    );
  }

  /// 将认证配置中的模板字段解析为最终执行值。
  RequestAuthentication _resolvedAuthentication(
    RequestAuthentication authentication,
  ) => authentication.copyWith(
    bearerToken: _resolve(authentication.bearerToken),
    username: _resolve(authentication.username),
    password: _resolve(authentication.password),
    apiKeyName: _resolve(authentication.apiKeyName),
    apiKeyValue: _resolve(authentication.apiKeyValue),
  );

  /// 返回草稿实际使用的认证：环境来源时取活动环境配置，否则取请求自身。
  RequestAuthentication _effectiveAuthenticationFor(RequestDraft draft) =>
      draft.authenticationSource == RequestAuthenticationSource.environment
      ? _environmentStore.activeEnvironment.authentication
      : draft.authentication;

  /// 计算字节内容的 64 位 FNV-1a 哈希，用于识别文件内容变化。
  String _fingerprint(List<int> bytes) {
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

  /// 生成用于历史记录的请求快照，密钥值脱敏后写入。
  ExecutionRequestSnapshot _requestSnapshot(
    RequestDraft draft,
    String executionUrl,
  ) => ExecutionRequestSnapshot(
    method: draft.method,
    protocol: draft.protocol,
    resolvedUrl: executionUrl,
    headers: [
      for (final header in _headersWithAuthentication(
        draft,
      ).where((item) => item.enabled))
        KeyValueRow(
          keyName: header.keyName,
          value: header.secret ? '••••••••••••' : _resolve(header.value),
          secret: header.secret,
        ),
    ],
    body: _snapshotBody(draft),
    environmentName: activeEnvironment.name,
  );

  /// 生成请求快照的安全版本：变量解析失败时退化为未解析的原始模板。
  ExecutionRequestSnapshot _safeRequestSnapshot(RequestDraft draft) {
    try {
      return _requestSnapshot(draft, resolvedUrl);
    } catch (_) {
      // 解析异常时用未解析的模板兜底，保证历史记录总能生成。
      return ExecutionRequestSnapshot(
        method: draft.method,
        protocol: draft.protocol,
        resolvedUrl: '${draft.baseUrlToken}${draft.path}',
        headers: [
          for (final header in _headersWithAuthentication(
            draft,
          ).where((item) => item.enabled))
            KeyValueRow(
              keyName: header.keyName,
              value: header.secret ? '••••••••••••' : header.value,
              secret: header.secret,
            ),
        ],
        body: _snapshotBody(draft),
        environmentName: activeEnvironment.name,
      );
    }
  }

  /// 生成历史记录中展示的请求体文本：multipart 时列出各字段与文件。
  String _snapshotBody(RequestDraft draft) {
    if (!_hasMultipartContentType(draft.headers)) return draft.body;
    return [
      for (final field in draft.multipartFields.where((item) => item.enabled))
        '${field.keyName}: ${field.value}',
      for (final file in draft.multipartFiles.where((item) => item.enabled))
        '${file.keyName}: @${file.fileName}',
    ].join('\n');
  }

  /// 追加一条执行记录到历史头部，最多保留 8 条。
  void _appendHistory({
    required String requestId,
    required RequestDraft draft,
    required ExecutionRequestSnapshot snapshot,
    required int timeMs,
    int? status,
    ResponseSnapshot? response,
    String? errorCategory,
    String? errorMessage,
  }) {
    final id = 'execution-${DateTime.now().microsecondsSinceEpoch}';
    final record = ExecutionRecord(
      id: id,
      requestId: requestId,
      method: draft.method,
      protocol: draft.protocol,
      path: draft.path,
      status: status,
      timeMs: timeMs,
      when: 'now',
      requestSnapshot: snapshot,
      response: response,
      errorCategory: errorCategory,
      errorMessage: errorMessage,
    );
    _history = [record, ..._history.take(7)];
    final store = historyStore;
    if (store != null) unawaited(store.append(record));
  }

  /// 将刚终止的 WebSocket 会话转为不含任何消息负载的本地历史摘要。
  void _persistFinishedWebSocketSessions() {
    for (final session in _webSocketSessions.sessions) {
      final startedAt = session.sessionStartedAt;
      final endedAt = session.sessionEndedAt;
      if (startedAt == null || endedAt == null) continue;
      _appendWebSocketSessionSummary(
        session,
        startedAt: startedAt,
        endedAt: endedAt,
      );
    }
  }

  /// 追加一个 WebSocket 会话摘要；registry 中的消息事件与二进制帧不参与编码。
  void _appendWebSocketSessionSummary(
    WebSocketSession session, {
    required DateTime startedAt,
    required DateTime endedAt,
  }) {
    if (_persistedWebSocketSessionStarts[session.requestId] == startedAt) {
      return;
    }
    _persistedWebSocketSessionStarts[session.requestId] = startedAt;
    final terminalStatus = session.state == WebSocketConnectionState.error
        ? 'error'
        : 'closed';
    final summary = WebSocketSessionHistorySummary(
      endpoint: session.endpoint ?? 'WebSocket endpoint unavailable',
      startedAt: startedAt.toUtc(),
      endedAt: endedAt.toUtc(),
      terminalStatus: terminalStatus,
      inboundMessageCount: session.inboundMessageCount,
      outboundMessageCount: session.outboundMessageCount,
      errorMessage: session.errorMessage,
    );
    final record = ExecutionRecord(
      id: 'websocket-${endedAt.microsecondsSinceEpoch}',
      requestId: session.requestId,
      method: 'WS',
      protocol: ApiRequestProtocol.webSocket,
      path: summary.endpoint,
      // 101 表示正常的 WebSocket 关闭；错误保持 null，沿用历史失败语义。
      status: terminalStatus == 'closed' ? 101 : null,
      timeMs: endedAt.difference(startedAt).inMilliseconds.clamp(0, 1 << 31),
      when: 'now',
      errorCategory: terminalStatus == 'error' ? 'websocket' : null,
      errorMessage: summary.errorMessage,
      webSocketSummary: summary,
    );
    _history = [record, ..._history.take(7)];
    final store = historyStore;
    if (store != null) unawaited(store.append(record));
  }

  /// 从历史中查找最近一条带有响应与请求快照的记录。
  ExecutionRecord? _latestResponseRecord() {
    for (final record in _history) {
      if (record.response != null && record.requestSnapshot != null) {
        return record;
      }
    }
    return null;
  }
}
