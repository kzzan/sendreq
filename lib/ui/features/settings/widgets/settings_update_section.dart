import 'package:flutter/material.dart';

import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/features/settings/view_models/app_update_controller.dart';
import 'package:sendreq/ui/features/settings/widgets/settings_controls.dart';

class SettingsUpdateSection extends StatelessWidget {
  const SettingsUpdateSection({super.key, required this.controller});

  final AppUpdateController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l10n = AppLocalizations.of(context);
      final checking = controller.state == AppUpdateState.checking;
      final status = switch (controller.state) {
        AppUpdateState.idle => l10n.updateCheckNotRun,
        AppUpdateState.checking => l10n.checkingForUpdates,
        AppUpdateState.upToDate => l10n.appIsUpToDate(
          controller.currentVersion ?? '',
        ),
        AppUpdateState.updateAvailable => l10n.appUpdateAvailable(
          controller.latestRelease?.version ?? '',
        ),
        AppUpdateState.failed => l10n.updateCheckFailed,
      };
      final statusColor = switch (controller.state) {
        AppUpdateState.updateAvailable => context.chakra.warning,
        AppUpdateState.failed => context.chakra.error,
        AppUpdateState.upToDate => context.chakra.success,
        _ => context.chakra.fgMuted,
      };
      return SettingsSection(
        title: l10n.updates,
        child: SettingsField(
          title: l10n.updates,
          description: l10n.updateDescription,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status,
                key: const Key('settings-update-status'),
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('settings-check-updates'),
                    onPressed: checking ? null : controller.checkForUpdates,
                    icon: checking
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: Text(l10n.checkForUpdates),
                  ),
                  if (controller.state == AppUpdateState.updateAvailable)
                    FilledButton.icon(
                      key: const Key('settings-update-now'),
                      onPressed: controller.update,
                      icon: const Icon(Icons.system_update_alt, size: 16),
                      label: Text(l10n.updateNow),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
