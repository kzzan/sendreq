import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/workspace_models.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/workspace_message_localizations.dart';
import '../../workspace/models/workspace_shell_models.dart';
import '../../workspace/view_models/workspace_view_model.dart';
import '../../../core/widgets/dense_controls.dart';

/// Quick Mock 面板：配置一条本地假响应路由，并将其提供给调用方。
class MockServersPanel extends StatelessWidget {
  /// 构造 Quick Mock 面板。
  const MockServersPanel({super.key, required this.viewModel});

  /// 工作区视图模型，提供 Quick Mock 草稿与运行控制能力。
  final WorkspaceViewModel viewModel;

  /// 创建新 Mock 草稿前，若已有草稿先确认是否替换。
  Future<void> _replaceQuickMock(
    BuildContext context,
    VoidCallback create,
  ) async {
    if (viewModel.mockDraft != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l10n.replaceQuickMockTitle),
            content: Text(l10n.replaceQuickMockMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.replaceQuickMock),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }
    create();
  }

  /// 构建 Quick Mock 面板：无草稿显示空态，有草稿显示编辑工作区。
  @override
  Widget build(BuildContext context) {
    final draft = viewModel.mockDraft;
    return Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuickMockHeader(
            viewModel: viewModel,
            draft: draft,
            onCreateManual: () =>
                _replaceQuickMock(context, viewModel.createManualMockDraft),
          ),
          Expanded(
            child: draft == null
                ? _QuickMockEmptyWorkspace(
                    viewModel: viewModel,
                    onCreateManual: () => _replaceQuickMock(
                      context,
                      viewModel.createManualMockDraft,
                    ),
                    onCreateFromResponse: () =>
                        _replaceQuickMock(context, viewModel.createMockDraft),
                  )
                : _QuickMockWorkspace(viewModel: viewModel, draft: draft),
          ),
        ],
      ),
    );
  }
}

/// Quick Mock 页头部：标题、来源描述与新建/返回操作。
class _QuickMockHeader extends StatelessWidget {
  /// 构造 Quick Mock 页头部。
  const _QuickMockHeader({
    required this.viewModel,
    required this.draft,
    required this.onCreateManual,
  });

  /// 工作区视图模型，提供草稿与返回操作。
  final WorkspaceViewModel viewModel;

  /// 当前 Mock 草稿；无草稿时仅展示描述文案。
  final MockDraft? draft;

  /// 新建手工 Mock 草稿回调。
  final VoidCallback onCreateManual;

  /// 构建 Quick Mock 页头部。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitle = draft == null
        ? l10n.mockDraftDescription
        : draft!.source == MockDraftSource.manual
        ? l10n.manualMock
        : l10n.fromLatestResponse;
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 25,
          height: 25,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.route_outlined, size: 15, color: AppColors.primary),
        ),
        const SizedBox(width: 9),
        Text(
          l10n.mockDraft,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (draft?.source == MockDraftSource.response) ...[
          DenseIconButton(
            icon: Icons.arrow_back_outlined,
            tooltip: l10n.returnToResponse,
            onPressed: viewModel.returnFromMockDraft,
          ),
          const SizedBox(width: 4),
        ],
        if (draft != null)
          FilledButton.icon(
            key: const Key('replace-with-new-mock-button'),
            onPressed: onCreateManual,
            icon: const Icon(Icons.add, size: 16),
            label: Text(l10n.newMock),
          ),
      ],
    );
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.fromLTRB(18, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outline)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              title,
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: MonoText(subtitle, color: AppColors.textMuted, size: 10),
              ),
            ],
          );
          if (constraints.maxWidth < 620 && draft != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              if (draft != null) actions,
            ],
          );
        },
      ),
    );
  }
}

/// Quick Mock 空态：无草稿时提供新建与“从响应创建”入口。
class _QuickMockEmptyWorkspace extends StatelessWidget {
  /// 构造 Quick Mock 空态。
  const _QuickMockEmptyWorkspace({
    required this.viewModel,
    required this.onCreateManual,
    required this.onCreateFromResponse,
  });

  /// 工作区视图模型，提供创建能力判断。
  final WorkspaceViewModel viewModel;

  /// 新建手工 Mock 草稿回调。
  final VoidCallback onCreateManual;

  /// 从最新响应创建 Mock 草稿回调。
  final VoidCallback onCreateFromResponse;

  /// 构建 Quick Mock 空态：引导侧栏 + 示例画布。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rail = Container(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MonoText('CREATE', color: AppColors.textFaint, size: 10),
          const SizedBox(height: 10),
          Text(l10n.noMockDraft, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            l10n.mockLoopbackNote,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('new-manual-mock-button'),
              onPressed: onCreateManual,
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.newMock),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('create-mock-from-response-button'),
              onPressed: viewModel.canCreateMockFromResponse
                  ? onCreateFromResponse
                  : null,
              icon: const Icon(Icons.content_copy_outlined, size: 16),
              label: Text(l10n.createMockFromResponse),
            ),
          ),
        ],
      ),
    );
    final canvas = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.route_outlined, size: 28, color: AppColors.textFaint),
          const SizedBox(height: 10),
          MonoText('METHOD  /PATH  ->  STATUS', color: AppColors.textFaint),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                rail,
                const Divider(height: 1),
                SizedBox(height: 180, child: canvas),
              ],
            ),
          );
        }
        return Row(
          children: [
            SizedBox(width: WorkspacePaneWidths.secondary, child: rail),
            VerticalDivider(width: 1, color: AppColors.outline),
            Expanded(child: canvas),
          ],
        );
      },
    );
  }
}

/// Quick Mock 编辑工作区：路由侧栏 + 响应编辑器。
class _QuickMockWorkspace extends StatelessWidget {
  /// 构造 Quick Mock 编辑工作区。
  const _QuickMockWorkspace({required this.viewModel, required this.draft});

  /// 工作区视图模型，提供草稿数据与编辑操作。
  final WorkspaceViewModel viewModel;

  /// 当前编辑的 Mock 草稿。
  final MockDraft draft;

  /// 构建 Quick Mock 编辑工作区：窄屏上下堆叠，宽屏左右分栏。
  @override
  Widget build(BuildContext context) {
    final rail = _QuickMockRouteRail(viewModel: viewModel, draft: draft);
    final response = _QuickMockResponseWorkspace(
      viewModel: viewModel,
      draft: draft,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [rail, const Divider(height: 1), response],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: WorkspacePaneWidths.secondary, child: rail),
            VerticalDivider(width: 1, color: AppColors.outline),
            Expanded(child: response),
          ],
        );
      },
    );
  }
}

/// Quick Mock 路由侧栏：路由编辑与本地运行控制。
class _QuickMockRouteRail extends StatelessWidget {
  /// 构造路由侧栏。
  const _QuickMockRouteRail({required this.viewModel, required this.draft});

  /// 工作区视图模型，提供路由与运行控制。
  final WorkspaceViewModel viewModel;

  /// 当前编辑的 Mock 草稿。
  final MockDraft draft;

  /// 构建路由侧栏。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MonoText('ROUTE', color: AppColors.textFaint, size: 10),
          const SizedBox(height: 10),
          _MockRouteEditor(viewModel: viewModel, draft: draft),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.outline),
          const SizedBox(height: 14),
          MonoText(
            l10n.localRuntime.toUpperCase(),
            color: AppColors.textFaint,
            size: 10,
          ),
          const SizedBox(height: 10),
          _RuntimeControls(viewModel: viewModel),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.outline),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 14, color: AppColors.textFaint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.mockLoopbackNote,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mock 响应编辑区：响应体与响应头编辑器。
class _QuickMockResponseWorkspace extends StatelessWidget {
  /// 构造响应编辑区。
  const _QuickMockResponseWorkspace({
    required this.viewModel,
    required this.draft,
  });

  /// 工作区视图模型，提供响应数据与编辑操作。
  final WorkspaceViewModel viewModel;

  /// 当前编辑的 Mock 草稿。
  final MockDraft draft;

  /// 构建响应编辑区。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              MonoText(
                l10n.mockResponse.toUpperCase(),
                color: AppColors.textFaint,
                size: 10,
              ),
              const Spacer(),
              StatusPill(draft.response.statusCode),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: TextFormField(
              key: const Key('mock-response-body-input'),
              initialValue: draft.response.body,
              onChanged: viewModel.updateMockResponseBody,
              expands: true,
              minLines: null,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                height: 1.5,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.all(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.outline),
          const SizedBox(height: 14),
          _MockResponseHeadersEditor(
            viewModel: viewModel,
            headers: draft.response.headers,
          ),
        ],
      ),
    );
  }
}

/// Mock 路由编辑器：方法、路径与状态码输入。
class _MockRouteEditor extends StatelessWidget {
  /// 构造路由编辑器。
  const _MockRouteEditor({required this.viewModel, required this.draft});

  /// 工作区视图模型，提供路由更新操作。
  final WorkspaceViewModel viewModel;

  /// 当前编辑的 Mock 草稿。
  final MockDraft draft;

  /// 构建路由编辑器。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final methodControl = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MonoText(
          l10n.method.toUpperCase(),
          color: AppColors.textFaint,
          size: 10,
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: l10n.changeHttpMethod,
          onSelected: viewModel.updateMockMethod,
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'GET', child: Text('GET')),
            PopupMenuItem(value: 'POST', child: Text('POST')),
            PopupMenuItem(value: 'PUT', child: Text('PUT')),
            PopupMenuItem(value: 'PATCH', child: Text('PATCH')),
            PopupMenuItem(value: 'DELETE', child: Text('DELETE')),
          ],
          child: MethodPill(draft.request.method),
        ),
      ],
    );
    final statusControl = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MonoText(
          l10n.status.toUpperCase(),
          color: AppColors.textFaint,
          size: 10,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: TextFormField(
            key: const Key('mock-status-input'),
            initialValue: '${draft.response.statusCode}',
            keyboardType: TextInputType.number,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: (value) {
              final status = int.tryParse(value);
              if (status != null) viewModel.updateMockStatusCode(status);
            },
            validator: (value) {
              final status = int.tryParse(value ?? '');
              return status != null && status >= 100 && status <= 599
                  ? null
                  : l10n.invalidHttpStatus;
            },
            style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
            decoration: const InputDecoration(isDense: true),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 270
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    methodControl,
                    const SizedBox(height: 8),
                    statusControl,
                  ],
                )
              : Row(children: [methodControl, const Spacer(), statusControl]),
        ),
        const SizedBox(height: 12),
        MonoText(l10n.path.toUpperCase(), color: AppColors.textFaint, size: 10),
        const SizedBox(height: 5),
        TextFormField(
          key: const Key('mock-route-input'),
          initialValue: viewModel.mockRoute,
          onChanged: viewModel.updateMockRoute,
          style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
          decoration: const InputDecoration(isDense: true),
        ),
      ],
    );
  }
}

/// Mock 响应 Header 的结构化编辑器，支持新增、启用、修改和移除。
class _MockResponseHeadersEditor extends StatelessWidget {
  /// 构造响应头编辑器。
  const _MockResponseHeadersEditor({
    required this.viewModel,
    required this.headers,
  });

  /// 工作区视图模型，提供响应头增删改操作。
  final WorkspaceViewModel viewModel;

  /// 当前响应头列表。
  final List<KeyValueRow> headers;

  /// 构建响应头编辑器。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MonoText(
              l10n.responseHeaders.toUpperCase(),
              color: AppColors.textFaint,
              size: 10,
            ),
            const Spacer(),
            DenseIconButton(
              icon: Icons.add,
              tooltip: l10n.addField,
              onPressed: viewModel.addMockResponseHeader,
              size: 28,
            ),
          ],
        ),
        const SizedBox(height: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 144),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: headers.length,
            itemBuilder: (context, index) {
              final header = headers[index];
              return Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: header.enabled
                      ? AppColors.surfaceLow
                      : AppColors.surfaceLow.withValues(alpha: 0.55),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Checkbox(
                        value: header.enabled,
                        onChanged: (value) =>
                            viewModel.updateMockResponseHeader(
                              index: index,
                              enabled: value ?? false,
                            ),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('mock-header-key-${header.id}'),
                        initialValue: header.keyName,
                        onChanged: (value) =>
                            viewModel.updateMockResponseHeader(
                              index: index,
                              keyName: value,
                            ),
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: l10n.key,
                        ),
                      ),
                    ),
                    Container(width: 1, height: 22, color: AppColors.outline),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('mock-header-value-${header.id}'),
                        initialValue: header.value,
                        onChanged: (value) =>
                            viewModel.updateMockResponseHeader(
                              index: index,
                              value: value,
                            ),
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: l10n.value,
                        ),
                      ),
                    ),
                    DenseIconButton(
                      icon: Icons.close,
                      tooltip: l10n.removeRow,
                      onPressed: () =>
                          viewModel.removeMockResponseHeader(index),
                      size: 26,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 本地运行控制：启动/停止 Mock 服务并展示可复制的服务地址。
class _RuntimeControls extends StatelessWidget {
  /// 构造本地运行控制。
  const _RuntimeControls({required this.viewModel});

  /// 工作区视图模型，提供 Mock 服务的启停与地址。
  final WorkspaceViewModel viewModel;

  /// 执行异步操作并以 SnackBar 反馈操作结果。
  Future<void> _showActionFeedback(
    BuildContext context,
    Future<void> action,
  ) async {
    await action;
    if (!context.mounted) return;
    final message = viewModel.lastActionMessage.localized(
      AppLocalizations.of(context),
    );
    if (message == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 构建运行控制：启停按钮与可复制的服务地址。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final url = viewModel.mockUrl;
    final running = viewModel.isMockRunning;
    final starting = viewModel.isMockStarting;
    final runtimeState = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MonoText(l10n.localRuntime, color: AppColors.textFaint, size: 10),
        const SizedBox(width: 10),
        MonoText(
          running ? l10n.running : l10n.stopped,
          color: running ? AppColors.success : AppColors.textMuted,
          size: 10,
          weight: FontWeight.w700,
        ),
      ],
    );
    // 启动中显示进度并禁用按钮；运行中切换为停止，否则为启动
    final launchButton = FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      onPressed: starting
          ? null
          : () => _showActionFeedback(
              context,
              running
                  ? viewModel.stopMockServer()
                  : viewModel.startMockServer(),
            ),
      icon: Icon(
        running ? Icons.stop_outlined : Icons.play_arrow_outlined,
        size: 16,
      ),
      label: starting
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(running ? l10n.stopServer : l10n.startServer),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 440;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact) ...[
              runtimeState,
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: launchButton),
            ] else
              Row(children: [runtimeState, const Spacer(), launchButton]),
            // 服务运行时展示地址并提供一键复制。
            if (url != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  MethodPill(viewModel.mockDraft!.request.method),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MonoText(url.toString(), color: AppColors.primary),
                  ),
                  DenseIconButton(
                    icon: Icons.copy_outlined,
                    tooltip: l10n.copyMockAddress,
                    onPressed: () => copyToClipboard(
                      context,
                      url.toString(),
                      l10n.mockAddressCopied,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
