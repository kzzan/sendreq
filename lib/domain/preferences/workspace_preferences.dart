/// 应用外观偏好。
enum AppearancePreference {
  /// 浅色。
  light,

  /// 深色。
  dark,

  /// 跟随系统。
  system,
}

/// 语言偏好。
enum LocalePreference {
  /// 跟随系统。
  system,

  /// 英文。
  english,

  /// 简体中文。
  simplifiedChinese,
}

/// 外观偏好的中文展示标签。
extension AppearancePreferenceCopy on AppearancePreference {
  /// 返回外观选项的中文标签。
  String get label => switch (this) {
    AppearancePreference.light => '浅色',
    AppearancePreference.dark => '深色',
    AppearancePreference.system => '跟随系统',
  };
}

/// 应用界面使用的字体偏好；数据和代码区域仍保持等宽字体以便扫描。
enum WorkspaceFontPreference {
  /// 随应用打包的 Noto Sans 字体。
  notoSans,

  /// 跟随系统字体。
  system,
}

/// 字体偏好的展示信息。
extension WorkspaceFontPreferenceCopy on WorkspaceFontPreference {
  /// 返回字体偏好的字体族名；system 返回 null 表示使用系统默认。
  String? get family => switch (this) {
    WorkspaceFontPreference.notoSans => 'Noto Sans',
    WorkspaceFontPreference.system => null,
  };
}

/// 代码、JSON 与协议时间线使用的等宽字体偏好。
enum CodeFontPreference { jetBrainsMono, system }

extension CodeFontPreferenceCopy on CodeFontPreference {
  String get family => switch (this) {
    CodeFontPreference.jetBrainsMono => 'JetBrains Mono',
    CodeFontPreference.system => 'monospace',
  };
}

/// 工作区用户偏好集合。
class WorkspacePreferences {
  /// 构建工作区偏好。
  const WorkspacePreferences({
    required this.appearance,
    this.locale = LocalePreference.system,
    this.font = WorkspaceFontPreference.system,
    this.codeFont = CodeFontPreference.jetBrainsMono,
    this.codeFontSize = 12,
  });

  /// 默认偏好（深色外观 + 跟随系统语言）。
  static const defaults = WorkspacePreferences(
    appearance: AppearancePreference.dark,
    locale: LocalePreference.system,
    font: WorkspaceFontPreference.system,
    codeFont: CodeFontPreference.jetBrainsMono,
    codeFontSize: 12,
  );

  /// 外观偏好。
  final AppearancePreference appearance;

  /// 语言偏好。
  final LocalePreference locale;

  /// 应用正文与控件字体。
  final WorkspaceFontPreference font;

  /// 代码、JSON 与协议时间线的等宽字体。
  final CodeFontPreference codeFont;

  /// 代码文字基准字号。
  final double codeFontSize;
}
