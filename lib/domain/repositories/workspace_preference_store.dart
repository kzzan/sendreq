import 'package:sendreq/domain/preferences/workspace_preferences.dart';

/// 工作区偏好的领域仓储契约。
abstract interface class WorkspacePreferenceStore {
  Future<WorkspacePreferences> load();

  Future<void> save(WorkspacePreferences preferences);
}
