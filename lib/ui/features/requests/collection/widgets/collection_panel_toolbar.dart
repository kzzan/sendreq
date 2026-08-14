import 'package:flutter/material.dart';

import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/widgets/workspace_navigation_rail.dart';
import 'package:sendreq/ui/features/requests/collection/widgets/collection_panel_actions.dart';
import 'package:sendreq/ui/features/requests/collection/widgets/openapi_export_actions.dart';
import 'package:sendreq/ui/features/requests/collection/widgets/openapi_import_actions.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// Collection 标题、计数、新建请求和低频资源操作入口。
class CollectionToolbar extends StatelessWidget {
  const CollectionToolbar({super.key, required this.viewModel});

  final WorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NavigationRailHeader(
      title: l10n.collections,
      subtitle: '${viewModel.collections.length}',
      leading: Icon(
        Icons.folder_open_outlined,
        size: 17,
        color: context.chakra.colorPaletteFg,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NewRequestControl(viewModel: viewModel),
          SizedBox(
            width: 30,
            height: 30,
            child: PopupMenuButton<_CollectionToolbarAction>(
              tooltip: l10n.collectionActions,
              icon: const Icon(Icons.more_horiz, size: 19),
              padding: EdgeInsets.zero,
              onSelected: (action) =>
                  _handleCollectionToolbarAction(context, viewModel, action),
              itemBuilder: (menuContext) => [
                PopupMenuItem(
                  value: _CollectionToolbarAction.newCollection,
                  child: CollectionMenuItemContent(
                    icon: Icons.create_new_folder_outlined,
                    label: l10n.newCollection,
                  ),
                ),
                PopupMenuItem(
                  value: _CollectionToolbarAction.loadDemoExample,
                  child: CollectionMenuItemContent(
                    icon: Icons.rocket_launch_outlined,
                    label: l10n.loadDemoExample,
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _CollectionToolbarAction.importOpenApi,
                  child: CollectionMenuItemContent(
                    icon: Icons.file_upload_outlined,
                    label: l10n.importOpenApi,
                  ),
                ),
                PopupMenuItem(
                  value: _CollectionToolbarAction.exportOpenApi,
                  child: CollectionMenuItemContent(
                    icon: Icons.file_download_outlined,
                    label: l10n.exportOpenApi,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewRequestControl extends StatelessWidget {
  const _NewRequestControl({required this.viewModel});

  final WorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final protocol = viewModel.requestWorkingProtocol;
    if (protocol != null) {
      return DenseIconButton(
        key: const Key('new-request-for-working-view'),
        icon: Icons.add,
        tooltip: l10n.newRequest,
        onPressed: viewModel.createRequest,
        size: 30,
      );
    }
    return SizedBox(
      width: 30,
      height: 30,
      child: PopupMenuButton<ApiRequestProtocol>(
        key: const Key('new-request-type-menu'),
        tooltip: l10n.newRequest,
        icon: const Icon(Icons.add, size: 18),
        padding: EdgeInsets.zero,
        onSelected: (value) => viewModel.createRequest(protocol: value),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: ApiRequestProtocol.http,
            child: Text(l10n.restRequests),
          ),
          PopupMenuItem(
            value: ApiRequestProtocol.webSocket,
            child: Text(l10n.webSocketRequests),
          ),
          PopupMenuItem(
            value: ApiRequestProtocol.grpc,
            child: Text(l10n.grpcRequests),
          ),
        ],
      ),
    );
  }
}

void _handleCollectionToolbarAction(
  BuildContext context,
  WorkspaceViewModel viewModel,
  _CollectionToolbarAction action,
) {
  switch (action) {
    case _CollectionToolbarAction.newCollection:
      viewModel.createCollection();
    case _CollectionToolbarAction.loadDemoExample:
      viewModel.loadDemoExample();
    case _CollectionToolbarAction.importOpenApi:
      showOpenApiImportDialog(context, viewModel);
    case _CollectionToolbarAction.exportOpenApi:
      exportOpenApiToFile(context, viewModel);
  }
}

enum _CollectionToolbarAction {
  newCollection,
  loadDemoExample,
  importOpenApi,
  exportOpenApi,
}
