import 'package:flutter/material.dart';

import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/features/requests/collection/widgets/collection_panel.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_panel.dart';
import 'package:sendreq/ui/features/requests/environment/manager/widgets/environment_panel.dart';
import 'package:sendreq/ui/features/requests/output/widgets/response_panel.dart';
import 'package:sendreq/ui/features/requests/websocket/widgets/websocket_session_panel.dart';
import 'package:sendreq/ui/shell/application/workspace_startup_recovery.dart';
import 'package:sendreq/ui/shell/models/workspace_shell_models.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 宽屏 Requests 保持原工作面可见，并在右侧覆盖局部 Environment 管理抽屉。
class RequestWorkspaceWithEnvironmentDrawer extends StatelessWidget {
  const RequestWorkspaceWithEnvironmentDrawer({
    super.key,
    required this.viewModel,
    required this.onCloseEnvironment,
  });

  final WorkspaceViewModel viewModel;
  final VoidCallback onCloseEnvironment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final drawerWidth = (constraints.maxWidth * 0.66)
          .clamp(680.0, 840.0)
          .toDouble();
      return Stack(
        children: [
          Positioned.fill(
            child: Row(
              key: const Key('collection-desktop-workspace'),
              children: [
                CollectionPanel(viewModel: viewModel),
                RequestEditorPanel(viewModel: viewModel),
                Expanded(
                  child: viewModel.isActiveWebSocket
                      ? WebSocketSessionPanel(viewModel: viewModel)
                      : ResponsePanel(viewModel: viewModel),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              key: const Key('environment-manage-scrim'),
              behavior: HitTestBehavior.opaque,
              onTap: onCloseEnvironment,
              child: ColoredBox(
                color: context.chakra.bg.withValues(alpha: 0.48),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              key: const Key('environment-manage-drawer'),
              width: drawerWidth,
              height: double.infinity,
              decoration: ChakraSlotRecipes.drawer(context.chakra),
              child: Material(
                color: context.chakra.transparent,
                child: EnvironmentPanel(
                  viewModel: viewModel,
                  onCloseRequested: onCloseEnvironment,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// 空集合工作区：左侧集合树 + 右侧引导创建首个请求的空状态。
class EmptyCollectionsWorkspace extends StatelessWidget {
  /// 构造空集合工作区。
  const EmptyCollectionsWorkspace({super.key, required this.viewModel});

  /// 共享的工作区 ViewModel。
  final WorkspaceViewModel viewModel;

  /// 构建空集合引导界面。
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final prompt = _EmptyRequestPrompt(viewModel: viewModel);
      if (constraints.maxWidth < 600) return prompt;
      return Row(
        children: [
          CollectionPanel(viewModel: viewModel),
          Expanded(child: prompt),
        ],
      );
    },
  );
}

class _EmptyRequestPrompt extends StatelessWidget {
  const _EmptyRequestPrompt({required this.viewModel});

  final WorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('requests-empty-state'),
      color: context.chakra.bg,
      padding: WorkspaceLayoutMetrics.pagePadding,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            size: 28,
            color: context.chakra.fgSubtle,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.noRequestsYet,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.createRequestToStart,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.chakra.fgMuted),
          ),
          const SizedBox(height: 14),
          if (viewModel.requestWorkingProtocol case final protocol?)
            OutlinedButton.icon(
              onPressed: () => viewModel.createRequest(protocol: protocol),
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.newRequest),
            )
          else
            PopupMenuButton<ApiRequestProtocol>(
              key: const Key('empty-new-request-type-menu'),
              tooltip: l10n.newRequest,
              onSelected: (protocol) =>
                  viewModel.createRequest(protocol: protocol),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: ApiRequestProtocol.http,
                  child: Text(l10n.restRequests),
                ),
                PopupMenuItem(
                  value: ApiRequestProtocol.webSocket,
                  child: Text(l10n.webSocketRequests),
                ),
                PopupMenuItem(
                  value: ApiRequestProtocol.grpc,
                  child: Text(l10n.grpcRequests),
                ),
              ],
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.add, size: 16),
                label: Text(l10n.newRequest),
              ),
            ),
        ],
      ),
    );
  }
}

/// 窄屏（<980px）下的单窗格请求工作区：顶部分页在集合/请求/响应间切换。
class NarrowRequestWorkspace extends StatelessWidget {
  /// 构造窄屏请求工作区。
  const NarrowRequestWorkspace({super.key, required this.viewModel});

  /// 共享的工作区 ViewModel。
  final WorkspaceViewModel viewModel;

  /// 构建窄屏单窗格工作区界面。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const Key('collection-narrow-workspace'),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // 三个页签在最窄视口均分可用空间，宽屏则保持稳定的工具型宽度。
            final tabWidth = ((constraints.maxWidth - 36) / 3)
                .clamp(0, 92.0)
                .toDouble();
            return Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.chakra.border),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: tabWidth,
                    child: _NarrowPanelTab(
                      label: l10n.collections,
                      selected:
                          viewModel.narrowWorkspacePanel ==
                          NarrowWorkspacePanel.collections,
                      onTap: () => viewModel.selectNarrowWorkspacePanel(
                        NarrowWorkspacePanel.collections,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: tabWidth,
                    child: _NarrowPanelTab(
                      label: l10n.request,
                      selected:
                          viewModel.narrowWorkspacePanel ==
                          NarrowWorkspacePanel.request,
                      onTap: () => viewModel.selectNarrowWorkspacePanel(
                        NarrowWorkspacePanel.request,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: tabWidth,
                    child: _NarrowPanelTab(
                      label: l10n.response,
                      selected:
                          viewModel.narrowWorkspacePanel ==
                          NarrowWorkspacePanel.response,
                      onTap: () => viewModel.selectNarrowWorkspacePanel(
                        NarrowWorkspacePanel.response,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // 根据当前选中的窄屏页签渲染对应面板；响应页额外允许空状态发送。
        Expanded(
          child: switch (viewModel.narrowWorkspacePanel) {
            NarrowWorkspacePanel.collections => CollectionPanel(
              viewModel: viewModel,
              expandToFill: true,
            ),
            NarrowWorkspacePanel.request => RequestEditorPanel(
              viewModel: viewModel,
              compact: true,
            ),
            NarrowWorkspacePanel.response => ResponsePanel(
              viewModel: viewModel,
              showEmptySendAction: true,
            ),
          },
        ),
      ],
    );
  }
}

/// 窄屏工作区的页签按钮，选中态用主色与描边高亮。
class _NarrowPanelTab extends StatelessWidget {
  /// 构造页签按钮。
  const _NarrowPanelTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// 页签显示文本。
  final String label;

  /// 是否处于选中态。
  final bool selected;

  /// 点击回调。
  final VoidCallback onTap;

  /// 构建页签按钮界面。
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: ChakraRecipes.sized(
        ChakraRecipes.selectableFor(context, selected: selected),
        minimumSize: const Size(0, 28),
      ),
      child: Text(label),
    );
  }
}

/// 顶部恢复带只在启动持久化未完成时出现，保留工作区空间并使恢复动作随时可见。
class StartupRecoveryBanner extends StatelessWidget {
  /// 构造启动恢复提示带。
  const StartupRecoveryBanner({super.key, required this.recovery});

  /// 启动恢复端口，用于展示状态与触发重试。
  final WorkspaceStartupRecovery recovery;

  /// 构建恢复提示带界面。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.chakra.bgSubtle,
        border: Border(
          bottom: BorderSide(
            color: context.chakra.warning.withValues(alpha: .42),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.storage_rounded, color: context.chakra.warning, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.startupRecoveryTitle,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.chakra.fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.startupRecoveryDescription,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.chakra.fgMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          TextButton.icon(
            onPressed: recovery.isRetrying ? null : recovery.retry,
            icon: recovery.isRetrying
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
