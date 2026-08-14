import 'package:flutter/material.dart';

import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';

/// multipart/form-data 请求体的文件与文本字段编辑器。
class MultipartBodyEditor extends StatelessWidget {
  const MultipartBodyEditor({
    super.key,
    required this.fields,
    required this.files,
    required this.onChooseFiles,
    required this.onAddField,
    required this.onUpdateField,
    required this.onRemoveField,
    required this.onUpdateFile,
    required this.onRemoveFile,
    required this.onApplyFileFieldName,
  });

  final List<KeyValueRow> fields;
  final List<MultipartFileRow> files;
  final Future<void> Function() onChooseFiles;
  final VoidCallback onAddField;
  final void Function({
    required int index,
    String? keyName,
    String? value,
    bool? enabled,
  })
  onUpdateField;
  final ValueChanged<int> onRemoveField;
  final void Function({required int index, String? keyName, bool? enabled})
  onUpdateFile;
  final ValueChanged<int> onRemoveFile;
  final ValueChanged<String> onApplyFileFieldName;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
    children: [
      RequestBodySectionHeading(
        icon: Icons.attach_file_outlined,
        title: AppLocalizations.of(context).files,
        detail: files.isEmpty
            ? AppLocalizations.of(context).noFiles
            : AppLocalizations.of(context).selectedFileCount(files.length),
        action: OutlinedButton.icon(
          onPressed: onChooseFiles,
          style: ChakraRecipes.sized(
            ChakraRecipes.outlineFor(context),
            minimumSize: const Size(0, 30),
            padding: const EdgeInsets.symmetric(horizontal: 9),
          ),
          icon: const Icon(Icons.upload_file_outlined, size: 16),
          label: Text(AppLocalizations.of(context).chooseFiles),
        ),
      ),
      const SizedBox(height: 6),
      if (files.isEmpty)
        _MultipartEmptyState(onChooseFiles: onChooseFiles)
      else
        for (final (index, file) in files.indexed)
          _MultipartFileLine(
            key: ValueKey('multipart-file-${file.id}'),
            file: file,
            onChanged: (keyName) =>
                onUpdateFile(index: index, keyName: keyName),
            onToggle: () => onUpdateFile(index: index, enabled: !file.enabled),
            onRemove: () => onRemoveFile(index),
          ),
      if (files.length > 1) ...[
        const SizedBox(height: 8),
        _BatchFileFieldControl(
          fieldName: _sharedFileFieldName(files),
          onApply: onApplyFileFieldName,
        ),
      ],
      const SizedBox(height: 18),
      RequestBodySectionHeading(
        icon: Icons.short_text_outlined,
        title: AppLocalizations.of(context).formFields,
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
      for (final (index, field) in fields.indexed)
        _MultipartTextFieldLine(
          key: ValueKey('multipart-field-${field.id}'),
          field: field,
          onChanged: (keyName, value) =>
              onUpdateField(index: index, keyName: keyName, value: value),
          onToggle: () => onUpdateField(index: index, enabled: !field.enabled),
          onRemove: () => onRemoveField(index),
        ),
      if (fields.isEmpty)
        Text(
          AppLocalizations.of(context).multipartFieldsDescription,
          style: TextStyle(color: context.chakra.fgSubtle, fontSize: 12),
        ),
    ],
  );
}

class RequestBodySectionHeading extends StatelessWidget {
  const RequestBodySectionHeading({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Widget action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: context.chakra.colorPaletteFg),
      const SizedBox(width: 7),
      Text(title, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(width: 7),
      MonoText(detail, color: context.chakra.fgSubtle, size: 10),
      const Spacer(),
      action,
    ],
  );
}

class _MultipartEmptyState extends StatelessWidget {
  const _MultipartEmptyState({required this.onChooseFiles});

  final Future<void> Function() onChooseFiles;

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: context.chakra.bgSubtle,
      border: Border.all(color: context.chakra.border),
      borderRadius: ChakraRadii.control,
    ),
    child: Row(
      children: [
        Icon(Icons.file_upload_outlined, color: context.chakra.fgSubtle),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            AppLocalizations.of(context).chooseFilesDescription,
            style: TextStyle(color: context.chakra.fgMuted, fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: onChooseFiles,
          child: Text(AppLocalizations.of(context).browse),
        ),
      ],
    ),
  );
}

class _BatchFileFieldControl extends StatefulWidget {
  const _BatchFileFieldControl({
    required this.fieldName,
    required this.onApply,
  });

  final String fieldName;
  final ValueChanged<String> onApply;

  @override
  State<_BatchFileFieldControl> createState() => _BatchFileFieldControlState();
}

class _BatchFileFieldControlState extends State<_BatchFileFieldControl> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.fieldName);
  }

  @override
  void didUpdateWidget(covariant _BatchFileFieldControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.fieldName) {
      _controller.value = TextEditingValue(
        text: widget.fieldName,
        selection: TextSelection.collapsed(offset: widget.fieldName.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canApply = _controller.text.trim().isNotEmpty;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: context.chakra.colorPaletteFg.withValues(alpha: 0.08),
        border: Border.all(
          color: context.chakra.colorPaletteFg.withValues(alpha: 0.34),
        ),
        borderRadius: ChakraRadii.control,
      ),
      child: Row(
        children: [
          Icon(
            Icons.layers_outlined,
            size: 16,
            color: context.chakra.colorPaletteFg,
          ),
          const SizedBox(width: 7),
          MonoText(
            AppLocalizations.of(context).batchField,
            color: context.chakra.colorPaletteFg,
            size: 10,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              key: const Key('multipart-batch-field-input'),
              controller: _controller,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).fieldName,
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          TextButton(
            onPressed: canApply
                ? () => widget.onApply(_controller.text.trim())
                : null,
            style: ChakraRecipes.sized(
              ChakraRecipes.ghostFor(context),
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 7),
            ),
            child: Text(AppLocalizations.of(context).apply),
          ),
        ],
      ),
    );
  }
}

class _MultipartFileLine extends StatelessWidget {
  const _MultipartFileLine({
    super.key,
    required this.file,
    required this.onChanged,
    required this.onToggle,
    required this.onRemove,
  });

  final MultipartFileRow file;
  final ValueChanged<String> onChanged;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 140),
    opacity: file.enabled ? 1 : 0.5,
    child: Container(
      key: Key('multipart-file-row-${file.id}'),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.chakra.border)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 18,
            color: context.chakra.colorPaletteFg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.chakra.fgMuted, fontSize: 12),
                ),
                MonoText(
                  _formatFileSize(file.sizeBytes),
                  color: context.chakra.fgSubtle,
                  size: 10,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 92,
            child: TextFormField(
              key: ValueKey('multipart-file-key-${file.id}'),
              initialValue: file.keyName,
              onChanged: onChanged,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).fieldName,
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          DenseIconButton(
            icon: file.enabled
                ? Icons.check_box_outlined
                : Icons.check_box_outline_blank,
            tooltip: file.enabled
                ? AppLocalizations.of(context).fileDisabled
                : AppLocalizations.of(context).fileEnabled,
            onPressed: onToggle,
            size: 28,
          ),
          DenseIconButton(
            icon: Icons.close,
            tooltip: AppLocalizations.of(context).removeFile,
            onPressed: onRemove,
            size: 28,
          ),
        ],
      ),
    ),
  );
}

class _MultipartTextFieldLine extends StatelessWidget {
  const _MultipartTextFieldLine({
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
      key: Key('multipart-field-row-${field.id}'),
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
              key: ValueKey('multipart-field-key-${field.id}'),
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
              key: ValueKey('multipart-field-value-${field.id}'),
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

String _formatFileSize(int sizeBytes) {
  if (sizeBytes < 1024) return '$sizeBytes B';
  if (sizeBytes < 1024 * 1024) {
    return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _sharedFileFieldName(List<MultipartFileRow> files) {
  if (files.isEmpty) return '';
  final first = files.first.keyName;
  return files.every((file) => file.keyName == first) ? first : '';
}
