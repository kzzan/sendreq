import 'package:flutter/material.dart';

import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';

enum ProtocolTone {
  neutral,
  progress,
  success,
  warning,
  danger,
  inbound,
  outbound,
}

Color _tone(ChakraSemanticTokens tokens, ProtocolTone tone) => switch (tone) {
  ProtocolTone.neutral => tokens.information,
  ProtocolTone.progress => tokens.colorPaletteFg,
  ProtocolTone.success => tokens.success,
  ProtocolTone.warning => tokens.warning,
  ProtocolTone.danger => tokens.error,
  ProtocolTone.inbound => tokens.inbound,
  ProtocolTone.outbound => tokens.outbound,
};

class ProtocolStatusBar extends StatelessWidget {
  const ProtocolStatusBar({
    super.key,
    required this.label,
    required this.tone,
    this.detail,
    this.trailing,
  });
  final String label;
  final ProtocolTone tone;
  final String? detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = _tone(context.chakra, tone);
    return Semantics(
      liveRegion: true,
      label: detail == null ? label : '$label: $detail',
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.chakra.bgPanel,
          border: Border(
            left: BorderSide(color: color, width: 3),
            bottom: BorderSide(color: context.chakra.border),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.circle, color: color, size: 10),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            if (detail != null) ...[
              const SizedBox(width: 10),
              Expanded(child: MonoText(detail!, color: context.chakra.fgMuted)),
            ] else
              const Spacer(),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class ProtocolEventRow extends StatelessWidget {
  const ProtocolEventRow({
    super.key,
    required this.time,
    required this.kind,
    required this.summary,
    required this.tone,
    this.onTap,
  });
  final String time, kind, summary;
  final ProtocolTone tone;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.chakra.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: MonoText(time, color: context.chakra.fgSubtle),
          ),
          SizedBox(
            width: 88,
            child: Text(
              kind,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _tone(context.chakra, tone),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: MonoText(summary, color: context.chakra.fgMuted)),
        ],
      ),
    ),
  );
}

class ProtocolStateNotice extends StatelessWidget {
  const ProtocolStateNotice({
    super.key,
    required this.title,
    this.message,
    required this.tone,
    this.action,
  });
  final String title;
  final String? message;
  final ProtocolTone tone;
  final Widget? action;
  @override
  Widget build(BuildContext context) => DensePanel(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, color: _tone(context.chakra, tone), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              if (message case final message?
                  when message.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class SafeSessionChip extends StatelessWidget {
  const SafeSessionChip({super.key, required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: context.chakra.bgMuted,
        border: Border.all(color: context.chakra.border),
        borderRadius: ChakraRadii.control,
      ),
      child: Text(
        '$label: $value',
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    ),
  );
}
