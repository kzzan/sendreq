import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/form_control_metrics.dart';
import '../../../core/widgets/dense_controls.dart';
import '../../../domain/models/workspace_models.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'collection_tree_header.dart';
import 'collection_tree_rows.dart';

/// 可搜索的集合资源树。
///
/// 搜索只改变当前显示结果，不会写回集合或文件夹的展开状态；清空搜索后，
/// 用户原本的资源树层级会完整恢复。
class CollectionResourceBrowser extends StatefulWidget {
  const CollectionResourceBrowser({
    super.key,
    required this.collections,
    required this.activeRequestId,
    required this.onToggleCollection,
    required this.onToggleFolder,
    required this.onSelectRequest,
    required this.onCollectionMenu,
    required this.onFolderMenu,
    required this.onRequestMenu,
  });

  final List<CollectionResource> collections;
  final String? activeRequestId;
  final ValueChanged<CollectionResource> onToggleCollection;
  final ValueChanged<FolderResource> onToggleFolder;
  final ValueChanged<RequestResource> onSelectRequest;
  final void Function(CollectionResource collection, Offset position)
  onCollectionMenu;
  final void Function(
    CollectionResource collection,
    FolderResource folder,
    Offset position,
  )
  onFolderMenu;
  final void Function(RequestResource request, Offset position) onRequestMenu;

  @override
  State<CollectionResourceBrowser> createState() =>
      _CollectionResourceBrowserState();
}

class _CollectionResourceBrowserState extends State<CollectionResourceBrowser> {
  var _query = '';

  bool get _isSearching => _query.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _query.trim().toLowerCase();
    final matches = _matchingCollections(query);

    return Column(
      children: [
        SizedBox(
          height: FormControlMetrics.standardHeight,
          child: TextField(
            key: const Key('collection-search-input'),
            onChanged: (value) => setState(() => _query = value),
            style: const TextStyle(fontSize: 12),
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              isDense: true,
              constraints: FormControlMetrics.standardConstraints,
              contentPadding: const EdgeInsets.symmetric(vertical: 7),
              hintText: l10n.searchRequests,
              hintStyle: TextStyle(color: AppColors.textFaint, fontSize: 12),
              prefixIcon: Icon(
                Icons.search,
                size: 17,
                color: AppColors.textFaint,
              ),
              prefixIconConstraints: FormControlMetrics.iconConstraints,
              suffixIconConstraints: FormControlMetrics.iconConstraints,
              suffixIcon: _isSearching
                  ? IconButton(
                      tooltip: l10n.clearSearch,
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _query = ''),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceMid,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: BorderSide(color: AppColors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: BorderSide(color: AppColors.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: matches.isEmpty
              ? _EmptySearchResult(message: l10n.noMatchingResources)
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final match in matches)
                      _CollectionMatch(
                        collection: match.collection,
                        folders: match.folders,
                      ).build(
                        activeRequestId: widget.activeRequestId,
                        onToggleCollection: widget.onToggleCollection,
                        onToggleFolder: widget.onToggleFolder,
                        onSelectRequest: widget.onSelectRequest,
                        onCollectionMenu: widget.onCollectionMenu,
                        onFolderMenu: widget.onFolderMenu,
                        onRequestMenu: widget.onRequestMenu,
                        forceExpanded: _isSearching,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  List<_CollectionMatch> _matchingCollections(String query) {
    if (query.isEmpty) {
      return widget.collections
          .map(
            (collection) => _CollectionMatch(
              collection: collection,
              folders: collection.folders
                  .map((folder) => _FolderMatch(folder: folder))
                  .toList(growable: false),
            ),
          )
          .toList(growable: false);
    }

    return widget.collections
        .map((collection) {
          final collectionMatches = _matches(collection.name, query);
          final folders = collection.folders
              .map((folder) {
                final folderMatches = _matches(folder.name, query);
                final requests = folder.requests
                    .where(
                      (request) =>
                          collectionMatches ||
                          folderMatches ||
                          _matches(request.name, query) ||
                          _matches(request.method, query) ||
                          _matches(request.path, query),
                    )
                    .toList(growable: false);
                return _FolderMatch(folder: folder, requests: requests);
              })
              .where((match) => collectionMatches || match.requests.isNotEmpty)
              .toList(growable: false);
          return _CollectionMatch(collection: collection, folders: folders);
        })
        .where(
          (match) =>
              _matches(match.collection.name, query) ||
              match.folders.isNotEmpty,
        )
        .toList(growable: false);
  }

  bool _matches(String value, String query) =>
      value.toLowerCase().contains(query);
}

class _CollectionMatch {
  const _CollectionMatch({required this.collection, required this.folders});

  final CollectionResource collection;
  final List<_FolderMatch> folders;

  Widget build({
    required String? activeRequestId,
    required ValueChanged<CollectionResource> onToggleCollection,
    required ValueChanged<FolderResource> onToggleFolder,
    required ValueChanged<RequestResource> onSelectRequest,
    required void Function(CollectionResource collection, Offset position)
    onCollectionMenu,
    required void Function(
      CollectionResource collection,
      FolderResource folder,
      Offset position,
    )
    onFolderMenu,
    required void Function(RequestResource request, Offset position)
    onRequestMenu,
    required bool forceExpanded,
  }) {
    final showContents = forceExpanded || collection.isExpanded;
    return Column(
      children: [
        CollectionTreeHeader(
          collection: collection,
          expanded: showContents,
          onTap: () => onToggleCollection(collection),
          onSecondaryTapDown: (details) =>
              onCollectionMenu(collection, details.globalPosition),
          onLongPressStart: (details) =>
              onCollectionMenu(collection, details.globalPosition),
        ),
        if (showContents)
          for (final match in folders)
            _FolderMatchRow(
              collection: collection,
              match: match,
              activeRequestId: activeRequestId,
              expanded: forceExpanded || match.folder.isExpanded,
              onToggleFolder: onToggleFolder,
              onSelectRequest: onSelectRequest,
              onFolderMenu: onFolderMenu,
              onRequestMenu: onRequestMenu,
            ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _FolderMatch {
  _FolderMatch({required this.folder, List<RequestResource>? requests})
    : requests = requests ?? folder.requests;

  final FolderResource folder;
  final List<RequestResource> requests;
}

class _FolderMatchRow extends StatelessWidget {
  const _FolderMatchRow({
    required this.collection,
    required this.match,
    required this.activeRequestId,
    required this.expanded,
    required this.onToggleFolder,
    required this.onSelectRequest,
    required this.onFolderMenu,
    required this.onRequestMenu,
  });

  final CollectionResource collection;
  final _FolderMatch match;
  final String? activeRequestId;
  final bool expanded;
  final ValueChanged<FolderResource> onToggleFolder;
  final ValueChanged<RequestResource> onSelectRequest;
  final void Function(
    CollectionResource collection,
    FolderResource folder,
    Offset position,
  )
  onFolderMenu;
  final void Function(RequestResource request, Offset position) onRequestMenu;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CollectionFolderRow(
        folder: match.folder,
        expanded: expanded,
        onTap: () => onToggleFolder(match.folder),
        onSecondaryTapDown: (details) =>
            onFolderMenu(collection, match.folder, details.globalPosition),
        onLongPressStart: (details) =>
            onFolderMenu(collection, match.folder, details.globalPosition),
      ),
      if (expanded)
        for (final request in match.requests)
          CollectionRequestRow(
            request: request,
            selected: request.id == activeRequestId,
            onTap: () => onSelectRequest(request),
            onSecondaryTapDown: (details) =>
                onRequestMenu(request, details.globalPosition),
            onLongPressStart: (details) =>
                onRequestMenu(request, details.globalPosition),
          ),
    ],
  );
}

class _EmptySearchResult extends StatelessWidget {
  const _EmptySearchResult({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) =>
      Center(child: MonoText(message, color: AppColors.textFaint, size: 11));
}
