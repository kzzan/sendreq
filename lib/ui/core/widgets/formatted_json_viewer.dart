import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';

/// 统一的 JSON 解析与两空格格式化结果。
class FormattedJsonContent {
  const FormattedJsonContent._({
    required this.isJson,
    required this.formatted,
    required this.value,
  });

  factory FormattedJsonContent.parse(String source) {
    try {
      final value = jsonDecode(source);
      return FormattedJsonContent._(
        isJson: true,
        formatted: const JsonEncoder.withIndent('  ').convert(value),
        value: value,
      );
    } on FormatException {
      return const FormattedJsonContent._(
        isJson: false,
        formatted: '',
        value: null,
      );
    }
  }

  final bool isJson;
  final String formatted;
  final Object? value;
}

/// 可逐节点折叠的格式化 JSON 树，供响应正文与协议消息共同使用。
class FormattedJsonTree extends StatefulWidget {
  const FormattedJsonTree({
    super.key,
    required this.value,
    required this.textStyle,
    this.textHeightBehavior = const TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
    ),
    this.nodeKeyPrefix = 'json',
  });

  final Object? value;
  final TextStyle textStyle;
  final TextHeightBehavior textHeightBehavior;
  final String nodeKeyPrefix;

  @override
  State<FormattedJsonTree> createState() => _FormattedJsonTreeState();
}

class _FormattedJsonTreeState extends State<FormattedJsonTree> {
  final _collapsedNodes = <String>{};
  late List<_JsonTreeLine> _lines;

  @override
  void initState() {
    super.initState();
    _rebuildLines();
  }

  @override
  void didUpdateWidget(covariant FormattedJsonTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.value, widget.value)) {
      _collapsedNodes.clear();
      _rebuildLines();
    }
  }

  void _rebuildLines() {
    _lines = _JsonTreeLineBuilder(
      value: widget.value,
      collapsedNodes: _collapsedNodes,
    ).build();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Column(
        key: ValueKey('${widget.nodeKeyPrefix}-tree'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in _lines)
            _JsonTreeLineView(
              line: line,
              textStyle: widget.textStyle,
              textHeightBehavior: widget.textHeightBehavior,
              keyPrefix: widget.nodeKeyPrefix,
              onToggle: line.nodeId == null
                  ? null
                  : () => setState(() {
                      if (!_collapsedNodes.add(line.nodeId!)) {
                        _collapsedNodes.remove(line.nodeId);
                      }
                      _rebuildLines();
                    }),
            ),
        ],
      ),
    );
  }
}

class _JsonTreeLineView extends StatelessWidget {
  const _JsonTreeLineView({
    required this.line,
    required this.textStyle,
    required this.textHeightBehavior,
    required this.keyPrefix,
    required this.onToggle,
  });

  final _JsonTreeLine line;
  final TextStyle textStyle;
  final TextHeightBehavior textHeightBehavior;
  final String keyPrefix;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) => Padding(
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
                  key: ValueKey('$keyPrefix-toggle-${line.nodeId}'),
                  tooltip: line.isExpanded
                      ? AppLocalizations.of(context).collapseJsonNode
                      : AppLocalizations.of(context).expandJsonNode,
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
                  color: context.chakra.fgMuted,
                  onPressed: onToggle,
                ),
        ),
        Text.rich(
          JsonSyntaxHighlighter.highlight(context.chakra, line.displayText),
          style: textStyle,
          textHeightBehavior: textHeightBehavior,
          softWrap: false,
        ),
      ],
    ),
  );
}

class _JsonTreeLineBuilder {
  const _JsonTreeLineBuilder({
    required this.value,
    required this.collapsedNodes,
  });

  final Object? value;
  final Set<String> collapsedNodes;

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

  void _appendValue({
    required List<_JsonTreeLine> lines,
    required Object? value,
    required int level,
    required String? keyName,
    required bool isLast,
    required String nodeId,
  }) {
    final prefix =
        '${_indent(level)}${keyName == null ? '' : '${jsonEncode(keyName)}: '}';
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
      _JsonTreeLine(
        text: '$prefix${const JsonEncoder().convert(value)}$suffix',
        level: level,
      ),
    );
  }

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

  String _indent(int level) => List<String>.filled(level, '  ').join();
}

class _JsonTreeLine {
  const _JsonTreeLine({
    required this.text,
    required this.level,
    this.nodeId,
    this.isExpanded = false,
  });

  final String text;
  final int level;
  final String? nodeId;
  final bool isExpanded;
  String get displayText => text.substring(level * 2);
}

/// 不改变源文本的 JSON 语法高亮。
abstract final class JsonSyntaxHighlighter {
  static TextSpan highlight(ChakraSemanticTokens tokens, String source) {
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
              color: isKey ? tokens.colorPaletteFg : tokens.success,
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
            style: TextStyle(color: tokens.warning),
          ),
        );
      } else if (_matchesLiteral(source, index, 'true') ||
          _matchesLiteral(source, index, 'false') ||
          _matchesLiteral(source, index, 'null')) {
        final literal = _matchesLiteral(source, index, 'true')
            ? 'true'
            : _matchesLiteral(source, index, 'false')
            ? 'false'
            : 'null';
        spans.add(
          TextSpan(
            text: literal,
            style: TextStyle(
              color: literal == 'null' ? tokens.fgSubtle : tokens.success,
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
                  ? tokens.fgMuted
                  : isPunctuation
                  ? tokens.fgSubtle
                  : tokens.fg,
              fontWeight: isStructure ? FontWeight.w600 : null,
            ),
          ),
        );
        index++;
      }
    }
    return TextSpan(children: spans);
  }

  static String? _nextNonWhitespace(String source, int index) {
    while (index < source.length && source[index].trim().isEmpty) {
      index++;
    }
    return index < source.length ? source[index] : null;
  }

  static bool _isNumberStart(String value) =>
      value == '-' || (value.codeUnitAt(0) >= 48 && value.codeUnitAt(0) <= 57);

  static bool _isNumberCharacter(String value) =>
      '0123456789+-.eE'.contains(value);

  static bool _matchesLiteral(String source, int index, String literal) =>
      source.startsWith(literal, index) &&
      (index + literal.length == source.length ||
          '{}[],: \n\r\t'.contains(source[index + literal.length]));
}
