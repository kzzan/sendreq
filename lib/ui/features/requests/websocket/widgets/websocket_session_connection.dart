import 'package:flutter/material.dart';

import 'package:sendreq/domain/request_runtime/websocket_session_projection.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/widgets/protocol_workspace_primitives.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

// 连接状态栏：状态指示灯、连接地址、错误提示与连接/断开按钮。
class WebSocketConnectionBar extends StatelessWidget {
  /// 构造连接状态栏。
  const WebSocketConnectionBar({
    super.key,
    required this.viewModel,
    required this.session,
  });

  // 视图模型：提供连接与断开操作。
  final WorkspaceViewModel viewModel;
  // 当前会话：用于读取连接状态与错误信息。
  final WebSocketSession session;

  /// 构建连接状态栏：状态指示灯、地址、错误提示与连接/断开按钮。
  @override
  Widget build(BuildContext context) {
    final state = session.state;
    // 连接中或关闭中视为"进行中"状态：按钮禁用并显示进度指示。
    final connecting =
        state == WebSocketConnectionState.connecting ||
        state == WebSocketConnectionState.closing;
    final isConnected = state == WebSocketConnectionState.connected;
    return Column(
      children: [
        ProtocolStatusBar(
          label: _stateLabel(context, state),
          detail: session.endpoint ?? viewModel.activeDraftUrl,
          tone: _protocolTone(state),
        ),
        Container(
          padding: WorkspaceLayoutMetrics.panelPadding,
          decoration: BoxDecoration(
            color: context.chakra.bgPanel,
            border: Border(bottom: BorderSide(color: context.chakra.border)),
          ),
          child: Wrap(
            spacing: WorkspaceLayoutMetrics.sectionGap,
            runSpacing: WorkspaceLayoutMetrics.groupGap,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SessionContextChip(
                icon: Icons.layers_outlined,
                label: session.requiresReconnect
                    ? AppLocalizations.of(context).currentSessionEnvironment(
                        session.sessionContext.environmentName,
                      )
                    : session.sessionContext.environmentName,
              ),
              if (session.requiresReconnect)
                _SessionContextChip(
                  icon: Icons.next_plan_outlined,
                  label: AppLocalizations.of(
                    context,
                  ).nextCallEnvironment(viewModel.activeEnvironment.name),
                  warning: true,
                ),
              _SessionContextChip(
                icon: Icons.verified_user_outlined,
                label: session.sessionContext.authenticationLabel,
              ),
              if (session.requiresReconnect)
                _SessionContextChip(
                  icon: Icons.restart_alt_outlined,
                  label: AppLocalizations.of(context).reconnectToApplyChanges,
                  warning: true,
                ),
              if (session.errorMessage != null) ...[
                const SizedBox(width: WorkspaceLayoutMetrics.sectionGap),
                Icon(
                  Icons.error_outline,
                  color: context.chakra.error,
                  size: 18,
                ),
                TextButton.icon(
                  key: const Key('websocket-copy-error'),
                  onPressed: () => copyToClipboard(
                    context,
                    session.errorMessage!,
                    AppLocalizations.of(context).errorDetailsCopied,
                  ),
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: Text(AppLocalizations.of(context).copyErrorDetails),
                ),
              ],
              // 已连接时提供断开按钮，未连接时提供连接按钮（进行中禁用）。
              if (isConnected)
                OutlinedButton.icon(
                  onPressed: () => viewModel.disconnectActiveWebSocket(),
                  icon: const Icon(Icons.link_off, size: 16),
                  label: Text(AppLocalizations.of(context).disconnect),
                )
              else
                FilledButton.icon(
                  onPressed: connecting
                      ? null
                      : () => viewModel.connectActiveWebSocket(),
                  icon: connecting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link, size: 16),
                  label: Text(
                    state == WebSocketConnectionState.closing
                        ? AppLocalizations.of(context).closing
                        : state == WebSocketConnectionState.connecting
                        ? AppLocalizations.of(context).connecting
                        : AppLocalizations.of(context).connect,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // 将连接状态转换为本地化文本。
  String _stateLabel(BuildContext context, WebSocketConnectionState state) =>
      switch (state) {
        WebSocketConnectionState.disconnected => AppLocalizations.of(
          context,
        ).disconnected,
        WebSocketConnectionState.connecting => AppLocalizations.of(
          context,
        ).connecting,
        WebSocketConnectionState.connected => AppLocalizations.of(
          context,
        ).connected,
        WebSocketConnectionState.closing => AppLocalizations.of(
          context,
        ).closing,
        WebSocketConnectionState.error => AppLocalizations.of(
          context,
        ).connectionError,
      };

  ProtocolTone _protocolTone(WebSocketConnectionState state) => switch (state) {
    WebSocketConnectionState.connected => ProtocolTone.success,
    WebSocketConnectionState.connecting ||
    WebSocketConnectionState.closing => ProtocolTone.progress,
    WebSocketConnectionState.error => ProtocolTone.danger,
    WebSocketConnectionState.disconnected => ProtocolTone.neutral,
  };
}

class _SessionContextChip extends StatelessWidget {
  const _SessionContextChip({
    required this.icon,
    required this.label,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
    height: 24,
    padding: const EdgeInsets.symmetric(horizontal: 7),
    decoration: BoxDecoration(
      color: (warning ? context.chakra.warning : context.chakra.bgSubtle)
          .withValues(alpha: warning ? 0.12 : 1),
      border: Border.all(
        color: (warning ? context.chakra.warning : context.chakra.border)
            .withValues(alpha: 0.7),
      ),
      borderRadius: ChakraRadii.control,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: warning ? context.chakra.warning : context.chakra.fgMuted,
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: warning ? context.chakra.warning : context.chakra.fgMuted,
            ),
          ),
        ),
      ],
    ),
  );
}
