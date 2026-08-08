import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../data/demo/workbench_seed.dart';
import '../../../data/demo/demo_example_catalog.dart';
import '../../../data/services/http_request_execution_runtime.dart';
import '../../../data/services/desktop_grpc_transport.dart';
import '../../../data/services/desktop_websocket_transport.dart';
import '../../../data/services/api_documentation_generator.dart';
import '../../../data/services/documentation_output_directory.dart';
import '../../../data/services/local_mock_runtime.dart';
import '../../../data/services/openapi_request_importer.dart';
import '../../../data/services/openapi_request_exporter.dart';
import '../../../data/services/protobuf_descriptor_set.dart';
import '../../../data/services/protobuf_dynamic_codec.dart';
import '../../../data/services/proto_source_parser.dart';
import '../../../domain/api_assets/api_asset_models.dart';
import '../../../domain/authentication/request_authentication.dart';
import '../../../domain/environments/environment_models.dart';
import '../../../domain/grpc/grpc_call_registry.dart';
import '../../../domain/grpc/grpc_transport.dart';
import '../../../domain/models/workspace_models.dart';
import '../../../domain/preferences/workspace_preferences.dart';
import '../../../domain/repositories/api_asset_repository.dart';
import '../../../domain/repositories/environment_store.dart';
import '../../../domain/repositories/execution_history_store.dart';
import '../../../domain/repositories/workspace_preference_store.dart';
import '../../../domain/request_runtime/request_execution_runtime.dart';
import '../../../domain/websocket/websocket_session_registry.dart';
import '../../../domain/websocket/websocket_transport.dart';
import '../../request_editor/models/request_editor_models.dart';
import '../../response_viewer/models/response_viewer_models.dart';
import '../application/workspace_dependencies.dart';
import '../models/workspace_shell_models.dart';

part 'workspace_view_model_assets.dart';
part 'workspace_view_model_execution.dart';
part 'workspace_view_model_navigation.dart';
part 'workspace_view_model_persistence.dart';
part 'workspace_view_model_protocols.dart';
part 'workspace_view_model_request_configuration.dart';

/// Protobuf 发送预览：成功时给出编码后的字节数，失败时给出字段路径错误。
class ProtobufEncodePreview {
  /// 私有构造，仅由成功 / 失败工厂构造器调用。
  const ProtobufEncodePreview._({this.byteLength, this.error});

  /// 创建编码成功的结果，携带编码后的字节数。
  const ProtobufEncodePreview.success(int byteLength)
    : this._(byteLength: byteLength);

  /// 创建编码失败的结果，携带错误信息。
  const ProtobufEncodePreview.failure(String error) : this._(error: error);

  /// 编码后的字节数；失败时为空。
  final int? byteLength;

  /// 字段校验或 schema 错误；成功时为空。
  final String? error;

  /// 是否成功完成编码。
  bool get isSuccess => error == null;
}

/// WebSocket 二进制帧按当前 Protobuf schema 解码后的详情。
class WebSocketProtobufDecodeDetail {
  /// 私有构造，仅由成功 / 失败工厂构造器调用。
  const WebSocketProtobufDecodeDetail._({this.formattedJson, this.error});

  /// 创建解码成功的结果，携带格式化 JSON。
  const WebSocketProtobufDecodeDetail.success(String formattedJson)
    : this._(formattedJson: formattedJson);

  /// 创建单帧解码失败的结果，携带错误信息。
  const WebSocketProtobufDecodeDetail.failure(String error)
    : this._(error: error);

  /// 解码后的格式化 JSON；失败时为空。
  final String? formattedJson;

  /// 单帧解码错误；成功时为空。
  final String? error;

  /// 是否成功解码。
  bool get isSuccess => error == null;
}

/// 壳层 ViewModel 只编排 UI 状态，不直接承担真实网络发送。
class WorkspaceViewModel extends ChangeNotifier {
  /// 构建工作区 ViewModel。
  ///
  /// 仓储必须由应用组合根注入，避免 ViewModel 依赖具体的存储后端。
  /// 运行时传输与功能服务可按需替换，便于测试。
  /// 初始偏好取自 [initialPreferences]，WebSocket 会话注册表的变更会触发
  /// [notifyListeners] 刷新 UI。
  factory WorkspaceViewModel({
    WorkbenchSeed? seed,
    required ApiAssetRepository assetRepository,
    required EnvironmentStore environmentStore,
    RequestExecutionRuntime? executionRuntime,
    WebSocketTransport? webSocketTransport,
    GrpcTransport? grpcTransport,
    ApiDocumentationGenerator? documentationGenerator,
    LocalMockRuntime? mockRuntime,
    required WorkspacePreferenceStore preferenceStore,
    ExecutionHistoryStore? historyStore,
    List<ExecutionRecord>? initialHistory,
    WorkspacePreferences initialPreferences = WorkspacePreferences.defaults,
    String? defaultDocumentationOutputDirectory,
  }) => WorkspaceViewModel._(
    seed: seed,
    assetRepository: assetRepository,
    environmentStore: environmentStore,
    executionRuntime: executionRuntime,
    webSocketTransport: webSocketTransport,
    grpcTransport: grpcTransport,
    documentationGenerator: documentationGenerator,
    mockRuntime: mockRuntime,
    preferenceStore: preferenceStore,
    historyStore: historyStore,
    initialHistory: initialHistory,
    initialPreferences: initialPreferences,
    defaultDocumentationOutputDirectory: defaultDocumentationOutputDirectory,
  );

  /// 从 Workspace 的完整依赖快照构建 ViewModel。
  ///
  /// Workspace 视图应使用此入口，避免了解每个持久化端口的内部组成；针对
  /// 单个仓储行为的单元测试仍可使用主构造器注入精确替身。
  factory WorkspaceViewModel.fromDependencies({
    WorkbenchSeed? seed,
    required WorkspaceDependencies dependencies,
    RequestExecutionRuntime? executionRuntime,
    WebSocketTransport? webSocketTransport,
    GrpcTransport? grpcTransport,
    ApiDocumentationGenerator? documentationGenerator,
    LocalMockRuntime? mockRuntime,
    WorkspacePreferences initialPreferences = WorkspacePreferences.defaults,
  }) => WorkspaceViewModel(
    seed: seed,
    assetRepository: dependencies.assetRepository,
    environmentStore: dependencies.environmentStore,
    executionRuntime: executionRuntime,
    webSocketTransport: webSocketTransport,
    grpcTransport: grpcTransport,
    documentationGenerator: documentationGenerator,
    mockRuntime: mockRuntime,
    preferenceStore: dependencies.preferenceStore,
    historyStore: dependencies.historyStore,
    initialHistory: dependencies.initialHistory,
    initialPreferences: initialPreferences,
    defaultDocumentationOutputDirectory:
        dependencies.defaultDocumentationOutputDirectory,
  );

  WorkspaceViewModel._({
    WorkbenchSeed? seed,
    required this._assetRepository,
    required this._environmentStore,
    RequestExecutionRuntime? executionRuntime,
    WebSocketTransport? webSocketTransport,
    GrpcTransport? grpcTransport,
    ApiDocumentationGenerator? documentationGenerator,
    LocalMockRuntime? mockRuntime,
    required this._preferenceStore,
    this.historyStore,
    List<ExecutionRecord>? initialHistory,
    WorkspacePreferences initialPreferences = WorkspacePreferences.defaults,
    String? defaultDocumentationOutputDirectory,
  }) : _seed = seed ?? WorkbenchSeed.sample(),
       _executionRuntime = executionRuntime ?? HttpRequestExecutionRuntime(),
       _documentationGenerator =
           documentationGenerator ?? const ApiDocumentationGenerator(),
       _mockRuntime = mockRuntime ?? LoopbackMockRuntime() {
    // 用种子数据初始化执行历史与当前活动请求。
    _history = List.of(initialHistory ?? _seed.history);
    _activeRequestId = _assetRepository.activeRequestId;
    _sendShortcut = initialPreferences.sendShortcut;
    _customSendShortcut = initialPreferences.customSendShortcut;
    _appearance = initialPreferences.appearance;
    _locale = initialPreferences.locale;
    _font = initialPreferences.font;
    _defaultDocumentationOutputDirectory =
        defaultDocumentationOutputDirectory ??
        DocumentationOutputDirectory.testFallbackPath();
    final configuredOutputDirectory = initialPreferences
        .documentationOutputDirectory
        ?.trim();
    _documentationOutputDirectory =
        configuredOutputDirectory == null || configuredOutputDirectory.isEmpty
        ? _defaultDocumentationOutputDirectory
        : configuredOutputDirectory;
    // 已保存的自定义目录可能被用户在应用外删除；启动后立即尝试重建，
    // 真正导出与保存时仍会等待并报告失败。
    unawaited(_ensureInitialDocumentationOutputDirectory());
    // WebSocket 会话状态变化直接驱动整个工作区重绘。
    _webSocketSessions = WebSocketSessionRegistry(
      webSocketTransport ?? const DesktopWebSocketTransport(),
      onChanged: () {
        if (!_isDisposed) {
          _persistFinishedWebSocketSessions();
          notifyListeners();
        }
      },
    );
    _grpcCalls = GrpcCallRegistry(
      grpcTransport ?? const DesktopGrpcTransport(),
      onChanged: () {
        if (!_isDisposed) notifyListeners();
      },
    );
  }

  /// 种子数据源，提供演示用的集合、指标与执行历史。
  final WorkbenchSeed _seed;

  /// 请求资产的读写仓库（集合 / 请求 / 打开标签页）。
  final ApiAssetRepository _assetRepository;

  /// 环境变量与环境的存储。
  final EnvironmentStore _environmentStore;

  /// 负责真实发送 HTTP 请求的执行运行时。
  final RequestExecutionRuntime _executionRuntime;

  /// 按请求管理的 WebSocket 会话注册表，延迟到构造函数中初始化。
  late final WebSocketSessionRegistry _webSocketSessions;

  /// 按请求 ID 管理 gRPC 调用和有限响应时间线。
  late final GrpcCallRegistry _grpcCalls;

  /// 根据请求草稿生成 API 文档。
  final ApiDocumentationGenerator _documentationGenerator;

  /// 本地 Mock 服务器运行时。
  final LocalMockRuntime _mockRuntime;

  /// 用户偏好（外观 / 快捷键 / 语言）的持久化存储。
  final WorkspacePreferenceStore _preferenceStore;

  /// 执行历史持久化端口；未注入时保持内存行为，便于组件测试。
  final ExecutionHistoryStore? historyStore;

  /// 防止异步会话清理在销毁后通知已释放的界面。
  bool _isDisposed = false;

  /// 最近一次执行的请求记录列表，头部为最新记录。
  late List<ExecutionRecord> _history;

  /// 当前可见的工作区区块。
  WorkspaceSection _activeSection = WorkspaceSection.collections;

  /// 进入环境区块前的来源区块，用于从环境页返回时还原上下文。
  WorkspaceSection? _environmentReturnSection;

  /// 当前活动请求的 ID，为空表示没有打开的请求。
  String? _activeRequestId;

  /// 请求编辑器当前选中的子标签页。
  RequestEditorSection _activeRequestTab = RequestEditorSection.params;

  /// 响应面板当前选中的子标签页。
  ResponseTab _activeResponseTab = ResponseTab.body;

  /// 仪表盘展示的时间范围选项。
  String _dashboardRange = '24H';

  /// 发送请求的快捷键偏好。
  SendShortcutPreference _sendShortcut = SendShortcutPreference.controlEnter;

  /// 自定义发送组合键；仅在 [_sendShortcut] 为 custom 时生效。
  ShortcutBinding _customSendShortcut = ShortcutBinding.controlEnter;

  /// 界面外观偏好（浅色 / 深色 / 跟随系统）。
  AppearancePreference _appearance = AppearancePreference.dark;

  /// 界面语言偏好。
  LocalePreference _locale = LocalePreference.system;

  /// 应用正文与控件字体偏好。
  WorkspaceFontPreference _font = WorkspaceFontPreference.inter;

  /// Markdown 接口文档导出的目标目录。
  String _documentationOutputDirectory =
      DocumentationOutputDirectory.testFallbackPath();

  /// 启动组合根解析出的默认目录，供“恢复默认目录”动作稳定复用。
  late final String _defaultDocumentationOutputDirectory;

  /// 偏好是否被修改过但尚未保存。
  bool _hasPreferenceChanges = false;

  /// 串行化偏好写入，避免快速连续配置时旧快照覆盖新快照。
  Future<void> _preferenceSaveQueue = Future<void>.value();

  /// 最近一次入队的偏好写入版本，用于避免旧写入提前清除未保存状态。
  int _preferenceSaveVersion = 0;

  /// 窄布局下右侧面板的当前选择。
  NarrowWorkspacePanel _narrowWorkspacePanel = NarrowWorkspacePanel.request;

  /// 最近一次执行得到的响应快照。
  ResponseSnapshot? _response;

  /// 当前是否正在发送请求。
  bool _isSending = false;

  /// 正在发送的请求 ID，用于并发控制与取消判断。
  String? _sendingRequestId;

  /// 执行代数，每次发起新请求时递增，用于作废过期的异步结果。
  int _executionGeneration = 0;

  /// 最近一次执行失败的错误信息。
  String? _executionError;

  /// 正在查看的历史记录，为空表示未打开历史详情。
  ExecutionRecord? _openedHistoryRecord;

  /// 创建 Mock 服务时正在编辑的草稿。
  MockDraft? _mockDraft;

  /// Mock 服务正在绑定本地端口，期间禁止重复启动。
  bool _isMockStarting = false;

  /// 生成文档时正在编辑的草稿。
  DocumentationDraft? _documentationDraft;

  /// 进入 Mock 页前的来源区块，用于返回时还原。
  WorkspaceSection _mockReturnSection = WorkspaceSection.collections;

  /// 进入文档页前的来源区块，用于返回时还原。
  WorkspaceSection _documentationReturnSection = WorkspaceSection.collections;

  /// 最近一次用户操作的提示消息，展示后即清除。
  String? _lastActionMessage;

  /// 未保存的请求编辑草稿，键为请求 ID。
  final Map<String, RequestDraft> _draftOverrides = {};

  /// 各请求的 WebSocket 消息编辑草稿。
  final Map<String, WebSocketMessageDraft> _webSocketMessageDrafts = {};

  /// 已落库的 WebSocket 会话起始时间，防止同一终止状态重复写入历史。
  final Map<String, DateTime> _persistedWebSocketSessionStarts = {};

  /// 各请求可用的 Protobuf 消息类型名列表。
  final Map<String, List<String>> _protobufMessageTypes = {};

  /// 各请求已解析的 Protobuf 描述符集，按路径缓存。
  final Map<String, ProtobufDescriptorSet> _protobufDescriptors = {};

  /// 已折叠的集合 ID 集合，用于记忆展开状态。
  final Set<String> _collapsedCollectionIds = {};

  /// 已折叠的文件夹 ID 集合。
  final Set<String> _collapsedFolderIds = {};

  /// 已手动展开（显示明文）的草稿字段 ID 集合。
  final Set<String> _revealedDraftFieldIds = {};

  /// 为新建草稿字段生成稳定 ID 的自增序号。
  int _draftFieldSequence = 0;

  /// 当前选中的工作区区块。
  WorkspaceSection get activeSection => _activeSection;

  /// 当前选中的请求编辑器子标签页 ID。
  String get activeRequestTab => _activeRequestTab.id;

  /// 当前选中的响应面板子标签页。
  ResponseTab get activeResponseTab => _activeResponseTab;

  /// 仪表盘当前的时间范围选项。
  String get dashboardRange => _dashboardRange;

  /// 发送快捷键偏好。
  SendShortcutPreference get sendShortcut => _sendShortcut;

  /// 发送请求实际注册到应用的快捷键。
  ShortcutBinding get sendShortcutBinding => switch (_sendShortcut) {
    SendShortcutPreference.controlEnter => ShortcutBinding.controlEnter,
    SendShortcutPreference.controlSpace => ShortcutBinding.controlSpace,
    SendShortcutPreference.custom => _customSendShortcut,
  };

  /// 判断键盘事件是否匹配当前发送组合键。
  ///
  /// 预设快捷键兼容 Ctrl 与 Cmd；自定义组合键严格按录入结果匹配。
  bool matchesSendShortcut(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final binding = sendShortcutBinding;
    final keyboard = HardwareKeyboard.instance;
    final usesMetaForPreset =
        _sendShortcut != SendShortcutPreference.custom &&
        !binding.meta &&
        keyboard.isMetaPressed;
    return event.logicalKey.keyId == binding.keyId &&
        keyboard.isControlPressed ==
            (usesMetaForPreset ? false : binding.control) &&
        keyboard.isAltPressed == binding.alt &&
        keyboard.isShiftPressed == binding.shift &&
        keyboard.isMetaPressed == (binding.meta || usesMetaForPreset);
  }

  /// 当前发送快捷键的可见标签。
  String get sendShortcutLabel => sendShortcutBinding.label;

  /// 外观偏好。
  AppearancePreference get appearance => _appearance;

  /// 语言偏好。
  LocalePreference get locale => _locale;

  /// 当前界面字体偏好。
  WorkspaceFontPreference get font => _font;

  /// Markdown 接口文档导出的目标目录。
  String get documentationOutputDirectory => _documentationOutputDirectory;

  /// 当前文档导出是否使用系统默认目录。
  bool get usesDefaultDocumentationOutputDirectory =>
      _documentationOutputDirectory == _defaultDocumentationOutputDirectory;

  /// 是否存在未保存的偏好变更。
  bool get hasPreferenceChanges => _hasPreferenceChanges;

  /// 窄布局下右侧面板的当前选择。
  NarrowWorkspacePanel get narrowWorkspacePanel => _narrowWorkspacePanel;

  /// 最近一次操作提示消息。
  String? get lastActionMessage => _lastActionMessage;

  /// 是否存在活动请求。
  bool get hasActiveRequest => _activeRequestId != null;

  /// 以视图资源形式暴露全部集合（含展开状态与请求列表）。
  List<CollectionResource> get collections => _assetRepository
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
                      .map(_toRequestResource)
                      .toList(growable: false),
                ),
              )
              .toList(growable: false),
        ),
      )
      .toList(growable: false);

  /// 以视图资源形式暴露全部请求。
  List<RequestResource> get requests => _assetRepository
      .listRequests()
      .map(_toRequestResource)
      .toList(growable: false);

  /// 当前打开的请求标签页列表。
  List<RequestTab> get openRequestTabs => _assetRepository.listOpenTabs();

  /// 当前环境下的全部变量视图。
  List<EnvironmentVariableView> get variables =>
      _environmentStore.listVariables();

  /// 已保留但未被当前环境认证使用的凭据，可由用户明确确认后清理。
  List<String> get unusedAuthenticationVariableNames =>
      _environmentStore.listUnusedAuthenticationVariableNames();

  /// 全部环境配置。
  List<EnvironmentProfile> get environments =>
      _environmentStore.listEnvironments();

  /// 当前活动环境。
  EnvironmentProfile get activeEnvironment =>
      _environmentStore.activeEnvironment;

  /// 当前环境必填 baseUrl 的展示值，Collection 与请求编辑器共享该上下文。
  String get activeEnvironmentBaseUrl => _environmentStore
      .listVariables()
      .firstWhere((variable) => variable.key == 'baseUrl')
      .displayValue;

  /// 环境是否存在未保存的修改。
  bool get hasEnvironmentChanges => _environmentStore.hasUnsavedChanges;

  /// 仪表盘展示的指标数据。
  List<MetricSummary> get metrics => _seed.metrics;

  /// 执行历史（不可变视图）。
  List<ExecutionRecord> get history => List.unmodifiable(_history);

  /// 最近一次执行得到的响应快照。
  ResponseSnapshot? get response => _response;

  /// 是否正在发送请求。
  bool get isSending => _isSending;

  /// 活动请求是否为 WebSocket 协议。
  bool get isActiveWebSocket =>
      hasActiveRequest && activeDraft.protocol == ApiRequestProtocol.webSocket;

  /// 活动请求是否使用 gRPC 协议。
  bool get isActiveGrpc =>
      hasActiveRequest && activeDraft.protocol == ApiRequestProtocol.grpc;

  /// 活动请求的 WebSocket 会话快照。
  WebSocketSession get activeWebSocketSession =>
      _webSocketSessions.sessionFor(_activeRequestId!);

  /// 当前 gRPC 请求的调用状态与有界事件时间线。
  GrpcCallSnapshot get activeGrpcCall => _grpcCalls.callFor(_activeRequestId!);

  /// 按当前 RPC 的响应消息描述解码一条 gRPC 二进制事件。
  ProtobufDecodeResult? decodeActiveGrpcEvent(GrpcCallEvent event) {
    final message = event.message;
    final descriptor = _protobufDescriptors[_activeRequestId];
    final service = descriptor?.service(activeDraft.grpc.serviceName ?? '');
    final method = service?.methods
        .where((item) => item.name == activeDraft.grpc.methodName)
        .firstOrNull;
    if (message == null || descriptor == null || method == null) return null;
    return ProtobufDynamicCodec(
      descriptor,
    ).tryDecodeJson(method.responseType, message);
  }

  /// 活动请求的 WebSocket 消息编辑草稿，未编辑过则返回空草稿。
  WebSocketMessageDraft get activeWebSocketMessageDraft =>
      _webSocketMessageDrafts[_activeRequestId] ??
      const WebSocketMessageDraft();

  /// 活动请求可用的 Protobuf 消息类型列表。
  List<String> get activeProtobufMessageTypes =>
      _protobufMessageTypes[_activeRequestId] ?? const [];

  /// 当前导入 proto 中可选择的 gRPC 服务。
  List<ProtobufServiceDescriptor> get activeGrpcServices =>
      (_protobufDescriptors[_activeRequestId]?.services.values.toList()
        ?..sort((left, right) => left.name.compareTo(right.name))) ??
      const [];

  /// 当前选定服务下可选择的 RPC 方法。
  List<ProtobufMethodDescriptor> get activeGrpcMethods {
    final service = _protobufDescriptors[_activeRequestId]?.service(
      activeDraft.grpc.serviceName ?? '',
    );
    return service?.methods ?? const [];
  }

  /// 当前 gRPC JSON 草稿的编码预览；错误保留字段路径供编辑器就地展示。
  ProtobufEncodePreview? get activeGrpcRequestPreview {
    if (!isActiveGrpc) return null;
    final descriptor = _protobufDescriptors[_activeRequestId];
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
      final bytes = ProtobufDynamicCodec(
        descriptor,
      ).encodeJson(method.requestType, _resolve(activeDraft.body));
      return ProtobufEncodePreview.success(bytes.length);
    } on FormatException catch (error) {
      return ProtobufEncodePreview.failure(error.message);
    }
  }

  /// 活动请求的 Protobuf 描述符文件是否缺失（路径非空但文件不存在）。
  bool get isActiveProtobufSchemaMissing {
    final path = activeDraft.webSocket.protobufSchema?.path;
    return path != null && path.isNotEmpty && !File(path).existsSync();
  }

  /// 文档草稿所引用的原始请求是否仍存在。
  bool get canTryDocumentationDraft {
    final requestId = _documentationDraft?.requestId;
    return requestId != null && requestExists(requestId);
  }

  /// 最近一次执行失败的错误信息。
  String? get executionError => _executionError;

  /// 当前查看的历史记录。
  ExecutionRecord? get openedHistoryRecord => _openedHistoryRecord;

  /// 当前 Mock 服务草稿。
  MockDraft? get mockDraft => _mockDraft;

  /// 是否存在可用于预填 Mock 草稿的成功响应。
  bool get canCreateMockFromResponse {
    final source = _openedHistoryRecord ?? _latestResponseRecord();
    return source?.requestSnapshot != null && source?.response != null;
  }

  /// 本地 Mock 服务是否在运行。
  bool get isMockRunning => _mockRuntime.isRunning;

  /// 本地 Mock 服务是否正在启动。
  bool get isMockStarting => _isMockStarting;

  /// 本地 Mock 服务的可调用完整 endpoint，包含草稿中的路径和查询参数。
  Uri? get mockUrl {
    final base = _mockRuntime.info?.url;
    final draft = _mockDraft;
    if (base == null || draft == null) return null;
    final target = Uri.tryParse(draft.request.resolvedUrl);
    return base.replace(path: target?.path ?? '/', query: target?.query ?? '');
  }

  /// Mock 草稿当前用于路由匹配的路径和查询参数。
  String get mockRoute {
    final target = Uri.tryParse(_mockDraft?.request.resolvedUrl ?? '');
    if (target == null) return '/';
    final path = target.path.isEmpty ? '/' : target.path;
    return target.hasQuery ? '$path?${target.query}' : path;
  }

  /// 当前文档草稿。
  DocumentationDraft? get documentationDraft => _documentationDraft;

  /// 根据文档草稿实时生成 API 文档。
  GeneratedApiDocumentation? get generatedDocumentation {
    final draft = _documentationDraft;
    return draft == null ? null : _documentationGenerator.generate(draft);
  }

  /// 描述当前区块下活动资源的引用，供面包屑与全局操作定位。
  WorkspaceResourceRef get activeResource {
    switch (_activeSection) {
      case WorkspaceSection.dashboard:
        return const WorkspaceResourceRef(
          type: WorkspaceResourceType.dashboard,
          workspaceId: 'workspace-main',
          id: 'dashboard',
          title: 'Dashboard',
        );
      case WorkspaceSection.collections:
        // 集合区块下若没有打开的请求，则资源定位到默认集合。
        if (_activeRequestId == null) {
          return const WorkspaceResourceRef(
            type: WorkspaceResourceType.collection,
            workspaceId: 'workspace-main',
            id: 'collection-sendreq-demo',
            title: 'Sendreq Demo Example',
          );
        }
        return WorkspaceResourceRef(
          type: WorkspaceResourceType.request,
          workspaceId: 'workspace-main',
          id: _activeRequestId!,
          title: activeRequest.name,
        );
      case WorkspaceSection.history:
        return const WorkspaceResourceRef(
          type: WorkspaceResourceType.history,
          workspaceId: 'workspace-main',
          id: 'history',
          title: 'History',
        );
      case WorkspaceSection.environments:
        return const WorkspaceResourceRef(
          type: WorkspaceResourceType.environment,
          workspaceId: 'workspace-main',
          id: 'staging',
          title: 'Staging',
        );
      case WorkspaceSection.mockServers:
        return const WorkspaceResourceRef(
          type: WorkspaceResourceType.mockServer,
          workspaceId: 'workspace-main',
          id: 'mock-servers',
          title: 'Quick Mock',
        );
      case WorkspaceSection.documentation:
        return const WorkspaceResourceRef(
          type: WorkspaceResourceType.documentation,
          workspaceId: 'workspace-main',
          id: 'documentation',
          title: 'Documentation',
        );
      case WorkspaceSection.settings:
        return const WorkspaceResourceRef(
          type: WorkspaceResourceType.settings,
          workspaceId: 'workspace-main',
          id: 'settings',
          title: 'Settings',
        );
    }
  }

  /// 可由命令面板检索的工作区资源。
  List<WorkspaceResourceRef> get searchableResources => [
    const WorkspaceResourceRef(
      type: WorkspaceResourceType.dashboard,
      workspaceId: 'workspace-main',
      id: 'dashboard',
      title: 'Dashboard',
    ),
    const WorkspaceResourceRef(
      type: WorkspaceResourceType.history,
      workspaceId: 'workspace-main',
      id: 'history',
      title: 'History',
    ),
    const WorkspaceResourceRef(
      type: WorkspaceResourceType.environment,
      workspaceId: 'workspace-main',
      id: 'environments',
      title: 'Environments',
    ),
    const WorkspaceResourceRef(
      type: WorkspaceResourceType.mockServer,
      workspaceId: 'workspace-main',
      id: 'mock-servers',
      title: 'Quick Mock',
    ),
    const WorkspaceResourceRef(
      type: WorkspaceResourceType.documentation,
      workspaceId: 'workspace-main',
      id: 'documentation',
      title: 'Documentation',
    ),
    const WorkspaceResourceRef(
      type: WorkspaceResourceType.settings,
      workspaceId: 'workspace-main',
      id: 'settings',
      title: 'Settings',
    ),
    for (final request in requests)
      WorkspaceResourceRef(
        type: WorkspaceResourceType.request,
        workspaceId: 'workspace-main',
        id: request.id,
        title: request.name,
      ),
  ];

  /// 打开命令面板选中的请求或工作区分区。
  void openSearchResource(WorkspaceResourceRef resource) {
    switch (resource.type) {
      case WorkspaceResourceType.request:
        selectRequest(resource.id);
      case WorkspaceResourceType.dashboard:
        selectSection(WorkspaceSection.dashboard);
      case WorkspaceResourceType.history:
        selectSection(WorkspaceSection.history);
      case WorkspaceResourceType.environment:
        selectSection(WorkspaceSection.environments);
      case WorkspaceResourceType.mockServer:
        selectSection(WorkspaceSection.mockServers);
      case WorkspaceResourceType.documentation:
        selectSection(WorkspaceSection.documentation);
      case WorkspaceResourceType.settings:
        selectSection(WorkspaceSection.settings);
      case WorkspaceResourceType.collection:
        selectSection(WorkspaceSection.collections);
    }
  }

  /// 汇总全局操作（发送 / 保存）当前是否可用及不可用原因。
  WorkspaceActionAvailability get actionAvailability {
    final isRequest = activeResource.isRequest;
    final isWebSocket =
        isRequest && activeDraft.protocol == ApiRequestProtocol.webSocket;
    final hasUrl =
        isRequest &&
        '${activeDraft.baseUrlToken}${activeDraft.path}'.trim().isNotEmpty;
    final missingVariables = activeMissingVariableKeys;
    return WorkspaceActionAvailability(
      canSave: isRequest && isRequestDirty(_activeRequestId!),
      // WebSocket 请求只有在已连接时才能发送；普通请求要求有地址、
      // 环境变量齐全且当前没有正在发送的请求。
      canSend: isWebSocket
          ? activeWebSocketSession.canSend
          : hasUrl && missingVariables.isEmpty && !_isSending,
      // 按优先级给出不可发送的具体原因，供 UI 展示提示。
      sendUnavailableReason: !isRequest
          ? 'Send is available when an active request is open.'
          : isWebSocket && !activeWebSocketSession.canSend
          ? 'Connect before sending a message.'
          : _isSending
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
    return _toRequestResource(_assetRepository.getRequest(_activeRequestId!));
  }

  /// 活动请求的编辑草稿：优先返回未保存的覆盖草稿，否则从仓库转换而来。
  RequestDraft get activeDraft {
    return _draftOverrides[_activeRequestId] ??
        _toRequestDraft(_assetRepository.getRequest(_activeRequestId!));
  }

  /// GET 与 HEAD 不携带请求体；其余 HTTP 方法保留正文编辑能力。
  bool get activeRequestSupportsBody =>
      activeDraft.protocol == ApiRequestProtocol.grpc ||
      (activeDraft.protocol == ApiRequestProtocol.http &&
          !_isBodylessHttpMethod(activeDraft.method));

  /// GET / HEAD 草稿中仍保留的实体数据会在发送时被忽略，供编辑器提示用户。
  bool get activeRequestHasIgnoredEntityData {
    if (activeDraft.protocol != ApiRequestProtocol.http ||
        !_isBodylessHttpMethod(activeDraft.method)) {
      return false;
    }
    return activeDraft.body.isNotEmpty ||
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
      draft.body,
      ..._effectiveAuthenticationFor(draft).templateValues,
      for (final row in draft.params) row.keyName,
      for (final row in draft.params) row.value,
      for (final row in draft.headers) row.keyName,
      for (final row in draft.headers) row.value,
      for (final row in draft.multipartFields) row.keyName,
      for (final row in draft.multipartFields) row.value,
    ];
    for (final template in templates) {
      missing.addAll(_environmentStore.resolveTemplate(template).missingKeys);
    }
    return missing.toList(growable: false);
  }

  /// 是否可以从环境区块返回（存在来源区块且有活动请求）。
  bool get canReturnFromEnvironment =>
      _environmentReturnSection != null && hasActiveRequest;

  /// 活动请求经过变量解析后的最终请求地址。
  ///
  /// 保留 URL 中已有的查询参数，并追加草稿中启用的参数行（允许同名参数合并）。
  String get resolvedUrl {
    final baseUrl = _resolve(activeDraft.baseUrlToken);
    final path = _resolve(activeDraft.path);
    final uri = Uri.parse('$baseUrl$path');
    final queryParameters = <String, List<String>>{
      for (final entry in uri.queryParametersAll.entries)
        entry.key: List<String>.of(entry.value),
    };
    for (final item in _paramsWithAuthentication(
      activeDraft,
    ).where((item) => item.enabled && item.keyName.trim().isNotEmpty)) {
      queryParameters
          .putIfAbsent(_resolve(item.keyName), () => [])
          .add(_resolve(item.value));
    }
    return uri.replace(queryParameters: queryParameters).toString();
  }

  /// 活动草稿在地址栏中展示的 URL；启用的 Params 行会同步为 query string。
  String get activeDraftUrl => _urlWithParams(activeDraft);

  /// 指定请求是否存在未保存的草稿修改。
  bool isRequestDirty(String requestId) =>
      _draftOverrides.containsKey(requestId);

  /// 指定请求是否仍存在于仓库中。
  bool requestExists(String requestId) =>
      _assetRepository.listRequests().any((request) => request.id == requestId);

  /// 集合是否处于展开状态（默认展开，仅在折叠集合中缺席时收起）。
  bool isCollectionExpanded(String collectionId) =>
      !_collapsedCollectionIds.contains(collectionId);

  /// 文件夹是否处于展开状态。
  bool isFolderExpanded(String folderId) =>
      !_collapsedFolderIds.contains(folderId);

  /// 切换集合的展开 / 折叠状态。
  void toggleCollection(String collectionId) {
    // 先尝试移除；失败说明此前未折叠，则加入折叠集合。
    if (!_collapsedCollectionIds.remove(collectionId)) {
      _collapsedCollectionIds.add(collectionId);
    }
    notifyListeners();
  }

  /// 切换文件夹的展开 / 折叠状态。
  void toggleFolder(String folderId) {
    if (!_collapsedFolderIds.remove(folderId)) {
      _collapsedFolderIds.add(folderId);
    }
    notifyListeners();
  }

  /// 销毁时释放全部 WebSocket 会话并停止本地 Mock 服务。
  @override
  void dispose() {
    // ChangeNotifier 的 dispose 不能 await；先记下活跃会话摘要，避免退出丢失。
    final endedAt = DateTime.now();
    for (final session in _webSocketSessions.sessions) {
      final startedAt = session.sessionStartedAt;
      if (startedAt != null) {
        _appendWebSocketSessionSummary(
          session,
          startedAt: startedAt,
          endedAt: session.sessionEndedAt ?? endedAt,
        );
      }
    }
    _isDisposed = true;
    unawaited(_webSocketSessions.dispose());
    unawaited(_grpcCalls.dispose());
    _mockRuntime.stop();
    super.dispose();
  }

  /// 供同一 library 的领域操作扩展触发一次界面刷新。
  void _notify() => notifyListeners();
}

/// URL 拆分结果：baseUrl 模板标记、路径与 query 参数。
class _DraftUrlParts {
  /// 构造 URL 拆分结果。
  const _DraftUrlParts({
    required this.baseUrlToken,
    required this.path,
    required this.parameters,
  });

  /// baseUrl 模板标记（含 `{{ }}`），无 baseUrl 时为空。
  final String baseUrlToken;

  /// 不含 query 的路径部分。
  final String path;

  /// 解析后的 query 参数列表。
  final List<_UrlQueryParameter> parameters;
}

/// 单个 query 参数的键值对。
class _UrlQueryParameter {
  /// 构造一个 query 参数。
  const _UrlQueryParameter({required this.key, required this.value});

  /// 参数键。
  final String key;

  /// 参数值。
  final String value;
}
