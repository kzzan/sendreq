import 'package:sendreq/ui/shell/application/workspace_dependencies.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/data/repositories/in_memory_environment_store.dart';
import 'package:sendreq/data/repositories/in_memory_mock_server_repository.dart';
import 'package:sendreq/data/repositories/in_memory_user_notice_repository.dart';
import 'package:sendreq/data/repositories/in_memory_workspace_preference_store.dart';
import 'package:sendreq/data/services/local_mock_server_runtime.dart';
import 'package:sendreq/data/services/http_request_execution_runtime.dart';
import 'package:sendreq/data/services/openapi_request_importer.dart';
import 'package:sendreq/data/services/openapi_request_exporter.dart';
import 'package:sendreq/data/services/openapi_file_exporter.dart';
import 'package:sendreq/data/services/local_workspace_file_ports.dart';
import 'package:sendreq/data/services/openapi_output_directory.dart';
import 'package:sendreq/data/services/openapi_markdown_documentation_renderer.dart';
import 'package:sendreq/data/services/markdown_documentation_file_exporter.dart';
import 'package:sendreq/data/services/proto_source_parser.dart';
import 'package:sendreq/domain/contract_publishing/session_contract_publishing_service.dart';
import 'package:sendreq/domain/repositories/api_asset_repository.dart';
import 'package:sendreq/domain/api_assets/openapi_exchange.dart';
import 'package:sendreq/domain/api_assets/collection_documentation.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/domain/repositories/environment_store.dart';
import 'package:sendreq/domain/repositories/workspace_preference_store.dart';
import 'package:sendreq/domain/grpc/grpc_transport.dart';
import 'package:sendreq/domain/request_runtime/grpc_execution_service.dart';
import 'package:sendreq/domain/request_runtime/websocket_execution_service.dart';
import 'package:sendreq/domain/preferences/workspace_preferences.dart';
import 'package:sendreq/domain/request_runtime/request_execution_runtime.dart';
import 'package:sendreq/domain/request_runtime/http_execution_service.dart';
import 'package:sendreq/domain/environments/environment_execution_resolver.dart';
import 'package:sendreq/domain/websocket/websocket_transport.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/data/demo/demo_example_catalog.dart';

/// 为 ViewModel 测试提供显式的内存仓储，保持生产代码不依赖 data 层默认值。
WorkspaceViewModel workspaceViewModel({
  ApiAssetRepository? assetRepository,
  EnvironmentStore? environmentStore,
  MockServerRepository? mockServerRepository,
  ContractPublishingService? contractPublishingService,
  MockServerRuntimePort? mockServerRuntime,
  UserNoticeRepository? userNoticeRepository,
  EnvironmentResolver? environmentResolver,
  ExecutionService? executionService,
  RequestExecutionRuntime? executionRuntime,
  WebSocketTransport? webSocketTransport,
  GrpcTransport? grpcTransport,
  WorkspacePreferenceStore? preferenceStore,
  OpenApiFileExportPort? openApiFileExporter,
  OpenApiOutputDirectoryPort? openApiOutputDirectory,
  OpenApiMarkdownDocumentationPort? openApiMarkdownRenderer,
  MarkdownDocumentationFilePort? markdownDocumentationFile,
  ProtobufSourcePort? protobufSource,
  WorkspacePreferences initialPreferences = WorkspacePreferences.defaults,
}) {
  final resolvedEnvironmentStore =
      environmentStore ?? InMemoryEnvironmentStore.sample();
  final resolvedMockServerRepository =
      mockServerRepository ?? InMemoryMockServerRepository();
  return WorkspaceViewModel(
    assetRepository: assetRepository ?? InMemoryApiAssetRepository.demo(),
    environmentStore: resolvedEnvironmentStore,
    environmentResolver:
        environmentResolver ??
        EnvironmentExecutionResolver(resolvedEnvironmentStore),
    executionService:
        executionService ??
        HttpExecutionService(
          runtime: executionRuntime ?? HttpRequestExecutionRuntime(),
        ),
    openApiImporter: const OpenApiRequestImporter(),
    openApiExporter: const OpenApiRequestExporter(),
    openApiFileExporter: openApiFileExporter ?? const OpenApiFileExporter(),
    openApiFileReader: const LocalOpenApiFileReader(),
    openApiOutputDirectory:
        openApiOutputDirectory ?? const LocalOpenApiOutputDirectory(),
    openApiMarkdownRenderer:
        openApiMarkdownRenderer ?? const OpenApiMarkdownDocumentationRenderer(),
    markdownDocumentationFile:
        markdownDocumentationFile ?? const MarkdownDocumentationFileExporter(),
    protobufSource: protobufSource ?? const LocalProtobufSourcePort(),
    responseBodyDownload: const LocalResponseBodyDownload(),
    webSocketExecutionService: WebSocketExecutionService(
      webSocketTransport ?? const _NoopWebSocketTransport(),
    ),
    grpcExecutionService: GrpcExecutionService(
      grpcTransport ?? const _NoopGrpcTransport(),
    ),
    contractPublishingService:
        contractPublishingService ??
        SessionContractPublishingService(
          mockServerRepository: resolvedMockServerRepository,
          mockServerRuntime: mockServerRuntime ?? LocalMockServerRuntime(),
        ),
    userNoticeRepository:
        userNoticeRepository ?? InMemoryUserNoticeRepository(),
    preferenceStore: preferenceStore ?? InMemoryWorkspacePreferenceStore(),
    demoCollection: DemoExampleCatalog.collection,
    initialPreferences: initialPreferences,
  );
}

class _NoopWebSocketTransport implements WebSocketTransport {
  const _NoopWebSocketTransport();
  @override
  Future<WebSocketConnection> connect(
    WebSocketConnectionConfiguration configuration,
  ) => throw UnsupportedError('WebSocket transport was not configured.');
}

class _NoopGrpcTransport implements GrpcTransport {
  const _NoopGrpcTransport();
  @override
  Future<GrpcCall> start(GrpcCallConfiguration configuration) =>
      throw UnsupportedError('gRPC transport was not configured.');
}

/// 为需要完整视图的测试提供与生产相同的依赖边界。
WorkspaceDependencies workspaceTestDependencies({
  WorkspacePreferenceStore? preferenceStore,
  ApiAssetRepository? assetRepository,
  EnvironmentStore? environmentStore,
  MockServerRepository? mockServerRepository,
  UserNoticeRepository? userNoticeRepository,
}) => WorkspaceDependencies(
  preferenceStore: preferenceStore ?? InMemoryWorkspacePreferenceStore(),
  assetRepository: assetRepository ?? InMemoryApiAssetRepository.demo(),
  environmentStore: environmentStore ?? InMemoryEnvironmentStore.sample(),
  mockServerRepository: mockServerRepository ?? InMemoryMockServerRepository(),
  userNoticeRepository: userNoticeRepository ?? InMemoryUserNoticeRepository(),
  demoCollection: DemoExampleCatalog.collection,
);
