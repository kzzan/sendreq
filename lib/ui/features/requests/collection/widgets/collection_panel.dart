import 'package:flutter/material.dart';

import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/workspace_navigation_rail.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/ui/features/requests/collection/widgets/collection_resource_browser.dart';
import 'package:sendreq/ui/features/requests/collection/widgets/collection_panel_actions.dart';
import 'package:sendreq/ui/features/requests/collection/widgets/collection_panel_toolbar.dart';

/// Collection 导航面板：只负责持久化资源树与资源命令。
class CollectionPanel extends StatelessWidget {
  const CollectionPanel({
    super.key,
    required this.viewModel,
    this.expandToFill = false,
  });

  final WorkspaceViewModel viewModel;
  final bool expandToFill;

  /// 三栏工作区中 Collection 导航的稳定宽度。
  static const double desktopWidth = 280;

  @override
  Widget build(BuildContext context) {
    final actions = CollectionPanelActions(viewModel);
    return SizedBox(
      key: const Key('collection-panel'),
      width: expandToFill ? null : desktopWidth,
      child: WorkspaceNavigationRail(
        child: Padding(
          padding: WorkspaceLayoutMetrics.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CollectionToolbar(viewModel: viewModel),
              const SizedBox(height: WorkspaceLayoutMetrics.sectionGap),
              Expanded(
                child: CollectionResourceBrowser(
                  collections: viewModel.collections,
                  activeRequestId: viewModel.hasActiveRequest
                      ? viewModel.activeRequest.id
                      : null,
                  protocolFilter: viewModel.requestWorkingProtocol,
                  onToggleCollection: (collection) =>
                      viewModel.toggleCollection(collection.id),
                  onToggleFolder: (folder) => viewModel.toggleFolder(folder.id),
                  onSelectRequest: (request) =>
                      viewModel.selectRequest(request.id),
                  onCollectionMenu: (collection, position) =>
                      actions.showCollectionMenu(context, collection, position),
                  onFolderMenu: (collection, folder, position) => actions
                      .showFolderMenu(context, collection, folder, position),
                  onRequestMenu: (request, position) =>
                      actions.showRequestMenu(context, request, position),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
