import 'package:flutter/material.dart';

import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 已打开请求的标签条及右键批量关闭菜单。
class RequestTabStrip extends StatelessWidget {
  const RequestTabStrip({
    super.key,
    required this.viewModel,
    required this.onClose,
  });

  final WorkspaceViewModel viewModel;
  final ValueChanged<RequestTab> onClose;

  Future<void> _showTabMenu(
    BuildContext context,
    List<RequestTab> tabs,
    int index,
    Offset position,
  ) async {
    final action = await showMenu<_TabMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: _TabMenuAction.closeOthers,
          child: Text(AppLocalizations.of(context).closeOtherTabs),
        ),
        if (index > 0)
          PopupMenuItem(
            value: _TabMenuAction.closeLeft,
            child: Text(AppLocalizations.of(context).closeTabsToLeft),
          ),
        if (index < tabs.length - 1)
          PopupMenuItem(
            value: _TabMenuAction.closeRight,
            child: Text(AppLocalizations.of(context).closeTabsToRight),
          ),
      ],
    );
    if (action == null || !context.mounted) return;
    final ids = switch (action) {
      _TabMenuAction.closeOthers => [
        for (final tab in tabs)
          if (tab != tabs[index]) tab.id,
      ],
      _TabMenuAction.closeLeft => [for (final tab in tabs.take(index)) tab.id],
      _TabMenuAction.closeRight => [
        for (final tab in tabs.skip(index + 1)) tab.id,
      ],
    };
    viewModel.closeRequestTabs(ids);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = viewModel.openRequestTabs;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 3),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final selected = tab.requestId == viewModel.activeRequest.id;
          return GestureDetector(
            onSecondaryTapDown: (details) =>
                _showTabMenu(context, tabs, index, details.globalPosition),
            child: Container(
              decoration: BoxDecoration(
                color: selected
                    ? context.chakra.bgPanel
                    : context.chakra.transparent,
                border: Border.all(
                  color: selected
                      ? context.chakra.colorPaletteFg.withValues(alpha: 0.7)
                      : context.chakra.transparent,
                ),
                borderRadius: ChakraRadii.control,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => viewModel.selectRequestTab(tab.id),
                    style: ChakraRecipes.sized(
                      ChakraRecipes.ghostFor(context),
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.only(left: 10, right: 4),
                    ),
                    child: Text(
                      '${tab.title}${viewModel.isRequestDirty(tab.requestId) ? ' *' : ''}',
                    ),
                  ),
                  DenseIconButton(
                    icon: Icons.close,
                    tooltip: AppLocalizations.of(
                      context,
                    ).closeRequest(tab.title),
                    onPressed: () => onClose(tab),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _TabMenuAction { closeOthers, closeLeft, closeRight }
