import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 已保存 Mock Server 的选择投影。
extension WorkspaceContractPublishingOperations on WorkspaceViewModel {
  List<MockServerProjection> get savedMockServers =>
      internals.contractPublishing.mockServers;

  String? get activeMockServerId => internals.activeMockServerId;

  void selectMockServer(String id) {
    if (!savedMockServers.any((item) => item.server.id == id)) return;
    internals.activeMockServerId = id;
    internals.activeSection = WorkspaceSection.mock;
    notifyWorkspace();
  }
}
