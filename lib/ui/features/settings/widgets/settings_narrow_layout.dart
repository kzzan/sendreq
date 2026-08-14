import 'package:flutter/material.dart';

import 'package:sendreq/domain/preferences/workspace_preferences.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/features/settings/widgets/settings_controls.dart';
import 'package:sendreq/ui/features/settings/widgets/settings_update_section.dart';

/// 窄屏单列设置面，保留原有的阅读顺序与 620px 工作宽度。
class SettingsNarrowLayout extends StatelessWidget {
  const SettingsNarrowLayout({super.key, required this.controls});

  final SettingsControls controls;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: DensePanel(
          key: const Key('settings-single-surface'),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NarrowAppearanceSection(controls: controls),
              Divider(height: 1, color: context.chakra.border),
              SettingsSection(
                title: l10n.font,
                child: SettingsField(
                  title: l10n.font,
                  description: l10n.fontDescription,
                  child: SettingsOptionGroup<WorkspaceFontPreference>(
                    selected: controls.viewModel.font,
                    onSelected: controls.selectFont,
                    options: const [
                      SettingsOption(
                        key: Key('settings-interface-font-system'),
                        value: WorkspaceFontPreference.system,
                        label: 'System',
                      ),
                      SettingsOption(
                        key: Key('settings-interface-font-noto'),
                        value: WorkspaceFontPreference.notoSans,
                        label: 'Noto Sans',
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: context.chakra.border),
              SettingsSection(
                title: l10n.codeFont,
                child: CodeTypographyControls(controls: controls),
              ),
              Divider(height: 1, color: context.chakra.border),
              SettingsSection(
                title: l10n.language,
                child: SettingsField(
                  title: l10n.language,
                  description: l10n.languageDescription,
                  child: SettingsOptionGroup<LocalePreference>(
                    selected: controls.viewModel.locale,
                    onSelected: controls.selectLocale,
                    options: [
                      SettingsOption(
                        key: const Key('settings-locale-system'),
                        value: LocalePreference.system,
                        label: l10n.system,
                      ),
                      SettingsOption(
                        key: const Key('settings-locale-zh'),
                        value: LocalePreference.simplifiedChinese,
                        label: l10n.simplifiedChinese,
                      ),
                      SettingsOption(
                        key: const Key('settings-locale-en'),
                        value: LocalePreference.english,
                        label: l10n.english,
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: context.chakra.border),
              SettingsUpdateSection(
                controller: controls.viewModel.appUpdateController,
              ),
              Divider(height: 1, color: context.chakra.border),
              Padding(
                padding: WorkspaceLayoutMetrics.panelPadding,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.resetPreferencesDescription,
                        style: TextStyle(
                          color: context.chakra.fgMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: WorkspaceLayoutMetrics.groupGap),
                    OutlinedButton(
                      onPressed: controls.reset,
                      child: Text(l10n.resetDefaults),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NarrowAppearanceSection extends StatelessWidget {
  const _NarrowAppearanceSection({required this.controls});

  final SettingsControls controls;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Text(
            l10n.appearance,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Divider(height: 1, color: context.chakra.border),
        SettingsSection(
          title: '',
          child: SettingsField(
            title: l10n.appearance,
            description: l10n.appearanceDescription,
            child: SettingsOptionGroup<AppearancePreference>(
              selected: controls.viewModel.appearance,
              onSelected: controls.selectAppearance,
              options: [
                SettingsOption(
                  key: const Key('settings-appearance-light'),
                  value: AppearancePreference.light,
                  label: l10n.light,
                ),
                SettingsOption(
                  key: const Key('settings-appearance-dark'),
                  value: AppearancePreference.dark,
                  label: l10n.dark,
                ),
                SettingsOption(
                  key: const Key('settings-appearance-system'),
                  value: AppearancePreference.system,
                  label: l10n.system,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
