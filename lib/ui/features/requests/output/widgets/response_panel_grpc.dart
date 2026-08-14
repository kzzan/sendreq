import 'package:flutter/material.dart';

import 'package:sendreq/domain/request_runtime/grpc_session_projection.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/widgets/formatted_json_viewer.dart';
import 'package:sendreq/ui/core/widgets/protocol_workspace_primitives.dart';
import 'package:sendreq/ui/features/requests/output/widgets/grpc_session_snapshot_strip.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// gRPC 调用的状态栏与事件时间线，独立于单次 HTTP 响应摘要。
class GrpcResponsePanel extends StatelessWidget {
  const GrpcResponsePanel({super.key, required this.viewModel, this.title});

  final WorkspaceViewModel viewModel;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final call = viewModel.activeGrpcCall;
    return Container(
      color: context.chakra.bg,
      padding: WorkspaceLayoutMetrics.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtocolStatusBar(
            label: _grpcStateLabel(l10n, call.state.name),
            detail: call.endpoint ?? l10n.grpcResponseTitle,
            tone: _grpcTone(call.state.name),
          ),
          const SizedBox(height: 8),
          PanelTitle(
            title: title ?? l10n.grpcResponseTitle,
            subtitle: _grpcSubtitle(
              l10n,
              call.state.name,
              call.clientStreaming,
              call.requestStreamOpen,
            ),
          ),
          const SizedBox(height: 8),
          GrpcSessionSnapshotStrip(
            call: call,
            nextEnvironmentName: viewModel.activeEnvironment.name,
          ),
          if (call.omittedEventCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.earlierGrpcEventsOmitted(call.omittedEventCount),
                style: TextStyle(color: context.chakra.fgMuted, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: call.events.isEmpty
                ? _GrpcEmptyState(
                    errorMessage: call.errorMessage,
                    awaitingMessage: l10n.awaitingGrpcResponse,
                  )
                : ListView.separated(
                    itemCount: call.events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final event = call.events[index];
                      return _GrpcTimelineEvent(
                        key: ValueKey(event),
                        event: event,
                        viewModel: viewModel,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

ProtocolTone _grpcTone(String state) => switch (state) {
  'running' || 'connecting' => ProtocolTone.progress,
  'completed' => ProtocolTone.success,
  'error' => ProtocolTone.danger,
  'cancelled' || 'cancelling' => ProtocolTone.warning,
  _ => ProtocolTone.neutral,
};

String _grpcStateLabel(AppLocalizations l10n, String state) => switch (state) {
  'connecting' => l10n.grpcStateStarting,
  'running' => l10n.grpcStateRunning,
  'completed' => l10n.grpcStateCompleted,
  'cancelling' => l10n.grpcStateCancelling,
  'cancelled' => l10n.grpcStateCancelled,
  'error' => l10n.grpcStateFailed,
  _ => l10n.grpcStateIdle,
};

String _grpcSubtitle(
  AppLocalizations l10n,
  String state,
  bool clientStreaming,
  bool requestStreamOpen,
) => clientStreaming
    ? '${_grpcStateLabel(l10n, state)}  ${requestStreamOpen ? l10n.grpcRequestStreamOpen : l10n.grpcRequestStreamClosed}'
    : _grpcStateLabel(l10n, state);

class _GrpcEmptyState extends StatelessWidget {
  const _GrpcEmptyState({
    required this.errorMessage,
    required this.awaitingMessage,
  });

  final String? errorMessage;
  final String awaitingMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (errorMessage == null) {
      return Center(
        child: Text(
          awaitingMessage,
          style: TextStyle(color: context.chakra.fgMuted),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.chakra.error),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('grpc-copy-error'),
            onPressed: () => copyToClipboard(
              context,
              errorMessage!,
              l10n.errorDetailsCopied,
            ),
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: Text(l10n.copyErrorDetails),
          ),
        ],
      ),
    );
  }
}

class _GrpcTimelineEvent extends StatefulWidget {
  const _GrpcTimelineEvent({
    super.key,
    required this.event,
    required this.viewModel,
  });

  final GrpcCallEvent event;
  final WorkspaceViewModel viewModel;

  @override
  State<_GrpcTimelineEvent> createState() => _GrpcTimelineEventState();
}

class _GrpcTimelineEventState extends State<_GrpcTimelineEvent> {
  late bool _expanded;
  late ProtobufDecodeResult? _decoded;
  late FormattedJsonContent? _jsonContent;

  @override
  void initState() {
    super.initState();
    _expanded =
        widget.event.kind == GrpcTransportEventKind.request ||
        widget.event.kind == GrpcTransportEventKind.message ||
        widget.event.kind == GrpcTransportEventKind.error;
    _decodeEvent();
  }

  @override
  void didUpdateWidget(covariant _GrpcTimelineEvent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.event, widget.event) ||
        !identical(oldWidget.viewModel, widget.viewModel)) {
      _decodeEvent();
    }
  }

  void _decodeEvent() {
    _decoded = widget.viewModel.decodeActiveGrpcEvent(widget.event);
    final json = _decoded?.isSuccess == true ? _decoded!.formattedJson : null;
    _jsonContent = json == null ? null : FormattedJsonContent.parse(json);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final event = widget.event;
    final decoded = _decoded;
    final visual = _grpcEventVisual(context.chakra, l10n, event);
    final json = decoded?.isSuccess == true ? decoded!.formattedJson : null;
    final jsonContent = _jsonContent;
    final detail =
        json ??
        decoded?.error ??
        event.statusMessage ??
        (event.metadata.isEmpty
            ? l10n.byteCount(event.byteLength)
            : event.metadata.entries
                  .map((item) => '${item.key}: ${item.value}')
                  .join('\n'));
    final detailColor =
        decoded?.isSuccess == false ||
            event.kind == GrpcTransportEventKind.error
        ? context.chakra.error
        : context.chakra.fg;
    return Container(
      decoration: ChakraSlotRecipes.timelineEvent(context.chakra),
      child: ClipRRect(
        borderRadius: ChakraRadii.control,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: DecoratedBox(
                decoration: ChakraSlotRecipes.timelineAccent(visual.color),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 9, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DenseIconButton(
                            key: ValueKey(
                              'grpc-event-toggle-${event.timestamp.microsecondsSinceEpoch}-${event.kind.name}',
                            ),
                            icon: _expanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_right_rounded,
                            tooltip: _expanded
                                ? l10n.collapseJsonNode
                                : l10n.expandJsonNode,
                            size: 26,
                            onPressed: () =>
                                setState(() => _expanded = !_expanded),
                          ),
                          const SizedBox(width: 2),
                          Icon(visual.icon, color: visual.color, size: 15),
                          const SizedBox(width: 6),
                          _GrpcEventPill(
                            label: visual.label,
                            color: visual.color,
                          ),
                        ],
                      ),
                      MonoText(
                        _grpcTimestamp(event.timestamp),
                        color: context.chakra.fgSubtle,
                        size: 10,
                      ),
                      MonoText(
                        l10n.byteCount(event.byteLength),
                        color: context.chakra.fgSubtle,
                        size: 10,
                      ),
                      DenseIconButton(
                        key: ValueKey(
                          'grpc-event-copy-${event.timestamp.microsecondsSinceEpoch}-${event.kind.name}',
                        ),
                        icon: Icons.copy_outlined,
                        tooltip: l10n.copyResponseBody,
                        size: 26,
                        showTooltip: false,
                        onPressed: () => copyToClipboard(
                          context,
                          detail,
                          l10n.responseBodyCopied,
                        ),
                      ),
                    ],
                  ),
                  if (_expanded) const SizedBox(height: 8),
                  if (_expanded)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: ChakraSlotRecipes.codeSurface(context.chakra),
                      child: jsonContent?.isJson != true
                          ? Text(
                              detail,
                              style: TextStyle(
                                color: detailColor,
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                                height: 1.5,
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: FormattedJsonTree(
                                value: jsonContent!.value,
                                nodeKeyPrefix:
                                    'grpc-event-${event.timestamp.microsecondsSinceEpoch}',
                                textStyle: TextStyle(
                                  color: context.chakra.fg,
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrpcEventPill extends StatelessWidget {
  const _GrpcEventPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 20,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      border: Border.all(color: color.withValues(alpha: 0.52)),
      borderRadius: ChakraRadii.control,
    ),
    child: MonoText(
      label.toUpperCase(),
      color: color,
      size: 9,
      weight: FontWeight.w700,
    ),
  );
}

class _GrpcEventVisual {
  const _GrpcEventVisual({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}

_GrpcEventVisual _grpcEventVisual(
  ChakraSemanticTokens tokens,
  AppLocalizations l10n,
  GrpcCallEvent event,
) => switch (event.kind) {
  GrpcTransportEventKind.request => _GrpcEventVisual(
    label: l10n.grpcEventSent,
    color: tokens.success,
    icon: Icons.north_east,
  ),
  GrpcTransportEventKind.message => _GrpcEventVisual(
    label: l10n.grpcEventReceived,
    color: tokens.methodGet,
    icon: Icons.south_west,
  ),
  GrpcTransportEventKind.headers => _GrpcEventVisual(
    label: l10n.grpcEventHeaders,
    color: tokens.warning,
    icon: Icons.vertical_align_top,
  ),
  GrpcTransportEventKind.trailers => _GrpcEventVisual(
    label: l10n.grpcEventTrailers,
    color: tokens.warning,
    icon: Icons.vertical_align_bottom,
  ),
  GrpcTransportEventKind.status => _GrpcEventVisual(
    label: l10n.grpcEventStatus,
    color: event.statusCode == 0 ? tokens.success : tokens.error,
    icon: event.statusCode == 0
        ? Icons.check_circle_outline
        : Icons.error_outline,
  ),
  GrpcTransportEventKind.error => _GrpcEventVisual(
    label: l10n.grpcEventError,
    color: tokens.error,
    icon: Icons.error_outline,
  ),
};

String _grpcTimestamp(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}.${value.millisecond.toString().padLeft(3, '0')}';
}
