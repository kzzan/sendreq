import 'package:flutter/material.dart';

import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/l10n/workspace_message_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';

class ResponseHeaderTable extends StatelessWidget {
  /// 构造响应头表格。
  const ResponseHeaderTable({super.key, required this.response});

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
              color: context.chakra.bgEmphasized,
              border: Border(bottom: BorderSide(color: context.chakra.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: MonoText(
                    l10n.key.toUpperCase(),
                    color: context.chakra.fgSubtle,
                    size: 10,
                    weight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: MonoText(
                    l10n.value.toUpperCase(),
                    color: context.chakra.fgSubtle,
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
                        color: context.chakra.fgMuted,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: response.headers.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: context.chakra.border),
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
                                  color: context.chakra.fg,
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
                                  color: context.chakra.fgMuted,
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

/// 空响应占位状态：无响应时引导发送当前 Request。
class ResponseAwaitingState extends StatelessWidget {
  /// 构造空响应占位状态。
  const ResponseAwaitingState({
    super.key,
    required this.onSend,
    this.sendUnavailableReason,
  });

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
                color: context.chakra.colorPaletteFg.withValues(alpha: 0.12),
                border: Border.all(
                  color: context.chakra.colorPaletteFg.withValues(alpha: 0.48),
                ),
                borderRadius: ChakraRadii.panel,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 26,
                color: context.chakra.colorPaletteFg,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noResponseYet,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.responseAwaitingDescription,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.chakra.fgMuted, fontSize: 12),
            ),
            if (onSend != null) ...[
              const SizedBox(height: 14),
              Tooltip(
                key: ValueKey('response-send-tooltip-$sendUnavailableReason'),
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

/// 发送进行中状态：进度指示、请求与环境信息以及取消按钮。
class ResponseSendingState extends StatelessWidget {
  /// 构造发送中状态。
  const ResponseSendingState({
    super.key,
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
            style: TextStyle(color: context.chakra.fgMuted, fontSize: 12),
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
class ResponseErrorState extends StatelessWidget {
  /// 构造执行错误状态。
  const ResponseErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.onEditRequest,
  });

  /// 错误消息（本地化前原文）。
  final String message;

  /// 重试回调；为 null 时隐藏重试按钮。
  final Future<void> Function()? onRetry;

  /// 返回请求编辑器回调；为 null 时隐藏入口。
  final VoidCallback? onEditRequest;

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
            style: TextStyle(color: context.chakra.error),
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
