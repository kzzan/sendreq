import 'dart:async';
import 'dart:typed_data';

import 'package:sendreq/domain/grpc/protobuf_codec.dart';
import 'package:sendreq/domain/grpc/grpc_transport.dart'
    show GrpcReflectionConfiguration;
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/request_runtime/long_lived_session_context.dart';
import 'package:sendreq/domain/contract_publishing/mock_server.dart';
import 'package:sendreq/domain/request_runtime/grpc_session_projection.dart';
import 'package:sendreq/domain/request_runtime/websocket_session_projection.dart';

export 'package:sendreq/domain/api_assets/openapi_exchange.dart'
    show OpenApiOutputDirectoryPort;
export 'package:sendreq/domain/contract_publishing/mock_server.dart'
    show
        MockEndpoint,
        MockRequestMatcher,
        MockResponseVariant,
        MockRequestProjection,
        MockServer,
        MockServerLifecycle,
        MockServerLifecycleTransitions,
        MockServerMatching,
        MockServerProjection,
        MockServerRuntimePort,
        MockServerRuntimeProjection,
        MockServerRuntimeStatus,
        MockSourceKind,
        MockSourceReference,
        MockVariantMatcher;
export 'package:sendreq/domain/repositories/mock_server_repository.dart'
    show MockServerRepository;
export 'package:sendreq/domain/notifications/user_notice_repository.dart'
    show
        DurableNoticeSeverity,
        PersistentUserNotice,
        UserNoticeRepository,
        UserNoticeRetentionPolicy;
export 'package:sendreq/domain/grpc/protobuf_codec.dart'
    show
        ProtobufDecodeResult,
        ProtobufDescriptorSet,
        ProtobufEnumDescriptor,
        ProtobufFieldDescriptor,
        ProtobufMessageDescriptor,
        ProtobufMethodDescriptor,
        ProtobufServiceDescriptor;
export 'package:sendreq/domain/request_runtime/grpc_session_projection.dart'
    show
        GrpcCallConfiguration,
        GrpcCallCommand,
        GrpcCallEvent,
        GrpcCallSnapshot,
        GrpcRpcShape,
        GrpcSchemaSource,
        GrpcTransportEventKind;
export 'package:sendreq/domain/request_runtime/websocket_session_projection.dart'
    show WebSocketSession, WebSocketSessionException;

/// 请求执行前发送给 Environment 的意图。
class ResolveExecutionRequest {
  const ResolveExecutionRequest({
    required this.executionId,
    required this.requestRef,
    required this.draft,
    this.environmentRef,
  });

  final String executionId;
  final RequestRef requestRef;
  final RequestDraft draft;
  final ResourceRef? environmentRef;
}

/// 将模板与认证数据解析为仅用于执行的命令。
abstract interface class EnvironmentResolver {
  Future<ResolvedExecutionCommand> resolve(ResolveExecutionRequest request);
}

/// 由 Execution adapter 提供的 Protobuf schema 读取与解析能力。
///
/// Workspace 只保留已解析的描述符投影，不接触文件系统、Flutter asset 或解析器实现。
abstract interface class ProtobufSourcePort {
  Future<ProtobufDescriptorSet> parseSourceFile(String path);

  ProtobufDescriptorSet parseDescriptorSet(Uint8List bytes);

  Future<Uint8List> readBytes(String path);

  bool exists(String path);
}

/// 保存已净化的响应正文，并只将实际保存路径返回给 Shell。
abstract interface class ResponseBodyDownloadPort {
  Future<String> save(String body);
}

/// 拥有 HTTP 执行与长时间运行协议会话命令。
abstract interface class ExecutionService {
  Future<SanitizedExecutionResult> execute(ResolvedExecutionCommand command);

  Future<OperationOutcome> cancel(String executionId);

  Future<SanitizedSessionProjection?> session(String sessionId);

  Future<void> disposeRequestSessions(RequestRef requestRef);
}

/// 由执行运行时拥有的 WebSocket 会话的应用端口。
///
/// Workspace Shell 直接使用这些命令与安全投影，无需
/// 触及注册表或传输实现。
abstract interface class WebSocketExecutionPort {
  Stream<void> get changes;

  WebSocketSession session(RequestRef requestRef);

  Iterable<WebSocketSession> get sessions;

  Future<void> connect({
    required RequestRef requestRef,
    required Uri url,
    required Map<String, String> headers,
    required List<String> subprotocols,
    required RedactionPolicy redactionPolicy,
    required LongLivedSessionContext sessionContext,
  });

  Future<void> sendText(
    RequestRef requestRef,
    String value, {
    String? formatLabel,
  });

  Future<void> sendBinary(
    RequestRef requestRef,
    Uint8List value, {
    String? protobufMessageType,
    String? formatLabel,
  });

  Future<void> disconnect(RequestRef requestRef);

  void markConfigurationChanged([RequestRef? requestRef]);

  Future<void> disposeRequest(RequestRef requestRef);

  Future<void> dispose();
}

/// 由执行运行时拥有的 gRPC 调用的应用端口。
abstract interface class GrpcExecutionPort {
  Stream<void> get changes;

  GrpcCallSnapshot call(RequestRef requestRef);

  Iterable<GrpcCallSnapshot> get calls;

  String? validateMessage(
    ProtobufDescriptorSet descriptors,
    String messageType,
    String source,
  );

  Uint8List encodeMessage(
    ProtobufDescriptorSet descriptors,
    String messageType,
    String source,
  );

  ProtobufDecodeResult decodeMessage(
    ProtobufDescriptorSet descriptors,
    String messageType,
    Uint8List bytes,
  );

  Future<ProtobufDescriptorSet> discoverServices(
    GrpcReflectionConfiguration configuration,
  );

  Future<void> start({
    required RequestRef requestRef,
    required GrpcCallConfiguration configuration,
  });

  Future<void> send({
    required RequestRef requestRef,
    required Uint8List message,
  });

  Future<void> closeRequestStream(RequestRef requestRef);

  Future<void> cancel(RequestRef requestRef);

  void markConfigurationChanged([RequestRef? requestRef]);

  Future<void> disposeRequest(RequestRef requestRef);

  Future<void> dispose();
}

/// 拥有已保存 HTTP Mock Server 的 Contract Publishing 边界。
abstract interface class ContractPublishingService {
  /// 从已脱敏响应快照直接创建可复用的 HTTP Mock Server。
  Future<OperationOutcome> createMockServerFromSnapshot(
    SanitizedMockSourceSnapshot snapshot,
  );

  /// 已保存 Mock Server 的安全显示投影。运行时地址仅在运行期间可见。
  List<MockServerProjection> get mockServers;

  /// 从持久化仓储加载 Mock Server；失败通过结构化结果返回。
  Future<OperationOutcome> loadMockServers();

  /// 创建或更新一个已验证、已脱敏的本地 Mock Server 定义。
  Future<OperationOutcome> saveMockServer(MockServer server);

  /// 归档已保存 Server，归档资产不可启动但仍可恢复或删除。
  Future<OperationOutcome> archiveMockServer(ResourceRef mockServerRef);

  /// 删除已保存 Server，并停止其临时本地运行时。
  Future<OperationOutcome> deleteMockServer(ResourceRef mockServerRef);

  /// 显式启动一个已保存的 Server；绝不自动恢复监听器。
  Future<OperationOutcome> startMockServer(ResourceRef mockServerRef);

  /// 显式停止一个已保存 Server 的本地监听器。
  Future<OperationOutcome> stopMockServer(ResourceRef mockServerRef);

  Future<void> disposeSession();
}
