part of 'response_panel.dart';

class _GrpcResponsePanel extends StatelessWidget {
  const _GrpcResponsePanel({required this.viewModel, this.title});

  final WorkspaceViewModel viewModel;
  final String? title;

  @override
  /// 构建 gRPC 调用响应面板。
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final call = viewModel.activeGrpcCall;
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(
            title: title ?? l10n.grpcResponseTitle,
            subtitle: call.state.name,
            trailing: call.state.name == 'running'
                ? IconButton(
                    icon: const Icon(Icons.stop_circle_outlined),
                    tooltip: l10n.cancelGrpcCall,
                    onPressed: viewModel.cancelActiveRequest,
                  )
                : null,
          ),
          if (call.omittedEventCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.earlierGrpcEventsOmitted(call.omittedEventCount),
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: call.events.isEmpty
                ? Center(
                    child: Text(
                      call.errorMessage ?? l10n.awaitingGrpcResponse,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: call.events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final event = call.events[index];
                      final decoded = viewModel.decodeActiveGrpcEvent(event);
                      final detail = decoded?.isSuccess == true
                          ? decoded!.formattedJson!
                          : decoded?.error ??
                                event.statusMessage ??
                                (event.metadata.isEmpty
                                    ? l10n.byteCount(event.byteLength)
                                    : event.metadata.entries
                                          .map(
                                            (item) =>
                                                '${item.key}: ${item.value}',
                                          )
                                          .join('\n'));
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMid,
                          border: Border.all(color: AppColors.outline),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MonoText(event.kind.name.toUpperCase(), size: 10),
                            const SizedBox(height: 5),
                            SelectableText(
                              detail,
                              style: TextStyle(
                                color: decoded?.isSuccess == false
                                    ? AppColors.danger
                                    : AppColors.text,
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 响应摘要带：状态、性能指标与结果操作位于同一条稳定的执行信息带中。
class _ResponseSummaryStrip extends StatelessWidget {
  /// 构造响应摘要带。
  const _ResponseSummaryStrip({
    required this.response,
    required this.onCreateMock,
    required this.onCreateDocumentation,
  });

  /// 响应快照数据。
  final ResponseSnapshot response;

  /// 从当前响应创建 Mock 的回调。
  final VoidCallback onCreateMock;

  /// 创建文档草稿的回调。
  final VoidCallback onCreateDocumentation;

  /// 构建摘要带：状态/指标 + 操作按钮，窄屏时自动换行。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusColor = _statusColor(response.statusCode);
    return Container(
      key: const Key('response-summary-strip'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMid,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 440;
          final details = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ResponseStatusReadout(
                statusCode: response.statusCode,
                color: statusColor,
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 26, color: AppColors.outline),
              const SizedBox(width: 12),
              _ResponseMetric(
                icon: Icons.schedule_outlined,
                label: l10n.duration,
                value: '${response.timeMs} ms',
              ),
              const SizedBox(width: 14),
              _ResponseMetric(
                icon: Icons.data_usage_outlined,
                label: l10n.size,
                value: '${response.sizeKb.toStringAsFixed(1)} KB',
              ),
            ],
          );
          final actions = Row(
            key: const Key('response-summary-actions'),
            mainAxisSize: MainAxisSize.min,
            children: [
              DenseIconButton(
                icon: Icons.copy_outlined,
                tooltip: l10n.copyResponseBody,
                onPressed: () => copyToClipboard(
                  context,
                  response.body,
                  l10n.responseBodyCopied,
                ),
                size: 30,
              ),
              DenseIconButton(
                icon: Icons.download_outlined,
                tooltip: l10n.downloadResponseBody,
                onPressed: () => _downloadResponse(context, response.body),
                size: 30,
              ),
              DenseIconButton(
                icon: Icons.article_outlined,
                tooltip: l10n.generateDocumentation,
                onPressed: onCreateDocumentation,
                size: 30,
              ),
              DenseIconButton(
                icon: Icons.dns_outlined,
                tooltip: l10n.createMock,
                onPressed: onCreateMock,
                size: 30,
              ),
            ],
          );
          if (compact) {
            return Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [details, actions],
            );
          }
          return Row(children: [details, const Spacer(), actions]);
        },
      ),
    );
  }

  /// 按状态码映射颜色：4xx/5xx 危险色，3xx 警告色，其余成功色。
  Color _statusColor(int statusCode) => statusCode >= 400
      ? AppColors.danger
      : statusCode >= 300
      ? AppColors.warning
      : AppColors.success;

  /// 将响应体保存为 JSON 文件到系统 Downloads 目录。
  /// 使用时间戳命名以避免覆盖旧文件，失败时向用户展示原因。
  Future<void> _downloadResponse(BuildContext context, String body) async {
    try {
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw const FileSystemException(
          'System Downloads directory is unavailable.',
        );
      }
      await directory.create(recursive: true);
      final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
      final file = File(
        '${directory.path}${Platform.pathSeparator}sendreq-response-$timestamp.json',
      );
      await file.writeAsString(body);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).responseSavedAt(file.path),
            ),
          ),
        );
      }
    } on FileSystemException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).responseSaveFailed(error.message),
            ),
          ),
        );
      }
    }
  }
}

/// 响应状态读数：状态码 + HTTP 徽标，按状态色展示。
class _ResponseStatusReadout extends StatelessWidget {
  /// 构造状态读数。
  const _ResponseStatusReadout({required this.statusCode, required this.color});

  /// 响应状态码。
  final int statusCode;

  /// 状态展示色（由摘要带统一计算传入）。
  final Color color;

  /// 构建状态读数徽标。
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('response-status-readout'),
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      border: Border.all(color: color.withValues(alpha: 0.52)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        MonoText(
          '$statusCode',
          color: color,
          size: 14,
          weight: FontWeight.w700,
        ),
        const SizedBox(width: 6),
        MonoText('HTTP', color: color, size: 10, weight: FontWeight.w700),
      ],
    ),
  );
}

/// 单项「图标 + 标签 + 数值」指标，便于在响应摘要中快速横向扫描。
class _ResponseMetric extends StatelessWidget {
  /// 构造单项指标。
  const _ResponseMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  /// 指标图标。
  final IconData icon;

  /// 指标标签（小号大写）。
  final String label;

  /// 指标数值。
  final String value;

  /// 构建单项指标行。
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: AppColors.textFaint),
      const SizedBox(width: 5),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MonoText(label.toUpperCase(), color: AppColors.textFaint, size: 9),
          const SizedBox(height: 1),
          MonoText(value, color: AppColors.text, size: 11),
        ],
      ),
    ],
  );
}
