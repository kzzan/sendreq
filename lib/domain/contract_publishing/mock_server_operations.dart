import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';

/// Owns saved Mock Server persistence, runtime lifecycle, and outcome mapping.
class MockServerOperations {
  MockServerOperations({
    required this._repository,
    required this._runtime,
    required this._now,
  });

  final MockServerRepository _repository;
  final MockServerRuntimePort _runtime;
  final DateTime Function() _now;
  final Map<String, MockServer> _servers = {};

  List<MockServerProjection> get projections {
    final servers = _servers.values.toList()
      ..sort((left, right) {
        final updated = right.updatedAt.compareTo(left.updatedAt);
        return updated != 0 ? updated : left.id.compareTo(right.id);
      });
    return List.unmodifiable([
      for (final server in servers)
        MockServerProjection(
          server: server,
          runtime: _runtime.projectionFor(server.id),
        ),
    ]);
  }

  ResourceRef ref(String id) =>
      ResourceRef(kind: ResourceKind.mockServer, id: id);

  Future<OperationOutcome> load() async {
    try {
      final servers = await _repository.list();
      _servers
        ..clear()
        ..addEntries(servers.map((server) => MapEntry(server.id, server)));
      return _success('mockServer.loaded');
    } on Object {
      return OperationOutcome(
        kind: OperationOutcomeKind.failed,
        code: 'mockServer.loadFailed',
        isRecoverable: true,
        recovery: RecoveryCommand(id: RecoveryCommandId.retry),
      );
    }
  }

  Future<OperationOutcome> save(MockServer server) =>
      _save(server, successCode: 'mockServer.saved');

  Future<OperationOutcome> archive(ResourceRef serverRef) async {
    final server = _serverFor(serverRef);
    if (server == null) return _notFound(serverRef);
    if (server.lifecycle == MockServerLifecycle.archived) {
      return _success('mockServer.archived', serverRef);
    }
    final stopFailure = await _stopBeforeMutation(server.id, serverRef);
    if (stopFailure != null) return stopFailure;
    final archived = MockServerLifecycleTransitions.transition(
      server,
      MockServerLifecycle.archived,
      updatedAt: _now(),
    );
    return _save(archived, successCode: 'mockServer.archived');
  }

  Future<OperationOutcome> delete(ResourceRef serverRef) async {
    final server = _serverFor(serverRef);
    if (server == null) return _notFound(serverRef);
    final stopFailure = await _stopBeforeMutation(server.id, serverRef);
    if (stopFailure != null) return stopFailure;
    try {
      await _repository.delete(server.id);
      _servers.remove(server.id);
      return _success('mockServer.deleted', serverRef);
    } on Object {
      return _failure(
        code: 'mockServer.deleteFailed',
        resourceRef: serverRef,
        recoveryId: RecoveryCommandId.retry,
      );
    }
  }

  Future<OperationOutcome> start(ResourceRef serverRef) async {
    final server = _serverFor(serverRef);
    if (server == null) return _notFound(serverRef);
    if (server.lifecycle == MockServerLifecycle.archived ||
        server.lifecycle == MockServerLifecycle.disabled) {
      return _failed('mockServer.startUnavailable', serverRef);
    }
    try {
      await _runtime.start(server);
      return _success('mockServer.started', serverRef);
    } on Object {
      return _failure(
        code: 'mockServer.startFailed',
        resourceRef: serverRef,
        recoveryId: RecoveryCommandId.retryMockServerStart,
      );
    }
  }

  Future<OperationOutcome> stop(ResourceRef serverRef) async {
    if (_serverFor(serverRef) == null) return _notFound(serverRef);
    try {
      await _runtime.stop(serverRef.id);
      return _success('mockServer.stopped', serverRef);
    } on Object {
      return _failure(
        code: 'mockServer.stopFailed',
        resourceRef: serverRef,
        recoveryId: RecoveryCommandId.retryMockServerStop,
      );
    }
  }

  Future<void> dispose() => _runtime.dispose();

  Future<OperationOutcome?> _stopBeforeMutation(
    String id,
    ResourceRef serverRef,
  ) async {
    try {
      await _runtime.stop(id);
      return null;
    } on Object {
      return _failure(
        code: 'mockServer.stopFailed',
        resourceRef: serverRef,
        recoveryId: RecoveryCommandId.retryMockServerStop,
      );
    }
  }

  Future<OperationOutcome> _save(
    MockServer server, {
    required String successCode,
  }) async {
    final serverRef = ref(server.id);
    try {
      await _repository.save(server);
      _servers[server.id] = server;
      _runtime.apply(server);
      return _success(successCode, serverRef);
    } on Object {
      return _failure(
        code: 'mockServer.saveFailed',
        resourceRef: serverRef,
        recoveryId: RecoveryCommandId.retryMockServerSave,
      );
    }
  }

  MockServer? _serverFor(ResourceRef serverRef) =>
      serverRef.kind == ResourceKind.mockServer ? _servers[serverRef.id] : null;

  OperationOutcome _notFound(ResourceRef serverRef) =>
      _failed('mockServer.notFound', serverRef);

  OperationOutcome _success(String code, [ResourceRef? serverRef]) =>
      OperationOutcome(
        kind: OperationOutcomeKind.success,
        code: code,
        resourceRef: serverRef,
      );

  OperationOutcome _failed(String code, ResourceRef serverRef) =>
      OperationOutcome(
        kind: OperationOutcomeKind.failed,
        code: code,
        resourceRef: serverRef,
      );

  OperationOutcome _failure({
    required String code,
    required ResourceRef resourceRef,
    required RecoveryCommandId recoveryId,
  }) => OperationOutcome(
    kind: OperationOutcomeKind.failed,
    code: code,
    resourceRef: resourceRef,
    isRecoverable: true,
    recovery: RecoveryCommand(id: recoveryId, resourceRef: resourceRef),
  );
}
