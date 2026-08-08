part of 'response_panel.dart';

class _HeaderTable extends StatelessWidget {
  /// 构造响应头表格。
  const _HeaderTable({required this.response});

  /// 响应快照，提供响应头列表。
  final ResponseSnapshot response;

  /// 构建表格：表头行 + 键/值列表，无响应头时展示空态。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DensePanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              border: Border(bottom: BorderSide(color: AppColors.outline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: MonoText(
                    l10n.key.toUpperCase(),
                    color: AppColors.textFaint,
                    size: 10,
                    weight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: MonoText(
                    l10n.value.toUpperCase(),
                    color: AppColors.textFaint,
                    size: 10,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: response.headers.isEmpty
                ? Center(
                    child: Text(
                      l10n.empty,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: response.headers.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: AppColors.outline),
                    itemBuilder: (context, index) {
                      final header = response.headers[index];
                      return Container(
                        constraints: const BoxConstraints(minHeight: 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SelectableText(
                                header.keyName,
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: SelectableText(
                                header.value,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 12,
                                  height: 1.4,
                                ),
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

/// 空响应占位状态：无响应时引导发送请求；
/// 历史快照模式下则展示执行时的请求摘要（图标、方法与 URL）。
class _AwaitingState extends StatelessWidget {
  /// 构造空响应占位状态。
  const _AwaitingState({
    this.snapshot,
    required this.onSend,
    this.sendUnavailableReason,
  });

  /// 执行时的请求快照；为 null 表示普通等待状态。
  final ExecutionRequestSnapshot? snapshot;

  /// 发送回调；为 null 时不展示发送按钮。
  final VoidCallback? onSend;

  /// 发送不可用时的原因文案。
  final String? sendUnavailableReason;

  /// 构建占位：图标、标题、摘要与可选的发送按钮。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DensePanel(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.48),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              // 无响应时为「播放」图标，历史快照下则为「记录归档」图标。
              child: Icon(
                snapshot == null
                    ? Icons.play_arrow_rounded
                    : Icons.inventory_2_outlined,
                size: 26,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              snapshot == null ? l10n.noResponseYet : l10n.noResponseBody,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              // 历史快照下展示「方法 + 解析后 URL」，让用户回顾请求去向。
              snapshot == null
                  ? l10n.responseAwaitingDescription
                  : '${_snapshotTypeLabel(snapshot!)} ${snapshot!.resolvedUrl}',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            if (snapshot == null && onSend != null) ...[
              const SizedBox(height: 14),
              Tooltip(
                message:
                    sendUnavailableReason.localized(l10n) ??
                    l10n.sendActiveRequest,
                child: FilledButton.icon(
                  onPressed: onSend,
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: Text(l10n.sendRequest),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 历史请求快照块：展示执行当时的方法、解析后 URL、环境以及请求头/体，
/// 秘密请求头（secret）以警示色呈现。
class _RequestSnapshotBlock extends StatelessWidget {
  /// 构造历史请求快照块。
  const _RequestSnapshotBlock({required this.snapshot});

  /// 执行时保存的请求快照。
  final ExecutionRequestSnapshot snapshot;

  /// 构建快照块：方法/URL、环境、请求头与请求体。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DensePanel(
      padding: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          MonoText(
            l10n.requestAtExecution,
            color: AppColors.textFaint,
            size: 10,
          ),
          const SizedBox(height: 6),
          MonoText(
            '${_snapshotTypeLabel(snapshot)} ${snapshot.resolvedUrl}',
            color: AppColors.text,
          ),
          const SizedBox(height: 4),
          MonoText(
            l10n.environmentValue(snapshot.environmentName),
            color: AppColors.primary,
            size: 11,
          ),
          const SizedBox(height: 16),
          MonoText(l10n.requestHeaders, color: AppColors.textFaint, size: 10),
          const SizedBox(height: 6),
          for (final header in snapshot.headers)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: MonoText(
                '${header.keyName}: ${header.value}',
                color: header.secret ? AppColors.warning : AppColors.textMuted,
              ),
            ),
          const SizedBox(height: 12),
          MonoText(l10n.requestBody, color: AppColors.textFaint, size: 10),
          const SizedBox(height: 6),
          MonoText(
            snapshot.body.isEmpty ? l10n.empty : snapshot.body,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

/// 根据快照协议返回类型标签；HTTP 使用其方法名。
String _snapshotTypeLabel(ExecutionRequestSnapshot snapshot) =>
    switch (snapshot.protocol) {
      ApiRequestProtocol.http => snapshot.method,
      ApiRequestProtocol.webSocket => 'WebSocket',
      ApiRequestProtocol.grpc => 'gRPC',
    };

/// 发送进行中状态：进度指示、请求与环境信息以及取消按钮。
class _SendingState extends StatelessWidget {
  /// 构造发送中状态。
  const _SendingState({
    required this.requestName,
    required this.environmentName,
    required this.onCancel,
  });

  /// 正在发送的请求名称。
  final String requestName;

  /// 当前使用的环境名称。
  final String environmentName;

  /// 点击取消发送的回调。
  final VoidCallback onCancel;

  /// 构建发送中视图：进度指示 + 请求/环境信息 + 取消按钮。
  @override
  Widget build(BuildContext context) => DensePanel(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).sendingRequest(requestName),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).usingEnvironment(environmentName),
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onCancel,
            child: Text(AppLocalizations.of(context).cancelSend),
          ),
        ],
      ),
    ),
  );
}

/// 执行错误状态：展示错误消息并支持复制、重试与返回请求编辑器。
/// 历史记录模式下列出「原请求已删除」提示，并禁用相关操作。
class _ErrorState extends StatelessWidget {
  /// 构造执行错误状态。
  const _ErrorState({
    required this.message,
    this.onRetry,
    this.onEditRequest,
    this.unavailableRequestMessage,
  });

  /// 错误消息（本地化前原文）。
  final String message;

  /// 重试回调；为 null 时隐藏重试按钮。
  final Future<void> Function()? onRetry;

  /// 返回请求编辑器回调；为 null 时隐藏入口。
  final VoidCallback? onEditRequest;

  /// 原请求不可用时的提示文案。
  final String? unavailableRequestMessage;

  /// 构建错误视图：错误消息 + 复制/重试/返回操作。
  @override
  Widget build(BuildContext context) => DensePanel(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.localized(AppLocalizations.of(context))!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.danger),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => copyToClipboard(
              context,
              message,
              AppLocalizations.of(context).errorDetailsCopied,
            ),
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: Text(AppLocalizations.of(context).copyErrorDetails),
          ),
          if (onRetry != null || onEditRequest != null)
            const SizedBox(height: 8),
          if (unavailableRequestMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                unavailableRequestMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          if (onRetry != null)
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(AppLocalizations.of(context).retry),
            ),
          if (onEditRequest != null)
            OutlinedButton.icon(
              onPressed: onEditRequest,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(AppLocalizations.of(context).returnToRequestEditor),
            ),
        ],
      ),
    ),
  );
}
