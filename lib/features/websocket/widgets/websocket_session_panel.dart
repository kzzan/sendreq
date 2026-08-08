import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/workspace_models.dart';
import '../../../domain/websocket/websocket_session_registry.dart';
import '../../../domain/websocket/websocket_transport.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/workspace_message_localizations.dart';
import '../../workspace/view_models/workspace_view_model.dart';
import '../../../core/widgets/dense_controls.dart';

/// WebSocket 会话面板：展示当前会话的连接状态、消息时间线（收发帧），
/// 以及消息输入区（JSON 格式化、Protobuf 校验、Base64 二进制）。
class WebSocketSessionPanel extends StatefulWidget {
  /// 构造 WebSocket 会话面板。
  const WebSocketSessionPanel({super.key, required this.viewModel});

  /// 视图模型：提供 WebSocket 会话的连接、断开与消息收发操作。
  final WorkspaceViewModel viewModel;

  /// 创建会话面板状态。
  @override
  State<WebSocketSessionPanel> createState() => _WebSocketSessionPanelState();
}

/// 会话面板状态：管理时间线滚动与消息输入控制器，并跟踪未读消息。
class _WebSocketSessionPanelState extends State<WebSocketSessionPanel> {
  /// 消息时间线的滚动控制器。
  final ScrollController _timelineController = ScrollController();

  /// 消息输入框的文本控制器。
  late final TextEditingController _composerController;
  // 上一帧记录的事件数量，用于感知会话新增事件。
  int _previousEventCount = 0;
  // 用户未跟随最新消息时的未读事件计数。
  int _unreadCount = 0;
  // 是否自动跟随最新消息滚动到底部。
  bool _followLatest = true;

  /// 以草稿中的当前负载初始化输入框，并监听滚动以判断是否仍跟随最新消息。
  @override
  void initState() {
    super.initState();
    // 以草稿中的当前负载初始化输入框，并监听滚动以判断是否仍跟随最新消息。
    _composerController = TextEditingController(
      text: widget.viewModel.activeWebSocketMessageDraft.payload,
    );
    _timelineController.addListener(_onTimelineScroll);
  }

  /// 外部草稿变化（如撤销）时同步输入框；会话追加事件时决定自动跟随或累计未读数。
  @override
  void didUpdateWidget(covariant WebSocketSessionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final session = widget.viewModel.activeWebSocketSession;
    final message = widget.viewModel.activeWebSocketMessageDraft;
    // 外部草稿变化（如撤销）时同步输入框，不打断用户正在编辑的内容。
    if (_composerController.text != message.payload) {
      _composerController.value = TextEditingValue(
        text: message.payload,
        selection: TextSelection.collapsed(offset: message.payload.length),
      );
    }
    // The registry can append events while the user is inspecting older frames.
    // Preserve their scroll position and expose an explicit return-to-latest action.
    // 会话可能在用户查看历史帧时追加事件：跟随模式下自动滚动到底部，
    // 否则累计未读数，由用户手动点击"回到最新"按钮。
    if (session.events.length > _previousEventCount) {
      final incoming = session.events.length - _previousEventCount;
      if (_followLatest) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
      } else {
        _unreadCount += incoming;
      }
    }
    _previousEventCount = session.events.length;
  }

  /// 释放滚动控制器与输入控制器资源。
  @override
  void dispose() {
    _timelineController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  // 平滑滚动到时间线底部。
  void _scrollToLatest() {
    if (!_timelineController.hasClients) return;
    _timelineController.animateTo(
      _timelineController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
    );
  }

  // 根据距底部的距离判断是否处于"跟随最新"状态；24px 阈值避免按钮闪烁。
  void _onTimelineScroll() {
    if (!_timelineController.hasClients) return;
    final distance =
        _timelineController.position.maxScrollExtent -
        _timelineController.offset;
    // Treat a small distance as already at the bottom to avoid button flicker
    // from sub-pixel scroll updates.
    final follow = distance < 24;
    if (_followLatest != follow) setState(() => _followLatest = follow);
  }

  // 点击"回到最新"：恢复跟随模式、清零未读数后滚动到底部。
  void _returnToLatest() {
    setState(() {
      _followLatest = true;
      _unreadCount = 0;
    });
    _scrollToLatest();
  }

  /// 构建面板：连接状态栏、消息时间线（含未读提示浮层）与消息输入区。
  @override
  Widget build(BuildContext context) {
    final session = widget.viewModel.activeWebSocketSession;
    final message = widget.viewModel.activeWebSocketMessageDraft;
    // 面板纵向结构：连接状态栏、消息时间线（含未读提示浮层）与消息输入区。
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          _ConnectionBar(viewModel: widget.viewModel, session: session),
          Expanded(
            child: Stack(
              children: [
                _MessageTimeline(
                  controller: _timelineController,
                  session: session,
                  onScroll: _onTimelineScroll,
                ),
                // 用户离开底部且存在新消息时，悬浮"回到最新"按钮。
                if (!_followLatest && _unreadCount > 0)
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: FilledButton.icon(
                      onPressed: _returnToLatest,
                      icon: const Icon(Icons.south, size: 16),
                      label: Text(
                        AppLocalizations.of(context).newMessages(_unreadCount),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _MessageComposer(
            controller: _composerController,
            viewModel: widget.viewModel,
            message: message,
            connected: session.canSend,
          ),
        ],
      ),
    );
  }
}

// 连接状态栏：状态指示灯、连接地址、错误提示与连接/断开按钮。
class _ConnectionBar extends StatelessWidget {
  /// 构造连接状态栏。
  const _ConnectionBar({required this.viewModel, required this.session});

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
    return Semantics(
      liveRegion: true,
      label: AppLocalizations.of(
        context,
      ).webSocketState(_stateLabel(context, state)),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.outline)),
        ),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: _stateColor(state),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _stateLabel(context, state),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                // 已连接后优先展示 registry 保存的脱敏端点，避免回显解析后的 Secret。
                session.endpoint ?? viewModel.activeDraftUrl,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
            if (session.errorMessage != null) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: session.errorMessage!.localized(
                  AppLocalizations.of(context),
                )!,
                child: Icon(
                  Icons.error_outline,
                  color: AppColors.danger,
                  size: 18,
                ),
              ),
            ],
            const SizedBox(width: 12),
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

  // 按连接状态返回指示灯颜色。
  Color _stateColor(WebSocketConnectionState state) => switch (state) {
    WebSocketConnectionState.connected => AppColors.success,
    WebSocketConnectionState.connecting ||
    WebSocketConnectionState.closing => AppColors.warning,
    WebSocketConnectionState.error => AppColors.danger,
    WebSocketConnectionState.disconnected => AppColors.textFaint,
  };
}

// 消息时间线：按时间顺序列出收发事件；超出内存上限而被省略的旧消息以提示行占位。
class _MessageTimeline extends StatelessWidget {
  /// 构造消息时间线。
  const _MessageTimeline({
    required this.controller,
    required this.session,
    required this.onScroll,
  });

  /// 时间线滚动控制器（由外部传入以便联动未读状态）。
  final ScrollController controller;

  /// 当前会话，提供事件列表与省略计数。
  final WebSocketSession session;

  /// 滚动位置变化回调。
  final VoidCallback onScroll;

  /// 构建消息时间线：事件列表 + 被省略旧消息的占位提示行。
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount:
          session.events.length + (session.omittedEventCount > 0 ? 1 : 0),
      itemBuilder: (context, index) {
        // 首行展示被省略的旧消息计数（内存保护），后续行按偏移取事件。
        if (session.omittedEventCount > 0 && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              AppLocalizations.of(
                context,
              ).earlierMessagesOmitted(session.omittedEventCount),
              style: TextStyle(color: AppColors.textFaint, fontSize: 12),
            ),
          );
        }
        final offset = session.omittedEventCount > 0 ? 1 : 0;
        return _TimelineEvent(event: session.events[index - offset]);
      },
    );
  }
}

// 单个消息事件行：方向、类型、字节数与负载预览，可展开查看完整内容。
class _TimelineEvent extends StatelessWidget {
  /// 构造单条消息事件行。
  const _TimelineEvent({required this.event});

  /// 事件数据，用于渲染方向、类型、字节数与负载。
  final WebSocketMessageEvent event;

  /// 构建事件行：方向/类型/字节数标题 + 可展开的完整内容。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 按方向与类型决定配色：错误红、入站绿、出站主色。
    final inbound = event.direction == WebSocketFrameDirection.inbound;
    final direction = switch (event.direction) {
      WebSocketFrameDirection.inbound => l10n.webSocketInbound,
      WebSocketFrameDirection.outbound => l10n.webSocketOutbound,
      WebSocketFrameDirection.system => l10n.webSocketSystem,
    };
    final kind = switch (event.kind) {
      WebSocketFrameKind.text => l10n.webSocketTextFrame,
      WebSocketFrameKind.binary => l10n.webSocketBinaryFrame,
      WebSocketFrameKind.close => l10n.webSocketCloseFrame,
      WebSocketFrameKind.error => l10n.webSocketErrorFrame,
    };
    final color = event.kind == WebSocketFrameKind.error
        ? AppColors.danger
        : inbound
        ? AppColors.success
        : AppColors.primary;
    final detail = event.textPayload ?? event.preview.localized(l10n)!;
    return Semantics(
      button: true,
      label: l10n.webSocketMessageSemantics(direction, kind, event.byteLength),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.outline),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Material(
          color: Colors.transparent,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            leading: Icon(
              inbound ? Icons.south_west : Icons.north_east,
              size: 17,
              color: color,
            ),
            title: Row(
              children: [
                MonoText(
                  direction,
                  color: color,
                  size: 10,
                  weight: FontWeight.w800,
                ),
                const SizedBox(width: 8),
                Text(kind, style: const TextStyle(fontSize: 12)),
                const Spacer(),
                MonoText(
                  l10n.byteCount(event.byteLength),
                  color: AppColors.textFaint,
                  size: 10,
                ),
              ],
            ),
            subtitle: Text(
              event.preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            children: [
              SelectableText(
                detail,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  color: AppColors.text,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 消息输入区：将帧类型与负载格式分离，提供适配文本和二进制协议的紧凑工作台。
class _MessageComposer extends StatelessWidget {
  /// 构造消息输入区。
  const _MessageComposer({
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
    final messageHint = !connected
        ? l10n.connectBeforeSending
        : l10n.sendWithShortcut;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
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
                    ? AppColors.primary
                    : AppColors.success,
              ),
              const SizedBox(width: 8),
              MonoText(
                message.mode.isBinary
                    ? l10n.webSocketBinaryFrame
                    : l10n.webSocketTextFrame,
                color: message.mode.isBinary
                    ? AppColors.primary
                    : AppColors.success,
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
                    color: AppColors.surfaceMid,
                    border: Border.all(color: AppColors.outline),
                    borderRadius: BorderRadius.circular(3),
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
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // 仅 JSON 模式提供格式化按钮，格式化失败以 SnackBar 提示。
              if (message.mode == WebSocketComposerMode.json)
                DenseIconButton(
                  icon: Icons.format_align_left,
                  tooltip: AppLocalizations.of(context).formatJson,
                  onPressed: () {
                    final error = viewModel.formatActiveWebSocketMessageJson();
                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            error.localized(AppLocalizations.of(context))!,
                          ),
                        ),
                      );
                    }
                  },
                ),
              Tooltip(
                message: messageHint,
                child: FilledButton(
                  onPressed: canSend
                      ? () => viewModel.sendActiveWebSocketMessage()
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(72, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
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
                  style: TextStyle(color: AppColors.textFaint, fontSize: 11),
                ),
              ),
              if (message.mode.requiresBase64)
                MonoText(
                  'BASE64',
                  color: AppColors.warning,
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
    color: AppColors.textFaint,
    size: 10,
    weight: FontWeight.w800,
  );
}
