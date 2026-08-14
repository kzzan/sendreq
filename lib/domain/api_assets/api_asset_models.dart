import 'dart:convert';

import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/grpc/grpc_rpc_shape.dart';

/// 请求使用的网络协议。
enum ApiRequestProtocol {
  /// HTTP(S) 协议。
  http('http'),

  /// WebSocket 协议。
  webSocket('websocket'),

  /// gRPC 协议。
  grpc('grpc');

  /// 构造并绑定持久化值。
  const ApiRequestProtocol(this.storageValue);

  /// 持久化时使用的字符串值。
  final String storageValue;

  /// 从存储值还原协议，未知值回退为 HTTP。
  static ApiRequestProtocol fromStorageValue(Object? value) => switch (value) {
    'websocket' => ApiRequestProtocol.webSocket,
    'grpc' => ApiRequestProtocol.grpc,
    _ => ApiRequestProtocol.http,
  };
}

/// 对 protobuf 模式文件的引用。
class ProtobufSchemaReference {
  /// 构建一个 protobuf 模式引用。
  const ProtobufSchemaReference({
    required this.path,
    required this.fingerprint,
    this.messageType,
  });

  /// 模式文件路径。
  final String path;

  /// 文件指纹，用于检测内容是否变更。
  final String fingerprint;

  /// 可选的消息类型名。
  final String? messageType;

  /// 复制并部分更新引用。
  ProtobufSchemaReference copyWith({
    String? path,
    String? fingerprint,
    String? messageType,
    bool clearMessageType = false,
  }) => ProtobufSchemaReference(
    path: path ?? this.path,
    fingerprint: fingerprint ?? this.fingerprint,
    // clearMessageType 为 true 时显式清空消息类型。
    messageType: clearMessageType ? null : messageType ?? this.messageType,
  );

  /// 序列化为 JSON。
  Map<String, Object?> toJson() => {
    'path': path,
    'fingerprint': fingerprint,
    'messageType': messageType,
  };

  /// 从 JSON 还原引用。
  factory ProtobufSchemaReference.fromJson(Map<String, dynamic> json) =>
      ProtobufSchemaReference(
        path: json['path'] as String,
        fingerprint: json['fingerprint'] as String,
        messageType: json['messageType'] as String?,
      );
}

/// WebSocket 请求的连接配置。
class WebSocketRequestConfiguration {
  /// 构建 WebSocket 连接配置。
  const WebSocketRequestConfiguration({
    this.subprotocols = const [],
    this.protobufSchema,
  });

  /// 子协议列表。
  final List<String> subprotocols;

  /// 可选的 protobuf 模式引用。
  final ProtobufSchemaReference? protobufSchema;

  /// 复制并部分更新配置。
  WebSocketRequestConfiguration copyWith({
    List<String>? subprotocols,
    ProtobufSchemaReference? protobufSchema,
    bool clearProtobufSchema = false,
  }) => WebSocketRequestConfiguration(
    subprotocols: subprotocols ?? this.subprotocols,
    // clearProtobufSchema 为 true 时显式清空 protobuf 配置。
    protobufSchema: clearProtobufSchema
        ? null
        : protobufSchema ?? this.protobufSchema,
  );

  /// 序列化为 JSON。
  Map<String, Object?> toJson() => {
    'subprotocols': subprotocols,
    'protobufSchema': protobufSchema?.toJson(),
  };

  /// 从 JSON 还原配置。
  factory WebSocketRequestConfiguration.fromJson(Map<String, dynamic> json) =>
      WebSocketRequestConfiguration(
        subprotocols: (json['subprotocols'] as List<dynamic>? ?? const [])
            .cast<String>(),
        // protobufSchema 缺失时回退为空配置。
        protobufSchema: switch (json['protobufSchema']) {
          final Map value => ProtobufSchemaReference.fromJson(
            Map<String, dynamic>.from(value),
          ),
          _ => null,
        },
      );
}

/// gRPC 请求的本地 schema 与调用配置。
class GrpcRequestConfiguration {
  /// 构建 gRPC 调用配置。
  const GrpcRequestConfiguration({
    this.protoSchema,
    this.serviceName,
    this.methodName,
    this.useTls = true,
    GrpcRpcShape? rpcShape,
    bool clientStreaming = false,
    bool serverStreaming = false,
    this.deadlineMs = '',
    GrpcSchemaSource? schemaSource,
    bool useReflection = false,
  }) : rpcShape =
           rpcShape ??
           (clientStreaming
               ? (serverStreaming
                     ? GrpcRpcShape.bidirectionalStreaming
                     : GrpcRpcShape.clientStreaming)
               : (serverStreaming
                     ? GrpcRpcShape.serverStreaming
                     : GrpcRpcShape.unary)),
       schemaSource =
           schemaSource ??
           (useReflection
               ? GrpcSchemaSource.reflection
               : GrpcSchemaSource.proto);

  /// 本地 `.proto` schema 引用；只保存路径与指纹，不保存源文件内容。
  final ProtobufSchemaReference? protoSchema;

  /// 用户选择的完整服务名。
  final String? serviceName;

  /// 用户选择的 RPC 方法名。
  final String? methodName;

  /// 是否通过 TLS 建立 gRPC HTTP/2 连接。
  final bool useTls;

  /// 选定方法的请求与响应流形。
  final GrpcRpcShape rpcShape;

  /// 可选的请求 deadline（毫秒）输入。保留原始草稿以便在调用前准确提示格式错误。
  final String deadlineMs;

  /// schema 来自本地 Proto 或 server reflection。
  final GrpcSchemaSource schemaSource;

  bool get useReflection => schemaSource == GrpcSchemaSource.reflection;
  bool get clientStreaming => rpcShape.hasClientStream;
  bool get serverStreaming => rpcShape.hasServerStream;

  /// 复制并部分更新配置。
  GrpcRequestConfiguration copyWith({
    ProtobufSchemaReference? protoSchema,
    bool clearProtoSchema = false,
    String? serviceName,
    bool clearServiceName = false,
    String? methodName,
    bool clearMethodName = false,
    bool? useTls,
    GrpcRpcShape? rpcShape,
    bool? clientStreaming,
    bool? serverStreaming,
    String? deadlineMs,
    GrpcSchemaSource? schemaSource,
    bool? useReflection,
  }) => GrpcRequestConfiguration(
    protoSchema: clearProtoSchema ? null : protoSchema ?? this.protoSchema,
    serviceName: clearServiceName ? null : serviceName ?? this.serviceName,
    methodName: clearMethodName ? null : methodName ?? this.methodName,
    useTls: useTls ?? this.useTls,
    rpcShape:
        rpcShape ??
        ((clientStreaming != null || serverStreaming != null)
            ? GrpcRpcShape.fromStreamingFlags(
                clientStreaming: clientStreaming ?? this.clientStreaming,
                serverStreaming: serverStreaming ?? this.serverStreaming,
              )
            : this.rpcShape),
    deadlineMs: deadlineMs ?? this.deadlineMs,
    schemaSource:
        schemaSource ??
        (useReflection == null
            ? this.schemaSource
            : useReflection
            ? GrpcSchemaSource.reflection
            : GrpcSchemaSource.proto),
  );

  /// 序列化为持久化 JSON。
  Map<String, Object?> toJson() => {
    'protoSchema': protoSchema?.toJson(),
    'serviceName': serviceName,
    'methodName': methodName,
    'useTls': useTls,
    'rpcShape': rpcShape.storageValue,
    'deadlineMs': deadlineMs,
    'schemaSource': schemaSource.storageValue,
  };

  /// 从 JSON 还原配置；缺失字段回退到安全默认值。
  factory GrpcRequestConfiguration.fromJson(Map<String, dynamic> json) =>
      GrpcRequestConfiguration(
        protoSchema: switch (json['protoSchema']) {
          final Map value => ProtobufSchemaReference.fromJson(
            Map<String, dynamic>.from(value),
          ),
          _ => null,
        },
        serviceName: json['serviceName'] as String?,
        methodName: json['methodName'] as String?,
        useTls: json['useTls'] as bool? ?? true,
        rpcShape: GrpcRpcShape.fromStorageValue(
          json['rpcShape'],
          legacyClientStreaming: json['clientStreaming'] as bool? ?? false,
          legacyServerStreaming: json['serverStreaming'] as bool? ?? false,
        ),
        deadlineMs: json['deadlineMs']?.toString() ?? '',
        schemaSource: json.containsKey('schemaSource')
            ? GrpcSchemaSource.fromStorageValue(json['schemaSource'])
            : (json['useReflection'] as bool? ?? false)
            ? GrpcSchemaSource.reflection
            : GrpcSchemaSource.proto,
      );
}

/// API 请求中的键值字段（查询参数/请求头/表单字段）。
class ApiField {
  /// 构建一个 API 键值字段。
  const ApiField({
    required this.key,
    required this.value,
    this.enabled = true,
    this.secretReference = false,
  });

  /// 字段名。
  final String key;

  /// 字段值。
  final String value;

  /// 是否启用。
  final bool enabled;

  /// 是否引用密钥（占位符形式）。
  final bool secretReference;

  /// 序列化为 JSON。
  Map<String, Object> toJson() => {
    'key': key,
    'value': value,
    'enabled': enabled,
    'secretReference': secretReference,
  };

  /// 从 JSON 还原字段。
  factory ApiField.fromJson(Map<String, dynamic> json) => ApiField(
    key: json['key'] as String,
    value: json['value'] as String,
    enabled: json['enabled'] as bool? ?? true,
    secretReference: json['secretReference'] as bool? ?? false,
  );
}

/// API 请求中的文件字段。
class ApiFileField {
  /// 构建一个文件字段。
  const ApiFileField({
    required this.key,
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    this.enabled = true,
  });

  /// 表单字段名。
  final String key;

  /// 本地文件路径。
  final String path;

  /// 原始文件名。
  final String fileName;

  /// 文件大小（字节）。
  final int sizeBytes;

  /// 是否启用。
  final bool enabled;

  /// 序列化为 JSON。
  Map<String, Object> toJson() => {
    'key': key,
    'path': path,
    'fileName': fileName,
    'sizeBytes': sizeBytes,
    'enabled': enabled,
  };

  /// 从 JSON 还原文件字段。
  factory ApiFileField.fromJson(Map<String, dynamic> json) => ApiFileField(
    key: json['key'] as String,
    path: json['path'] as String,
    fileName: json['fileName'] as String,
    sizeBytes: (json['sizeBytes'] as num).toInt(),
    enabled: json['enabled'] as bool? ?? true,
  );
}

/// 持久化的请求定义，包含 URL 模板与完整请求配置。
class ApiRequestDefinition {
  /// 构建请求定义。
  const ApiRequestDefinition({
    required this.id,
    required this.collectionId,
    required this.folderId,
    required this.name,
    required this.method,
    required this.urlTemplate,
    required this.queryParams,
    required this.headers,
    required this.bodyTemplate,
    this.authentication = const RequestAuthentication.none(),
    this.authenticationSource = RequestAuthenticationSource.environment,
    this.protocol = ApiRequestProtocol.http,
    this.webSocket = const WebSocketRequestConfiguration(),
    this.grpc = const GrpcRequestConfiguration(),
    this.formUrlEncodedFields = const [],
    this.multipartFields = const [],
    this.multipartFiles = const [],
    this.metadata = const {},
  });

  /// 请求唯一标识。
  final String id;

  /// 所属集合 id。
  final String collectionId;

  /// 所属文件夹 id。
  final String folderId;

  /// 请求名称。
  final String name;

  /// HTTP 方法。
  final String method;

  /// URL 模板（可含变量占位符）。
  final String urlTemplate;

  /// 查询参数。
  final List<ApiField> queryParams;

  /// 请求头。
  final List<ApiField> headers;

  /// 请求体模板。
  final String bodyTemplate;

  /// 独立的认证配置；运行时将其合成为认证头。
  final RequestAuthentication authentication;

  /// 请求可继承环境认证，或改用自身的独立认证配置。
  final RequestAuthenticationSource authenticationSource;

  /// 协议类型。
  final ApiRequestProtocol protocol;

  /// WebSocket 连接配置。
  final WebSocketRequestConfiguration webSocket;

  /// gRPC 调用配置。
  final GrpcRequestConfiguration grpc;

  /// application/x-www-form-urlencoded 表单字段。
  final List<ApiField> formUrlEncodedFields;

  /// multipart 表单字段。
  final List<ApiField> multipartFields;

  /// multipart 文件字段。
  final List<ApiFileField> multipartFiles;

  /// 附加元数据。
  final Map<String, String> metadata;

  /// 复制并部分更新请求定义。
  ApiRequestDefinition copyWith({
    String? id,
    String? collectionId,
    String? folderId,
    String? name,
    String? method,
    String? urlTemplate,
    List<ApiField>? queryParams,
    List<ApiField>? headers,
    String? bodyTemplate,
    RequestAuthentication? authentication,
    RequestAuthenticationSource? authenticationSource,
    ApiRequestProtocol? protocol,
    WebSocketRequestConfiguration? webSocket,
    GrpcRequestConfiguration? grpc,
    List<ApiField>? formUrlEncodedFields,
    List<ApiField>? multipartFields,
    List<ApiFileField>? multipartFiles,
    Map<String, String>? metadata,
  }) => ApiRequestDefinition(
    id: id ?? this.id,
    collectionId: collectionId ?? this.collectionId,
    folderId: folderId ?? this.folderId,
    name: name ?? this.name,
    method: method ?? this.method,
    urlTemplate: urlTemplate ?? this.urlTemplate,
    queryParams: queryParams ?? this.queryParams,
    headers: headers ?? this.headers,
    bodyTemplate: bodyTemplate ?? this.bodyTemplate,
    authentication: authentication ?? this.authentication,
    authenticationSource: authenticationSource ?? this.authenticationSource,
    protocol: protocol ?? this.protocol,
    webSocket: webSocket ?? this.webSocket,
    grpc: grpc ?? this.grpc,
    formUrlEncodedFields: formUrlEncodedFields ?? this.formUrlEncodedFields,
    multipartFields: multipartFields ?? this.multipartFields,
    multipartFiles: multipartFiles ?? this.multipartFiles,
    metadata: metadata ?? this.metadata,
  );

  /// 序列化为 JSON 映射。
  Map<String, Object> toJson() => {
    'id': id,
    'collectionId': collectionId,
    'folderId': folderId,
    'name': name,
    'method': method,
    'urlTemplate': urlTemplate,
    'queryParams': queryParams.map((field) => field.toJson()).toList(),
    'headers': headers.map((field) => field.toJson()).toList(),
    'bodyTemplate': bodyTemplate,
    'authentication': authentication.toJson(),
    'authenticationSource': authenticationSource.storageValue,
    'protocol': protocol.storageValue,
    'webSocket': webSocket.toJson(),
    'grpc': grpc.toJson(),
    'formUrlEncodedFields': formUrlEncodedFields
        .map((field) => field.toJson())
        .toList(),
    'multipartFields': multipartFields.map((field) => field.toJson()).toList(),
    'multipartFiles': multipartFiles.map((file) => file.toJson()).toList(),
    'metadata': metadata,
  };

  /// 编码为 JSON 字符串。
  String encodeJson() => jsonEncode(toJson());

  /// 从 JSON 字符串解码请求定义。
  factory ApiRequestDefinition.decodeJson(String source) =>
      ApiRequestDefinition.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// 从 JSON 映射还原请求定义。
  factory ApiRequestDefinition.fromJson(Map<String, dynamic> json) =>
      ApiRequestDefinition(
        id: json['id'] as String,
        collectionId: json['collectionId'] as String,
        folderId: json['folderId'] as String,
        name: json['name'] as String,
        method: json['method'] as String,
        urlTemplate: json['urlTemplate'] as String,
        queryParams: (json['queryParams'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(ApiField.fromJson)
            .toList(growable: false),
        headers: (json['headers'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(ApiField.fromJson)
            .toList(growable: false),
        bodyTemplate: json['bodyTemplate'] as String,
        authentication: switch (json['authentication']) {
          final Map value => RequestAuthentication.fromJson(
            Map<String, dynamic>.from(value),
          ),
          _ => const RequestAuthentication.none(),
        },
        // 旧版本数据缺少该字段时回退为请求自带认证。
        authenticationSource: json.containsKey('authenticationSource')
            ? RequestAuthenticationSource.fromStorageValue(
                json['authenticationSource'],
              )
            : RequestAuthenticationSource.request,
        protocol: ApiRequestProtocol.fromStorageValue(json['protocol']),
        // webSocket 配置缺失时回退为空配置。
        webSocket: switch (json['webSocket']) {
          final Map value => WebSocketRequestConfiguration.fromJson(
            Map<String, dynamic>.from(value),
          ),
          _ => const WebSocketRequestConfiguration(),
        },
        grpc: switch (json['grpc']) {
          final Map value => GrpcRequestConfiguration.fromJson(
            Map<String, dynamic>.from(value),
          ),
          _ => const GrpcRequestConfiguration(),
        },
        formUrlEncodedFields:
            (json['formUrlEncodedFields'] as List<dynamic>? ??
                    const <dynamic>[])
                .cast<Map<String, dynamic>>()
                .map(ApiField.fromJson)
                .toList(growable: false),
        multipartFields:
            (json['multipartFields'] as List<dynamic>? ?? const <dynamic>[])
                .cast<Map<String, dynamic>>()
                .map(ApiField.fromJson)
                .toList(growable: false),
        multipartFiles:
            (json['multipartFiles'] as List<dynamic>? ?? const <dynamic>[])
                .cast<Map<String, dynamic>>()
                .map(ApiFileField.fromJson)
                .toList(growable: false),
        metadata: Map<String, String>.from(json['metadata'] as Map),
      );
}

/// 请求文件夹。
class ApiFolder {
  /// 构建请求文件夹。
  const ApiFolder({
    required this.id,
    required this.name,
    required this.requests,
  });

  /// 文件夹唯一标识。
  final String id;

  /// 文件夹名称。
  final String name;

  /// 文件夹内的请求列表。
  final List<ApiRequestDefinition> requests;

  /// 复制并部分更新文件夹。
  ApiFolder copyWith({
    String? id,
    String? name,
    List<ApiRequestDefinition>? requests,
  }) => ApiFolder(
    id: id ?? this.id,
    name: name ?? this.name,
    requests: requests ?? this.requests,
  );

  /// 序列化为 JSON。
  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'requests': requests.map((request) => request.toJson()).toList(),
  };

  /// 从 JSON 还原文件夹。
  factory ApiFolder.fromJson(Map<String, dynamic> json) => ApiFolder(
    id: json['id'] as String,
    name: json['name'] as String,
    requests: (json['requests'] as List<dynamic>)
        .map(
          (value) => ApiRequestDefinition.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(growable: false),
  );
}

/// 请求集合（顶级容器）。
class ApiCollection {
  /// 构建请求集合。
  const ApiCollection({
    required this.id,
    required this.name,
    required this.folders,
  });

  /// 集合唯一标识。
  final String id;

  /// 集合名称。
  final String name;

  /// 集合内的文件夹列表。
  final List<ApiFolder> folders;

  /// 复制并部分更新集合。
  ApiCollection copyWith({
    String? id,
    String? name,
    List<ApiFolder>? folders,
  }) => ApiCollection(
    id: id ?? this.id,
    name: name ?? this.name,
    folders: folders ?? this.folders,
  );

  /// 序列化为 JSON。
  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'folders': folders.map((folder) => folder.toJson()).toList(),
  };

  /// 从 JSON 还原集合。
  factory ApiCollection.fromJson(Map<String, dynamic> json) => ApiCollection(
    id: json['id'] as String,
    name: json['name'] as String,
    folders: (json['folders'] as List<dynamic>)
        .map(
          (value) =>
              ApiFolder.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(growable: false),
  );
}

/// 请求编辑标签页。
class RequestTab {
  /// 构建请求标签页。
  const RequestTab({
    required this.id,
    required this.requestId,
    required this.title,
    required this.openedAt,
    this.isDirty = false,
  });

  /// 标签页唯一标识。
  final String id;

  /// 关联的请求定义 id。
  final String requestId;

  /// 标签页标题。
  final String title;

  /// 打开时间。
  final DateTime openedAt;

  /// 是否有未保存的修改。
  final bool isDirty;

  /// 序列化为 JSON。
  Map<String, Object> toJson() => {
    'id': id,
    'requestId': requestId,
    'title': title,
    'openedAt': openedAt.toUtc().toIso8601String(),
    'isDirty': isDirty,
  };

  /// 从 JSON 还原标签页。
  factory RequestTab.fromJson(Map<String, dynamic> json) => RequestTab(
    id: json['id'] as String,
    requestId: json['requestId'] as String,
    title: json['title'] as String,
    openedAt: DateTime.parse(json['openedAt'] as String).toUtc(),
    isDirty: json['isDirty'] as bool? ?? false,
  );
}
