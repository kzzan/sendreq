import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/workspace_models.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../workspace/models/workspace_shell_models.dart';
import '../../workspace/view_models/workspace_view_model.dart';
import '../../../core/widgets/dense_controls.dart';
import 'openapi_export_actions.dart';
import 'openapi_import_actions.dart';

/// 仪表盘面板：集中展示工作区执行指标、请求量趋势、环境健康状态与最近请求快照。
class DashboardPanel extends StatelessWidget {
  /// 构造仪表盘面板。
  const DashboardPanel({
    super.key,
    required this.viewModel,
    this.compact = false,
  });

  /// 工作区视图模型，提供指标、历史与环境等数据。
  final WorkspaceViewModel viewModel;

  /// 是否以紧凑模式渲染（仅显示执行历史，用于窄面板）。
  final bool compact;

  /// 构建仪表盘：紧凑模式仅显示执行历史，完整模式展示指标与图表。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 紧凑模式：仅展示执行历史列表，隐藏指标与图表。
    if (compact) {
      return Container(
        color: AppColors.background,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PanelTitle(
              title: l10n.executionHistory,
              subtitle: l10n.latestRequestSnapshots,
            ),
            const SizedBox(height: 10),
            Expanded(child: _HistoryList(viewModel: viewModel)),
          ],
        ),
      );
    }

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(
            title: l10n.dashboard,
            subtitle: l10n.dashboardForEnvironment(
              viewModel.activeEnvironment.name,
            ),
            trailing: FilledButton.icon(
              onPressed: viewModel.createRequest,
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.newRequest),
            ),
          ),
          const SizedBox(height: 10),
          _MetricsStrip(metrics: viewModel.metrics),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 宽度 ≥ 920 时显示右侧栏（环境健康 + 快速开始），否则上下堆叠。
                final showSideRail = constraints.maxWidth >= 920;
                final main = Column(
                  children: [
                    SizedBox(
                      height: 208,
                      child: _RequestVolumePanel(viewModel: viewModel),
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: _HistoryList(viewModel: viewModel)),
                  ],
                );
                // 窄屏下退回上下布局，避免侧栏挤压主内容。
                if (!showSideRail) return main;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: main),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: WorkspacePaneWidths.secondary,
                      child: Column(
                        children: [
                          _EnvironmentHealth(viewModel: viewModel),
                          const SizedBox(height: 10),
                          _QuickStart(viewModel: viewModel),
                        ],
                      ),
                    ),
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

/// 仪表盘指标区：宽屏横排，较窄窗口自动折为两列，避免信息卡被压扁。
class _MetricsStrip extends StatelessWidget {
  const _MetricsStrip({required this.metrics});

  final List<MetricSummary> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 760 ? metrics.length : 2;
      final rows = (metrics.length / columns).ceil();
      return SizedBox(
        height: rows * 94.0 + (rows - 1) * 8,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: 94,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return _MetricCard(
              label: metric.label,
              value: metric.value,
              delta: metric.delta,
            );
          },
        ),
      );
    },
  );
}

/// 单个指标卡片：展示标签、当前数值与相比上期的增量。
class _MetricCard extends StatelessWidget {
  /// 构造指标卡片。
  const _MetricCard({
    required this.label,
    required this.value,
    required this.delta,
  });

  /// 指标名称（如“请求数”），以大写等宽字体显示。
  final String label;

  /// 指标当前数值。
  final String value;

  /// 指标增量描述，如“+12%”。
  final String delta;

  /// 构建指标卡片：标签、数值与增量。
  @override
  Widget build(BuildContext context) => DensePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoText(label.toUpperCase(), color: AppColors.textFaint, size: 10),
        const Spacer(),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        MonoText(delta, color: AppColors.success, size: 11),
      ],
    ),
  );
}

/// 请求量趋势面板：按时间范围（1H/24H/7D）绘制请求量折线图。
class _RequestVolumePanel extends StatelessWidget {
  /// 构造请求量趋势面板。
  const _RequestVolumePanel({required this.viewModel});

  /// 工作区视图模型，提供当前选中的时间范围。
  final WorkspaceViewModel viewModel;

  /// 构建请求量趋势面板：标题、时间范围切换与折线图。
  @override
  Widget build(BuildContext context) => DensePanel(
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.query_stats_outlined,
              color: AppColors.warning,
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              AppLocalizations.of(context).requestVolume,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            // 时间范围切换按钮组：选中项高亮并更新图表数据。
            for (final range in const ['1H', '24H', '7D'])
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: _RangeButton(
                  label: range,
                  selected: viewModel.dashboardRange == range,
                  onTap: () => viewModel.selectDashboardRange(range),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: CustomPaint(
            painter: _VolumeTracePainter(_pointsFor(viewModel.dashboardRange)),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    ),
  );

  /// 返回所选时间范围的采样点（高度归一化为 0~1），用于绘制折线图。
  /// 当前为演示数据，后续可替换为真实的请求量统计。
  List<double> _pointsFor(String range) => switch (range) {
    '1H' => const [0.28, 0.44, 0.39, 0.72, 0.56, 0.76, 0.64, 0.86],
    '7D' => const [0.34, 0.48, 0.41, 0.62, 0.58, 0.76, 0.53, 0.82],
    _ => const [0.22, 0.36, 0.55, 0.43, 0.78, 0.46, 0.68, 0.84],
  };
}

/// 时间范围切换按钮：选中态使用主题色高亮边框与文字。
class _RangeButton extends StatelessWidget {
  /// 构造时间范围切换按钮。
  const _RangeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// 按钮文本，如“1H”。
  final String label;

  /// 是否为当前选中的时间范围。
  final bool selected;

  /// 点击回调。
  final VoidCallback onTap;

  /// 构建时间范围切换按钮。
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(3),
    child: Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.surfaceHighest : AppColors.surfaceHigh,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.outline,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: MonoText(
        label,
        color: selected ? AppColors.primary : AppColors.textMuted,
        size: 10,
      ),
    ),
  );
}

/// 请求量折线图的画笔：负责绘制网格、面积填充、折线与采样点标记。
class _VolumeTracePainter extends CustomPainter {
  /// 以归一化采样点列表构造画笔。
  const _VolumeTracePainter(this.points);

  /// 归一化（0~1）的采样点列表。
  final List<double> points;

  @override
  /// 绘制过程：先画水平网格，再依次绘制面积、折线与数据点。
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.outline.withValues(alpha: 0.38)
      ..strokeWidth = 1;
    // 绘制 4 条水平网格线，将图表高度三等分。
    for (var index = 0; index < 4; index++) {
      final y = size.height * index / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    // 依据采样点构建折线路径：首点使用 moveTo，其余使用 lineTo。
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final x = size.width * index / (points.length - 1);
      final y = size.height * (1 - points[index]);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    // 将折线闭合到图表底部，形成面积填充区域。
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()..color = AppColors.primary.withValues(alpha: 0.12),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke,
    );
    // 在每个采样点绘制圆点标记，便于定位数值位置。
    final marker = Paint()..color = AppColors.warning;
    for (var index = 0; index < points.length; index++) {
      final x = size.width * index / (points.length - 1);
      final y = size.height * (1 - points[index]);
      canvas.drawCircle(Offset(x, y), 2.5, marker);
    }
  }

  @override
  /// 仅当采样点数据发生变化时才触发重绘。
  bool shouldRepaint(covariant _VolumeTracePainter oldDelegate) =>
      oldDelegate.points != points;
}

/// 环境健康状态列表：为每个环境显示状态点，并标出当前激活的环境。
class _EnvironmentHealth extends StatelessWidget {
  /// 构造环境健康状态列表。
  const _EnvironmentHealth({required this.viewModel});

  /// 工作区视图模型，提供环境列表与当前激活环境。
  final WorkspaceViewModel viewModel;

  /// 构建环境健康状态列表。
  @override
  Widget build(BuildContext context) => Expanded(
    child: DensePanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Text(
              AppLocalizations.of(context).environmentHealth,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final environment in viewModel.environments)
            _HealthRow(
              name: environment.name,
              active: environment.id == viewModel.activeEnvironment.id,
            ),
        ],
      ),
    ),
  );
}

/// 单条环境健康行：状态圆点 + 环境名称 + 运行状态文本。
class _HealthRow extends StatelessWidget {
  /// 构造单条环境健康行。
  const _HealthRow({required this.name, required this.active});

  /// 环境名称。
  final String name;

  /// 是否为当前激活环境。
  final bool active;

  /// 构建单条环境健康行：状态圆点、名称与状态文本。
  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.outline)),
    ),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.success : AppColors.textFaint,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
        MonoText(
          active
              ? AppLocalizations.of(context).active
              : AppLocalizations.of(context).ready,
          color: active ? AppColors.success : AppColors.textFaint,
          size: 10,
        ),
      ],
    ),
  );
}

/// 快速开始面板：提供新建请求、新建集合与导入 OpenAPI 的快捷入口。
class _QuickStart extends StatelessWidget {
  /// 构造快速开始面板。
  const _QuickStart({required this.viewModel});

  /// 工作区视图模型，提供创建请求/集合及导入能力。
  final WorkspaceViewModel viewModel;

  /// 构建快速开始面板：快捷操作按钮组。
  @override
  Widget build(BuildContext context) => DensePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).quickStart,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          AppLocalizations.of(context).quickStartDescription,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: viewModel.createRequest,
            icon: const Icon(Icons.add, size: 16),
            label: Text(AppLocalizations.of(context).newRequest),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: viewModel.createCollection,
            icon: const Icon(Icons.create_new_folder_outlined, size: 16),
            label: Text(AppLocalizations.of(context).newCollection),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => showOpenApiImportDialog(context, viewModel),
            icon: const Icon(Icons.file_upload_outlined, size: 16),
            label: Text(AppLocalizations.of(context).importOpenApi),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => exportOpenApiToFile(context, viewModel),
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: Text(AppLocalizations.of(context).exportOpenApi),
          ),
        ),
      ],
    ),
  );
}

/// 执行历史列表：表头 + 每条请求记录（方法/路径/状态/耗时/时间）。
class _HistoryList extends StatelessWidget {
  /// 构造执行历史列表。
  const _HistoryList({required this.viewModel});

  /// 工作区视图模型，提供执行历史数据。
  final WorkspaceViewModel viewModel;

  /// 构建执行历史列表：表头与每条请求记录。
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final showDuration = constraints.maxWidth >= 520;
      final showWhen = constraints.maxWidth >= 650;
      return DensePanel(
        padding: EdgeInsets.zero,
        child: ListView(
          children: [
            Container(
              height: 30,
              color: AppColors.surfaceHigh,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: MonoText(
                      AppLocalizations.of(context).method.toUpperCase(),
                      color: AppColors.textFaint,
                      size: 10,
                    ),
                  ),
                  Expanded(
                    child: MonoText(
                      AppLocalizations.of(context).path.toUpperCase(),
                      color: AppColors.textFaint,
                      size: 10,
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: MonoText(
                      AppLocalizations.of(context).status.toUpperCase(),
                      color: AppColors.textFaint,
                      size: 10,
                    ),
                  ),
                  if (showDuration)
                    SizedBox(
                      width: 72,
                      child: MonoText(
                        AppLocalizations.of(context).duration.toUpperCase(),
                        color: AppColors.textFaint,
                        size: 10,
                      ),
                    ),
                  if (showWhen)
                    SizedBox(
                      width: 86,
                      child: MonoText(
                        AppLocalizations.of(context).when.toUpperCase(),
                        color: AppColors.textFaint,
                        size: 10,
                      ),
                    ),
                ],
              ),
            ),
            for (final item in viewModel.history)
              Tooltip(
                // 仅带快照的记录可点击打开，旧记录禁用并给出提示。
                message: item.hasSnapshot
                    ? AppLocalizations.of(context).openExecutionSnapshot
                    : AppLocalizations.of(context).legacyExecutionNoSnapshot,
                child: InkWell(
                  key: item.id.isEmpty ? null : Key('history-entry-${item.id}'),
                  onTap: item.hasSnapshot
                      ? () => viewModel.openHistoryRecord(item.id)
                      : null,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.outline)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 76,
                          child: RequestKindPill(
                            protocol: item.protocol,
                            method: item.method,
                          ),
                        ),
                        Expanded(
                          child: MonoText(item.path, color: AppColors.text),
                        ),
                        SizedBox(
                          width: 70,
                          child: item.status == null
                              ? _ErrorPill(item.errorCategory ?? 'error')
                              : StatusPill(item.status!),
                        ),
                        if (showDuration)
                          SizedBox(
                            width: 72,
                            child: MonoText(
                              '${item.timeMs} ms',
                              color: AppColors.textMuted,
                            ),
                          ),
                        if (showWhen)
                          SizedBox(
                            width: 86,
                            child: MonoText(
                              item.when,
                              color: AppColors.textFaint,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// 请求失败标签：以危险色高亮展示错误分类。
class _ErrorPill extends StatelessWidget {
  /// 以错误分类名称构造失败标签。
  const _ErrorPill(this.category);

  /// 错误分类名称。
  final String category;

  /// 构建请求失败标签。
  @override
  Widget build(BuildContext context) => Container(
    height: 24,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.danger.withValues(alpha: 0.12),
      border: Border.all(color: AppColors.danger.withValues(alpha: 0.55)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: MonoText(
      category.toUpperCase(),
      color: AppColors.danger,
      size: 10,
      weight: FontWeight.w700,
    ),
  );
}
