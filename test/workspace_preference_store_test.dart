import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sendreq/data/repositories/file_workspace_preference_store.dart';
import 'package:sendreq/data/repositories/in_memory_workspace_preference_store.dart';
import 'package:sendreq/data/repositories/shared_preferences_workspace_preference_store.dart';
import 'package:sendreq/data/repositories/workspace_preference_store.dart';
import 'package:sendreq/data/services/documentation_output_directory.dart';
import 'package:sendreq/data/services/openapi_file_exporter.dart';
import 'package:sendreq/domain/preferences/workspace_preferences.dart';
import 'package:sendreq/features/workspace/view_models/workspace_view_model.dart';

import 'support/workspace_view_model_test_factory.dart';

void main() {
  test(
    'shared preferences store restores a complete preference snapshot',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesWorkspacePreferenceStore.fromPreferences(
        await SharedPreferences.getInstance(),
      );
      const preferences = WorkspacePreferences(
        appearance: AppearancePreference.light,
        sendShortcut: SendShortcutPreference.custom,
        locale: LocalePreference.english,
        font: WorkspaceFontPreference.notoSans,
        documentationOutputDirectory: '/tmp/sendreq-docs',
        customSendShortcut: ShortcutBinding(
          keyId: 0x00000000064,
          keyLabel: 'D',
          control: true,
          shift: true,
        ),
      );

      await store.save(preferences);
      final restored = await store.load();

      expect(restored.appearance, preferences.appearance);
      expect(restored.sendShortcut, preferences.sendShortcut);
      expect(restored.locale, preferences.locale);
      expect(restored.font, preferences.font);
      expect(restored.documentationOutputDirectory, '/tmp/sendreq-docs');
      expect(restored.customSendShortcut, preferences.customSendShortcut);
    },
  );

  test(
    'shared preferences migrates the old JSON after creating a backup',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp('sendreq-prefs-');
      addTearDown(() => directory.delete(recursive: true));
      const legacyPreferences = WorkspacePreferences(
        appearance: AppearancePreference.system,
        sendShortcut: SendShortcutPreference.controlSpace,
        locale: LocalePreference.simplifiedChinese,
      );
      final legacyStore = FileWorkspacePreferenceStore(
        configurationDirectory: directory,
      );
      await legacyStore.save(legacyPreferences);
      final store = SharedPreferencesWorkspacePreferenceStore.fromPreferences(
        await SharedPreferences.getInstance(),
        legacyStore: legacyStore,
      );

      final migrated = await store.load();

      expect(migrated.appearance, AppearancePreference.system);
      expect(migrated.sendShortcut, SendShortcutPreference.controlSpace);
      expect(migrated.locale, LocalePreference.simplifiedChinese);
      expect(
        await directory.list().any((item) => item.path.endsWith('.bak')),
        isTrue,
      );
    },
  );

  test(
    'shared preferences reports invalid legacy JSON without marking migration',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'sendreq-prefs-bad-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = File('${directory.path}/preferences.json');
      await source.writeAsString('{ invalid json');
      final store = SharedPreferencesWorkspacePreferenceStore.fromPreferences(
        await SharedPreferences.getInstance(),
        legacyStore: FileWorkspacePreferenceStore(
          configurationDirectory: directory,
        ),
      );

      final loaded = await store.load();

      expect(loaded, hasDefaults);
      expect(store.migrationIssue, isA<FormatException>());
      expect(await source.readAsString(), '{ invalid json');
    },
  );

  // 验证基于文件存储的偏好设置具备持久化能力：保存后可从磁盘完整还原。
  test('file preference store restores a saved snapshot', () async {
    // 在临时目录中运行，避免污染真实用户配置目录。
    final directory = await Directory.systemTemp.createTemp('sendreq-prefs-');
    addTearDown(() => directory.delete(recursive: true));
    final store = FileWorkspacePreferenceStore(
      configurationDirectory: directory,
    );
    const preferences = WorkspacePreferences(
      appearance: AppearancePreference.light,
      sendShortcut: SendShortcutPreference.custom,
      font: WorkspaceFontPreference.notoSans,
      documentationOutputDirectory: '/tmp/sendreq-api-docs',
      customSendShortcut: ShortcutBinding(
        keyId: 0x00000000064,
        keyLabel: 'D',
        control: true,
        shift: true,
      ),
    );

    await store.save(preferences);
    final restored = await store.load();

    expect(restored.appearance, AppearancePreference.light);
    expect(restored.sendShortcut, SendShortcutPreference.custom);
    expect(restored.font, WorkspaceFontPreference.notoSans);
    expect(restored.customSendShortcut.label, 'Ctrl+Shift+D');
    expect(restored.documentationOutputDirectory, '/tmp/sendreq-api-docs');
  });

  test(
    'file preference store falls back for missing or invalid content',
    () async {
      final directory = await Directory.systemTemp.createTemp('sendreq-prefs-');
      addTearDown(() => directory.delete(recursive: true));
      final store = FileWorkspacePreferenceStore(
        configurationDirectory: directory,
      );

      // 配置文件不存在时应回退到默认值。
      expect(await store.load(), hasDefaults);
      // 写入损坏的 JSON 内容，验证解析失败同样安全回退到默认值而非抛错。
      await File(
        '${directory.path}/preferences.json',
      ).writeAsString('not json');
      expect(await store.load(), hasDefaults);
    },
  );

  // 设置变更会即时作用于当前会话，但只有显式保存才会写入本地存储。
  test('workspace persists preferences only after explicit save', () async {
    final store = InMemoryWorkspacePreferenceStore();
    final viewModel = workspaceViewModel(preferenceStore: store);

    expect(await store.load(), hasDefaults);
    viewModel.updateAppearance(AppearancePreference.system);
    viewModel.updateSendShortcut(SendShortcutPreference.controlSpace);
    viewModel.updateDocumentationOutputDirectory('/tmp/sendreq-api-docs');
    expect(await store.load(), hasDefaults);
    expect(viewModel.hasPreferenceChanges, isTrue);

    await viewModel.savePreferences();
    final restored = await store.load();

    expect(restored.appearance, AppearancePreference.system);
    expect(restored.sendShortcut, SendShortcutPreference.controlSpace);
    expect(restored.documentationOutputDirectory, '/tmp/sendreq-api-docs');
    // 显式保存成功后“存在未保存修改”标记应被清除。
    expect(viewModel.hasPreferenceChanges, isFalse);
    viewModel.dispose();
  });

  test(
    'custom shortcuts reject reserved bindings and persist valid bindings',
    () async {
      final store = InMemoryWorkspacePreferenceStore();
      final viewModel = workspaceViewModel(preferenceStore: store);
      const reserved = ShortcutBinding(
        keyId: 0x0000000006b,
        keyLabel: 'K',
        control: true,
      );
      const custom = ShortcutBinding(
        keyId: 0x00000000064,
        keyLabel: 'D',
        control: true,
        shift: true,
      );

      expect(viewModel.updateCustomSendShortcut(reserved), isFalse);
      expect(viewModel.updateCustomSendShortcut(custom), isTrue);
      expect(viewModel.sendShortcut, SendShortcutPreference.custom);
      expect(viewModel.sendShortcutLabel, 'Ctrl+Shift+D');

      await viewModel.savePreferences();
      final restored = await store.load();
      expect(restored.sendShortcut, SendShortcutPreference.custom);
      expect(restored.customSendShortcut, custom);
      viewModel.dispose();
    },
  );

  test(
    'custom output directory and recorded shortcut persist to the file store',
    () async {
      final configuration = await Directory.systemTemp.createTemp(
        'sendreq-config-',
      );
      final output = Directory(
        '${configuration.path}${Platform.pathSeparator}docs',
      );
      addTearDown(() => configuration.delete(recursive: true));
      final store = FileWorkspacePreferenceStore(
        configurationDirectory: configuration,
      );
      final viewModel = workspaceViewModel(preferenceStore: store);
      const shortcut = ShortcutBinding(
        keyId: 0x00000000064,
        keyLabel: 'D',
        control: true,
        shift: true,
      );

      viewModel.updateDocumentationOutputDirectory(output.path);
      expect(viewModel.updateCustomSendShortcut(shortcut), isTrue);
      await viewModel.savePreferences();
      final restored = await store.load();

      expect(restored.documentationOutputDirectory, output.path);
      expect(restored.sendShortcut, SendShortcutPreference.custom);
      expect(restored.customSendShortcut, shortcut);
      expect(await output.exists(), isTrue);
      viewModel.dispose();
    },
  );

  test(
    'documentation output directory defaults to the system Documents folder',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'sendreq-documents-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final documents = Directory(
        '${temporary.path}${Platform.pathSeparator}Documents',
      );
      final defaultDirectory =
          await DocumentationOutputDirectory.defaultPathForCurrentUser(
            documentsDirectory: () async => documents,
          );
      final viewModel = workspaceViewModel(
        defaultDocumentationOutputDirectory: defaultDirectory,
      );

      expect(viewModel.documentationOutputDirectory, defaultDirectory);
      expect(
        defaultDirectory,
        '${documents.path}${Platform.pathSeparator}sendreq',
      );

      viewModel.updateDocumentationOutputDirectory('/tmp/sendreq-api-docs');
      viewModel.updateDocumentationOutputDirectory(null);
      expect(viewModel.documentationOutputDirectory, defaultDirectory);

      viewModel.resetPreferences();
      expect(viewModel.documentationOutputDirectory, defaultDirectory);
      viewModel.dispose();
    },
  );

  test('documentation output directory creates a requested folder', () async {
    final temporary = await Directory.systemTemp.createTemp('sendreq-docs-');
    final output = Directory('${temporary.path}${Platform.pathSeparator}api');
    addTearDown(() => temporary.delete(recursive: true));

    final created = await DocumentationOutputDirectory.ensureExists(
      output.path,
    );

    expect(created.path, output.path);
    expect(await output.exists(), isTrue);
  });

  test('documentation output directory is recreated after removal', () async {
    final temporary = await Directory.systemTemp.createTemp('sendreq-docs-');
    final output = Directory('${temporary.path}${Platform.pathSeparator}api');
    addTearDown(() => temporary.delete(recursive: true));

    await DocumentationOutputDirectory.ensureExists(output.path);
    await output.delete(recursive: true);
    await DocumentationOutputDirectory.ensureExists(output.path);

    expect(await output.exists(), isTrue);
  });

  test(
    'view model recreates the active documentation directory before use',
    () async {
      final temporary = await Directory.systemTemp.createTemp('sendreq-docs-');
      final output = Directory('${temporary.path}${Platform.pathSeparator}api');
      addTearDown(() => temporary.delete(recursive: true));
      final viewModel = workspaceViewModel(
        defaultDocumentationOutputDirectory: output.path,
      );

      await viewModel.ensureDocumentationOutputDirectory();
      await output.delete(recursive: true);
      final ensured = await viewModel.ensureDocumentationOutputDirectory();

      expect(ensured, output.path);
      expect(await output.exists(), isTrue);
      viewModel.dispose();
    },
  );

  test(
    'default output uses the platform-provided Documents directory',
    () async {
      final temporary = await Directory.systemTemp.createTemp('sendreq-docs-');
      addTearDown(() => temporary.delete(recursive: true));
      final documentsDirectories = <Directory>[
        Directory(
          '${temporary.path}${Platform.pathSeparator}Windows Documents',
        ),
        Directory('${temporary.path}${Platform.pathSeparator}macOS Documents'),
        Directory('${temporary.path}${Platform.pathSeparator}Linux Documents'),
      ];

      for (final documents in documentsDirectories) {
        final output =
            await DocumentationOutputDirectory.defaultPathForCurrentUser(
              documentsDirectory: () async => documents,
            );
        expect(output, '${documents.path}${Platform.pathSeparator}sendreq');
      }
    },
  );

  test(
    'OpenAPI file export writes a timestamped JSON into the output folder',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'sendreq-openapi-',
      );
      addTearDown(() => temporary.delete(recursive: true));

      final file = await const OpenApiFileExporter().export(
        outputDirectory: '${temporary.path}${Platform.pathSeparator}sendreq',
        source: '{"openapi":"3.0.3"}',
        now: DateTime.utc(2026, 8, 7, 9, 30),
      );

      expect(file.path, endsWith('openapi-20260807T093000000Z.json'));
      expect(await file.readAsString(), '{"openapi":"3.0.3"}');
    },
  );

  test(
    'OpenAPI export does not overwrite an existing timestamped document',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'sendreq-openapi-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      const exporter = OpenApiFileExporter();
      final output = '${temporary.path}${Platform.pathSeparator}sendreq';
      final timestamp = DateTime.utc(2026, 8, 7, 9, 30);

      final first = await exporter.export(
        outputDirectory: output,
        source: '{"openapi":"3.0.3"}',
        now: timestamp,
      );
      final second = await exporter.export(
        outputDirectory: output,
        source: '{"openapi":"3.1.0"}',
        now: timestamp,
      );

      expect(first.path, isNot(second.path));
      expect(second.path, endsWith('-1.json'));
      expect(await first.readAsString(), '{"openapi":"3.0.3"}');
      expect(await second.readAsString(), '{"openapi":"3.1.0"}');
    },
  );

  // 验证保存失败时修改标记保持“脏”状态，并给出可重试的提示信息，便于用户再次尝试。
  test('workspace keeps preference changes dirty when saving fails', () async {
    final viewModel = workspaceViewModel(preferenceStore: _FailingStore());
    viewModel.updateAppearance(AppearancePreference.light);

    await viewModel.savePreferences();

    expect(viewModel.hasPreferenceChanges, isTrue);
    expect(viewModel.lastActionMessage, 'Could not save preferences. Retry.');
    viewModel.dispose();
  });
}

/// 自定义匹配器：校验偏好设置对象是否与文档化默认值一致（深色外观 + Control+Enter 发送）。
const hasDefaults = _WorkspacePreferenceMatcher();

class _WorkspacePreferenceMatcher extends Matcher {
  const _WorkspacePreferenceMatcher();

  @override
  Description describe(Description description) =>
      description.add('the documented workspace preference defaults');

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) =>
      item is WorkspacePreferences &&
      item.appearance == AppearancePreference.dark &&
      item.sendShortcut == SendShortcutPreference.controlEnter;
}

/// 注入式失败存储：save 恒抛异常，用于验证视图模型的保存失败处理路径。
class _FailingStore implements WorkspacePreferenceStore {
  @override
  Future<WorkspacePreferences> load() async => WorkspacePreferences.defaults;

  @override
  Future<void> save(WorkspacePreferences preferences) =>
      Future<void>.error(StateError('disk unavailable'));
}
