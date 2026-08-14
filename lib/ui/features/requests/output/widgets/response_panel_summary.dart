import 'package:flutter/material.dart';

import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/application/user_message.dart';
import 'package:sendreq/ui/core/widgets/user_message_scope.dart';

/// HTTP 响应的状态、指标与结果操作摘要带。
class ResponseSummaryStrip extends StatelessWidget {
  const ResponseSummaryStrip({
    super.key,
    required this.response,
    required this.onDownload,
    required this.onCreateMock,
    this.showMockAction = true,
  });

  final ResponseSnapshot response;
  final Future<String> Function(String body) onDownload;
  final VoidCallback onCreateMock;
  final bool showMockAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusColor = _responseStatusColor(
      context.chakra,
      response.statusCode,
    );
    return Container(
      key: const Key('response-summary-strip'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: context.chakra.bgMuted,
        border: Border.all(color: context.chakra.border),
        borderRadius: ChakraRadii.control,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ResponseStatusReadout(
                statusCode: response.statusCode,
                color: statusColor,
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 26, color: context.chakra.border),
              const SizedBox(width: 12),
              _ResponseMetric(
                icon: Icons.schedule_outlined,
                label: l10n.duration,
                value: '${response.timeMs} ms',
              ),
              const SizedBox(width: 14),
              _ResponseMetric(
                icon: Icons.data_usage_outlined,
                label: l10n.size,
                value: '${response.sizeKb.toStringAsFixed(1)} KB',
              ),
            ],
          );
          final actions = _ResponseSummaryActions(
            response: response,
            onDownload: onDownload,
            onCreateMock: onCreateMock,
            showMockAction: showMockAction,
          );
          return constraints.maxWidth < 440
              ? Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [details, actions],
                )
              : Row(children: [details, const Spacer(), actions]);
        },
      ),
    );
  }
}

class _ResponseSummaryActions extends StatelessWidget {
  const _ResponseSummaryActions({
    required this.response,
    required this.onDownload,
    required this.onCreateMock,
    required this.showMockAction,
  });

  final ResponseSnapshot response;
  final Future<String> Function(String body) onDownload;
  final VoidCallback onCreateMock;
  final bool showMockAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      key: const Key('response-summary-actions'),
      mainAxisSize: MainAxisSize.min,
      children: [
        DenseIconButton(
          icon: Icons.copy_outlined,
          tooltip: l10n.copyResponseBody,
          onPressed: () =>
              copyToClipboard(context, response.body, l10n.responseBodyCopied),
          size: 30,
        ),
        DenseIconButton(
          icon: Icons.download_outlined,
          tooltip: l10n.downloadResponseBody,
          onPressed: () =>
              _downloadResponseBody(context, onDownload, response.body),
          size: 30,
        ),
        if (showMockAction) ...[
          DenseIconButton(
            icon: Icons.dns_outlined,
            tooltip: l10n.createMock,
            onPressed: onCreateMock,
            size: 30,
          ),
        ],
      ],
    );
  }
}

Future<void> _downloadResponseBody(
  BuildContext context,
  Future<String> Function(String body) onDownload,
  String body,
) async {
  try {
    final path = await onDownload(body);
    if (context.mounted) {
      publishUserMessage(
        context,
        AppLocalizations.of(context).responseSavedAt(path),
        severity: UserMessageSeverity.success,
        deduplicationKey: 'response.download.succeeded',
      );
    }
  } on Object {
    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      publishUserMessage(
        context,
        l10n.responseSaveFailed(l10n.notificationActionFailed),
        severity: UserMessageSeverity.error,
        deduplicationKey: 'response.download.failed',
      );
    }
  }
}

Color _responseStatusColor(ChakraSemanticTokens tokens, int statusCode) =>
    statusCode >= 400
    ? tokens.error
    : statusCode >= 300
    ? tokens.warning
    : tokens.success;

class _ResponseStatusReadout extends StatelessWidget {
  const _ResponseStatusReadout({required this.statusCode, required this.color});

  final int statusCode;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('response-status-readout'),
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      border: Border.all(color: color.withValues(alpha: 0.52)),
      borderRadius: ChakraRadii.control,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        MonoText(
          '$statusCode',
          color: color,
          size: 14,
          weight: FontWeight.w700,
        ),
        const SizedBox(width: 6),
        MonoText('HTTP', color: color, size: 10, weight: FontWeight.w700),
      ],
    ),
  );
}

class _ResponseMetric extends StatelessWidget {
  const _ResponseMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: context.chakra.fgSubtle),
      const SizedBox(width: 5),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MonoText(
            label.toUpperCase(),
            color: context.chakra.fgSubtle,
            size: 9,
          ),
          const SizedBox(height: 1),
          MonoText(value, color: context.chakra.fg, size: 11),
        ],
      ),
    ],
  );
}
