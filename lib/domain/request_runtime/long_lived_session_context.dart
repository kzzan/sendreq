import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/grpc/grpc_rpc_shape.dart';

/// 建立长连接时固定的、可安全展示的配置上下文。
///
/// 该对象绝不保存已解析的 URL 查询 Secret、认证值或 metadata；它仅用于
/// 让用户判断当前会话属于哪个环境及其认证来源。
class LongLivedSessionContext {
  const LongLivedSessionContext({
    required this.environmentName,
    required this.authenticationLabel,
    required this.authenticationType,
    required this.authenticationSource,
  });

  const LongLivedSessionContext.unbound()
    : environmentName = 'No environment',
      authenticationLabel = 'No authentication',
      authenticationType = RequestAuthenticationType.none,
      authenticationSource = RequestAuthenticationSource.request;

  final String environmentName;
  final String authenticationLabel;

  /// 结构化认证类型；错误处理不得依赖展示标签推断类型。
  final RequestAuthenticationType authenticationType;

  /// 凭据归属于活动环境还是请求自身。
  final RequestAuthenticationSource authenticationSource;
}

/// 启动 gRPC 调用时冻结的安全配置摘要。
class GrpcSessionContextSnapshot extends LongLivedSessionContext {
  const GrpcSessionContextSnapshot({
    required super.environmentName,
    required super.authenticationLabel,
    required super.authenticationType,
    required super.authenticationSource,
    this.environmentId,
    required this.redactedEndpoint,
    required this.schemaSource,
    required this.serviceName,
    required this.methodName,
    required this.rpcShape,
    required this.useTls,
    this.deadlineMs,
    this.metadataKeys = const [],
  });

  const GrpcSessionContextSnapshot.unbound()
    : environmentId = null,
      redactedEndpoint = null,
      schemaSource = GrpcSchemaSource.proto,
      serviceName = null,
      methodName = null,
      rpcShape = GrpcRpcShape.unary,
      useTls = true,
      deadlineMs = null,
      metadataKeys = const [],
      super.unbound();

  factory GrpcSessionContextSnapshot.from(LongLivedSessionContext context) =>
      GrpcSessionContextSnapshot(
        environmentName: context.environmentName,
        authenticationLabel: context.authenticationLabel,
        authenticationType: context.authenticationType,
        authenticationSource: context.authenticationSource,
        redactedEndpoint: null,
        schemaSource: GrpcSchemaSource.proto,
        serviceName: null,
        methodName: null,
        rpcShape: GrpcRpcShape.unary,
        useTls: true,
      );

  final String? environmentId;
  final String? redactedEndpoint;
  final GrpcSchemaSource schemaSource;
  final String? serviceName;
  final String? methodName;
  final GrpcRpcShape rpcShape;
  final bool useTls;
  final int? deadlineMs;
  final List<String> metadataKeys;
}
