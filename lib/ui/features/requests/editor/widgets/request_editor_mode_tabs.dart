import 'package:flutter/material.dart';

import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';

/// 协议相关的编辑模式标签条。
class EditorModeTabs extends StatelessWidget {
  const EditorModeTabs({
    super.key,
    required this.tabs,
    required this.active,
    required this.onSelected,
    required this.labelFor,
  });

  final List<String> tabs;
  final String active;
  final ValueChanged<String> onSelected;
  final String Function(String tab) labelFor;

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: context.chakra.border)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in tabs)
              _EditorModeTab(
                label: labelFor(tab),
                selected: tab == active,
                compact: constraints.maxWidth < 420,
                onPressed: () => onSelected(tab),
              ),
          ],
        ),
      ),
    ),
  );
}

class _EditorModeTab extends StatelessWidget {
  const _EditorModeTab({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    width: compact ? 68 : null,
    child: TextButton(
      onPressed: onPressed,
      style: ChakraRecipes.flatTabFor(
        context,
        selected: selected,
        minimumWidth: compact ? 56 : 68,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? context.chakra.colorPaletteFg
                  : context.chakra.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(label),
      ),
    ),
  );
}

String editorTabLabel(
  AppLocalizations l10n,
  String tab, {
  required ApiRequestProtocol protocol,
}) => switch ((protocol, tab)) {
  (ApiRequestProtocol.grpc, 'Headers') => l10n.grpcMetadata,
  (ApiRequestProtocol.grpc, 'Body') => l10n.grpcMessage,
  (ApiRequestProtocol.grpc, 'Protocol') => l10n.grpcProto,
  (_, 'Params') => l10n.requestTabParams,
  (_, 'Headers') => l10n.requestTabHeaders,
  (_, 'Auth') => l10n.requestTabAuth,
  (_, 'Body') => l10n.requestTabBody,
  (_, 'Protocol') => l10n.requestTabProtocol,
  _ => tab,
};
