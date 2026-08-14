import 'package:flutter/foundation.dart';

import 'package:sendreq/domain/preferences/workspace_preferences.dart';
import 'package:sendreq/ui/features/settings/view_models/app_update_controller.dart';

/// Current persistence status of the complete preference snapshot.
enum PreferencePersistenceState { saved, saving, failed }

/// Immutable Settings projection with explicit commands.
///
/// The workspace owns the listening lifecycle. Settings widgets consume only
/// this feature contract, so they do not depend on the Shell implementation.
class SettingsViewModel {
  const SettingsViewModel({
    required this.appearance,
    required this.locale,
    required this.font,
    required this.codeFont,
    required this.codeFontSize,
    required this.persistenceState,
    required this.updateAppearance,
    required this.updateLocale,
    required this.updateFont,
    required this.updateCodeFont,
    required this.updateCodeFontSize,
    required this.resetPreferences,
    required this.retryPreferenceSave,
    required this.appUpdateController,
  });

  final AppearancePreference appearance;
  final LocalePreference locale;
  final WorkspaceFontPreference font;
  final CodeFontPreference codeFont;
  final double codeFontSize;
  final PreferencePersistenceState persistenceState;
  final AppUpdateController appUpdateController;

  final ValueChanged<AppearancePreference> updateAppearance;
  final ValueChanged<LocalePreference> updateLocale;
  final ValueChanged<WorkspaceFontPreference> updateFont;
  final ValueChanged<CodeFontPreference> updateCodeFont;
  final ValueChanged<double> updateCodeFontSize;
  final VoidCallback resetPreferences;
  final AsyncCallback retryPreferenceSave;
}
