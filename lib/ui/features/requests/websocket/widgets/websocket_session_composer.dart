import 'package:flutter/material.dart';

import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/l10n/workspace_message_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/application/user_message.dart';
import 'package:sendreq/ui/core/widgets/user_message_scope.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

// 消息输入区：将帧类型与负载格式分离，提供适配文本和二进制协议的紧凑工作台。
class WebSocketMessageComposer extends StatelessWidget {
  /// 构造消息输入区。
  const WebSocketMessageComposer({
    super.key,
    required this.controller,
    required this.viewModel,
    required this.message,
    required this.connected,
  });

  /// 输入框文本控制器。
  final TextEditingController controller;

  /// 视图模型，提供发送、格式化与 Protobuf 预览能力。
  final WorkspaceViewModel viewModel;

  /// 当前待发送的消息草稿。
  final WebSocketMessageDraft message;

  /// 是否已连接（未连接时禁止发送）。
  final bool connected;

  /// 构建消息输入区：格式菜单、负载编辑器、编码状态和发送操作。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSend = connected;
    final messageHint = !connected ? l10n.connectBeforeSending : l10n.send;
    return Container(
      padding: WorkspaceLayoutMetrics.panelPadding,
      decoration: BoxDecoration(
        color: context.chakra.bgPanel,
        border: Border(top: BorderSide(color: context.chakra.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                message.mode.isBinary ? Icons.data_object : Icons.subject,
                size: 16,
                color: message.mode.isBinary
                    ? context.chakra.colorPaletteFg
                    : context.chakra.success,
              ),
              const SizedBox(width: 8),
              MonoText(
                message.mode.isBinary
                    ? l10n.webSocketBinaryFrame
                    : l10n.webSocketTextFrame,
                color: message.mode.isBinary
                    ? context.chakra.colorPaletteFg
                    : context.chakra.success,
                size: 10,
                weight: FontWeight.w800,
              ),
              const SizedBox(width: 8),
              PopupMenuButton<WebSocketComposerMode>(
                tooltip: l10n.webSocketMessageFormat,
                onSelected: viewModel.updateActiveWebSocketMessageMode,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: _FormatMenuHeading(l10n.webSocketTextFrameHeading),
                  ),
                  for (final mode in [
                    WebSocketComposerMode.text,
                    WebSocketComposerMode.json,
                    WebSocketComposerMode.xml,
                  ])
                    PopupMenuItem(value: mode, child: Text(mode.label)),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    enabled: false,
                    child: _FormatMenuHeading(l10n.webSocketBinaryFrameHeading),
                  ),
                  for (final mode in [WebSocketComposerMode.messagePack])
                    PopupMenuItem(value: mode, child: Text(mode.label)),
                ],
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  decoration: BoxDecoration(
                    color: context.chakra.bgMuted,
                    border: Border.all(color: context.chakra.border),
                    borderRadius: ChakraRadii.control,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.mode.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: context.chakra.fgMuted,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // 仅 JSON 模式提供格式化按钮，命令结果进入统一消息通知。
              if (message.mode == WebSocketComposerMode.json)
                DenseIconButton(
                  icon: Icons.format_align_left,
                  tooltip: AppLocalizations.of(context).formatJson,
                  onPressed: () {
                    final error = viewModel.formatActiveWebSocketMessageJson();
                    if (error != null) {
                      publishUserMessage(
                        context,
                        error.localized(AppLocalizations.of(context))!,
                        severity: UserMessageSeverity.warning,
                        deduplicationKey: 'websocket.message.format.failed',
                      );
                    }
                  },
                ),
              Tooltip(
                key: ValueKey('websocket-send-tooltip-$messageHint'),
                message: messageHint,
                child: FilledButton(
                  onPressed: canSend
                      ? () => viewModel.sendActiveWebSocketMessage()
                      : null,
                  style: ChakraRecipes.sized(
                    ChakraRecipes.solidFor(context),
                    minimumSize: const Size(72, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Icon(Icons.send, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            onChanged: viewModel.updateActiveWebSocketMessage,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.all(10),
              hintText: message.mode.inputHint,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  message.mode.requiresBase64
                      ? l10n.pasteSerializedMessageBase64(message.mode.label)
                      : messageHint,
                  style: TextStyle(
                    color: context.chakra.fgSubtle,
                    fontSize: 11,
                  ),
                ),
              ),
              if (message.mode.requiresBase64)
                MonoText(
                  'BASE64',
                  color: context.chakra.warning,
                  size: 10,
                  weight: FontWeight.w800,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 格式选择菜单的分组标题，帮助用户区分 WebSocket 的两种数据帧。
class _FormatMenuHeading extends StatelessWidget {
  const _FormatMenuHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => MonoText(
    label,
    color: context.chakra.fgSubtle,
    size: 10,
    weight: FontWeight.w800,
  );
}
