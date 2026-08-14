import 'package:flutter/material.dart';

import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/widgets/formatted_json_viewer.dart';

/// 响应正文查看器：识别 JSON 后默认美化展示，并允许随时查看原始载荷。

class ResponseBodyViewer extends StatefulWidget {
  /// 以响应正文字符串构造查看器。
  const ResponseBodyViewer(this.body, {super.key});

  /// 响应正文原始内容。
  final String body;

  /// 创建查看器状态。
  @override
  State<ResponseBodyViewer> createState() => _ResponseBodyViewerState();
}

/// 正文查看器状态：解析正文并维护格式化/滚动状态。
class _ResponseBodyViewerState extends State<ResponseBodyViewer> {
  // 响应正文会被反复阅读、对比与复制，因此给代码区域一个
  // 比紧凑 UI 更舒适的桌面级字号。

  /// 代码区字号。
  static const _codeFontSize = 14.0;

  /// 代码区行高。
  static const _codeLineHeight = 1.65;

  /// 解析后的响应正文内容。
  late FormattedJsonContent _content;

  /// 是否展示格式化 JSON（原始视图时置为 false）。
  var _showFormatted = true;

  /// 纵向滚动控制器。
  final _verticalController = ScrollController();

  /// 横向滚动控制器。
  final _horizontalController = ScrollController();

  /// 首次构建时解析响应正文。
  @override
  void initState() {
    super.initState();
    _content = FormattedJsonContent.parse(widget.body);
  }

  /// 正文变化时重新解析并重置回顶部。
  @override
  void didUpdateWidget(covariant ResponseBodyViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.body == widget.body) return;
    _content = FormattedJsonContent.parse(widget.body);
    _showFormatted = true;
    if (_verticalController.hasClients) _verticalController.jumpTo(0);
    if (_horizontalController.hasClients) _horizontalController.jumpTo(0);
  }

  /// 释放两个滚动控制器资源。
  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  /// 当前实际展示的正文（格式化 JSON 或原始内容）。
  String get _displayedBody =>
      _showFormatted && _content.isJson ? _content.formatted : widget.body;

  /// 当前展示正文的 TextSpan（JSON 应用语法着色）。
  TextSpan get _displayedBodySpan => _content.isJson
      ? JsonSyntaxHighlighter.highlight(context.chakra, _displayedBody)
      : TextSpan(text: _displayedBody);

  /// 切换载荷呈现方式而不丢失当前阅读位置。
  void _setFormat(bool showFormatted) {
    if (_showFormatted == showFormatted) return;
    setState(() => _showFormatted = showFormatted);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clampScrollOffset(_verticalController);
      _clampScrollOffset(_horizontalController);
    });
  }

  /// 内容高度或宽度变化后，将现有阅读位置限制在有效范围内。
  void _clampScrollOffset(ScrollController controller) {
    if (!mounted || !controller.hasClients) return;
    final position = controller.position;
    final offset = controller.offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (offset != controller.offset) controller.jumpTo(offset);
  }

  /// 构建查看器：工具栏 + 格式化 JSON 树或原始文本区。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formattedJson = _showFormatted && _content.isJson;
    final isEmpty = _displayedBody.trim().isEmpty;
    const codeStyle = TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: _codeFontSize,
      height: _codeLineHeight,
      letterSpacing: 0,
    );
    return DensePanel(
      key: const Key('response-body-viewer'),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _ResponseBodyToolbar(
            isJson: _content.isJson,
            showFormatted: _showFormatted,
            onFormatChanged: _setFormat,
            onCopy: () => copyToClipboard(
              context,
              _displayedBody,
              l10n.displayedResponseCopied,
            ),
          ),
          Expanded(
            child: isEmpty
                ? _EmptyResponseBody(label: l10n.noResponseBody)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // 让代码画布始终与所在面板同宽，避免较短的响应
                      // 仅仅因为支持横向滚动就坍缩到最长一行的宽度，
                      // 从而保持阅读与复制的整体稳定。
                      final horizontalInset = constraints.maxWidth >= 520
                          ? 20.0
                          : 16.0;
                      final codeCanvasWidth =
                          (constraints.maxWidth - (horizontalInset * 2))
                              .clamp(0.0, double.infinity)
                              .toDouble();
                      final bodyStyle = codeStyle.copyWith(
                        color: context.chakra.fg,
                      );
                      final heightBehavior = const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      );
                      return Container(
                        key: const Key('response-body-viewport'),
                        color: context.chakra.bgSubtle,
                        child: Scrollbar(
                          controller: _verticalController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            key: const Key('response-body-vertical-scroll'),
                            controller: _verticalController,
                            padding: EdgeInsets.fromLTRB(
                              horizontalInset,
                              16,
                              horizontalInset + 2,
                              20,
                            ),
                            child: ClipRect(
                              child: Scrollbar(
                                controller: _horizontalController,
                                notificationPredicate: (notification) =>
                                    notification.metrics.axis ==
                                    Axis.horizontal,
                                child: SingleChildScrollView(
                                  key: const Key(
                                    'response-body-horizontal-scroll',
                                  ),
                                  controller: _horizontalController,
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    key: const Key(
                                      'response-body-scroll-canvas',
                                    ),
                                    constraints: BoxConstraints(
                                      minWidth: codeCanvasWidth,
                                    ),
                                    child: formattedJson
                                        ? FormattedJsonTree(
                                            value: _content.value,
                                            textStyle: bodyStyle,
                                            textHeightBehavior: heightBehavior,
                                            nodeKeyPrefix: 'response-json',
                                          )
                                        : SelectionArea(
                                            key: const Key(
                                              'response-raw-wrapped-text',
                                            ),
                                            child: Text.rich(
                                              _displayedBodySpan,
                                              softWrap: false,
                                              style: bodyStyle,
                                              textHeightBehavior:
                                                  heightBehavior,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 正文查看器工具栏：类型标识、格式化/原始视图切换与复制按钮。
class _ResponseBodyToolbar extends StatelessWidget {
  /// 构造正文工具栏。
  const _ResponseBodyToolbar({
    required this.isJson,
    required this.showFormatted,
    required this.onFormatChanged,
    required this.onCopy,
  });

  /// 正文是否为合法 JSON。
  final bool isJson;

  /// 当前是否展示格式化视图。
  final bool showFormatted;

  /// 格式化/原始视图切换回调。
  final ValueChanged<bool> onFormatChanged;

  /// 复制当前展示正文的回调。
  final VoidCallback onCopy;

  /// 构建工具栏：宽窗用分段控件、窄窗用图标按钮。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.chakra.bgEmphasized,
          border: Border(bottom: BorderSide(color: context.chakra.border)),
        ),
        child: Row(
          children: [
            Icon(
              isJson ? Icons.data_object_outlined : Icons.notes_outlined,
              size: 16,
              color: isJson
                  ? context.chakra.colorPaletteFg
                  : context.chakra.fgMuted,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: MonoText(
                isJson ? l10n.validJson : l10n.plainText,
                color: isJson
                    ? context.chakra.colorPaletteFg
                    : context.chakra.fgMuted,
                size: 10,
              ),
            ),
            if (isJson) ...[
              if (constraints.maxWidth < 1000)
                DenseIconButton(
                  key: const Key('response-body-format-toggle'),
                  icon: showFormatted
                      ? Icons.subject_outlined
                      : Icons.data_object_outlined,
                  tooltip: showFormatted ? l10n.rawView : l10n.formattedView,
                  onPressed: () => onFormatChanged(!showFormatted),
                  size: 30,
                )
              else
                SizedBox(
                  width: 154,
                  child: SegmentedTabs(
                    key: const Key('response-body-format'),
                    tabs: [l10n.formattedView, l10n.rawView],
                    active: showFormatted ? l10n.formattedView : l10n.rawView,
                    onSelected: (value) =>
                        onFormatChanged(value == l10n.formattedView),
                  ),
                ),
              const SizedBox(width: 4),
            ],
            DenseIconButton(
              icon: Icons.copy_outlined,
              tooltip: l10n.copyDisplayedResponse,
              onPressed: onCopy,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }
}

/// 空响应正文占位：正文为空时展示图标与提示文案。
class _EmptyResponseBody extends StatelessWidget {
  /// 构造空正文占位。
  const _EmptyResponseBody({required this.label});

  /// 占位提示文案。
  final String label;

  /// 构建居中的空状态占位。
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('response-empty-body'),
    color: context.chakra.bgSubtle,
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.data_object_outlined,
          size: 22,
          color: context.chakra.fgSubtle,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: context.chakra.fgMuted, fontSize: 12),
        ),
      ],
    ),
  );
}

/// JSON parsing, tree rendering, and syntax highlighting use the shared core viewer.
/// 响应头表格：逐行展示「键 / 值」对。
