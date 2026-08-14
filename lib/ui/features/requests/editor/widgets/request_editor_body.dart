import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/l10n/workspace_message_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/application/user_message.dart';
import 'package:sendreq/ui/core/widgets/user_message_scope.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_form_url_encoded.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_multipart.dart';

class BodyEditor extends StatefulWidget {
  /// 构造请求体编辑器。
  const BodyEditor({
    super.key,
    required this.body,
    required this.onChanged,
    required this.onFormatJson,
    required this.contentType,
    required this.usesJson,
    required this.usesFormUrlEncoded,
    required this.usesMultipart,
    required this.onContentTypeChanged,
    required this.formUrlEncodedFields,
    required this.onAddFormUrlEncodedField,
    required this.onUpdateFormUrlEncodedField,
    required this.onRemoveFormUrlEncodedField,
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
  // 是否使用 application/x-www-form-urlencoded（决定结构化字段表）。
  final bool usesFormUrlEncoded;
  // 是否使用 multipart/form-data（决定编辑区形态）。
  final bool usesMultipart;
  // Content-Type 变更回调。
  final ValueChanged<String?> onContentTypeChanged;
  // URL 编码表单字段与操作回调。
  final List<KeyValueRow> formUrlEncodedFields;
  final VoidCallback onAddFormUrlEncodedField;
  final void Function({
    required int index,
    String? keyName,
    String? value,
    bool? enabled,
  })
  onUpdateFormUrlEncodedField;
  final ValueChanged<int> onRemoveFormUrlEncodedField;
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
  State<BodyEditor> createState() => _BodyEditorState();
}

/// 请求体编辑器状态：管理正文输入与滚动控制器。
class _BodyEditorState extends State<BodyEditor> {
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
  void didUpdateWidget(covariant BodyEditor oldWidget) {
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
      publishUserMessage(
        context,
        AppLocalizations.of(context).selectedFilesUnreadable,
        severity: UserMessageSeverity.warning,
        deduplicationKey: 'multipart.files.unreadable',
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
              border: Border(bottom: BorderSide(color: context.chakra.border)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final l10n = AppLocalizations.of(context);
                final formatAction = constraints.maxWidth < 420
                    ? DenseIconButton(
                        key: const Key('request-body-format-json'),
                        icon: Icons.format_align_left,
                        tooltip: l10n.formatJson,
                        onPressed: _formatJson,
                        size: 28,
                      )
                    : TextButton.icon(
                        key: const Key('request-body-format-json'),
                        onPressed: _formatJson,
                        style: ChakraRecipes.sized(
                          ChakraRecipes.ghostFor(context),
                          minimumSize: const Size(0, 28),
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                        ),
                        icon: const Icon(Icons.format_align_left, size: 15),
                        label: Text(l10n.formatJson),
                      );
                return Row(
                  children: [
                    // 标题行：BODY 标题 + Content-Type 下拉选择。
                    MonoText(
                      AppLocalizations.of(context).body.toUpperCase(),
                      color: context.chakra.fgSubtle,
                      size: 10,
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 1,
                      height: 16,
                      color: context.chakra.border,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PopupMenuButton<String>(
                        tooltip: AppLocalizations.of(
                          context,
                        ).changeBodyContentType,
                        padding: EdgeInsets.zero,
                        onSelected: (contentType) =>
                            widget.onContentTypeChanged(
                              contentType.isEmpty ? null : contentType,
                            ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: '',
                            child: Text(
                              AppLocalizations.of(context).noContentType,
                            ),
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
                            value: 'application/xml',
                            child: Text('application/xml'),
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
                                ? context.chakra.colorPaletteFg.withValues(
                                    alpha: 0.12,
                                  )
                                : context.chakra.bgEmphasized,
                            border: Border.all(
                              color: widget.usesJson
                                  ? context.chakra.colorPaletteFg.withValues(
                                      alpha: 0.5,
                                    )
                                  : context.chakra.border,
                            ),
                            borderRadius: ChakraRadii.control,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.data_object_outlined,
                                size: 14,
                                color: widget.usesJson
                                    ? context.chakra.colorPaletteFg
                                    : context.chakra.fgSubtle,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: MonoText(
                                  widget.contentType ??
                                      AppLocalizations.of(
                                        context,
                                      ).noContentType,
                                  color: widget.usesJson
                                      ? context.chakra.colorPaletteFg
                                      : context.chakra.fgMuted,
                                  size: 10,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.expand_more,
                                size: 15,
                                color: context.chakra.fgSubtle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (widget.usesJson) formatAction,
                  ],
                );
              },
            ),
          ),
          // 两种表单格式使用结构化编辑，其余原始类型使用全屏文本编辑。
          if (widget.usesMultipart)
            Expanded(
              child: MultipartBodyEditor(
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
          else if (widget.usesFormUrlEncoded)
            Expanded(
              child: FormUrlEncodedBodyEditor(
                fields: widget.formUrlEncodedFields,
                onAddField: widget.onAddFormUrlEncodedField,
                onUpdateField: widget.onUpdateFormUrlEncodedField,
                onRemoveField: widget.onRemoveFormUrlEncodedField,
              ),
            )
          else
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.chakra.bgSubtle,
                  border: Border.all(color: context.chakra.border),
                  borderRadius: ChakraRadii.control,
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
                      color: context.chakra.fg,
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
                      // 这里是代码编辑面而不是标准表单控件，
                      // 因此由自身管理外框与间距。
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                      hintText: AppLocalizations.of(context).requestBodyHint,
                      hintStyle: TextStyle(
                        color: context.chakra.fgSubtle,
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

  void _formatJson() {
    final message = widget.onFormatJson();
    if (message == null) return;
    publishUserMessage(
      context,
      message.localized(AppLocalizations.of(context))!,
      severity: UserMessageSeverity.warning,
      deduplicationKey: 'request.body.format.failed',
    );
  }
}
