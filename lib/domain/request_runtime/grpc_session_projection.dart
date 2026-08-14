// 由执行边界暴露的安全、只读 gRPC 调用值。
export 'package:sendreq/domain/grpc/grpc_call_registry.dart'
    show GrpcCallEvent, GrpcCallSnapshot;
export 'package:sendreq/domain/grpc/grpc_call_registry.dart'
    show GrpcCallCommand;
export 'package:sendreq/domain/grpc/grpc_transport.dart'
    show GrpcCallConfiguration, GrpcTransportEventKind;
export 'package:sendreq/domain/grpc/grpc_rpc_shape.dart'
    show GrpcRpcShape, GrpcSchemaSource;
export 'package:sendreq/domain/grpc/protobuf_dynamic_codec.dart'
    show ProtobufDecodeResult;
