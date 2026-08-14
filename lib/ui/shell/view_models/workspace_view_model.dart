import 'dart:async';
import 'package:flutter/widgets.dart';

import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/api_assets/collection_documentation.dart';
import 'package:sendreq/domain/api_assets/openapi_exchange.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/domain/preferences/workspace_preferences.dart';
import 'package:sendreq/domain/repositories/api_asset_repository.dart';
import 'package:sendreq/domain/repositories/environment_store.dart';
import 'package:sendreq/domain/repositories/workspace_preference_store.dart';
import 'package:sendreq/domain/websocket/websocket_transport.dart';
import 'package:sendreq/ui/shell/application/workspace_dependencies.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model_state.dart';
import 'package:sendreq/ui/shell/view_models/workspace_execution_coordination.dart';

export 'workspace_assets.dart';
export 'workspace_contract_publishing.dart';
export 'workspace_execution_coordination.dart';
export 'workspace_execution_requests.dart';
export 'workspace_documentation_export.dart';
export 'workspace_navigation.dart';
export 'workspace_protocol_operations.dart';
export 'workspace_preferences.dart';
export 'workspace_read_model.dart';
export 'workspace_request_configuration.dart';
export 'workspace_request_persistence.dart';

/// Protobuf 发送预览：成功时给出编码后的字节数，失败时给出字段路径错误。
class ProtobufEncodePreview {
  /// 私有构造，仅由成功 / 失败工厂构造器调用。
  const ProtobufEncodePreview._({this.byteLength, this.error});

  /// 创建编码成功的结果，携带编码后的字节数。
  const ProtobufEncodePreview.success(int byteLength)
    : this._(byteLength: byteLength);

  /// 创建编码失败的结果，携带错误信息。
  const ProtobufEncodePreview.failure(String error) : this._(error: error);

  /// 编码后的字节数；失败时为空。
  final int? byteLength;

  /// 字段校验或 schema 错误；成功时为空。
  final String? error;

  /// 是否成功完成编码。
  bool get isSuccess => error == null;
}

/// WebSocket 二进制帧按当前 Protobuf schema 解码后的详情。
class WebSocketProtobufDecodeDetail {
  /// 私有构造，仅由成功 / 失败工厂构造器调用。
  const WebSocketProtobufDecodeDetail._({this.formattedJson, this.error});

  /// 创建解码成功的结果，携带格式化 JSON。
  const WebSocketProtobufDecodeDetail.success(String formattedJson)
    : this._(formattedJson: formattedJson);

  /// 创建单帧解码失败的结果，携带错误信息。
  const WebSocketProtobufDecodeDetail.failure(String error)
    : this._(error: error);

  /// 解码后的格式化 JSON；失败时为空。
  final String? formattedJson;

  /// 单帧解码错误；成功时为空。
  final String? error;

  /// 是否成功解码。
  bool get isSuccess => error == null;
}

/// 壳层 ViewModel 只编排 UI 状态，不直接承担真实网络发送。
class WorkspaceViewModel extends ChangeNotifier {
  /// 构建工作区 ViewModel。
  ///
  /// 仓储必须由应用组合根注入，避免 ViewModel 依赖具体的存储后端。
  /// 运行时传输与功能服务可按需替换，便于测试。
  /// 初始偏好取自 [initialPreferences]，WebSocket 会话注册表的变更会触发
  /// [notifyListeners] 刷新 UI。
  factory WorkspaceViewModel({
    required ApiAssetRepository assetRepository,
    required EnvironmentStore environmentStore,
    required EnvironmentResolver environmentResolver,
    required ExecutionService executionService,
    required OpenApiImportTransformer openApiImporter,
    required OpenApiExportPort openApiExporter,
    required OpenApiFileExportPort openApiFileExporter,
    required OpenApiFileReadPort openApiFileReader,
    required OpenApiOutputDirectoryPort openApiOutputDirectory,
    required OpenApiMarkdownDocumentationPort openApiMarkdownRenderer,
    required MarkdownDocumentationFilePort markdownDocumentationFile,
    required ProtobufSourcePort protobufSource,
    required ResponseBodyDownloadPort responseBodyDownload,
    required WebSocketExecutionPort webSocketExecutionService,
    required GrpcExecutionPort grpcExecutionService,
    required ContractPublishingService contractPublishingService,
    required UserNoticeRepository userNoticeRepository,
    required WorkspacePreferenceStore preferenceStore,
    required ApiCollection demoCollection,
    WorkspacePreferences initialPreferences = WorkspacePreferences.defaults,
  }) => WorkspaceViewModel._(
    assetRepository: assetRepository,
    environmentStore: environmentStore,
    environmentResolver: environmentResolver,
    executionService: executionService,
    openApiImporter: openApiImporter,
    openApiExporter: openApiExporter,
    openApiFileExporter: openApiFileExporter,
    openApiFileReader: openApiFileReader,
    openApiOutputDirectory: openApiOutputDirectory,
    openApiMarkdownRenderer: openApiMarkdownRenderer,
    markdownDocumentationFile: markdownDocumentationFile,
    protobufSource: protobufSource,
    responseBodyDownload: responseBodyDownload,
    webSocketExecutionService: webSocketExecutionService,
    grpcExecutionService: grpcExecutionService,
    contractPublishingService: contractPublishingService,
    userNoticeRepository: userNoticeRepository,
    preferenceStore: preferenceStore,
    demoCollection: demoCollection,
    initialPreferences: initialPreferences,
  );

  /// 从 Workspace 的完整依赖快照构建 ViewModel。
  ///
  /// Workspace 视图应使用此入口，避免了解每个持久化端口的内部组成；针对
  /// 单个仓储行为的单元测试仍可使用主构造器注入精确替身。
  factory WorkspaceViewModel.fromDependencies({
    required WorkspaceDependencies dependencies,
    required EnvironmentResolver environmentResolver,
    required ExecutionService executionService,
    required OpenApiImportTransformer openApiImporter,
    required OpenApiExportPort openApiExporter,
    required OpenApiFileExportPort openApiFileExporter,
    required OpenApiFileReadPort openApiFileReader,
    required OpenApiOutputDirectoryPort openApiOutputDirectory,
    required OpenApiMarkdownDocumentationPort openApiMarkdownRenderer,
    required MarkdownDocumentationFilePort markdownDocumentationFile,
    required ProtobufSourcePort protobufSource,
    required ResponseBodyDownloadPort responseBodyDownload,
    required WebSocketExecutionPort webSocketExecutionService,
    required GrpcExecutionPort grpcExecutionService,
    required ContractPublishingService contractPublishingService,
    WorkspacePreferences initialPreferences = WorkspacePreferences.defaults,
  }) => WorkspaceViewModel(
    assetRepository: dependencies.assetRepository,
    environmentStore: dependencies.environmentStore,
    environmentResolver: environmentResolver,
    executionService: executionService,
    openApiImporter: openApiImporter,
    openApiExporter: openApiExporter,
    openApiFileExporter: openApiFileExporter,
    openApiFileReader: openApiFileReader,
    openApiOutputDirectory: openApiOutputDirectory,
    openApiMarkdownRenderer: openApiMarkdownRenderer,
    markdownDocumentationFile: markdownDocumentationFile,
    protobufSource: protobufSource,
    responseBodyDownload: responseBodyDownload,
    webSocketExecutionService: webSocketExecutionService,
    grpcExecutionService: grpcExecutionService,
    contractPublishingService: contractPublishingService,
    userNoticeRepository: dependencies.userNoticeRepository,
    preferenceStore: dependencies.preferenceStore,
    demoCollection: dependencies.demoCollection,
    initialPreferences: initialPreferences,
  );

  WorkspaceViewModel._({
    required ApiAssetRepository assetRepository,
    required EnvironmentStore environmentStore,
    required EnvironmentResolver environmentResolver,
    required ExecutionService executionService,
    required OpenApiImportTransformer openApiImporter,
    required OpenApiExportPort openApiExporter,
    required OpenApiFileExportPort openApiFileExporter,
    required OpenApiFileReadPort openApiFileReader,
    required OpenApiOutputDirectoryPort openApiOutputDirectory,
    required OpenApiMarkdownDocumentationPort openApiMarkdownRenderer,
    required MarkdownDocumentationFilePort markdownDocumentationFile,
    required ProtobufSourcePort protobufSource,
    required ResponseBodyDownloadPort responseBodyDownload,
    required WebSocketExecutionPort webSocketExecutionService,
    required GrpcExecutionPort grpcExecutionService,
    required ContractPublishingService contractPublishingService,
    required UserNoticeRepository userNoticeRepository,
    required WorkspacePreferenceStore preferenceStore,
    required ApiCollection demoCollection,
    WorkspacePreferences initialPreferences = WorkspacePreferences.defaults,
  }) {
    internals = WorkspaceViewModelState(
      assetRepository: assetRepository,
      environmentStore: environmentStore,
      environmentResolver: environmentResolver,
      executionService: executionService,
      openApiImporter: openApiImporter,
      openApiExporter: openApiExporter,
      openApiFileExporter: openApiFileExporter,
      openApiFileReader: openApiFileReader,
      openApiDirectoryPort: openApiOutputDirectory,
      openApiMarkdownRenderer: openApiMarkdownRenderer,
      markdownDocumentationFile: markdownDocumentationFile,
      protobufSource: protobufSource,
      responseBodyDownload: responseBodyDownload,
      webSocketSessions: webSocketExecutionService,
      grpcCalls: grpcExecutionService,
      contractPublishing: contractPublishingService,
      userNoticeRepository: userNoticeRepository,
      preferenceStore: preferenceStore,
      demoCollection: demoCollection,
      initialPreferences: initialPreferences,
    );
    // WebSocket 会话状态变化直接驱动整个工作区重绘。
    internals.webSocketChanges = internals.webSocketSessions.changes.listen((
      _,
    ) {
      if (!internals.isDisposed) {
        for (final session in internals.webSocketSessions.sessions) {
          final failureKey = 'websocket:${session.requestId}';
          final failedInBackground =
              session.state == WebSocketConnectionState.error &&
              (internals.activeSection != WorkspaceSection.requests ||
                  internals.activeRequestId != session.requestId);
          if (session.state != WebSocketConnectionState.error) {
            internals.backgroundSessionFailures.remove(failureKey);
          } else if (failedInBackground &&
              internals.backgroundSessionFailures.add(failureKey)) {
            unawaited(
              internals.feedbackDispatcher.dispatchSession(
                SanitizedSessionProjection(
                  sessionId: session.requestId,
                  requestRef: RequestRef(id: session.requestId),
                  status: 'failed',
                  summary: session.errorMessage ?? 'WebSocket session failed.',
                ),
              ),
            );
          }
        }
        notifyListeners();
      }
    });
    internals.grpcChanges = internals.grpcCalls.changes.listen((_) {
      if (internals.isDisposed) return;
      for (final call in internals.grpcCalls.calls) {
        final failureKey = 'grpc:${call.requestId}';
        final failedInBackground =
            call.state.name == 'error' &&
            (internals.activeSection != WorkspaceSection.requests ||
                internals.activeRequestId != call.requestId);
        if (call.state.name != 'error') {
          internals.backgroundSessionFailures.remove(failureKey);
        } else if (failedInBackground &&
            internals.backgroundSessionFailures.add(failureKey)) {
          unawaited(
            internals.feedbackDispatcher.dispatchSession(
              SanitizedSessionProjection(
                sessionId: call.requestId,
                requestRef: RequestRef(id: call.requestId),
                status: 'failed',
                summary: call.errorMessage ?? 'gRPC call failed.',
              ),
            ),
          );
        }
      }
      notifyListeners();
    });
    unawaited(loadSavedMockServersInternal());
    unawaited(restoreUnreadNoticesInternal());
  }

  /// Internal contract shared by the split command and read-model modules.
  late final WorkspaceViewModelState internals;

  /// 销毁时释放全部 WebSocket 会话并停止本地 Mock 服务。
  @override
  void dispose() {
    internals.isDisposed = true;
    unawaited(internals.webSocketChanges.cancel());
    unawaited(internals.grpcChanges.cancel());
    unawaited(internals.webSocketSessions.dispose());
    unawaited(internals.grpcCalls.dispose());
    unawaited(internals.contractPublishing.disposeSession());
    super.dispose();
  }

  /// 供同一 library 的领域操作扩展触发一次界面刷新。
  void notifyWorkspace() {
    if (!internals.isDisposed) notifyListeners();
  }
}
