import 'dart:convert';
import 'dart:io';

import '../../domain/preferences/workspace_preferences.dart';
import '../../domain/repositories/workspace_preference_store.dart';

/// 将工作区偏好设置持久化到 JSON 配置文件的实现。
///
/// 配置写入 `preferences.json`，存储位置可显式指定，否则遵循
/// XDG 约定（无 XDG_CONFIG_HOME 时回退到 `~/.config/sendreq`）。
class FileWorkspacePreferenceStore implements WorkspacePreferenceStore {
  /// 创建偏好存储；[configurationDirectory] 可显式指定存储目录。
  FileWorkspacePreferenceStore({this.configurationDirectory});

  /// 显式指定的配置目录；为 null 时按系统约定自动推导。
  final Directory? configurationDirectory;

  /// 加载偏好设置；任何异常都回退到默认配置。
  @override
  Future<WorkspacePreferences> load() async {
    try {
      return await loadForMigration();
    } on Object {
      // 任何读写或解析异常都不阻断启动，统一回退到默认值。
      return WorkspacePreferences.defaults;
    }
  }

  /// 读取旧 JSON 供迁移使用。与 [load] 不同，存在但无效的文件会抛出，
  /// 让启动层保留源文件并向用户提供修复和重试入口。
  Future<WorkspacePreferences> loadForMigration() async {
    final file = _file;
    if (!await file.exists()) return WorkspacePreferences.defaults;
    final value = jsonDecode(await file.readAsString());
    // 兼容历次旧版本格式；不认识的版本一律视为无效。
    if (value is! Map<String, dynamic> ||
        (value['version'] != 1 &&
            value['version'] != 2 &&
            value['version'] != 3 &&
            value['version'] != 4)) {
      throw const FormatException('Unsupported legacy preference format.');
    }
    final appearance = _appearance(value['appearance']);
    final shortcut = _shortcut(value['sendShortcut']);
    // 各版本新增字段：旧版本按字段引入的版本提供默认值。
    final locale = value['version'] == 1
        ? LocalePreference.system
        : _locale(value['locale']);
    final font = value['version'] == 3 || value['version'] == 4
        ? _font(value['font'])
        : WorkspaceFontPreference.inter;
    final customShortcut = value['version'] == 3 || value['version'] == 4
        ? ShortcutBinding.fromJson(value['customSendShortcut'])
        : ShortcutBinding.controlEnter;
    final rawDocumentationOutputDirectory = value['version'] == 4
        ? value['documentationOutputDirectory']
        : null;
    final documentationOutputDirectory =
        rawDocumentationOutputDirectory is String &&
            rawDocumentationOutputDirectory.trim().isNotEmpty
        ? rawDocumentationOutputDirectory.trim()
        : null;
    if (appearance == null ||
        shortcut == null ||
        locale == null ||
        font == null ||
        customShortcut == null ||
        (rawDocumentationOutputDirectory != null &&
            documentationOutputDirectory == null)) {
      throw const FormatException('Invalid legacy preference values.');
    }
    return WorkspacePreferences(
      appearance: appearance,
      sendShortcut: shortcut,
      locale: locale,
      font: font,
      customSendShortcut: customShortcut,
      documentationOutputDirectory: documentationOutputDirectory,
    );
  }

  /// 将偏好设置持久化到配置文件。
  @override
  Future<void> save(WorkspacePreferences preferences) async {
    final directory = _directory;
    await directory.create(recursive: true);
    // 先写临时文件再原子重命名，避免写入中断留下损坏的配置。
    final temporary = File('${_file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'version': 4,
        'appearance': preferences.appearance.name,
        'sendShortcut': preferences.sendShortcut.name,
        'locale': preferences.locale.name,
        'font': preferences.font.name,
        'customSendShortcut': preferences.customSendShortcut.toJson(),
        'documentationOutputDirectory':
            preferences.documentationOutputDirectory,
      }),
      flush: true,
    );
    await temporary.rename(_file.path);
  }

  /// 在迁移至平台偏好存储前创建旧配置的不可覆盖备份。
  ///
  /// 源文件不存在时不创建空备份；调用方应在写入新存储前调用本方法。
  Future<void> backupIfPresent() async {
    final source = _file;
    if (!await source.exists()) return;
    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    await source.copy('${source.path}.$timestamp.bak');
  }

  /// 解析配置存储目录：优先显式目录，其次 XDG 配置路径，最后回退到 home/当前目录。
  Directory get _directory {
    if (configurationDirectory != null) return configurationDirectory!;
    final configured = Platform.environment['XDG_CONFIG_HOME'];
    if (configured != null && configured.isNotEmpty) {
      return Directory('$configured/sendreq');
    }
    final home = Platform.environment['HOME'];
    // 无 HOME 环境变量时退化到进程工作目录下的隐藏目录。
    return home == null || home.isEmpty
        ? Directory('${Directory.current.path}/.sendreq')
        : Directory('$home/.config/sendreq');
  }

  /// 配置文件的实际路径。
  File get _file => File('${_directory.path}/preferences.json');

  /// 将存储字符串解析为主题偏好，无法识别时返回 null。
  AppearancePreference? _appearance(Object? value) => switch (value) {
    'light' => AppearancePreference.light,
    'dark' => AppearancePreference.dark,
    'system' => AppearancePreference.system,
    _ => null,
  };

  /// 将存储字符串解析为发送快捷键偏好，无法识别时返回 null。
  SendShortcutPreference? _shortcut(Object? value) => switch (value) {
    'controlEnter' => SendShortcutPreference.controlEnter,
    'controlSpace' => SendShortcutPreference.controlSpace,
    'custom' => SendShortcutPreference.custom,
    _ => null,
  };

  /// 将存储字符串解析为语言偏好，无法识别时返回 null。
  LocalePreference? _locale(Object? value) => switch (value) {
    'system' => LocalePreference.system,
    'english' => LocalePreference.english,
    'simplifiedChinese' => LocalePreference.simplifiedChinese,
    _ => null,
  };

  /// 将存储字符串解析为字体偏好，无法识别时返回 null。
  WorkspaceFontPreference? _font(Object? value) => switch (value) {
    'inter' => WorkspaceFontPreference.inter,
    'notoSans' => WorkspaceFontPreference.notoSans,
    'system' => WorkspaceFontPreference.system,
    _ => null,
  };
}
