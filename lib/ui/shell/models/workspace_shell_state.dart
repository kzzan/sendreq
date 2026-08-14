import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/ui/features/requests/editor/models/request_editor_models.dart';
import 'package:sendreq/ui/features/requests/output/models/response_viewer_models.dart';
import 'package:sendreq/ui/shell/models/workspace_shell_models.dart';

/// Shell 独有的导航状态，不包含领域服务或业务草稿。
class WorkspaceNavigationState {
  WorkspaceSection activeSection = WorkspaceSection.requests;
  RequestWorkingView requestWorkingView = RequestWorkingView.all;
  bool environmentManagerOpen = false;
  String? editingEnvironmentId;
  NarrowWorkspacePanel narrowWorkspacePanel = NarrowWorkspacePanel.request;
}

/// Shell 当前选中的资源与页签，不拥有资源内容。
class WorkspaceSelectionState {
  String? activeRequestId;
  String? activeMockServerId;
  RequestEditorSection activeRequestTab = RequestEditorSection.params;
  ResponseTab activeResponseTab = ResponseTab.body;
}

/// Shell 的短生命周期呈现反馈，不能作为模块间领域状态使用。
class WorkspaceTransientFeedbackState {
  ResponseSnapshot? response;
  bool isSending = false;
  String? sendingRequestId;
  String? activeExecutionId;
  int executionGeneration = 0;
  String? executionError;
  String? lastActionMessage;
  SanitizedExecutionResult? currentExecutionResult;
}
