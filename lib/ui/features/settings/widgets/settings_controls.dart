import 'package:flutter/material.dart';

import 'package:sendreq/domain/preferences/workspace_preferences.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';
import 'package:sendreq/ui/core/theme/chakra_recipes.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/features/settings/view_models/settings_view_model.dart';

/// 集中偏好读取和写入，确保宽窄布局始终执行相同的应用级同步。
class SettingsControls {
  const SettingsControls({
    required this.viewModel,
    required this.onAppearanceChanged,
    required this.onLocaleChanged,
    required this.onFontChanged,
    required this.onCodeFontChanged,
    required this.onCodeFontSizeChanged,
  });

  final SettingsViewModel viewModel;
  final ValueChanged<AppearancePreference>? onAppearanceChanged;
  final ValueChanged<LocalePreference>? onLocaleChanged;
  final ValueChanged<WorkspaceFontPreference>? onFontChanged;
  final ValueChanged<CodeFontPreference>? onCodeFontChanged;
  final ValueChanged<double>? onCodeFontSizeChanged;

  void selectAppearance(AppearancePreference appearance) {
    viewModel.updateAppearance(appearance);
    onAppearanceChanged?.call(appearance);
  }

  void selectLocale(LocalePreference locale) {
    viewModel.updateLocale(locale);
    onLocaleChanged?.call(locale);
  }

  void selectFont(WorkspaceFontPreference font) {
    viewModel.updateFont(font);
    onFontChanged?.call(font);
  }

  void selectCodeFont(CodeFontPreference font) {
    viewModel.updateCodeFont(font);
    onCodeFontChanged?.call(font);
  }

  void selectCodeFontSize(double value) {
    final size = value.roundToDouble().clamp(10, 18).toDouble();
    viewModel.updateCodeFontSize(size);
    onCodeFontSizeChanged?.call(size);
  }

  void reset() {
    const defaults = WorkspacePreferences.defaults;
    viewModel.resetPreferences();
    onAppearanceChanged?.call(defaults.appearance);
    onLocaleChanged?.call(defaults.locale);
    onFontChanged?.call(defaults.font);
    onCodeFontChanged?.call(defaults.codeFont);
    onCodeFontSizeChanged?.call(defaults.codeFontSize);
  }
}

class SettingsOption<T> {
  const SettingsOption({required this.value, required this.label, this.key});

  final T value;
  final String label;
  final Key? key;
}

/// Typed segmented options keep localization labels out of preference commands.
class SettingsOptionGroup<T> extends StatelessWidget {
  const SettingsOptionGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<SettingsOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                key: option.key,
                style: ChakraRecipes.compactSelectableFor(
                  context,
                  selected: option.value == selected,
                ),
                onPressed: () => onSelected(option.value),
                child: Text(option.label),
              ),
            ),
        ],
      ),
    );
  }
}

class SettingsField extends StatelessWidget {
  const SettingsField({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    label: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          style: TextStyle(color: context.chakra.fgMuted, fontSize: 12),
        ),
        const SizedBox(height: WorkspaceLayoutMetrics.groupGap),
        child,
      ],
    ),
  );
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: WorkspaceLayoutMetrics.panelPadding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: WorkspaceLayoutMetrics.groupGap),
        child,
      ],
    ),
  );
}

class CodeTypographyControls extends StatelessWidget {
  const CodeTypographyControls({super.key, required this.controls});

  final SettingsControls controls;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsField(
          title: l10n.codeFont,
          description: l10n.codeFontDescription,
          child: SettingsOptionGroup<CodeFontPreference>(
            selected: controls.viewModel.codeFont,
            onSelected: controls.selectCodeFont,
            options: const [
              SettingsOption(
                key: Key('settings-code-font-jetbrains-mono'),
                value: CodeFontPreference.jetBrainsMono,
                label: 'JetBrains Mono',
              ),
              SettingsOption(
                key: Key('settings-code-font-system'),
                value: CodeFontPreference.system,
                label: 'System Mono',
              ),
            ],
          ),
        ),
        const SizedBox(height: WorkspaceLayoutMetrics.sectionGap),
        SettingsField(
          title: l10n.codeFontSize,
          description: l10n.codeFontSizeDescription,
          child: Row(
            children: [
              Expanded(
                child: Slider(
                  key: const Key('code-font-size-slider'),
                  min: 10,
                  max: 18,
                  divisions: 8,
                  value: controls.viewModel.codeFontSize,
                  label: '${controls.viewModel.codeFontSize.round()}',
                  onChanged: controls.selectCodeFontSize,
                ),
              ),
              SizedBox(
                width: 32,
                child: MonoText(
                  '${controls.viewModel.codeFontSize.round()}',
                  color: context.chakra.fg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
