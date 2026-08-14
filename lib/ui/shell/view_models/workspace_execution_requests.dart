import 'dart:async';
import 'dart:typed_data';

import 'package:sendreq/domain/request_runtime/long_lived_session_context.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/ui/shell/models/workspace_shell_models.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 请求发送、取消及窄布局操作协调。
extension WorkspaceExecutionRequestOperations on WorkspaceViewModel {
  /// 选择窄布局下右侧面板的内容。
  void selectNarrowWorkspacePanel(NarrowWorkspacePanel panel) {
    if (internals.narrowWorkspacePanel == panel) return;
    internals.narrowWorkspacePanel = panel;
    notifyWorkspace();
  }

  /// 分发全局发送操作，并在入口统一做可用性校验。
  void dispatch(WorkspaceGlobalAction action) {
    internals.lastActionMessage = null;
    if (!actionAvailability.canSend) {
      internals.lastActionMessage = actionAvailability.sendUnavailableReason;
      notifyWorkspace();
      return;
    }
    if (isActiveWebSocket) {
      sendActiveWebSocketMessage();
    } else if (isActiveGrpc) {
      sendActiveGrpcRequest();
    } else {
      sendActiveRequest();
    }
  }

  /// 发送活动请求并更新当前 Request 的瞬态结果。
  ///
  /// 通过执行代数确保只有最新请求的结果会被采纳。
  Future<void> sendActiveRequest() async {
    if (isActiveGrpc) return sendActiveGrpcRequest();
    if (internals.isSending || internals.activeRequestId == null) return;
    final requestId = internals.activeRequestId!;
    final executionGeneration = ++internals.executionGeneration;
    internals.isSending = true;
    internals.sendingRequestId = requestId;
    internals.executionError = null;
    internals.currentExecutionResult = null;
    notifyWorkspace();
    final stopwatch = Stopwatch()..start();
    final draft = activeDraft;
    final requestedExecutionId =
        'execution-${DateTime.now().microsecondsSinceEpoch}';
    internals.activeExecutionId = requestedExecutionId;
    late final ResolvedExecutionCommand executionCommand;
    try {
      // 环境是模板展开、认证与密钥的唯一归属方。
      executionCommand = await internals.environmentResolver.resolve(
        ResolveExecutionRequest(
          executionId: requestedExecutionId,
          requestRef: RequestRef(id: requestId),
          draft: draft,
        ),
      );
      internals.activeExecutionId = executionCommand.executionId;
      final result = await internals.executionService.execute(executionCommand);
      // 若期间用户切走、取消或再次发送，则丢弃过期结果。
      if (!_isCurrentExecution(executionGeneration, requestId)) return;
      internals.currentExecutionResult = result;
      final snapshot = result.responseSnapshot;
      if (snapshot == null) {
        internals.executionError = result.summary;
        return;
      }
      internals.response = ResponseSnapshot(
        statusCode: snapshot.statusCode ?? 0,
        timeMs: result.durationMs,
        sizeKb: snapshot.bodyPreview.length / 1024,
        body: snapshot.bodyPreview,
        headers: [
          for (final entry in snapshot.headers.entries)
            KeyValueRow(keyName: entry.key, value: entry.value),
        ],
      );
    } catch (error) {
      if (!_isCurrentExecution(executionGeneration, requestId)) return;
      internals.executionError = 'Request failed.';
    } finally {
      stopwatch.stop();
      // 仅当仍然是最新一次执行时才复位发送状态。
      if (executionGeneration == internals.executionGeneration) {
        internals.isSending = false;
        internals.sendingRequestId = null;
        internals.activeExecutionId = null;
        notifyWorkspace();
      }
    }
  }

  /// 重试活动请求。
  Future<void> retryActiveRequest() => sendActiveRequest();

  /// 编码并发起当前 gRPC 请求；校验失败不会越过本地边界发起网络调用。
  Future<void> sendActiveGrpcRequest() async {
    if (internals.activeRequestId == null || !isActiveGrpc) return;
    final requestId = internals.activeRequestId!;
    final draft = activeDraft;
    final descriptor = internals.protobufDescriptors[requestId];
    final service = descriptor?.service(draft.grpc.serviceName ?? '');
    final method = service?.methods
        .where((item) => item.name == draft.grpc.methodName)
        .firstOrNull;
    if (descriptor == null || method == null) {
      internals.executionError =
          'Import a proto file and select a service, method, and endpoint.';
      notifyWorkspace();
      return;
    }
    try {
      final deadline = parseGrpcDeadlineInternal(draft.grpc.deadlineMs);
      final command = await internals.environmentResolver.resolve(
        ResolveExecutionRequest(
          executionId: 'grpc-${DateTime.now().microsecondsSinceEpoch}',
          requestRef: RequestRef(id: requestId),
          draft: draft,
        ),
      );
      final endpoint = Uri.tryParse(command.payload.resolvedUrl);
      if (endpoint?.host.isEmpty != false) {
        internals.executionError =
            'Import a proto file and select a service, method, and endpoint.';
        notifyWorkspace();
        return;
      }
      final executionDraft = command.payload.draft;
      final requestBytes = method.clientStreaming
          ? Uint8List(0)
          : internals.grpcCalls.encodeMessage(
              descriptor,
              method.requestType,
              executionDraft.body,
            );
      final metadata = <String, String>{
        for (final header in executionDraft.headers)
          if (header.enabled && header.keyName.trim().isNotEmpty)
            header.keyName: header.value,
      };
      final sessionContext = longLivedSessionContextForInternal(draft);
      final timeoutMs = deadline?.inMilliseconds;
      internals.executionError = null;
      await internals.grpcCalls.start(
        requestRef: RequestRef(id: requestId),
        configuration: GrpcCallConfiguration(
          endpoint: endpoint!,
          serviceName: service!.name,
          methodName: method.name,
          requestType: method.requestType,
          responseType: method.responseType,
          requestBytes: requestBytes,
          metadata: metadata,
          useTls: draft.grpc.useTls,
          rpcShape: GrpcRpcShape.fromStreamingFlags(
            clientStreaming: method.clientStreaming,
            serverStreaming: method.serverStreaming,
          ),
          timeout: deadline,
          redactionPolicy: command.redactionPolicy,
          redactedEndpoint: command.redactionPolicy.redact(
            command.payload.resolvedUrl,
          ),
          sessionContext: sessionContext,
          grpcSessionContext: GrpcSessionContextSnapshot(
            environmentId: command.environmentRef?.id,
            environmentName:
                command.environmentName ?? sessionContext.environmentName,
            authenticationLabel: sessionContext.authenticationLabel,
            authenticationType: sessionContext.authenticationType,
            authenticationSource: sessionContext.authenticationSource,
            redactedEndpoint: command.redactionPolicy.redact(
              command.payload.resolvedUrl,
            ),
            schemaSource: draft.grpc.schemaSource,
            serviceName: service.name,
            methodName: method.name,
            rpcShape: GrpcRpcShape.fromStreamingFlags(
              clientStreaming: method.clientStreaming,
              serverStreaming: method.serverStreaming,
            ),
            useTls: draft.grpc.useTls,
            deadlineMs: timeoutMs,
            metadataKeys: (metadata.keys.toList()..sort()),
          ),
        ),
      );
    } on FormatException catch (error) {
      internals.executionError = error.message;
      notifyWorkspace();
    }
  }

  /// 向已启动的客户端流或双向流发送当前正文中的下一条 Protobuf 消息。
  Future<void> sendActiveGrpcMessage() async {
    if (internals.activeRequestId == null || !canSendActiveGrpcMessage) return;
    final descriptor = internals.protobufDescriptors[internals.activeRequestId];
    final method = activeGrpcMethod;
    if (descriptor == null || method == null) return;
    try {
      final command = await internals.environmentResolver.resolve(
        ResolveExecutionRequest(
          executionId: 'grpc-message-${DateTime.now().microsecondsSinceEpoch}',
          requestRef: RequestRef(id: internals.activeRequestId!),
          draft: activeDraft,
        ),
      );
      final message = internals.grpcCalls.encodeMessage(
        descriptor,
        method.requestType,
        command.payload.draft.body,
      );
      internals.executionError = null;
      await internals.grpcCalls.send(
        requestRef: RequestRef(id: internals.activeRequestId!),
        message: message,
      );
    } on FormatException catch (error) {
      internals.executionError = error.message;
      notifyWorkspace();
    } on StateError catch (error) {
      internals.executionError = error.message;
      notifyWorkspace();
    }
  }

  /// 结束客户端流发送方向，服务端可继续推送剩余消息直至调用完成。
  Future<void> closeActiveGrpcRequestStream() async {
    if (internals.activeRequestId == null || !isActiveGrpc) return;
    await internals.grpcCalls.closeRequestStream(
      RequestRef(id: internals.activeRequestId!),
    );
  }

  /// 释放旧调用并使用当前草稿、活动环境和认证重新启动。
  Future<void> restartActiveGrpcCall() async {
    if (internals.activeRequestId == null || !isActiveGrpc) return;
    await internals.grpcCalls.cancel(
      RequestRef(id: internals.activeRequestId!),
    );
    await sendActiveGrpcRequest();
  }

  /// 取消正在发送的请求：递增代数作废在途结果并通知运行时终止。
  void cancelActiveRequest() {
    if (isActiveGrpc && internals.activeRequestId != null) {
      unawaited(
        internals.grpcCalls.cancel(RequestRef(id: internals.activeRequestId!)),
      );
      return;
    }
    if (!internals.isSending) return;
    internals.executionGeneration++;
    internals.isSending = false;
    internals.sendingRequestId = null;
    _cancelActiveExecution();
    notifyWorkspace();
  }

  /// 环境是请求执行上下文的一部分。环境切换、变量值或认证策略变更后，
  /// 旧响应不能继续代表当前 Collection 的执行结果；在途结果也必须作废。
  void invalidateEnvironmentExecutionContextInternal() {
    // 运行中的长连接保留建立时的凭据；环境改动只能显式重连后生效。
    internals.webSocketSessions.markConfigurationChanged();
    internals.grpcCalls.markConfigurationChanged();
    if (internals.isSending) {
      internals.executionGeneration++;
      internals.isSending = false;
      internals.sendingRequestId = null;
      _cancelActiveExecution();
    }
    internals.response = null;
    internals.currentExecutionResult = null;
    internals.executionError = null;
  }

  /// 若正在发送的请求属于 [requestIds]，则取消该执行。
  void cancelExecutionForInternal(Set<String> requestIds) {
    final sendingRequestId = internals.sendingRequestId;
    if (sendingRequestId == null || !requestIds.contains(sendingRequestId)) {
      return;
    }
    cancelActiveRequest();
  }

  void _cancelActiveExecution() {
    final executionId = internals.activeExecutionId;
    internals.activeExecutionId = null;
    if (executionId != null) {
      unawaited(internals.executionService.cancel(executionId));
    }
  }

  /// 判断执行结果是否仍属于当前有效执行：代数、请求与活动请求均一致且请求存在。
  bool _isCurrentExecution(int generation, String requestId) =>
      generation == internals.executionGeneration &&
      internals.sendingRequestId == requestId &&
      internals.activeRequestId == requestId &&
      requestExists(requestId);
}
