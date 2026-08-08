part of 'request_editor_panel.dart';

class _BodyEditor extends StatefulWidget {
  /// 构造请求体编辑器。
  const _BodyEditor({
    required this.body,
    required this.onChanged,
    required this.onFormatJson,
    required this.contentType,
    required this.usesJson,
    required this.usesMultipart,
    required this.onContentTypeChanged,
    required this.multipartFields,
    required this.multipartFiles,
    required this.onAddMultipartField,
    required this.onUpdateMultipartField,
    required this.onRemoveMultipartField,
    required this.onAddMultipartFile,
    required this.onUpdateMultipartFile,
    required this.onRemoveMultipartFile,
    required this.onApplyMultipartFileFieldName,
  });

  // 请求体原始文本内容。
  final String body;
  // 请求体内容变更回调。
  final ValueChanged<String> onChanged;
  // 格式化 JSON，失败时返回错误消息。
  final String? Function() onFormatJson;
  // 当前请求体 Content-Type（可为空）。
  final String? contentType;
  // 是否使用 JSON 请求体（用于高亮 Content-Type 下拉）。
  final bool usesJson;
  // 是否使用 multipart/form-data（决定编辑区形态）。
  final bool usesMultipart;
  // Content-Type 变更回调。
  final ValueChanged<String?> onContentTypeChanged;
  // multipart 表单字段列表。
  final List<KeyValueRow> multipartFields;
  // multipart 已选文件列表。
  final List<MultipartFileRow> multipartFiles;

  /// 添加 multipart 表单字段回调。
  final VoidCallback onAddMultipartField;

  /// 更新 multipart 表单字段回调。
  final void Function({
    required int index,
    String? keyName,
    String? value,
    bool? enabled,
  })
  onUpdateMultipartField;

  /// 移除 multipart 表单字段回调。
  final ValueChanged<int> onRemoveMultipartField;

  /// 添加 multipart 文件回调。
  final void Function({
    required String path,
    required String fileName,
    required int sizeBytes,
    required String keyName,
  })
  onAddMultipartFile;

  /// 更新 multipart 文件回调。
  final void Function({required int index, String? keyName, bool? enabled})
  onUpdateMultipartFile;

  /// 移除 multipart 文件回调。
  final ValueChanged<int> onRemoveMultipartFile;

  /// 批量设置文件字段名回调。
  final ValueChanged<String> onApplyMultipartFileFieldName;

  /// 创建请求体编辑器状态。
  @override
  State<_BodyEditor> createState() => _BodyEditorState();
}

/// 请求体编辑器状态：管理正文输入与滚动控制器。
class _BodyEditorState extends State<_BodyEditor> {
  /// 正文文本输入控制器。
  late final TextEditingController _controller;

  /// 正文编辑区滚动控制器。
  final _scrollController = ScrollController();

  /// 以草稿正文初始化输入框。
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.body);
  }

  /// 外部正文变化时同步输入框，光标置于末尾。
  @override
  void didUpdateWidget(covariant _BodyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.body) {
      _controller.value = TextEditingValue(
        text: widget.body,
        selection: TextSelection.collapsed(offset: widget.body.length),
      );
    }
  }

  /// 释放输入与滚动控制器资源。
  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 选择多个文件加入 multipart 请求体：多选时字段名默认 files[]，单选为 file；
  // 无法读取到本地路径的文件被跳过并提示。
  Future<void> _pickMultipartFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (!mounted || result == null) return;
    var omittedFileCount = 0;
    final fieldName = result.files.length > 1 ? 'files[]' : 'file';
    for (final file in result.files) {
      final path = file.path;
      if (path == null) {
        omittedFileCount++;
        continue;
      }
      widget.onAddMultipartFile(
        path: path,
        fileName: file.name,
        sizeBytes: file.size,
        keyName: fieldName,
      );
    }
    if (omittedFileCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).selectedFilesUnreadable),
        ),
      );
    }
  }

  /// 构建请求体编辑区：标题行 + Content-Type 选择 + 正文或多表单编辑。
  @override
  Widget build(BuildContext context) {
    return DensePanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.outline)),
            ),
            child: Row(
              children: [
                // 标题行：BODY 标题 + Content-Type 下拉选择。
                MonoText(
                  AppLocalizations.of(context).body.toUpperCase(),
                  color: AppColors.textFaint,
                  size: 10,
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 16, color: AppColors.outline),
                const SizedBox(width: 10),
                Expanded(
                  child: PopupMenuButton<String>(
                    tooltip: AppLocalizations.of(context).changeBodyContentType,
                    padding: EdgeInsets.zero,
                    onSelected: (contentType) => widget.onContentTypeChanged(
                      contentType.isEmpty ? null : contentType,
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: '',
                        child: Text(AppLocalizations.of(context).noContentType),
                      ),
                      PopupMenuItem(
                        value: 'application/json',
                        child: Text('application/json'),
                      ),
                      PopupMenuItem(
                        value: 'application/x-www-form-urlencoded',
                        child: Text('application/x-www-form-urlencoded'),
                      ),
                      PopupMenuItem(
                        value: 'multipart/form-data',
                        child: Text('multipart/form-data'),
                      ),
                      PopupMenuItem(
                        value: 'text/plain',
                        child: Text('text/plain'),
                      ),
                    ],
                    child: Container(
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(
                        color: widget.usesJson
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.surfaceHigh,
                        border: Border.all(
                          color: widget.usesJson
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : AppColors.outline,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.data_object_outlined,
                            size: 14,
                            color: widget.usesJson
                                ? AppColors.primary
                                : AppColors.textFaint,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: MonoText(
                              widget.contentType ??
                                  AppLocalizations.of(context).noContentType,
                              color: widget.usesJson
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              size: 10,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.expand_more,
                            size: 15,
                            color: AppColors.textFaint,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.usesJson)
                  TextButton.icon(
                    onPressed: () {
                      final message = widget.onFormatJson();
                      if (message != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              message.localized(AppLocalizations.of(context))!,
                            ),
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                    ),
                    icon: const Icon(Icons.format_align_left, size: 15),
                    label: Text(AppLocalizations.of(context).formatJson),
                  ),
              ],
            ),
          ),
          // multipart/form-data 采用结构化表单编辑，其余类型使用全屏文本编辑。
          if (widget.usesMultipart)
            Expanded(
              child: _MultipartBodyEditor(
                fields: widget.multipartFields,
                files: widget.multipartFiles,
                onChooseFiles: _pickMultipartFiles,
                onAddField: widget.onAddMultipartField,
                onUpdateField: widget.onUpdateMultipartField,
                onRemoveField: widget.onRemoveMultipartField,
                onUpdateFile: widget.onUpdateMultipartFile,
                onRemoveFile: widget.onRemoveMultipartFile,
                onApplyFileFieldName: widget.onApplyMultipartFileFieldName,
              ),
            )
          else
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  border: Border.all(color: AppColors.outline),
                  borderRadius: BorderRadius.circular(3),
                ),
                clipBehavior: Clip.antiAlias,
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: TextFormField(
                    key: const Key('request-body-input'),
                    controller: _controller,
                    scrollController: _scrollController,
                    onChanged: widget.onChanged,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    scrollPadding: const EdgeInsets.all(12),
                    autocorrect: false,
                    enableSuggestions: false,
                    style: TextStyle(
                      color: AppColors.text,
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      height: 1.58,
                      letterSpacing: 0,
                    ),
                    strutStyle: const StrutStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      height: 1.58,
                      forceStrutHeight: true,
                    ),
                    decoration: InputDecoration(
                      // This is a code editor surface rather than a standard
                      // form field, so it owns its outer frame and spacing.
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                      hintText: AppLocalizations.of(context).requestBodyHint,
                      hintStyle: TextStyle(
                        color: AppColors.textFaint,
                        height: 1.58,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// multipart/form-data 请求体编辑：文件列表与表单字段列表。
class _MultipartBodyEditor extends StatelessWidget {
  /// 构造 multipart 请求体编辑器。
  const _MultipartBodyEditor({
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

  /// multipart 表单字段列表。
  final List<KeyValueRow> fields;

  /// multipart 已选文件列表。
  final List<MultipartFileRow> files;

  /// 选择本地文件的回调。
  final Future<void> Function() onChooseFiles;

  /// 添加表单字段回调。
  final VoidCallback onAddField;

  /// 更新表单字段回调。
  final void Function({
    required int index,
    String? keyName,
    String? value,
    bool? enabled,
  })
  onUpdateField;

  /// 移除表单字段回调。
  final ValueChanged<int> onRemoveField;

  /// 更新文件回调（字段名、启用状态）。
  final void Function({required int index, String? keyName, bool? enabled})
  onUpdateFile;

  /// 移除文件回调。
  final ValueChanged<int> onRemoveFile;

  /// 批量设置文件字段名回调。
  final ValueChanged<String> onApplyFileFieldName;

  /// 构建 multipart 编辑区：文件区与表单字段区。
  @override
  Widget build(BuildContext context) {
    // 结构：文件区（选择文件、逐行编辑字段名、批量设置）与表单字段区。
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
      children: [
        // 文件区标题行。
        _MultipartSectionHeading(
          icon: Icons.attach_file_outlined,
          title: AppLocalizations.of(context).files,
          detail: files.isEmpty
              ? AppLocalizations.of(context).noFiles
              : AppLocalizations.of(context).selectedFileCount(files.length),
          action: OutlinedButton.icon(
            onPressed: onChooseFiles,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              side: BorderSide(color: AppColors.outlineStrong),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
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
              onToggle: () =>
                  onUpdateFile(index: index, enabled: !file.enabled),
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
        // 表单字段区标题行。
        _MultipartSectionHeading(
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
            onToggle: () =>
                onUpdateField(index: index, enabled: !field.enabled),
            onRemove: () => onRemoveField(index),
          ),
        if (fields.isEmpty)
          Text(
            AppLocalizations.of(context).multipartFieldsDescription,
            style: TextStyle(color: AppColors.textFaint, fontSize: 12),
          ),
      ],
    );
  }
}

// 分区标题行：图标 + 标题 + 统计信息 + 右侧操作按钮。
class _MultipartSectionHeading extends StatelessWidget {
  /// 构造分区标题行。
  const _MultipartSectionHeading({
    required this.icon,
    required this.title,
    required this.detail,
    required this.action,
  });

  /// 分区图标。
  final IconData icon;

  /// 分区标题文本。
  final String title;

  /// 右侧统计信息文本。
  final String detail;

  /// 右侧操作按钮。
  final Widget action;

  /// 构建分区标题行。
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 7),
      Text(title, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(width: 7),
      MonoText(detail, color: AppColors.textFaint, size: 10),
      const Spacer(),
      action,
    ],
  );
}

// 未选择任何文件时的占位提示，点击可浏览本地文件。
class _MultipartEmptyState extends StatelessWidget {
  /// 构造空状态占位提示。
  const _MultipartEmptyState({required this.onChooseFiles});

  /// 选择本地文件的回调。
  final Future<void> Function() onChooseFiles;

  /// 构建占位提示：说明文案 + 浏览按钮。
  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.surfaceLow,
      border: Border.all(color: AppColors.outline),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      children: [
        Icon(Icons.file_upload_outlined, color: AppColors.textFaint),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            AppLocalizations.of(context).chooseFilesDescription,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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

// 批量字段名控件：一次为所有已选文件设置同一个 form-data 字段名。
class _BatchFileFieldControl extends StatefulWidget {
  /// 构造批量字段名控件。
  const _BatchFileFieldControl({
    required this.fieldName,
    required this.onApply,
  });

  /// 当前共享字段名（所有文件一致时提供，否则为空串）。
  final String fieldName;

  /// 点击“应用”时的回调。
  final ValueChanged<String> onApply;

  /// 创建批量字段名控件状态。
  @override
  State<_BatchFileFieldControl> createState() => _BatchFileFieldControlState();
}

/// 批量字段名控件状态：管理字段名输入控制器。
class _BatchFileFieldControlState extends State<_BatchFileFieldControl> {
  /// 字段名输入控制器。
  late final TextEditingController _controller;

  /// 以共享字段名初始化输入框。
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.fieldName);
  }

  /// 外部共享字段名变化时同步输入框。
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

  /// 释放输入控制器资源。
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 构建批量控件：输入框 + “应用”按钮，输入为空时按钮禁用。
  @override
  Widget build(BuildContext context) {
    final canApply = _controller.text.trim().isNotEmpty;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.layers_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 7),
          MonoText(
            AppLocalizations.of(context).batchField,
            color: AppColors.primary,
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
            style: TextButton.styleFrom(
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

// 单个已选文件行：显示文件名与大小，可编辑字段名、启用/禁用或移除。
class _MultipartFileLine extends StatelessWidget {
  /// 构造文件行。
  const _MultipartFileLine({
    super.key,
    required this.file,
    required this.onChanged,
    required this.onToggle,
    required this.onRemove,
  });

  /// 当前文件数据。
  final MultipartFileRow file;

  /// 字段名变更回调。
  final ValueChanged<String> onChanged;

  /// 启用/禁用切换回调。
  final VoidCallback onToggle;

  /// 移除本文件回调。
  final VoidCallback onRemove;

  /// 构建文件行：文件名与大小 + 字段名输入 + 启用/移除按钮。
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 140),
    opacity: file.enabled ? 1 : 0.5,
    child: Container(
      key: Key('multipart-file-row-${file.id}'),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 18,
            color: AppColors.primary,
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
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                MonoText(
                  _formatFileSize(file.sizeBytes),
                  color: AppColors.textFaint,
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

// 单个表单字段行：键/值输入，支持启用开关与移除。
class _MultipartTextFieldLine extends StatelessWidget {
  /// 构造表单字段行。
  const _MultipartTextFieldLine({
    super.key,
    required this.field,
    required this.onChanged,
    required this.onToggle,
    required this.onRemove,
  });

  /// 当前字段数据。
  final KeyValueRow field;

  /// 键或值变更回调。
  final void Function(String keyName, String value) onChanged;

  /// 启用/禁用切换回调。
  final VoidCallback onToggle;

  /// 移除本字段回调。
  final VoidCallback onRemove;

  /// 构建字段行：启用开关 + 键/值输入 + 移除按钮。
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 140),
    opacity: field.enabled ? 1 : 0.5,
    child: Container(
      key: Key('multipart-field-row-${field.id}'),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outline)),
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

// 将文件字节数格式化为 B / KB / MB 的可读文本。
String _formatFileSize(int sizeBytes) {
  if (sizeBytes < 1024) return '$sizeBytes B';
  if (sizeBytes < 1024 * 1024) {
    return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

// 当所有文件的字段名一致时返回该字段名，否则返回空串（用于批量输入的默认值）。
String _sharedFileFieldName(List<MultipartFileRow> files) {
  if (files.isEmpty) return '';
  final first = files.first.keyName;
  return files.every((file) => file.keyName == first) ? first : '';
}

// 鉴权编辑区：认证类型与固定字段独立于 Headers；Bearer 由运行时生成唯一的
// Authorization 请求头，避免用户在两处编辑同一凭据。
