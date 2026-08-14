import 'package:flutter/material.dart';

import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/features/requests/editor/models/request_editor_models.dart';
import 'package:sendreq/ui/shell/models/workspace_shell_models.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_status.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_chrome.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_mode_tabs.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_protocols_and_fields.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_request_tabs.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_url_bar.dart';

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
        color: context.chakra.bg,
        border: Border(right: BorderSide(color: context.chakra.border)),
      ),
      child: Padding(
        padding: WorkspaceLayoutMetrics.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RequestTabStrip(
              viewModel: viewModel,
              onClose: (tab) => _confirmClose(context, tab),
            ),
            const SizedBox(height: WorkspaceLayoutMetrics.sectionGap),
            RequestIdentity(
              title: viewModel.activeRequest.name,
              path: viewModel.activeRequest.path,
              isDirty: viewModel.isRequestDirty(viewModel.activeRequest.id),
              onDiscard: () => _confirmDiscard(
                context,
                viewModel.activeRequest.id,
                viewModel.activeRequest.name,
              ),
            ),
            const SizedBox(height: WorkspaceLayoutMetrics.sectionGap),
            RequestUrlBar(
              requestId: viewModel.activeRequest.id,
              draft: draft,
              url: viewModel.activeDraftUrl,
              onUrlChanged: viewModel.updateActiveDraftUrl,
              onSend: viewModel.isActiveGrpc
                  ? switch (viewModel.activeGrpcPrimaryCommand) {
                      GrpcCallCommand.start =>
                        viewModel.actionAvailability.canSend
                            ? viewModel.sendActiveGrpcRequest
                            : null,
                      GrpcCallCommand.restart =>
                        viewModel.restartActiveGrpcCall,
                      GrpcCallCommand.cancel => viewModel.cancelActiveRequest,
                      _ => null,
                    }
                  : viewModel.actionAvailability.canSend
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
              grpcClientStreaming:
                  viewModel.activeGrpcMethod?.clientStreaming ?? false,
              grpcCommand: viewModel.activeGrpcPrimaryCommand,
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
                onOpenEnvironment: viewModel.openEnvironmentManager,
              ),
            ],
            if (viewModel.activeRequestHasIgnoredEntityData) ...[
              const SizedBox(height: 6),
              _IgnoredEntityDataNotice(method: draft.method),
            ],
            const SizedBox(height: WorkspaceLayoutMetrics.sectionGap),
            // 按协议决定编辑标签集合：WebSocket 显示协议标签，HTTP 显示请求体标签。
            EditorModeTabs(
              tabs: draft.protocol == ApiRequestProtocol.http
                  ? [
                      RequestEditorSection.params.id,
                      RequestEditorSection.headers.id,
                      RequestEditorSection.auth.id,
                      if (viewModel.activeRequestSupportsBody)
                        RequestEditorSection.body.id,
                    ]
                  : draft.protocol == ApiRequestProtocol.grpc
                  ? [
                      RequestEditorSection.body.id,
                      RequestEditorSection.headers.id,
                      RequestEditorSection.auth.id,
                      RequestEditorSection.protocol.id,
                    ]
                  : [
                      RequestEditorSection.params.id,
                      RequestEditorSection.headers.id,
                      RequestEditorSection.auth.id,
                      RequestEditorSection.protocol.id,
                    ],
              active: viewModel.activeRequestTab,
              onSelected: viewModel.selectRequestEditorTab,
              labelFor: (tab) =>
                  editorTabLabel(l10n, tab, protocol: draft.protocol),
            ),
            const SizedBox(height: WorkspaceLayoutMetrics.groupGap),
            Expanded(child: RequestTabBody(viewModel: viewModel)),
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
    final choice = await showDialog<RequestCloseChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).unsavedRequest),
        content: Text(
          AppLocalizations.of(context).saveRequestBeforeClose(tab.title),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(RequestCloseChoice.cancel),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(RequestCloseChoice.discard),
            child: Text(AppLocalizations.of(context).discardChanges),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(RequestCloseChoice.save),
            child: Text(AppLocalizations.of(context).saveAndClose),
          ),
        ],
      ),
    );
    if (choice == RequestCloseChoice.cancel || choice == null) {
      return;
    }
    if (choice == RequestCloseChoice.save) {
      viewModel.saveRequest(tab.requestId);
    }
    if (choice == RequestCloseChoice.discard) {
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
        color: context.chakra.warning.withValues(alpha: 0.10),
        border: Border.all(
          color: context.chakra.warning.withValues(alpha: 0.42),
        ),
        borderRadius: ChakraRadii.control,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 15, color: context.chakra.warning),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              l10n.entityDataIgnoredForMethod(method),
              style: TextStyle(color: context.chakra.fgMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// 关闭标签页对话框的三个可选结果。
