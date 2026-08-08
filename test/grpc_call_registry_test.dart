import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/domain/grpc/grpc_call_registry.dart';
import 'package:sendreq/domain/grpc/grpc_transport.dart';

void main() {
  test('registry bounds events and redacts metadata and errors', () async {
    final call = _TestGrpcCall();
    final registry = GrpcCallRegistry(
      _TestGrpcTransport(call),
      maxEventsPerCall: 2,
      maxRetainedBytesPerCall: 1024,
    );
    await registry.start(
      requestId: 'health',
      configuration: _configuration(redactedValues: const ['test-token']),
    );
    call.emit(
      const GrpcTransportEvent.headers({'authorization': 'Bearer test-token'}),
    );
    call.emit(GrpcTransportEvent.message(Uint8List.fromList([8, 1])));
    call.emit(const GrpcTransportEvent.error('test-token was rejected'));
    await Future<void>.delayed(Duration.zero);

    final snapshot = registry.callFor('health');
    expect(snapshot.state, GrpcCallState.error);
    expect(snapshot.headers['authorization'], 'Bearer ********');
    expect(snapshot.errorMessage, '******** was rejected');
    expect(snapshot.events, hasLength(2));
    expect(snapshot.omittedEventCount, 1);
    expect(snapshot.retainedByteCount, greaterThan(0));
  });

  test('registry cancels the request-specific active call', () async {
    final call = _TestGrpcCall();
    final registry = GrpcCallRegistry(_TestGrpcTransport(call));
    await registry.start(requestId: 'watch', configuration: _configuration());

    await registry.cancel('watch');

    expect(call.cancelled, isTrue);
    expect(registry.callFor('watch').state, GrpcCallState.cancelled);
  });
}

GrpcCallConfiguration _configuration({
  List<String> redactedValues = const [],
}) => GrpcCallConfiguration(
  endpoint: Uri.parse('http://127.0.0.1:8080'),
  serviceName: '.sendreq.Health',
  methodName: 'Watch',
  requestType: '.sendreq.CheckRequest',
  responseType: '.sendreq.CheckResponse',
  requestBytes: Uint8List(0),
  redactedValues: redactedValues,
);

class _TestGrpcTransport implements GrpcTransport {
  _TestGrpcTransport(this.call);

  final _TestGrpcCall call;

  @override
  Future<GrpcCall> start(GrpcCallConfiguration configuration) async => call;
}

class _TestGrpcCall implements GrpcCall {
  final _events = StreamController<GrpcTransportEvent>.broadcast();
  bool cancelled = false;

  @override
  Stream<GrpcTransportEvent> get events => _events.stream;

  void emit(GrpcTransportEvent event) => _events.add(event);

  @override
  Future<void> cancel() async {
    cancelled = true;
    await _events.close();
  }
}
