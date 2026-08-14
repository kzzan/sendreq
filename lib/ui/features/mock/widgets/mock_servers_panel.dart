import 'package:flutter/material.dart';

import 'package:sendreq/domain/contract_publishing/mock_server.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/features/mock/widgets/mock_servers_panel_workspace.dart';

/// Mock 面板需要的安全投影和显式 Shell 命令。
///
/// 它刻意不持有 Workspace ViewModel、环境值、请求草稿或本地运行时。
class MockServersPanelState {
  const MockServersPanelState({
    this.savedMockServers = const [],
    this.selectedMockServerId,
    this.selectMockServer,
    required this.canCreateFromResponse,
    required this.createManual,
    required this.createFromResponse,
    this.startSaved,
    this.stopSaved,
    this.saveSaved,
    this.archiveSaved,
    this.deleteSaved,
    this.openSource,
    this.sourceUnavailableReason,
  });

  final List<MockServerProjection> savedMockServers;
  final String? selectedMockServerId;
  final ValueChanged<String>? selectMockServer;
  final bool canCreateFromResponse;
  final VoidCallback createManual;
  final VoidCallback createFromResponse;
  final Future<void> Function(ResourceRef ref)? startSaved;
  final Future<void> Function(ResourceRef ref)? stopSaved;
  final Future<void> Function(MockServer server)? saveSaved;
  final Future<void> Function(ResourceRef ref)? archiveSaved;
  final Future<void> Function(ResourceRef ref)? deleteSaved;
  final ValueChanged<MockSourceReference>? openSource;
  final String? Function(MockSourceReference source)? sourceUnavailableReason;
}

/// Mock 面板只展示持久化 HTTP Server 的安全投影。
class MockServersPanel extends StatelessWidget {
  const MockServersPanel({super.key, required this.state});

  final MockServersPanelState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.chakra.bg,
      child: state.savedMockServers.isNotEmpty
          ? SavedMockServerWorkspace(
              servers: state.savedMockServers,
              selectedId: state.selectedMockServerId,
              onSelect: state.selectMockServer,
              canCreateFromResponse: state.canCreateFromResponse,
              onCreateManual: state.createManual,
              onCreateFromResponse: state.createFromResponse,
              onSave: state.saveSaved,
              onStart: state.startSaved,
              onStop: state.stopSaved,
              onArchive: state.archiveSaved,
              onDelete: state.deleteSaved,
              onOpenSource: state.openSource,
              sourceUnavailableReason: state.sourceUnavailableReason,
            )
          : _EmptyState(
              canCreateFromResponse: state.canCreateFromResponse,
              onCreateManual: state.createManual,
              onCreateFromResponse: state.createFromResponse,
            ),
    );
  }
}

/// Saved mock server workspace, editor, and controls live in dedicated part files.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.canCreateFromResponse,
    required this.onCreateManual,
    required this.onCreateFromResponse,
  });

  final bool canCreateFromResponse;
  final VoidCallback onCreateManual;
  final VoidCallback onCreateFromResponse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route_outlined,
              size: 32,
              color: context.chakra.fgSubtle,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noMockDraft,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.mockLoopbackNote,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.chakra.fgMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('mock-create-manual-action'),
              onPressed: onCreateManual,
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.newMock),
            ),
            if (canCreateFromResponse) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('mock-create-from-response-action'),
                onPressed: onCreateFromResponse,
                icon: const Icon(Icons.content_copy_outlined, size: 16),
                label: Text(l10n.createMockFromResponse),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
