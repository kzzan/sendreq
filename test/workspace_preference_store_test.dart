import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/data/repositories/file_workspace_preference_store.dart';
import 'package:sendreq/data/repositories/shared_preferences_workspace_preference_store.dart';
import 'package:sendreq/domain/preferences/workspace_preferences.dart';
import 'package:sendreq/domain/repositories/workspace_preference_store.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/ui/features/settings/view_models/settings_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/workspace_view_model_test_factory.dart';

void main() {
  test('migrates the legacy fluent font value to the system font', () async {
    SharedPreferences.setMockInitialValues({
      'sendreq.preferences.schema_version': 3,
      'sendreq.preferences.appearance': 'dark',
      'sendreq.preferences.locale': 'system',
      'sendreq.preferences.font': 'fluent',
      'sendreq.preferences.code_font': 'jetBrainsMono',
      'sendreq.preferences.code_font_size': 12.0,
    });
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesWorkspacePreferenceStore.fromPreferences(
      preferences,
    );

    final loaded = await store.load();

    expect(loaded.font, WorkspaceFontPreference.system);
    expect(loaded.font.family, isNull);
  });

  test('writes the current bundled font preference name', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesWorkspacePreferenceStore.fromPreferences(
      preferences,
    );

    await store.save(
      const WorkspacePreferences(
        appearance: AppearancePreference.dark,
        font: WorkspaceFontPreference.notoSans,
      ),
    );

    expect(preferences.getString('sendreq.preferences.font'), 'notoSans');
  });

  test('legacy JSON migration accepts the old fluent font value', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sendreq-preferences-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/preferences.json');
    await file.writeAsString(
      jsonEncode({
        'version': 5,
        'appearance': 'dark',
        'locale': 'system',
        'font': 'fluent',
      }),
    );

    final loaded = await FileWorkspacePreferenceStore(
      configurationDirectory: directory,
    ).loadForMigration();

    expect(loaded.font, WorkspaceFontPreference.system);
  });

  test(
    'rapid preference changes coalesce into the latest durable value',
    () async {
      final store = _ControlledPreferenceStore();
      final viewModel = workspaceViewModel(preferenceStore: store);
      addTearDown(viewModel.dispose);

      viewModel.updateAppearance(AppearancePreference.light);
      viewModel.updateAppearance(AppearancePreference.system);
      viewModel.updateAppearance(AppearancePreference.dark);

      expect(
        viewModel.preferencePersistenceState,
        PreferencePersistenceState.saving,
      );

      await viewModel.waitForPendingPreferenceWrites();

      expect(store.saved, hasLength(1));
      expect(store.saved.single.appearance, AppearancePreference.dark);
      expect(viewModel.appearance, AppearancePreference.dark);
      expect(viewModel.hasPreferenceChanges, isFalse);
      expect(
        viewModel.preferencePersistenceState,
        PreferencePersistenceState.saved,
      );
    },
  );

  test(
    'changes during an active write persist only the first and latest values',
    () async {
      final store = _BlockingPreferenceStore();
      final viewModel = workspaceViewModel(preferenceStore: store);
      addTearDown(viewModel.dispose);

      viewModel.updateAppearance(AppearancePreference.light);
      await store.firstSaveStarted.future;

      viewModel.updateAppearance(AppearancePreference.system);
      viewModel.updateAppearance(AppearancePreference.dark);

      expect(store.saved, hasLength(1));
      expect(store.saved.single.appearance, AppearancePreference.light);

      store.releaseFirstSave.complete();
      await viewModel.waitForPendingPreferenceWrites();

      expect(store.saved, hasLength(2));
      expect(store.saved.last.appearance, AppearancePreference.dark);
      expect(viewModel.hasPreferenceChanges, isFalse);
      expect(
        viewModel.preferencePersistenceState,
        PreferencePersistenceState.saved,
      );
    },
  );

  test('failed auto-save keeps the preview and retry persists it', () async {
    final store = _ControlledPreferenceStore(failuresRemaining: 1);
    final viewModel = workspaceViewModel(preferenceStore: store);
    addTearDown(viewModel.dispose);

    viewModel.updateAppearance(AppearancePreference.light);
    await viewModel.waitForPendingPreferenceWrites();

    expect(viewModel.appearance, AppearancePreference.light);
    expect(viewModel.hasPreferenceChanges, isTrue);
    expect(
      viewModel.preferencePersistenceState,
      PreferencePersistenceState.failed,
    );
    expect(viewModel.lastActionMessage, 'Could not save preferences. Retry.');

    final retry = viewModel.retryPreferenceSave();
    expect(
      viewModel.preferencePersistenceState,
      PreferencePersistenceState.saving,
    );
    await retry;

    expect(store.saved.single.appearance, AppearancePreference.light);
    expect(viewModel.appearance, AppearancePreference.light);
    expect(viewModel.hasPreferenceChanges, isFalse);
    expect(
      viewModel.preferencePersistenceState,
      PreferencePersistenceState.saved,
    );
    expect(viewModel.lastActionMessage, isNull);
  });

  test(
    'all preference fields persist together and reset to domain defaults',
    () async {
      final store = _ControlledPreferenceStore();
      final viewModel = workspaceViewModel(preferenceStore: store);
      addTearDown(viewModel.dispose);

      viewModel.updateLocale(LocalePreference.simplifiedChinese);
      viewModel.updateFont(WorkspaceFontPreference.notoSans);
      viewModel.updateCodeFont(CodeFontPreference.system);
      viewModel.updateCodeFontSize(18);
      await viewModel.waitForPendingPreferenceWrites();

      final saved = store.saved.last;
      expect(saved.locale, LocalePreference.simplifiedChinese);
      expect(saved.font, WorkspaceFontPreference.notoSans);
      expect(saved.codeFont, CodeFontPreference.system);
      expect(saved.codeFontSize, 18);

      viewModel.resetPreferences();
      await viewModel.waitForPendingPreferenceWrites();
      final reset = store.saved.last;
      expect(reset.appearance, WorkspacePreferences.defaults.appearance);
      expect(reset.locale, WorkspacePreferences.defaults.locale);
      expect(reset.font, WorkspacePreferences.defaults.font);
      expect(reset.codeFont, WorkspacePreferences.defaults.codeFont);
      expect(reset.codeFontSize, WorkspacePreferences.defaults.codeFontSize);
    },
  );
}

class _ControlledPreferenceStore implements WorkspacePreferenceStore {
  _ControlledPreferenceStore({this.failuresRemaining = 0});

  int failuresRemaining;
  final List<WorkspacePreferences> saved = [];

  @override
  Future<WorkspacePreferences> load() async => WorkspacePreferences.defaults;

  @override
  Future<void> save(WorkspacePreferences preferences) async {
    await Future<void>.delayed(Duration.zero);
    if (failuresRemaining > 0) {
      failuresRemaining -= 1;
      throw StateError('unavailable');
    }
    saved.add(preferences);
  }
}

class _BlockingPreferenceStore implements WorkspacePreferenceStore {
  final firstSaveStarted = Completer<void>();
  final releaseFirstSave = Completer<void>();
  final List<WorkspacePreferences> saved = [];

  @override
  Future<WorkspacePreferences> load() async => WorkspacePreferences.defaults;

  @override
  Future<void> save(WorkspacePreferences preferences) async {
    saved.add(preferences);
    if (saved.length != 1) return;
    firstSaveStarted.complete();
    await releaseFirstSave.future;
  }
}
