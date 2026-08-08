import 'package:flutter/material.dart';

/// 高密度桌面工具的可切换语义色板。
///
/// Widgets read these tokens while rebuilding. The root app changes the active
/// palette before it rebuilds, which keeps custom-painted and Material surfaces
/// in the same appearance mode without a second styling system.
abstract final class AppColors {
  /// 全局背景色。
  static Color background = _dark.background;

  /// 常规表面色。
  static Color surface = _dark.surface;

  /// 低层级表面色。
  static Color surfaceLow = _dark.surfaceLow;

  /// 中间层级表面色。
  static Color surfaceMid = _dark.surfaceMid;

  /// 高层级表面色。
  static Color surfaceHigh = _dark.surfaceHigh;

  /// 最高层级表面色（弹层、工具提示等浮层）。
  static Color surfaceHighest = _dark.surfaceHighest;

  /// 常规描边/分隔线色。
  static Color outline = _dark.outline;

  /// 强调描边色。
  static Color outlineStrong = _dark.outlineStrong;

  /// 主要文本色。
  static Color text = _dark.text;

  /// 次要文本色。
  static Color textMuted = _dark.textMuted;

  /// 弱化文本色（辅助信息）。
  static Color textFaint = _dark.textFaint;

  /// 主强调色。
  static Color primary = _dark.primary;

  /// 主强调容器色。
  static Color primaryContainer = _dark.primaryContainer;

  /// 主强调色上的内容色。
  static Color onPrimary = _dark.onPrimary;

  /// 成功语义色。
  static Color success = _dark.success;

  /// 警告语义色。
  static Color warning = _dark.warning;

  /// 危险/错误语义色。
  static Color danger = _dark.danger;

  /// HTTP GET 方法色。
  static Color methodGet = _dark.methodGet;

  /// HTTP POST 方法色。
  static Color methodPost = _dark.methodPost;

  /// HTTP PUT 方法色。
  static Color methodPut = _dark.methodPut;

  /// HTTP DELETE 方法色。
  static Color methodDelete = _dark.methodDelete;

  /// 按目标亮度切换活动色板；根组件在重建前调用，以保持整套界面外观一致。
  static void applyBrightness(Brightness brightness) {
    // 选择与目标亮度匹配的色板并整体替换当前活动色板。
    final palette = brightness == Brightness.dark ? _dark : _light;
    background = palette.background;
    surface = palette.surface;
    surfaceLow = palette.surfaceLow;
    surfaceMid = palette.surfaceMid;
    surfaceHigh = palette.surfaceHigh;
    surfaceHighest = palette.surfaceHighest;
    outline = palette.outline;
    outlineStrong = palette.outlineStrong;
    text = palette.text;
    textMuted = palette.textMuted;
    textFaint = palette.textFaint;
    primary = palette.primary;
    primaryContainer = palette.primaryContainer;
    onPrimary = palette.onPrimary;
    success = palette.success;
    warning = palette.warning;
    danger = palette.danger;
    methodGet = palette.methodGet;
    methodPost = palette.methodPost;
    methodPut = palette.methodPut;
    methodDelete = palette.methodDelete;
  }

  // 暗色预设色板。
  static const _dark = _AppPalette(
    background: Color(0xFF0B1326),
    surface: Color(0xFF0B1326),
    surfaceLow: Color(0xFF131B2E),
    surfaceMid: Color(0xFF171F33),
    surfaceHigh: Color(0xFF222A3D),
    surfaceHighest: Color(0xFF2D3449),
    outline: Color(0xFF464554),
    outlineStrong: Color(0xFF908FA0),
    text: Color(0xFFDAE2FD),
    textMuted: Color(0xFFC7C4D7),
    textFaint: Color(0xFF908FA0),
    primary: Color(0xFFC0C1FF),
    primaryContainer: Color(0xFF8083FF),
    onPrimary: Color(0xFF1000A9),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFFB783),
    danger: Color(0xFFFFB4AB),
    methodGet: Color(0xFF60A5FA),
    methodPost: Color(0xFF4ADE80),
    methodPut: Color(0xFFC0C1FF),
    methodDelete: Color(0xFFFFB4AB),
  );

  // 亮色预设色板。
  static const _light = _AppPalette(
    background: Color(0xFFF9F9FF),
    surface: Color(0xFFF9F9FF),
    surfaceLow: Color(0xFFF1F3FF),
    surfaceMid: Color(0xFFE9EDFF),
    surfaceHigh: Color(0xFFE1E8FD),
    surfaceHighest: Color(0xFFDCE2F7),
    outline: Color(0xFFC7C4D8),
    outlineStrong: Color(0xFF777587),
    text: Color(0xFF141B2B),
    textMuted: Color(0xFF464555),
    textFaint: Color(0xFF777587),
    primary: Color(0xFF3E32D3),
    primaryContainer: Color(0xFF5850EC),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFBA1A1A),
    methodGet: Color(0xFF3B82F6),
    methodPost: Color(0xFF10B981),
    methodPut: Color(0xFF3E32D3),
    methodDelete: Color(0xFFBA1A1A),
  );
}

/// 一套完整的语义色板（内部不可变数据结构）。
class _AppPalette {
  /// 构造一套完整的语义色板。
  const _AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceLow,
    required this.surfaceMid,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.outline,
    required this.outlineStrong,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.primary,
    required this.primaryContainer,
    required this.onPrimary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.methodGet,
    required this.methodPost,
    required this.methodPut,
    required this.methodDelete,
  });

  // 表面层级色（从背景到最高层浮层）。
  final Color background, surface, surfaceLow, surfaceMid, surfaceHigh;
  // 浮层表面、描边与文本层级色。
  final Color surfaceHighest, outline, outlineStrong, text, textMuted;
  // 弱化文本与主强调色。
  final Color textFaint, primary, primaryContainer, onPrimary;
  // 语义色（成功/警告/危险）与 HTTP 方法色。
  final Color success, warning, danger, methodGet, methodPost, methodPut;
  final Color methodDelete;
}
