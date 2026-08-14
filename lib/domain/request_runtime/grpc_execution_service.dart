import 'dart:async';
import 'dart:typed_data';

import 'package:sendreq/domain/grpc/protobuf_codec.dart';
import 'package:sendreq/domain/grpc/grpc_call_registry.dart';
import 'package:sendreq/domain/grpc/grpc_transport.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';

/// 执行层拥有的 gRPC 调用生命周期操作门面。
class GrpcExecutionService implements GrpcExecutionPort {
  GrpcExecutionService(GrpcTransport transport) {
    _transport = transport;
    _registry = GrpcCallRegistry(transport, onChanged: _emitChange);
  }

  late final GrpcTransport _transport;
  late final GrpcCallRegistry _registry;
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  @override
  Stream<void> get changes => _changes.stream;

  void _emitChange() => _changes.add(null);

  @override
  GrpcCallSnapshot call(RequestRef requestRef) =>
      _registry.callFor(requestRef.id);

  @override
  Iterable<GrpcCallSnapshot> get calls => _registry.calls;

  @override
  String? validateMessage(
    ProtobufDescriptorSet descriptors,
    String messageType,
    String source,
  ) => ProtobufDynamicCodec(descriptors).validateJson(messageType, source);

  @override
  Uint8List encodeMessage(
    ProtobufDescriptorSet descriptors,
    String messageType,
    String source,
  ) => ProtobufDynamicCodec(descriptors).encodeJson(messageType, source);

  @override
  ProtobufDecodeResult decodeMessage(
    ProtobufDescriptorSet descriptors,
    String messageType,
    Uint8List bytes,
  ) => ProtobufDynamicCodec(descriptors).tryDecodeJson(messageType, bytes);

  @override
  Future<ProtobufDescriptorSet> discoverServices(
    GrpcReflectionConfiguration configuration,
  ) async {
    if (_transport is! GrpcReflectionTransport) {
      throw UnsupportedError('Server reflection is unavailable.');
    }
    final reflectionTransport = _transport as GrpcReflectionTransport;
    final bytes = await reflectionTransport.discover(configuration);
    return ProtobufDescriptorSet.parse(bytes);
  }

  @override
  Future<void> start({
    required RequestRef requestRef,
    required GrpcCallConfiguration configuration,
  }) => _registry.start(requestId: requestRef.id, configuration: configuration);

  @override
  Future<void> send({
    required RequestRef requestRef,
    required Uint8List message,
  }) => _registry.send(requestId: requestRef.id, message: message);

  @override
  Future<void> closeRequestStream(RequestRef requestRef) =>
      _registry.closeRequestStream(requestRef.id);

  @override
  Future<void> cancel(RequestRef requestRef) => _registry.cancel(requestRef.id);

  @override
  void markConfigurationChanged([RequestRef? requestRef]) =>
      _registry.markConfigurationChanged(requestRef?.id);

  @override
  Future<void> disposeRequest(RequestRef requestRef) =>
      _registry.disposeRequest(requestRef.id);

  @override
  Future<void> dispose() async {
    await _registry.dispose();
    await _changes.close();
  }
}
