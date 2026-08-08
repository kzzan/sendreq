import '../../domain/preferences/workspace_preferences.dart';
import '../../domain/repositories/workspace_preference_store.dart';

/// 基于内存的工作区偏好存储，仅供原型使用，重启后数据丢失。
class InMemoryWorkspacePreferenceStore implements WorkspacePreferenceStore {
  /// [initial] 可注入初始偏好；未提供时使用默认配置。
  InMemoryWorkspacePreferenceStore([WorkspacePreferences? initial])
    : _saved = initial ?? WorkspacePreferences.defaults;

  /// 当前保存的偏好值（内存变量，不落盘）。
  WorkspacePreferences _saved;

  /// 同步返回内存中的当前偏好值。
  @override
  Future<WorkspacePreferences> load() async => _saved;

  /// 直接覆盖内存中的偏好值。
  @override
  Future<void> save(WorkspacePreferences preferences) async {
    _saved = preferences;
  }
}
