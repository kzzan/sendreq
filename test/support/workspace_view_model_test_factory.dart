import 'package:sendreq/features/workspace/application/workspace_dependencies.dart';
import 'package:sendreq/data/demo/workbench_seed.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/data/repositories/in_memory_environment_store.dart';
import 'package:sendreq/data/repositories/in_memory_workspace_preference_store.dart';
import 'package:sendreq/data/services/api_documentation_generator.dart';
import 'package:sendreq/data/services/local_mock_runtime.dart';
import 'package:sendreq/domain/repositories/api_asset_repository.dart';
import 'package:sendreq/domain/repositories/environment_store.dart';
import 'package:sendreq/domain/repositories/execution_history_store.dart';
import 'package:sendreq/domain/repositories/workspace_preference_store.dart';
import 'package:sendreq/domain/grpc/grpc_transport.dart';
import 'package:sendreq/domain/models/workspace_models.dart';
import 'package:sendreq/domain/preferences/workspace_preferences.dart';
import 'package:sendreq/domain/request_runtime/request_execution_runtime.dart';
import 'package:sendreq/domain/websocket/websocket_transport.dart';
import 'package:sendreq/features/workspace/view_models/workspace_view_model.dart';

/// 为 ViewModel 测试提供显式的内存仓储，保持生产代码不依赖 data 层默认值。
WorkspaceViewModel workspaceViewModel({
  WorkbenchSeed? seed,
  ApiAssetRepository? assetRepository,
  EnvironmentStore? environmentStore,
  RequestExecutionRuntime? executionRuntime,
  WebSocketTransport? webSocketTransport,
  GrpcTransport? grpcTransport,
  ApiDocumentationGenerator? documentationGenerator,
  LocalMockRuntime? mockRuntime,
  WorkspacePreferenceStore? preferenceStore,
  ExecutionHistoryStore? historyStore,
  List<ExecutionRecord>? initialHistory,
  WorkspacePreferences initialPreferences = WorkspacePreferences.defaults,
  String? defaultDocumentationOutputDirectory,
}) => WorkspaceViewModel(
  seed: seed,
  assetRepository: assetRepository ?? InMemoryApiAssetRepository.demo(),
  environmentStore: environmentStore ?? InMemoryEnvironmentStore.sample(),
  executionRuntime: executionRuntime,
  webSocketTransport: webSocketTransport,
  grpcTransport: grpcTransport,
  documentationGenerator: documentationGenerator,
  mockRuntime: mockRuntime,
  preferenceStore: preferenceStore ?? InMemoryWorkspacePreferenceStore(),
  historyStore: historyStore,
  initialHistory: initialHistory,
  initialPreferences: initialPreferences,
  defaultDocumentationOutputDirectory: defaultDocumentationOutputDirectory,
);

/// 为需要完整视图的测试提供与生产相同的依赖边界。
WorkspaceDependencies workspaceTestDependencies({
  WorkspacePreferenceStore? preferenceStore,
  ApiAssetRepository? assetRepository,
  EnvironmentStore? environmentStore,
  ExecutionHistoryStore? historyStore,
  List<ExecutionRecord> initialHistory = const [],
  String? defaultDocumentationOutputDirectory,
}) => WorkspaceDependencies(
  preferenceStore: preferenceStore ?? InMemoryWorkspacePreferenceStore(),
  assetRepository: assetRepository ?? InMemoryApiAssetRepository.demo(),
  environmentStore: environmentStore ?? InMemoryEnvironmentStore.sample(),
  historyStore: historyStore,
  initialHistory: initialHistory,
  defaultDocumentationOutputDirectory: defaultDocumentationOutputDirectory,
);
