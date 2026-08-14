import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// 显示 Requests 内的 OpenAPI JSON 导入入口：可粘贴或读取本地文件。
Future<void> showOpenApiImportDialog(
  BuildContext context,
  WorkspaceViewModel viewModel,
) => showDialog<void>(
  context: context,
  builder: (_) => _OpenApiImportDialog(viewModel: viewModel),
);

/// 统一的 OpenAPI JSON 导入对话框：可直接粘贴 JSON，也可读取本地文件。
class _OpenApiImportDialog extends StatefulWidget {
  /// 构造导入对话框。
  const _OpenApiImportDialog({required this.viewModel});

  /// 工作区视图模型，提供 OpenAPI 导入与结果消息读取能力。
  final WorkspaceViewModel viewModel;

  /// 创建导入对话框状态。
  @override
  State<_OpenApiImportDialog> createState() => _OpenApiImportDialogState();
}

/// 导入对话框状态：管理输入控制器、已选文件名与文件读取错误。
class _OpenApiImportDialogState extends State<_OpenApiImportDialog> {
  /// 粘贴或载入内容的文本输入控制器。
  final _controller = TextEditingController();

  /// 已成功读取的本地文件名称（用于文件选择行展示）。
  String? _selectedFileName;

  /// 文件读取失败时的错误文案，为空表示当前没有错误。
  String? _fileError;

  /// 释放输入控制器资源。
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 通过系统文件选择器读取本地 JSON 文件并填入输入框。
  Future<void> _selectFile() async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    // 未选择文件则直接返回；无本地路径时提示文件不可读。
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null) {
      setState(() => _fileError = l10n.openApiFileReadFailed);
      return;
    }
    try {
      final source = await widget.viewModel.readOpenApiFile(path);
      if (!mounted) return;
      setState(() {
        _controller.text = source;
        _selectedFileName = file.name;
        _fileError = null;
      });
    } on Object {
      if (mounted) {
        setState(() => _fileError = l10n.openApiFileReadFailed);
      }
    }
  }

  /// 将输入框内容导入为 OpenAPI 并关闭对话框；结果由统一通知中心展示。
  void _import() {
    widget.viewModel.importOpenApi(_controller.text);
    Navigator.pop(context);
  }

  /// 构建导入对话框：文件选择入口、错误提示与 JSON 输入区。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.importOpenApiJson),
      content: SizedBox(
        width: 560,
        height: 430,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _selectFile,
                  icon: const Icon(Icons.upload_file_outlined, size: 16),
                  label: Text(l10n.selectOpenApiFile),
                ),
                if (_selectedFileName != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.openApiFileLoaded(_selectedFileName!),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (_fileError != null) ...[
              const SizedBox(height: 8),
              Text(
                _fileError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: l10n.openApiJsonExample,
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _import, child: Text(l10n.import)),
      ],
    );
  }
}
