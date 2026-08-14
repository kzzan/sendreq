import 'package:sendreq/domain/api_assets/api_asset_models.dart';

/// Owns request tab ordering, activation, title synchronization, and cleanup.
class RequestTabState {
  RequestTabState(Iterable<RequestTab> initialTabs, this.activeRequestId)
    : _tabs = List.of(initialTabs);

  final List<RequestTab> _tabs;
  String? activeRequestId;

  List<RequestTab> get tabs => List.unmodifiable(_tabs);

  RequestTab open(ApiRequestDefinition request) {
    final existing = _tabs.where((tab) => tab.requestId == request.id);
    final tab = existing.isNotEmpty
        ? existing.first
        : RequestTab(
            id: 'tab-${request.id}',
            requestId: request.id,
            title: request.name,
            openedAt: DateTime.now().toUtc(),
          );
    if (existing.isEmpty) _tabs.add(tab);
    activeRequestId = request.id;
    return tab;
  }

  void activate(String tabId) {
    activeRequestId = _tabs.firstWhere((tab) => tab.id == tabId).requestId;
  }

  void close(String tabId) {
    final index = _tabs.indexWhere((tab) => tab.id == tabId);
    if (index < 0) return;
    final wasActive = _tabs[index].requestId == activeRequestId;
    _tabs.removeAt(index);
    if (wasActive) _activateAdjacent(index);
  }

  void removeRequest(String requestId) {
    final index = _tabs.indexWhere((tab) => tab.requestId == requestId);
    if (index < 0) return;
    final wasActive = activeRequestId == requestId;
    _tabs.removeAt(index);
    if (wasActive) _activateAdjacent(index);
  }

  void removeRequests(Set<String> requestIds) {
    final removesActive = requestIds.contains(activeRequestId);
    _tabs.removeWhere((tab) => requestIds.contains(tab.requestId));
    if (removesActive) {
      activeRequestId = _tabs.isEmpty ? null : _tabs.last.requestId;
    }
  }

  void renameRequest(String requestId, String name) {
    for (var index = 0; index < _tabs.length; index++) {
      final tab = _tabs[index];
      if (tab.requestId != requestId) continue;
      _tabs[index] = RequestTab(
        id: tab.id,
        requestId: tab.requestId,
        title: name,
        openedAt: tab.openedAt,
        isDirty: tab.isDirty,
      );
    }
  }

  void _activateAdjacent(int index) {
    activeRequestId = _tabs.isEmpty
        ? null
        : _tabs[(index - 1).clamp(0, _tabs.length - 1)].requestId;
  }
}
