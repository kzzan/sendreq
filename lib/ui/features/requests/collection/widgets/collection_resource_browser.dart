import 'package:flutter/material.dart';

import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/form_control_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/features/requests/collection/widgets/collection_tree_header.dart';
import 'package:sendreq/ui/features/requests/collection/widgets/collection_tree_rows.dart';

/// 可搜索的集合资源树。
class CollectionResourceBrowser extends StatefulWidget {
  const CollectionResourceBrowser({
    super.key,
    required this.collections,
    required this.activeRequestId,
    required this.protocolFilter,
    required this.onToggleCollection,
    required this.onToggleFolder,
    required this.onSelectRequest,
    required this.onCollectionMenu,
    required this.onFolderMenu,
    required this.onRequestMenu,
  });

  final List<CollectionResource> collections;
  final String? activeRequestId;
  final ApiRequestProtocol? protocolFilter;
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
    return Semantics(
      container: true,
      label: l10n.collectionResources,
      child: Column(
        key: const Key('collection-resource-browser'),
        children: [
          SizedBox(
            height: FormControlMetrics.standardHeight,
            child: TextField(
              key: const Key('collection-search-input'),
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(fontSize: 12),
              textAlignVertical: TextAlignVertical.center,
              decoration: ChakraRecipes.mutedInputFor(
                context,
                hintText: l10n.searchRequests,
                prefixIcon: Icon(
                  Icons.search,
                  size: 17,
                  color: context.chakra.fgSubtle,
                ),
                suffixIcon: _isSearching
                    ? IconButton(
                        tooltip: l10n.clearSearch,
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _query = ''),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: matches.isEmpty
                ? _EmptySearchResult(message: l10n.noMatchingResources)
                : ListView(
                    key: const Key('collection-resource-list'),
                    padding: EdgeInsets.zero,
                    children: [
                      for (final match in matches)
                        match.build(
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
      ),
    );
  }

  List<_CollectionMatch> _matchingCollections(String query) {
    if (query.isEmpty) {
      return [
        for (final collection in widget.collections)
          _CollectionMatch(
            collection: collection,
            folders: [
              for (final folder in collection.folders)
                _FolderMatch(
                  folder: folder,
                  requests: folder.requests
                      .where(_matchesProtocol)
                      .toList(growable: false),
                ),
            ],
          ),
      ];
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
                          _matchesProtocol(request) &&
                          (query.isEmpty ||
                              collectionMatches ||
                              folderMatches ||
                              _matches(request.name, query) ||
                              _matches(request.method, query) ||
                              _matches(request.path, query)),
                    )
                    .toList(growable: false);
                return _FolderMatch(folder: folder, requests: requests);
              })
              .where((match) => match.requests.isNotEmpty)
              .toList(growable: false);
          return _CollectionMatch(collection: collection, folders: folders);
        })
        .where((match) => match.folders.isNotEmpty)
        .toList(growable: false);
  }

  bool _matchesProtocol(RequestResource request) =>
      widget.protocolFilter == null ||
      request.protocol == widget.protocolFilter;

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
          onMenuRequested: (position) => onCollectionMenu(collection, position),
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
        onMenuRequested: (position) =>
            onFolderMenu(collection, match.folder, position),
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
            onMenuRequested: (position) => onRequestMenu(request, position),
          ),
    ],
  );
}

class _EmptySearchResult extends StatelessWidget {
  const _EmptySearchResult({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: MonoText(message, color: context.chakra.fgSubtle, size: 11),
  );
}
