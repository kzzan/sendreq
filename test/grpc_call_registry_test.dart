import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/domain/authentication/request_authentication.dart';
import 'package:sendreq/domain/grpc/grpc_call_registry.dart';
import 'package:sendreq/domain/grpc/grpc_transport.dart';
import 'package:sendreq/domain/grpc/grpc_rpc_shape.dart';
import 'package:sendreq/domain/request_runtime/long_lived_session_context.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';

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
      configuration: _configuration(
        redactionPolicy: RedactionPolicy(const ['test-token']),
      ),
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
    expect(snapshot.omittedEventCount, 2);
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

  test(
    'disposing a terminal call releases its transport subscription',
    () async {
      final call = _TestGrpcCall();
      final registry = GrpcCallRegistry(_TestGrpcTransport(call));
      await registry.start(requestId: 'done', configuration: _configuration());
      call.emit(const GrpcTransportEvent.status(0));
      await Future<void>.delayed(Duration.zero);

      await registry.disposeRequest('done');

      expect(call.cancelled, isTrue);
      expect(registry.callFor('done').state, GrpcCallState.idle);
    },
  );

  test(
    'registry writes client-stream messages and keeps server reads open',
    () async {
      final call = _TestGrpcCall();
      final registry = GrpcCallRegistry(_TestGrpcTransport(call));
      await registry.start(
        requestId: 'chat',
        configuration: _configuration(clientStreaming: true),
      );

      await registry.send(
        requestId: 'chat',
        message: Uint8List.fromList([10, 5, 104, 101, 108, 108, 111]),
      );
      await registry.closeRequestStream('chat');

      final snapshot = registry.callFor('chat');
      expect(call.sentMessages, [
        Uint8List.fromList([10, 5, 104, 101, 108, 108, 111]),
      ]);
      expect(call.requestStreamClosed, isTrue);
      expect(snapshot.requestStreamOpen, isFalse);
      expect(snapshot.events.single.kind, GrpcTransportEventKind.request);
    },
  );

  test('projects context-correct commands for every RPC shape', () async {
    for (final shape in GrpcRpcShape.values) {
      final call = _TestGrpcCall();
      final registry = GrpcCallRegistry(_TestGrpcTransport(call));

      expect(registry.callFor(shape.name).availableCommands, {
        GrpcCallCommand.start,
      });

      await registry.start(
        requestId: shape.name,
        configuration: _configuration(rpcShape: shape),
      );
      final running = registry.callFor(shape.name);
      expect(running.rpcShape, shape);
      expect(running.can(GrpcCallCommand.cancel), isTrue);
      expect(running.can(GrpcCallCommand.sendNext), shape.hasClientStream);
      expect(running.can(GrpcCallCommand.endSending), shape.hasClientStream);

      if (shape.hasClientStream) {
        await registry.closeRequestStream(shape.name);
        expect(registry.callFor(shape.name).availableCommands, {
          GrpcCallCommand.cancel,
        });
      }
      call.emit(const GrpcTransportEvent.status(0));
      await Future<void>.delayed(Duration.zero);
      expect(registry.callFor(shape.name).availableCommands, {
        GrpcCallCommand.restart,
      });
    }
  });

  test('frozen gRPC context retains metadata keys without values', () async {
    final call = _TestGrpcCall();
    final registry = GrpcCallRegistry(_TestGrpcTransport(call));
    await registry.start(
      requestId: 'chat',
      configuration: _configuration(
        rpcShape: GrpcRpcShape.bidirectionalStreaming,
        grpcSessionContext: const GrpcSessionContextSnapshot(
          environmentId: 'environment-local',
          environmentName: 'Local Protocol',
          authenticationLabel: 'Environment Bearer token',
          authenticationType: RequestAuthenticationType.bearer,
          authenticationSource: RequestAuthenticationSource.environment,
          redactedEndpoint: 'http://127.0.0.1:50051',
          schemaSource: GrpcSchemaSource.reflection,
          serviceName: '.example.v1.ExampleService',
          methodName: 'Chat',
          rpcShape: GrpcRpcShape.bidirectionalStreaming,
          useTls: false,
          deadlineMs: 3000,
          metadataKeys: ['authorization', 'x-request-id'],
        ),
      ),
    );

    final context = registry.callFor('chat').sessionContext;
    expect(context.rpcShape, GrpcRpcShape.bidirectionalStreaming);
    expect(context.schemaSource, GrpcSchemaSource.reflection);
    expect(context.metadataKeys, ['authorization', 'x-request-id']);
    expect(context.toString(), isNot(contains('secret-token')));
  });

  test(
    'keeps a sanitized call context and marks configuration changes',
    () async {
      final call = _TestGrpcCall();
      final registry = GrpcCallRegistry(_TestGrpcTransport(call));
      await registry.start(
        requestId: 'watch',
        configuration: _configuration(
          sessionContext: const LongLivedSessionContext(
            environmentName: 'Local Protocol',
            authenticationLabel: 'Environment Bearer token',
            authenticationType: RequestAuthenticationType.bearer,
            authenticationSource: RequestAuthenticationSource.environment,
          ),
        ),
      );

      registry.markConfigurationChanged('watch');

      final snapshot = registry.callFor('watch');
      expect(snapshot.sessionContext.environmentName, 'Local Protocol');
      expect(
        snapshot.sessionContext.authenticationLabel,
        'Environment Bearer token',
      );
      expect(snapshot.requiresRestart, isTrue);
    },
  );

  test('status 16 explains the Bearer environment used by the call', () async {
    final call = _TestGrpcCall();
    final registry = GrpcCallRegistry(_TestGrpcTransport(call));
    await registry.start(
      requestId: 'watch',
      configuration: _configuration(
        sessionContext: const LongLivedSessionContext(
          environmentName: 'Production',
          authenticationLabel: 'Environment Bearer token',
          authenticationType: RequestAuthenticationType.bearer,
          authenticationSource: RequestAuthenticationSource.environment,
        ),
      ),
    );

    call.emit(
      const GrpcTransportEvent.status(
        16,
        'valid Bearer authorization is required',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      registry.callFor('watch').errorMessage,
      'Bearer authentication failed. This call uses the Environment Bearer token from Production. Switch to the intended environment or update its Bearer token, then restart the call.',
    );
  });

  test('status 16 distinguishes a request Bearer token', () async {
    final call = _TestGrpcCall();
    final registry = GrpcCallRegistry(_TestGrpcTransport(call));
    await registry.start(
      requestId: 'request-bearer',
      configuration: _configuration(
        sessionContext: const LongLivedSessionContext(
          environmentName: 'Production',
          authenticationLabel: 'Request Bearer token',
          authenticationType: RequestAuthenticationType.bearer,
          authenticationSource: RequestAuthenticationSource.request,
        ),
      ),
    );

    call.emit(const GrpcTransportEvent.status(16));
    await Future<void>.delayed(Duration.zero);

    expect(
      registry.callFor('request-bearer').errorMessage,
      'Bearer authentication failed. This call uses the request Bearer token. Update the request token, then restart the call.',
    );
  });

  test('status 16 distinguishes request API key and Basic credentials', () async {
    for (final expectation in <(String, RequestAuthenticationType, String)>[
      (
        'Request API key',
        RequestAuthenticationType.apiKey,
        'API key authentication failed. Update the request API key name and value, then restart the call.',
      ),
      (
        'Request Basic authentication',
        RequestAuthenticationType.basic,
        'Basic authentication failed. Update the request username and password, then restart the call.',
      ),
    ]) {
      final call = _TestGrpcCall();
      final registry = GrpcCallRegistry(_TestGrpcTransport(call));
      await registry.start(
        requestId: expectation.$1,
        configuration: _configuration(
          sessionContext: LongLivedSessionContext(
            environmentName: 'Production',
            authenticationLabel: expectation.$1,
            authenticationType: expectation.$2,
            authenticationSource: RequestAuthenticationSource.request,
          ),
        ),
      );

      call.emit(const GrpcTransportEvent.status(16));
      await Future<void>.delayed(Duration.zero);

      expect(registry.callFor(expectation.$1).errorMessage, expectation.$3);
    }
  });
}

GrpcCallConfiguration _configuration({
  RedactionPolicy? redactionPolicy,
  List<String> redactedValues = const [],
  bool clientStreaming = false,
  GrpcRpcShape? rpcShape,
  LongLivedSessionContext sessionContext =
      const LongLivedSessionContext.unbound(),
  GrpcSessionContextSnapshot? grpcSessionContext,
}) => GrpcCallConfiguration(
  endpoint: Uri.parse('http://127.0.0.1:8080'),
  serviceName: '.sendreq.Health',
  methodName: 'Watch',
  requestType: '.sendreq.CheckRequest',
  responseType: '.sendreq.CheckResponse',
  requestBytes: Uint8List(0),
  clientStreaming: clientStreaming,
  rpcShape: rpcShape,
  redactionPolicy: redactionPolicy,
  redactedValues: redactedValues,
  sessionContext: sessionContext,
  grpcSessionContext: grpcSessionContext,
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
  bool requestStreamClosed = false;
  final sentMessages = <Uint8List>[];

  @override
  Stream<GrpcTransportEvent> get events => _events.stream;

  void emit(GrpcTransportEvent event) => _events.add(event);

  @override
  Future<void> send(Uint8List message) async {
    sentMessages.add(Uint8List.fromList(message));
  }

  @override
  Future<void> closeRequestStream() async {
    requestStreamClosed = true;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    await _events.close();
  }
}
