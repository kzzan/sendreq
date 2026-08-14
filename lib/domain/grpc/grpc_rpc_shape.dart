/// gRPC schema 的获取方式。
enum GrpcSchemaSource {
  proto('proto'),
  reflection('reflection');

  const GrpcSchemaSource(this.storageValue);

  final String storageValue;

  static GrpcSchemaSource fromStorageValue(Object? value) => switch (value) {
    'reflection' => GrpcSchemaSource.reflection,
    _ => GrpcSchemaSource.proto,
  };
}

/// RPC 的请求与响应流形。
enum GrpcRpcShape {
  unary('unary', hasClientStream: false, hasServerStream: false),
  clientStreaming(
    'clientStreaming',
    hasClientStream: true,
    hasServerStream: false,
  ),
  serverStreaming(
    'serverStreaming',
    hasClientStream: false,
    hasServerStream: true,
  ),
  bidirectionalStreaming(
    'bidirectionalStreaming',
    hasClientStream: true,
    hasServerStream: true,
  );

  const GrpcRpcShape(
    this.storageValue, {
    required this.hasClientStream,
    required this.hasServerStream,
  });

  final String storageValue;
  final bool hasClientStream;
  final bool hasServerStream;

  static GrpcRpcShape fromStreamingFlags({
    required bool clientStreaming,
    required bool serverStreaming,
  }) => switch ((clientStreaming, serverStreaming)) {
    (true, true) => GrpcRpcShape.bidirectionalStreaming,
    (true, false) => GrpcRpcShape.clientStreaming,
    (false, true) => GrpcRpcShape.serverStreaming,
    (false, false) => GrpcRpcShape.unary,
  };

  static GrpcRpcShape fromStorageValue(
    Object? value, {
    bool legacyClientStreaming = false,
    bool legacyServerStreaming = false,
  }) => switch (value) {
    'clientStreaming' => GrpcRpcShape.clientStreaming,
    'serverStreaming' => GrpcRpcShape.serverStreaming,
    'bidirectionalStreaming' => GrpcRpcShape.bidirectionalStreaming,
    'unary' => GrpcRpcShape.unary,
    _ => fromStreamingFlags(
      clientStreaming: legacyClientStreaming,
      serverStreaming: legacyServerStreaming,
    ),
  };
}
