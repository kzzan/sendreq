/// 由各持久化边界独占的版本化 WorkspaceDocument 键。
///
/// 版本属于载荷格式而非 Isar collection schema。
abstract final class WorkspaceDocumentKeys {
  static const persistentMockServersV1 = 'persistent-mock-servers-v1';
  static const userNoticesV1 = 'user-notices-v1';
}
