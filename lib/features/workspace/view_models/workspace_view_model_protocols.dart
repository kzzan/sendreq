part of 'workspace_view_model.dart';

/// WebSocket、gRPC 与 Protobuf 协议配置和会话操作。
extension WorkspaceProtocolOperations on WorkspaceViewModel {
  /// 恢复已保存的 gRPC proto 描述符，使重启后仍可直接发送请求。
  Future<void> _restoreGrpcSchema(ApiRequestDefinition request) async {
    if (request.protocol != ApiRequestProtocol.grpc ||
        _protobufDescriptors.containsKey(request.id)) {
      return;
    }
    final path = request.grpc.protoSchema?.path;
    if (path == null || path.isEmpty) return;
    try {
      final descriptor = await const ProtoSourceParser().parseFile(path);
      _protobufDescriptors[request.id] = descriptor;
      _protobufMessageTypes[request.id] = descriptor.messageTypes;
      if (_activeRequestId == request.id) _notify();
    } on Object catch (error) {
      if (_activeRequestId != request.id) return;
      _lastActionMessage = 'Could not load proto source: $error';
      _notify();
    }
  }

  /// 切换活动请求的协议；长连接协议直接进入其连接配置页。
  void updateActiveDraftProtocol(ApiRequestProtocol protocol) {
    _updateActiveDraft(activeDraft.copyWith(protocol: protocol));
    _activeRequestTab = protocol == ApiRequestProtocol.http
        ? RequestEditorSection.params
        : RequestEditorSection.protocol;
  }

  /// 解析子协议文本（按换行或逗号分隔）并更新 WebSocket 草稿。
  void updateActiveWebSocketSubprotocols(String source) {
    final subprotocols = source
        .split(RegExp(r'[\n,]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    _updateActiveDraft(
      activeDraft.copyWith(
        webSocket: activeDraft.webSocket.copyWith(subprotocols: subprotocols),
      ),
    );
  }

  /// 从文件导入 Protobuf descriptor set，缓存消息类型并绑定到草稿。
  ///
  /// 成功返回 null，失败返回面向用户的错误信息。
  Future<String?> importActiveProtobufDescriptor(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final descriptor = ProtobufDescriptorSet.parse(bytes);
      _protobufMessageTypes[_activeRequestId!] = descriptor.messageTypes;
      _protobufDescriptors[_activeRequestId!] = descriptor;
      _updateActiveDraft(
        activeDraft.copyWith(
          webSocket: activeDraft.webSocket.copyWith(
            protobufSchema: ProtobufSchemaReference(
              path: path,
              fingerprint: _fingerprint(bytes),
            ),
          ),
        ),
      );
      return null;
    } on Object catch (error) {
      return 'Could not import descriptor set: $error';
    }
  }

  /// 导入本地 `.proto` 图；失败时不覆盖当前 gRPC schema 关联。
  Future<String?> importActiveGrpcProto(String path) async {
    try {
      final descriptor = await const ProtoSourceParser().parseFile(path);
      final bytes = await File(path).readAsBytes();
      _protobufDescriptors[_activeRequestId!] = descriptor;
      _protobufMessageTypes[_activeRequestId!] = descriptor.messageTypes;
      _updateActiveDraft(
        activeDraft.copyWith(
          grpc: activeDraft.grpc.copyWith(
            protoSchema: ProtobufSchemaReference(
              path: path,
              fingerprint: _fingerprint(bytes),
            ),
          ),
        ),
      );
      return null;
    } on Object catch (error) {
      return 'Could not import proto source: $error';
    }
  }

  /// 选择 gRPC 服务，并清除不再属于该服务的方法选择。
  void selectActiveGrpcService(String? serviceName) {
    _updateActiveDraft(
      activeDraft.copyWith(
        grpc: activeDraft.grpc.copyWith(
          serviceName: serviceName,
          clearServiceName: serviceName == null,
          clearMethodName: true,
          serverStreaming: false,
        ),
      ),
    );
  }

  /// 选择 gRPC RPC 方法，并依据描述符同步服务端流标记。
  void selectActiveGrpcMethod(String? methodName) {
    final method = activeGrpcMethods
        .where((item) => item.name == methodName)
        .firstOrNull;
    _updateActiveDraft(
      activeDraft.copyWith(
        grpc: activeDraft.grpc.copyWith(
          methodName: methodName,
          clearMethodName: methodName == null,
          serverStreaming: method?.serverStreaming ?? false,
        ),
      ),
    );
  }

  /// 更新 gRPC TLS 配置，不影响请求头中的 metadata 模板。
  void updateActiveGrpcUseTls(bool useTls) {
    _updateActiveDraft(
      activeDraft.copyWith(grpc: activeDraft.grpc.copyWith(useTls: useTls)),
    );
  }

  /// 选择活动请求的 Protobuf 消息类型；传 null 表示清除选择。
  void selectActiveProtobufMessageType(String? messageType) {
    final schema = activeDraft.webSocket.protobufSchema;
    if (schema == null) return;
    _updateActiveDraft(
      activeDraft.copyWith(
        webSocket: activeDraft.webSocket.copyWith(
          protobufSchema: schema.copyWith(
            messageType: messageType,
            clearMessageType: messageType == null,
          ),
        ),
      ),
    );
  }

  /// 为活动 WebSocket 请求发起连接。
  ///
  /// 校验地址协议，解析请求头与子协议中的环境变量，并收集敏感请求头作为
  /// 会话记录中的脱敏值。
  Future<void> connectActiveWebSocket() async {
    if (!isActiveWebSocket || _activeRequestId == null) return;
    final requestId = _activeRequestId!;
    final url = resolvedUrl;
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'ws' && uri.scheme != 'wss')) {
      _lastActionMessage = 'WebSocket URL must use ws:// or wss://.';
      _notify();
      return;
    }
    final executionDraft = _resolvedExecutionDraft(activeDraft);
    final resolvedHeaders = <String, String>{
      for (final header in executionDraft.headers)
        if (header.enabled && header.keyName.trim().isNotEmpty)
          header.keyName: header.value,
    };
    // 标记为 secret 的请求头值需要在记录中脱敏，防止泄漏。
    final secrets = [
      ..._resolvedEnvironmentSecretValues(),
      for (final header in executionDraft.headers)
        if (header.enabled && header.secret) header.value,
      for (final parameter in _paramsWithAuthentication(activeDraft))
        if (parameter.enabled && parameter.secret) _resolve(parameter.value),
    ];
    await _webSocketSessions.connect(
      requestId: requestId,
      configuration: WebSocketConnectionConfiguration(
        url: uri,
        headers: resolvedHeaders,
        subprotocols: [
          for (final value in activeDraft.webSocket.subprotocols)
            _resolve(value),
        ],
        redactedValues: secrets,
        redactedEndpoint: _redactWebSocketEndpoint(url, secrets),
      ),
    );
  }

  /// 断开活动请求的 WebSocket 连接。
  Future<void> disconnectActiveWebSocket() async {
    if (_activeRequestId == null) return;
    await _webSocketSessions.disconnect(_activeRequestId!);
  }

  /// 更新活动请求的 WebSocket 消息编辑草稿内容。
  void updateActiveWebSocketMessage(String payload) {
    _webSocketMessageDrafts[_activeRequestId!] = activeWebSocketMessageDraft
        .copyWith(payload: payload.trim());
    _notify();
  }

  /// 切换 WebSocket 消息的负载格式与对应帧类型。
  void updateActiveWebSocketMessageMode(WebSocketComposerMode mode) {
    _webSocketMessageDrafts[_activeRequestId!] = activeWebSocketMessageDraft
        .copyWith(mode: mode);
    _notify();
  }

  /// 格式化 WebSocket 消息为缩进 JSON；无效 JSON 时返回错误说明。
  String? formatActiveWebSocketMessageJson() {
    final payload = activeWebSocketMessageDraft.payload.trim();
    if (payload.isEmpty) return 'Enter a JSON message before formatting.';
    try {
      updateActiveWebSocketMessage(
        const JsonEncoder.withIndent('  ').convert(jsonDecode(payload)),
      );
      return null;
    } on FormatException {
      return 'The message is not valid JSON.';
    }
  }

  /// 按当前格式将活动 WebSocket 消息发送为文本帧或二进制帧。
  Future<void> sendActiveWebSocketMessage() async {
    if (!isActiveWebSocket || _activeRequestId == null) return;
    final draft = activeWebSocketMessageDraft;
    try {
      switch (draft.mode) {
        case WebSocketComposerMode.text:
          await _webSocketSessions.sendText(_activeRequestId!, draft.payload);
        case WebSocketComposerMode.json:
          // JSON 模式先做一次解析校验，再按文本发送。
          jsonDecode(draft.payload);
          await _webSocketSessions.sendText(
            _activeRequestId!,
            draft.payload,
            formatLabel: draft.mode.label,
          );
        case WebSocketComposerMode.xml:
          await _webSocketSessions.sendText(
            _activeRequestId!,
            draft.payload,
            formatLabel: draft.mode.label,
          );
        case WebSocketComposerMode.messagePack:
          await _webSocketSessions.sendBinary(
            _activeRequestId!,
            base64Decode(draft.payload.trim()),
            formatLabel: draft.mode.label,
          );
      }
    } on FormatException {
      // MessagePack 要求合法 Base64，JSON 要求合法 JSON。
      _lastActionMessage = draft.mode.requiresBase64
          ? 'Binary messages must use valid Base64.'
          : 'The message is not valid JSON.';
      _notify();
    } on WebSocketSessionException catch (error) {
      _lastActionMessage = error.message;
      _notify();
    } on Object catch (error) {
      _lastActionMessage = 'Could not send message: $error';
      _notify();
    }
  }

  /// 更新活动请求的请求体文本。
  void updateActiveDraftBody(String body) =>
      _updateActiveDraft(activeDraft.copyWith(body: body));

  /// 更新活动请求参数或请求头中的某一行的字段。
  void updateActiveDraftField({
    required bool headers,
    required int index,
    String? keyName,
    String? value,
    bool? enabled,
    bool? secret,
  }) {
    final fields = List<KeyValueRow>.of(
      headers ? activeDraft.headers : activeDraft.params,
    );
    fields[index] = fields[index].copyWith(
      keyName: keyName,
      value: value,
      enabled: enabled,
      secret: secret,
    );
    _updateActiveDraft(
      headers
          ? activeDraft.copyWith(headers: fields)
          : activeDraft.copyWith(params: fields),
    );
  }

  /// 向活动请求的参数或请求头列表追加一行空字段。
  void addActiveDraftField({required bool headers}) {
    final fields =
        List<KeyValueRow>.of(headers ? activeDraft.headers : activeDraft.params)
          ..add(
            KeyValueRow(
              id: _nextDraftFieldId(headers: headers),
              keyName: '',
              value: '',
              enabled: true,
            ),
          );
    _updateActiveDraft(
      headers
          ? activeDraft.copyWith(headers: fields)
          : activeDraft.copyWith(params: fields),
    );
  }

  /// 移除活动请求参数或请求头中的指定行，并清理其可见性状态。
  void removeActiveDraftField({required bool headers, required int index}) {
    final fields = List<KeyValueRow>.of(
      headers ? activeDraft.headers : activeDraft.params,
    );
    _revealedDraftFieldIds.remove(fields[index].id);
    fields.removeAt(index);
    _updateActiveDraft(
      headers
          ? activeDraft.copyWith(headers: fields)
          : activeDraft.copyWith(params: fields),
    );
  }
}
