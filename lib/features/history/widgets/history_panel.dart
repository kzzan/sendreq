import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/workspace_models.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../workspace/models/workspace_shell_models.dart';
import '../../workspace/view_models/workspace_view_model.dart';
import '../../../core/widgets/dense_controls.dart';
import '../../response_viewer/widgets/response_panel.dart';

/// 历史记录工作台：左侧负责定位一次执行，右侧展示不可变的执行快照。
class HistoryPanel extends StatefulWidget {
  /// 构造历史记录工作台。
  const HistoryPanel({super.key, required this.viewModel});

  /// 工作区视图模型，提供历史记录数据。
  final WorkspaceViewModel viewModel;

  /// 创建历史面板状态。
  @override
  State<HistoryPanel> createState() => _HistoryPanelState();
}

/// 历史面板状态：维护搜索关键字、筛选条件与记录可见性计算。
class _HistoryPanelState extends State<HistoryPanel> {
  /// 搜索关键字。
  var _query = '';

  /// 当前筛选条件。
  var _filter = _HistoryFilter.all;

  /// 依据筛选条件与搜索关键字过滤出的可见记录。
  List<ExecutionRecord> get _visibleRecords => widget.viewModel.history
      .where((record) {
        if (!_filter.includes(record)) return false;
        // 关键字命中方法/路径/状态/错误/时间任一字段即保留
        final query = _query.trim().toLowerCase();
        if (query.isEmpty) return true;
        return [
          record.method,
          record.path,
          record.status?.toString() ?? '',
          record.errorCategory ?? '',
          record.errorMessage ?? '',
          record.webSocketSummary?.terminalStatus ?? '',
          record.webSocketSummary?.endpoint ?? '',
          record.when,
        ].any((value) => value.toLowerCase().contains(query));
      })
      .toList(growable: false);

  /// 更新搜索关键字并重建界面。
  void _updateQuery(String value) {
    setState(() => _query = value);
  }

  /// 切换筛选条件；当前打开记录不在结果中时自动打开首个带快照的记录。
  void _selectFilter(_HistoryFilter value) {
    setState(() => _filter = value);
    final selected = widget.viewModel.openedHistoryRecord;
    final visible = _visibleRecords;
    // 当前打开记录仍在过滤结果中时保持原选择
    if (selected != null && visible.any((record) => record.id == selected.id)) {
      return;
    }
    final next = visible.where((record) => record.hasSnapshot).firstOrNull;
    if (next != null) widget.viewModel.openHistoryRecord(next.id);
  }

  /// 二次确认后清空全部历史记录并提示。
  Future<void> _confirmClearHistory() async {
    if (widget.viewModel.history.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.clearHistoryTitle),
          content: Text(l10n.clearHistoryMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.clearHistory),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    widget.viewModel.clearHistory();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).historyCleared)),
    );
  }

  /// 构建历史工作台：页头 + 时间线与详情快照。
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          _HistoryPageHeader(
            viewModel: widget.viewModel,
            onClearHistory: _confirmClearHistory,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isStacked = constraints.maxWidth < 920;
                final timeline = _HistoryTimeline(
                  viewModel: widget.viewModel,
                  records: _visibleRecords,
                  query: _query,
                  filter: _filter,
                  onQueryChanged: _updateQuery,
                  onFilterChanged: _selectFilter,
                );
                final details = ResponsePanel(
                  viewModel: widget.viewModel,
                  titleOverride: AppLocalizations.of(
                    context,
                  ).historyExecutionDetail,
                );
                if (isStacked) {
                  // 窄屏上下堆叠：时间线取高度 42%，并限制在 240~330 之间
                  final timelineHeight = (constraints.maxHeight * 0.42)
                      .clamp(240.0, 330.0)
                      .toDouble();
                  return Column(
                    children: [
                      SizedBox(height: timelineHeight, child: timeline),
                      Divider(height: 1, color: AppColors.outline),
                      Expanded(child: details),
                    ],
                  );
                }
                return Row(
                  children: [
                    SizedBox(
                      width: WorkspacePaneWidths.secondary,
                      child: timeline,
                    ),
                    VerticalDivider(width: 1, color: AppColors.outline),
                    Expanded(child: details),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 历史记录的筛选条件：全部 / 成功 / 失败。
enum _HistoryFilter {
  all,
  success,
  failed;

  /// 判断给定记录是否属于当前筛选范围。
  bool includes(ExecutionRecord record) {
    final summary = record.webSocketSummary;
    if (summary != null) {
      return switch (this) {
        _HistoryFilter.all => true,
        _HistoryFilter.success => summary.terminalStatus != 'error',
        _HistoryFilter.failed => summary.terminalStatus == 'error',
      };
    }
    return switch (this) {
      _HistoryFilter.all => true,
      _HistoryFilter.success => record.status != null && record.status! < 400,
      _HistoryFilter.failed => record.status == null || record.status! >= 400,
    };
  }
}

/// 顶部上下文带：明确当前查看的执行与问题量，避免详情脱离列表语境。
class _HistoryPageHeader extends StatelessWidget {
  /// 构造历史页头部。
  const _HistoryPageHeader({
    required this.viewModel,
    required this.onClearHistory,
  });

  /// 工作区视图模型，提供当前打开记录与统计。
  final WorkspaceViewModel viewModel;

  /// 清空历史回调；无记录时为 null 禁用。
  final VoidCallback? onClearHistory;

  /// 构建历史页头部：当前执行、统计与清空入口。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = viewModel.openedHistoryRecord;
    final total = viewModel.history.length;
    final failed = viewModel.history
        .where(_HistoryFilter.failed.includes)
        .length;
    final heading = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.history, size: 15, color: AppColors.primary),
            ),
            const SizedBox(width: 9),
            Text(
              l10n.history,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.only(left: 34),
          child: current == null
              ? MonoText(
                  l10n.historyExecutionCount(total),
                  color: AppColors.textMuted,
                  size: 10,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RequestKindPill(
                      protocol: current.protocol,
                      method: current.method,
                      width: 76,
                      height: 18,
                      fontSize: 9,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: MonoText(
                        current.path,
                        color: AppColors.textMuted,
                        size: 10,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
    final statistics = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HistoryStatistic(
          label: l10n.historyTotal,
          value: '$total',
          color: AppColors.primary,
        ),
        Container(width: 1, height: 28, color: AppColors.outline),
        _HistoryStatistic(
          label: l10n.historyFailed,
          value: '$failed',
          color: failed == 0 ? AppColors.success : AppColors.danger,
        ),
        const SizedBox(width: 6),
        DenseIconButton(
          icon: Icons.delete_outline,
          tooltip: l10n.clearHistory,
          onPressed: total == 0 ? null : onClearHistory,
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
        builder: (context, constraints) => constraints.maxWidth < 620
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading,
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerRight, child: statistics),
                ],
              )
            : Row(
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 12),
                  statistics,
                ],
              ),
      ),
    );
  }
}

/// 单个历史统计数字：标签 + 数值。
class _HistoryStatistic extends StatelessWidget {
  /// 构造统计数字。
  const _HistoryStatistic({
    required this.label,
    required this.value,
    required this.color,
  });

  /// 统计项标签。
  final String label;

  /// 统计数值。
  final String value;

  /// 数值颜色（如失败数非零时用危险色）。
  final Color color;

  /// 构建统计数字。
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 54,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MonoText(label.toUpperCase(), color: AppColors.textFaint, size: 9),
        const SizedBox(height: 2),
        MonoText(value, color: color, size: 13, weight: FontWeight.w700),
      ],
    ),
  );
}

/// 历史时间线列表：搜索框、筛选控件与记录列表。
class _HistoryTimeline extends StatelessWidget {
  /// 构造历史时间线，并绑定搜索与筛选回调。
  const _HistoryTimeline({
    required this.viewModel,
    required this.records,
    required this.query,
    required this.filter,
    required this.onQueryChanged,
    required this.onFilterChanged,
  });

  /// 工作区视图模型，提供历史数据。
  final WorkspaceViewModel viewModel;

  /// 当前可见的记录列表。
  final List<ExecutionRecord> records;

  /// 当前搜索关键字。
  final String query;

  /// 当前筛选条件。
  final _HistoryFilter filter;

  /// 搜索关键字变更回调。
  final ValueChanged<String> onQueryChanged;

  /// 筛选条件变更回调。
  final ValueChanged<_HistoryFilter> onFilterChanged;

  /// 构建历史时间线：搜索、筛选与记录列表。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final allRecords = viewModel.history;
    return Container(
      color: AppColors.surfaceLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HistoryTimelineHeader(total: allRecords.length),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              key: const Key('history-search-input'),
              onChanged: onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: Icon(
                  Icons.search,
                  size: 17,
                  color: AppColors.textFaint,
                ),
                hintText: l10n.searchHistory,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: _HistoryFilterControl(
              selected: filter,
              onSelected: onFilterChanged,
            ),
          ),
          Container(height: 1, color: AppColors.outline),
          Expanded(
            child: records.isEmpty
                ? _HistoryEmptyState(hasQuery: query.trim().isNotEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: records.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 12,
                      endIndent: 12,
                      color: AppColors.outline.withValues(alpha: 0.72),
                    ),
                    itemBuilder: (context, index) => _HistoryRecordRow(
                      record: records[index],
                      selected:
                          records[index].id ==
                          viewModel.openedHistoryRecord?.id,
                      onTap: records[index].hasSnapshot
                          ? () => viewModel.openHistoryRecord(records[index].id)
                          : null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 时间线标题栏：显示标题与记录总数。
class _HistoryTimelineHeader extends StatelessWidget {
  /// 构造时间线标题栏。
  const _HistoryTimelineHeader({required this.total});

  /// 记录总数。
  final int total;

  /// 构建时间线标题栏。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.historyTimeline,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  MonoText(
                    l10n.historyExecutionCount(total),
                    color: AppColors.textFaint,
                    size: 10,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 历史筛选控件：全部 / 成功 / 失败分段按钮。
class _HistoryFilterControl extends StatelessWidget {
  /// 构造筛选控件。
  const _HistoryFilterControl({
    required this.selected,
    required this.onSelected,
  });

  /// 当前选中的筛选条件。
  final _HistoryFilter selected;

  /// 筛选条件变更回调。
  final ValueChanged<_HistoryFilter> onSelected;

  /// 构建筛选控件。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<_HistoryFilter>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: _HistoryFilter.all, label: Text(l10n.historyAll)),
        ButtonSegment(
          value: _HistoryFilter.success,
          label: Text(l10n.historySuccess),
        ),
        ButtonSegment(
          value: _HistoryFilter.failed,
          label: Text(l10n.historyFailed),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (selection) => onSelected(selection.single),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.labelSmall,
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}

/// 单条历史记录行：方法/路径/状态/耗时与快照入口。
class _HistoryRecordRow extends StatelessWidget {
  /// 构造历史记录行。
  const _HistoryRecordRow({
    required this.record,
    required this.selected,
    required this.onTap,
  });

  /// 当前渲染的执行记录。
  final ExecutionRecord record;

  /// 是否选中（当前打开的快照）。
  final bool selected;

  /// 单击打开快照回调；无快照的记录为 null。
  final VoidCallback? onTap;

  /// 是否属于失败记录（HTTP 无状态码或 >= 400；WebSocket 以终止状态判断）。
  bool get _isFailure =>
      record.webSocketSummary?.terminalStatus == 'error' ||
      (record.webSocketSummary == null &&
          (record.status == null || record.status! >= 400));

  /// 构建历史记录行。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = record.webSocketSummary;
    final stateColor = _isFailure ? AppColors.danger : AppColors.success;
    final label =
        summary?.terminalStatus ??
        record.status?.toString() ??
        l10n.historyFailed;
    final detail = summary == null
        ? (_isFailure
              ? record.errorCategory?.toUpperCase() ?? 'HTTP $label'
              : '${record.when}  ·  ${record.timeMs} ms')
        : _isFailure
        ? summary.errorMessage ?? 'WebSocket error'
        : '${record.when}  ·  ${record.timeMs} ms  ·  '
              '${summary.outboundMessageCount} sent / '
              '${summary.inboundMessageCount} received';
    return Tooltip(
      message: summary != null
          ? 'WebSocket session summary'
          : record.hasSnapshot
          ? l10n.openExecutionSnapshot
          : l10n.legacyExecutionNoSnapshot,
      child: InkWell(
        key: record.id.isEmpty ? null : Key('history-entry-${record.id}'),
        onTap: onTap,
        hoverColor: AppColors.surfaceHigh,
        focusColor: AppColors.surfaceHigh,
        child: Opacity(
          opacity: record.hasSnapshot || summary != null ? 1 : 0.58,
          child: Container(
            height: 70,
            padding: const EdgeInsets.only(left: 12, right: 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                RequestKindPill(
                  protocol: record.protocol,
                  method: record.method,
                  width: 76,
                  height: 20,
                  fontSize: 10,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonoText(record.path, color: AppColors.text, size: 11),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            _isFailure
                                ? Icons.error_outline
                                : Icons.schedule_outlined,
                            size: 12,
                            color: _isFailure
                                ? stateColor
                                : AppColors.textFaint,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: MonoText(
                              detail,
                              color: _isFailure
                                  ? stateColor
                                  : AppColors.textFaint,
                              size: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      height: 20,
                      constraints: const BoxConstraints(minWidth: 34),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: stateColor.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: MonoText(
                        label.toUpperCase(),
                        color: stateColor,
                        size: 10,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Icon(
                      record.hasSnapshot
                          ? Icons.chevron_right
                          : summary != null
                          ? Icons.forum_outlined
                          : Icons.inventory_2_outlined,
                      size: 15,
                      color: record.hasSnapshot || summary != null
                          ? AppColors.textMuted
                          : AppColors.textFaint,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 历史列表空态：区分“无记录”与“搜索无结果”。
class _HistoryEmptyState extends StatelessWidget {
  /// 构造历史空态。
  const _HistoryEmptyState({required this.hasQuery});

  /// 是否因搜索关键字无结果而显示空态。
  final bool hasQuery;

  /// 构建历史空态提示。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.manage_search_outlined,
            color: AppColors.textFaint,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            hasQuery ? l10n.historyNoSearchResults : l10n.historyEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
