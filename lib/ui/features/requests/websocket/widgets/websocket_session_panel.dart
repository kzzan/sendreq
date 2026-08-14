import 'package:flutter/material.dart';

import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/ui/features/requests/websocket/widgets/websocket_session_composer.dart';
import 'package:sendreq/ui/features/requests/websocket/widgets/websocket_session_connection.dart';
import 'package:sendreq/ui/features/requests/websocket/widgets/websocket_session_timeline.dart';

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
    // 用户在查看历史帧时，注册表仍可能追加事件。
    // 此时保留滚动位置，并提供显式的"回到最新"操作。
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
    // 距离很小时视为已到底部，避免亚像素滚动更新导致按钮闪烁。
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
      color: context.chakra.bg,
      child: Column(
        children: [
          WebSocketConnectionBar(viewModel: widget.viewModel, session: session),
          Expanded(
            child: Stack(
              children: [
                WebSocketMessageTimeline(
                  controller: _timelineController,
                  session: session,
                  onScroll: _onTimelineScroll,
                ),
                // 用户离开底部且存在新消息时，悬浮"回到最新"按钮。
                if (!_followLatest && _unreadCount > 0)
                  Positioned(
                    right: WorkspaceLayoutMetrics.pagePadding.left,
                    bottom: WorkspaceLayoutMetrics.pagePadding.bottom,
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
          WebSocketMessageComposer(
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
