part of 'request_editor_panel.dart';

enum _CloseChoice { save, discard, cancel }

// 编辑器顶部的横向模式标签条：根据协议动态决定可切换的编辑区域。
class _EditorModeTabs extends StatelessWidget {
  /// 构造编辑模式标签条。
  const _EditorModeTabs({
    required this.tabs,
    required this.active,
    required this.onSelected,
    required this.labelFor,
  });

  // 可切换的标签标识符列表。
  final List<String> tabs;
  // 当前选中的标签标识符。
  final String active;
  // 标签选中回调。
  final ValueChanged<String> onSelected;
  // 将标签标识符转换为本地化显示文本。
  final String Function(String tab) labelFor;

  /// 构建横向滚动标签条：遍历标签并渲染对应标签按钮。
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.outline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in tabs)
              _EditorModeTab(
                label: labelFor(tab),
                selected: tab == active,
                onPressed: () => onSelected(tab),
              ),
          ],
        ),
      ),
    );
  }
}

// 单个编辑模式标签按钮：选中时以主色下划线高亮。
class _EditorModeTab extends StatelessWidget {
  /// 构造编辑模式标签按钮。
  const _EditorModeTab({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  /// 标签显示文本。
  final String label;

  /// 是否选中，选中时以主色下划线高亮。
  final bool selected;

  /// 点击标签的回调。
  final VoidCallback onPressed;

  /// 构建标签按钮：下划线动画 + 文字。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(68, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: selected ? AppColors.text : AppColors.textFaint,
          shape: const RoundedRectangleBorder(),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

// 将内部标签标识符映射为本地化显示文本。
String _editorTabLabel(AppLocalizations l10n, String tab) => switch (tab) {
  'Params' => l10n.requestTabParams,
  'Headers' => l10n.requestTabHeaders,
  'Auth' => l10n.requestTabAuth,
  'Body' => l10n.requestTabBody,
  'Protocol' => l10n.requestTabProtocol,
  _ => tab,
};

// 请求标签条：横向排列所有已打开的请求标签，支持右键批量关闭。
class _RequestTabStrip extends StatelessWidget {
  /// 构造请求标签条。
  const _RequestTabStrip({required this.viewModel, required this.onClose});

  /// 视图模型，提供标签列表与选中/关闭操作。
  final WorkspaceViewModel viewModel;

  /// 点击关闭按钮时的回调（交由外层处理未保存确认）。
  final ValueChanged<RequestTab> onClose;

  // 在标签上右键弹出关闭菜单：可关闭其他 / 左侧 / 右侧的标签。
  Future<void> _showTabMenu(
    BuildContext context,
    List<RequestTab> tabs,
    int index,
    Offset position,
  ) async {
    final action = await showMenu<_TabMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: _TabMenuAction.closeOthers,
          child: Text(AppLocalizations.of(context).closeOtherTabs),
        ),
        if (index > 0)
          PopupMenuItem(
            value: _TabMenuAction.closeLeft,
            child: Text(AppLocalizations.of(context).closeTabsToLeft),
          ),
        if (index < tabs.length - 1)
          PopupMenuItem(
            value: _TabMenuAction.closeRight,
            child: Text(AppLocalizations.of(context).closeTabsToRight),
          ),
      ],
    );
    if (action == null || !context.mounted) return;
    final ids = switch (action) {
      _TabMenuAction.closeOthers => [
        for (final tab in tabs)
          if (tab != tabs[index]) tab.id,
      ],
      _TabMenuAction.closeLeft => [for (final tab in tabs.take(index)) tab.id],
      _TabMenuAction.closeRight => [
        for (final tab in tabs.skip(index + 1)) tab.id,
      ],
    };
    viewModel.closeRequestTabs(ids);
  }

  /// 构建标签条：横向 ListView，每项含选中态高亮、标题与关闭按钮。
  @override
  Widget build(BuildContext context) {
    final tabs = viewModel.openRequestTabs;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 3),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final selected = tab.requestId == viewModel.activeRequest.id;
          return GestureDetector(
            onSecondaryTapDown: (details) =>
                _showTabMenu(context, tabs, index, details.globalPosition),
            child: Container(
              decoration: BoxDecoration(
                color: selected ? AppColors.surfaceHighest : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.7)
                      : Colors.transparent,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => viewModel.selectRequestTab(tab.id),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.only(left: 10, right: 4),
                      foregroundColor: selected
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                    child: Text(
                      '${tab.title}${viewModel.isRequestDirty(tab.requestId) ? ' *' : ''}',
                    ),
                  ),
                  DenseIconButton(
                    icon: Icons.close,
                    tooltip: AppLocalizations.of(
                      context,
                    ).closeRequest(tab.title),
                    onPressed: () => onClose(tab),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// 标签右键菜单可选操作。
enum _TabMenuAction { closeOthers, closeLeft, closeRight }

/// 用户可直接操作的请求种类。HTTP 方法与 WebSocket/gRPC 在此处同级。
enum _RequestKind {
  get('get', 'GET', ApiRequestProtocol.http, httpMethod: 'GET'),
  post('post', 'POST', ApiRequestProtocol.http, httpMethod: 'POST'),
  put('put', 'PUT', ApiRequestProtocol.http, httpMethod: 'PUT'),
  patch('patch', 'PATCH', ApiRequestProtocol.http, httpMethod: 'PATCH'),
  delete('delete', 'DELETE', ApiRequestProtocol.http, httpMethod: 'DELETE'),
  webSocket('websocket', 'WebSocket', ApiRequestProtocol.webSocket),
  grpc('grpc', 'gRPC', ApiRequestProtocol.grpc);

  const _RequestKind(this.id, this.label, this.protocol, {this.httpMethod});

  final String id;
  final String label;
  final ApiRequestProtocol protocol;
  final String? httpMethod;

  /// 请求类型对应的主题色。
  Color get color => switch (this) {
    _RequestKind.get => AppColors.methodGet,
    _RequestKind.post => AppColors.methodPost,
    _RequestKind.put || _RequestKind.patch => AppColors.methodPut,
    _RequestKind.delete => AppColors.methodDelete,
    _RequestKind.webSocket => AppColors.success,
    _RequestKind.grpc => AppColors.primary,
  };

  /// 紧凑展示标签；WebSocket 使用缩写 WS。
  String get compactLabel => this == _RequestKind.webSocket ? 'WS' : label;

  bool matches({
    required ApiRequestProtocol protocol,
    required String method,
  }) =>
      this.protocol == protocol &&
      (httpMethod == null || httpMethod == method.toUpperCase());
}

// 请求行采用“请求类型 + 端点 + 操作”结构；菜单中的每一项均为独立请求类型。
class _UrlBar extends StatefulWidget {
  /// 构造 URL 栏。
  const _UrlBar({
    required this.requestId,
    required this.draft,
    required this.url,
    required this.shortcut,
    required this.sendUnavailableReason,
    required this.onSend,
    required this.onUrlChanged,
    required this.webSocketState,
    required this.onWebSocketConnect,
    required this.onWebSocketDisconnect,
    required this.onRequestKindSelected,
  });

  /// 当前请求 ID（用于区分不同请求的 URL 栏）。
  final String requestId;

  /// 当前请求草稿，用于读取协议与方法。
  final RequestDraft draft;

  /// URL 的受控值（来自草稿）。
  final String url;

  /// 发送快捷键的提示文案。
  final String shortcut;

  /// 发送回调；为 null 时发送按钮禁用。
  final VoidCallback? onSend;

  /// 发送不可用时的原因文案。
  final String? sendUnavailableReason;

  /// URL 文本变更回调。
  final ValueChanged<String> onUrlChanged;

  /// WebSocket 连接当前状态，用于填充地址栏的固定执行槽位。
  final WebSocketConnectionState webSocketState;

  /// 建立 WebSocket 连接。
  final VoidCallback onWebSocketConnect;

  /// 断开当前 WebSocket 连接。
  final VoidCallback onWebSocketDisconnect;

  /// 选择一个独立请求类型（GET、WebSocket、gRPC 等）。
  final ValueChanged<_RequestKind> onRequestKindSelected;

  /// 创建 URL 栏状态。
  @override
  State<_UrlBar> createState() => _UrlBarState();
}

/// URL 栏状态：持有输入控制器并保持与草稿 URL 同步。
class _UrlBarState extends State<_UrlBar> {
  /// URL 输入框的文本控制器。
  late final TextEditingController _controller;

  /// 输入焦点只改变主输入面的描边色，不影响控件几何。
  late final FocusNode _focusNode;

  /// 当前草稿中的 URL（受控值来源）。
  String get _url => widget.url;

  /// 初始化输入控制器并预填当前 URL。
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _url);
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  void _handleFocusChanged() => setState(() {});

  /// 地址栏与 Params 必须一一对应；草稿任意一侧变化后立即回写。
  @override
  void didUpdateWidget(covariant _UrlBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 地址栏与 Params 必须一一对应；草稿任意一侧变化后立即回写。
    _syncController();
  }

  /// 将输入框内容回写到草稿 URL，光标保持置于末尾。
  void _syncController() {
    if (_controller.text == _url) return;
    _controller.value = TextEditingValue(
      text: _url,
      selection: TextSelection.collapsed(offset: _url.length),
    );
  }

  /// 释放输入控制器资源。
  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  /// 构建请求命令条：类型与执行控制在上，地址在下一行独占编辑宽度。
  ///
  /// 端点通常比方法或执行命令长得多。将三者挤在同一行会让 URL 的可读
  /// 宽度随面板变窄而迅速失效，所以这里固定为两行；协议切换只替换首行
  /// 的语义内容，整个编辑器的几何保持不变。
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('request-url-bar'),
      height: 102,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMid,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 340;
          final gap = compact ? 6.0 : 8.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    _RequestKindSelector(
                      protocol: widget.draft.protocol,
                      method: widget.draft.method,
                      compact: compact,
                      onSelected: widget.onRequestKindSelected,
                    ),
                    const Spacer(),
                    _EndpointActionSlot(
                      protocol: widget.draft.protocol,
                      shortcut: widget.shortcut,
                      sendUnavailableReason: widget.sendUnavailableReason,
                      onSend: widget.onSend,
                      webSocketState: widget.webSocketState,
                      onWebSocketConnect: widget.onWebSocketConnect,
                      onWebSocketDisconnect: widget.onWebSocketDisconnect,
                      compact: compact,
                    ),
                  ],
                ),
              ),
              SizedBox(height: gap),
              _EndpointUrlInput(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: widget.onUrlChanged,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 主端点输入面：独占命令条整行，保证模板 URL 可阅读且文字垂直居中。
class _EndpointUrlInput extends StatelessWidget {
  const _EndpointUrlInput({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('request-url-input'),
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border.all(
          color: focusNode.hasFocus
              ? AppColors.primary
              : AppColors.outlineStrong,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          // 固定编辑槽而不是依赖 InputDecorator 的自适应高度；等宽 URL 和
          // 光标会与 40px 输入面严格同心，且不受全局表单密度影响。
          child: Transform.translate(
            // EditableText 的实际字形盒在 20px 槽内会向下偏 2px；补偿后
            // 文本与光标的可见中心恰好对齐 40px 输入面中心。
            offset: const Offset(0, -2),
            child: SizedBox(
              height: 20,
              width: double.infinity,
              child: TextFormField(
                key: const Key('request-url-text-field'),
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
                strutStyle: const StrutStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  height: 1.2,
                  leading: 0,
                  forceStrutHeight: true,
                ),
                cursorHeight: 18,
                maxLines: 1,
                scrollPadding: EdgeInsets.zero,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'https://api.example.com/...',
                  hintStyle: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 13,
                    color: AppColors.textFaint,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 请求类型选择器。请求类型是唯一入口，不再将 HTTP 协议和方法拆成两层。
class _RequestKindSelector extends StatefulWidget {
  const _RequestKindSelector({
    required this.protocol,
    required this.method,
    required this.compact,
    required this.onSelected,
  });

  final ApiRequestProtocol protocol;
  final String method;
  final bool compact;
  final ValueChanged<_RequestKind> onSelected;

  @override
  State<_RequestKindSelector> createState() => _RequestKindSelectorState();
}

/// 请求类型选择器的状态：计算当前选中项并弹出下拉菜单。
class _RequestKindSelectorState extends State<_RequestKindSelector> {
  /// 与当前请求协议/方法匹配的类型；未匹配时回退到 GET。
  _RequestKind get _selected => _RequestKind.values.firstWhere(
    (kind) => kind.matches(protocol: widget.protocol, method: widget.method),
    orElse: () => _RequestKind.get,
  );

  Future<void> _openMenu() async {
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
    final value = await showMenu<_RequestKind>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(origin.dx, origin.dy + button.size.height + 4, 84, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final kind in _RequestKind.values)
          PopupMenuItem<_RequestKind>(
            key: Key('request-kind-option-${kind.id}'),
            value: kind,
            child: Row(
              children: [
                SizedBox(
                  width: 82,
                  child: MonoText(
                    kind.label,
                    color: kind.color,
                    size: 11,
                    weight: FontWeight.w800,
                  ),
                ),
                if (kind == _selected)
                  Icon(Icons.check, size: 16, color: kind.color),
              ],
            ),
          ),
      ],
    );
    if (value != null) widget.onSelected(value);
  }

  @override
  /// 构建请求类型选择器按钮。
  Widget build(BuildContext context) {
    final selected = _selected;
    return SizedBox(
      key: const Key('request-kind-selector'),
      width: widget.compact ? 64 : 92,
      height: 36,
      child: Tooltip(
        message: 'Change request type',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openMenu,
            borderRadius: BorderRadius.circular(5),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.only(
                left: widget.compact ? 8 : 10,
                right: widget.compact ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: selected.color.withValues(alpha: 0.1),
                border: Border.all(
                  color: selected.color.withValues(alpha: 0.62),
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: MonoText(
                      widget.compact ? selected.compactLabel : selected.label,
                      color: selected.color,
                      size: 11.5,
                      weight: FontWeight.w800,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 17,
                    color: selected.color,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 固定宽度的执行按钮，覆盖本地化文案与最长连接动作，不会挤压文字。
class _EndpointActionSlot extends StatelessWidget {
  const _EndpointActionSlot({
    required this.protocol,
    required this.shortcut,
    required this.sendUnavailableReason,
    required this.onSend,
    required this.webSocketState,
    required this.onWebSocketConnect,
    required this.onWebSocketDisconnect,
    required this.compact,
  });

  final ApiRequestProtocol protocol;
  final String shortcut;
  final String? sendUnavailableReason;
  final VoidCallback? onSend;
  final WebSocketConnectionState webSocketState;
  final VoidCallback onWebSocketConnect;
  final VoidCallback onWebSocketDisconnect;
  final bool compact;

  @override
  /// 构建发送栏：根据协议显示发送/连接按钮与快捷键提示。
  Widget build(BuildContext context) {
    final isWebSocket = protocol == ApiRequestProtocol.webSocket;
    final connecting =
        webSocketState == WebSocketConnectionState.connecting ||
        webSocketState == WebSocketConnectionState.closing;
    final connected = webSocketState == WebSocketConnectionState.connected;
    final label = isWebSocket
        ? connected
              ? AppLocalizations.of(context).disconnect
              : AppLocalizations.of(context).connect
        : protocol == ApiRequestProtocol.grpc
        ? 'Call'
        : AppLocalizations.of(context).send;
    final icon = isWebSocket
        ? connected
              ? Icons.link_off
              : Icons.link
        : protocol == ApiRequestProtocol.grpc
        ? Icons.call_made_outlined
        : Icons.play_arrow_rounded;
    final onPressed = isWebSocket
        ? connecting
              ? null
              : connected
              ? onWebSocketDisconnect
              : onWebSocketConnect
        : onSend;
    final tooltip = isWebSocket
        ? connecting
              ? AppLocalizations.of(context).connecting
              : label
        : sendUnavailableReason?.localized(AppLocalizations.of(context)) ??
              AppLocalizations.of(context).sendRequestWithShortcut(shortcut);
    final width = compact ? 46.0 : 112.0;
    final style = FilledButton.styleFrom(
      minimumSize: Size(width, 36),
      maximumSize: Size(width, 36),
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 10),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      disabledBackgroundColor: AppColors.surfaceHighest,
      disabledForegroundColor: AppColors.textMuted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    );
    final actionIcon = connecting
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 15);
    final action = compact
        ? FilledButton(style: style, onPressed: onPressed, child: actionIcon)
        : FilledButton.icon(
            style: style,
            onPressed: onPressed,
            icon: actionIcon,
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                fontSize: 13,
                height: 1.1,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          );
    return SizedBox(
      key: const Key('request-action-slot'),
      width: width,
      height: 36,
      child: Tooltip(message: tooltip, child: action),
    );
  }
}

// 请求身份区域：展示请求名称、路径，以及未保存标记和撤销入口。
class _RequestIdentity extends StatelessWidget {
  /// 构造请求身份区域。
  const _RequestIdentity({
    required this.title,
    required this.path,
    required this.isDirty,
    required this.onDiscard,
  });

  /// 请求名称。
  final String title;

  /// 请求路径（为空时不展示）。
  final String path;

  /// 是否存在未保存更改；为 true 时展示未保存标记与撤销按钮。
  final bool isDirty;

  /// 点击撤销按钮（丢弃未保存更改）的回调。
  final VoidCallback onDiscard;

  /// 构建请求身份区：名称、路径 + 可选的未保存标记与撤销入口。
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MonoText(
                AppLocalizations.of(context).request,
                color: AppColors.textFaint,
                size: 10,
              ),
              const SizedBox(height: 3),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (path.isNotEmpty)
                Text(
                  path,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
        if (isDirty) ...[
          const SizedBox(width: 8),
          Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.45),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: MonoText(
              AppLocalizations.of(context).unsaved,
              color: AppColors.warning,
              size: 10,
            ),
          ),
          DenseIconButton(
            icon: Icons.undo,
            tooltip: AppLocalizations.of(context).discardUnsavedChangesTooltip,
            onPressed: onDiscard,
            size: 26,
          ),
        ],
      ],
    );
  }
}

// 根据当前选中的编辑标签渲染对应编辑区域。
