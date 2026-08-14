import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/form_control_metrics.dart';

/// 共享字段标签与辅助文本。窄空间时改为垂直排列，保留可读的控件宽度。
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.helperText,
    this.enabled = true,
    this.labelWidth = 152,
  });

  final String label;
  final Widget child;
  final String? helperText;
  final bool enabled;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: enabled ? context.chakra.fg : context.chakra.disabled,
    );
    final labelBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        if (helperText != null) ...[
          const SizedBox(height: 3),
          Text(
            helperText!,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: context.chakra.fgMuted),
          ),
        ],
      ],
    );
    return Semantics(
      container: true,
      label: helperText == null ? label : '$label. $helperText',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 768) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [labelBlock, const SizedBox(height: 6), child],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: labelWidth, child: labelBlock),
              const SizedBox(width: 12),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}

class CompactSelectItem<T> {
  const CompactSelectItem({required this.value, required this.label});

  final T value;
  final String label;
}

/// 使用共享高度、焦点和禁用说明的单行选择器。
class CompactSelect<T> extends StatelessWidget {
  const CompactSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.enabled = true,
    this.dense = false,
  });

  final T? value;
  final List<CompactSelectItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final bool enabled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final height = dense
        ? FormControlMetrics.denseHeight
        : FormControlMetrics.standardHeight;
    return Semantics(
      enabled: enabled && onChanged != null,
      child: SizedBox(
        height: height,
        child: DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          isDense: true,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: EdgeInsets.symmetric(
              horizontal: FormControlMetrics.horizontalPadding,
              vertical: dense ? 4 : FormControlMetrics.verticalPadding,
            ),
          ),
          items: [
            for (final item in items)
              DropdownMenuItem(value: item.value, child: Text(item.label)),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class ModeSelectorItem<T> {
  const ModeSelectorItem({required this.value, required this.label});

  final T value;
  final String label;
}

/// 单选模式的紧凑、等宽切换器。
class ModeSelector<T> extends StatelessWidget {
  const ModeSelector({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final T value;
  final List<ModeSelectorItem<T>> items;
  final ValueChanged<T>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stack = constraints.maxWidth < 360;
      return Semantics(
        container: true,
        label: 'Mode selector',
        child: Wrap(
          spacing: stack ? 0 : 4,
          runSpacing: 4,
          children: [
            for (final item in items)
              SizedBox(
                width: stack
                    ? constraints.maxWidth
                    : (constraints.maxWidth - (items.length - 1) * 4) /
                          items.length,
                height: FormControlMetrics.standardHeight,
                child: OutlinedButton(
                  style: ChakraRecipes.standardSelectableFor(
                    context,
                    selected: item.value == value,
                  ),
                  onPressed: enabled && onChanged != null
                      ? () => onChanged!(item.value)
                      : null,
                  child: Text(item.label, overflow: TextOverflow.ellipsis),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// 在配置行内保持标签、辅助文本与开关基线对齐的二元控件。
class InlineSwitch extends StatelessWidget {
  const InlineSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helperText,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? helperText;

  @override
  Widget build(BuildContext context) => Semantics(
    label: helperText == null ? label : '$label. $helperText',
    toggled: value,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: FormControlMetrics.standardHeight,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                if (helperText != null)
                  Text(
                    helperText!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.chakra.fgMuted,
                    ),
                  ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    ),
  );
}

void _previewChanged<T>(T value) {}

@Preview(name: 'Workspace controls', group: 'Controls', size: Size(640, 300))
Widget workspaceControlsPreview() => MaterialApp(
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LabeledField(
            label: 'Authentication',
            helperText: 'Applied to the active request.',
            child: CompactSelect<String>(
              value: 'Bearer',
              items: const [
                CompactSelectItem(value: 'Bearer', label: 'Bearer token'),
                CompactSelectItem(value: 'Basic', label: 'Basic auth'),
              ],
              onChanged: _previewChanged,
            ),
          ),
          const SizedBox(height: 16),
          ModeSelector<String>(
            value: 'Header',
            items: const [
              ModeSelectorItem(value: 'Header', label: 'Header'),
              ModeSelectorItem(value: 'Query', label: 'Query'),
            ],
            onChanged: _previewChanged,
          ),
          const SizedBox(height: 12),
          InlineSwitch(
            label: 'Use TLS',
            helperText: 'Encrypt the connection.',
            value: true,
            onChanged: _previewChanged,
          ),
        ],
      ),
    ),
  ),
);
