import 'package:flutter/material.dart';

import 'package:sendreq/domain/contract_publishing/mock_server.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/features/mock/widgets/mock_servers_panel_controls.dart';

enum _MockServerMenuAction { copyUrl, openSource, archive, delete }

class SavedMockServerEditor extends StatefulWidget {
  const SavedMockServerEditor({
    super.key,
    required this.projection,
    required this.onSave,
    required this.onStart,
    required this.onStop,
    required this.onArchive,
    required this.onDelete,
    required this.onOpenSource,
    required this.sourceUnavailableReason,
  });

  final MockServerProjection projection;
  final Future<void> Function(MockServer server)? onSave;
  final Future<void> Function(ResourceRef ref)? onStart;
  final Future<void> Function(ResourceRef ref)? onStop;
  final Future<void> Function(ResourceRef ref)? onArchive;
  final Future<void> Function(ResourceRef ref)? onDelete;
  final ValueChanged<MockSourceReference>? onOpenSource;
  final String? Function(MockSourceReference source)? sourceUnavailableReason;

  @override
  State<SavedMockServerEditor> createState() => _SavedServerEditorState();
}

class _SavedServerEditorState extends State<SavedMockServerEditor> {
  late MockServer _draft;
  late String _selectedEndpointId;
  late String _selectedVariantId;
  bool _dirty = false;
  var _editorRevision = 0;

  @override
  void initState() {
    super.initState();
    _draft = widget.projection.server;
    _selectedEndpointId = _draft.endpoints.first.id;
    _selectedVariantId = _draft.endpoints.first.variants.first.id;
  }

  MockEndpoint get _endpoint =>
      _draft.endpoints.firstWhere((item) => item.id == _selectedEndpointId);

  MockResponseVariant get _variant =>
      _endpoint.variants.firstWhere((item) => item.id == _selectedVariantId);

  void _change(MockServer next) => setState(() {
    _draft = next;
    _dirty = true;
  });

  void _replaceEndpoint(MockEndpoint next) {
    _change(
      _draft.copyWith(
        endpoints: [
          for (final endpoint in _draft.endpoints)
            endpoint.id == next.id ? next : endpoint,
        ],
      ),
    );
  }

  void _replaceVariant(MockResponseVariant next) {
    _replaceEndpoint(
      _endpoint.copyWith(
        variants: [
          for (final variant in _endpoint.variants)
            variant.id == next.id ? next : variant,
        ],
      ),
    );
  }

  void _addEndpoint() {
    final id = '${_draft.id}-endpoint-${DateTime.now().microsecondsSinceEpoch}';
    final endpoint = MockEndpoint(
      id: id,
      matcher: MockRequestMatcher(method: 'GET', path: '/new-endpoint'),
      variants: [
        MockResponseVariant(
          id: '$id-default',
          statusCode: 200,
          headers: const {'content-type': 'application/json'},
          body: '{\n  "message": "Mock response"\n}',
        ),
      ],
    );
    _change(_draft.copyWith(endpoints: [..._draft.endpoints, endpoint]));
    setState(() {
      _selectedEndpointId = endpoint.id;
      _selectedVariantId = endpoint.variants.first.id;
    });
  }

  void _addVariant() {
    final id =
        '${_endpoint.id}-variant-${DateTime.now().microsecondsSinceEpoch}';
    final variant = MockResponseVariant(
      id: id,
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: '{\n  "message": "Alternate response"\n}',
      matcher: MockVariantMatcher(headers: {'x-mock-variant': id}),
    );
    _replaceEndpoint(
      _endpoint.copyWith(variants: [..._endpoint.variants, variant]),
    );
    setState(() => _selectedVariantId = id);
  }

  void _removeVariant() {
    if (_variant.matcher.isDefault) return;
    final variants = _endpoint.variants
        .where((item) => item.id != _variant.id)
        .toList(growable: false);
    _replaceEndpoint(_endpoint.copyWith(variants: variants));
    setState(() => _selectedVariantId = variants.first.id);
  }

  void _restoreDraft() => setState(() {
    _draft = widget.projection.server;
    _selectedEndpointId = _draft.endpoints.first.id;
    _selectedVariantId = _draft.endpoints.first.variants.first.id;
    _dirty = false;
    _editorRevision++;
  });

  Future<void> _discard() async {
    if (!_dirty) {
      _restoreDraft();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).discardMockChangesTitle),
        content: Text(AppLocalizations.of(context).discardMockChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).continueEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).discardChanges),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _restoreDraft();
  }

  Future<void> _save() async {
    final save = widget.onSave;
    if (save == null) return;
    await save(_draft.copyWith(updatedAt: DateTime.now().toUtc()));
    if (mounted) setState(() => _dirty = false);
  }

  Future<void> _runLifecycleAction(
    Future<void> Function(ResourceRef ref)? action,
  ) async {
    if (action == null) return;
    await action(ResourceRef(kind: ResourceKind.mockServer, id: _draft.id));
  }

  Future<void> _confirmLifecycleAction({
    required String title,
    required String message,
    required Future<void> Function(ResourceRef ref) action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(title),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await action(ResourceRef(kind: ResourceKind.mockServer, id: _draft.id));
      if (mounted) _restoreDraft();
    }
  }

  Widget _sourceAction({
    required MockSourceReference? source,
    required String tooltip,
  }) {
    if (source == null) {
      return MockTooltipIconButton(
        tooltip: AppLocalizations.of(context).mockSourceUnavailable,
        icon: Icons.link_off_outlined,
      );
    }
    final unavailableReason = widget.sourceUnavailableReason?.call(source);
    final l10n = AppLocalizations.of(context);
    return MockTooltipIconButton(
      tooltip: unavailableReason == null
          ? tooltip
          : switch (source.kind) {
              MockSourceKind.request => l10n.sourceRequestUnavailable,
              MockSourceKind.responseSnapshot => l10n.sourceResponseUnavailable,
            },
      icon: Icons.link_outlined,
      onPressed: unavailableReason == null && widget.onOpenSource != null
          ? () => widget.onOpenSource!(source)
          : null,
    );
  }

  Widget _serverActions(MockServerRuntimeProjection runtime) {
    final l10n = AppLocalizations.of(context);
    final source = _draft.source;
    final sourceAvailable =
        source != null &&
        widget.sourceUnavailableReason?.call(source) == null &&
        widget.onOpenSource != null;
    final archiveAvailable =
        widget.onArchive != null &&
        _draft.lifecycle != MockServerLifecycle.archived;
    return PopupMenuButton<_MockServerMenuAction>(
      key: const Key('saved-mock-secondary-actions'),
      tooltip: l10n.mockServerActions,
      icon: const Icon(Icons.more_horiz, size: 18),
      onSelected: (action) {
        switch (action) {
          case _MockServerMenuAction.copyUrl:
            copyToClipboard(
              context,
              runtime.loopbackUrl!,
              l10n.serverUrlCopied,
            );
            return;
          case _MockServerMenuAction.openSource:
            widget.onOpenSource!(source!);
            return;
          case _MockServerMenuAction.archive:
            _confirmLifecycleAction(
              title: l10n.archiveServer,
              message: _dirty
                  ? l10n.archiveMockWithUnsavedEdits
                  : l10n.archiveMockMessage,
              action: widget.onArchive!,
            );
            return;
          case _MockServerMenuAction.delete:
            _confirmLifecycleAction(
              title: l10n.deleteServer,
              message: _dirty
                  ? l10n.deleteMockWithUnsavedEdits
                  : l10n.deleteMockMessage,
              action: widget.onDelete!,
            );
            return;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _MockServerMenuAction.copyUrl,
          enabled: runtime.loopbackUrl != null,
          child: MockMenuLabel(
            icon: Icons.copy_outlined,
            label: l10n.copyServerUrl,
          ),
        ),
        PopupMenuItem(
          value: _MockServerMenuAction.openSource,
          enabled: sourceAvailable,
          child: MockMenuLabel(
            icon: Icons.link_outlined,
            label: l10n.openServerSource,
          ),
        ),
        PopupMenuItem(
          value: _MockServerMenuAction.archive,
          enabled: archiveAvailable,
          child: MockMenuLabel(
            icon: Icons.archive_outlined,
            label: l10n.archiveServer,
          ),
        ),
        PopupMenuItem(
          value: _MockServerMenuAction.delete,
          enabled: widget.onDelete != null,
          child: MockMenuLabel(
            icon: Icons.delete_outline,
            label: l10n.deleteServer,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final runtime = widget.projection.runtime;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final name = KeyedSubtree(
                key: ValueKey('saved-mock-name-$_editorRevision'),
                child: TextFormField(
                  key: const Key('saved-mock-name-input'),
                  initialValue: _draft.name,
                  onChanged: (value) {
                    final normalized = value.trim();
                    if (normalized.isNotEmpty) {
                      _change(_draft.copyWith(name: normalized));
                    }
                  },
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).serverName,
                  ),
                ),
              );
              final running =
                  runtime.status == MockServerRuntimeStatus.running ||
                  runtime.status == MockServerRuntimeStatus.stopping;
              final lifecyclePending =
                  runtime.status == MockServerRuntimeStatus.starting ||
                  runtime.status == MockServerRuntimeStatus.stopping;
              final canStart =
                  _draft.lifecycle != MockServerLifecycle.archived &&
                  _draft.lifecycle != MockServerLifecycle.disabled;
              final primaryAction = _dirty
                  ? FilledButton.icon(
                      key: const Key('saved-mock-save-button'),
                      onPressed: widget.onSave == null ? null : _save,
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: Text(AppLocalizations.of(context).saveChanges),
                    )
                  : FilledButton.icon(
                      key: const Key('saved-mock-lifecycle-button'),
                      onPressed: lifecyclePending || (!running && !canStart)
                          ? null
                          : () => _runLifecycleAction(
                              running ? widget.onStop : widget.onStart,
                            ),
                      icon: Icon(
                        running
                            ? Icons.stop_outlined
                            : Icons.play_arrow_outlined,
                        size: 16,
                      ),
                      label: Text(
                        running
                            ? AppLocalizations.of(context).stopSavedServer
                            : AppLocalizations.of(context).startSavedServer,
                      ),
                    );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _serverActions(runtime),
                  MockTooltipIconButton(
                    key: const Key('saved-mock-discard-button'),
                    tooltip: _dirty
                        ? AppLocalizations.of(context).discardMockEdits
                        : AppLocalizations.of(context).noMockEditsToDiscard,
                    icon: Icons.undo_outlined,
                    onPressed: _dirty ? _discard : null,
                  ),
                  const SizedBox(width: 4),
                  primaryAction,
                ],
              );
              if (constraints.maxWidth < 680) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: name),
                        const SizedBox(width: 8),
                        MockRuntimeBadge(runtime: runtime),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: name),
                  const SizedBox(width: 10),
                  MockRuntimeBadge(runtime: runtime),
                  const SizedBox(width: 10),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: WorkspaceLayoutMetrics.sectionGap),
          MockEditorSectionHeader(
            title: AppLocalizations.of(context).endpoints,
            actionLabel: AppLocalizations.of(context).addEndpoint,
            onAction: _addEndpoint,
          ),
          const SizedBox(height: 6),
          CompactSelectionStrip<String>(
            key: const Key('saved-mock-endpoint-selector'),
            selected: _selectedEndpointId,
            onSelected: (id) => setState(() {
              _selectedEndpointId = id;
              _selectedVariantId = _endpoint.variants.first.id;
            }),
            items: [
              for (final endpoint in _draft.endpoints)
                CompactSelectionItem(
                  value: endpoint.id,
                  label: '${endpoint.matcher.method} ${endpoint.matcher.path}',
                  controlKey: ValueKey('saved-mock-endpoint-${endpoint.id}'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          MockEndpointEditor(
            key: ValueKey('saved-endpoint-editor-$_editorRevision'),
            endpoint: _endpoint,
            onChange: _replaceEndpoint,
            sourceAction: _sourceAction(
              source: _endpoint.source,
              tooltip: AppLocalizations.of(context).openEndpointSource,
            ),
          ),
          const SizedBox(height: WorkspaceLayoutMetrics.sectionGap),
          MockEditorSectionHeader(
            title: AppLocalizations.of(context).responseVariants,
            actionLabel: AppLocalizations.of(context).addVariant,
            onAction: _addVariant,
          ),
          const SizedBox(height: 6),
          CompactSelectionStrip<String>(
            key: const Key('saved-mock-variant-selector'),
            selected: _selectedVariantId,
            onSelected: (id) => setState(() => _selectedVariantId = id),
            items: [
              for (final variant in _endpoint.variants)
                CompactSelectionItem(
                  value: variant.id,
                  label: variant.matcher.isDefault
                      ? AppLocalizations.of(context).defaultVariant
                      : AppLocalizations.of(context).conditionalVariant,
                  controlKey: ValueKey('saved-mock-variant-${variant.id}'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          MockVariantEditor(
            key: ValueKey('saved-variant-editor-$_editorRevision'),
            variant: _variant,
            onChange: _replaceVariant,
            onRemove: _variant.matcher.isDefault ? null : _removeVariant,
            sourceAction: _sourceAction(
              source: _variant.source,
              tooltip: AppLocalizations.of(context).openResponseSource,
            ),
          ),
        ],
      ),
    );
  }
}
