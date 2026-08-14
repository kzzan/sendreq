import 'package:flutter/widgets.dart';

/// 高密度工作台的共享几何规格。
///
/// 这些值只描述空间与尺寸，不承载颜色或主题语义。
abstract final class WorkspaceLayoutMetrics {
  /// 一级工具导航栏固定宽度。
  static const double toolRailWidth = 184;

  /// 窄窗口下只保留带 Tooltip 的协议与工具图标。
  static const double compactToolRailWidth = 56;

  /// 一级工具导航项点击高度。
  static const double toolRailItemHeight = 40;

  /// Requests 下协议工作视图的紧凑行高。
  static const double requestViewItemHeight = 32;

  /// 主工作区页面容器的标准内边距。
  static const EdgeInsets pagePadding = EdgeInsets.all(8);

  /// 面板内部的标准内边距。
  static const EdgeInsets panelPadding = EdgeInsets.all(8);

  /// 同一操作组内的常规间距。
  static const double groupGap = 6;

  /// 独立区块之间的间距。
  static const double sectionGap = 8;

  /// 顶部工具栏高度。
  static const double topBarHeight = 44;

  /// 共享面板标题的最小高度。
  static const double panelTitleHeight = 36;

  /// 资源树、列表和紧凑表格的标准行高。
  static const double resourceRowHeight = 32;

  /// 标准输入、选择和分段控件高度。
  static const double fieldHeight = 34;
}
