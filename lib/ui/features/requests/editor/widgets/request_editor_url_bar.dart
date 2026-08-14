import 'package:flutter/material.dart';

import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/domain/request_runtime/websocket_session_projection.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_endpoint_action.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_request_kind.dart';

/// 请求类型、执行命令与端点输入组成的两行命令条。
class RequestUrlBar extends StatefulWidget {
  const RequestUrlBar({
    super.key,
    required this.requestId,
    required this.draft,
    required this.url,
    required this.sendUnavailableReason,
    required this.onSend,
    required this.onUrlChanged,
    required this.webSocketState,
    required this.onWebSocketConnect,
    required this.onWebSocketDisconnect,
    required this.grpcClientStreaming,
    required this.grpcCommand,
    required this.onRequestKindSelected,
  });

  final String requestId;
  final RequestDraft draft;
  final String url;
  final VoidCallback? onSend;
  final String? sendUnavailableReason;
  final ValueChanged<String> onUrlChanged;
  final WebSocketConnectionState webSocketState;
  final VoidCallback onWebSocketConnect;
  final VoidCallback onWebSocketDisconnect;
  final bool grpcClientStreaming;
  final GrpcCallCommand? grpcCommand;
  final ValueChanged<RequestKind> onRequestKindSelected;

  @override
  State<RequestUrlBar> createState() => _UrlBarState();
}

class _UrlBarState extends State<RequestUrlBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.url);
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  void _handleFocusChanged() => setState(() {});

  @override
  void didUpdateWidget(covariant RequestUrlBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text == widget.url) return;
    _controller.value = TextEditingValue(
      text: widget.url,
      selection: TextSelection.collapsed(offset: widget.url.length),
    );
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('request-url-bar'),
    height: 102,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: context.chakra.bgMuted,
      border: Border.all(color: context.chakra.border),
      borderRadius: ChakraRadii.panel,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  RequestKindSelector(
                    protocol: widget.draft.protocol,
                    method: widget.draft.method,
                    compact: compact,
                    onSelected: widget.onRequestKindSelected,
                  ),
                  const Spacer(),
                  EndpointActionSlot(
                    protocol: widget.draft.protocol,
                    sendUnavailableReason: widget.sendUnavailableReason,
                    onSend: widget.onSend,
                    webSocketState: widget.webSocketState,
                    onWebSocketConnect: widget.onWebSocketConnect,
                    onWebSocketDisconnect: widget.onWebSocketDisconnect,
                    grpcClientStreaming: widget.grpcClientStreaming,
                    grpcCommand: widget.grpcCommand,
                    compact: compact,
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            _EndpointUrlInput(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: widget.onUrlChanged,
            ),
          ],
        );
      },
    ),
  );
}

class _EndpointUrlInput extends StatelessWidget {
  const _EndpointUrlInput({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('request-url-input'),
    height: 40,
    decoration: BoxDecoration(
      color: context.chakra.bgSubtle,
      border: Border.all(
        color: focusNode.hasFocus
            ? context.chakra.colorPaletteFg
            : context.chakra.borderEmphasized,
      ),
      borderRadius: ChakraRadii.panel,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -2),
          child: SizedBox(
            height: 20,
            width: double.infinity,
            child: TextFormField(
              key: const Key('request-url-text-field'),
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: context.chakra.fg,
              ),
              strutStyle: const StrutStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                height: 1.2,
                leading: 0,
                forceStrutHeight: true,
              ),
              cursorHeight: 18,
              maxLines: 1,
              scrollPadding: EdgeInsets.zero,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'https://api.example.com/...',
                hintStyle: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  color: context.chakra.fgSubtle,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
