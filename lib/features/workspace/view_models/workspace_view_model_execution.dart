part of 'workspace_view_model.dart';

/// 历史记录、Mock、文档草稿与 HTTP/gRPC 执行协调。
extension WorkspaceExecutionOperations on WorkspaceViewModel {
  /// 选择响应面板的子标签页。
  void selectResponseTab(ResponseTab tab) {
    if (_activeResponseTab == tab) {
      return;
    }
    _activeResponseTab = tab;
    _notify();
  }

  /// 打开一条历史记录，将响应与错误信息还原到响应面板。
  void openHistoryRecord(String id) {
    final record = _history.firstWhere((item) => item.id == id);
    _openedHistoryRecord = record;
    _activeSection = WorkspaceSection.history;
    _response = record.response;
    _executionError = record.errorMessage;
    _activeResponseTab = ResponseTab.body;
    _notify();
  }

  /// 清除当前会话中的执行历史，并同步移除右侧展示的历史快照。
  void clearHistory() {
    if (_history.isEmpty) return;
    _history = [];
    _openedHistoryRecord = null;
    _response = null;
    _executionError = null;
    _activeResponseTab = ResponseTab.body;
    _lastActionMessage = 'History cleared.';
    final store = historyStore;
    if (store != null) unawaited(store.clear());
    _notify();
  }

  /// 打开历史记录对应的原始请求；若请求已被删除则提示用户。
  void openSelectedHistoryRequest() {
    final requestId = _openedHistoryRecord?.requestId;
    if (requestId == null) return;
    if (!requestExists(requestId)) {
      _lastActionMessage = 'The original request was deleted.';
      _notify();
      return;
    }
    selectRequest(requestId);
  }

  /// 从零创建一个可编辑、可立即启动的临时 Quick Mock 草稿。
  void createManualMockDraft() {
    const body = '{\n  "message": "Mock response"\n}';
    final draft = MockDraft(
      request: const ExecutionRequestSnapshot(
        method: 'GET',
        resolvedUrl: 'http://mock.sendreq.local/',
        headers: [],
        body: '',
        environmentName: 'Local Mock',
      ),
      response: ResponseSnapshot(
        statusCode: 200,
        timeMs: 0,
        sizeKb: utf8.encode(body).length / 1024,
        body: body,
        headers: const [
          KeyValueRow(
            id: 'mock-header-content-type',
            keyName: 'Content-Type',
            value: 'application/json',
          ),
        ],
      ),
      source: MockDraftSource.manual,
    );
    _mockDraft = draft;
    _mockRuntime.updateDraft(draft);
    _mockReturnSection = _activeSection;
    _activeSection = WorkspaceSection.mockServers;
    _notify();
  }

  /// 基于最近的请求与响应预填临时 Quick Mock，并跳转到对应区块。
  void createMockDraft() {
    // 优先取正在查看的历史记录，否则回退到最近一次成功响应的记录。
    final source = _openedHistoryRecord ?? _latestResponseRecord();
    if (source?.requestSnapshot == null || source?.response == null) {
      _lastActionMessage = 'Send a request before creating a Quick Mock.';
      _notify();
      return;
    }
    _mockDraft = MockDraft(
      request: source!.requestSnapshot!,
      response: source.response!,
      source: MockDraftSource.response,
    );
    _mockRuntime.updateDraft(_mockDraft!);
    _mockReturnSection = _activeSection;
    _activeSection = WorkspaceSection.mockServers;
    _notify();
  }

  /// 更新 Mock 的 HTTP 方法，修改会即时同步到正在运行的本地服务。
  void updateMockMethod(String method) {
    final draft = _mockDraft;
    if (draft == null) return;
    final normalized = method.trim().toUpperCase();
    if (!const {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'}.contains(normalized)) {
      return;
    }
    _replaceMockDraft(method: normalized);
  }

  /// 更新 Mock endpoint 的路径与可选 query string。
  void updateMockRoute(String value) {
    final draft = _mockDraft;
    if (draft == null) return;
    final input = value.trim();
    if (input.isEmpty) return;
    final route = Uri.tryParse(input.startsWith('/') ? input : '/$input');
    final target = Uri.tryParse(draft.request.resolvedUrl);
    if (route == null || target == null) return;
    _replaceMockDraft(
      resolvedUrl: target
          .replace(
            path: route.path.isEmpty ? '/' : route.path,
            query: route.query,
          )
          .toString(),
    );
  }

  /// 更新 Mock 的响应状态码；仅接受有效 HTTP 状态范围。
  void updateMockStatusCode(int statusCode) {
    if (statusCode < 100 || statusCode > 599 || _mockDraft == null) return;
    _replaceMockDraft(statusCode: statusCode);
  }

  /// 更新 Mock 的响应 body，修改会即时同步到正在运行的本地服务。
  void updateMockResponseBody(String body) {
    if (_mockDraft == null) return;
    _replaceMockDraft(body: body.trim());
  }

  /// 为 Mock 响应追加一条可编辑 Header。
  void addMockResponseHeader() {
    if (_mockDraft == null) return;
    _replaceMockDraft(
      responseHeaders: [
        ..._mockDraft!.response.headers,
        KeyValueRow(
          id: 'mock-header-${_draftFieldSequence++}',
          keyName: '',
          value: '',
        ),
      ],
    );
  }

  /// 更新 Mock 响应 Header 的键、值或启用状态。
  void updateMockResponseHeader({
    required int index,
    String? keyName,
    String? value,
    bool? enabled,
  }) {
    final draft = _mockDraft;
    if (draft == null || index < 0 || index >= draft.response.headers.length) {
      return;
    }
    final headers = List<KeyValueRow>.of(draft.response.headers);
    headers[index] = headers[index].copyWith(
      keyName: keyName?.trim(),
      value: value?.trim(),
      enabled: enabled,
    );
    _replaceMockDraft(responseHeaders: headers);
  }

  /// 删除指定 Mock 响应 Header。
  void removeMockResponseHeader(int index) {
    final draft = _mockDraft;
    if (draft == null || index < 0 || index >= draft.response.headers.length) {
      return;
    }
    final headers = List<KeyValueRow>.of(draft.response.headers)
      ..removeAt(index);
    _replaceMockDraft(responseHeaders: headers);
  }

  /// 基于最近的请求与响应创建文档草稿，并跳转到文档区块。
  void createDocumentationDraft() {
    final source = _openedHistoryRecord ?? _latestResponseRecord();
    if (source?.requestId == null ||
        source?.requestSnapshot == null ||
        source?.response == null) {
      _lastActionMessage = 'Send a request before creating documentation.';
      _notify();
      return;
    }
    _documentationDraft = DocumentationDraft(
      requestId: source!.requestId!,
      request: source.requestSnapshot!,
      response: source.response!,
    );
    _documentationReturnSection = _activeSection;
    _activeSection = WorkspaceSection.documentation;
    _notify();
  }

  /// 从 Mock 区块返回创建草稿前的来源区块。
  void returnFromMockDraft() {
    _activeSection = _mockReturnSection;
    _notify();
  }

  /// 启动本地 Mock 服务器。
  Future<void> startMockServer() async {
    final draft = _mockDraft;
    if (draft == null) {
      _lastActionMessage = 'Create a Quick Mock before starting it.';
      _notify();
      return;
    }
    if (_isMockStarting) return;
    _isMockStarting = true;
    _notify();
    try {
      await _mockRuntime.start(draft);
      _lastActionMessage = 'Quick Mock started.';
    } on Object {
      _lastActionMessage = 'Could not start Quick Mock. Retry.';
    } finally {
      _isMockStarting = false;
      _notify();
    }
  }

  /// 停止本地 Mock 服务器，立即反馈结果再等待异步收尾。
  Future<void> stopMockServer() async {
    final stopFuture = _mockRuntime.stop();
    _lastActionMessage = 'Quick Mock stopped.';
    _notify();
    try {
      await stopFuture;
    } on Object {
      _lastActionMessage = 'Could not stop Quick Mock. Retry.';
      _notify();
    }
  }

  /// 替换 Mock 草稿并将新规则同步给当前运行时。
  void _replaceMockDraft({
    String? method,
    String? resolvedUrl,
    int? statusCode,
    String? body,
    List<KeyValueRow>? responseHeaders,
  }) {
    final draft = _mockDraft!;
    final next = MockDraft(
      request: ExecutionRequestSnapshot(
        method: method ?? draft.request.method,
        resolvedUrl: resolvedUrl ?? draft.request.resolvedUrl,
        headers: draft.request.headers,
        body: draft.request.body,
        environmentName: draft.request.environmentName,
      ),
      response: ResponseSnapshot(
        statusCode: statusCode ?? draft.response.statusCode,
        timeMs: draft.response.timeMs,
        sizeKb: utf8.encode(body ?? draft.response.body).length / 1024,
        body: body ?? draft.response.body,
        headers: responseHeaders ?? draft.response.headers,
      ),
      source: draft.source,
    );
    _mockDraft = next;
    _mockRuntime.updateDraft(next);
    _notify();
  }

  /// 切换到集合区块。
  void openCollections() {
    _activeSection = WorkspaceSection.collections;
    _notify();
  }

  /// 从文档区块返回创建草稿前的来源区块。
  void returnFromDocumentationDraft() {
    _activeSection = _documentationReturnSection;
    _notify();
  }

  /// 尝试打开文档草稿对应的原始请求，请求已删除时给出提示。
  void tryDocumentationDraft() {
    final requestId = _documentationDraft?.requestId;
    if (requestId == null) return;
    if (!requestExists(requestId)) {
      _lastActionMessage = 'The original request was deleted.';
      _notify();
      return;
    }
    selectRequest(requestId);
  }

  /// 选择窄布局下右侧面板的内容。
  void selectNarrowWorkspacePanel(NarrowWorkspacePanel panel) {
    if (_narrowWorkspacePanel == panel) {
      return;
    }
    _narrowWorkspacePanel = panel;
    _notify();
  }

  /// 分发全局动作（发送 / 保存 / 打开命令面板），在入口统一做可用性校验。
  void dispatch(WorkspaceGlobalAction action) {
    _lastActionMessage = null;
    switch (action.type) {
      case WorkspaceActionType.send:
        // 不可发送时展示具体原因而非静默失败。
        if (!actionAvailability.canSend) {
          _lastActionMessage = actionAvailability.sendUnavailableReason;
          _notify();
          return;
        }
        if (isActiveWebSocket) {
          sendActiveWebSocketMessage();
        } else if (isActiveGrpc) {
          sendActiveGrpcRequest();
        } else {
          sendActiveRequest();
        }
      case WorkspaceActionType.save:
        if (!actionAvailability.canSave) {
          _lastActionMessage = 'No saveable changes in the active resource.';
          _notify();
          return;
        }
        saveRequest(_activeRequestId!);
      case WorkspaceActionType.openCommand:
        _notify();
    }
  }

  /// 发送活动请求并记录执行历史。
  ///
  /// 通过执行代数（[executionGeneration]）与 [_isCurrentExecution] 确保只有
  /// 最新一次请求的结果会被采纳，避免快速连续发送或取消时旧结果覆盖新状态。
  Future<void> sendActiveRequest() async {
    if (isActiveGrpc) return sendActiveGrpcRequest();
    if (_isSending || _activeRequestId == null) return;
    final requestId = _activeRequestId!;
    final executionGeneration = ++_executionGeneration;
    _isSending = true;
    _sendingRequestId = requestId;
    _executionError = null;
    _openedHistoryRecord = null;
    _notify();
    final stopwatch = Stopwatch()..start();
    final draft = activeDraft;
    late final String executionUrl;
    late final ExecutionRequestSnapshot requestSnapshot;
    try {
      // 先解析最终地址与请求快照，再交给运行时真正发送。
      executionUrl = resolvedUrl;
      requestSnapshot = _requestSnapshot(draft, executionUrl);
      final runtimeResponse = await _executionRuntime.send(
        draft: _resolvedExecutionDraft(draft),
        resolvedUrl: executionUrl,
      );
      // 若期间用户切走、取消或再次发送，则丢弃过期结果。
      if (!_isCurrentExecution(executionGeneration, requestId)) return;
      _response = ResponseSnapshot(
        statusCode: runtimeResponse.statusCode,
        timeMs: runtimeResponse.timeMs,
        sizeKb: runtimeResponse.sizeKb,
        body: runtimeResponse.body,
        headers: runtimeResponse.headers,
      );

      _appendHistory(
        requestId: requestId,
        draft: draft,
        snapshot: requestSnapshot,
        status: runtimeResponse.statusCode,
        timeMs: runtimeResponse.timeMs,
        response: _response,
      );
    } on RuntimeRequestException catch (error) {
      // 请求层可识别的错误：记录分类与原因，供历史与统计展示。
      if (!_isCurrentExecution(executionGeneration, requestId)) return;
      _executionError = error.message;
      _appendHistory(
        requestId: requestId,
        draft: draft,
        snapshot: _safeRequestSnapshot(draft),
        timeMs: stopwatch.elapsedMilliseconds,
        errorCategory: error.category.name,
        errorMessage: error.message,
      );
    } catch (error) {
      if (!_isCurrentExecution(executionGeneration, requestId)) return;
      _executionError = 'Request failed: $error';
      _appendHistory(
        requestId: requestId,
        draft: draft,
        snapshot: _safeRequestSnapshot(draft),
        timeMs: stopwatch.elapsedMilliseconds,
        errorCategory: RuntimeErrorCategory.unknown.name,
        errorMessage: _executionError!,
      );
    } finally {
      stopwatch.stop();
      // 仅当仍然是最新一次执行时才复位发送状态。
      if (executionGeneration == _executionGeneration) {
        _isSending = false;
        _sendingRequestId = null;
        _notify();
      }
    }
  }

  /// 重试活动请求。
  Future<void> retryActiveRequest() => sendActiveRequest();

  /// 编码并发起当前 gRPC 请求；校验失败不会越过本地边界发起网络调用。
  Future<void> sendActiveGrpcRequest() async {
    if (_activeRequestId == null || !isActiveGrpc) return;
    final requestId = _activeRequestId!;
    final draft = activeDraft;
    final descriptor = _protobufDescriptors[requestId];
    final service = descriptor?.service(draft.grpc.serviceName ?? '');
    final method = service?.methods
        .where((item) => item.name == draft.grpc.methodName)
        .firstOrNull;
    final endpoint = Uri.tryParse(resolvedUrl);
    if (descriptor == null ||
        method == null ||
        endpoint?.host.isEmpty != false) {
      _executionError =
          'Import a proto file and select a service, method, and endpoint.';
      _notify();
      return;
    }
    try {
      final executionDraft = _resolvedExecutionDraft(draft);
      final requestBytes = ProtobufDynamicCodec(
        descriptor,
      ).encodeJson(method.requestType, executionDraft.body);
      final metadata = <String, String>{
        for (final header in executionDraft.headers)
          if (header.enabled && header.keyName.trim().isNotEmpty)
            header.keyName: header.value,
      };
      final redactedValues = <String>[
        for (final header in executionDraft.headers)
          if (header.enabled && header.secret && header.value.isNotEmpty)
            header.value,
      ];
      _executionError = null;
      _openedHistoryRecord = null;
      await _grpcCalls.start(
        requestId: requestId,
        configuration: GrpcCallConfiguration(
          endpoint: endpoint!,
          serviceName: service!.name,
          methodName: method.name,
          requestType: method.requestType,
          responseType: method.responseType,
          requestBytes: requestBytes,
          metadata: metadata,
          useTls: draft.grpc.useTls,
          serverStreaming: method.serverStreaming,
          redactedValues: redactedValues,
        ),
      );
    } on FormatException catch (error) {
      _executionError = error.message;
      _notify();
    }
  }

  /// 取消正在发送的请求：递增代数作废在途结果并通知运行时终止。
  void cancelActiveRequest() {
    if (isActiveGrpc && _activeRequestId != null) {
      unawaited(_grpcCalls.cancel(_activeRequestId!));
      return;
    }
    if (!_isSending) return;
    _executionGeneration++;
    _isSending = false;
    _sendingRequestId = null;
    _executionRuntime.cancel();
    _notify();
  }

  /// 环境是请求执行上下文的一部分。环境切换、变量值或认证策略变更后，
  /// 旧响应不能继续代表当前 Collection 的执行结果；在途结果也必须作废。
  void _invalidateEnvironmentExecutionContext() {
    if (_isSending) {
      _executionGeneration++;
      _isSending = false;
      _sendingRequestId = null;
      _executionRuntime.cancel();
    }
    _response = null;
    _executionError = null;
    _openedHistoryRecord = null;
  }

  /// 若正在发送的请求属于 [requestIds]，则取消该执行。
  void _cancelExecutionFor(Set<String> requestIds) {
    final sendingRequestId = _sendingRequestId;
    if (sendingRequestId == null || !requestIds.contains(sendingRequestId)) {
      return;
    }
    cancelActiveRequest();
  }

  /// 判断执行结果是否仍属于当前有效执行：代数、请求与活动请求均一致且请求存在。
  bool _isCurrentExecution(int generation, String requestId) =>
      generation == _executionGeneration &&
      _sendingRequestId == requestId &&
      _activeRequestId == requestId &&
      requestExists(requestId);
}
