import 'package:flutter/material.dart';

import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/features/requests/output/models/response_viewer_models.dart';
import 'package:sendreq/ui/features/requests/output/widgets/response_panel_body.dart';
import 'package:sendreq/ui/features/requests/output/widgets/response_panel_grpc.dart';
import 'package:sendreq/ui/features/requests/output/widgets/response_panel_states.dart';
import 'package:sendreq/ui/features/requests/output/widgets/response_panel_summary.dart';
import 'package:sendreq/ui/shell/models/workspace_shell_models.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 响应面板：根据 ViewModel 当前状态渲染「发送中 / 出错 / 等待 / 已有结果」四种视图，
/// 结果视图下提供响应元信息、页签切换（正文/响应头/请求快照）及快捷操作。
class ResponsePanel extends StatelessWidget {
  /// 构造响应面板。
  const ResponsePanel({
    super.key,
    required this.viewModel,
    this.showEmptySendAction = false,
    this.titleOverride,
  });

  /// 工作区 ViewModel，驱动响应渲染与所有交互动作。
  final WorkspaceViewModel viewModel;

  /// 是否在「尚无响应」状态下展示「发送」入口。
  /// 窄屏单窗格工作区需要该入口；宽屏下发送由工具栏完成，故默认为 false。
  final bool showEmptySendAction;

  /// 嵌入其他工作台时允许使用更准确的详情标题。
  final String? titleOverride;

  /// 构建响应面板：响应页签条 + 对应状态区（空/发送中/错误/正文）。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final response = viewModel.response;
    // 当前 Request 的响应始终留在 Collection 内。
    final responseTabs = <ResponseTab, String>{
      ResponseTab.body: l10n.body,
      ResponseTab.headers: l10n.responseHeaders,
    };
    if (viewModel.isActiveGrpc) {
      return GrpcResponsePanel(viewModel: viewModel, title: titleOverride);
    }
    return Container(
      color: context.chakra.bg,
      child: Padding(
        padding: WorkspaceLayoutMetrics.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PanelTitle(
              title: titleOverride ?? l10n.responseTitle,
              subtitle: response == null
                  ? l10n.awaitingCurrentRequest
                  : l10n.executionResult,
              trailing: response == null
                  ? MonoText(
                      l10n.pending,
                      color: context.chakra.success,
                      size: 10,
                    )
                  : null,
            ),
            const SizedBox(height: WorkspaceLayoutMetrics.groupGap),
            // 发送中：展示进度、请求与环境信息以及取消入口。
            if (viewModel.isSending)
              Expanded(
                child: ResponseSendingState(
                  requestName: viewModel.activeRequest.name,
                  environmentName: viewModel.activeEnvironment.name,
                  onCancel: viewModel.cancelActiveRequest,
                ),
              )
            // 执行出错：展示错误详情，支持复制、重试与返回请求编辑器。
            else if (viewModel.executionError != null)
              Expanded(
                child: ResponseErrorState(
                  message: viewModel.executionError!,
                  onRetry: viewModel.retryActiveRequest,
                  onEditRequest: null,
                ),
              )
            // 尚无响应：引导发送当前 Request。
            else if (response == null)
              Expanded(
                child: ResponseAwaitingState(
                  // 仅当面板允许发送且当前状态可用时，才挂载发送回调。
                  onSend:
                      showEmptySendAction &&
                          viewModel.actionAvailability.canSend
                      ? () => viewModel.dispatch(
                          WorkspaceGlobalAction(
                            type: WorkspaceActionType.send,
                            source: WorkspaceActionSource.toolbar,
                          ),
                        )
                      : null,
                  sendUnavailableReason: showEmptySendAction
                      ? viewModel.actionAvailability.sendUnavailableReason
                      : null,
                ),
              )
            // 已有响应：展示元信息、页签与对应内容区。
            else ...[
              ResponseSummaryStrip(
                response: response,
                onDownload: viewModel.downloadResponseBody,
                onCreateMock: viewModel.createMockServerFromResponse,
                showMockAction: true,
              ),
              const SizedBox(height: WorkspaceLayoutMetrics.sectionGap),
              SegmentedTabs(
                tabs: responseTabs.values.toList(growable: false),
                active: responseTabs[viewModel.activeResponseTab]!,
                onSelected: (label) => viewModel.selectResponseTab(
                  responseTabs.entries
                      .firstWhere((entry) => entry.value == label)
                      .key,
                ),
              ),
              const SizedBox(height: WorkspaceLayoutMetrics.sectionGap),
              Expanded(
                child: viewModel.activeResponseTab == ResponseTab.headers
                    ? ResponseHeaderTable(response: response)
                    : ResponseBodyViewer(response.body),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// gRPC 调用使用独立时间线，避免将服务端流压缩为单一 HTTP 响应。
