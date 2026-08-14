import 'dart:async';

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
import 'package:sendreq/ui/features/requests/editor/models/request_editor_models.dart';
import 'package:sendreq/ui/features/requests/output/models/response_viewer_models.dart';
import 'package:sendreq/ui/features/settings/view_models/settings_view_model.dart';
import 'package:sendreq/ui/shell/application/request_draft_editor.dart';
import 'package:sendreq/ui/shell/application/user_notice.dart';
import 'package:sendreq/ui/core/application/user_message.dart';
import 'package:sendreq/ui/shell/models/workspace_shell_models.dart';
import 'package:sendreq/ui/shell/models/workspace_shell_state.dart';

/// Explicit collaboration state for the split WorkspaceViewModel modules.
///
/// Views consume the ViewModel's read model and commands, never this mutable
/// implementation contract directly.
class WorkspaceViewModelState {
  WorkspaceViewModelState({
    required this.assetRepository,
    required this.environmentStore,
    required this.environmentResolver,
    required this.executionService,
    required this.openApiImporter,
    required this.openApiExporter,
    required this.openApiFileExporter,
    required this.openApiFileReader,
    required this.openApiDirectoryPort,
    required this.openApiMarkdownRenderer,
    required this.markdownDocumentationFile,
    required this.protobufSource,
    required this.responseBodyDownload,
    required this.webSocketSessions,
    required this.grpcCalls,
    required this.contractPublishing,
    required UserNoticeRepository userNoticeRepository,
    required this.preferenceStore,
    required this.demoCollection,
    required WorkspacePreferences initialPreferences,
  }) : noticeController = WorkspaceNoticeController(
         repository: userNoticeRepository,
       ),
       appearance = initialPreferences.appearance,
       locale = initialPreferences.locale,
       font = initialPreferences.font,
       codeFont = initialPreferences.codeFont,
       codeFontSize = initialPreferences.codeFontSize {
    feedbackDispatcher = WorkspaceFeedbackDispatcher(noticeController);
    activeRequestId = assetRepository.activeRequestId;
  }

  final ApiAssetRepository assetRepository;
  final ApiCollection demoCollection;
  final EnvironmentStore environmentStore;
  final EnvironmentResolver environmentResolver;
  final ExecutionService executionService;
  final OpenApiImportTransformer openApiImporter;
  final OpenApiExportPort openApiExporter;
  final OpenApiFileExportPort openApiFileExporter;
  final OpenApiFileReadPort openApiFileReader;
  final OpenApiOutputDirectoryPort openApiDirectoryPort;
  final OpenApiMarkdownDocumentationPort openApiMarkdownRenderer;
  final MarkdownDocumentationFilePort markdownDocumentationFile;
  final ProtobufSourcePort protobufSource;
  final ResponseBodyDownloadPort responseBodyDownload;
  final WorkspaceNoticeController noticeController;
  late final WorkspaceFeedbackDispatcher feedbackDispatcher;
  final WebSocketExecutionPort webSocketSessions;
  late final StreamSubscription<void> webSocketChanges;
  final GrpcExecutionPort grpcCalls;
  late final StreamSubscription<void> grpcChanges;
  final ContractPublishingService contractPublishing;
  final WorkspacePreferenceStore preferenceStore;

  bool isDisposed = false;
  final navigationState = WorkspaceNavigationState();
  final selectionState = WorkspaceSelectionState();
  final feedbackState = WorkspaceTransientFeedbackState();

  AppearancePreference appearance;
  LocalePreference locale;
  WorkspaceFontPreference font;
  CodeFontPreference codeFont;
  double codeFontSize;
  String openApiOutputDirectory = 'sendreq-openapi';
  final String defaultOpenApiOutputDirectory = 'sendreq-openapi';
  bool hasPreferenceChanges = false;
  PreferencePersistenceState preferencePersistenceState =
      PreferencePersistenceState.saved;
  Future<void> preferenceSaveQueue = Future<void>.value();
  int preferenceSaveVersion = 0;
  WorkspacePreferences? pendingPreferenceSnapshot;
  bool preferenceSaveWorkerRunning = false;
  final Set<String> backgroundSessionFailures = {};
  final Map<String, RequestDraft> draftOverrides = {};
  final Set<String> grpcReflectionDiscoveries = {};
  final RequestDraftEditor draftEditor = const RequestDraftEditor();
  final Map<String, WebSocketMessageDraft> webSocketMessageDrafts = {};
  final Map<String, List<String>> protobufMessageTypes = {};
  final Map<String, ProtobufDescriptorSet> protobufDescriptors = {};
  final Set<String> collapsedCollectionIds = {};
  final Set<String> collapsedFolderIds = {};
  final Set<String> revealedDraftFieldIds = {};
  int draftFieldSequence = 0;

  WorkspaceSection get activeSection => navigationState.activeSection;
  set activeSection(WorkspaceSection value) =>
      navigationState.activeSection = value;

  RequestWorkingView get requestWorkingView =>
      navigationState.requestWorkingView;
  set requestWorkingView(RequestWorkingView value) =>
      navigationState.requestWorkingView = value;

  bool get environmentManagerOpen => navigationState.environmentManagerOpen;
  set environmentManagerOpen(bool value) =>
      navigationState.environmentManagerOpen = value;

  String? get editingEnvironmentId => navigationState.editingEnvironmentId;
  set editingEnvironmentId(String? value) =>
      navigationState.editingEnvironmentId = value;

  NarrowWorkspacePanel get narrowWorkspacePanel =>
      navigationState.narrowWorkspacePanel;
  set narrowWorkspacePanel(NarrowWorkspacePanel value) =>
      navigationState.narrowWorkspacePanel = value;

  String? get activeRequestId => selectionState.activeRequestId;
  set activeRequestId(String? value) => selectionState.activeRequestId = value;

  String? get activeMockServerId => selectionState.activeMockServerId;
  set activeMockServerId(String? value) =>
      selectionState.activeMockServerId = value;

  RequestEditorSection get activeRequestTab => selectionState.activeRequestTab;
  set activeRequestTab(RequestEditorSection value) =>
      selectionState.activeRequestTab = value;

  ResponseTab get activeResponseTab => selectionState.activeResponseTab;
  set activeResponseTab(ResponseTab value) =>
      selectionState.activeResponseTab = value;

  ResponseSnapshot? get response => feedbackState.response;
  set response(ResponseSnapshot? value) => feedbackState.response = value;

  bool get isSending => feedbackState.isSending;
  set isSending(bool value) => feedbackState.isSending = value;

  String? get sendingRequestId => feedbackState.sendingRequestId;
  set sendingRequestId(String? value) => feedbackState.sendingRequestId = value;

  String? get activeExecutionId => feedbackState.activeExecutionId;
  set activeExecutionId(String? value) =>
      feedbackState.activeExecutionId = value;

  int get executionGeneration => feedbackState.executionGeneration;
  set executionGeneration(int value) =>
      feedbackState.executionGeneration = value;

  String? get executionError => feedbackState.executionError;
  set executionError(String? value) => feedbackState.executionError = value;

  String? get lastActionMessage => feedbackState.lastActionMessage;
  set lastActionMessage(String? value) =>
      feedbackState.lastActionMessage = value;

  void recordUserMessage(
    String message, {
    UserMessageSeverity severity = UserMessageSeverity.success,
    String? deduplicationKey,
  }) {
    lastActionMessage = message;
    noticeController.recordSessionMessage(
      UserMessage(
        message: message,
        severity: severity,
        deduplicationKey: deduplicationKey,
      ),
    );
  }

  SanitizedExecutionResult? get currentExecutionResult =>
      feedbackState.currentExecutionResult;
  set currentExecutionResult(SanitizedExecutionResult? value) =>
      feedbackState.currentExecutionResult = value;
}
