import 'package:flutter/material.dart';

import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/domain/preferences/workspace_preferences.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/features/settings/view_models/settings_view_model.dart';
import 'package:sendreq/ui/features/settings/widgets/settings_controls.dart';
import 'package:sendreq/ui/features/settings/widgets/settings_narrow_layout.dart';
import 'package:sendreq/ui/features/settings/widgets/settings_wide_layout.dart';

/// 设置入口：选择与可用宽度相符的工作面并展示持久化状态。
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.viewModel,
    this.onAppearanceChanged,
    this.onLocaleChanged,
    this.onFontChanged,
    this.onCodeFontChanged,
    this.onCodeFontSizeChanged,
  });

  final SettingsViewModel viewModel;
  final ValueChanged<AppearancePreference>? onAppearanceChanged;
  final ValueChanged<LocalePreference>? onLocaleChanged;
  final ValueChanged<WorkspaceFontPreference>? onFontChanged;
  final ValueChanged<CodeFontPreference>? onCodeFontChanged;
  final ValueChanged<double>? onCodeFontSizeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controls = SettingsControls(
      viewModel: viewModel,
      onAppearanceChanged: onAppearanceChanged,
      onLocaleChanged: onLocaleChanged,
      onFontChanged: onFontChanged,
      onCodeFontChanged: onCodeFontChanged,
      onCodeFontSizeChanged: onCodeFontSizeChanged,
    );
    return Container(
      color: context.chakra.bg,
      padding: WorkspaceLayoutMetrics.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(
            title: l10n.settings,
            subtitle: l10n.settingsSubtitle,
            trailing: _PreferencePersistenceStatus(viewModel: viewModel),
          ),
          const SizedBox(height: WorkspaceLayoutMetrics.sectionGap),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 780
                  ? SettingsWideLayout(controls: controls)
                  : SettingsNarrowLayout(controls: controls),
            ),
          ),
        ],
      ),
    );
  }
}

/// 固定几何的自动保存反馈，状态切换不会推动设置标题和表单位置。
class _PreferencePersistenceStatus extends StatelessWidget {
  const _PreferencePersistenceStatus({required this.viewModel});

  final SettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = viewModel.persistenceState;
    final color = switch (state) {
      PreferencePersistenceState.failed => context.chakra.error,
      PreferencePersistenceState.saved => context.chakra.success,
      PreferencePersistenceState.saving => context.chakra.fgMuted,
    };
    final icon = switch (state) {
      PreferencePersistenceState.failed => Icons.error_outline,
      PreferencePersistenceState.saved => Icons.check_circle_outline,
      PreferencePersistenceState.saving => Icons.sync,
    };
    final label = switch (state) {
      PreferencePersistenceState.failed => l10n.preferencesSaveFailedShort,
      PreferencePersistenceState.saved => l10n.preferencesSaved,
      PreferencePersistenceState.saving => l10n.preferencesSaving,
    };

    return SizedBox(
      key: const Key('settings-persistence-status'),
      width: 220,
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (state == PreferencePersistenceState.failed) ...[
            const SizedBox(width: 8),
            TextButton(
              key: const Key('settings-retry-save'),
              onPressed: viewModel.retryPreferenceSave,
              child: Text(l10n.retry),
            ),
          ],
        ],
      ),
    );
  }
}
