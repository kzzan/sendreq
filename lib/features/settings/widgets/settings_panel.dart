import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/form_control_metrics.dart';
import '../../../domain/preferences/workspace_preferences.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../workspace/view_models/workspace_view_model.dart';
import '../../../core/widgets/dense_controls.dart';

/// 设置面板：集中管理外观、语言、快捷键等工作区偏好设置。
class SettingsPanel extends StatelessWidget {
  /// 构造设置面板。
  const SettingsPanel({
    super.key,
    required this.viewModel,
    this.onAppearanceChanged,
    this.onLocaleChanged,
    this.onFontChanged,
  });

  /// 工作区视图模型，提供偏好读取与保存能力。
  final WorkspaceViewModel viewModel;

  /// 外观切换回调（用于同步应用级主题状态）。
  final ValueChanged<AppearancePreference>? onAppearanceChanged;

  /// 语言切换回调（用于同步应用级多语言状态）。
  final ValueChanged<LocalePreference>? onLocaleChanged;

  /// 字体变更回调，用于让应用根部即时刷新主题。
  final ValueChanged<WorkspaceFontPreference>? onFontChanged;

  /// 构建设置面板：外观、字体、语言、快捷键、导出目录等分组设置。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(
            title: l10n.settings,
            subtitle: l10n.settingsSubtitle,
            trailing: FilledButton.icon(
              // 仅在有未保存改动时允许点击保存。
              onPressed: viewModel.hasPreferenceChanges
                  ? viewModel.savePreferences
                  : null,
              icon: const Icon(Icons.save_outlined, size: 16),
              label: Text(l10n.savePreferences),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 780) {
                  return _SettingsWideLayout(
                    viewModel: viewModel,
                    onAppearanceChanged: onAppearanceChanged,
                    onLocaleChanged: onLocaleChanged,
                    onFontChanged: onFontChanged,
                  );
                }
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: DensePanel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            child: Text(
                              l10n.appearance,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Divider(height: 1, color: AppColors.outline),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.appearanceDescription,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SegmentedTabs(
                                  tabs: [l10n.light, l10n.dark, l10n.system],
                                  active: _appearanceLabel(
                                    l10n,
                                    viewModel.appearance,
                                  ),
                                  // 根据选中的文本标签映射为对应的外观偏好。
                                  onSelected: (label) {
                                    final appearance = switch (label) {
                                      _ when label == l10n.light =>
                                        AppearancePreference.light,
                                      _ when label == l10n.system =>
                                        AppearancePreference.system,
                                      _ => AppearancePreference.dark,
                                    };
                                    viewModel.updateAppearance(appearance);
                                    onAppearanceChanged?.call(appearance);
                                  },
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: AppColors.outline),
                          _SettingsSection(
                            title: l10n.font,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.fontDescription,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SegmentedTabs(
                                  tabs: const ['Inter', 'Noto Sans', 'System'],
                                  active: _fontLabel(viewModel.font),
                                  onSelected: (label) {
                                    final font = switch (label) {
                                      'Noto Sans' =>
                                        WorkspaceFontPreference.notoSans,
                                      'System' =>
                                        WorkspaceFontPreference.system,
                                      _ => WorkspaceFontPreference.inter,
                                    };
                                    viewModel.updateFont(font);
                                    onFontChanged?.call(font);
                                  },
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: AppColors.outline),
                          _SettingsSection(
                            title: l10n.language,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.languageDescription,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SegmentedTabs(
                                  tabs: [
                                    l10n.system,
                                    l10n.simplifiedChinese,
                                    l10n.english,
                                  ],
                                  active: _localeLabel(l10n, viewModel.locale),
                                  // 根据选中的文本标签映射为对应的语言偏好。
                                  onSelected: (label) {
                                    final locale = label == l10n.english
                                        ? LocalePreference.english
                                        : label == l10n.simplifiedChinese
                                        ? LocalePreference.simplifiedChinese
                                        : LocalePreference.system;
                                    viewModel.updateLocale(locale);
                                    onLocaleChanged?.call(locale);
                                  },
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: AppColors.outline),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            child: Text(
                              l10n.keyboardShortcuts,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Divider(height: 1, color: AppColors.outline),
                          _SettingsSection(
                            title: l10n.documentationExport,
                            child: _DocumentationOutputDirectorySetting(
                              viewModel: viewModel,
                            ),
                          ),
                          Divider(height: 1, color: AppColors.outline),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MonoText(
                                  l10n.sendRequest,
                                  color: AppColors.textFaint,
                                  size: 10,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.sendShortcutDescription,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SegmentedTabs(
                                  tabs: const ['Ctrl+Enter', 'Ctrl+Space'],
                                  active:
                                      viewModel.sendShortcut ==
                                          SendShortcutPreference.controlSpace
                                      ? 'Ctrl+Space'
                                      : viewModel.sendShortcut ==
                                            SendShortcutPreference.custom
                                      ? ''
                                      : 'Ctrl+Enter',
                                  onSelected: (label) =>
                                      viewModel.updateSendShortcut(
                                        label == 'Ctrl+Space'
                                            ? SendShortcutPreference
                                                  .controlSpace
                                            : SendShortcutPreference
                                                  .controlEnter,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                _ShortcutRecorder(viewModel: viewModel),
                                // 选择 Ctrl+Space 时可能与系统输入法切换冲突，给出提醒。
                                if (viewModel.sendShortcut ==
                                    SendShortcutPreference.controlSpace) ...[
                                  const SizedBox(height: 10),
                                  _ShortcutNotice(
                                    message: l10n.shortcutConflictWarning,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Divider(height: 1, color: AppColors.outline),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l10n.resetPreferencesDescription,
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () {
                                    // 重置偏好并同步外观/语言的应用级状态。
                                    viewModel.resetPreferences();
                                    onAppearanceChanged?.call(
                                      AppearancePreference.dark,
                                    );
                                    onLocaleChanged?.call(
                                      LocalePreference.system,
                                    );
                                    onFontChanged?.call(
                                      WorkspaceFontPreference.inter,
                                    );
                                  },
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
              },
            ),
          ),
          // 仅在用户显式保存成功后展示确认，预览设置不会触发该状态。
          if (viewModel.lastActionMessage == 'Preferences saved.') ...[
            const SizedBox(height: 8),
            MonoText(l10n.preferencesSaved, color: AppColors.success, size: 10),
          ],
        ],
      ),
    );
  }

  /// 将语言偏好枚举映射为对应的本地化标签文本。
  String _localeLabel(AppLocalizations l10n, LocalePreference locale) =>
      switch (locale) {
        LocalePreference.system => l10n.system,
        LocalePreference.english => l10n.english,
        LocalePreference.simplifiedChinese => l10n.simplifiedChinese,
      };

  /// 将外观偏好枚举映射为对应的本地化标签文本。
  String _appearanceLabel(
    AppLocalizations l10n,
    AppearancePreference appearance,
  ) => switch (appearance) {
    AppearancePreference.light => l10n.light,
    AppearancePreference.dark => l10n.dark,
    AppearancePreference.system => l10n.system,
  };

  /// 将字体偏好枚举映射为对应的展示标签文本。
  String _fontLabel(WorkspaceFontPreference font) => switch (font) {
    WorkspaceFontPreference.inter => 'Inter',
    WorkspaceFontPreference.notoSans => 'Noto Sans',
    WorkspaceFontPreference.system => 'System',
  };
}

/// 宽屏设置工作面：把显示、语言和工作流偏好分列，避免长表单持续滚动。
class _SettingsWideLayout extends StatelessWidget {
  const _SettingsWideLayout({
    required this.viewModel,
    required this.onAppearanceChanged,
    required this.onLocaleChanged,
    required this.onFontChanged,
  });

  final WorkspaceViewModel viewModel;
  final ValueChanged<AppearancePreference>? onAppearanceChanged;
  final ValueChanged<LocalePreference>? onLocaleChanged;
  final ValueChanged<WorkspaceFontPreference>? onFontChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _SettingsSurface(
                    icon: Icons.contrast_outlined,
                    title: l10n.appearance,
                    child: _SettingsField(
                      title: l10n.appearance,
                      description: l10n.appearanceDescription,
                      child: SegmentedTabs(
                        tabs: [l10n.light, l10n.dark, l10n.system],
                        active: _appearanceLabel(l10n, viewModel.appearance),
                        onSelected: (label) {
                          final appearance = switch (label) {
                            _ when label == l10n.light =>
                              AppearancePreference.light,
                            _ when label == l10n.system =>
                              AppearancePreference.system,
                            _ => AppearancePreference.dark,
                          };
                          viewModel.updateAppearance(appearance);
                          onAppearanceChanged?.call(appearance);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SettingsSurface(
                    icon: Icons.text_fields_outlined,
                    title: l10n.font,
                    child: _SettingsField(
                      title: l10n.font,
                      description: l10n.fontDescription,
                      child: SegmentedTabs(
                        tabs: const ['Inter', 'Noto Sans', 'System'],
                        active: _fontLabel(viewModel.font),
                        onSelected: (label) {
                          final font = switch (label) {
                            'Noto Sans' => WorkspaceFontPreference.notoSans,
                            'System' => WorkspaceFontPreference.system,
                            _ => WorkspaceFontPreference.inter,
                          };
                          viewModel.updateFont(font);
                          onFontChanged?.call(font);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SettingsSurface(
                    icon: Icons.translate_outlined,
                    title: l10n.language,
                    child: _SettingsField(
                      title: l10n.language,
                      description: l10n.languageDescription,
                      child: SegmentedTabs(
                        tabs: [
                          l10n.system,
                          l10n.simplifiedChinese,
                          l10n.english,
                        ],
                        active: _localeLabel(l10n, viewModel.locale),
                        onSelected: (label) {
                          final locale = label == l10n.english
                              ? LocalePreference.english
                              : label == l10n.simplifiedChinese
                              ? LocalePreference.simplifiedChinese
                              : LocalePreference.system;
                          viewModel.updateLocale(locale);
                          onLocaleChanged?.call(locale);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  _SettingsSurface(
                    icon: Icons.keyboard_outlined,
                    title: l10n.keyboardShortcuts,
                    child: _SettingsField(
                      title: l10n.sendRequest,
                      description: l10n.sendShortcutDescription,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SegmentedTabs(
                            tabs: const ['Ctrl+Enter', 'Ctrl+Space'],
                            active:
                                viewModel.sendShortcut ==
                                    SendShortcutPreference.controlSpace
                                ? 'Ctrl+Space'
                                : viewModel.sendShortcut ==
                                      SendShortcutPreference.custom
                                ? ''
                                : 'Ctrl+Enter',
                            onSelected: (label) => viewModel.updateSendShortcut(
                              label == 'Ctrl+Space'
                                  ? SendShortcutPreference.controlSpace
                                  : SendShortcutPreference.controlEnter,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ShortcutRecorder(viewModel: viewModel),
                          if (viewModel.sendShortcut ==
                              SendShortcutPreference.controlSpace) ...[
                            const SizedBox(height: 10),
                            _ShortcutNotice(
                              message: l10n.shortcutConflictWarning,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SettingsSurface(
                    icon: Icons.folder_open_outlined,
                    title: l10n.documentationExport,
                    child: _SettingsField(
                      title: l10n.documentationExport,
                      description: l10n.documentationOutputDirectoryDescription,
                      child: _DocumentationOutputDirectorySetting(
                        viewModel: viewModel,
                        showDescription: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SettingsSurface(
                    icon: Icons.restart_alt_outlined,
                    title: l10n.resetDefaults,
                    child: _SettingsField(
                      title: l10n.resetDefaults,
                      description: l10n.resetPreferencesDescription,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            viewModel.resetPreferences();
                            onAppearanceChanged?.call(
                              AppearancePreference.dark,
                            );
                            onLocaleChanged?.call(LocalePreference.system);
                            onFontChanged?.call(WorkspaceFontPreference.inter);
                          },
                          icon: const Icon(
                            Icons.restart_alt_outlined,
                            size: 16,
                          ),
                          label: Text(l10n.resetDefaults),
                        ),
                      ),
                    ),
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

/// 单个设置组的稳定工具面。标题负责定位，内容只放实际可编辑控件。
class _SettingsSurface extends StatelessWidget {
  const _SettingsSurface({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => DensePanel(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            border: Border(bottom: BorderSide(color: AppColors.outline)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.all(12), child: child),
      ],
    ),
  );
}

/// 设置项的说明与控件分开排布，避免标签和选项在同一条基线上争抢空间。
class _SettingsField extends StatelessWidget {
  const _SettingsField({
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
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

String _localeLabel(AppLocalizations l10n, LocalePreference locale) =>
    switch (locale) {
      LocalePreference.system => l10n.system,
      LocalePreference.english => l10n.english,
      LocalePreference.simplifiedChinese => l10n.simplifiedChinese,
    };

String _appearanceLabel(
  AppLocalizations l10n,
  AppearancePreference appearance,
) => switch (appearance) {
  AppearancePreference.light => l10n.light,
  AppearancePreference.dark => l10n.dark,
  AppearancePreference.system => l10n.system,
};

String _fontLabel(WorkspaceFontPreference font) => switch (font) {
  WorkspaceFontPreference.inter => 'Inter',
  WorkspaceFontPreference.notoSans => 'Noto Sans',
  WorkspaceFontPreference.system => 'System',
};

/// 显示并维护 Markdown 文档输出目录，目录选择交给系统原生对话框。
class _DocumentationOutputDirectorySetting extends StatelessWidget {
  /// 构造文档输出目录设置项。
  const _DocumentationOutputDirectorySetting({
    required this.viewModel,
    this.showDescription = true,
  });

  /// 工作区视图模型，用于读写文档输出目录偏好。
  final WorkspaceViewModel viewModel;

  /// 是否显示字段说明；宽屏设置面已由外层负责说明。
  final bool showDescription;

  /// 通过系统目录选择器选取新的输出目录并写入偏好。
  Future<void> _chooseDirectory(BuildContext context) async {
    final directory = await FilePicker.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context).chooseDocumentationOutputFolder,
    );
    // 仅当用户确认选择后才更新目录偏好。
    if (directory == null || !context.mounted) return;
    viewModel.updateDocumentationOutputDirectory(directory);
    await _verifyDirectory(context);
  }

  /// 切换目录后立即尝试创建它，保存和实际导出时还会再次校验。
  Future<void> _verifyDirectory(BuildContext context) async {
    try {
      await viewModel.ensureDocumentationOutputDirectory();
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).documentationOutputDirectoryUnavailable(error.toString()),
          ),
        ),
      );
    }
  }

  /// 恢复默认目录，同时保留显式保存的语义。
  Future<void> _restoreDefaultDirectory(BuildContext context) async {
    viewModel.updateDocumentationOutputDirectory(null);
    await _verifyDirectory(context);
  }

  /// 构建设置项：说明文案 + 当前目录展示 + 更改目录按钮。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final directory = viewModel.documentationOutputDirectory;
    final usesDefault = viewModel.usesDefaultDocumentationOutputDirectory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDescription) ...[
          Text(
            l10n.documentationOutputDirectoryDescription,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: (usesDefault ? AppColors.primary : AppColors.success)
                .withValues(alpha: 0.10),
            border: Border.all(
              color: (usesDefault ? AppColors.primary : AppColors.success)
                  .withValues(alpha: 0.40),
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                usesDefault ? Icons.home_outlined : Icons.folder_outlined,
                size: 14,
                color: usesDefault ? AppColors.primary : AppColors.success,
              ),
              const SizedBox(width: 5),
              Text(
                usesDefault
                    ? l10n.defaultOutputDirectory
                    : l10n.customOutputDirectory,
                style: TextStyle(
                  color: usesDefault ? AppColors.primary : AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Tooltip(
                message: directory,
                child: Container(
                  height: FormControlMetrics.standardHeight,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    border: Border.all(color: AppColors.outline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: MonoText(directory, color: AppColors.text),
                ),
              ),
            ),
            const SizedBox(width: 8),
            DenseIconButton(
              icon: Icons.drive_folder_upload_outlined,
              tooltip: l10n.changeOutputDirectory,
              onPressed: () => _chooseDirectory(context),
            ),
            const SizedBox(width: 4),
            DenseIconButton(
              icon: Icons.restart_alt_outlined,
              tooltip: l10n.restoreDefaultOutputDirectory,
              onPressed: usesDefault
                  ? null
                  : () => _restoreDefaultDirectory(context),
            ),
          ],
        ),
      ],
    );
  }
}

/// 通过捕获一次按键事件来设置全局发送快捷键，避免手工编辑组合字符串。
class _ShortcutRecorder extends StatefulWidget {
  /// 构造快捷键录制入口。
  const _ShortcutRecorder({required this.viewModel});

  /// 工作区视图模型，提供自定义快捷键的读取与保存能力。
  final WorkspaceViewModel viewModel;

  /// 创建快捷键录制入口状态。
  @override
  State<_ShortcutRecorder> createState() => _ShortcutRecorderState();
}

/// 快捷键录制入口状态：弹出捕获对话框并应用新录制的快捷键。
class _ShortcutRecorderState extends State<_ShortcutRecorder> {
  /// 弹出快捷键捕获对话框，应用新组合并提示结果。
  Future<void> _recordShortcut() async {
    final binding = await showDialog<ShortcutBinding>(
      context: context,
      builder: (context) => const _ShortcutCaptureDialog(),
    );
    if (binding == null || !mounted) return;
    // 应用失败（如组合不可用）时通过 SnackBar 提示用户。
    final applied = widget.viewModel.updateCustomSendShortcut(binding);
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          applied
              ? l10n.shortcutUpdated(binding.label)
              : l10n.shortcutUnavailable,
        ),
      ),
    );
  }

  /// 构建录制入口：展示当前自定义快捷键 + 录制按钮。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MonoText(
                l10n.customShortcut,
                color: AppColors.textFaint,
                size: 10,
              ),
              const SizedBox(height: 4),
              MonoText(
                widget.viewModel.sendShortcut == SendShortcutPreference.custom
                    ? widget.viewModel.sendShortcutLabel
                    : l10n.noCustomShortcut,
                color: AppColors.textMuted,
                size: 11,
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          key: const Key('record-send-shortcut-button'),
          onPressed: _recordShortcut,
          icon: const Icon(Icons.keyboard_outlined, size: 16),
          label: Text(l10n.recordShortcut),
        ),
      ],
    );
  }
}

/// 快捷键捕获对话框：捕获一次按键组合后返回 ShortcutBinding。
class _ShortcutCaptureDialog extends StatefulWidget {
  /// 构造捕获对话框。
  const _ShortcutCaptureDialog();

  /// 创建捕获对话框状态。
  @override
  State<_ShortcutCaptureDialog> createState() => _ShortcutCaptureDialogState();
}

/// 捕获对话框状态：持有焦点并监听按键事件。
class _ShortcutCaptureDialogState extends State<_ShortcutCaptureDialog> {
  /// 用于立即聚焦对话框内容的焦点节点。
  final _focusNode = FocusNode();

  /// 校验失败时的提示文案，为空表示当前没有错误。
  String? _message;

  /// 帧回调结束后请求焦点，确保对话框完成布局后再聚焦。
  @override
  void initState() {
    super.initState();
    // 帧回调结束后请求焦点，确保对话框完成布局后再聚焦。
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  /// 释放焦点节点资源。
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// 处理按键：Esc 取消；组合键校验通过则返回，否则提示原因。
  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    final binding = ShortcutBinding.fromKeyEvent(event);
    if (binding == null) return KeyEventResult.handled;
    final l10n = AppLocalizations.of(context);
    // 快捷键必须包含修饰键，且不能与系统保留快捷键冲突。
    if (!binding.hasModifier) {
      setState(() => _message = l10n.shortcutModifierRequired);
      return KeyEventResult.handled;
    }
    if (binding.conflictsWithReservedAction()) {
      setState(() => _message = l10n.shortcutReserved);
      return KeyEventResult.handled;
    }
    Navigator.of(context).pop(binding);
    return KeyEventResult.handled;
  }

  /// 构建捕获对话框：聚焦区域 + 提示文案。
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.recordShortcut),
      // 焦点层负责拦截按键，避免输入框被冒泡处理。
      content: Focus(
        focusNode: _focusNode,
        onKeyEvent: _onKeyEvent,
        child: SizedBox(
          width: 380,
          height: 108,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard_outlined, size: 26, color: AppColors.primary),
              const SizedBox(height: 10),
              Text(l10n.recordShortcutHint, textAlign: TextAlign.center),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(_message!, style: TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

/// 设置分组容器：展示分组标题与内容。
class _SettingsSection extends StatelessWidget {
  /// 构造设置分组容器。
  const _SettingsSection({required this.title, required this.child});

  /// 分组标题。
  final String title;

  /// 分组内容。
  final Widget child;

  /// 构建分组：标题 + 内容区。
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

/// 快捷键冲突提醒条：以警告色高亮提示用户。
class _ShortcutNotice extends StatelessWidget {
  /// 构造快捷键冲突提醒条。
  const _ShortcutNotice({required this.message});

  /// 提醒文案。
  final String message;

  /// 构建警告色提示条：图标 + 文案。
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.1),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Row(
      children: [
        Icon(Icons.warning_amber_outlined, size: 16, color: AppColors.warning),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
