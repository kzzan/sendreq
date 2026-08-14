import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/code_text_theme.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/application/user_message.dart';
import 'package:sendreq/ui/core/widgets/user_message_scope.dart';

/// 复制 [value] 到系统剪贴板，并通过统一消息通知提示 [message]。
///
/// 所有需要“复制 + 提示”的面板共用此实现，避免各面板重复编写剪贴板代码。
void copyToClipboard(BuildContext context, String value, String message) {
  Clipboard.setData(ClipboardData(text: value));
  publishUserMessage(
    context,
    message,
    severity: UserMessageSeverity.success,
    deduplicationKey: 'clipboard.copied',
  );
}

/// 紧凑型信息面板容器：带背景色与描边的通用包裹组件，
/// 供密集工具栏区域统一信息展示样式。
class DensePanel extends StatelessWidget {
  /// 构造紧凑信息面板。
  const DensePanel({
    super.key,
    required this.child,
    this.padding = WorkspaceLayoutMetrics.panelPadding,
  });

  /// 面板内部内容。
  final Widget child;

  /// 内边距，默认使用工作台的统一 8px 基线。
  final EdgeInsetsGeometry padding;

  /// 构建信息面板容器。
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: ChakraSlotRecipes.panel(context.chakra),
      child: child,
    );
  }
}

/// 面板标题栏：左侧主标题（可选副标题），右侧可选的尾部控件。
class PanelTitle extends StatelessWidget {
  /// 构造面板标题栏。
  const PanelTitle({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
  });

  /// 主标题文本。
  final String title;

  /// 可选副标题，显示在主标题下方（如资源数量统计）。
  final String? subtitle;

  /// 标题栏右侧的尾部控件（如一排工具按钮）。
  final Widget? trailing;

  /// 构建标题栏：主标题、副标题与尾部控件。
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // 无副标题时取较矮高度，保证标题栏紧凑
      constraints: BoxConstraints(
        minHeight: subtitle == null
            ? WorkspaceLayoutMetrics.panelTitleHeight
            : 40,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// 等宽字体文本：默认使用 JetBrains Mono，适合代码/数字等符号展示。
class MonoText extends StatelessWidget {
  /// 构造等宽字体文本。
  const MonoText(
    this.data, {
    super.key,
    this.color,
    this.size = 12,
    this.weight = FontWeight.w500,
  });

  /// 显示的文本内容。
  final String data;

  /// 文本颜色，默认使用主题主文字色。
  final Color? color;

  /// 字号，默认 12。
  final double size;

  /// 字重，默认 w500。
  final FontWeight weight;

  /// 构建等宽字体文本。
  @override
  Widget build(BuildContext context) {
    final codeTheme = Theme.of(context).extension<CodeTextTheme>();
    return Text(
      data,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color ?? context.chakra.fg,
        fontFamily: codeTheme?.fontFamily ?? 'JetBrains Mono',
        fontSize: size == 12 ? codeTheme?.fontSize ?? size : size,
        fontWeight: weight,
        letterSpacing: 0,
      ),
    );
  }
}

/// HTTP 方法徽标：按方法名（GET/POST 等）着色的小胶囊。
class MethodPill extends StatelessWidget {
  /// 构造 HTTP 方法徽标。
  const MethodPill(
    this.method, {
    super.key,
    this.width = 56,
    this.height = 22,
    this.fontSize = 11,
  });

  /// HTTP 方法名，如 GET、POST、PUT、DELETE。
  final String method;

  /// 徽标宽度，默认 56。
  final double width;

  /// 徽标高度，默认 22。
  final double height;

  /// 方法文字字号，默认 11。
  final double fontSize;

  /// 构建 HTTP 方法徽标。
  @override
  Widget build(BuildContext context) {
    // 按 HTTP 方法映射颜色，未识别的方法回退到主题主色
    final color = switch (method) {
      'GET' => context.chakra.methodGet,
      'POST' => context.chakra.methodPost,
      'PUT' => context.chakra.methodPut,
      'DELETE' => context.chakra.methodDelete,
      _ => context.chakra.colorPaletteFg,
    };

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: ChakraRadii.control,
      ),
      child: MonoText(
        method,
        color: color,
        size: fontSize,
        weight: FontWeight.w700,
      ),
    );
  }
}

/// 请求类型徽标：HTTP 方法、WebSocket 和 gRPC 使用同一展示规格。
class RequestKindPill extends StatelessWidget {
  /// 构造请求类型徽标。
  const RequestKindPill({
    super.key,
    required this.protocol,
    required this.method,
    this.width = 76,
    this.height = 20,
    this.fontSize = 10,
  });

  final ApiRequestProtocol protocol;
  final String method;
  final double width;
  final double height;
  final double fontSize;

  @override
  /// 构建方法徽标：按协议/方法映射颜色与文案。
  Widget build(BuildContext context) {
    final (label, color) = switch (protocol) {
      ApiRequestProtocol.http => (
        method,
        _httpMethodColor(context.chakra, method),
      ),
      ApiRequestProtocol.webSocket => ('WebSocket', context.chakra.success),
      ApiRequestProtocol.grpc => ('gRPC', context.chakra.colorPaletteFg),
    };
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: ChakraRadii.control,
      ),
      child: MonoText(
        label,
        color: color,
        size: fontSize,
        weight: FontWeight.w700,
      ),
    );
  }
}

/// 将 HTTP 方法名映射为徽标颜色；未知方法使用主色。
Color _httpMethodColor(ChakraSemanticTokens tokens, String method) =>
    switch (method) {
      'GET' => tokens.methodGet,
      'POST' => tokens.methodPost,
      'PUT' => tokens.methodPut,
      'DELETE' => tokens.methodDelete,
      _ => tokens.colorPaletteFg,
    };

/// HTTP 状态码徽标：>= 400 以危险色显示，其余以成功色显示。
class StatusPill extends StatelessWidget {
  /// 以状态码构造徽标。
  const StatusPill(this.statusCode, {super.key});

  /// 要展示的 HTTP 状态码。
  final int statusCode;

  /// 构建 HTTP 状态码徽标。
  @override
  Widget build(BuildContext context) {
    // 4xx/5xx 视为失败用危险色，其余视为成功用成功色
    final color = statusCode >= 400
        ? context.chakra.error
        : context.chakra.success;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: ChakraRadii.control,
      ),
      child: MonoText(
        '$statusCode',
        color: color,
        size: 12,
        weight: FontWeight.w700,
      ),
    );
  }
}

/// 紧凑图标按钮：带 Tooltip 提示，适合在空间紧张的工具栏中密集排布。
class DenseIconButton extends StatelessWidget {
  /// 构造紧凑图标按钮。
  const DenseIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 32,
    this.showTooltip = true,
  });

  /// 按钮图标。
  final IconData icon;

  /// 悬停/长按时显示的提示文本。
  final String tooltip;

  /// 点击回调；为 null 时按钮处于禁用状态。
  final VoidCallback? onPressed;

  /// 按钮边长（宽高一致），默认 32。
  final double size;

  /// 流式时间线中的按钮会频繁增删，禁用 Tooltip 避免动画状态复用。
  final bool showTooltip;

  /// 构建紧凑图标按钮：Tooltip + 固定尺寸 IconButton。
  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      style: ChakraRecipes.iconFor(context, size: size),
      iconSize: 18,
      onPressed: onPressed,
      icon: Icon(icon),
    );
    if (showTooltip) {
      return Tooltip(
        key: ValueKey('dense-tooltip-$tooltip'),
        message: tooltip,
        child: button,
      );
    }
    return button;
  }
}

/// 分段标签切换栏：横向排布的一组标签按钮，支持横向滚动。
class SegmentedTabs extends StatelessWidget {
  /// 构造分段标签切换栏。
  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.active,
    required this.onSelected,
  });

  /// 所有标签文本列表。
  final List<String> tabs;

  /// 当前激活的标签文本。
  final String active;

  /// 用户切换标签时的回调。
  final ValueChanged<String> onSelected;

  /// 构建可横向滚动的分段标签栏。
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // 允许横向滚动，避免标签过多时超出可用宽度
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                style: ChakraRecipes.compactSelectableFor(
                  context,
                  selected: tab == active,
                ),
                onPressed: () => onSelected(tab),
                child: Text(tab),
              ),
            ),
        ],
      ),
    );
  }
}
