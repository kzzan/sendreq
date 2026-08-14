import 'package:flutter/material.dart';

import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_key_value_rows.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 查询参数与请求头共用的键值表格编排。
class KeyValueTable extends StatelessWidget {
  const KeyValueTable({
    super.key,
    required this.title,
    required this.rows,
    required this.headers,
    required this.viewModel,
  });

  final String title;
  final List<KeyValueRow> rows;
  final bool headers;
  final WorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) => DensePanel(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        FieldTableTitle(
          title: title,
          enabledCount: rows
              .where((row) => row.enabled && row.keyName.trim().isNotEmpty)
              .length,
          onAdd: () => viewModel.addActiveDraftField(headers: headers),
          environmentVariables: headers
              ? const []
              : viewModel.activeAvailableEnvironmentParameters,
          onAddEnvironmentVariable: headers
              ? null
              : (variable) =>
                    _addEnvironmentParameter(context, viewModel, variable),
        ),
        const _TableHeader(),
        Expanded(
          child: ListView(
            children: [
              if (!headers &&
                  viewModel.activeManagedApiKeyQueryParameter != null)
                _ManagedAuthenticationParameterLine(
                  row: viewModel.activeManagedApiKeyQueryParameter!,
                ),
              for (final (index, row) in rows.indexed)
                KeyValueLine(
                  key: ValueKey('$headers-${row.id}'),
                  row: row,
                  headers: headers,
                  revealed: viewModel.isActiveDraftFieldRevealed(row.id),
                  onChanged: (keyName, value) =>
                      viewModel.updateActiveDraftField(
                        headers: headers,
                        index: index,
                        keyName: keyName,
                        value: value,
                      ),
                  onToggle: () => viewModel.updateActiveDraftField(
                    headers: headers,
                    index: index,
                    enabled: !row.enabled,
                  ),
                  onRemove: () => viewModel.removeActiveDraftField(
                    headers: headers,
                    index: index,
                  ),
                  onToggleSecret: () => viewModel.updateActiveDraftField(
                    headers: headers,
                    index: index,
                    secret: !row.secret,
                  ),
                  onToggleVisibility: () =>
                      viewModel.toggleActiveDraftFieldVisibility(row.id),
                ),
              AddRowHint(
                onTap: () => viewModel.addActiveDraftField(headers: headers),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 让用户为环境变量指定参数名，确认后写入查询参数。
Future<void> _addEnvironmentParameter(
  BuildContext context,
  WorkspaceViewModel viewModel,
  KeyValueRow variable,
) async {
  final controller = TextEditingController();
  final parameterKey = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(AppLocalizations.of(context).addParameterFromEnvironment),
      content: TextFormField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).key,
          hintText: 'input',
          helperText: '{{${variable.keyName}}}',
        ),
        onFieldSubmitted: (value) =>
            Navigator.of(dialogContext).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: Text(AppLocalizations.of(context).addField),
        ),
      ],
    ),
  );
  controller.dispose();
  if (parameterKey == null || parameterKey.isEmpty) return;
  viewModel.addActiveEnvironmentVariableParameter(
    variable.keyName,
    parameterKey: parameterKey,
  );
}

/// 由鉴权模块管理的只读查询参数行。
class _ManagedAuthenticationParameterLine extends StatelessWidget {
  const _ManagedAuthenticationParameterLine({required this.row});

  final KeyValueRow row;

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: context.chakra.colorPaletteSolid.withValues(alpha: 0.16),
      border: Border(top: BorderSide(color: context.chakra.border)),
    ),
    child: Row(
      children: [
        const SizedBox(
          width: FieldTableColumns.enabled,
          child: Icon(Icons.lock_outline, size: 15),
        ),
        Expanded(
          flex: FieldTableColumns.keyFlex,
          child: MonoText(row.keyName, color: context.chakra.fg),
        ),
        const SizedBox(width: FieldTableColumns.gap),
        Expanded(
          flex: FieldTableColumns.valueFlex,
          child: MonoText(row.value, color: context.chakra.warning),
        ),
        const SizedBox(width: FieldTableColumns.gap),
        SizedBox(
          width: FieldTableColumns.action,
          child: Align(
            alignment: Alignment.centerLeft,
            child: MonoText(
              AppLocalizations.of(context).managedByAuthentication,
              color: context.chakra.fgMuted,
              size: 10,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('request-field-table-header'),
    height: 30,
    color: context.chakra.bgEmphasized,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Row(
      children: [
        SizedBox(
          width: FieldTableColumns.enabled,
          child: MonoText(
            AppLocalizations.of(context).enabled,
            color: context.chakra.fgSubtle,
            size: 10,
          ),
        ),
        Expanded(
          flex: FieldTableColumns.keyFlex,
          child: MonoText(
            AppLocalizations.of(context).key.toUpperCase(),
            color: context.chakra.fgSubtle,
            size: 10,
          ),
        ),
        SizedBox(width: FieldTableColumns.gap),
        Expanded(
          flex: FieldTableColumns.valueFlex,
          child: MonoText(
            AppLocalizations.of(context).value.toUpperCase(),
            color: context.chakra.fgSubtle,
            size: 10,
          ),
        ),
        SizedBox(width: FieldTableColumns.gap),
        SizedBox(width: FieldTableColumns.action),
      ],
    ),
  );
}
