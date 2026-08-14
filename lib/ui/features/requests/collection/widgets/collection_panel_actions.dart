import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/application/user_message.dart';
import 'package:sendreq/ui/core/widgets/user_message_scope.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 资源树的右键菜单、重命名和含草稿保护的删除流程。
class CollectionPanelActions {
  const CollectionPanelActions(this.viewModel);

  final WorkspaceViewModel viewModel;

  Future<void> showCollectionMenu(
    BuildContext context,
    CollectionResource collection,
    Offset position,
  ) async {
    final action = await showMenu<_CollectionMenuAction>(
      context: context,
      position: _collectionMenuPosition(position),
      items: [
        PopupMenuItem(
          value: _CollectionMenuAction.addRequest,
          child: CollectionMenuItemContent(
            icon: Icons.add,
            label: AppLocalizations.of(context).newRequest,
          ),
        ),
        PopupMenuItem(
          value: _CollectionMenuAction.addFolder,
          child: CollectionMenuItemContent(
            icon: Icons.create_new_folder_outlined,
            label: AppLocalizations.of(context).newFolder,
          ),
        ),
        PopupMenuItem(
          value: _CollectionMenuAction.rename,
          child: CollectionMenuItemContent(
            icon: Icons.edit_outlined,
            label: AppLocalizations.of(context).rename,
          ),
        ),
        PopupMenuItem(
          value: _CollectionMenuAction.exportDocumentation,
          child: CollectionMenuItemContent(
            icon: Icons.description_outlined,
            label: AppLocalizations.of(context).exportApiDocumentation,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _CollectionMenuAction.delete,
          child: CollectionMenuItemContent(
            icon: Icons.delete_outline,
            label: AppLocalizations.of(context).delete,
            destructive: true,
          ),
        ),
      ],
    );
    if (!context.mounted || action == null) return;
    final requests = [
      for (final folder in collection.folders) ...folder.requests,
    ];
    switch (action) {
      case _CollectionMenuAction.addRequest:
        final protocol = await _selectRequestProtocol(context, position);
        if (protocol != null) {
          viewModel.createRequest(
            collectionId: collection.id,
            protocol: protocol,
          );
        }
      case _CollectionMenuAction.addFolder:
        viewModel.createFolder(collection.id);
      case _CollectionMenuAction.rename:
        final name = await _showRenameDialog(
          context,
          title: AppLocalizations.of(context).renameCollection,
          initialName: collection.name,
        );
        if (name != null) viewModel.renameCollection(collection.id, name);
      case _CollectionMenuAction.exportDocumentation:
        await _exportCollectionDocumentation(context, collection);
      case _CollectionMenuAction.delete:
        final choice = await _confirmDeleteResources(
          context,
          title: AppLocalizations.of(context).deleteCollection,
          description: AppLocalizations.of(context)
              .deleteCollectionConfirmation(
                collection.name,
                collection.requestCount,
              ),
          requests: requests,
        );
        if (choice != _DeleteChoice.cancel && context.mounted) {
          _saveBeforeDeleting(choice, requests);
          viewModel.deleteCollection(collection.id);
        }
    }
  }

  Future<void> _exportCollectionDocumentation(
    BuildContext context,
    CollectionResource collection,
  ) async {
    final l10n = AppLocalizations.of(context);
    final hasHttpRequest = collection.folders.any(
      (group) => group.requests.any(
        (request) => request.protocol == ApiRequestProtocol.http,
      ),
    );
    if (!hasHttpRequest) {
      publishUserMessage(
        context,
        l10n.collectionHasNoHttpRequests,
        severity: UserMessageSeverity.error,
        deduplicationKey: 'collection.documentation.export.failed',
      );
      return;
    }
    final directory = await FilePicker.getDirectoryPath(
      dialogTitle: l10n.selectDocumentationOutputDirectory,
    );
    if (directory == null || !context.mounted) return;
    try {
      await viewModel.exportCollectionDocumentation(
        collectionId: collection.id,
        outputDirectory: directory,
        languageCode: Localizations.localeOf(context).languageCode,
      );
      if (!context.mounted) return;
      publishUserMessage(
        context,
        l10n.collectionDocumentationExported(collection.name),
        severity: UserMessageSeverity.success,
        deduplicationKey: 'collection.documentation.export.succeeded',
      );
    } on Object {
      if (!context.mounted) return;
      publishUserMessage(
        context,
        l10n.collectionDocumentationExportFailed,
        severity: UserMessageSeverity.error,
        deduplicationKey: 'collection.documentation.export.failed',
      );
    }
  }

  Future<void> showFolderMenu(
    BuildContext context,
    CollectionResource collection,
    FolderResource folder,
    Offset position,
  ) async {
    final action = await showMenu<_FolderMenuAction>(
      context: context,
      position: _collectionMenuPosition(position),
      items: [
        PopupMenuItem(
          value: _FolderMenuAction.addRequest,
          child: CollectionMenuItemContent(
            icon: Icons.add,
            label: AppLocalizations.of(context).newRequest,
          ),
        ),
        PopupMenuItem(
          value: _FolderMenuAction.rename,
          child: CollectionMenuItemContent(
            icon: Icons.edit_outlined,
            label: AppLocalizations.of(context).rename,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _FolderMenuAction.delete,
          child: CollectionMenuItemContent(
            icon: Icons.delete_outline,
            label: AppLocalizations.of(context).delete,
            destructive: true,
          ),
        ),
      ],
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case _FolderMenuAction.addRequest:
        final protocol = await _selectRequestProtocol(context, position);
        if (protocol != null) {
          viewModel.createRequest(
            collectionId: collection.id,
            folderId: folder.id,
            protocol: protocol,
          );
        }
      case _FolderMenuAction.rename:
        final name = await _showRenameDialog(
          context,
          title: AppLocalizations.of(context).renameFolder,
          initialName: folder.name,
        );
        if (name != null) {
          viewModel.renameFolder(
            collectionId: collection.id,
            folderId: folder.id,
            name: name,
          );
        }
      case _FolderMenuAction.delete:
        final choice = await _confirmDeleteResources(
          context,
          title: AppLocalizations.of(context).deleteFolder,
          description: AppLocalizations.of(
            context,
          ).deleteFolderConfirmation(folder.name, folder.requests.length),
          requests: folder.requests,
        );
        if (choice != _DeleteChoice.cancel && context.mounted) {
          _saveBeforeDeleting(choice, folder.requests);
          viewModel.deleteFolder(
            collectionId: collection.id,
            folderId: folder.id,
          );
        }
    }
  }

  Future<ApiRequestProtocol?> _selectRequestProtocol(
    BuildContext context,
    Offset position,
  ) async {
    final visibleProtocol = viewModel.requestWorkingProtocol;
    if (visibleProtocol != null) return visibleProtocol;
    final l10n = AppLocalizations.of(context);
    return showMenu<ApiRequestProtocol>(
      context: context,
      position: _collectionMenuPosition(position),
      items: [
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
    );
  }

  Future<void> showRequestMenu(
    BuildContext context,
    RequestResource request,
    Offset position,
  ) async {
    final action = await showMenu<_RequestMenuAction>(
      context: context,
      position: _collectionMenuPosition(position),
      items: [
        PopupMenuItem(
          value: _RequestMenuAction.rename,
          child: CollectionMenuItemContent(
            icon: Icons.edit_outlined,
            label: AppLocalizations.of(context).rename,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _RequestMenuAction.delete,
          child: CollectionMenuItemContent(
            icon: Icons.delete_outline,
            label: AppLocalizations.of(context).delete,
            destructive: true,
          ),
        ),
      ],
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case _RequestMenuAction.rename:
        final name = await _showRenameDialog(
          context,
          title: AppLocalizations.of(context).renameRequest,
          initialName: request.name,
        );
        if (name != null) viewModel.renameRequest(request.id, name);
      case _RequestMenuAction.delete:
        final choice = await _confirmDeleteResources(
          context,
          title: AppLocalizations.of(context).deleteRequest,
          description: AppLocalizations.of(
            context,
          ).deleteRequestConfirmation(request.name),
          requests: [request],
        );
        if (choice != _DeleteChoice.cancel && context.mounted) {
          _saveBeforeDeleting(choice, [request]);
          viewModel.deleteRequest(request.id);
        }
    }
  }

  Future<String?> _showRenameDialog(
    BuildContext context, {
    required String title,
    required String initialName,
  }) {
    final controller = TextEditingController(text: initialName);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          autofocus: true,
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).name,
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(AppLocalizations.of(context).rename),
          ),
        ],
      ),
    );
  }

  Future<_DeleteChoice> _confirmDeleteResources(
    BuildContext context, {
    required String title,
    required String description,
    required List<RequestResource> requests,
  }) async {
    final dirtyCount = requests.where((request) => request.isDirty).length;
    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dirtyCount == 0
              ? title
              : AppLocalizations.of(context).unsavedRequestChanges,
        ),
        content: Text(
          dirtyCount == 0
              ? description
              : AppLocalizations.of(
                  context,
                ).deleteWithUnsavedChanges(description, dirtyCount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _DeleteChoice.cancel),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          if (dirtyCount > 0)
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _DeleteChoice.discard),
              child: Text(AppLocalizations.of(context).discardAndDelete),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              dirtyCount == 0 ? _DeleteChoice.discard : _DeleteChoice.save,
            ),
            child: Text(
              dirtyCount == 0
                  ? AppLocalizations.of(context).delete
                  : AppLocalizations.of(context).saveAndDelete,
            ),
          ),
        ],
      ),
    );
    return choice ?? _DeleteChoice.cancel;
  }

  void _saveBeforeDeleting(
    _DeleteChoice choice,
    List<RequestResource> requests,
  ) {
    if (choice != _DeleteChoice.save) return;
    for (final request in requests.where((request) => request.isDirty)) {
      viewModel.saveRequest(request.id);
    }
  }
}

RelativeRect _collectionMenuPosition(Offset position) =>
    RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy);

enum _CollectionMenuAction {
  addRequest,
  addFolder,
  rename,
  exportDocumentation,
  delete,
}

enum _FolderMenuAction { addRequest, rename, delete }

enum _RequestMenuAction { rename, delete }

enum _DeleteChoice { cancel, discard, save }

class CollectionMenuItemContent extends StatelessWidget {
  const CollectionMenuItemContent({
    super.key,
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? context.chakra.error : context.chakra.fgMuted;
    return Row(
      children: [
        SizedBox(width: 18, child: Icon(icon, size: 17, color: color)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: destructive ? context.chakra.error : null),
          ),
        ),
      ],
    );
  }
}
