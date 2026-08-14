import 'dart:async';
import 'dart:convert';

import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/grpc/grpc_transport.dart'
    show GrpcReflectionConfiguration, GrpcReflectionException;
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/ui/features/requests/editor/models/request_editor_models.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// WebSocket、gRPC 与 Protobuf 协议配置和会话操作。
extension WorkspaceProtocolOperations on WorkspaceViewModel {
  Future<void> restoreGrpcSchemaInternal(ApiRequestDefinition request) async {
    if (request.protocol != ApiRequestProtocol.grpc ||
        internals.protobufDescriptors.containsKey(request.id)) {
      return;
    }
    if (request.grpc.useReflection) return;
    final path = request.grpc.protoSchema?.path;
    if (path == null || path.isEmpty) return;
    try {
      final descriptor = await internals.protobufSource.parseSourceFile(path);
      internals.protobufDescriptors[request.id] = descriptor;
      internals.protobufMessageTypes[request.id] = descriptor.messageTypes;
      if (internals.activeRequestId == request.id) notifyWorkspace();
    } on Object {
      if (internals.activeRequestId != request.id) return;
      internals.lastActionMessage =
          'Could not load proto source. Review the file and try again.';
      notifyWorkspace();
    }
  }

  void updateActiveDraftProtocol(ApiRequestProtocol protocol) {
    final draft = activeDraft;
    updateActiveDraftInternal(
      draft.copyWith(
        protocol: protocol,
        authentication:
            protocol == ApiRequestProtocol.grpc &&
                draft.protocol != ApiRequestProtocol.grpc
            ? const RequestAuthentication.none()
            : draft.authentication,
        authenticationSource:
            protocol == ApiRequestProtocol.grpc &&
                draft.protocol != ApiRequestProtocol.grpc
            ? RequestAuthenticationSource.request
            : draft.authenticationSource,
      ),
    );
    internals.activeRequestTab = protocol == ApiRequestProtocol.http
        ? RequestEditorSection.params
        : RequestEditorSection.protocol;
  }

  void updateActiveWebSocketSubprotocols(String source) {
    final subprotocols = source
        .split(RegExp(r'[\n,]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    updateActiveDraftInternal(
      activeDraft.copyWith(
        webSocket: activeDraft.webSocket.copyWith(subprotocols: subprotocols),
      ),
    );
  }

  /// Imports a descriptor set and returns a user-facing failure, if any.
  Future<String?> importActiveProtobufDescriptor(String path) async {
    try {
      final bytes = await internals.protobufSource.readBytes(path);
      final descriptor = internals.protobufSource.parseDescriptorSet(bytes);
      internals.protobufMessageTypes[internals.activeRequestId!] =
          descriptor.messageTypes;
      internals.protobufDescriptors[internals.activeRequestId!] = descriptor;
      updateActiveDraftInternal(
        activeDraft.copyWith(
          webSocket: activeDraft.webSocket.copyWith(
            protobufSchema: ProtobufSchemaReference(
              path: path,
              fingerprint: fingerprintInternal(bytes),
            ),
          ),
        ),
      );
      return null;
    } on Object {
      return 'Could not import descriptor set. Review the file and try again.';
    }
  }

  /// 导入本地 `.proto` 图；失败时不覆盖当前 gRPC schema 关联。
  Future<String?> importActiveGrpcProto(String path) async {
    try {
      final descriptor = await internals.protobufSource.parseSourceFile(path);
      final bytes = await internals.protobufSource.readBytes(path);
      internals.protobufDescriptors[internals.activeRequestId!] = descriptor;
      internals.protobufMessageTypes[internals.activeRequestId!] =
          descriptor.messageTypes;
      updateActiveDraftInternal(
        activeDraft.copyWith(
          grpc: activeDraft.grpc.copyWith(
            protoSchema: ProtobufSchemaReference(
              path: path,
              fingerprint: fingerprintInternal(bytes),
            ),
            schemaSource: GrpcSchemaSource.proto,
          ),
        ),
      );
      return null;
    } on Object {
      return 'Could not import proto source. Review the file and try again.';
    }
  }

  /// 使用当前 endpoint、环境认证和 metadata 通过标准 reflection 发现服务。
  Future<String?> discoverActiveGrpcServices() async {
    final requestId = internals.activeRequestId;
    if (requestId == null || !isActiveGrpc || isDiscoveringGrpcServices) {
      return null;
    }
    internals.grpcReflectionDiscoveries.add(requestId);
    notifyWorkspace();
    final draft = activeDraft;
    try {
      final deadline = parseGrpcDeadlineInternal(draft.grpc.deadlineMs);
      final command = await internals.environmentResolver.resolve(
        ResolveExecutionRequest(
          executionId:
              'grpc-reflection-${DateTime.now().microsecondsSinceEpoch}',
          requestRef: RequestRef(id: requestId),
          draft: draft,
        ),
      );
      final endpoint = Uri.tryParse(command.payload.resolvedUrl);
      if (endpoint?.host.isEmpty != false) {
        return 'Enter a valid gRPC endpoint before discovering services.';
      }
      final metadata = <String, String>{
        for (final header in command.payload.draft.headers)
          if (header.enabled && header.keyName.trim().isNotEmpty)
            header.keyName: header.value,
      };
      final descriptor = await internals.grpcCalls.discoverServices(
        GrpcReflectionConfiguration(
          endpoint: endpoint!,
          metadata: metadata,
          useTls: draft.grpc.useTls,
          timeout: deadline,
        ),
      );
      if (descriptor.services.isEmpty) {
        return 'Server reflection returned no callable services.';
      }
      internals.protobufDescriptors[requestId] = descriptor;
      internals.protobufMessageTypes[requestId] = descriptor.messageTypes;
      final selectedService = descriptor.service(draft.grpc.serviceName ?? '');
      final selectedMethod = selectedService?.methods
          .where((method) => method.name == draft.grpc.methodName)
          .firstOrNull;
      updateActiveDraftInternal(
        activeDraft.copyWith(
          grpc: activeDraft.grpc.copyWith(
            schemaSource: GrpcSchemaSource.reflection,
            clearProtoSchema: true,
            clearServiceName: selectedService == null,
            clearMethodName: selectedMethod == null,
            rpcShape: selectedMethod == null
                ? GrpcRpcShape.unary
                : GrpcRpcShape.fromStreamingFlags(
                    clientStreaming: selectedMethod.clientStreaming,
                    serverStreaming: selectedMethod.serverStreaming,
                  ),
          ),
        ),
      );
      return null;
    } on FormatException catch (error) {
      return error.message;
    } on GrpcReflectionException catch (error) {
      if (error.statusCode == 16) {
        return _grpcReflectionAuthenticationFailure(draft);
      }
      if (error.statusCode == 12) {
        return 'Server reflection is not enabled. Import a .proto file instead.';
      }
      return 'Server reflection failed. Review the endpoint and try again.';
    } on Object {
      return 'Server reflection failed. Review the endpoint and try again.';
    } finally {
      internals.grpcReflectionDiscoveries.remove(requestId);
      notifyWorkspace();
    }
  }

  String _grpcReflectionAuthenticationFailure(RequestDraft draft) {
    final authentication = effectiveAuthenticationForInternal(draft);
    return switch (authentication.type) {
      RequestAuthenticationType.bearer
          when draft.authenticationSource ==
              RequestAuthenticationSource.environment =>
        'Bearer authentication failed. Service discovery uses the Environment Bearer token from ${activeEnvironment.name}. Switch to the intended environment or update its Bearer token, then discover services again.',
      RequestAuthenticationType.bearer =>
        'Bearer authentication failed. Update the request Bearer token, then discover services again.',
      RequestAuthenticationType.basic =>
        'Basic authentication failed. Update the request username and password, then discover services again.',
      RequestAuthenticationType.apiKey =>
        'API key authentication failed. Update the request API key name and value, then discover services again.',
      RequestAuthenticationType.none =>
        'Authentication is required for service discovery. Configure request or environment authentication, then try again.',
    };
  }

  /// 选择 gRPC 服务，并清除不再属于该服务的方法选择。
  void selectActiveGrpcService(String? serviceName) {
    updateActiveDraftInternal(
      activeDraft.copyWith(
        grpc: activeDraft.grpc.copyWith(
          serviceName: serviceName,
          clearServiceName: serviceName == null,
          clearMethodName: true,
          rpcShape: GrpcRpcShape.unary,
        ),
      ),
    );
  }

  /// 选择 gRPC RPC 方法，并依据描述符同步服务端流标记。
  void selectActiveGrpcMethod(String? methodName) {
    final method = activeGrpcMethods
        .where((item) => item.name == methodName)
        .firstOrNull;
    // 方法确定后直接转到请求消息编辑面；流式方法不要求用户再寻找 Body 标签。
    if (method != null) internals.activeRequestTab = RequestEditorSection.body;
    updateActiveDraftInternal(
      activeDraft.copyWith(
        grpc: activeDraft.grpc.copyWith(
          methodName: methodName,
          clearMethodName: methodName == null,
          rpcShape: method == null
              ? GrpcRpcShape.unary
              : GrpcRpcShape.fromStreamingFlags(
                  clientStreaming: method.clientStreaming,
                  serverStreaming: method.serverStreaming,
                ),
        ),
      ),
    );
  }

  /// 更新 gRPC TLS 配置，不影响请求头中的 metadata 模板。
  void updateActiveGrpcUseTls(bool useTls) {
    updateActiveDraftInternal(
      activeDraft.copyWith(grpc: activeDraft.grpc.copyWith(useTls: useTls)),
    );
  }

  /// 更新请求级 gRPC deadline 草稿；格式校验在发送前统一执行。
  void updateActiveGrpcDeadline(String deadlineMs) {
    updateActiveDraftInternal(
      activeDraft.copyWith(
        grpc: activeDraft.grpc.copyWith(deadlineMs: deadlineMs),
      ),
    );
  }

  /// 选择活动请求的 Protobuf 消息类型；传 null 表示清除选择。
  void selectActiveProtobufMessageType(String? messageType) {
    final schema = activeDraft.webSocket.protobufSchema;
    if (schema == null) return;
    updateActiveDraftInternal(
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
  /// 环境只解析一次握手配置，执行层消费其策略。
  Future<void> connectActiveWebSocket() async {
    if (!isActiveWebSocket || internals.activeRequestId == null) return;
    final requestId = internals.activeRequestId!;
    final command = await internals.environmentResolver.resolve(
      ResolveExecutionRequest(
        executionId: 'websocket-${DateTime.now().microsecondsSinceEpoch}',
        requestRef: RequestRef(id: requestId),
        draft: activeDraft,
      ),
    );
    final uri = Uri.tryParse(command.payload.resolvedUrl);
    if (uri == null || (uri.scheme != 'ws' && uri.scheme != 'wss')) {
      internals.lastActionMessage = 'WebSocket URL must use ws:// or wss://.';
      notifyWorkspace();
      return;
    }
    final resolvedHeaders = <String, String>{
      for (final header in command.payload.draft.headers)
        if (header.enabled && header.keyName.trim().isNotEmpty)
          header.keyName: header.value,
    };
    await internals.webSocketSessions.connect(
      requestRef: RequestRef(id: requestId),
      url: uri,
      headers: resolvedHeaders,
      subprotocols: command.payload.draft.webSocket.subprotocols,
      redactionPolicy: command.redactionPolicy,
      sessionContext: longLivedSessionContextForInternal(activeDraft),
    );
  }

  /// 断开活动请求的 WebSocket 连接。
  Future<void> disconnectActiveWebSocket() async {
    if (internals.activeRequestId == null) return;
    await internals.webSocketSessions.disconnect(
      RequestRef(id: internals.activeRequestId!),
    );
  }

  /// 更新活动请求的 WebSocket 消息编辑草稿内容。
  void updateActiveWebSocketMessage(String payload) {
    internals.webSocketMessageDrafts[internals.activeRequestId!] =
        activeWebSocketMessageDraft.copyWith(payload: payload.trim());
    notifyWorkspace();
  }

  /// 切换 WebSocket 消息的负载格式与对应帧类型。
  void updateActiveWebSocketMessageMode(WebSocketComposerMode mode) {
    internals.webSocketMessageDrafts[internals.activeRequestId!] =
        activeWebSocketMessageDraft.copyWith(mode: mode);
    notifyWorkspace();
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
    if (!isActiveWebSocket || internals.activeRequestId == null) return;
    final requestId = internals.activeRequestId!;
    final draft = activeWebSocketMessageDraft;
    // 合法 JSON 无论来自 Text 还是 JSON 模式，均在发送边界统一规范化。
    // 这样 transport、echo 与会话历史看到的是同一份稳定的可读载荷。
    final normalizedTextPayload = draft.mode.isText
        ? _formatWebSocketJsonIfPossible(draft.payload)
        : null;
    try {
      switch (draft.mode) {
        case WebSocketComposerMode.text:
          await internals.webSocketSessions.sendText(
            RequestRef(id: requestId),
            normalizedTextPayload!,
            formatLabel: normalizedTextPayload == draft.payload
                ? null
                : WebSocketComposerMode.json.label,
          );
        case WebSocketComposerMode.json:
          // JSON 模式仍严格校验，避免把无效 JSON 当作普通文本发出。
          jsonDecode(draft.payload);
          await internals.webSocketSessions.sendText(
            RequestRef(id: requestId),
            normalizedTextPayload!,
            formatLabel: draft.mode.label,
          );
        case WebSocketComposerMode.xml:
          await internals.webSocketSessions.sendText(
            RequestRef(id: requestId),
            draft.payload,
            formatLabel: draft.mode.label,
          );
        case WebSocketComposerMode.messagePack:
          await internals.webSocketSessions.sendBinary(
            RequestRef(id: requestId),
            base64Decode(draft.payload.trim()),
            formatLabel: draft.mode.label,
          );
      }
      // 仅在 transport 确认发送后清空编辑器，失败时保留原始草稿供修正或重试。
      internals.webSocketMessageDrafts[requestId] = draft.copyWith(payload: '');
      notifyWorkspace();
    } on FormatException {
      // MessagePack 要求合法 Base64，JSON 要求合法 JSON。
      internals.lastActionMessage = draft.mode.requiresBase64
          ? 'Binary messages must use valid Base64.'
          : 'The message is not valid JSON.';
      notifyWorkspace();
    } on WebSocketSessionException catch (error) {
      internals.lastActionMessage = error.message;
      notifyWorkspace();
    } on Object {
      internals.lastActionMessage = 'Could not send message. Retry.';
      notifyWorkspace();
    }
  }

  /// 返回缩进后的 JSON；非 JSON 文本保持原样以兼容普通 WebSocket 文本帧。
  String _formatWebSocketJsonIfPossible(String value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(value));
    } on FormatException {
      return value;
    }
  }

  /// 更新活动请求的请求体文本。
  void updateActiveDraftBody(String body) =>
      updateActiveDraftInternal(activeDraft.copyWith(body: body));

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
    updateActiveDraftInternal(
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
              id: nextDraftFieldIdInternal(headers: headers),
              keyName: '',
              value: '',
              enabled: true,
            ),
          );
    updateActiveDraftInternal(
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
    internals.revealedDraftFieldIds.remove(fields[index].id);
    fields.removeAt(index);
    updateActiveDraftInternal(
      headers
          ? activeDraft.copyWith(headers: fields)
          : activeDraft.copyWith(params: fields),
    );
  }
}

Duration? parseGrpcDeadlineInternal(String source) {
  final value = source.trim();
  if (value.isEmpty) return null;
  final milliseconds = int.tryParse(value);
  if (milliseconds == null || milliseconds <= 0) {
    throw const FormatException(
      'gRPC deadline must be a positive whole number of milliseconds.',
    );
  }
  return Duration(milliseconds: milliseconds);
}
