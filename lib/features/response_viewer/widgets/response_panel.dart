import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/api_assets/api_asset_models.dart';
import '../../../domain/models/workspace_models.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/workspace_message_localizations.dart';
import '../models/response_viewer_models.dart';
import '../../workspace/models/workspace_shell_models.dart';
import '../../workspace/view_models/workspace_view_model.dart';
import '../../../core/widgets/dense_controls.dart';

part 'response_panel_body.dart';
part 'response_panel_states.dart';
part 'response_panel_summary.dart';

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

  /// 依据当前响应创建 Mock 草稿；若已有草稿先弹窗确认是否替换。
  Future<void> _createQuickMockFromResponse(BuildContext context) async {
    if (viewModel.mockDraft != null) {
      // 已有 Mock 草稿时需用户确认，避免静默覆盖。
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l10n.replaceQuickMockTitle),
            content: Text(l10n.replaceQuickMockMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.replaceQuickMock),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }
    viewModel.createMockDraft();
  }

  /// 构建响应面板：响应页签条 + 对应状态区（空/发送中/错误/正文）。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final response = viewModel.response;
    final historyRecord = viewModel.openedHistoryRecord;
    // 是否处于「查看历史执行记录快照」模式。
    final isHistorySnapshot = historyRecord != null;
    // 响应区页签集合；仅历史快照模式下才额外提供「请求快照」页。
    final responseTabs = <ResponseTab, String>{
      ResponseTab.body: l10n.body,
      ResponseTab.headers: l10n.responseHeaders,
      if (isHistorySnapshot) ResponseTab.requestSnapshot: l10n.requestSnapshot,
    };
    // 历史记录关联的原请求可能已被删除：此时可回看结果，但禁止回到请求编辑器。
    final historyRequestAvailable =
        !isHistorySnapshot ||
        (historyRecord.requestId != null &&
            viewModel.requestExists(historyRecord.requestId!));
    if (viewModel.isActiveGrpc && !isHistorySnapshot) {
      return _GrpcResponsePanel(viewModel: viewModel, title: titleOverride);
    }
    return Container(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PanelTitle(
              title: titleOverride ?? l10n.responseTitle,
              subtitle: isHistorySnapshot
                  ? l10n.executionSnapshot(
                      historyRecord.requestSnapshot?.environmentName ??
                          l10n.unknownEnvironment,
                    )
                  : response == null
                  ? l10n.awaitingCurrentRequest
                  : l10n.executionResult,
              trailing: response == null
                  ? MonoText(l10n.pending, color: AppColors.success, size: 10)
                  : null,
            ),
            const SizedBox(height: 8),
            // 发送中：展示进度、请求与环境信息以及取消入口。
            if (viewModel.isSending)
              Expanded(
                child: _SendingState(
                  requestName: viewModel.activeRequest.name,
                  environmentName: viewModel.activeEnvironment.name,
                  onCancel: viewModel.cancelActiveRequest,
                ),
              )
            // 执行出错：展示错误详情，支持复制、重试与返回请求编辑器。
            else if (viewModel.executionError != null)
              Expanded(
                child: _ErrorState(
                  message: viewModel.executionError!,
                  onRetry: isHistorySnapshot
                      ? null
                      : viewModel.retryActiveRequest,
                  onEditRequest: isHistorySnapshot
                      ? historyRequestAvailable
                            ? viewModel.openSelectedHistoryRequest
                            : null
                      : null,
                  unavailableRequestMessage:
                      isHistorySnapshot && !historyRequestAvailable
                      ? l10n.originalRequestDeleted
                      : null,
                ),
              )
            // 尚无响应：引导发送请求；历史快照模式则展示执行时请求摘要。
            else if (response == null)
              Expanded(
                child: _AwaitingState(
                  snapshot: historyRecord?.requestSnapshot,
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
              _ResponseSummaryStrip(
                response: response,
                onCreateMock: () => _createQuickMockFromResponse(context),
                onCreateDocumentation: viewModel.createDocumentationDraft,
              ),
              const SizedBox(height: 10),
              SegmentedTabs(
                tabs: responseTabs.values.toList(growable: false),
                active: responseTabs[viewModel.activeResponseTab]!,
                onSelected: (label) => viewModel.selectResponseTab(
                  responseTabs.entries
                      .firstWhere((entry) => entry.value == label)
                      .key,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child:
                    viewModel.activeResponseTab ==
                            ResponseTab.requestSnapshot &&
                        historyRecord?.requestSnapshot != null
                    ? _RequestSnapshotBlock(
                        snapshot: historyRecord!.requestSnapshot!,
                      )
                    : viewModel.activeResponseTab == ResponseTab.headers
                    ? _HeaderTable(response: response)
                    : _ResponseBodyViewer(response.body),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// gRPC 调用使用独立时间线，避免将服务端流压缩为单一 HTTP 响应。
