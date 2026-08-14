import 'dart:async';

import 'package:sendreq/domain/preferences/workspace_preferences.dart';
import 'package:sendreq/ui/core/application/user_message.dart';
import 'package:sendreq/ui/features/settings/view_models/settings_view_model.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';

/// Workspace preference updates, durable write coalescing, and output path.
extension WorkspacePreferenceOperations on WorkspaceViewModel {
  void updateAppearance(AppearancePreference appearance) {
    if (internals.appearance == appearance) return;
    internals.appearance = appearance;
    _markPreferencesChanged();
  }

  void updateLocale(LocalePreference locale) {
    if (internals.locale == locale) return;
    internals.locale = locale;
    _markPreferencesChanged();
  }

  void updateFont(WorkspaceFontPreference font) {
    if (internals.font == font) return;
    internals.font = font;
    _markPreferencesChanged();
  }

  void updateCodeFont(CodeFontPreference font) {
    if (internals.codeFont == font) return;
    internals.codeFont = font;
    _markPreferencesChanged();
  }

  void updateCodeFontSize(double size) {
    final normalized = size.clamp(10, 18).toDouble();
    if (internals.codeFontSize == normalized) return;
    internals.codeFontSize = normalized;
    _markPreferencesChanged();
  }

  void updateOpenApiOutputDirectory(String? directory) {
    final normalized = directory?.trim();
    final value = normalized == null || normalized.isEmpty
        ? internals.defaultOpenApiOutputDirectory
        : normalized;
    if (internals.openApiOutputDirectory == value) {
      unawaited(_ensureInitialOpenApiOutputDirectory());
      return;
    }
    internals.openApiOutputDirectory = value;
    _markPreferencesChanged();
  }

  void resetPreferences() {
    const defaults = WorkspacePreferences.defaults;
    internals.appearance = defaults.appearance;
    internals.locale = defaults.locale;
    internals.font = defaults.font;
    internals.codeFont = defaults.codeFont;
    internals.codeFontSize = defaults.codeFontSize;
    internals.openApiOutputDirectory = internals.defaultOpenApiOutputDirectory;
    _markPreferencesChanged();
  }

  Future<void> retryPreferenceSave() {
    internals.preferencePersistenceState = PreferencePersistenceState.saving;
    internals.lastActionMessage = null;
    notifyWorkspace();
    return _enqueuePreferenceSave();
  }

  Future<void> waitForPendingPreferenceWrites() =>
      internals.preferenceSaveQueue;

  Future<String> ensureOpenApiOutputDirectory() async {
    final normalized = internals.openApiOutputDirectory.trim();
    if (normalized.isEmpty) {
      internals.openApiOutputDirectory =
          internals.defaultOpenApiOutputDirectory;
      internals.hasPreferenceChanges = true;
    }
    await internals.openApiDirectoryPort.ensureExists(
      internals.openApiOutputDirectory,
    );
    return internals.openApiOutputDirectory;
  }

  void _markPreferencesChanged() {
    internals.hasPreferenceChanges = true;
    internals.preferencePersistenceState = PreferencePersistenceState.saving;
    internals.lastActionMessage = null;
    notifyWorkspace();
    unawaited(_enqueuePreferenceSave());
  }

  Future<void> _ensureInitialOpenApiOutputDirectory() async {
    try {
      await ensureOpenApiOutputDirectory();
    } on Object {
      // Save and export validate the path again and surface any failure.
    }
  }

  Future<void> _enqueuePreferenceSave() {
    internals.pendingPreferenceSnapshot = WorkspacePreferences(
      appearance: internals.appearance,
      locale: internals.locale,
      font: internals.font,
      codeFont: internals.codeFont,
      codeFontSize: internals.codeFontSize,
    );
    internals.preferenceSaveVersion++;
    if (internals.preferenceSaveWorkerRunning) {
      return internals.preferenceSaveQueue;
    }
    internals.preferenceSaveWorkerRunning = true;
    internals.preferenceSaveQueue = Future<void>.delayed(
      Duration.zero,
      _drainPreferenceSaves,
    );
    return internals.preferenceSaveQueue;
  }

  Future<void> _drainPreferenceSaves() async {
    try {
      while (true) {
        final snapshot = internals.pendingPreferenceSnapshot;
        if (snapshot == null) break;
        internals.pendingPreferenceSnapshot = null;
        final version = internals.preferenceSaveVersion;
        var failed = false;
        try {
          await internals.preferenceStore.save(snapshot);
        } on Object {
          failed = true;
        }

        if (internals.pendingPreferenceSnapshot != null) continue;
        if (internals.isDisposed ||
            version != internals.preferenceSaveVersion) {
          continue;
        }
        if (!failed) {
          internals.hasPreferenceChanges = false;
          internals.preferencePersistenceState =
              PreferencePersistenceState.saved;
          internals.lastActionMessage = null;
          internals.noticeController.queue.resolve('settings.save.failed');
        } else {
          internals.hasPreferenceChanges = true;
          internals.preferencePersistenceState =
              PreferencePersistenceState.failed;
          internals.recordUserMessage(
            'Could not save preferences. Retry.',
            severity: UserMessageSeverity.error,
            deduplicationKey: 'settings.save.failed',
          );
        }
        notifyWorkspace();
      }
    } finally {
      internals.preferenceSaveWorkerRunning = false;
    }
  }
}
