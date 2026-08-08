import '../api_assets/api_asset_models.dart';
import '../authentication/request_authentication.dart';

/// 工作区主导航分区。
enum WorkspaceSection {
  /// 仪表盘（指标概览）。
  dashboard,

  /// 请求集合。
  collections,

  /// 历史记录。
  history,

  /// 环境变量管理。
  environments,

  /// 本地 Mock 服务器。
  mockServers,

  /// API 文档。
  documentation,

  /// 应用设置。
  settings,
}

/// 侧栏请求列表中的请求条目描述。
class RequestResource {
  /// 构建侧栏请求条目。
  const RequestResource({
    required this.id,
    required this.method,
    required this.name,
    required this.path,
    required this.folder,
    this.protocol = ApiRequestProtocol.http,
    this.isDirty = false,
  });

  /// 唯一标识。
  final String id;

  /// HTTP 方法（GET/POST 等）。
  final String method;

  /// 显示名称。
  final String name;

  /// 请求路径。
  final String path;

  /// 所属文件夹名。
  final String folder;

  /// 请求协议（HTTP 或 WebSocket）。
  final ApiRequestProtocol protocol;

  /// 是否有未保存的修改。
  final bool isDirty;
}

/// 集合概览条目，用于侧栏树状展示。
class CollectionResource {
  /// 构建集合概览条目。
  const CollectionResource({
    required this.id,
    required this.name,
    required this.folders,
    this.isExpanded = true,
  });

  /// 唯一标识。
  final String id;

  /// 集合名称。
  final String name;

  /// 集合下的文件夹列表。
  final List<FolderResource> folders;

  /// 侧栏中是否默认展开。
  final bool isExpanded;

  /// 集合内请求总数（跨文件夹汇总）。
  int get requestCount =>
      folders.fold(0, (total, folder) => total + folder.requests.length);
}

/// 文件夹概览条目。
class FolderResource {
  /// 构建文件夹概览条目。
  const FolderResource({
    required this.id,
    required this.name,
    required this.requests,
    this.isExpanded = true,
  });

  /// 唯一标识。
  final String id;

  /// 文件夹名称。
  final String name;

  /// 文件夹内的请求列表。
  final List<RequestResource> requests;

  /// 侧栏中是否默认展开。
  final bool isExpanded;
}

/// 键值对行，用于查询参数、请求头、表单字段等场景。
class KeyValueRow {
  /// 构建一个键值行。
  const KeyValueRow({
    required this.keyName,
    required this.value,
    this.id = '',
    this.enabled = true,
    this.secret = false,
  });

  /// 键名。
  final String keyName;

  /// 值。
  final String value;

  /// 行唯一标识（用于编辑状态同步，可为空）。
  final String id;

  /// 是否启用该行。
  final bool enabled;

  /// 是否为敏感值（如密钥）。
  final bool secret;

  /// 复制并部分更新当前行。
  KeyValueRow copyWith({
    String? id,
    String? keyName,
    String? value,
    bool? enabled,
    bool? secret,
  }) => KeyValueRow(
    id: id ?? this.id,
    keyName: keyName ?? this.keyName,
    value: value ?? this.value,
    enabled: enabled ?? this.enabled,
    secret: secret ?? this.secret,
  );
}

/// multipart 文件字段行。
class MultipartFileRow {
  /// 构建一个 multipart 文件行。
  const MultipartFileRow({
    required this.id,
    required this.keyName,
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    this.enabled = true,
  });

  /// 行唯一标识。
  final String id;

  /// 表单字段名。
  final String keyName;

  /// 本地文件路径。
  final String path;

  /// 原始文件名。
  final String fileName;

  /// 文件大小（字节）。
  final int sizeBytes;

  /// 是否启用该文件字段。
  final bool enabled;

  /// 复制并部分更新文件名/启用状态。
  MultipartFileRow copyWith({String? keyName, bool? enabled}) =>
      MultipartFileRow(
        id: id,
        keyName: keyName ?? this.keyName,
        path: path,
        fileName: fileName,
        sizeBytes: sizeBytes,
        enabled: enabled ?? this.enabled,
      );
}

/// 请求编辑器当前的草稿（执行前的完整状态）。
class RequestDraft {
  /// 构建请求编辑器草稿。
  const RequestDraft({
    required this.method,
    required this.baseUrlToken,
    required this.path,
    required this.params,
    required this.headers,
    required this.body,
    this.authentication = const RequestAuthentication.none(),
    this.authenticationSource = RequestAuthenticationSource.environment,
    this.protocol = ApiRequestProtocol.http,
    this.webSocket = const WebSocketRequestConfiguration(),
    this.grpc = const GrpcRequestConfiguration(),
    this.multipartFields = const [],
    this.multipartFiles = const [],
  });

  /// HTTP 方法。
  final String method;

  /// base URL 的环境变量令牌（如 {{baseUrl}}）。
  final String baseUrlToken;

  /// 请求路径。
  final String path;

  /// 查询参数列表。
  final List<KeyValueRow> params;

  /// 请求头列表。
  final List<KeyValueRow> headers;

  /// 请求体文本。
  final String body;

  /// 独立的认证配置，不与用户自定义 Headers 混用。
  final RequestAuthentication authentication;

  /// 认证是继承当前环境，还是使用请求自身的独立配置。
  final RequestAuthenticationSource authenticationSource;

  /// 协议类型。
  final ApiRequestProtocol protocol;

  /// WebSocket 连接配置。
  final WebSocketRequestConfiguration webSocket;

  /// gRPC 调用配置。
  final GrpcRequestConfiguration grpc;

  /// multipart 表单字段。
  final List<KeyValueRow> multipartFields;

  /// multipart 文件字段。
  final List<MultipartFileRow> multipartFiles;

  /// 复制并部分更新草稿字段。
  RequestDraft copyWith({
    String? method,
    String? baseUrlToken,
    String? path,
    List<KeyValueRow>? params,
    List<KeyValueRow>? headers,
    String? body,
    RequestAuthentication? authentication,
    RequestAuthenticationSource? authenticationSource,
    ApiRequestProtocol? protocol,
    WebSocketRequestConfiguration? webSocket,
    GrpcRequestConfiguration? grpc,
    List<KeyValueRow>? multipartFields,
    List<MultipartFileRow>? multipartFiles,
  }) => RequestDraft(
    method: method ?? this.method,
    baseUrlToken: baseUrlToken ?? this.baseUrlToken,
    path: path ?? this.path,
    params: params ?? this.params,
    headers: headers ?? this.headers,
    body: body ?? this.body,
    authentication: authentication ?? this.authentication,
    authenticationSource: authenticationSource ?? this.authenticationSource,
    protocol: protocol ?? this.protocol,
    webSocket: webSocket ?? this.webSocket,
    grpc: grpc ?? this.grpc,
    multipartFields: multipartFields ?? this.multipartFields,
    multipartFiles: multipartFiles ?? this.multipartFiles,
  );
}

/// WebSocket 消息编辑器的编辑模式。
enum WebSocketComposerMode {
  /// 纯文本。
  text,

  /// JSON 文本。
  json,

  /// XML 文本。
  xml,

  /// MessagePack 二进制消息（Base64 输入）。
  messagePack,
}

/// WebSocket 编辑模式的展示标签。
extension WebSocketComposerModeLabel on WebSocketComposerMode {
  /// 返回对应编辑模式的英文标签。
  String get label => switch (this) {
    WebSocketComposerMode.text => 'Text',
    WebSocketComposerMode.json => 'JSON',
    WebSocketComposerMode.xml => 'XML',
    WebSocketComposerMode.messagePack => 'MessagePack',
  };

  /// 该格式对应的 WebSocket 帧类型。
  bool get isBinary => switch (this) {
    WebSocketComposerMode.messagePack => true,
    WebSocketComposerMode.text ||
    WebSocketComposerMode.json ||
    WebSocketComposerMode.xml => false,
  };

  /// MessagePack 由用户提供已编码的 Base64 字节。
  bool get requiresBase64 => isBinary;

  /// 文本格式可在一条 WebSocket 文本帧中直接发送。
  bool get isText => !isBinary;

  /// 对输入编辑器的简洁说明。
  String get inputHint => switch (this) {
    WebSocketComposerMode.text => 'Plain text message',
    WebSocketComposerMode.json => 'JSON object or value',
    WebSocketComposerMode.xml => 'XML document or fragment',
    WebSocketComposerMode.messagePack => 'Base64-encoded MessagePack bytes',
  };
}

/// 一条待发送的 WebSocket 消息草稿。
class WebSocketMessageDraft {
  /// 构建一条 WebSocket 消息草稿。
  const WebSocketMessageDraft({
    this.mode = WebSocketComposerMode.text,
    this.payload = '',
  });

  /// 编辑模式。
  final WebSocketComposerMode mode;

  /// 消息载荷文本。
  final String payload;

  /// 复制并部分更新消息草稿。
  WebSocketMessageDraft copyWith({
    WebSocketComposerMode? mode,
    String? payload,
  }) => WebSocketMessageDraft(
    mode: mode ?? this.mode,
    payload: payload ?? this.payload,
  );
}

/// 环境变量条目（含作用域标记）。
class EnvironmentVariable {
  /// 构建环境变量条目。
  const EnvironmentVariable({
    required this.scope,
    required this.keyName,
    required this.value,
    required this.type,
    this.secret = false,
  });

  /// 变量作用域（如全局或环境名）。
  final String scope;

  /// 变量名。
  final String keyName;

  /// 变量值。
  final String value;

  /// 值类型标识。
  final String type;

  /// 是否为敏感变量。
  final bool secret;
}

/// 一次请求响应的快照，用于历史记录与文档生成。
class ResponseSnapshot {
  /// 构建响应快照。
  const ResponseSnapshot({
    required this.statusCode,
    required this.timeMs,
    required this.sizeKb,
    required this.body,
    required this.headers,
  });

  /// 状态码。
  final int statusCode;

  /// 耗时（毫秒）。
  final int timeMs;

  /// 响应体大小（KB）。
  final double sizeKb;

  /// 响应体文本。
  final String body;

  /// 响应头列表。
  final List<KeyValueRow> headers;
}

/// 仪表盘指标项（标签 + 当前值 + 变化量）。
class MetricSummary {
  /// 构建指标项。
  const MetricSummary({
    required this.label,
    required this.value,
    required this.delta,
  });

  /// 指标名称。
  final String label;

  /// 当前值文本。
  final String value;

  /// 相对变化量文本。
  final String delta;
}

/// 已结束 WebSocket 会话的轻量本地摘要。
///
/// 仅保存连接元数据与计数，不保存任何消息载荷或二进制帧。
class WebSocketSessionHistorySummary {
  /// 构建一个已结束会话的安全摘要。
  const WebSocketSessionHistorySummary({
    required this.endpoint,
    required this.startedAt,
    required this.endedAt,
    required this.terminalStatus,
    required this.inboundMessageCount,
    required this.outboundMessageCount,
    this.errorMessage,
  });

  /// 已脱敏的 WebSocket 端点。
  final String endpoint;

  /// 会话开始时间（UTC）。
  final DateTime startedAt;

  /// 会话结束时间（UTC）。
  final DateTime endedAt;

  /// 最终状态：`closed` 或 `error`。
  final String terminalStatus;

  /// 收到的数据帧总数。
  final int inboundMessageCount;

  /// 发出的数据帧总数。
  final int outboundMessageCount;

  /// 已脱敏的终止错误；正常关闭时为空。
  final String? errorMessage;
}

/// 一次请求执行的完整记录（历史列表条目）。
class ExecutionRecord {
  /// 构建一次执行记录。
  const ExecutionRecord({
    this.id = '',
    this.requestId,
    required this.method,
    this.protocol = ApiRequestProtocol.http,
    required this.path,
    this.status,
    required this.timeMs,
    required this.when,
    this.requestSnapshot,
    this.response,
    this.errorCategory,
    this.errorMessage,
    this.webSocketSummary,
  });

  /// 记录唯一标识。
  final String id;

  /// 关联的请求资源 id。
  final String? requestId;

  /// 请求方法。
  final String method;

  /// 执行时的请求类型，用于在历史与 Dashboard 中准确呈现 gRPC/WebSocket。
  final ApiRequestProtocol protocol;

  /// 请求路径。
  final String path;

  /// 响应状态码（执行失败时为 null）。
  final int? status;

  /// 总耗时（毫秒）。
  final int timeMs;

  /// 执行时间文本。
  final String when;

  /// 执行时刻的请求快照。
  final ExecutionRequestSnapshot? requestSnapshot;

  /// 响应快照。
  final ResponseSnapshot? response;

  /// 错误类别（无错误时为 null）。
  final String? errorCategory;

  /// 错误信息（无错误时为 null）。
  final String? errorMessage;

  /// WebSocket 会话摘要；存在时该记录不包含 HTTP 请求/响应负载。
  final WebSocketSessionHistorySummary? webSocketSummary;

  /// 是否包含请求快照。
  bool get hasSnapshot => requestSnapshot != null;

  /// 是否为没有请求/响应负载的 WebSocket 会话历史。
  bool get isWebSocketSession => webSocketSummary != null;
}

/// 执行时刻的请求快照（URL 已解析、变量已替换）。
class ExecutionRequestSnapshot {
  /// 构建执行时刻的请求快照。
  const ExecutionRequestSnapshot({
    required this.method,
    this.protocol = ApiRequestProtocol.http,
    required this.resolvedUrl,
    required this.headers,
    required this.body,
    required this.environmentName,
  });

  /// 请求方法。
  final String method;

  /// 执行时的请求类型，保证响应回放不会把 gRPC/WebSocket 标成 HTTP 方法。
  final ApiRequestProtocol protocol;

  /// 解析后的完整 URL。
  final String resolvedUrl;

  /// 实际发送的请求头。
  final List<KeyValueRow> headers;

  /// 实际发送的请求体。
  final String body;

  /// 使用的环境名称。
  final String environmentName;
}

/// Mock 草稿的初始来源。
enum MockDraftSource {
  /// 用户从零配置的假响应。
  manual,

  /// 从一次已捕获的响应预填。
  response,
}

/// 本地 Mock 服务器规则的草稿。
class MockDraft {
  /// 构建 Mock 规则草稿。
  const MockDraft({
    required this.request,
    required this.response,
    this.source = MockDraftSource.response,
  });

  /// 请求快照。
  final ExecutionRequestSnapshot request;

  /// 响应快照。
  final ResponseSnapshot response;

  /// 草稿的初始来源；两种来源都可编辑并作为假响应返回。
  final MockDraftSource source;
}

/// 由一次执行生成 API 文档条目的草稿。
class DocumentationDraft {
  /// 构建文档条目草稿。
  const DocumentationDraft({
    required this.requestId,
    required this.request,
    required this.response,
  });

  /// 关联的请求资源 id。
  final String requestId;

  /// 请求快照。
  final ExecutionRequestSnapshot request;

  /// 响应快照。
  final ResponseSnapshot response;
}
