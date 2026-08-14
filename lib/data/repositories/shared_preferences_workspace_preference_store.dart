import 'package:shared_preferences/shared_preferences.dart';

import 'package:sendreq/domain/preferences/workspace_preferences.dart';
import 'package:sendreq/data/repositories/file_workspace_preference_store.dart';
import 'package:sendreq/domain/repositories/workspace_preference_store.dart';

/// 基于平台 KV 存储的轻量工作区偏好实现。
///
/// Collection 与执行结果不使用该存储。首次读取时可将旧
/// [FileWorkspacePreferenceStore] 的配置迁入，并只在迁入成功后写入版本标记。
class SharedPreferencesWorkspacePreferenceStore
    implements WorkspacePreferenceStore {
  /// 私有构造，仅由 [create] 与 [fromPreferences] 调用。
  SharedPreferencesWorkspacePreferenceStore._(
    this._preferences, {
    this.legacyStore,
  });

  /// 当前偏好存储的 schema 版本。
  static const _schemaVersion = 3;

  /// 写入的 schema 版本标记键。
  static const _schemaKey = 'sendreq.preferences.schema_version';

  /// 外观偏好的存储键。
  static const _appearanceKey = 'sendreq.preferences.appearance';

  /// 已废弃的发送快捷键存储键；保存时主动清除。
  static const _sendShortcutKey = 'sendreq.preferences.send_shortcut';

  /// 语言偏好的存储键。
  static const _localeKey = 'sendreq.preferences.locale';

  /// 字体偏好的存储键。
  static const _fontKey = 'sendreq.preferences.font';
  static const _codeFontKey = 'sendreq.preferences.code_font';
  static const _codeFontSizeKey = 'sendreq.preferences.code_font_size';

  /// 已废弃的自定义快捷键存储键；保存时主动清除。
  static const _customShortcutKey = 'sendreq.preferences.custom_shortcut';

  /// 旧版本不再使用的输出目录键；保存时主动清除。
  static const _legacyOutputDirectoryKey =
      'sendreq.preferences.documentation_output_directory';

  /// 底层平台 KV 存储。
  final SharedPreferences _preferences;

  /// 可选的旧 JSON 偏好存储，用于首次读取时迁移。
  final FileWorkspacePreferenceStore? legacyStore;

  /// 最近一次旧配置迁移的失败原因（无则保持 null）。
  Object? _migrationIssue;

  /// 旧 JSON 迁移的最近失败原因；原文件不会因该失败被删除或覆盖。
  Object? get migrationIssue => _migrationIssue;

  /// 创建正式桌面偏好存储。
  static Future<SharedPreferencesWorkspacePreferenceStore> create({
    FileWorkspacePreferenceStore? legacyStore,
  }) async => SharedPreferencesWorkspacePreferenceStore._(
    await SharedPreferences.getInstance(),
    legacyStore: legacyStore,
  );

  /// 供单元测试注入受控平台偏好实现。
  static SharedPreferencesWorkspacePreferenceStore fromPreferences(
    SharedPreferences preferences, {
    FileWorkspacePreferenceStore? legacyStore,
  }) => SharedPreferencesWorkspacePreferenceStore._(
    preferences,
    legacyStore: legacyStore,
  );

  /// 加载偏好：首次且存在旧配置时先迁移，失败则返回默认值并记录原因。
  @override
  Future<WorkspacePreferences> load() async {
    _migrationIssue = null;
    final version = _preferences.getInt(_schemaKey);
    // 无版本标记且存在旧配置时，尝试一次性迁移。
    if (version == null && legacyStore != null) {
      try {
        await _migrateLegacyPreferences();
      } on Object catch (error) {
        _migrationIssue = error;
        return WorkspacePreferences.defaults;
      }
    }
    return _readCurrent();
  }

  /// 将完整偏好快照写入平台 KV 存储。
  @override
  Future<void> save(WorkspacePreferences preferences) async {
    // 完整快照按固定顺序写入；ViewModel 负责将多个快照串行化。
    await _preferences.setString(_appearanceKey, preferences.appearance.name);
    await _preferences.setString(_localeKey, preferences.locale.name);
    await _preferences.setString(_fontKey, preferences.font.name);
    await _preferences.setString(_codeFontKey, preferences.codeFont.name);
    await _preferences.setDouble(
      _codeFontSizeKey,
      preferences.codeFontSize.clamp(10, 18),
    );
    await _preferences.remove(_sendShortcutKey);
    await _preferences.remove(_customShortcutKey);
    await _preferences.remove(_legacyOutputDirectoryKey);
    await _preferences.setInt(_schemaKey, _schemaVersion);
  }

  /// 备份旧配置并迁移到新存储；备份失败时不迁移。
  Future<void> _migrateLegacyPreferences() async {
    // 备份失败时不迁移，避免新存储成为唯一副本。
    await legacyStore!.backupIfPresent();
    final legacyPreferences = await legacyStore!.loadForMigration();
    await save(legacyPreferences);
  }

  /// 从 KV 读取并解析当前偏好；任一字段无效时回退默认值。
  WorkspacePreferences _readCurrent() {
    final appearance = _appearance(_preferences.getString(_appearanceKey));
    final locale = _locale(_preferences.getString(_localeKey));
    final font = _font(_preferences.getString(_fontKey));
    final codeFont =
        _codeFont(_preferences.getString(_codeFontKey)) ??
        CodeFontPreference.jetBrainsMono;
    final codeFontSize =
        _preferences.getDouble(_codeFontSizeKey)?.clamp(10, 18).toDouble() ??
        12;
    // 任一字段缺失或非法时，整体回退到默认配置。
    if (appearance == null || locale == null || font == null) {
      return WorkspacePreferences.defaults;
    }
    return WorkspacePreferences(
      appearance: appearance,
      locale: locale,
      font: font,
      codeFont: codeFont,
      codeFontSize: codeFontSize,
    );
  }

  /// 将存储字符串解析为外观偏好，无法识别时返回 null。
  AppearancePreference? _appearance(String? value) => switch (value) {
    'light' => AppearancePreference.light,
    'dark' => AppearancePreference.dark,
    'system' => AppearancePreference.system,
    _ => null,
  };

  /// 将存储字符串解析为语言偏好，无法识别时返回 null。
  LocalePreference? _locale(String? value) => switch (value) {
    'system' => LocalePreference.system,
    'english' => LocalePreference.english,
    'simplifiedChinese' => LocalePreference.simplifiedChinese,
    _ => null,
  };

  /// 将存储字符串解析为字体偏好，无法识别时返回 null。
  WorkspaceFontPreference? _font(String? value) => switch (value) {
    // Historical unbundled families migrate to the reliable system font.
    'fluent' || 'segoeUi' || 'inter' => WorkspaceFontPreference.system,
    'notoSans' => WorkspaceFontPreference.notoSans,
    'system' => WorkspaceFontPreference.system,
    _ => null,
  };

  CodeFontPreference? _codeFont(String? value) => switch (value) {
    'jetBrainsMono' => CodeFontPreference.jetBrainsMono,
    'sourceCodePro' => CodeFontPreference.system,
    'system' => CodeFontPreference.system,
    _ => null,
  };
}
