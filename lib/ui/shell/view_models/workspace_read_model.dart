import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/environments/environment_models.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/domain/preferences/workspace_preferences.dart';
import 'package:sendreq/ui/features/requests/output/models/response_viewer_models.dart';
import 'package:sendreq/ui/features/settings/view_models/settings_view_model.dart';
import 'package:sendreq/ui/shell/application/user_notice.dart';
import 'package:sendreq/ui/shell/models/workspace_shell_models.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 供 Shell 与 feature widget 使用的稳定只读状态投影。
extension WorkspaceReadModel on WorkspaceViewModel {
  /// 当前选中的工作区区块。
  WorkspaceSection get activeSection => internals.activeSection;

  /// Requests 当前协议工作视图；不属于持久化资产状态。
  RequestWorkingView get requestWorkingView => internals.requestWorkingView;

  /// 当前 Request 是否打开局部 Environment 管理层。
  bool get environmentManagerOpen => internals.environmentManagerOpen;

  /// 当前选中的请求编辑器子标签页 ID。
  String get activeRequestTab => internals.activeRequestTab.id;

  /// 当前选中的响应面板子标签页。
  ResponseTab get activeResponseTab => internals.activeResponseTab;

  /// 外观偏好。
  AppearancePreference get appearance => internals.appearance;

  /// 语言偏好。
  LocalePreference get locale => internals.locale;

  /// 当前界面字体偏好。
  WorkspaceFontPreference get font => internals.font;

  CodeFontPreference get codeFont => internals.codeFont;
  double get codeFontSize => internals.codeFontSize;

  /// 是否存在未保存的偏好变更。
  bool get hasPreferenceChanges => internals.hasPreferenceChanges;

  /// 当前偏好快照的自动持久化状态。
  PreferencePersistenceState get preferencePersistenceState =>
      internals.preferencePersistenceState;

  /// 窄布局下右侧面板的当前选择。
  NarrowWorkspacePanel get narrowWorkspacePanel =>
      internals.narrowWorkspacePanel;

  /// 最近一次操作提示消息。
  String? get lastActionMessage => internals.lastActionMessage;

  /// 是否存在活动请求。
  bool get hasActiveRequest => internals.activeRequestId != null;

  /// 以视图资源形式暴露全部集合（含展开状态与请求列表）。
  List<CollectionResource> get collections => internals.assetRepository
      .listCollections()
      .map(
        (collection) => CollectionResource(
          id: collection.id,
          name: collection.name,
          isExpanded: isCollectionExpanded(collection.id),
          folders: collection.folders
              .map(
                (folder) => FolderResource(
                  id: folder.id,
                  name: folder.name,
                  isExpanded: isFolderExpanded(folder.id),
                  requests: folder.requests
                      .map(toRequestResourceInternal)
                      .toList(growable: false),
                ),
              )
              .toList(growable: false),
        ),
      )
      .toList(growable: false);

  /// 当前工作视图需要展示的协议；All requests 返回 null。
  ApiRequestProtocol? get requestWorkingProtocol =>
      internals.requestWorkingView.protocol;

  /// 以视图资源形式暴露全部请求。
  List<RequestResource> get requests => internals.assetRepository
      .listRequests()
      .map(toRequestResourceInternal)
      .toList(growable: false);

  /// 当前打开的请求标签页列表。
  List<RequestTab> get openRequestTabs =>
      internals.assetRepository.listOpenTabs();

  /// Environment 管理器当前编辑目标下的全部变量视图。
  List<EnvironmentVariableView> get variables => internals.environmentStore
      .listVariables(environmentId: editingEnvironment.id);

  /// 已保留但未被当前环境认证使用的凭据，可由用户明确确认后清理。
  List<String> get unusedAuthenticationVariableNames =>
      internals.environmentStore.listUnusedAuthenticationVariableNames(
        environmentId: editingEnvironment.id,
      );

  /// 全部环境配置。
  List<EnvironmentProfile> get environments =>
      internals.environmentStore.listEnvironments();

  /// 当前活动环境。
  EnvironmentProfile get activeEnvironment =>
      internals.environmentStore.activeEnvironment;

  /// 管理器正在编辑的环境；管理器关闭时稳定回退到活动环境。
  EnvironmentProfile get editingEnvironment {
    final editingId = internals.editingEnvironmentId;
    return internals.environmentStore.listEnvironments().firstWhere(
      (environment) => environment.id == editingId,
      orElse: () => internals.environmentStore.activeEnvironment,
    );
  }

  bool get isEditingActiveEnvironment =>
      editingEnvironment.id == activeEnvironment.id;

  /// 当前环境必填 baseUrl 的展示值，Collection 与请求编辑器共享该上下文。
  String get activeEnvironmentBaseUrl => internals.environmentStore
      .listVariables()
      .firstWhere((variable) => variable.key == 'baseUrl')
      .displayValue;

  /// 环境是否存在未保存的修改。
  bool get hasEnvironmentChanges =>
      internals.environmentStore.hasUnsavedChanges;

  /// 最近一次执行得到的响应快照。
  ResponseSnapshot? get response => internals.response;

  /// 是否正在发送请求。
  bool get isSending => internals.isSending;

  /// 活动请求是否为 WebSocket 协议。
  bool get isActiveWebSocket =>
      hasActiveRequest && activeDraft.protocol == ApiRequestProtocol.webSocket;

  /// 活动请求是否使用 gRPC 协议。
  bool get isActiveGrpc =>
      hasActiveRequest && activeDraft.protocol == ApiRequestProtocol.grpc;

  /// 活动请求的 WebSocket 会话快照。
  WebSocketSession get activeWebSocketSession => internals.webSocketSessions
      .session(RequestRef(id: internals.activeRequestId!));

  /// 当前 gRPC 请求的调用状态与有界事件时间线。
  GrpcCallSnapshot get activeGrpcCall =>
      internals.grpcCalls.call(RequestRef(id: internals.activeRequestId!));

  /// 全部 WebSocket 会话快照；工作台可据此在离开编辑器后继续定位连接。
  List<WebSocketSession> get webSocketSessions => List.unmodifiable(
    internals.webSocketSessions.sessions.toList(growable: false),
  );

  /// 全部 gRPC 调用快照；只保留各调用受限的本地事件历史。
  List<GrpcCallSnapshot> get grpcCalls =>
      List.unmodifiable(internals.grpcCalls.calls.toList(growable: false));

  /// 当前请求的长连接是否仍使用建立时的配置快照。
  bool get activeLongLivedSessionNeedsRestart => isActiveWebSocket
      ? activeWebSocketSession.requiresReconnect
      : isActiveGrpc
      ? activeGrpcCall.requiresRestart
      : false;

  /// 按当前 RPC 的响应消息描述解码一条 gRPC 二进制事件。
  ProtobufDecodeResult? decodeActiveGrpcEvent(GrpcCallEvent event) {
    final message = event.message;
    final descriptor = internals.protobufDescriptors[internals.activeRequestId];
    final service = descriptor?.service(activeDraft.grpc.serviceName ?? '');
    final method = service?.methods
        .where((item) => item.name == activeDraft.grpc.methodName)
        .firstOrNull;
    if (message == null || descriptor == null || method == null) return null;
    return internals.grpcCalls.decodeMessage(
      descriptor,
      event.kind == GrpcTransportEventKind.request
          ? method.requestType
          : method.responseType,
      message,
    );
  }

  /// 活动请求的 WebSocket 消息编辑草稿，未编辑过则返回空草稿。
  WebSocketMessageDraft get activeWebSocketMessageDraft =>
      internals.webSocketMessageDrafts[internals.activeRequestId] ??
      const WebSocketMessageDraft();

  /// 活动请求可用的 Protobuf 消息类型列表。
  List<String> get activeProtobufMessageTypes =>
      internals.protobufMessageTypes[internals.activeRequestId] ?? const [];

  /// 当前导入 proto 中可选择的 gRPC 服务。
  List<ProtobufServiceDescriptor> get activeGrpcServices =>
      (internals.protobufDescriptors[internals.activeRequestId]?.services.values
          .toList()
        ?..sort((left, right) => left.name.compareTo(right.name))) ??
      const [];

  bool get isDiscoveringGrpcServices =>
      internals.activeRequestId != null &&
      internals.grpcReflectionDiscoveries.contains(internals.activeRequestId);

  /// 当前选定服务下可选择的 RPC 方法。
  List<ProtobufMethodDescriptor> get activeGrpcMethods {
    final service = internals.protobufDescriptors[internals.activeRequestId]
        ?.service(activeDraft.grpc.serviceName ?? '');
    return service?.methods ?? const [];
  }

  /// 当前选定的 gRPC 方法；未完成 schema 或方法选择时返回 null。
  ProtobufMethodDescriptor? get activeGrpcMethod => internals
      .protobufDescriptors[internals.activeRequestId]
      ?.service(activeDraft.grpc.serviceName ?? '')
      ?.methods
      .where((item) => item.name == activeDraft.grpc.methodName)
      .firstOrNull;

  /// 当前 RPC 请求消息的字段定义，用于按 proto 构造实际入参。
  ProtobufMessageDescriptor? get activeGrpcRequestMessage {
    final method = activeGrpcMethod;
    return method == null
        ? null
        : internals.protobufDescriptors[internals.activeRequestId]?.message(
            method.requestType,
          );
  }

  /// 客户端流或双向流正在运行，且当前仍可写入下一条请求消息。
  bool get canSendActiveGrpcMessage =>
      isActiveGrpc && activeGrpcCall.requestStreamOpen;

  /// gRPC 顶栏唯一主命令；运行态不再重复展示 Start。
  GrpcCallCommand? get activeGrpcPrimaryCommand {
    if (!isActiveGrpc) return null;
    final call = activeGrpcCall;
    if (call.requiresRestart || call.can(GrpcCallCommand.restart)) {
      return GrpcCallCommand.restart;
    }
    if (call.can(GrpcCallCommand.cancel)) return GrpcCallCommand.cancel;
    if (call.can(GrpcCallCommand.start)) return GrpcCallCommand.start;
    return null;
  }

  /// 当前 gRPC JSON 草稿的编码预览；错误保留字段路径供编辑器就地展示。
  ProtobufEncodePreview? get activeGrpcRequestPreview {
    if (!isActiveGrpc) return null;
    final descriptor = internals.protobufDescriptors[internals.activeRequestId];
    final serviceName = activeDraft.grpc.serviceName;
    final methodName = activeDraft.grpc.methodName;
    if (descriptor == null || serviceName == null || methodName == null) {
      return const ProtobufEncodePreview.failure(
        'Import a proto file and select a service and method first.',
      );
    }
    final method = descriptor
        .service(serviceName)
        ?.methods
        .where((item) => item.name == methodName)
        .firstOrNull;
    if (method == null) {
      return const ProtobufEncodePreview.failure(
        'The selected RPC method is no longer available.',
      );
    }
    try {
      final bytes = internals.grpcCalls.encodeMessage(
        descriptor,
        method.requestType,
        resolveInternal(activeDraft.body),
      );
      return ProtobufEncodePreview.success(bytes.length);
    } on FormatException catch (error) {
      return ProtobufEncodePreview.failure(error.message);
    }
  }

  /// 活动请求的 Protobuf 描述符文件是否缺失（路径非空但文件不存在）。
  bool get isActiveProtobufSchemaMissing {
    final path = activeDraft.webSocket.protobufSchema?.path;
    return path != null &&
        path.isNotEmpty &&
        !internals.protobufSource.exists(path);
  }

  /// 最近一次执行失败的错误信息。
  String? get executionError => internals.executionError;

  /// 所有告知型会话消息和持久化安全事件共用通知中心。
  List<UserNotice> get notices =>
      List.unmodifiable(internals.noticeController.queue.notices);

  /// 通知中心只显示可在后续处理的未确认记录。
  List<UserNotice> get actionableNotices =>
      List.unmodifiable(notices.where((notice) => notice.isActionable));

  /// 是否存在可用于创建已保存 Mock Server 的成功响应。
  bool get canCreateMockFromResponse {
    final source = internals.currentExecutionResult;
    return source?.requestRef.id == internals.activeRequestId &&
        source?.requestSnapshot != null &&
        source?.responseSnapshot != null &&
        !isActiveGrpc &&
        !isActiveWebSocket;
  }

  /// 汇总发送操作的当前可用性及不可用原因。
  WorkspaceActionAvailability get actionAvailability {
    final isRequest = hasActiveRequest;
    final isWebSocket =
        isRequest && activeDraft.protocol == ApiRequestProtocol.webSocket;
    final hasUrl =
        isRequest &&
        '${activeDraft.baseUrlToken}${activeDraft.path}'.trim().isNotEmpty;
    final missingVariables = activeMissingVariableKeys;
    return WorkspaceActionAvailability(
      // WebSocket 请求只有在已连接时才能发送；普通请求要求有地址、
      // 环境变量齐全且当前没有正在发送的请求。
      canSend: isWebSocket
          ? activeWebSocketSession.canSend
          : hasUrl && missingVariables.isEmpty && !internals.isSending,
      // 按优先级给出不可发送的具体原因，供 UI 展示提示。
      sendUnavailableReason: !isRequest
          ? 'Send is available when an active request is open.'
          : isWebSocket && !activeWebSocketSession.canSend
          ? 'Connect before sending a message.'
          : internals.isSending
          ? 'The active request is already sending.'
          : missingVariables.isNotEmpty
          ? 'Missing environment variables: ${missingVariables.join(', ')}'
          : hasUrl
          ? null
          : 'Enter a request URL before sending.',
    );
  }

  /// 以视图资源形式暴露活动请求。
  RequestResource get activeRequest {
    return toRequestResourceInternal(
      internals.assetRepository.getRequest(internals.activeRequestId!),
    );
  }

  /// 活动请求的编辑草稿：优先返回未保存的覆盖草稿，否则从仓库转换而来。
  RequestDraft get activeDraft {
    return internals.draftOverrides[internals.activeRequestId] ??
        toRequestDraftInternal(
          internals.assetRepository.getRequest(internals.activeRequestId!),
        );
  }

  /// GET 与 HEAD 不携带请求体；其余 HTTP 方法保留正文编辑能力。
  bool get activeRequestSupportsBody =>
      activeDraft.protocol == ApiRequestProtocol.grpc ||
      (activeDraft.protocol == ApiRequestProtocol.http &&
          !isBodylessHttpMethodInternal(activeDraft.method));

  /// GET / HEAD 草稿中仍保留的实体数据会在发送时被忽略，供编辑器提示用户。
  bool get activeRequestHasIgnoredEntityData {
    if (activeDraft.protocol != ApiRequestProtocol.http ||
        !isBodylessHttpMethodInternal(activeDraft.method)) {
      return false;
    }
    return activeDraft.body.isNotEmpty ||
        activeDraft.formUrlEncodedFields.isNotEmpty ||
        activeDraft.multipartFields.isNotEmpty ||
        activeDraft.multipartFiles.isNotEmpty ||
        activeDraft.headers.any(
          (header) =>
              header.enabled &&
              const {
                'content-type',
                'content-length',
                'transfer-encoding',
              }.contains(header.keyName.toLowerCase()),
        );
  }

  /// 活动请求草稿中引用但环境中未定义的变量名列表。
  List<String> get activeMissingVariableKeys {
    if (!hasActiveRequest) return const [];
    final missing = <String>{};
    final draft = activeDraft;
    // 收集所有可能引用变量的文本，统一交给环境解析器检查缺失项。
    final templates = <String>[
      draft.baseUrlToken,
      draft.path,
      if (!hasMultipartContentTypeInternal(draft.headers) &&
          !hasFormUrlEncodedContentTypeInternal(draft.headers))
        draft.body,
      ...effectiveAuthenticationForInternal(draft).templateValues,
      for (final row in draft.params.where((row) => row.enabled)) row.keyName,
      for (final row in draft.params.where((row) => row.enabled)) row.value,
      for (final row in draft.headers.where((row) => row.enabled)) row.keyName,
      for (final row in draft.headers.where((row) => row.enabled)) row.value,
      for (final row in draft.formUrlEncodedFields.where((row) => row.enabled))
        row.keyName,
      for (final row in draft.formUrlEncodedFields.where((row) => row.enabled))
        row.value,
      for (final row in draft.multipartFields.where((row) => row.enabled))
        row.keyName,
      for (final row in draft.multipartFields.where((row) => row.enabled))
        row.value,
    ];
    for (final template in templates) {
      missing.addAll(
        internals.environmentStore.resolveTemplate(template).missingKeys,
      );
    }
    return missing.toList(growable: false);
  }

  /// 是否可以关闭局部 Environment 管理层并返回 Requests。
  bool get canReturnFromEnvironment => internals.environmentManagerOpen;

  /// 活动请求经过变量解析后的最终请求地址。
  ///
  /// 保留 URL 中已有的查询参数，并追加草稿中启用的参数行（允许同名参数合并）。
  String get resolvedUrl {
    final baseUrl = resolveInternal(activeDraft.baseUrlToken);
    final path = resolveInternal(activeDraft.path);
    final uri = Uri.parse('$baseUrl$path');
    final queryParameters = <String, List<String>>{
      for (final entry in uri.queryParametersAll.entries)
        entry.key: List<String>.of(entry.value),
    };
    for (final item in paramsWithAuthenticationInternal(
      activeDraft,
    ).where((item) => item.enabled && item.keyName.trim().isNotEmpty)) {
      queryParameters
          .putIfAbsent(resolveInternal(item.keyName), () => [])
          .add(resolveInternal(item.value));
    }
    return uri.replace(queryParameters: queryParameters).toString();
  }

  /// 活动草稿在地址栏中展示的 URL；启用的 Params 行会同步为 query string。
  String get activeDraftUrl => urlWithParamsInternal(activeDraft);

  /// 指定请求是否存在未保存的草稿修改。
  bool isRequestDirty(String requestId) =>
      internals.draftOverrides.containsKey(requestId);

  /// 指定请求是否仍存在于仓库中。
  bool requestExists(String requestId) => internals.assetRepository
      .listRequests()
      .any((request) => request.id == requestId);

  /// 集合是否处于展开状态（默认展开，仅在折叠集合中缺席时收起）。
  bool isCollectionExpanded(String collectionId) =>
      !internals.collapsedCollectionIds.contains(collectionId);

  /// 文件夹是否处于展开状态。
  bool isFolderExpanded(String folderId) =>
      !internals.collapsedFolderIds.contains(folderId);

  /// 切换集合的展开 / 折叠状态。
  void toggleCollection(String collectionId) {
    // 先尝试移除；失败说明此前未折叠，则加入折叠集合。
    if (!internals.collapsedCollectionIds.remove(collectionId)) {
      internals.collapsedCollectionIds.add(collectionId);
    }
    notifyWorkspace();
  }

  /// 切换文件夹的展开 / 折叠状态。
  void toggleFolder(String folderId) {
    if (!internals.collapsedFolderIds.remove(folderId)) {
      internals.collapsedFolderIds.add(folderId);
    }
    notifyWorkspace();
  }
}
