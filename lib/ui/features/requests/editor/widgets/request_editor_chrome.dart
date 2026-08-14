import 'package:flutter/material.dart';

import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';

enum RequestCloseChoice { save, discard, cancel }

/// 当前请求的身份信息及未保存修改提示。
class RequestIdentity extends StatelessWidget {
  const RequestIdentity({
    super.key,
    required this.title,
    required this.path,
    required this.isDirty,
    required this.onDiscard,
  });

  final String title;
  final String path;
  final bool isDirty;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonoText(
              AppLocalizations.of(context).request,
              color: context.chakra.fgSubtle,
              size: 10,
            ),
            const SizedBox(height: 3),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (path.isNotEmpty)
              Text(
                path,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: context.chakra.fgMuted,
                ),
              ),
          ],
        ),
      ),
      if (isDirty) ...[
        const SizedBox(width: 8),
        Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.chakra.warning.withValues(alpha: 0.12),
            border: Border.all(
              color: context.chakra.warning.withValues(alpha: 0.45),
            ),
            borderRadius: ChakraRadii.control,
          ),
          child: MonoText(
            AppLocalizations.of(context).unsaved,
            color: context.chakra.warning,
            size: 10,
          ),
        ),
        DenseIconButton(
          icon: Icons.undo,
          tooltip: AppLocalizations.of(context).discardUnsavedChangesTooltip,
          onPressed: onDiscard,
          size: 26,
        ),
      ],
    ],
  );
}
