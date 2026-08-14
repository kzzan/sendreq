import 'package:flutter/material.dart';

import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_value_policy.dart';

/// Shared column geometry keeps field headers and rows aligned.
class FieldTableColumns {
  static const double enabled = 28;
  static const double gap = 12;
  static const double action = 96;
  static const int keyFlex = 5;
  static const int valueFlex = 6;
}

/// 键值表格的标题、字段行和添加入口渲染。
class FieldTableTitle extends StatelessWidget {
  const FieldTableTitle({
    super.key,
    required this.title,
    required this.enabledCount,
    required this.onAdd,
    this.environmentVariables = const [],
    this.onAddEnvironmentVariable,
  });

  final String title;
  final int enabledCount;
  final VoidCallback onAdd;
  final List<KeyValueRow> environmentVariables;
  final ValueChanged<KeyValueRow>? onAddEnvironmentVariable;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final showEnabledCount = constraints.maxWidth >= 320;
      return Container(
        height: 38,
        padding: const EdgeInsets.only(left: 10, right: 5),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.chakra.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (showEnabledCount) ...[
              const SizedBox(width: 7),
              MonoText(
                AppLocalizations.of(context).activeFieldCount(enabledCount),
                color: context.chakra.fgSubtle,
                size: 10,
              ),
            ],
            if (onAddEnvironmentVariable != null &&
                environmentVariables.isNotEmpty)
              PopupMenuButton<KeyValueRow>(
                tooltip: AppLocalizations.of(
                  context,
                ).addParameterFromEnvironment,
                icon: const Icon(Icons.data_object_outlined, size: 18),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                onSelected: onAddEnvironmentVariable,
                itemBuilder: (context) => [
                  for (final variable in environmentVariables)
                    PopupMenuItem(
                      key: ValueKey('add-param-variable-${variable.id}'),
                      value: variable,
                      child: Row(
                        children: [
                          const Icon(Icons.data_object_outlined, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${variable.keyName}  ${variable.value}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            const SizedBox(width: 2),
            DenseIconButton(
              icon: Icons.add,
              tooltip: AppLocalizations.of(context).addField,
              onPressed: onAdd,
              size: 28,
            ),
          ],
        ),
      );
    },
  );
}

class KeyValueLine extends StatelessWidget {
  const KeyValueLine({
    super.key,
    required this.row,
    required this.headers,
    required this.revealed,
    required this.onChanged,
    required this.onToggle,
    required this.onRemove,
    required this.onToggleSecret,
    required this.onToggleVisibility,
  });

  final KeyValueRow row;
  final bool headers;
  final bool revealed;
  final void Function(String keyName, String value) onChanged;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final VoidCallback onToggleSecret;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final masksSecret = row.secret && !isEnvironmentReference(row.value);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      key: Key('request-field-row-${row.id}'),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: row.enabled
            ? context.chakra.transparent
            : context.chakra.bgSubtle.withValues(alpha: 0.8),
        border: Border(top: BorderSide(color: context.chakra.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: FieldTableColumns.enabled,
            child: IconButton(
              tooltip: row.enabled
                  ? AppLocalizations.of(context).disableRow
                  : AppLocalizations.of(context).enableRow,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: onToggle,
              icon: Icon(
                row.enabled
                    ? Icons.check_box_outlined
                    : Icons.check_box_outline_blank,
                color: row.enabled
                    ? context.chakra.colorPaletteFg
                    : context.chakra.fgSubtle,
                size: 16,
              ),
            ),
          ),
          Expanded(
            flex: FieldTableColumns.keyFlex,
            child: TextFormField(
              key: ValueKey('field-key-${row.id}'),
              initialValue: row.keyName,
              onChanged: (value) => onChanged(value, row.value),
              style: _fieldTextStyle(
                row.enabled ? context.chakra.fg : context.chakra.fgSubtle,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: AppLocalizations.of(context).key,
              ),
            ),
          ),
          const SizedBox(width: FieldTableColumns.gap),
          Expanded(
            flex: FieldTableColumns.valueFlex,
            child: TextFormField(
              key: ValueKey('field-value-${row.id}'),
              initialValue: row.value,
              obscureText: masksSecret && !revealed,
              onChanged: (value) => onChanged(row.keyName, value),
              style: _fieldTextStyle(
                !row.enabled
                    ? context.chakra.fgSubtle
                    : row.secret
                    ? context.chakra.warning
                    : context.chakra.fgMuted,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: AppLocalizations.of(context).value,
              ),
            ),
          ),
          const SizedBox(width: FieldTableColumns.gap),
          SizedBox(
            width: FieldTableColumns.action,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (headers && masksSecret)
                  DenseIconButton(
                    icon: revealed
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    tooltip: revealed
                        ? AppLocalizations.of(context).hideValue
                        : AppLocalizations.of(context).revealValue,
                    onPressed: onToggleVisibility,
                    size: 28,
                  ),
                if (headers && !row.secret)
                  DenseIconButton(
                    icon: Icons.lock_outline,
                    tooltip: AppLocalizations.of(context).markAsSecret,
                    onPressed: onToggleSecret,
                    size: 28,
                  ),
                if (headers && row.secret)
                  DenseIconButton(
                    icon: Icons.lock_open_outlined,
                    tooltip: AppLocalizations.of(
                      context,
                    ).removeSecretProtection,
                    onPressed: onToggleSecret,
                    size: 28,
                  ),
                DenseIconButton(
                  icon: Icons.close,
                  tooltip: AppLocalizations.of(context).removeRow,
                  onPressed: onRemove,
                  size: 28,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _fieldTextStyle(Color color) =>
      TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, color: color);
}

class AddRowHint extends StatelessWidget {
  const AddRowHint({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.chakra.border)),
    ),
    child: TextButton.icon(
      onPressed: onTap,
      style: ChakraRecipes.sized(
        ChakraRecipes.ghostFor(context),
        minimumSize: const Size(0, 28),
        padding: EdgeInsets.zero,
      ),
      icon: const Icon(Icons.add, size: 15),
      label: Text(AppLocalizations.of(context).addRow),
    ),
  );
}
