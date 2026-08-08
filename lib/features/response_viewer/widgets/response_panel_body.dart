/// 响应正文查看器：识别 JSON 后默认美化展示，并允许随时查看原始载荷。
part of 'response_panel.dart';

class _ResponseBodyViewer extends StatefulWidget {
  /// 以响应正文字符串构造查看器。
  const _ResponseBodyViewer(this.body);

  /// 响应正文原始内容。
  final String body;

  /// 创建查看器状态。
  @override
  State<_ResponseBodyViewer> createState() => _ResponseBodyViewerState();
}

/// 正文查看器状态：解析正文并维护格式化/滚动状态。
class _ResponseBodyViewerState extends State<_ResponseBodyViewer> {
  // Response bodies are read, compared, and copied repeatedly. Give the code
  // surface a more comfortable desktop measure than the compact UI chrome.

  /// 代码区字号。
  static const _codeFontSize = 14.0;

  /// 代码区行高。
  static const _codeLineHeight = 1.65;

  /// 解析后的响应正文内容。
  late _ResponseBodyContent _content;

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
    _content = _ResponseBodyContent.parse(widget.body);
  }

  /// 正文变化时重新解析并重置回顶部。
  @override
  void didUpdateWidget(covariant _ResponseBodyViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.body == widget.body) return;
    _content = _ResponseBodyContent.parse(widget.body);
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
      ? _JsonSyntaxHighlighter.highlight(_displayedBody)
      : TextSpan(text: _displayedBody);

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
            onFormatChanged: (showFormatted) =>
                setState(() => _showFormatted = showFormatted),
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
                      // Keep the code canvas as wide as its pane. A short
                      // response must not collapse to the width of its longest
                      // line simply because horizontal scrolling is available.
                      final horizontalInset = constraints.maxWidth >= 520
                          ? 20.0
                          : 16.0;
                      final codeCanvasWidth =
                          (constraints.maxWidth - (horizontalInset * 2))
                              .clamp(0.0, double.infinity)
                              .toDouble();
                      final bodyStyle = codeStyle.copyWith(
                        color: AppColors.text,
                      );
                      final heightBehavior = const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      );
                      return Container(
                        color: AppColors.surfaceLow,
                        child: Scrollbar(
                          controller: _verticalController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _verticalController,
                            padding: EdgeInsets.fromLTRB(
                              horizontalInset,
                              16,
                              horizontalInset + 2,
                              20,
                            ),
                            child: formattedJson
                                ? ClipRect(
                                    child: Scrollbar(
                                      controller: _horizontalController,
                                      notificationPredicate: (notification) =>
                                          notification.metrics.axis ==
                                          Axis.horizontal,
                                      child: SingleChildScrollView(
                                        key: const Key(
                                          'response-formatted-horizontal-scroll',
                                        ),
                                        controller: _horizontalController,
                                        scrollDirection: Axis.horizontal,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minWidth: codeCanvasWidth,
                                          ),
                                          child: _JsonTreeViewer(
                                            value: _content.value,
                                            textStyle: bodyStyle,
                                            textHeightBehavior: heightBehavior,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : SelectionArea(
                                    key: const Key('response-raw-wrapped-text'),
                                    child: Text.rich(
                                      _displayedBodySpan,
                                      style: bodyStyle,
                                      textHeightBehavior: heightBehavior,
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
          color: AppColors.surfaceHigh,
          border: Border(bottom: BorderSide(color: AppColors.outline)),
        ),
        child: Row(
          children: [
            Icon(
              isJson ? Icons.data_object_outlined : Icons.notes_outlined,
              size: 16,
              color: isJson ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: MonoText(
                isJson ? l10n.validJson : l10n.plainText,
                color: isJson ? AppColors.primary : AppColors.textMuted,
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
    color: AppColors.surfaceLow,
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.data_object_outlined, size: 22, color: AppColors.textFaint),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    ),
  );
}

/// 响应正文解析结果：尝试按 JSON 解析，失败则视为纯文本。
class _ResponseBodyContent {
  /// 私有构造：外部统一通过 [parse] 创建。
  const _ResponseBodyContent._({
    required this.isJson,
    required this.formatted,
    required this.value,
  });

  // JSON permits arbitrary whitespace. Keep response output and copies on one
  // fixed two-space convention, independent from the current panel width.

  /// 格式化使用的统一两空格缩进。
  static const _standardIndent = '  ';

  /// 解析正文：成功按 JSON 处理，FormatException 回退为纯文本。
  factory _ResponseBodyContent.parse(String body) {
    try {
      final value = jsonDecode(body);
      final formatted = const JsonEncoder.withIndent(
        _standardIndent,
      ).convert(value);
      return _ResponseBodyContent._(
        isJson: true,
        formatted: formatted,
        value: value,
      );
    } on FormatException {
      return const _ResponseBodyContent._(
        isJson: false,
        formatted: '',
        value: null,
      );
    }
  }

  /// 正文是否为合法 JSON。
  final bool isJson;

  /// 格式化后的 JSON 文本（非 JSON 时为空串）。
  final String formatted;

  /// 反序列化后的值（非 JSON 时为 null）。
  final Object? value;
}

/// 可折叠的格式化 JSON 树。展开行仍严格采用两空格缩进。
class _JsonTreeViewer extends StatefulWidget {
  /// 构造 JSON 树查看器。
  const _JsonTreeViewer({
    required this.value,
    required this.textStyle,
    required this.textHeightBehavior,
  });

  /// 待渲染的 JSON 值。
  final Object? value;

  /// 节点文字样式。
  final TextStyle textStyle;

  /// 行高行为设置。
  final TextHeightBehavior textHeightBehavior;

  /// 创建 JSON 树状态。
  @override
  State<_JsonTreeViewer> createState() => _JsonTreeViewerState();
}

/// JSON 树查看器状态：维护各节点折叠状态。
class _JsonTreeViewerState extends State<_JsonTreeViewer> {
  /// 已折叠节点的 nodeId 集合。
  final _collapsedNodes = <String>{};

  /// JSON 值变化时清空所有折叠状态。
  @override
  void didUpdateWidget(covariant _JsonTreeViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.value, widget.value)) _collapsedNodes.clear();
  }

  /// 构建 JSON 树：逐行渲染并处理折叠切换。
  @override
  Widget build(BuildContext context) {
    final lines = _JsonTreeLineBuilder(
      value: widget.value,
      collapsedNodes: _collapsedNodes,
    ).build();
    return SelectionArea(
      child: Column(
        key: const Key('response-json-tree'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines)
            _JsonTreeLineView(
              line: line,
              textStyle: widget.textStyle,
              textHeightBehavior: widget.textHeightBehavior,
              onToggle: line.nodeId == null
                  ? null
                  : () => setState(() {
                      if (!_collapsedNodes.add(line.nodeId!)) {
                        _collapsedNodes.remove(line.nodeId);
                      }
                    }),
            ),
        ],
      ),
    );
  }
}

/// JSON 树单行视图：缩进 + 折叠开关 + 高亮文本。
class _JsonTreeLineView extends StatelessWidget {
  /// 构造 JSON 树行。
  const _JsonTreeLineView({
    required this.line,
    required this.textStyle,
    required this.textHeightBehavior,
    required this.onToggle,
  });

  /// 行数据。
  final _JsonTreeLine line;

  /// 文本样式。
  final TextStyle textStyle;

  /// 行高行为设置。
  final TextHeightBehavior textHeightBehavior;

  /// 折叠切换回调；为 null 时该行不可折叠。
  final VoidCallback? onToggle;

  /// 构建树行：按层级缩进并渲染开关与高亮文本。
  @override
  Widget build(BuildContext context) => Padding(
    // 18px is the visual width of the fixed two-space indentation at 14px.
    // Moving the toggle with the value makes nested objects read as a tree.
    padding: EdgeInsetsDirectional.only(start: line.level * 18),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          height: 23,
          child: onToggle == null
              ? null
              : IconButton(
                  key: Key('response-json-toggle-${line.nodeId}'),
                  tooltip: line.isExpanded
                      ? 'Collapse JSON node'
                      : 'Expand JSON node',
                  icon: Icon(
                    line.isExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                  ),
                  iconSize: 17,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 20,
                    height: 23,
                  ),
                  visualDensity: VisualDensity.compact,
                  color: AppColors.textMuted,
                  onPressed: onToggle,
                ),
        ),
        Text.rich(
          _JsonSyntaxHighlighter.highlight(line.displayText),
          style: textStyle,
          textHeightBehavior: textHeightBehavior,
          softWrap: false,
        ),
      ],
    ),
  );
}

/// 将 JSON 值展开为树形行列表，折叠节点用省略号表示。
class _JsonTreeLineBuilder {
  /// 构造树形行构建器。
  const _JsonTreeLineBuilder({
    required this.value,
    required this.collapsedNodes,
  });

  /// 待展开的根 JSON 值。
  final Object? value;

  /// 已折叠节点的 nodeId 集合。
  final Set<String> collapsedNodes;

  /// 构建全部树形行。
  List<_JsonTreeLine> build() {
    final lines = <_JsonTreeLine>[];
    _appendValue(
      lines: lines,
      value: value,
      level: 0,
      keyName: null,
      isLast: true,
      nodeId: 'root',
    );
    return lines;
  }

  /// 递归追加单个值对应的行：容器进入 [_appendContainer]，标量直接成行。
  void _appendValue({
    required List<_JsonTreeLine> lines,
    required Object? value,
    required int level,
    required String? keyName,
    required bool isLast,
    required String nodeId,
  }) {
    final prefix = _prefix(level, keyName);
    final suffix = isLast ? '' : ',';
    if (value is Map && value.isNotEmpty) {
      _appendContainer(
        lines: lines,
        value: value,
        level: level,
        prefix: prefix,
        suffix: suffix,
        nodeId: nodeId,
        open: '{',
        close: '}',
        children: value.entries
            .map((entry) => (key: entry.key.toString(), value: entry.value))
            .toList(growable: false),
      );
      return;
    }
    if (value is List && value.isNotEmpty) {
      _appendContainer(
        lines: lines,
        value: value,
        level: level,
        prefix: prefix,
        suffix: suffix,
        nodeId: nodeId,
        open: '[',
        close: ']',
        children: value
            .asMap()
            .entries
            .map((entry) => (key: entry.key.toString(), value: entry.value))
            .toList(growable: false),
      );
      return;
    }
    lines.add(
      _JsonTreeLine(text: '$prefix${_encodeValue(value)}$suffix', level: level),
    );
  }

  /// 追加容器行：折叠时输出省略号单行，否则输出开/闭括号并递归子节点。
  void _appendContainer({
    required List<_JsonTreeLine> lines,
    required Object value,
    required int level,
    required String prefix,
    required String suffix,
    required String nodeId,
    required String open,
    required String close,
    required List<({String key, Object? value})> children,
  }) {
    final expanded = !collapsedNodes.contains(nodeId);
    if (!expanded) {
      lines.add(
        _JsonTreeLine(
          text: '$prefix$open...$close$suffix',
          level: level,
          nodeId: nodeId,
          isExpanded: false,
        ),
      );
      return;
    }

    lines.add(
      _JsonTreeLine(
        text: '$prefix$open',
        level: level,
        nodeId: nodeId,
        isExpanded: true,
      ),
    );
    for (var index = 0; index < children.length; index++) {
      final child = children[index];
      _appendValue(
        lines: lines,
        value: child.value,
        level: level + 1,
        keyName: value is Map ? child.key : null,
        isLast: index == children.length - 1,
        nodeId: value is Map ? '$nodeId.${child.key}' : '$nodeId[${child.key}]',
      );
    }
    lines.add(
      _JsonTreeLine(text: '${_indent(level)}$close$suffix', level: level),
    );
  }

  /// 拼接行前缀：层级缩进 + 可选的键名。
  String _prefix(int level, String? keyName) =>
      '${_indent(level)}${keyName == null ? '' : '${jsonEncode(keyName)}: '}';

  /// 生成指定层级的缩进字符串。
  String _indent(int level) => List<String>.filled(level, '  ').join();

  /// 将标量值编码为 JSON 文本。
  String _encodeValue(Object? value) => const JsonEncoder().convert(value);
}

/// JSON 树中的一行文本及其层级信息。
class _JsonTreeLine {
  /// 构造树形行。
  const _JsonTreeLine({
    required this.text,
    required this.level,
    this.nodeId,
    this.isExpanded = false,
  });

  /// 含缩进与键名的完整行文本。
  final String text;

  /// 节点层级（决定缩进）。
  final int level;

  /// 节点标识；可折叠节点持有，标量行为 null。
  final String? nodeId;

  /// 容器节点当前是否展开。
  final bool isExpanded;

  /// 去掉前缀缩进后的展示文本。
  String get displayText => text.substring(level * 2);
}

/// 对已验证的 JSON 做轻量级语法着色，不改变可复制的实际文本内容。
abstract final class _JsonSyntaxHighlighter {
  /// 对 [source] 逐字符扫描生成高亮 TextSpan。
  static TextSpan highlight(String source) {
    final spans = <InlineSpan>[];
    var index = 0;
    while (index < source.length) {
      final character = source[index];
      if (character == '"') {
        final start = index++;
        while (index < source.length) {
          if (source[index] == r'\') {
            index += 2;
          } else if (source[index++] == '"') {
            break;
          }
        }
        final isKey = _nextNonWhitespace(source, index) == ':';
        spans.add(
          TextSpan(
            text: source.substring(start, index),
            style: TextStyle(
              color: isKey ? AppColors.primary : AppColors.success,
            ),
          ),
        );
      } else if (_isNumberStart(character)) {
        final start = index++;
        while (index < source.length && _isNumberCharacter(source[index])) {
          index++;
        }
        spans.add(
          TextSpan(
            text: source.substring(start, index),
            style: TextStyle(color: AppColors.warning),
          ),
        );
      } else if (_matchesLiteral(source, index, 'true') ||
          _matchesLiteral(source, index, 'false') ||
          _matchesLiteral(source, index, 'null')) {
        final isNull = _matchesLiteral(source, index, 'null');
        final literal = _matchesLiteral(source, index, 'true')
            ? 'true'
            : _matchesLiteral(source, index, 'false')
            ? 'false'
            : 'null';
        spans.add(
          TextSpan(
            text: literal,
            style: TextStyle(
              color: isNull ? AppColors.textFaint : AppColors.success,
            ),
          ),
        );
        index += literal.length;
      } else {
        final isPunctuation = '{}[],:'.contains(character);
        final isStructure = '{}[]'.contains(character);
        spans.add(
          TextSpan(
            text: character,
            style: TextStyle(
              color: isStructure
                  ? AppColors.textMuted
                  : isPunctuation
                  ? AppColors.textFaint
                  : AppColors.text,
              fontWeight: isStructure ? FontWeight.w600 : null,
            ),
          ),
        );
        index++;
      }
    }
    return TextSpan(children: spans);
  }

  /// 从 [index] 起查找第一个非空白字符。
  static String? _nextNonWhitespace(String source, int index) {
    while (index < source.length && source[index].trim().isEmpty) {
      index++;
    }
    return index < source.length ? source[index] : null;
  }

  /// 是否为数字起始字符（负号或数字 0-9）。
  static bool _isNumberStart(String value) =>
      value == '-' || (value.codeUnitAt(0) >= 48 && value.codeUnitAt(0) <= 57);

  /// 是否为数字组成部分。
  static bool _isNumberCharacter(String value) =>
      '0123456789+-.eE'.contains(value);

  /// 在 [index] 处是否匹配 [literal]，且其后紧跟合法分隔符。
  static bool _matchesLiteral(String source, int index, String literal) =>
      source.startsWith(literal, index) &&
      (index + literal.length == source.length ||
          '{}[],: \n\r\t'.contains(source[index + literal.length]));
}

/// 响应头表格：逐行展示「键 / 值」对。
