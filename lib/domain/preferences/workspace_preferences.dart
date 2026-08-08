import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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

/// 发送请求快捷键偏好。
enum SendShortcutPreference {
  /// Ctrl+Enter 发送。
  controlEnter,

  /// Ctrl+Space 发送。
  controlSpace,

  /// 用户录入的自定义组合键。
  custom,
}

/// 快捷键偏好的展示标签。
extension SendShortcutPreferenceCopy on SendShortcutPreference {
  /// 返回快捷键选项的标签。
  String get label => switch (this) {
    SendShortcutPreference.controlEnter => 'Ctrl+Enter',
    SendShortcutPreference.controlSpace => 'Ctrl+Space',
    SendShortcutPreference.custom => 'Custom',
  };
}

/// 应用界面使用的字体偏好；数据和代码区域仍保持等宽字体以便扫描。
enum WorkspaceFontPreference {
  /// Inter 字体。
  inter,

  /// Noto Sans 字体。
  notoSans,

  /// 跟随系统字体。
  system,
}

/// 字体偏好的展示信息。
extension WorkspaceFontPreferenceCopy on WorkspaceFontPreference {
  /// 返回字体偏好的字体族名；system 返回 null 表示使用系统默认。
  String? get family => switch (this) {
    WorkspaceFontPreference.inter => 'Inter',
    WorkspaceFontPreference.notoSans => 'Noto Sans',
    WorkspaceFontPreference.system => null,
  };
}

/// 可持久化的单一全局快捷键组合。
class ShortcutBinding {
  /// 构建快捷键绑定。
  const ShortcutBinding({
    required this.keyId,
    required this.keyLabel,
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  });

  /// 预置的 Ctrl+Enter 绑定。
  static const controlEnter = ShortcutBinding(
    keyId: 0x0010000000d,
    keyLabel: 'Enter',
    control: true,
  );

  /// 预置的 Ctrl+Space 绑定。
  static const controlSpace = ShortcutBinding(
    keyId: 0x00000000020,
    keyLabel: 'Space',
    control: true,
  );

  /// 主键的 Flutter keyId。
  final int keyId;

  /// 主键的展示文本。
  final String keyLabel;

  /// 是否按下 Control。
  final bool control;

  /// 是否按下 Alt。
  final bool alt;

  /// 是否按下 Shift。
  final bool shift;

  /// 是否按下 Meta（Command）。
  final bool meta;

  /// 是否携带任意修饰键。
  bool get hasModifier => control || alt || shift || meta;

  /// 组合键的展示标签，例如 “Ctrl+Enter”。
  String get label {
    final parts = <String>[
      if (control) 'Ctrl',
      if (meta) 'Cmd',
      if (alt) 'Alt',
      if (shift) 'Shift',
      keyLabel,
    ];
    return parts.join('+');
  }

  /// 对应的 Flutter 快捷键激活器。
  ShortcutActivator get activator => SingleActivator(
    // 未注册的 keyId 回退为直接构造的按键。
    LogicalKeyboardKey.findKeyByKeyId(keyId) ?? LogicalKeyboardKey(keyId),
    control: control,
    alt: alt,
    shift: shift,
    meta: meta,
  );

  /// 判断是否与应用保留的快捷键（Ctrl/Cmd+K 与 Ctrl/Cmd+S）冲突。
  bool conflictsWithReservedAction() {
    final isCommand = control || meta;
    final isUnmodifiedCommand = isCommand && !alt && !shift;
    // 仅当 Ctrl/Cmd 且不带其它修饰键时，才可能与保留快捷键冲突。
    return isUnmodifiedCommand &&
        (keyId == LogicalKeyboardKey.keyK.keyId ||
            keyId == LogicalKeyboardKey.keyS.keyId);
  }

  /// 序列化为 JSON。
  Map<String, Object> toJson() => {
    'keyId': keyId,
    'keyLabel': keyLabel,
    'control': control,
    'alt': alt,
    'shift': shift,
    'meta': meta,
  };

  /// 从 JSON 还原绑定；字段缺失或类型不合法时返回 null。
  static ShortcutBinding? fromJson(Object? value) {
    // 严格校验字段类型，避免损坏的持久化数据被还原。
    if (value is! Map<String, dynamic>) return null;
    final keyId = value['keyId'];
    final keyLabel = value['keyLabel'];
    if (keyId is! int || keyLabel is! String || keyLabel.isEmpty) return null;
    final control = value['control'];
    final alt = value['alt'];
    final shift = value['shift'];
    final meta = value['meta'];
    if (control is! bool || alt is! bool || shift is! bool || meta is! bool) {
      return null;
    }
    return ShortcutBinding(
      keyId: keyId,
      keyLabel: keyLabel,
      control: control,
      alt: alt,
      shift: shift,
      meta: meta,
    );
  }

  /// 从按键事件构建绑定；仅接受 KeyDownEvent，纯修饰键按下被忽略。
  static ShortcutBinding? fromKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || _isModifier(event.logicalKey)) return null;
    final key = event.logicalKey;
    final label = key.keyLabel.trim();
    // 部分按键没有 keyLabel，退回调试名作为展示文本。
    return ShortcutBinding(
      keyId: key.keyId,
      keyLabel: label.isEmpty ? (key.debugName ?? 'Key') : label,
      control: HardwareKeyboard.instance.isControlPressed,
      alt: HardwareKeyboard.instance.isAltPressed,
      shift: HardwareKeyboard.instance.isShiftPressed,
      meta: HardwareKeyboard.instance.isMetaPressed,
    );
  }

  /// 判断按键是否属于修饰键（Ctrl/Alt/Shift/Meta）。
  static bool _isModifier(LogicalKeyboardKey key) => {
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  }.contains(key);

  @override
  bool operator ==(Object other) =>
      other is ShortcutBinding &&
      other.keyId == keyId &&
      other.keyLabel == keyLabel &&
      other.control == control &&
      other.alt == alt &&
      other.shift == shift &&
      other.meta == meta;

  @override
  /// 基于全部绑定字段计算哈希值。
  int get hashCode => Object.hash(keyId, keyLabel, control, alt, shift, meta);
}

/// 工作区用户偏好集合。
class WorkspacePreferences {
  /// 构建工作区偏好。
  const WorkspacePreferences({
    required this.appearance,
    required this.sendShortcut,
    this.locale = LocalePreference.system,
    this.font = WorkspaceFontPreference.inter,
    this.customSendShortcut = ShortcutBinding.controlEnter,
    this.documentationOutputDirectory,
  });

  /// 默认偏好（深色外观 + Ctrl+Enter 发送 + 跟随系统语言）。
  static const defaults = WorkspacePreferences(
    appearance: AppearancePreference.dark,
    sendShortcut: SendShortcutPreference.controlEnter,
    locale: LocalePreference.system,
    font: WorkspaceFontPreference.inter,
    customSendShortcut: ShortcutBinding.controlEnter,
    documentationOutputDirectory: null,
  );

  /// 外观偏好。
  final AppearancePreference appearance;

  /// 发送快捷键偏好。
  final SendShortcutPreference sendShortcut;

  /// 语言偏好。
  final LocalePreference locale;

  /// 应用正文与控件字体。
  final WorkspaceFontPreference font;

  /// 当 [sendShortcut] 为 custom 时生效的组合键。
  final ShortcutBinding customSendShortcut;

  /// Markdown 接口文档的输出目录；未设置时导出操作会要求用户先选择目录。
  final String? documentationOutputDirectory;
}
