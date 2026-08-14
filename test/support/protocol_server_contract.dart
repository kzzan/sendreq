import 'dart:io';

import 'package:sendreq/domain/authentication/request_authentication.dart';

enum ProtocolCredentialKind { none, environmentBearer, basic, apiKey }

class WebSocketServerContract {
  const WebSocketServerContract({
    required this.requestId,
    required this.path,
    required this.credential,
  });

  final String requestId;
  final String path;
  final ProtocolCredentialKind credential;
}

class GrpcServerContract {
  const GrpcServerContract({
    required this.requestId,
    required this.methodName,
    required this.credential,
    required this.clientStreaming,
    required this.serverStreaming,
  });

  final String requestId;
  final String methodName;
  final ProtocolCredentialKind credential;
  final bool clientStreaming;
  final bool serverStreaming;
}

abstract final class ProtocolServerContract {
  static const webSocketEndpoint = 'ws://127.0.0.1:8080';
  static const grpcEndpoint = 'http://127.0.0.1:50051';
  static const grpcService = '.order.v1.OrderService';
  static const protoAsset = 'asset://assets/demo/order.proto';

  static const basicUsername = 'sendreq';
  static const basicPassword = 'basic-demo-password';
  static const apiKeyHeader = 'X-API-Key';
  static const apiKeyValue = 'sendreq-local-api-key';
  static const defaultBearerToken =
      'reurl_fca7a7c2b59c650b51de801789108dc7dc2abb7bbd58ff7f';

  static String get bearerToken =>
      Platform.environment['SENDREQ_PROTOCOL_TOKEN'] ?? defaultBearerToken;

  static const webSockets = [
    WebSocketServerContract(
      requestId: 'demo-websocket-echo',
      path: '/ws',
      credential: ProtocolCredentialKind.environmentBearer,
    ),
    WebSocketServerContract(
      requestId: 'demo-websocket-basic-echo',
      path: '/ws/basic',
      credential: ProtocolCredentialKind.basic,
    ),
    WebSocketServerContract(
      requestId: 'demo-websocket-api-key-echo',
      path: '/ws/api-key',
      credential: ProtocolCredentialKind.apiKey,
    ),
    WebSocketServerContract(
      requestId: 'demo-websocket-open-echo',
      path: '/ws/open',
      credential: ProtocolCredentialKind.none,
    ),
  ];

  static const grpcs = [
    GrpcServerContract(
      requestId: 'demo-grpc-create-order',
      methodName: 'CreateOrder',
      credential: ProtocolCredentialKind.none,
      clientStreaming: false,
      serverStreaming: false,
    ),
    GrpcServerContract(
      requestId: 'demo-grpc-get-order',
      methodName: 'GetOrder',
      credential: ProtocolCredentialKind.apiKey,
      clientStreaming: false,
      serverStreaming: false,
    ),
    GrpcServerContract(
      requestId: 'demo-grpc-submit-orders',
      methodName: 'SubmitOrders',
      credential: ProtocolCredentialKind.basic,
      clientStreaming: true,
      serverStreaming: false,
    ),
    GrpcServerContract(
      requestId: 'demo-grpc-order-chat',
      methodName: 'Chat',
      credential: ProtocolCredentialKind.environmentBearer,
      clientStreaming: true,
      serverStreaming: true,
    ),
    GrpcServerContract(
      requestId: 'demo-grpc-watch-orders',
      methodName: 'WatchOrders',
      credential: ProtocolCredentialKind.environmentBearer,
      clientStreaming: false,
      serverStreaming: true,
    ),
  ];

  static RequestAuthentication authenticationFor(
    ProtocolCredentialKind credential,
  ) => switch (credential) {
    ProtocolCredentialKind.none || ProtocolCredentialKind.environmentBearer =>
      const RequestAuthentication.none(),
    ProtocolCredentialKind.basic => const RequestAuthentication.basic(
      username: basicUsername,
      password: basicPassword,
    ),
    ProtocolCredentialKind.apiKey => const RequestAuthentication.apiKey(
      apiKeyName: apiKeyHeader,
      apiKeyValue: apiKeyValue,
      apiKeyLocation: ApiKeyLocation.header,
    ),
  };
}
