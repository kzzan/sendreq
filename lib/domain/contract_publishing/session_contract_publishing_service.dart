import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/domain/contract_publishing/mock_server_operations.dart';

/// Contract Publishing 仅拥有已保存 Mock Server 及其临时运行时。
class SessionContractPublishingService implements ContractPublishingService {
  factory SessionContractPublishingService({
    required MockServerRepository mockServerRepository,
    required MockServerRuntimePort mockServerRuntime,
    DateTime Function()? now,
    String Function()? createMockServerId,
  }) => SessionContractPublishingService._(
    mockServerRepository,
    mockServerRuntime,
    now ?? DateTime.now,
    createMockServerId ?? _defaultMockServerId,
  );

  SessionContractPublishingService._(
    MockServerRepository mockServerRepository,
    MockServerRuntimePort mockServerRuntime,
    this._now,
    this._createMockServerId,
  ) : _mockOperations = MockServerOperations(
        repository: mockServerRepository,
        runtime: mockServerRuntime,
        now: _now,
      );

  final DateTime Function() _now;
  final String Function() _createMockServerId;
  final MockServerOperations _mockOperations;

  @override
  List<MockServerProjection> get mockServers => _mockOperations.projections;

  @override
  Future<OperationOutcome> loadMockServers() => _mockOperations.load();

  @override
  Future<OperationOutcome> saveMockServer(MockServer server) =>
      _mockOperations.save(server);

  @override
  Future<OperationOutcome> archiveMockServer(ResourceRef mockServerRef) =>
      _mockOperations.archive(mockServerRef);

  @override
  Future<OperationOutcome> deleteMockServer(ResourceRef mockServerRef) =>
      _mockOperations.delete(mockServerRef);

  @override
  Future<OperationOutcome> startMockServer(ResourceRef mockServerRef) =>
      _mockOperations.start(mockServerRef);

  @override
  Future<OperationOutcome> stopMockServer(ResourceRef mockServerRef) =>
      _mockOperations.stop(mockServerRef);

  @override
  Future<OperationOutcome> createMockServerFromSnapshot(
    SanitizedMockSourceSnapshot snapshot,
  ) async {
    final definition = _mockDefinitionFor(snapshot);
    final ref = ResourceRef(
      kind: ResourceKind.mockServer,
      id: _createMockServerId(),
    );
    try {
      final now = _now().toUtc();
      return await saveMockServer(
        MockServer(
          id: ref.id,
          name: '${definition.method} ${definition.path}',
          createdAt: now,
          updatedAt: now,
          source: MockSourceReference(
            kind: MockSourceKind.request,
            resourceRef: ResourceRef(
              kind: ResourceKind.request,
              id: snapshot.requestRef.id,
            ),
          ),
          endpoints: [
            MockEndpoint(
              id: '${ref.id}-endpoint-1',
              matcher: MockRequestMatcher(
                method: definition.method,
                path: definition.path,
                query: Uri(query: definition.query).queryParameters,
              ),
              variants: [
                MockResponseVariant(
                  id: '${ref.id}-default',
                  statusCode: definition.statusCode,
                  headers: definition.headers,
                  body: definition.body,
                  source: MockSourceReference(
                    kind: MockSourceKind.responseSnapshot,
                    resourceRef: ResourceRef(
                      kind: ResourceKind.responseSnapshot,
                      id: snapshot.response.responseSnapshotId,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } on ArgumentError {
      return OperationOutcome(
        kind: OperationOutcomeKind.failed,
        code: 'mockServer.invalidSnapshot',
        resourceRef: ref,
      );
    }
  }

  @override
  Future<void> disposeSession() => _mockOperations.dispose();

  _MockServerDefinition _mockDefinitionFor(
    SanitizedMockSourceSnapshot snapshot,
  ) {
    final parts = snapshot.requestSummary.trim().split(RegExp(r'\s+'));
    final method = parts.isEmpty ? 'GET' : parts.first.toUpperCase();
    final requestUri = parts.length < 2 ? null : Uri.tryParse(parts[1]);
    final path = requestUri == null
        ? '/'
        : requestUri.hasScheme
        ? requestUri.path
        : requestUri.path.startsWith('/')
        ? requestUri.path
        : '/';
    return _MockServerDefinition(
      method: const {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'}.contains(method)
          ? method
          : 'GET',
      path: path.isEmpty ? '/' : path,
      statusCode: snapshot.response.statusCode ?? 200,
      headers: snapshot.response.headers,
      query: requestUri?.query ?? '',
      body: snapshot.response.bodyPreview,
    );
  }

  static String _defaultMockServerId() =>
      'mock-${DateTime.now().toUtc().microsecondsSinceEpoch}';
}

class _MockServerDefinition {
  const _MockServerDefinition({
    required this.method,
    required this.path,
    required this.statusCode,
    required this.headers,
    required this.query,
    required this.body,
  });

  final String method;
  final String path;
  final int statusCode;
  final Map<String, String> headers;
  final String query;
  final String body;
}
