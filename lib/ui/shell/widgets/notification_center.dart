import 'package:flutter/material.dart';

import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/domain/module_boundaries/boundary_models.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/l10n/workspace_message_localizations.dart';
import 'package:sendreq/ui/shell/application/user_notice.dart';

/// 通知中心展示 Shell 已准入的安全记录，不拥有底层业务状态。
class NotificationCenter extends StatelessWidget {
  const NotificationCenter({
    super.key,
    required this.notices,
    required this.acknowledge,
    required this.recover,
    required this.clearAll,
  });

  final List<UserNotice> notices;
  final Future<void> Function(String deduplicationKey) acknowledge;
  final Future<void> Function(UserNotice notice) recover;
  final Future<bool> Function() clearAll;

  Future<void> _clearNotifications(BuildContext context) async {
    if (notices.isEmpty) return;
    if (notices.any((notice) => notice.isActionable)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l10n.clearNotificationsTitle),
            content: Text(l10n.clearNotificationsRecoveryMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.clearNotifications),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !context.mounted) return;
    }
    final cleared = await clearAll();
    if (!context.mounted) return;
    if (cleared) {
      Navigator.of(context).pop();
      return;
    }
    // clearAll 已通过统一 controller 将安全失败消息放回当前队列。
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 560),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.notifications,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  DenseIconButton(
                    icon: Icons.delete_sweep_outlined,
                    tooltip: l10n.clearNotifications,
                    onPressed: notices.isEmpty
                        ? null
                        : () => _clearNotifications(context),
                  ),
                  IconButton(
                    tooltip: l10n.closeNotifications,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_outlined, size: 18),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.chakra.border),
            Expanded(
              child: notices.isEmpty
                  ? _NotificationEmptyState(label: l10n.noNotifications)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: notices.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: context.chakra.border),
                      itemBuilder: (context, index) => _NotificationRow(
                        notice: notices[index],
                        onAcknowledge: () =>
                            acknowledge(notices[index].deduplicationKey),
                        onRecover: notices[index].recovery == null
                            ? null
                            : () => recover(notices[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.notifications_none_outlined,
          size: 28,
          color: context.chakra.fgSubtle,
        ),
        const SizedBox(height: 10),
        Text(label, style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notice,
    required this.onAcknowledge,
    required this.onRecover,
  });

  final UserNotice notice;
  final Future<void> Function() onAcknowledge;
  final Future<void> Function()? onRecover;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = switch (notice.severity) {
      NoticeSeverity.error => context.chakra.error,
      NoticeSeverity.warning => context.chakra.warning,
      NoticeSeverity.success => context.chakra.success,
      NoticeSeverity.info => context.chakra.colorPaletteFg,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 3, height: 42, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleFor(l10n, notice.code),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  _descriptionFor(l10n, notice),
                  style: TextStyle(color: context.chakra.fgMuted, fontSize: 12),
                ),
                if (onRecover != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onRecover,
                    icon: const Icon(Icons.refresh_outlined, size: 16),
                    label: Text(_recoveryLabel(l10n, notice)),
                  ),
                ],
              ],
            ),
          ),
          DenseIconButton(
            icon: Icons.check_outlined,
            tooltip: l10n.acknowledgeNotification,
            onPressed: onAcknowledge,
          ),
        ],
      ),
    );
  }

  String _titleFor(AppLocalizations l10n, NoticeCode code) => switch (code) {
    NoticeCode.operationPartiallyCompleted =>
      l10n.notificationActionPartiallyCompleted,
    NoticeCode.operationFailed => l10n.notificationActionFailed,
    NoticeCode.sessionFailed => l10n.notificationSessionFailed,
    NoticeCode.sessionReconnecting => l10n.notificationSessionReconnecting,
    NoticeCode.sessionDisconnected => l10n.notificationSessionDisconnected,
    NoticeCode.operationSucceeded => l10n.notificationActionCompleted,
  };

  String _descriptionFor(AppLocalizations l10n, UserNotice notice) =>
      notice.message?.localized(l10n) ??
      (notice.recovery == null
          ? l10n.notificationReviewAndAcknowledge
          : l10n.notificationSafeRecoveryAvailable);

  String _recoveryLabel(AppLocalizations l10n, UserNotice notice) =>
      switch (notice.recovery!.id) {
        RecoveryCommandId.retryMockServerStart => l10n.retryStart,
        RecoveryCommandId.retryMockServerStop => l10n.retryStop,
        RecoveryCommandId.retryMockServerSave => l10n.retrySave,
        _ => l10n.retryAction,
      };
}
