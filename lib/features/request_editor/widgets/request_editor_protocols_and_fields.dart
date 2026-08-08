part of 'request_editor_panel.dart';

class _TabBody extends StatelessWidget {
  /// 构造标签内容区。
  const _TabBody({required this.viewModel});

  /// 视图模型，提供当前标签、草稿与编辑操作。
  final WorkspaceViewModel viewModel;

  /// 按激活标签分发渲染对应编辑区域。
  @override
  Widget build(BuildContext context) {
    // 按激活标签分发：Headers / Body / Auth / Protocol，默认 Params。
    switch (viewModel.activeRequestTab) {
      case 'Headers':
        return _KeyValueTable(
          title: AppLocalizations.of(context).requestHeaders,
          rows: viewModel.activeDraft.headers,
          headers: true,
          viewModel: viewModel,
        );
      case 'Body':
        if (!viewModel.activeRequestSupportsBody) {
          return _KeyValueTable(
            title: AppLocalizations.of(context).queryParameters,
            rows: viewModel.activeDraft.params,
            headers: false,
            viewModel: viewModel,
          );
        }
        final editor = _BodyEditor(
          body: viewModel.activeDraft.body,
          onChanged: viewModel.updateActiveDraftBody,
          onFormatJson: viewModel.formatActiveDraftJson,
          contentType: viewModel.activeContentType,
          usesJson: viewModel.usesJsonBody,
          usesMultipart: viewModel.usesMultipartBody,
          onContentTypeChanged: viewModel.updateActiveContentType,
          multipartFields: viewModel.activeDraft.multipartFields,
          multipartFiles: viewModel.activeDraft.multipartFiles,
          onAddMultipartField: viewModel.addActiveMultipartField,
          onUpdateMultipartField: viewModel.updateActiveMultipartField,
          onRemoveMultipartField: viewModel.removeActiveMultipartField,
          onAddMultipartFile: viewModel.addActiveMultipartFile,
          onUpdateMultipartFile: viewModel.updateActiveMultipartFile,
          onRemoveMultipartFile: viewModel.removeActiveMultipartFile,
          onApplyMultipartFileFieldName:
              viewModel.updateAllActiveMultipartFileKeyNames,
        );
        final preview = viewModel.activeGrpcRequestPreview;
        return preview == null
            ? editor
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: editor),
                  const SizedBox(height: 8),
                  Text(
                    preview.isSuccess
                        ? 'Protobuf request: ${preview.byteLength} bytes'
                        : preview.error!,
                    style: TextStyle(
                      color: preview.isSuccess
                          ? AppColors.success
                          : AppColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
      case 'Auth':
        return _AuthEditor(viewModel: viewModel);
      case 'Protocol':
        return viewModel.isActiveGrpc
            ? _GrpcProtocolEditor(viewModel: viewModel)
            : _WebSocketProtocolEditor(viewModel: viewModel);
      case 'Params':
      default:
        return _KeyValueTable(
          title: AppLocalizations.of(context).queryParameters,
          rows: viewModel.activeDraft.params,
          headers: false,
          viewModel: viewModel,
        );
    }
  }
}

/// gRPC 协议编辑：导入本地 proto 后选择服务与 RPC 方法。
class _GrpcProtocolEditor extends StatelessWidget {
  /// 构造 gRPC 协议编辑区。
  const _GrpcProtocolEditor({required this.viewModel});

  /// 视图模型，提供 proto 导入与服务/方法选择操作。
  final WorkspaceViewModel viewModel;

  /// 构建 gRPC 编辑区：proto 导入、服务/方法下拉与 TLS 开关。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = viewModel.activeDraft.grpc;
    return DensePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.grpcConfiguration,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final path = (await FilePicker.pickFiles(
                allowedExtensions: const ['proto'],
                type: FileType.custom,
              ))?.files.singleOrNull?.path;
              if (path == null) {
                return;
              }
              final error = await viewModel.importActiveGrpcProto(path);
              if (context.mounted && error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error.localized(AppLocalizations.of(context))!,
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.upload_file_outlined, size: 16),
            label: Text(l10n.importProto),
          ),
          const SizedBox(height: 8),
          Text(
            config.protoSchema?.path ?? l10n.noProtoSelected,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: config.serviceName,
            decoration: InputDecoration(labelText: l10n.grpcService),
            items: [
              for (final service in viewModel.activeGrpcServices)
                DropdownMenuItem(
                  value: service.name,
                  child: Text(service.name),
                ),
            ],
            onChanged: viewModel.activeGrpcServices.isEmpty
                ? null
                : viewModel.selectActiveGrpcService,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: config.methodName,
            decoration: InputDecoration(labelText: l10n.grpcMethod),
            items: [
              for (final method in viewModel.activeGrpcMethods)
                DropdownMenuItem(value: method.name, child: Text(method.name)),
            ],
            onChanged: viewModel.activeGrpcMethods.isEmpty
                ? null
                : viewModel.selectActiveGrpcMethod,
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.grpcTls),
              value: config.useTls,
              onChanged: viewModel.updateActiveGrpcUseTls,
            ),
          ),
          Text(
            l10n.grpcMetadataHint,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// WebSocket 协议编辑：配置握手时使用的子协议列表。
class _WebSocketProtocolEditor extends StatefulWidget {
  /// 构造 WebSocket 协议编辑区。
  const _WebSocketProtocolEditor({required this.viewModel});

  /// 视图模型，提供子协议读写操作。
  final WorkspaceViewModel viewModel;

  /// 创建 WebSocket 协议编辑区状态。
  @override
  State<_WebSocketProtocolEditor> createState() =>
      _WebSocketProtocolEditorState();
}

/// WebSocket 协议编辑区状态：管理子协议输入控制器。
class _WebSocketProtocolEditorState extends State<_WebSocketProtocolEditor> {
  /// 子协议列表输入框的文本控制器。
  late final TextEditingController _controller;

  /// 以草稿中的子协议列表初始化输入框。
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.viewModel.activeDraft.webSocket.subprotocols.join(', '),
    );
  }

  /// 外部子协议变化时同步输入框内容。
  @override
  void didUpdateWidget(covariant _WebSocketProtocolEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final source = widget.viewModel.activeDraft.webSocket.subprotocols.join(
      ', ',
    );
    if (_controller.text != source) _controller.text = source;
  }

  /// 释放输入控制器资源。
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 构建 WebSocket 协议编辑区：子协议输入。
  @override
  Widget build(BuildContext context) => DensePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).webSocketProtocol,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          AppLocalizations.of(context).webSocketProtocolHint,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _controller,
          onChanged: widget.viewModel.updateActiveWebSocketSubprotocols,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).subprotocols,
            hintText: AppLocalizations.of(context).subprotocolsHint,
          ),
        ),
      ],
    ),
  );
}

// 键值对编辑表格（查询参数与请求头共用）：启用开关、键、值输入及操作列。
class _KeyValueTable extends StatelessWidget {
  /// 构造键值对表格。
  const _KeyValueTable({
    required this.title,
    required this.rows,
    required this.headers,
    required this.viewModel,
  });

  /// 表格标题文本。
  final String title;

  /// 待展示的键值对行。
  final List<KeyValueRow> rows;

  /// 是否为请求头模式（决定环境变量入口与密钥能力）。
  final bool headers;

  /// 视图模型，提供字段增删改与显隐操作。
  final WorkspaceViewModel viewModel;

  /// 构建表格：标题行、表头、字段列表与底部添加行提示。
  @override
  Widget build(BuildContext context) {
    return DensePanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _FieldTableTitle(
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
                  _KeyValueLine(
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
                _AddRowHint(
                  onTap: () => viewModel.addActiveDraftField(headers: headers),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 弹出对话框让用户为环境变量指定参数名，确认后写入查询参数。
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

/// 受鉴权管理的查询参数行：只读展示，由鉴权模块运行时维护。
class _ManagedAuthenticationParameterLine extends StatelessWidget {
  /// 构造受鉴权管理的参数行。
  const _ManagedAuthenticationParameterLine({required this.row});

  /// 要展示的只读键值对行。
  final KeyValueRow row;

  /// 构建只读行：锁图标 + 键值 + “由鉴权管理”标记。
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.16),
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: _FieldTableColumns.enabled,
            child: Icon(Icons.lock_outline, size: 15),
          ),
          Expanded(
            flex: _FieldTableColumns.keyFlex,
            child: MonoText(row.keyName, color: AppColors.text),
          ),
          const SizedBox(width: _FieldTableColumns.gap),
          Expanded(
            flex: _FieldTableColumns.valueFlex,
            child: MonoText(row.value, color: AppColors.warning),
          ),
          const SizedBox(width: _FieldTableColumns.gap),
          SizedBox(
            width: _FieldTableColumns.action,
            child: Align(
              alignment: Alignment.centerLeft,
              child: MonoText(
                AppLocalizations.of(context).managedByAuthentication,
                color: AppColors.textMuted,
                size: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 键值表格各列共用的尺寸常量，保证表头与行单元格严格对齐。
class _FieldTableColumns {
  // Header and row cells share these dimensions so field edits never shift the
  // controls horizontally as content changes.
  // 表头与行单元格共用这些尺寸，保证编辑字段时控件不会横向漂移。

  /// 启用开关列宽度。
  static const double enabled = 28;

  /// 键与值两列之间的间距。
  static const double gap = 12;

  /// 右侧操作列宽度。
  static const double action = 96;

  /// 键列的弹性系数。
  static const int keyFlex = 5;

  /// 值列的弹性系数。
  static const int valueFlex = 6;
}

// 键值表格的表头行：启用、键、值、操作四列。
class _TableHeader extends StatelessWidget {
  /// 构造表头行。
  const _TableHeader();

  /// 构建表头：按各列尺寸渲染列标题文本。
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('request-field-table-header'),
      height: 30,
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          SizedBox(
            width: _FieldTableColumns.enabled,
            child: MonoText(
              AppLocalizations.of(context).enabled,
              color: AppColors.textFaint,
              size: 10,
            ),
          ),
          Expanded(
            flex: _FieldTableColumns.keyFlex,
            child: MonoText(
              AppLocalizations.of(context).key.toUpperCase(),
              color: AppColors.textFaint,
              size: 10,
            ),
          ),
          SizedBox(width: _FieldTableColumns.gap),
          Expanded(
            flex: _FieldTableColumns.valueFlex,
            child: MonoText(
              AppLocalizations.of(context).value.toUpperCase(),
              color: AppColors.textFaint,
              size: 10,
            ),
          ),
          SizedBox(width: _FieldTableColumns.gap),
          SizedBox(width: _FieldTableColumns.action),
        ],
      ),
    );
  }
}

// 表格标题行：显示标题与已启用字段数，并提供添加按钮。
class _FieldTableTitle extends StatelessWidget {
  /// 构造表格标题行。
  const _FieldTableTitle({
    required this.title,
    required this.enabledCount,
    required this.onAdd,
    this.environmentVariables = const [],
    this.onAddEnvironmentVariable,
  });

  /// 标题文本。
  final String title;

  /// 已启用且键非空的字段数量。
  final int enabledCount;

  /// 点击添加字段按钮的回调。
  final VoidCallback onAdd;

  /// 可选择的当前环境变量列表（查询参数模式提供）。
  final List<KeyValueRow> environmentVariables;

  /// 选择环境变量后的回调；为 null 时不展示环境变量入口。
  final ValueChanged<KeyValueRow>? onAddEnvironmentVariable;

  /// 构建标题行：标题 + 计数 + 环境变量入口 + 添加按钮。
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 在窄请求编辑器中优先保留添加入口，辅助的启用计数自动让位。
        final showEnabledCount = constraints.maxWidth >= 320;
        return Container(
          height: 38,
          padding: const EdgeInsets.only(left: 10, right: 5),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.outline)),
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
                  color: AppColors.textFaint,
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
}

// 单行键值对编辑：键/值输入、启用开关、移除按钮；
// 请求头行还支持将值标记为密钥并可临时显示。
class _KeyValueLine extends StatelessWidget {
  /// 构造单行键值对编辑。
  const _KeyValueLine({
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

  /// 当前行数据。
  final KeyValueRow row;

  /// 是否为请求头模式（请求头行才支持密钥标记与临时显示）。
  final bool headers;

  /// 密钥值当前是否被临时显示（非环境变量引用时生效）。
  final bool revealed;

  /// 键或值变更回调。
  final void Function(String keyName, String value) onChanged;

  /// 启用/禁用开关回调。
  final VoidCallback onToggle;

  /// 移除本行回调。
  final VoidCallback onRemove;

  /// 切换密钥标记回调。
  final VoidCallback onToggleSecret;

  /// 切换密钥临时显隐回调。
  final VoidCallback onToggleVisibility;

  /// 构建行：启用开关、键/值输入与操作按钮；禁用行以低透明度呈现。
  @override
  Widget build(BuildContext context) {
    // 环境变量引用（{{...}}）不作为真实密钥掩码，保持可读便于核对。
    final isEnvironmentReference = _isEnvironmentReference(row.value);
    final masksSecret = row.secret && !isEnvironmentReference;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      key: Key('request-field-row-${row.id}'),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: row.enabled
            ? Colors.transparent
            : AppColors.surfaceLow.withValues(alpha: 0.8),
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _FieldTableColumns.enabled,
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
                color: row.enabled ? AppColors.primary : AppColors.textFaint,
                size: 16,
              ),
            ),
          ),
          Expanded(
            flex: _FieldTableColumns.keyFlex,
            child: TextFormField(
              key: ValueKey('field-key-${row.id}'),
              initialValue: row.keyName,
              onChanged: (value) => onChanged(value, row.value),
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                color: row.enabled ? AppColors.text : AppColors.textFaint,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: AppLocalizations.of(context).key,
              ),
            ),
          ),
          const SizedBox(width: _FieldTableColumns.gap),
          Expanded(
            flex: _FieldTableColumns.valueFlex,
            child: TextFormField(
              key: ValueKey('field-value-${row.id}'),
              initialValue: row.value,
              obscureText: masksSecret && !revealed,
              onChanged: (value) => onChanged(row.keyName, value),
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                color: !row.enabled
                    ? AppColors.textFaint
                    : row.secret
                    ? AppColors.warning
                    : AppColors.textMuted,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: AppLocalizations.of(context).value,
              ),
            ),
          ),
          const SizedBox(width: _FieldTableColumns.gap),
          SizedBox(
            width: _FieldTableColumns.action,
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
}

// 表格底部的"添加行"提示按钮。
class _AddRowHint extends StatelessWidget {
  /// 构造添加行提示按钮。
  const _AddRowHint({required this.onTap});

  /// 点击添加行时的回调。
  final VoidCallback onTap;

  /// 构建“添加行”提示按钮。
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 28),
        ),
        icon: const Icon(Icons.add, size: 15),
        label: Text(AppLocalizations.of(context).addRow),
      ),
    );
  }
}

// 请求体编辑器：根据 Content-Type 在纯文本编辑与 multipart 表单编辑间切换。
