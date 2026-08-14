import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendreq/app/sendreq_app.dart';
import 'package:sendreq/ui/core/theme/code_text_theme.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/form_control_metrics.dart';
import 'package:sendreq/data/repositories/in_memory_api_asset_repository.dart';
import 'package:sendreq/data/repositories/in_memory_workspace_preference_store.dart';
import 'package:sendreq/data/demo/demo_example_catalog.dart';
import 'package:sendreq/data/services/demo_request_execution_runtime.dart';
import 'package:sendreq/domain/api_assets/api_asset_models.dart';
import 'package:sendreq/domain/workspace/workspace_models.dart';
import 'package:sendreq/domain/preferences/workspace_preferences.dart';
import 'package:sendreq/domain/request_runtime/request_execution_runtime.dart';
import 'package:sendreq/domain/repositories/workspace_preference_store.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_panel.dart';
import 'package:sendreq/ui/features/settings/widgets/settings_controls.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';

import 'support/workspace_view_model_test_factory.dart';
import 'support/app_update_fakes.dart';

// 工作台核心交互的组件测试：覆盖偏好、Requests、Environment 上下文与 Mock。
void main() {
  testWidgets('three-tool shell stays focused and stable at target widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const SendreqApp());
      await tester.pumpAndSettle();

      final requests = find.byKey(const ValueKey('request-working-view-all'));
      final mock = find.byKey(const ValueKey('tool-navigation-mock'));
      final settings = find.byKey(const ValueKey('tool-navigation-settings'));
      expect(requests, findsOneWidget);
      expect(mock, findsOneWidget);
      expect(settings, findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('tool-navigation-rail'))).width,
        width < 900 ? 56 : 184,
      );
      final buttonWidth = tester.getRect(requests).width;
      expect(tester.getRect(settings).bottom, greaterThan(740));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);

      await tester.tap(mock);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('mock-create-manual-action')),
        findsOneWidget,
      );
      expect(tester.getRect(mock).width, buttonWidth);

      await tester.tap(settings);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-single-surface')), findsOneWidget);
      expect(tester.getRect(settings).width, buttonWidth);
    }
  });

  testWidgets('Environment manage uses a local drawer on wide Requests', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SendreqApp());
    await tester.pumpAndSettle();

    await _openEnvironmentManager(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('environment-manage-drawer')), findsOneWidget);
    expect(find.byKey(const Key('environment-manage-stage')), findsNothing);
    expect(
      find.byKey(const Key('collection-desktop-workspace')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(300, 320));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('environment-manage-drawer')), findsNothing);
  });

  testWidgets('Environment outside click and Escape share dirty close guard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SendreqApp());
    await tester.pumpAndSettle();

    await _openEnvironmentManager(tester);
    await tester.tap(find.byKey(const ValueKey('new-environment-button')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('environment-name-input')),
      'Close guard',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create environment'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(300, 320));
    await tester.pumpAndSettle();
    expect(find.text('Apply environment changes?'), findsOneWidget);
    expect(find.byKey(const Key('environment-manage-drawer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('environment-close-keep-editing')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('environment-manage-drawer')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Apply environment changes?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('environment-close-discard')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('environment-manage-drawer')), findsNothing);
  });

  testWidgets('protocol working view keeps the active request stable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SendreqApp());
    await tester.pumpAndSettle();

    final urlField = tester.widget<TextFormField>(
      find.byKey(const Key('request-url-text-field')),
    );
    final activeUrl = urlField.controller!.text;
    final collection = find.byKey(const Key('collection-panel'));
    expect(find.byKey(const Key('collection-protocol-filter')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('request-working-view-grpc')));
    await tester.pumpAndSettle();
    final filteredPills = tester.widgetList<RequestKindPill>(
      find.descendant(of: collection, matching: find.byType(RequestKindPill)),
    );
    expect(filteredPills, isNotEmpty);
    expect(
      filteredPills.every((pill) => pill.protocol == ApiRequestProtocol.grpc),
      isTrue,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('request-url-text-field')),
          )
          .controller!
          .text,
      activeUrl,
    );

    await tester.tap(find.byKey(const ValueKey('request-working-view-all')));
    await tester.pumpAndSettle();
    final allProtocols = tester
        .widgetList<RequestKindPill>(
          find.descendant(
            of: collection,
            matching: find.byType(RequestKindPill),
          ),
        )
        .map((pill) => pill.protocol)
        .toSet();
    expect(allProtocols, containsAll(ApiRequestProtocol.values));
  });

  testWidgets('Environment manage uses a stage on narrow Requests', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SendreqApp());
    await tester.pumpAndSettle();

    await _openEnvironmentManager(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('environment-manage-stage')), findsOneWidget);
    expect(find.byKey(const Key('environment-manage-drawer')), findsNothing);
  });

  testWidgets('Environment stays available without an active request', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(
        workspaceDependencies: workspaceTestDependencies(
          assetRepository: InMemoryApiAssetRepository(collections: const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final contextControl = find.byKey(const Key('environment-context-control'));
    expect(contextControl, findsOneWidget);
    expect(find.text('ENV'), findsOneWidget);
    expect(find.text('No requests yet'), findsOneWidget);

    await _openEnvironmentManager(tester);

    expect(find.byKey(const Key('environment-manage-stage')), findsOneWidget);
    expect(find.text('Environment variables'), findsOneWidget);
  });

  // 场景：偏好设置为简体中文时，请求配置面板与集合上下文菜单应显示中文提示。
  // 通过删除确认弹窗中的计数文案，验证本地化词条在真实交互中生效。
  testWidgets(
    'request configuration and collection prompts localize in Chinese',
    (tester) async {
      // 将测试画布固定为 1440x900 桌面尺寸并复位 DPR，保证三栏布局完整渲染。
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        SendreqApp(
          workspaceDependencies: workspaceTestDependencies(
            preferenceStore: InMemoryWorkspacePreferenceStore(
              const WorkspacePreferences(
                appearance: AppearancePreference.dark,
                locale: LocalePreference.simplifiedChinese,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('参数'), findsOneWidget);
      expect(find.text('正文'), findsNothing);
      // 右键集合节点弹出上下文菜单，点击“删除”以触发中文删除确认弹窗。
      await tester.tapAt(
        tester.getCenter(find.text('Sendreq Demo Example')),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.text('删除 Sendreq Demo Example 及其 15 个请求？'), findsOneWidget);
    },
  );

  // 场景：启动时读取已保存的偏好，应以浅色外观初始化工作区。
  testWidgets('saved preferences initialize the workspace appearance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(
        executionRuntime: DemoRequestExecutionRuntime(),
        workspaceDependencies: workspaceTestDependencies(
          preferenceStore: InMemoryWorkspacePreferenceStore(
            const WorkspacePreferences(appearance: AppearancePreference.light),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      Theme.of(
        tester.element(find.byType(Scaffold)),
      ).extension<ChakraSemanticTokens>(),
      same(ChakraSemanticTokens.light),
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    final appearance = tester.widget<SettingsOptionGroup<AppearancePreference>>(
      find.byWidgetPredicate(
        (widget) => widget is SettingsOptionGroup<AppearancePreference>,
      ),
    );
    expect(appearance.selected, AppearancePreference.light);
  });

  // 场景：在设置页切换外观主题后，全局配色与 Scaffold 亮度应同步更新。
  testWidgets('settings changes the active appearance palette', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    expect(
      Theme.of(
        tester.element(find.byType(Scaffold)),
      ).extension<ChakraSemanticTokens>(),
      same(ChakraSemanticTokens.dark),
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(
      Theme.of(
        tester.element(find.byType(Scaffold)),
      ).extension<ChakraSemanticTokens>(),
      same(ChakraSemanticTokens.light),
    );
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
    expect(find.text('Save preferences'), findsNothing);
  });

  testWidgets('settings exposes fixed auto-save failure and retry status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _FailOncePreferenceStore();

    await tester.pumpWidget(
      SendreqApp(
        workspaceDependencies: workspaceTestDependencies(
          preferenceStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    final status = find.byKey(const Key('settings-persistence-status'));
    expect(find.text('Saved automatically'), findsOneWidget);
    final savedSize = tester.getSize(status);

    await tester.tap(find.byKey(const Key('settings-appearance-light')));
    await tester.pumpAndSettle();

    expect(find.text('Save failed'), findsOneWidget);
    expect(find.byKey(const Key('settings-retry-save')), findsOneWidget);
    expect(tester.getSize(status), savedSize);

    await tester.tap(find.byKey(const Key('settings-retry-save')));
    await tester.pumpAndSettle();

    expect(find.text('Saved automatically'), findsOneWidget);
    expect(find.byKey(const Key('settings-retry-save')), findsNothing);
    expect(tester.getSize(status), savedSize);
    expect(store.saved.single.appearance, AppearancePreference.light);
  });

  testWidgets('every setting updates the app and survives a restart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = InMemoryWorkspacePreferenceStore();

    await tester.pumpWidget(
      SendreqApp(
        workspaceDependencies: workspaceTestDependencies(
          preferenceStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-interface-font-noto')));
    await tester.pumpAndSettle();
    expect(
      Theme.of(
        tester.element(find.byType(Scaffold)),
      ).textTheme.bodyMedium?.fontFamily,
      'Noto Sans',
    );

    await tester.tap(find.byKey(const Key('settings-code-font-system')));
    await tester.pumpAndSettle();
    expect(
      Theme.of(
        tester.element(find.byType(Scaffold)),
      ).extension<CodeTextTheme>()?.fontFamily,
      'monospace',
    );

    final slider = find.byKey(const Key('code-font-size-slider'));
    await tester.drag(slider, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(
      Theme.of(
        tester.element(find.byType(Scaffold)),
      ).extension<CodeTextTheme>()?.fontSize,
      18,
    );

    await tester.tap(find.byKey(const Key('settings-locale-zh')));
    await tester.pumpAndSettle();
    expect(find.text('本地工作区偏好'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      SendreqApp(
        workspaceDependencies: workspaceTestDependencies(
          preferenceStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Noto Sans');
    expect(theme.extension<CodeTextTheme>()?.fontFamily, 'monospace');
    expect(theme.extension<CodeTextTheme>()?.fontSize, 18);
    expect(find.byTooltip('设置'), findsOneWidget);
  });

  testWidgets('reset restores every domain preference default', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(
        workspaceDependencies: workspaceTestDependencies(
          preferenceStore: InMemoryWorkspacePreferenceStore(
            const WorkspacePreferences(
              appearance: AppearancePreference.light,
              locale: LocalePreference.english,
              font: WorkspaceFontPreference.notoSans,
              codeFont: CodeFontPreference.system,
              codeFontSize: 18,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reset defaults'));
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.brightness, Brightness.dark);
    expect(theme.textTheme.bodyMedium?.fontFamily, isNot('Noto Sans'));
    final interfaceFont = tester
        .widget<SettingsOptionGroup<WorkspaceFontPreference>>(
          find.byWidgetPredicate(
            (widget) => widget is SettingsOptionGroup<WorkspaceFontPreference>,
          ),
        );
    expect(interfaceFont.selected, WorkspacePreferences.defaults.font);
    expect(
      theme.extension<CodeTextTheme>()?.fontFamily,
      WorkspacePreferences.defaults.codeFont.family,
    );
    expect(
      theme.extension<CodeTextTheme>()?.fontSize,
      WorkspacePreferences.defaults.codeFontSize,
    );
  });

  // 场景：跟随系统时，Material 主题和 Chakra 语义令牌必须在系统亮度变化后同步。
  testWidgets('system appearance synchronizes the semantic palette', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      SendreqApp(
        workspaceDependencies: workspaceTestDependencies(
          preferenceStore: InMemoryWorkspacePreferenceStore(
            const WorkspacePreferences(appearance: AppearancePreference.system),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      Theme.of(
        tester.element(find.byType(Scaffold)),
      ).extension<ChakraSemanticTokens>(),
      same(ChakraSemanticTokens.light),
    );
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();

    expect(
      Theme.of(
        tester.element(find.byType(Scaffold)),
      ).extension<ChakraSemanticTokens>(),
      same(ChakraSemanticTokens.dark),
    );
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
  });

  // 场景：在设置页切换语言时，所有设置项标签应整体在中英文之间切换。
  testWidgets(
    'settings switches every setting label between English and Chinese',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simplified Chinese'));
      await tester.pumpAndSettle();

      expect(find.text('设置'), findsWidgets);
      expect(find.text('本地工作区偏好'), findsOneWidget);
      expect(find.text('外观'), findsOneWidget);
      expect(find.text('语言'), findsOneWidget);
      expect(find.text('简体中文'), findsOneWidget);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsWidgets);
    },
  );

  // 场景：下拉菜单中的 HTTP 方法、WebSocket、gRPC 是平铺的独立请求类型。
  testWidgets('request kinds are flat and independently selectable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('request-kind-selector')), findsOneWidget);
    await tester.tap(find.byKey(const Key('request-kind-selector')));
    await tester.pumpAndSettle();
    for (final kind in [
      'get',
      'post',
      'put',
      'patch',
      'delete',
      'websocket',
      'grpc',
    ]) {
      expect(find.byKey(Key('request-kind-option-$kind')), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('request-kind-option-post')));
    await tester.pumpAndSettle();
    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('protocol switching keeps the endpoint rail geometry stable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    final urlInput = find.byKey(const Key('request-url-input'));
    final actionSlot = find.byKey(const Key('request-action-slot'));
    final initialUrlRect = tester.getRect(urlInput);
    final initialActionRect = tester.getRect(actionSlot);

    for (final requestKind in [
      const Key('request-kind-option-websocket'),
      const Key('request-kind-option-grpc'),
      const Key('request-kind-option-post'),
      const Key('request-kind-option-get'),
    ]) {
      await tester.tap(find.byKey(const Key('request-kind-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(requestKind));
      await tester.pumpAndSettle();
      expect(tester.getRect(urlInput), initialUrlRect);
      expect(tester.getRect(actionSlot), initialActionRect);
    }
  });

  testWidgets('endpoint input owns the full composer width', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    final composer = tester.getRect(find.byKey(const Key('request-url-bar')));
    final input = tester.getRect(find.byKey(const Key('request-url-input')));
    final requestKind = tester.getRect(
      find.byKey(const Key('request-kind-selector')),
    );
    final action = tester.getRect(find.byKey(const Key('request-action-slot')));

    expect(input.width, greaterThanOrEqualTo(composer.width - 20));
    expect(input.width, greaterThan(requestKind.width + action.width * 2));
    expect(input.height, 40);
  });

  // 场景：选择 gRPC 后必须进入独立 proto 配置流，不能错误复用 HTTP Body 或 WebSocket 子协议。
  testWidgets('request editor routes gRPC to its proto configuration', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('request-kind-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('request-kind-option-grpc')));
    await tester.pumpAndSettle();

    expect(find.text('gRPC configuration'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(
          const Key('collection-request-kind-demo-rest-list-users'),
        ),
        matching: find.text('gRPC'),
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Import .proto'),
      findsOneWidget,
    );
    expect(find.text('No .proto file selected'), findsOneWidget);
    expect(find.text('Params'), findsNothing);
    expect(find.text('Metadata'), findsOneWidget);
    expect(find.text('Proto'), findsOneWidget);
    await tester.tap(find.text('Message'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('grpc-message-editor')), findsOneWidget);
    expect(find.text('REQUEST MESSAGE'), findsOneWidget);
    expect(find.text('Query parameters'), findsNothing);
  });

  // 场景：在窄桌面宽度下，设置页的语言控件应自适应布局而不会被压缩丢失。
  testWidgets('settings adapts its language controls to a narrow desktop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(680, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Simplified Chinese'), findsOneWidget);
  });

  // 场景：Enter 通过全局发送命令执行当前 REST 请求。
  testWidgets('Enter sends the active REST request', (tester) async {
    // 固定测试画布，避免桌面三栏布局在默认测试尺寸下被压缩。
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    expect(find.text('No response yet'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Execution result for this request'), findsOneWidget);
    expect(find.text('200'), findsWidgets);
  });

  testWidgets('Ctrl+S saves the active request and flushes persistence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FlushRecordingApiAssetRepository.demo();
    await tester.pumpWidget(
      SendreqApp(
        executionRuntime: DemoRequestExecutionRuntime(),
        workspaceDependencies: workspaceTestDependencies(
          assetRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('request-url-text-field')),
      'https://saved.example.test/users',
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(repository.flushCalls, 1);
    expect(
      repository.getRequest('demo-rest-list-users').urlTemplate,
      'https://saved.example.test/users',
    );
  });

  testWidgets('settings checks GitHub releases on every click', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final releases = FakeAppReleaseRepository(version: 'v0.2.0');
    final launcher = FakeExternalReleaseLauncher();
    await tester.pumpWidget(
      SendreqApp(
        appReleaseRepository: releases,
        installedAppVersionProvider: const FakeInstalledAppVersionProvider(
          '0.1.0',
        ),
        externalReleaseLauncher: launcher,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-check-updates')));
    await tester.pumpAndSettle();
    expect(find.text('Version v0.2.0 is available.'), findsOneWidget);
    expect(releases.calls, 1);

    await tester.tap(find.byKey(const Key('settings-check-updates')));
    await tester.pumpAndSettle();
    expect(releases.calls, 2);
    await tester.tap(find.byKey(const Key('settings-update-now')));
    await tester.pumpAndSettle();
    expect(
      launcher.opened,
      Uri.parse('https://github.com/kzzan/sendreq/releases/latest'),
    );
  });

  testWidgets('response body formats valid JSON and can switch to raw', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Send').first);
    await tester.pumpAndSettle();

    expect(find.text('Valid JSON'), findsOneWidget);
    expect(find.byKey(const Key('response-summary-strip')), findsOneWidget);
    expect(find.byKey(const Key('response-status-readout')), findsOneWidget);
    expect(find.byKey(const Key('response-body-viewer')), findsOneWidget);
    // JSON 使用单一代码画布；不渲染额外行号栏，避免短响应视觉偏移。
    expect(find.byKey(const Key('response-json-line-numbers')), findsNothing);
    expect(find.byKey(const Key('response-json-tree')), findsOneWidget);
    expect(
      find.byKey(const Key('response-body-horizontal-scroll')),
      findsOneWidget,
    );
    final viewerRect = tester.getRect(
      find.byKey(const Key('response-body-viewer')),
    );
    final toolbarRect = tester.getRect(
      find.byKey(const Key('response-body-format-toggle')),
    );
    final viewportRect = tester.getRect(
      find.byKey(const Key('response-body-viewport')),
    );
    final formattedJson = _responseJsonTreeText(tester);
    // 代码树由每层固定的两空格等价步距渲染，缩进不使用 Tab。
    expect(
      formattedJson,
      contains(
        '"items": [\n'
        '{\n'
        '"id": "usr_1001",\n'
        '"role": "admin"\n'
        '},',
      ),
    );
    expect(formattedJson, isNot(contains('\t')));
    expect(
      tester
          .getCenter(
            find.byKey(const Key('response-json-toggle-root.items[0]')),
          )
          .dx,
      greaterThan(
        tester
                .getCenter(find.byKey(const Key('response-json-toggle-root')))
                .dx +
            24,
      ),
    );
    await tester.tap(find.byKey(const Key('response-json-toggle-root.items')));
    await tester.pump();
    expect(_responseJsonTreeText(tester), isNot(contains('"id": "usr_1001"')));
    expect(_responseJsonTreeText(tester), contains('"items": [...]'));
    await tester.tap(find.byKey(const Key('response-json-toggle-root.items')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('response-json-toggle-root.items[0]')),
    );
    await tester.pump();
    expect(_responseJsonTreeText(tester), isNot(contains('"id": "usr_1001"')));
    expect(_responseJsonTreeText(tester), contains('{...},'));
    final formatToggle = find.byKey(const Key('response-body-format-toggle'));
    expect(formatToggle, findsOneWidget);
    await tester.tap(formatToggle);
    await tester.pump();
    expect(
      find.byKey(const Key('response-body-horizontal-scroll')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('response-raw-wrapped-text')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('response-body-viewer'))),
      viewerRect,
    );
    expect(
      tester.getRect(find.byKey(const Key('response-body-format-toggle'))),
      toolbarRect,
    );
    expect(
      tester.getRect(find.byKey(const Key('response-body-viewport'))),
      viewportRect,
    );
  });

  testWidgets('response JSON tree controls localize in Chinese', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(
        executionRuntime: DemoRequestExecutionRuntime(),
        workspaceDependencies: workspaceTestDependencies(
          preferenceStore: InMemoryWorkspacePreferenceStore(
            const WorkspacePreferences(
              appearance: AppearancePreference.dark,
              locale: LocalePreference.simplifiedChinese,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '发送').first);
    await tester.pumpAndSettle();

    expect(find.byTooltip('收起 JSON 节点'), findsWidgets);
  });

  // 场景：宽屏布局下应只有唯一的 Send 主按钮，避免出现重复的发送入口。
  testWidgets('wide request workspace keeps a single primary send action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Send'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Send request'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();

    expect(find.text('Execution result for this request'), findsOneWidget);
  });

  // 场景：URL 含未定义变量时发送应被禁用，并提供跳转环境配置的入口；
  // 返回请求编辑页后，已输入的草稿内容不应丢失。
  testWidgets('missing variables open Environment and preserve the request', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    // 输入包含未定义变量 {{missingHost}} 的 URL，触发缺失变量校验。
    const draftUrl = '{{missingHost}}/health';
    await tester.enterText(
      find.byKey(const Key('request-url-input')),
      draftUrl,
    );
    await tester.pump();

    expect(
      find.text('Missing environment variables: missingHost'),
      findsOneWidget,
    );
    final send = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Send').first,
    );
    expect(send.onPressed, isNull);

    await tester.tap(find.widgetWithText(TextButton, 'Open environment'));
    await tester.pump();
    expect(find.text('Environment variables'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Back to request'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Back to request'));
    await tester.pump();
    expect(find.text('List users *'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('request-url-text-field')),
          )
          .controller!
          .text,
      draftUrl,
    );
  });

  // 环境页采用“环境上下文 + 变量表”布局，切换环境与密钥揭示不应丢失编辑能力。
  testWidgets('environment workspace switches profiles and reveals secrets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await _openEnvironmentManager(tester);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('environment-value-staging-token-true')),
      findsOneWidget,
    );
    final protectedTokenKey = find.byKey(
      const ValueKey('environment-key-staging-token'),
    );
    final protectedKeyInput = find.descendant(
      of: protectedTokenKey,
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(protectedKeyInput).readOnly, isTrue);
    final protectedDelete = find.ancestor(
      of: find.byIcon(Icons.lock_outline).last,
      matching: find.byType(IconButton),
    );
    expect(protectedDelete, findsOneWidget);
    expect(tester.widget<IconButton>(protectedDelete).onPressed, isNull);

    final toggleSecret = find.byTooltip('Show or hide secret');
    await tester.ensureVisible(toggleSecret);
    await tester.tap(toggleSecret);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('environment-value-staging-token-false')),
      findsOneWidget,
    );

    await tester.tap(find.text('Production'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('environment-value-production-token-true')),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Add variable'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('environment-key-variable-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('add-global-variable-button')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('environment-key-variable-2')),
      findsOneWidget,
    );

    final baseUrlKey = find.byKey(
      const ValueKey('environment-key-production-base-url'),
    );
    final baseUrlKeyInput = find.descendant(
      of: baseUrlKey,
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(baseUrlKeyInput).readOnly, isTrue);
  });

  testWidgets('environment authentication immediately binds credential rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await _openEnvironmentManager(tester);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('environment-authentication-type')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basic auth'));
    await tester.pumpAndSettle();
    expect(find.text('Switch authentication method?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('environment-key-staging-token')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('environment-authentication-type')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basic auth'));
    await tester.pumpAndSettle();
    expect(find.text('Switch authentication method?'), findsOneWidget);
    await tester.tap(find.text('Switch authentication'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('environment-key-staging-token')),
      findsNothing,
    );

    const usernameId = 'authentication-staging-username';
    const passwordId = 'authentication-staging-password';
    expect(
      find.byKey(const ValueKey('environment-auth-binding-$usernameId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('environment-auth-binding-$passwordId')),
      findsOneWidget,
    );
    final usernameKey = find.byKey(
      const ValueKey('environment-key-$usernameId'),
    );
    final usernameInput = find.descendant(
      of: usernameKey,
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(usernameInput).readOnly, isTrue);
    expect(
      find.byKey(const ValueKey('environment-value-$passwordId-true')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('environment-authentication-type')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('API key'));
    await tester.pumpAndSettle();
    expect(find.text('Switch authentication method?'), findsOneWidget);
    await tester.tap(find.text('Switch authentication'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('environment-key-$usernameId')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('environment-key-$passwordId')),
      findsNothing,
    );
    const apiKeyId = 'authentication-staging-apiKey';
    expect(
      find.byKey(const ValueKey('environment-auth-binding-$apiKeyId')),
      findsOneWidget,
    );
  });

  testWidgets('environment workspace creates renames and deletes profiles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await _openEnvironmentManager(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-environment-button')));
    await tester.pump();
    final environmentNameInput = find.byKey(
      const Key('environment-name-input'),
    );
    expect(
      tester.getSize(environmentNameInput).height,
      FormControlMetrics.standardHeight,
    );
    await tester.enterText(environmentNameInput, 'Local');
    await tester.tap(find.widgetWithText(FilledButton, 'Create environment'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('environment-actions-environment-1')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('environment-actions-environment-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename environment'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('environment-name-input')),
      'Local development',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(find.text('Local development'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('environment-actions-environment-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete environment'));
    await tester.pump();
    expect(
      find.text('Delete Local development and all of its variables?'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Local development'), findsNothing);
  });

  testWidgets('pending environment changes require an explicit close choice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await _openEnvironmentManager(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-environment-button')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('environment-name-input')),
      'Mock integration',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create environment'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Back to request'));
    await tester.pumpAndSettle();
    expect(find.text('Apply environment changes?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('environment-close-apply')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('environment-context-control')),
      findsOneWidget,
    );
    await _openEnvironmentManager(tester);
    await tester.pumpAndSettle();
    expect(find.text('Environment variables'), findsOneWidget);
  });

  testWidgets(
    'environment variables resolve through a new request into its response',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = _RecordingGeoIpRuntime();
      await tester.pumpWidget(SendreqApp(executionRuntime: runtime));
      await tester.pumpAndSettle();

      // 在环境界面创建当前流程专用的环境；创建只改变编辑目标。
      await _openEnvironmentManager(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('new-environment-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('environment-name-input')),
        'GeoIP UI flow',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create environment'));
      await tester.pumpAndSettle();

      // 在同一张变量表中录入请求主机与查询入参。
      await tester.tap(find.widgetWithText(FilledButton, 'Add variable'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('environment-key-variable-1')),
        'baseUrl',
      );
      await tester.enterText(
        find.byKey(const ValueKey('environment-value-variable-1-false')),
        'https://www.reurl.to',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add variable'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('environment-key-variable-2')),
        'domain',
      );
      await tester.enterText(
        find.byKey(const ValueKey('environment-value-variable-2-false')),
        'qq.com',
      );
      await tester.pumpAndSettle();

      // 执行上下文必须通过独立命令显式切换。
      await tester.tap(find.byKey(const Key('use-environment-for-requests')));
      await tester.pumpAndSettle();

      // 通过界面新建 GET 请求；地址栏会把 query string 同步为 Params 行。
      await tester.tap(find.widgetWithText(OutlinedButton, 'Back to request'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('environment-close-apply')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('new-request-type-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('REST').last);
      await tester.pumpAndSettle();
      const templateUrl = '{{baseUrl}}/tools/geoip/lookup?input={{domain}}';
      await tester.enterText(
        find.byKey(const Key('request-url-input')),
        templateUrl,
      );
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('request-url-text-field')),
            )
            .controller!
            .text,
        templateUrl,
      );
      expect(find.text('input'), findsWidgets);
      expect(find.text('{{domain}}'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, 'Send').first);
      await tester.pumpAndSettle();

      // 运行时收到的是变量已替换的 URL，响应面板随即展示格式化 JSON。
      expect(runtime.resolvedUrls, [
        'https://www.reurl.to/tools/geoip/lookup?input=qq.com',
      ]);
      expect(find.text('Execution result for this request'), findsOneWidget);
      expect(find.textContaining('113.108.81.189'), findsOneWidget);
      expect(find.byKey(const Key('response-body-viewer')), findsOneWidget);
    },
  );

  testWidgets('environment workspace right click exposes lifecycle actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await _openEnvironmentManager(tester);
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('environment-item-staging'))),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('New environment'), findsNothing);
    expect(find.text('Rename environment'), findsOneWidget);
    expect(find.text('Delete environment'), findsOneWidget);
  });

  // 场景：窄桌面宽度下仍保留 Send 按钮，通过顶部分段控件在工作区之间切换。
  testWidgets('narrow desktop retains Send and switches request workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(920, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('request-working-view-all')),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Collections'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Request'), findsOneWidget);
    expect(find.text('Response'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Collections'));
    await tester.pump();
    expect(find.text('Sendreq Demo Example'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Request'));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Send').first);
    await tester.pump();
    await tester.tap(find.text('Response'));
    await tester.pump();

    expect(find.text('Execution result for this request'), findsOneWidget);
  });

  // 场景：375px 视口下，窄屏工作区页签必须完全落在内容区，且仍能切换。
  testWidgets('mobile width keeps workspace tabs within the available pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    final collectionsTab = find.widgetWithText(TextButton, 'Collections');
    final requestTab = find.widgetWithText(TextButton, 'Request');
    final responseTab = find.widgetWithText(TextButton, 'Response');
    expect(collectionsTab, findsOneWidget);
    expect(requestTab, findsOneWidget);
    expect(responseTab, findsOneWidget);

    for (final tab in [collectionsTab, requestTab, responseTab]) {
      expect(tester.getRect(tab).right, lessThanOrEqualTo(375.0));
    }
    await tester.tap(collectionsTab);
    await tester.pumpAndSettle();
    expect(find.text('Sendreq Demo Example'), findsOneWidget);
  });

  testWidgets(
    'Collection keeps its planned workspace structure at target widths',
    (tester) async {
      for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
        );
        await tester.pumpAndSettle();

        if (width < 1240) {
          await tester.tap(find.widgetWithText(TextButton, 'Collections'));
          await tester.pumpAndSettle();
        }

        final collectionPanel = find.byKey(const Key('collection-panel'));
        final environmentSelector = find.byKey(
          const Key('request-topbar-environment-selector'),
        );
        final resourceBrowser = find.byKey(
          const Key('collection-resource-browser'),
        );
        expect(collectionPanel, findsOneWidget);
        expect(environmentSelector, findsOneWidget);
        expect(resourceBrowser, findsOneWidget);
        expect(tester.getRect(collectionPanel).right, lessThanOrEqualTo(width));
        expect(
          tester.getRect(environmentSelector).right,
          lessThanOrEqualTo(width),
        );
        expect(tester.getRect(resourceBrowser).right, lessThanOrEqualTo(width));

        if (width >= 1240) {
          expect(
            find.byKey(const Key('collection-desktop-workspace')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('collection-narrow-workspace')),
            findsNothing,
          );
          expect(tester.getSize(collectionPanel).width, 280);
        } else {
          expect(
            find.byKey(const Key('collection-narrow-workspace')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('collection-desktop-workspace')),
            findsNothing,
          );
          for (final tab in [
            find.widgetWithText(TextButton, 'Collections'),
            find.widgetWithText(TextButton, 'Request'),
            find.widgetWithText(TextButton, 'Response'),
          ]) {
            expect(tester.getRect(tab).right, lessThanOrEqualTo(width));
          }
        }
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );

  testWidgets('Collection exposes node actions without requiring right click', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('collection-menu-collection-sendreq-demo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('request-menu-demo-rest-list-users')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('request-menu-demo-rest-list-users')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('collection-menu-collection-sendreq-demo')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Export API documentation...'), findsOneWidget);
  });

  testWidgets('Collection resource browser exposes localized semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1440, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      SendreqApp(
        workspaceDependencies: workspaceTestDependencies(
          preferenceStore: InMemoryWorkspacePreferenceStore(
            const WorkspacePreferences(
              appearance: AppearancePreference.dark,
              locale: LocalePreference.simplifiedChinese,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('集合资源')), findsOneWidget);
    expect(find.byTooltip('新建请求'), findsOneWidget);
    semantics.dispose();
  });

  // 场景：宽屏显示可读协议导航，且不提供手动尺寸状态。
  testWidgets('far left sidebar exposes protocol views without resize state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    expect(find.text('sendreq'), findsOneWidget);
    expect(find.byTooltip('Collapse sidebar'), findsNothing);
    expect(find.byTooltip('Expand sidebar'), findsNothing);
    expect(find.text('All requests'), findsOneWidget);
    expect(find.text('REST'), findsWidgets);
    expect(find.text('WebSocket'), findsWidgets);
    expect(find.text('gRPC'), findsWidgets);
  });

  // 场景：点击集合树中的请求会打开请求标签页，关闭后对应标签应消失。
  testWidgets('collection selection opens and closes a request tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create user').first);
    await tester.pump();

    expect(find.byTooltip('Close Create user'), findsOneWidget);
    await tester.tap(find.byTooltip('Close Create user'));
    await tester.pump();

    expect(find.byTooltip('Close Create user'), findsNothing);
  });

  // 场景：左键点击文件夹/集合节点可折叠其子节点，再次点击同一节点应展开。
  testWidgets('collection tree left click collapses folders and collections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create user'), findsOneWidget);
    final restFolder = find.byKey(
      const ValueKey('collection-folder-folder-demo-rest'),
    );
    await tester.tap(restFolder);
    await tester.pump();
    expect(find.text('Create user'), findsNothing);

    await tester.tap(find.text('Sendreq Demo Example').first);
    await tester.pump();
    expect(restFolder, findsNothing);

    await tester.tap(find.text('Sendreq Demo Example').first);
    await tester.pump();
    expect(restFolder, findsOneWidget);
  });

  // 场景：第二栏搜索仅临时筛选树，不改变侧栏宽度或用户的展开状态。
  testWidgets('collection search keeps the resource pane stable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    final panel = find.byKey(const Key('collection-panel'));
    final search = find.byKey(const Key('collection-search-input'));
    final initialWidth = tester.getSize(panel).width;

    await tester.enterText(search, 'Create user');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('collection-request-kind-demo-rest-create-user')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('collection-request-kind-demo-rest-list-users')),
      findsNothing,
    );
    expect(tester.getSize(panel).width, initialWidth);

    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('collection-request-kind-demo-rest-list-users')),
      findsOneWidget,
    );
    expect(tester.getSize(panel).width, initialWidth);
  });

  // 场景：右键集合节点应弹出共享的资源操作菜单，并验证重命名结果生效。
  testWidgets('collection tree right click exposes shared resource actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('Sendreq Demo Example').first),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('New request'), findsOneWidget);
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Collapse'), findsNothing);
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Platform APIs');
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();

    expect(find.text('Platform APIs'), findsOneWidget);
  });

  // 场景：确认删除集合后树应进入空态，并可直接创建新集合与新请求。
  testWidgets('collection tree right click can delete a collection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('Sendreq Demo Example').first),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Sendreq Demo Example'), findsNothing);
    expect(find.text('Collections'), findsWidgets);
    expect(find.text('No requests yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('empty-new-request-type-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REST').last);
    await tester.pumpAndSettle();

    expect(find.text('New collection 1'), findsOneWidget);
    expect(find.text('New request 1 *'), findsOneWidget);
    expect(find.byKey(const Key('request-url-input')), findsOneWidget);
  });

  // 场景：右键删除分组只移除该分组，集合与其他协议分组必须继续显示。
  testWidgets('folder right click deletes only the selected group', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(
        find.byKey(const ValueKey('collection-folder-folder-demo-rest')),
      ),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('New request'), findsOneWidget);
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Collapse'), findsNothing);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete group'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Sendreq Demo Example'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('collection-folder-folder-demo-rest')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('collection-folder-folder-demo-websocket')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('collection-folder-folder-demo-grpc')),
      findsOneWidget,
    );
  });

  // 场景：集合右键菜单的“新建分组”应在该集合内创建带递增编号的分组。
  testWidgets('collection menu creates a group in that collection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('Sendreq Demo Example').first),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New group'));
    await tester.pumpAndSettle();

    expect(find.text('New group 4'), findsOneWidget);
  });

  // 场景：请求带未保存修改时删除，应先弹窗让用户明确选择保存后删除。
  testWidgets('deleting a dirty request requires an explicit save decision', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();
    // 先修改 URL 使请求处于未保存状态，再触发删除以测试保存决策弹窗。
    await tester.enterText(
      find.byKey(const Key('request-url-input')),
      'https://example.test/deleted',
    );
    await tester.pump();

    await tester.tapAt(
      tester.getCenter(find.text('List users').first),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Unsaved request changes'), findsOneWidget);
    expect(find.text('Discard and delete'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save and delete'));
    await tester.pumpAndSettle();

    expect(find.text('List users'), findsNothing);
    expect(find.text('Create user'), findsWidgets);
  });

  // 场景：右键单个请求的重命名与删除只作用于该请求，不影响集合内其他请求。
  testWidgets('request right click renames and deletes only that request', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('Create user').first),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Sign in');
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);

    await tester.tapAt(
      tester.getCenter(find.text('Sign in').first),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsNothing);
    expect(find.text('List users'), findsWidgets);
  });

  // 场景：参数表格的表头与请求行应同宽对齐，避免列错位。
  testWidgets('params table header and request rows share one width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    final header = tester.getRect(
      find.byKey(const Key('request-field-table-header')),
    );
    final row = tester.getRect(
      find.byKey(const Key('request-field-row-demo-rest-list-users:param:0')),
    );

    expect(row.left, header.left);
    expect(row.width, header.width);
  });

  // 场景：修改 URL 后当前草稿应立即标记为未保存。
  testWidgets('editing URL marks the active runtime draft dirty', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('request-url-input')),
      'https://example.test/status',
    );
    await tester.pump();
  });

  // 场景：在不同请求间切换时，URL 编辑器应刷新为对应请求的地址。
  testWidgets('switching requests updates the URL editor value', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create user').first);
    await tester.pumpAndSettle();
    var field = tester.widget<TextFormField>(
      find.byKey(const Key('request-url-text-field')),
    );
    expect(field.controller!.text, 'http://127.0.0.1:8081/api/v1/basic/users');

    await tester.tap(find.text('List users').first);
    await tester.pumpAndSettle();
    field = tester.widget<TextFormField>(
      find.byKey(const Key('request-url-text-field')),
    );
    expect(
      field.controller!.text,
      'http://127.0.0.1:8081/api/v1/users?page=1&limit=20',
    );
  });

  // 场景：删除一行参数后，其余已编辑行的输入应保持不变。
  testWidgets('removing a parameter row preserves other edited rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    final roleValue = find.byKey(
      const ValueKey('field-value-demo-rest-list-users:param:1'),
    );
    await tester.enterText(roleValue, 'editor');
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('request-url-text-field')),
          )
          .controller!
          .text,
      contains('limit=editor'),
    );
    await tester.tap(find.byTooltip('Remove row').first);
    await tester.pumpAndSettle();

    expect(tester.state<FormFieldState<String>>(roleValue).value, 'editor');
  });

  // 场景：URL 是请求编辑器的视觉主体；类型与执行操作固定在独立上行。
  testWidgets('request URL bar prioritizes readable URL input', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('request-url-bar'))).height,
      102,
    );
    expect(
      tester.getSize(find.byKey(const Key('request-url-input'))).height,
      40,
    );
    expect(
      tester.getSize(find.byKey(const Key('request-kind-selector'))).width,
      92,
    );
    final selectorRect = tester.getRect(
      find.byKey(const Key('request-kind-selector')),
    );
    final urlRect = tester.getRect(find.byKey(const Key('request-url-input')));
    final actionRect = tester.getRect(
      find.byKey(const Key('request-action-slot')),
    );
    expect(selectorRect.height, 36);
    expect(actionRect.width, 112);
    expect(selectorRect.top, lessThan(urlRect.top));
    expect(actionRect.top, closeTo(selectorRect.top, 0.5));
    expect(urlRect.width, greaterThan(actionRect.width * 3));
    final urlField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('request-url-input')),
        matching: find.byType(TextField),
      ),
    );
    expect(urlField.maxLines, 1);
    expect(urlField.textAlignVertical, TextAlignVertical.center);
    expect(urlField.decoration?.filled, isFalse);
    expect(urlField.decoration?.isCollapsed, isTrue);
    expect(urlField.decoration?.contentPadding, EdgeInsets.zero);
    final editable = tester
        .state<EditableTextState>(
          find.descendant(
            of: find.byKey(const Key('request-url-input')),
            matching: find.byType(EditableText),
          ),
        )
        .renderEditable;
    final editableRect = editable.localToGlobal(Offset.zero) & editable.size;
    expect(editableRect.center.dy, closeTo(urlRect.center.dy, 0.5));
    final urlInput = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('request-url-input')),
        matching: find.byType(EditableText),
      ),
    );
    expect(urlInput.style.fontFamily, 'JetBrains Mono');
    expect(urlInput.style.fontSize, 13);
  });

  // 场景：Collection 请求可在编辑上下文直接切换全局执行环境；请求定义不变，
  // 发送时 URL、参数、请求头和鉴权模板会按新环境重新解析。
  testWidgets('collection request switches execution environment in context', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = _RecordingGeoIpRuntime();
    await tester.pumpWidget(SendreqApp(executionRuntime: runtime));
    await tester.pumpAndSettle();

    final requestSelector = find.byKey(
      const Key('request-topbar-environment-selector'),
    );
    expect(requestSelector, findsOneWidget);
    final selectorWidth = tester.getSize(requestSelector).width;
    expect(selectorWidth, greaterThanOrEqualTo(164));
    expect(
      find.descendant(of: requestSelector, matching: find.text('ENVIRONMENT')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: requestSelector, matching: find.text('Staging')),
      findsOneWidget,
    );

    await tester.tap(requestSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Production').last);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: requestSelector, matching: find.text('Production')),
      findsOneWidget,
    );
    expect(tester.getSize(requestSelector).width, selectorWidth);
    await tester.tap(find.widgetWithText(FilledButton, 'Send').first);
    await tester.pumpAndSettle();
    expect(runtime.resolvedUrls, [
      'http://127.0.0.1:8081/api/v1/users?page=1&limit=20',
    ]);
  });

  testWidgets('Collection preserves a natural locate-to-response workflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create user').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close Create user'), findsOneWidget);
    expect(
      find.byKey(const Key('request-topbar-environment-selector')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('request-topbar-environment-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Production').last);
    await tester.pumpAndSettle();
    expect(find.text('Production'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Send').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('response-body-viewer')), findsOneWidget);
    final responseRect = tester.getRect(
      find.byKey(const Key('response-body-viewer')),
    );
    await tester.tap(find.byKey(const Key('response-body-format-toggle')));
    await tester.pump();
    expect(find.byKey(const Key('response-raw-wrapped-text')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('response-body-viewer'))),
      responseRect,
    );
    expect(find.byTooltip('Close Create user'), findsOneWidget);
    expect(
      find.byKey(const Key('request-topbar-environment-selector')),
      findsOneWidget,
    );
  });

  // 场景：编辑正文后继续保留草稿状态，由用户在后续流程明确决定是否持久化。
  testWidgets('request body remains an editable draft', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create user').first);
    await tester.pump();
    final bodyTab = find.text('Body');
    await tester.ensureVisible(bodyTab);
    await tester.pumpAndSettle();
    await tester.tap(bodyTab);
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('request-body-input')),
      '{"email":"new@sendreq.io"}',
    );
    await tester.pump();

    expect(find.text('Create user *'), findsOneWidget);
    expect(find.text('Create user *'), findsOneWidget);
  });

  // 场景：授权设置是独立的固定配置，不会在 Headers 中生成重复的 Authorization 行。
  testWidgets('request authorization is independent from request headers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Auth'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('request-authentication-source')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Request only (does not inherit environment)').last,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('request-authentication-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bearer token').last);
    await tester.pump();
    final tokenInput = find.byKey(const Key('request-bearer-token-input'));
    final editableToken = find.descendant(
      of: tokenInput,
      matching: find.byType(EditableText),
    );
    expect(tokenInput, findsOneWidget);
    expect(tester.widget<EditableText>(editableToken).obscureText, isFalse);
    expect(
      tester.widget<EditableText>(editableToken).controller.text,
      '{{token}}',
    );
    await tester.enterText(tokenInput, 'new-token');
    await tester.pump();
    expect(tester.widget<EditableText>(editableToken).obscureText, isTrue);
    expect(find.byTooltip('Reveal value'), findsOneWidget);
    await tester.tap(find.byTooltip('Reveal value'));
    await tester.pump();
    expect(tester.widget<EditableText>(editableToken).obscureText, isFalse);
    expect(find.byTooltip('Hide value'), findsOneWidget);

    await tester.tap(find.byKey(const Key('request-authentication-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No auth').last);
    await tester.pump();
    await tester.tap(find.text('Headers'));
    await tester.pump();

    expect(find.text('Authorization'), findsNothing);
  });

  // 场景：Auth 中的环境 token 保持可读，直接填入的固定 token 默认遮罩。
  testWidgets('Bearer authentication distinguishes environment references', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Auth'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('request-authentication-source')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Request only (does not inherit environment)').last,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('request-authentication-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bearer token').last);
    await tester.pump();
    final headerInput = find.byKey(const Key('request-bearer-token-input'));
    final editableHeader = find.descendant(
      of: headerInput,
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(editableHeader).obscureText, isFalse);
    expect(
      tester.widget<EditableText>(editableHeader).controller.text,
      '{{token}}',
    );

    await tester.enterText(headerInput, 'direct-token');
    await tester.pump();
    expect(tester.widget<EditableText>(editableHeader).obscureText, isTrue);
    await tester.tap(find.byTooltip('Reveal value'));
    await tester.pump();
    expect(tester.widget<EditableText>(editableHeader).obscureText, isFalse);
  });

  // 场景：点击“格式化 JSON”应将合法的 JSON 原地转为缩进排版。
  testWidgets('request body formats valid JSON in place', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create user').first);
    await tester.pump();
    await tester.tap(find.text('Body'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('request-body-input')),
      '{"name":"Mary","roles":["admin"]}',
    );
    await tester.pump();
    await tester.tap(find.text('Format JSON'));
    await tester.pump();

    final field = tester.widget<TextFormField>(
      find.byKey(const Key('request-body-input')),
    );
    expect(
      field.controller!.text,
      '{\n  "name": "Mary",\n  "roles": [\n    "admin"\n  ]\n}',
    );
  });

  testWidgets('narrow JSON request body preserves content type space', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Collections'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create user').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Request'));
    await tester.pumpAndSettle();
    final bodyTab = find.text('Body');
    expect(tester.getRect(bodyTab).right, lessThanOrEqualTo(375.0));
    await tester.tap(bodyTab);
    await tester.pumpAndSettle();

    final contentType = find.byTooltip('Change body content type');
    final formatAction = find.byKey(const Key('request-body-format-json'));
    expect(tester.takeException(), isNull);
    expect(contentType, findsOneWidget);
    expect(formatAction, findsOneWidget);
    expect(tester.getRect(contentType).right, lessThanOrEqualTo(375.0));
    expect(tester.getRect(formatAction).right, lessThanOrEqualTo(375.0));
    expect(find.text('Format JSON'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('request-body-input')),
      '{"name":"Mary"}',
    );
    await tester.tap(formatAction);
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('request-body-input')))
          .controller!
          .text,
      '{\n  "name": "Mary"\n}',
    );
  });

  // 场景：仅当正文 Content-Type 为 JSON 类时，才提供“格式化 JSON”入口。
  testWidgets('body formatting is only offered for JSON content types', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Body'), findsNothing);

    await tester.tap(find.text('Create user').first);
    await tester.pump();
    await tester.tap(find.text('Body'));
    await tester.pump();
    expect(find.text('Format JSON'), findsOneWidget);
  });

  // 场景：切换到 multipart/form-data 后，正文区应展示文件与表单字段控件。
  testWidgets('multipart body mode presents file and form field controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create user').first);
    await tester.pump();
    await tester.tap(find.text('Body'));
    await tester.pump();
    await tester.tap(find.byTooltip('Change body content type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('multipart/form-data'));
    await tester.pumpAndSettle();

    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Choose files'), findsOneWidget);
    expect(find.text('Form fields'), findsOneWidget);
    expect(find.byKey(const Key('request-body-input')), findsNothing);
  });

  testWidgets('URL encoded and XML body modes use their matching editors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create user').first);
    await tester.pump();
    await tester.tap(find.text('Body'));
    await tester.pump();
    await tester.tap(find.byTooltip('Change body content type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('application/x-www-form-urlencoded'));
    await tester.pumpAndSettle();

    expect(find.text('URL encoded fields'), findsOneWidget);
    expect(find.byKey(const Key('request-body-input')), findsNothing);
    await tester.tap(find.byTooltip('Add form field'));
    await tester.pump();
    final formKeyInput = find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField &&
          widget.key is ValueKey &&
          (widget.key! as ValueKey).value is String &&
          ((widget.key! as ValueKey).value as String).startsWith(
            'urlencoded-field-key-',
          ),
    );
    expect(formKeyInput, findsOneWidget);
    await tester.enterText(formKeyInput, 'email');
    await tester.pump();

    await tester.tap(find.byTooltip('Change body content type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('application/xml'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('request-body-input')), findsOneWidget);
    expect(find.text('Format JSON'), findsNothing);
  });

  // 场景：多个上传文件共享同一可编辑的批量字段名，应用后应统一生效。
  // 直接驱动 ViewModel 并在独立宿主中渲染 RequestEditorPanel，聚焦组件行为。
  testWidgets('multiple multipart files share an editable batch field name', (
    tester,
  ) async {
    final viewModel = workspaceViewModel(
      assetRepository: InMemoryApiAssetRepository.demo(),
    );
    viewModel.updateActiveDraftMethod('POST');
    viewModel.updateActiveContentType('multipart/form-data');
    viewModel.addActiveMultipartFile(
      path: '/tmp/one.txt',
      fileName: 'one.txt',
      sizeBytes: 1,
      keyName: 'files[]',
    );
    viewModel.addActiveMultipartFile(
      path: '/tmp/two.txt',
      fileName: 'two.txt',
      sizeBytes: 1,
      keyName: 'files[]',
    );
    viewModel.selectRequestEditorTab('Body');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AnimatedBuilder(
            animation: viewModel,
            builder: (_, _) => SizedBox(
              width: 512,
              child: RequestEditorPanel(viewModel: viewModel),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BATCH FIELD'), findsOneWidget);
    final batchField = find.byKey(const Key('multipart-batch-field-input'));
    await tester.enterText(batchField, 'attachments');
    await tester.tap(find.text('Apply'));
    await tester.pump();

    expect(
      viewModel.activeDraft.multipartFiles.map((file) => file.keyName),
      everyElement('attachments'),
    );
  });

  // 场景：丢弃未保存草稿应先弹出确认；选择继续编辑则草稿保留。
  testWidgets('discarding a draft requires confirmation', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('request-url-input')),
      'https://example.test/draft',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Discard unsaved changes'));
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Continue editing'));
    await tester.pumpAndSettle();
    expect(find.text('List users *'), findsOneWidget);
  });

  // 场景：关闭带未保存修改的标签页时，应先询问用户如何处理这些变更。
  testWidgets('closing a dirty request tab asks before discarding changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('request-url-input')),
      'https://example.test/status',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Close List users'));
    await tester.pumpAndSettle();

    expect(find.text('Unsaved request'), findsOneWidget);
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close List users'), findsNothing);
  });

  // 场景：从响应直接创建已保存 Mock Server，原请求草稿保持不变。
  testWidgets(
    'response creates a saved Mock Server and preserves the request draft',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('request-url-input')),
        'https://staging.sendreq.io/api/v1/users?source=mock-draft',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Send').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Create Mock Server from response'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('saved-mock-name-input')), findsOneWidget);
      expect(
        find.byKey(const Key('saved-mock-variant-status-input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('saved-mock-endpoint-path-input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('saved-mock-secondary-actions')),
        findsOneWidget,
      );
      final endpointChoice = find.descendant(
        of: find.byKey(const Key('saved-mock-endpoint-selector')),
        matching: find.byType(TextButton),
      );
      expect(tester.getSize(endpointChoice.first).height, 30);

      await tester.enterText(
        find.byKey(const Key('saved-mock-endpoint-path-input')),
        '/mock-users',
      );
      await tester.enterText(
        find.byKey(const Key('saved-mock-variant-status-input')),
        '201',
      );
      await tester.pump();
      final save = tester.widget<FilledButton>(
        find.byKey(const Key('saved-mock-save-button')),
      );
      expect(save.onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('saved-mock-save-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('saved-mock-save-button')), findsNothing);
      expect(
        find.byKey(const Key('saved-mock-lifecycle-button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('saved-mock-secondary-actions')));
      await tester.pumpAndSettle();
      expect(find.text('Archive server'), findsOneWidget);
      expect(find.text('Delete server'), findsOneWidget);
    },
  );

  // 场景：新请求以脏草稿打开，未填 URL 时禁止发送；填写后可发送并可保存去除脏标记。
  testWidgets('new request opens as a dirty draft and requires a URL to send', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('new-request-type-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REST').last);
    await tester.pumpAndSettle();

    expect(find.text('New request 1 *'), findsOneWidget);
    final send = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Send').first,
    );
    expect(send.onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('request-url-input')),
      'https://example.test/health',
    );
    await tester.pump();

    final enabledSend = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Send').first,
    );
    expect(enabledSend.onPressed, isNotNull);
    expect(find.text('New request 1 *'), findsOneWidget);
  });

  // 场景：从 Requests 的 Collection 菜单导入 OpenAPI JSON。
  testWidgets('Requests imports OpenAPI JSON into a request', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Collection actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import OpenAPI'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      '{"openapi":"3.0.0","paths":{"/projects":{"get":{"summary":"List projects"}}}}',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();

    expect(find.text('List projects'), findsWidgets);
    expect(find.byTooltip('1 notifications need attention'), findsOneWidget);
    await tester.tap(find.byTooltip('1 notifications need attention'));
    await tester.pumpAndSettle();
    expect(
      find.text('1 OpenAPI requests imported into Imported OpenAPI.'),
      findsOneWidget,
    );
  });

  // 场景：导入 application/json 示例后，请求正文应使用 JSON 编辑模式并提供格式化入口。
  testWidgets('imported OpenAPI JSON body exposes formatting controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SendreqApp(executionRuntime: DemoRequestExecutionRuntime()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Collection actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import OpenAPI'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      '''{"openapi":"3.0.3","info":{"title":"sendreq API"},"paths":{"/sessions":{"post":{"summary":"Create imported session","requestBody":{"content":{"application/json":{"example":{"email":"ops@sendreq.io","remember":true}}}}}}}}''',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Body'));
    await tester.pumpAndSettle();
    expect(find.text('Format JSON'), findsOneWidget);
    final body = tester.widget<TextFormField>(
      find.byKey(const Key('request-body-input')),
    );
    expect(
      body.controller!.text,
      '{\n  "email": "ops@sendreq.io",\n  "remember": true\n}',
    );
  });
}

class _FlushRecordingApiAssetRepository extends InMemoryApiAssetRepository {
  _FlushRecordingApiAssetRepository({
    required super.collections,
    required super.openTabs,
    required super.activeRequestId,
  });

  factory _FlushRecordingApiAssetRepository.demo() {
    const requestId = 'demo-rest-list-users';
    return _FlushRecordingApiAssetRepository(
      collections: const [DemoExampleCatalog.protocolTestCollection],
      openTabs: [
        RequestTab(
          id: 'tab-$requestId',
          requestId: requestId,
          title: 'List users',
          openedAt: DateTime.utc(2026, 8, 8),
        ),
      ],
      activeRequestId: requestId,
    );
  }

  int flushCalls = 0;

  @override
  Future<void> flush() async => flushCalls++;
}

String _responseJsonTreeText(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(const Key('response-json-tree')),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.textSpan!.toPlainText())
    .join('\n');

Future<void> _openEnvironmentManager(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('request-topbar-environment-selector')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Manage environments...'));
  await tester.pumpAndSettle();
}

/// 记录经 UI 发送的最终地址，并返回与 GeoIP 接口结构一致的 JSON 响应。
class _RecordingGeoIpRuntime implements RequestExecutionRuntime {
  final List<String> resolvedUrls = [];

  @override
  void cancel() {}

  @override
  Future<RuntimeResponse> send({
    required RequestDraft draft,
    required String resolvedUrl,
  }) {
    resolvedUrls.add(resolvedUrl);
    return Future.value(
      const RuntimeResponse(
        statusCode: 200,
        timeMs: 138,
        sizeKb: 0.3,
        body: '{"code":200,"data":{"ip":"113.108.81.189"},"msg":"ok"}',
        headers: [
          KeyValueRow(keyName: 'content-type', value: 'application/json'),
        ],
      ),
    );
  }
}

class _FailOncePreferenceStore implements WorkspacePreferenceStore {
  bool _shouldFail = true;
  final List<WorkspacePreferences> saved = [];

  @override
  Future<WorkspacePreferences> load() async => WorkspacePreferences.defaults;

  @override
  Future<void> save(WorkspacePreferences preferences) async {
    if (_shouldFail) {
      _shouldFail = false;
      throw StateError('unavailable');
    }
    saved.add(preferences);
  }
}
