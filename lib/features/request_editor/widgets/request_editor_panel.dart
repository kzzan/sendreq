import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/api_assets/api_asset_models.dart';
import '../../../domain/authentication/request_authentication.dart';
import '../../../domain/models/workspace_models.dart';
import '../../../domain/websocket/websocket_transport.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/workspace_message_localizations.dart';
import '../models/request_editor_models.dart';
import '../../workspace/models/workspace_shell_models.dart';
import '../../workspace/view_models/workspace_view_model.dart';
import '../../../core/widgets/dense_controls.dart';
import 'request_editor_status.dart';

part 'request_editor_authentication.dart';
part 'request_editor_body.dart';
part 'request_editor_chrome.dart';
part 'request_editor_protocols_and_fields.dart';

/// 请求编辑器面板：工作区左侧固定栏，围绕当前激活的请求提供
/// URL、请求头、鉴权、请求体以及 WebSocket 协议等编辑能力。
class RequestEditorPanel extends StatelessWidget {
  /// 构建请求编辑器面板。
  const RequestEditorPanel({
    super.key,
    required this.viewModel,
    this.compact = false,
  });

  /// 视图模型：提供请求草稿的读写、发送与标签页管理等能力。
  final WorkspaceViewModel viewModel;

  /// 是否使用紧凑布局（宽度自适应）；否则固定为 [desktopWidth] 桌面宽度。
  final bool compact;

  /// 桌面端面板的固定宽度。
  static const double desktopWidth = 468;

  /// 组装整个面板的纵向布局：请求标签条、请求身份、URL 栏、缺失变量提示、
  /// 编辑模式标签与对应内容区。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final draft = viewModel.activeDraft;
    return Container(
      width: compact ? null : desktopWidth,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(right: BorderSide(color: AppColors.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RequestTabStrip(
              viewModel: viewModel,
              onClose: (tab) => _confirmClose(context, tab),
            ),
            const SizedBox(height: 12),
            _RequestIdentity(
              title: viewModel.activeRequest.name,
              path: viewModel.activeRequest.path,
              isDirty: viewModel.isRequestDirty(viewModel.activeRequest.id),
              onDiscard: () => _confirmDiscard(
                context,
                viewModel.activeRequest.id,
                viewModel.activeRequest.name,
              ),
            ),
            const SizedBox(height: 12),
            _UrlBar(
              requestId: viewModel.activeRequest.id,
              draft: draft,
              url: viewModel.activeDraftUrl,
              shortcut: viewModel.sendShortcutLabel,
              onUrlChanged: viewModel.updateActiveDraftUrl,
              onSend: viewModel.actionAvailability.canSend
                  ? () => viewModel.dispatch(
                      WorkspaceGlobalAction(
                        type: WorkspaceActionType.send,
                        source: WorkspaceActionSource.toolbar,
                      ),
                    )
                  : null,
              sendUnavailableReason:
                  viewModel.actionAvailability.sendUnavailableReason,
              webSocketState: viewModel.activeWebSocketSession.state,
              onWebSocketConnect: () {
                viewModel.connectActiveWebSocket();
              },
              onWebSocketDisconnect: () {
                viewModel.disconnectActiveWebSocket();
              },
              onRequestKindSelected: (kind) {
                if (kind.protocol != draft.protocol) {
                  viewModel.updateActiveDraftProtocol(kind.protocol);
                }
                if (kind.httpMethod != null &&
                    kind.httpMethod != draft.method) {
                  viewModel.updateActiveDraftMethod(kind.httpMethod!);
                }
              },
            ),
            if (viewModel.activeMissingVariableKeys.isNotEmpty) ...[
              const SizedBox(height: 6),
              MissingVariablesNotice(
                variables: viewModel.activeMissingVariableKeys,
                onOpenEnvironment: viewModel.openEnvironmentForActiveRequest,
              ),
            ],
            if (viewModel.activeRequestHasIgnoredEntityData) ...[
              const SizedBox(height: 6),
              _IgnoredEntityDataNotice(method: draft.method),
            ],
            const SizedBox(height: 12),
            // 按协议决定编辑标签集合：WebSocket 显示协议标签，HTTP 显示请求体标签。
            _EditorModeTabs(
              tabs: draft.protocol != ApiRequestProtocol.http
                  ? [
                      RequestEditorSection.params.id,
                      RequestEditorSection.headers.id,
                      RequestEditorSection.auth.id,
                      if (viewModel.isActiveGrpc) RequestEditorSection.body.id,
                      RequestEditorSection.protocol.id,
                    ]
                  : [
                      RequestEditorSection.params.id,
                      RequestEditorSection.headers.id,
                      RequestEditorSection.auth.id,
                      if (viewModel.activeRequestSupportsBody)
                        RequestEditorSection.body.id,
                    ],
              active: viewModel.activeRequestTab,
              onSelected: viewModel.selectRequestEditorTab,
              labelFor: (tab) => _editorTabLabel(l10n, tab),
            ),
            const SizedBox(height: 8),
            Expanded(child: _TabBody(viewModel: viewModel)),
          ],
        ),
      ),
    );
  }

  // 关闭请求标签前处理未保存更改：弹出对话框让用户选择取消 / 保存 / 丢弃。
  Future<void> _confirmClose(BuildContext context, RequestTab tab) async {
    if (!viewModel.isRequestDirty(tab.requestId)) {
      viewModel.closeRequestTab(tab.id);
      return;
    }
    final choice = await showDialog<_CloseChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).unsavedRequest),
        content: Text(
          AppLocalizations.of(context).saveRequestBeforeClose(tab.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_CloseChoice.cancel),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_CloseChoice.discard),
            child: Text(AppLocalizations.of(context).discardChanges),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_CloseChoice.save),
            child: Text(AppLocalizations.of(context).saveAndClose),
          ),
        ],
      ),
    );
    if (choice == _CloseChoice.cancel || choice == null) {
      return;
    }
    if (choice == _CloseChoice.save) {
      viewModel.saveRequest(tab.requestId);
    }
    if (choice == _CloseChoice.discard) {
      viewModel.discardRequestDraft(tab.requestId);
    }
    viewModel.closeRequestTab(tab.id);
  }

  // 丢弃未保存更改前弹出确认对话框，避免误操作丢失草稿。
  Future<void> _confirmDiscard(
    BuildContext context,
    String requestId,
    String requestName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).discardUnsavedChanges),
        content: Text(
          AppLocalizations.of(context).discardChangesForRequest(requestName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).continueEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).discardChanges),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      viewModel.discardRequestDraft(requestId);
    }
  }
}

/// 提醒用户 GET/HEAD 会保留草稿数据以便切回有 body 的方法，但发送时不会使用。
class _IgnoredEntityDataNotice extends StatelessWidget {
  /// 构造忽略数据提示条。
  const _IgnoredEntityDataNotice({required this.method});

  /// 当前请求的 HTTP 方法名（用于拼接提示文案）。
  final String method;

  /// 构建警示横幅：信息图标 + 方法相关的忽略提示文案。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.42)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 15, color: AppColors.warning),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              l10n.entityDataIgnoredForMethod(method),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// 关闭标签页对话框的三个可选结果。
