import 'package:flutter/material.dart';

/// 桌面工作台表单控件的统一几何规格。
///
/// 普通配置表单使用 [standardHeight]；键值表、工具栏等高密度场景可明确
/// 选择 [denseHeight]，避免同一页面中控件随内容或状态出现跳动。
abstract final class FormControlMetrics {
  /// 常规输入框和下拉框高度，兼顾桌面紧凑度与点击、聚焦舒适度。
  static const double standardHeight = 36;

  /// 表格与工具栏中的内联控件高度。
  static const double denseHeight = 30;

  /// 多行编辑器开始时的推荐高度。
  static const double multilineMinHeight = 88;

  /// 常规单行控件的文字水平内边距。
  static const double horizontalPadding = 11;

  /// 单行字段的上下内边距；配合 [standardHeight] 保持文字垂直居中。
  static const double verticalPadding = 8;

  /// 全局单行控件的最小约束，内容增多时仍可自然扩展。
  static const BoxConstraints standardConstraints = BoxConstraints(
    minHeight: standardHeight,
  );

  /// 前后缀图标使用同样高度，避免图标将输入框异常撑高。
  static const BoxConstraints iconConstraints = BoxConstraints(
    minWidth: standardHeight,
    minHeight: standardHeight,
  );

  /// 标准文本框内边距。
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: horizontalPadding,
    vertical: verticalPadding,
  );
}
