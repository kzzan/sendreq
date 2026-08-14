import 'package:flutter/material.dart';

import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/domain/request_runtime/websocket_session_projection.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/l10n/workspace_message_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';

/// 固定尺寸的端点执行按钮，覆盖 HTTP、WebSocket 与 gRPC 状态。
class EndpointActionSlot extends StatelessWidget {
  const EndpointActionSlot({
    super.key,
    required this.protocol,
    required this.sendUnavailableReason,
    required this.onSend,
    required this.webSocketState,
    required this.onWebSocketConnect,
    required this.onWebSocketDisconnect,
    required this.grpcClientStreaming,
    required this.grpcCommand,
    required this.compact,
  });

  final ApiRequestProtocol protocol;
  final String? sendUnavailableReason;
  final VoidCallback? onSend;
  final WebSocketConnectionState webSocketState;
  final VoidCallback onWebSocketConnect;
  final VoidCallback onWebSocketDisconnect;
  final bool grpcClientStreaming;
  final GrpcCallCommand? grpcCommand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isWebSocket = protocol == ApiRequestProtocol.webSocket;
    final connecting =
        webSocketState == WebSocketConnectionState.connecting ||
        webSocketState == WebSocketConnectionState.closing;
    final connected = webSocketState == WebSocketConnectionState.connected;
    final label = isWebSocket
        ? connected
              ? AppLocalizations.of(context).disconnect
              : AppLocalizations.of(context).connect
        : protocol == ApiRequestProtocol.grpc
        ? switch (grpcCommand) {
            GrpcCallCommand.restart => AppLocalizations.of(
              context,
            ).restartGrpcCall,
            GrpcCallCommand.cancel => AppLocalizations.of(
              context,
            ).cancelGrpcCall,
            _ =>
              grpcClientStreaming
                  ? AppLocalizations.of(context).grpcStartStream
                  : 'Call',
          }
        : AppLocalizations.of(context).send;
    final icon = isWebSocket
        ? connected
              ? Icons.link_off
              : Icons.link
        : protocol == ApiRequestProtocol.grpc
        ? switch (grpcCommand) {
            GrpcCallCommand.restart => Icons.restart_alt_outlined,
            GrpcCallCommand.cancel => Icons.stop_circle_outlined,
            _ => Icons.call_made_outlined,
          }
        : Icons.play_arrow_rounded;
    final onPressed = isWebSocket
        ? connecting
              ? null
              : connected
              ? onWebSocketDisconnect
              : onWebSocketConnect
        : onSend;
    final tooltip = isWebSocket
        ? connecting
              ? AppLocalizations.of(context).connecting
              : label
        : sendUnavailableReason?.localized(AppLocalizations.of(context)) ??
              AppLocalizations.of(context).sendRequest;
    final width = compact ? 46.0 : 112.0;
    final style = ChakraRecipes.sized(
      ChakraRecipes.solidFor(context),
      minimumSize: Size(width, 36),
      maximumSize: Size(width, 36),
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 10),
    );
    final actionIcon = connecting
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 15);
    final action = compact
        ? FilledButton(style: style, onPressed: onPressed, child: actionIcon)
        : FilledButton.icon(
            style: style,
            onPressed: onPressed,
            icon: actionIcon,
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                fontSize: 13,
                height: 1.1,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          );
    return SizedBox(
      key: const Key('request-action-slot'),
      width: width,
      height: 36,
      child: Tooltip(
        key: ValueKey('request-action-tooltip-$tooltip'),
        message: tooltip,
        child: action,
      ),
    );
  }
}
