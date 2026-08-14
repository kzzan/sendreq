import 'package:flutter/material.dart';

import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_multipart.dart';

/// application/x-www-form-urlencoded 请求体编辑器，仅管理文本键值字段。
class FormUrlEncodedBodyEditor extends StatelessWidget {
  const FormUrlEncodedBodyEditor({
    super.key,
    required this.fields,
    required this.onAddField,
    required this.onUpdateField,
    required this.onRemoveField,
  });

  final List<KeyValueRow> fields;
  final VoidCallback onAddField;
  final void Function({
    required int index,
    String? keyName,
    String? value,
    bool? enabled,
  })
  onUpdateField;
  final ValueChanged<int> onRemoveField;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
    children: [
      RequestBodySectionHeading(
        icon: Icons.format_list_bulleted_outlined,
        title: AppLocalizations.of(context).formUrlEncodedFields,
        detail: fields.isEmpty
            ? AppLocalizations.of(context).optional
            : AppLocalizations.of(context).fieldCount(fields.length),
        action: DenseIconButton(
          icon: Icons.add,
          tooltip: AppLocalizations.of(context).addFormField,
          onPressed: onAddField,
          size: 30,
        ),
      ),
      const SizedBox(height: 6),
      if (fields.isEmpty)
        Text(
          AppLocalizations.of(context).formUrlEncodedFieldsDescription,
          style: TextStyle(color: context.chakra.fgSubtle, fontSize: 12),
        ),
      for (final (index, field) in fields.indexed)
        _FormUrlEncodedFieldLine(
          key: ValueKey('urlencoded-field-${field.id}'),
          field: field,
          onChanged: (keyName, value) =>
              onUpdateField(index: index, keyName: keyName, value: value),
          onToggle: () => onUpdateField(index: index, enabled: !field.enabled),
          onRemove: () => onRemoveField(index),
        ),
    ],
  );
}

/// URL 编码表单单行字段；其启用状态与 multipart 文本字段语义一致。
class _FormUrlEncodedFieldLine extends StatelessWidget {
  const _FormUrlEncodedFieldLine({
    super.key,
    required this.field,
    required this.onChanged,
    required this.onToggle,
    required this.onRemove,
  });

  final KeyValueRow field;
  final void Function(String keyName, String value) onChanged;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 140),
    opacity: field.enabled ? 1 : 0.5,
    child: Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.chakra.border)),
      ),
      child: Row(
        children: [
          DenseIconButton(
            icon: field.enabled
                ? Icons.check_box_outlined
                : Icons.check_box_outline_blank,
            tooltip: field.enabled
                ? AppLocalizations.of(context).fieldDisabled
                : AppLocalizations.of(context).fieldEnabled,
            onPressed: onToggle,
            size: 28,
          ),
          Expanded(
            child: TextFormField(
              key: ValueKey('urlencoded-field-key-${field.id}'),
              initialValue: field.keyName,
              onChanged: (value) => onChanged(value, field.value),
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).field,
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              key: ValueKey('urlencoded-field-value-${field.id}'),
              initialValue: field.value,
              onChanged: (value) => onChanged(field.keyName, value),
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).value,
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          DenseIconButton(
            icon: Icons.close,
            tooltip: AppLocalizations.of(context).removeFormField,
            onPressed: onRemove,
            size: 28,
          ),
        ],
      ),
    ),
  );
}
