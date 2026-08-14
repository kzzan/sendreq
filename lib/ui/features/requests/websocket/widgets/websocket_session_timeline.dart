import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:sendreq/domain/request_runtime/websocket_session_projection.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/widgets/formatted_json_viewer.dart';

// 消息时间线：按时间顺序列出收发事件；超出内存上限而被省略的旧消息以提示行占位。
class WebSocketMessageTimeline extends StatelessWidget {
  const WebSocketMessageTimeline({
    super.key,
    required this.controller,
    required this.session,
    required this.onScroll,
  });

  final ScrollController controller;
  final WebSocketSession session;
  final VoidCallback onScroll;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: WorkspaceLayoutMetrics.pagePadding,
      itemCount:
          session.events.length + (session.omittedEventCount > 0 ? 1 : 0),
      itemBuilder: (context, index) {
        if (session.omittedEventCount > 0 && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(
              bottom: WorkspaceLayoutMetrics.sectionGap,
            ),
            child: Text(
              AppLocalizations.of(
                context,
              ).earlierMessagesOmitted(session.omittedEventCount),
              style: TextStyle(color: context.chakra.fgSubtle, fontSize: 12),
            ),
          );
        }
        final offset = session.omittedEventCount > 0 ? 1 : 0;
        final event = session.events[index - offset];
        return _TimelineEvent(
          key: ValueKey(
            'websocket-event-${event.timestamp.microsecondsSinceEpoch}-${event.kind.name}',
          ),
          event: event,
        );
      },
    );
  }
}

// 单个事件采用左侧方向导轨和可点击负载区，避免长文本挤进居中的列表标题。
class _TimelineEvent extends StatefulWidget {
  const _TimelineEvent({super.key, required this.event});

  final WebSocketMessageEvent event;

  @override
  State<_TimelineEvent> createState() => _TimelineEventState();
}

class _TimelineEventState extends State<_TimelineEvent> {
  late bool _expanded;
  late FormattedJsonContent? _jsonContent;
  late String _detail;
  late bool _isStructured;

  @override
  void initState() {
    super.initState();
    _cacheEvent(resetExpansion: true);
  }

  @override
  void didUpdateWidget(covariant _TimelineEvent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.event, widget.event)) {
      _cacheEvent(resetExpansion: true);
    }
  }

  void _cacheEvent({required bool resetExpansion}) {
    _jsonContent = _timelineJsonContent(widget.event);
    _detail = _timelineDisplayDetail(widget.event, _jsonContent);
    _isStructured = _isStructuredTextEvent(widget.event, _jsonContent);
    if (resetExpansion) _expanded = _jsonContent?.isJson == true;
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final l10n = AppLocalizations.of(context);
    final direction = _timelineDirectionLabel(l10n, event);
    final kind = _timelineKindLabel(l10n, event);
    final color = _timelineEventColor(context.chakra, event);
    final detail = _detail;
    final jsonContent = _jsonContent;
    final isStructured = _isStructured;
    final eventKey =
        '${event.timestamp.microsecondsSinceEpoch}-${event.kind.name}';

    return Semantics(
      label: l10n.webSocketMessageSemantics(direction, kind, event.byteLength),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: ChakraSlotRecipes.timelineEvent(context.chakra),
        child: ClipRRect(
          borderRadius: ChakraRadii.panel,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 3,
                child: DecoratedBox(
                  decoration: ChakraSlotRecipes.timelineAccent(color),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 7, 6, 6),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: ChakraRadii.control,
                          ),
                          child: Icon(
                            _timelineDirectionIcon(event.direction),
                            size: 15,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              MonoText(
                                direction,
                                color: color,
                                size: 10,
                                weight: FontWeight.w800,
                              ),
                              Text(
                                kind,
                                style: TextStyle(
                                  color: context.chakra.fgMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              MonoText(
                                _timelineTimestamp(event.timestamp),
                                color: context.chakra.fgSubtle,
                                size: 10,
                              ),
                              MonoText(
                                l10n.byteCount(event.byteLength),
                                color: context.chakra.fgSubtle,
                                size: 10,
                              ),
                            ],
                          ),
                        ),
                        DenseIconButton(
                          key: ValueKey('websocket-event-open-$eventKey'),
                          icon: Icons.open_in_full,
                          tooltip: l10n.openWebSocketMessageDetail,
                          size: 26,
                          onPressed: () => _showMessageDetail(
                            context,
                            event: event,
                            direction: direction,
                            kind: kind,
                            detail: detail,
                            jsonContent: jsonContent,
                            color: color,
                          ),
                        ),
                        DenseIconButton(
                          key: ValueKey('websocket-event-copy-$eventKey'),
                          icon: Icons.copy_outlined,
                          tooltip: l10n.copyResponseBody,
                          size: 26,
                          onPressed: () => copyToClipboard(
                            context,
                            detail,
                            l10n.responseBodyCopied,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: context.chakra.border),
                  Material(
                    color: context.chakra.bgSubtle,
                    child: InkWell(
                      key: ValueKey('websocket-event-payload-$eventKey'),
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 9, 8, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOut,
                                alignment: Alignment.topLeft,
                                child: _expanded && jsonContent?.isJson == true
                                    ? SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: FormattedJsonTree(
                                          value: jsonContent!.value,
                                          nodeKeyPrefix:
                                              'websocket-event-json-$eventKey',
                                          textStyle: TextStyle(
                                            color: context.chakra.fg,
                                            fontFamily: 'JetBrains Mono',
                                            fontSize: 12,
                                            height: 1.45,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        detail,
                                        maxLines: _expanded
                                            ? null
                                            : isStructured
                                            ? 4
                                            : 2,
                                        overflow: _expanded
                                            ? TextOverflow.visible
                                            : TextOverflow.ellipsis,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                          color: context.chakra.fg,
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 12,
                                          height: 1.45,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Tooltip(
                                message: _expanded
                                    ? l10n.collapseWebSocketMessage
                                    : l10n.expandWebSocketMessage,
                                child: Icon(
                                  _expanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: context.chakra.fgSubtle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showMessageDetail(
  BuildContext context, {
  required WebSocketMessageEvent event,
  required String direction,
  required String kind,
  required String detail,
  required FormattedJsonContent? jsonContent,
  required Color color,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 720),
        child: SizedBox(
          width: MediaQuery.sizeOf(dialogContext).width * 0.82,
          height: MediaQuery.sizeOf(dialogContext).height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.only(left: 14, right: 6),
                decoration: BoxDecoration(
                  color: context.chakra.bgPanel,
                  border: Border(
                    bottom: BorderSide(color: context.chakra.border),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _timelineDirectionIcon(event.direction),
                      color: color,
                      size: 17,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      '$direction · $kind',
                      style: Theme.of(dialogContext).textTheme.titleSmall,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MonoText(
                        _timelineTimestamp(event.timestamp),
                        color: context.chakra.fgSubtle,
                        size: 10,
                      ),
                    ),
                    DenseIconButton(
                      icon: Icons.copy_outlined,
                      tooltip: l10n.copyResponseBody,
                      onPressed: () => copyToClipboard(
                        dialogContext,
                        detail,
                        l10n.responseBodyCopied,
                      ),
                    ),
                    DenseIconButton(
                      icon: Icons.close,
                      tooltip: l10n.closeWindow,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: context.chakra.bg,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: jsonContent?.isJson == true
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: FormattedJsonTree(
                              value: jsonContent!.value,
                              nodeKeyPrefix: 'websocket-detail-json',
                              textStyle: TextStyle(
                                color: context.chakra.fg,
                                fontFamily: 'JetBrains Mono',
                                fontSize: 13,
                                height: 1.55,
                              ),
                            ),
                          )
                        : SelectableText(
                            detail,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              color: context.chakra.fg,
                              fontFamily: 'JetBrains Mono',
                              fontSize: 13,
                              height: 1.55,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _timelineDirectionLabel(
  AppLocalizations l10n,
  WebSocketMessageEvent event,
) => switch (event.direction) {
  WebSocketFrameDirection.inbound => l10n.webSocketInbound,
  WebSocketFrameDirection.outbound => l10n.webSocketOutbound,
  WebSocketFrameDirection.system => l10n.webSocketSystem,
};

String _timelineKindLabel(AppLocalizations l10n, WebSocketMessageEvent event) =>
    switch (event.kind) {
      WebSocketFrameKind.text => l10n.webSocketTextFrame,
      WebSocketFrameKind.binary => l10n.webSocketBinaryFrame,
      WebSocketFrameKind.close => l10n.webSocketCloseFrame,
      WebSocketFrameKind.error => l10n.webSocketErrorFrame,
    };

Color _timelineEventColor(
  ChakraSemanticTokens tokens,
  WebSocketMessageEvent event,
) {
  if (event.kind == WebSocketFrameKind.error) return tokens.error;
  return switch (event.direction) {
    WebSocketFrameDirection.inbound => tokens.inbound,
    WebSocketFrameDirection.outbound => tokens.outbound,
    WebSocketFrameDirection.system => tokens.information,
  };
}

IconData _timelineDirectionIcon(WebSocketFrameDirection direction) =>
    switch (direction) {
      WebSocketFrameDirection.inbound => Icons.south_west,
      WebSocketFrameDirection.outbound => Icons.north_east,
      WebSocketFrameDirection.system => Icons.info_outline,
    };

String _timelineTimestamp(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}.${value.millisecond.toString().padLeft(3, '0')}';
}

bool _isStructuredTextEvent(
  WebSocketMessageEvent event,
  FormattedJsonContent? jsonContent,
) {
  final value = event.textPayload?.trimLeft();
  if (value == null) return false;
  if (value.startsWith('<')) return true;
  return jsonContent?.isJson == true;
}

FormattedJsonContent? _timelineJsonContent(WebSocketMessageEvent event) {
  final text = event.textPayload;
  return text == null ? null : FormattedJsonContent.parse(text);
}

/// 返回适合阅读与复制的原始负载；JSON 只做缩进，不再包裹额外元数据。
String _timelineDisplayDetail(
  WebSocketMessageEvent event,
  FormattedJsonContent? jsonContent,
) {
  if (event.binaryPayload case final bytes?) {
    return base64Encode(bytes);
  }
  if (event.textPayload case final text?) {
    return jsonContent?.isJson == true ? jsonContent!.formatted : text;
  }
  return event.preview;
}
