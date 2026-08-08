import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/authentication/request_authentication.dart';
import '../../../domain/models/workspace_models.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../workspace/models/workspace_shell_models.dart';
import '../../workspace/view_models/workspace_view_model.dart';
import '../../../core/widgets/dense_controls.dart';
import '../../dashboard/widgets/openapi_export_actions.dart';
import '../../dashboard/widgets/openapi_import_actions.dart';
import '../../request_editor/widgets/request_editor_status.dart';
import 'collection_resource_browser.dart';

/// 集合面板：以"集合 → 文件夹 → 请求"三层树形结构展示工作区资源，
/// 并提供新建、导入、重命名、删除等管理操作入口。
class CollectionPanel extends StatelessWidget {
  /// 构造集合面板，接收工作区视图模型与是否撑满宽度的配置。
  const CollectionPanel({
    super.key,
    required this.viewModel,
    this.expandToFill = false,
  });

  /// 工作区视图模型，承载集合树数据及全部增删改查操作。
  final WorkspaceViewModel viewModel;

  /// 是否撑满父级可用宽度（宽屏布局用）；为 false 时使用统一第二栏宽度。
  final bool expandToFill;

  /// 构建面板主体：标题工具栏 + 可滚动资源树 + 底部当前环境信息。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('collection-panel'),
      // 非撑满模式下保持固定宽度，营造稳定的侧栏布局
      width: expandToFill ? null : WorkspacePaneWidths.secondary,
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border(right: BorderSide(color: AppColors.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 34,
              child: Row(
                children: [
                  Text(
                    l10n.collections,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 7),
                  MonoText(
                    '${viewModel.collections.length}',
                    color: AppColors.textFaint,
                    size: 10,
                  ),
                  const Spacer(),
                  DenseIconButton(
                    icon: Icons.add,
                    tooltip: l10n.newRequest,
                    onPressed: viewModel.createRequest,
                    size: 30,
                  ),
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: PopupMenuButton<_CollectionToolbarAction>(
                      tooltip: l10n.collectionActions,
                      icon: const Icon(Icons.more_horiz, size: 19),
                      padding: EdgeInsets.zero,
                      onSelected: (action) =>
                          _handleToolbarAction(context, action),
                      itemBuilder: (menuContext) => [
                        PopupMenuItem(
                          value: _CollectionToolbarAction.newCollection,
                          child: _MenuItemContent(
                            icon: Icons.create_new_folder_outlined,
                            label: l10n.newCollection,
                          ),
                        ),
                        PopupMenuItem(
                          value: _CollectionToolbarAction.loadDemoExample,
                          child: _MenuItemContent(
                            icon: Icons.rocket_launch_outlined,
                            label: l10n.loadDemoExample,
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: _CollectionToolbarAction.importOpenApi,
                          child: _MenuItemContent(
                            icon: Icons.file_upload_outlined,
                            label: l10n.importOpenApi,
                          ),
                        ),
                        PopupMenuItem(
                          value: _CollectionToolbarAction.exportOpenApi,
                          child: _MenuItemContent(
                            icon: Icons.file_download_outlined,
                            label: l10n.exportOpenApi,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CollectionResourceBrowser(
                collections: viewModel.collections,
                activeRequestId: viewModel.hasActiveRequest
                    ? viewModel.activeRequest.id
                    : null,
                onToggleCollection: (collection) =>
                    viewModel.toggleCollection(collection.id),
                onToggleFolder: (folder) => viewModel.toggleFolder(folder.id),
                onSelectRequest: (request) =>
                    viewModel.selectRequest(request.id),
                onCollectionMenu: (collection, position) =>
                    _showCollectionMenu(context, collection, position),
                onFolderMenu: (collection, folder, position) =>
                    _showFolderMenu(context, collection, folder, position),
                onRequestMenu: (request, position) =>
                    _showRequestMenu(context, request, position),
              ),
            ),
            const SizedBox(height: 8),
            // 底部上下文条仅提示当前环境，不再与资源树争夺视觉层级。
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(2, 9, 2, 2),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.outline)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoText(
                    l10n.activeEnvironmentShort,
                    color: AppColors.textFaint,
                    size: 10,
                  ),
                  const SizedBox(height: 6),
                  RequestEnvironmentSelector(
                    controlKey: const Key('collection-environment-selector'),
                    environments: viewModel.environments,
                    activeEnvironmentId: viewModel.activeEnvironment.id,
                    onSelected: viewModel.selectEnvironment,
                  ),
                  const SizedBox(height: 4),
                  MonoText(
                    viewModel.activeEnvironmentBaseUrl,
                    key: const Key('collection-environment-base-url'),
                    color: AppColors.textMuted,
                    size: 10,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    key: const Key('collection-environment-authentication'),
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      MonoText(
                        _environmentAuthenticationLabel(
                          l10n,
                          viewModel.activeEnvironment.authentication.type,
                        ),
                        color: AppColors.primary,
                        size: 10,
                      ),
                    ],
                  ),
                  if (viewModel.hasEnvironmentChanges) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_outlined,
                          size: 13,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: MonoText(
                            l10n.environmentChangesPending,
                            color: AppColors.warning,
                            size: 10,
                          ),
                        ),
                        DenseIconButton(
                          icon: Icons.save_outlined,
                          tooltip: l10n.saveChanges,
                          onPressed: viewModel.openEnvironmentForActiveRequest,
                          size: 26,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 处理标题栏的低频资源操作，避免固定宽度第二栏出现横向溢出。
  void _handleToolbarAction(
    BuildContext context,
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

  // 展示集合的右键/长按上下文菜单：新建请求、新建文件夹、重命名或删除。
  Future<void> _showCollectionMenu(
    BuildContext context,
    CollectionResource collection,
    Offset position,
  ) async {
    final action = await showMenu<_CollectionMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: _CollectionMenuAction.addRequest,
          child: _MenuItemContent(
            icon: Icons.add,
            label: AppLocalizations.of(context).newRequest,
          ),
        ),
        PopupMenuItem(
          value: _CollectionMenuAction.addFolder,
          child: _MenuItemContent(
            icon: Icons.create_new_folder_outlined,
            label: AppLocalizations.of(context).newFolder,
          ),
        ),
        PopupMenuItem(
          value: _CollectionMenuAction.rename,
          child: _MenuItemContent(
            icon: Icons.edit_outlined,
            label: AppLocalizations.of(context).rename,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _CollectionMenuAction.delete,
          child: _MenuItemContent(
            icon: Icons.delete_outline,
            label: AppLocalizations.of(context).delete,
            destructive: true,
          ),
        ),
      ],
    );
    // 关闭菜单后校验上下文是否仍可用，并处理用户取消的情况
    if (!context.mounted || action == null) return;
    switch (action) {
      // 在选中集合下新建请求
      case _CollectionMenuAction.addRequest:
        viewModel.createRequest(collectionId: collection.id);
      // 在该集合下新建一个空文件夹
      case _CollectionMenuAction.addFolder:
        viewModel.createFolder(collection.id);
      // 重命名前先弹出输入框收集新名称
      case _CollectionMenuAction.rename:
        final name = await _showRenameDialog(
          context,
          title: AppLocalizations.of(context).renameCollection,
          initialName: collection.name,
        );
        if (name != null) viewModel.renameCollection(collection.id, name);
      // 删除涉及确认与"未保存修改"处理，确认后才真正删除
      case _CollectionMenuAction.delete:
        final choice = await _confirmDeleteResources(
          context,
          title: AppLocalizations.of(context).deleteCollection,
          description: AppLocalizations.of(context)
              .deleteCollectionConfirmation(
                collection.name,
                collection.requestCount,
              ),
          requests: [
            for (final folder in collection.folders) ...folder.requests,
          ],
        );
        if (choice != _DeleteChoice.cancel && context.mounted) {
          _saveBeforeDeleting(choice, [
            for (final folder in collection.folders) ...folder.requests,
          ]);
          viewModel.deleteCollection(collection.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).collectionDeleted),
            ),
          );
        }
    }
  }

  // 展示文件夹的右键/长按上下文菜单：新建请求、重命名或删除。
  Future<void> _showFolderMenu(
    BuildContext context,
    CollectionResource collection,
    FolderResource folder,
    Offset position,
  ) async {
    final action = await showMenu<_FolderMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: _FolderMenuAction.addRequest,
          child: _MenuItemContent(
            icon: Icons.add,
            label: AppLocalizations.of(context).newRequest,
          ),
        ),
        PopupMenuItem(
          value: _FolderMenuAction.rename,
          child: _MenuItemContent(
            icon: Icons.edit_outlined,
            label: AppLocalizations.of(context).rename,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _FolderMenuAction.delete,
          child: _MenuItemContent(
            icon: Icons.delete_outline,
            label: AppLocalizations.of(context).delete,
            destructive: true,
          ),
        ),
      ],
    );
    // 关闭菜单后校验上下文是否仍可用，并处理用户取消的情况
    if (!context.mounted || action == null) return;
    switch (action) {
      // 在选中文件夹下新建请求
      case _FolderMenuAction.addRequest:
        viewModel.createRequest(
          collectionId: collection.id,
          folderId: folder.id,
        );
      // 重命名前先弹出输入框收集新名称
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
      // 删除前需确认，并处理文件夹内请求的未保存修改
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).folderDeleted)),
          );
        }
    }
  }

  // 展示请求的右键/长按上下文菜单：重命名或删除。
  Future<void> _showRequestMenu(
    BuildContext context,
    RequestResource request,
    Offset position,
  ) async {
    final action = await showMenu<_RequestMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: _RequestMenuAction.rename,
          child: _MenuItemContent(
            icon: Icons.edit_outlined,
            label: AppLocalizations.of(context).rename,
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _RequestMenuAction.delete,
          child: _MenuItemContent(
            icon: Icons.delete_outline,
            label: AppLocalizations.of(context).delete,
            destructive: true,
          ),
        ),
      ],
    );
    // 关闭菜单后校验上下文是否仍可用，并处理用户取消的情况
    if (!context.mounted || action == null) return;
    switch (action) {
      // 重命名前先弹出输入框收集新名称
      case _RequestMenuAction.rename:
        final name = await _showRenameDialog(
          context,
          title: AppLocalizations.of(context).renameRequest,
          initialName: request.name,
        );
        if (name != null) viewModel.renameRequest(request.id, name);
      // 删除前需确认，并处理该请求的未保存修改
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).requestDeleted),
            ),
          );
        }
    }
  }

  // 弹出重命名输入框，返回用户输入的新名称；取消时返回 null。
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

  // 删除前的二次确认对话框；若存在未保存修改，额外提供"丢弃并删除 / 保存并删除"选项。
  Future<_DeleteChoice> _confirmDeleteResources(
    BuildContext context, {
    required String title,
    required String description,
    required List<RequestResource> requests,
  }) async {
    // 统计本次删除涉及到的"未保存修改"请求数量
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

  // 用户选择"保存并删除"时，先保存所有未保存的请求再执行删除。
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

/// 将请求认证类型映射为本地化的显示名称。
String _environmentAuthenticationLabel(
  AppLocalizations l10n,
  RequestAuthenticationType type,
) => switch (type) {
  RequestAuthenticationType.none => l10n.noAuth,
  RequestAuthenticationType.bearer => l10n.bearerToken,
  RequestAuthenticationType.basic => l10n.basicAuth,
  RequestAuthenticationType.apiKey => l10n.apiKey,
};

// 集合上下文菜单可执行的操作类型
enum _CollectionMenuAction { addRequest, addFolder, rename, delete }

// 标题栏中低频资源操作的菜单类型。
enum _CollectionToolbarAction {
  newCollection,
  loadDemoExample,
  importOpenApi,
  exportOpenApi,
}

// 文件夹上下文菜单可执行的操作类型
enum _FolderMenuAction { addRequest, rename, delete }

// 请求上下文菜单可执行的操作类型
enum _RequestMenuAction { rename, delete }

// 删除前的确认选择：取消 / 放弃修改 / 保存并删除
enum _DeleteChoice { cancel, discard, save }

// 菜单项内容：图标 + 文字；destructive 为 true 时以危险色渲染。
class _MenuItemContent extends StatelessWidget {
  /// 构造菜单项内容，可指定是否以危险色渲染。
  const _MenuItemContent({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  /// 菜单项图标。
  final IconData icon;

  /// 菜单项文字标签。
  final String label;

  // 是否为破坏性操作（如删除），用于危险色提示。
  final bool destructive;

  /// 构建菜单项内容行：图标 + 文字。
  @override
  Widget build(BuildContext context) {
    // 破坏性操作使用危险色，其余使用弱化文字色
    final color = destructive ? AppColors.danger : AppColors.textMuted;
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: destructive ? AppColors.danger : null),
        ),
      ],
    );
  }
}
