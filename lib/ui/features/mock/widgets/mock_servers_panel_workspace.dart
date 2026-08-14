import 'package:flutter/material.dart';

import 'package:sendreq/domain/contract_publishing/mock_server.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/widgets/workspace_navigation_rail.dart';
import 'package:sendreq/ui/features/mock/widgets/mock_servers_panel_controls.dart';
import 'package:sendreq/ui/features/mock/widgets/mock_servers_panel_editor.dart';

/// 已保存 Mock Server 的本地编辑工作面。编辑仅停留在不可变草稿中，
/// 用户确认保存后才通过 Shell 命令提交给 Contract Publishing。
class SavedMockServerWorkspace extends StatefulWidget {
  const SavedMockServerWorkspace({
    super.key,
    required this.servers,
    required this.selectedId,
    required this.onSelect,
    required this.canCreateFromResponse,
    required this.onCreateManual,
    required this.onCreateFromResponse,
    required this.onSave,
    required this.onStart,
    required this.onStop,
    required this.onArchive,
    required this.onDelete,
    required this.onOpenSource,
    required this.sourceUnavailableReason,
  });

  final List<MockServerProjection> servers;
  final String? selectedId;
  final ValueChanged<String>? onSelect;
  final bool canCreateFromResponse;
  final VoidCallback onCreateManual;
  final VoidCallback onCreateFromResponse;
  final Future<void> Function(MockServer server)? onSave;
  final Future<void> Function(ResourceRef ref)? onStart;
  final Future<void> Function(ResourceRef ref)? onStop;
  final Future<void> Function(ResourceRef ref)? onArchive;
  final Future<void> Function(ResourceRef ref)? onDelete;
  final ValueChanged<MockSourceReference>? onOpenSource;
  final String? Function(MockSourceReference source)? sourceUnavailableReason;

  @override
  State<SavedMockServerWorkspace> createState() =>
      _SavedMockServerWorkspaceState();
}

class _SavedMockServerWorkspaceState extends State<SavedMockServerWorkspace> {
  var _showNarrowDetail = false;

  @override
  void initState() {
    super.initState();
    _showNarrowDetail = widget.selectedId != null;
  }

  @override
  void didUpdateWidget(covariant SavedMockServerWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId != oldWidget.selectedId &&
        widget.selectedId != null) {
      _showNarrowDetail = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedId =
        widget.servers.any((item) => item.server.id == widget.selectedId)
        ? widget.selectedId
        : widget.servers.first.server.id;
    final selected = widget.servers.firstWhere(
      (item) => item.server.id == selectedId,
      orElse: () => widget.servers.first,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final serverList = _SavedServerList(
          servers: widget.servers,
          selectedId: selected.server.id,
          onSelect: (id) {
            widget.onSelect?.call(id);
            setState(() {
              _showNarrowDetail = true;
            });
          },
          onStart: widget.onStart,
          onStop: widget.onStop,
          canCreateFromResponse: widget.canCreateFromResponse,
          onCreateManual: widget.onCreateManual,
          onCreateFromResponse: widget.onCreateFromResponse,
        );
        final editor = SavedMockServerEditor(
          key: ValueKey(selected.server.id),
          projection: selected,
          onSave: widget.onSave,
          onStart: widget.onStart,
          onStop: widget.onStop,
          onArchive: widget.onArchive,
          onDelete: widget.onDelete,
          onOpenSource: widget.onOpenSource,
          sourceUnavailableReason: widget.sourceUnavailableReason,
        );
        if (constraints.maxWidth < 760) {
          if (!_showNarrowDetail) {
            return KeyedSubtree(
              key: const Key('mock-servers-narrow-list'),
              child: serverList,
            );
          }
          return Column(
            key: const Key('mock-servers-narrow-detail'),
            children: [
              _MockServerBackBar(
                onBack: () => setState(() => _showNarrowDetail = false),
              ),
              Expanded(child: editor),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 256, child: serverList),
            VerticalDivider(width: 1, color: context.chakra.border),
            Expanded(child: editor),
          ],
        );
      },
    );
  }
}

class _MockServerBackBar extends StatelessWidget {
  const _MockServerBackBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: context.chakra.bgPanel,
      border: Border(bottom: BorderSide(color: context.chakra.border)),
    ),
    child: Row(
      children: [
        DenseIconButton(
          icon: Icons.arrow_back,
          tooltip: AppLocalizations.of(context).savedMockServersTitle,
          onPressed: onBack,
        ),
        const SizedBox(width: 4),
        Text(
          AppLocalizations.of(context).savedMockServersTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    ),
  );
}

class _SavedServerList extends StatelessWidget {
  const _SavedServerList({
    required this.servers,
    required this.selectedId,
    required this.onSelect,
    required this.onStart,
    required this.onStop,
    required this.canCreateFromResponse,
    required this.onCreateManual,
    required this.onCreateFromResponse,
  });

  final List<MockServerProjection> servers;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final Future<void> Function(ResourceRef ref)? onStart;
  final Future<void> Function(ResourceRef ref)? onStop;
  final bool canCreateFromResponse;
  final VoidCallback onCreateManual;
  final VoidCallback onCreateFromResponse;

  @override
  Widget build(BuildContext context) => WorkspaceNavigationRail(
    showTrailingDivider: false,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(
        vertical: WorkspaceLayoutMetrics.groupGap,
      ),
      itemCount: servers.length + 1,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: context.chakra.border),
      itemBuilder: (context, index) {
        if (index == 0) {
          return NavigationRailHeader(
            title: AppLocalizations.of(context).savedMockServersTitle,
            subtitle: AppLocalizations.of(context).mockLoopbackNote,
            leading: Icon(
              Icons.dns_outlined,
              size: 17,
              color: context.chakra.colorPaletteFg,
            ),
            trailing: _MockCreationMenu(
              canCreateFromResponse: canCreateFromResponse,
              onCreateManual: onCreateManual,
              onCreateFromResponse: onCreateFromResponse,
            ),
          );
        }
        final projection = servers[index - 1];
        final server = projection.server;
        final ref = ResourceRef(kind: ResourceKind.mockServer, id: server.id);
        final running =
            projection.runtime.status == MockServerRuntimeStatus.running;
        final canStart =
            server.lifecycle != MockServerLifecycle.archived &&
            server.lifecycle != MockServerLifecycle.disabled;
        final selected = selectedId == server.id;
        return NavigationRailItem(
          selected: selected,
          onTap: () => onSelect(server.id),
          height: 54,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(
              children: [
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      MonoText(
                        projection.runtime.loopbackUrl ??
                            AppLocalizations.of(
                              context,
                            ).mockEndpointCount(server.endpoints.length),
                        color: running
                            ? context.chakra.success
                            : context.chakra.fgSubtle,
                        size: 10,
                      ),
                    ],
                  ),
                ),
                MockTooltipIconButton(
                  tooltip: running
                      ? AppLocalizations.of(context).stopSavedServer
                      : canStart
                      ? AppLocalizations.of(context).startSavedServer
                      : server.lifecycle == MockServerLifecycle.archived
                      ? AppLocalizations.of(context).archivedServerCannotStart
                      : AppLocalizations.of(context).disabledServerCannotStart,
                  onPressed: running
                      ? onStop == null
                            ? null
                            : () => onStop!(ref)
                      : onStart == null || !canStart
                      ? null
                      : () => onStart!(ref),
                  icon: running
                      ? Icons.stop_outlined
                      : Icons.play_arrow_outlined,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

enum _MockCreationAction { blank, fromResponse }

class _MockCreationMenu extends StatelessWidget {
  const _MockCreationMenu({
    required this.canCreateFromResponse,
    required this.onCreateManual,
    required this.onCreateFromResponse,
  });

  final bool canCreateFromResponse;
  final VoidCallback onCreateManual;
  final VoidCallback onCreateFromResponse;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_MockCreationAction>(
    key: const Key('mock-create-menu'),
    tooltip: AppLocalizations.of(context).newMock,
    icon: const Icon(Icons.add, size: 18),
    onSelected: (action) {
      switch (action) {
        case _MockCreationAction.blank:
          onCreateManual();
        case _MockCreationAction.fromResponse:
          onCreateFromResponse();
      }
    },
    itemBuilder: (context) => [
      PopupMenuItem(
        key: const Key('mock-create-manual-action'),
        value: _MockCreationAction.blank,
        child: Text(AppLocalizations.of(context).newMock),
      ),
      PopupMenuItem(
        key: const Key('mock-create-from-response-action'),
        value: _MockCreationAction.fromResponse,
        enabled: canCreateFromResponse,
        child: Text(AppLocalizations.of(context).createMockFromResponse),
      ),
    ],
  );
}
