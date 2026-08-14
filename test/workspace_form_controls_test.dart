import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/ui/core/theme/app_theme.dart';
import 'package:sendreq/ui/core/theme/form_control_metrics.dart';
import 'package:sendreq/ui/core/widgets/dense_controls.dart';
import 'package:sendreq/ui/core/widgets/workspace_form_controls.dart';

void main() {
  testWidgets('shared controls keep stable geometry across supported widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: SendreqTheme.dark(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  LabeledField(
                    label: 'Connection mode',
                    child: CompactSelect<String>(
                      value: 'Secure',
                      items: const [
                        CompactSelectItem(value: 'Secure', label: 'Secure'),
                        CompactSelectItem(value: 'Open', label: 'Open'),
                      ],
                      onChanged: (_) {},
                    ),
                  ),
                  const SizedBox(height: 12),
                  ModeSelector<String>(
                    value: 'Header',
                    items: const [
                      ModeSelectorItem(value: 'Header', label: 'Header'),
                      ModeSelectorItem(value: 'Query', label: 'Query'),
                    ],
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: 12),
                  InlineSwitch(
                    label: 'Use TLS',
                    value: true,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(CompactSelect<String>)).height,
        FormControlMetrics.standardHeight,
      );
      expect(find.text('Connection mode'), findsOneWidget);
      expect(find.text('Use TLS'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(LabeledField)).label,
        contains('Connection mode'),
      );
    }
  });

  testWidgets('mode selector remains keyboard reachable', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Focus(
            focusNode: focus,
            child: ModeSelector<String>(
              value: 'Header',
              items: const [
                ModeSelectorItem(value: 'Header', label: 'Header'),
                ModeSelectorItem(value: 'Query', label: 'Query'),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.binding.focusManager.primaryFocus, isNotNull);
    expect(find.text('Header'), findsOneWidget);
  });

  testWidgets(
    'shared control geometry stays synchronized across theme language and state',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(720, 640);
      tester.view.devicePixelRatio = 1;

      for (final theme in [SendreqTheme.light(), SendreqTheme.dark()]) {
        for (final locale in const [Locale('en'), Locale('zh')]) {
          for (final enabled in [true, false]) {
            final chinese = locale.languageCode == 'zh';
            final first = chinese ? '请求头' : 'Header';
            final second = chinese ? '查询参数' : 'Query';
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                locale: locale,
                home: Scaffold(
                  body: SizedBox(
                    width: 420,
                    child: Column(
                      children: [
                        ModeSelector<String>(
                          value: enabled ? first : second,
                          items: [
                            ModeSelectorItem(value: first, label: first),
                            ModeSelectorItem(value: second, label: second),
                          ],
                          enabled: enabled,
                          onChanged: (_) {},
                        ),
                        SegmentedTabs(
                          tabs: [first, second],
                          active: enabled ? first : second,
                          onSelected: (_) {},
                        ),
                        DenseIconButton(
                          icon: Icons.add,
                          tooltip: 'Add',
                          size: 28,
                          onPressed: enabled ? () {} : null,
                        ),
                        InlineSwitch(
                          label: chinese ? '使用 TLS' : 'Use TLS',
                          value: enabled,
                          onChanged: enabled ? (_) {} : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();

            expect(
              tester.getSize(find.widgetWithText(OutlinedButton, first)).height,
              FormControlMetrics.standardHeight,
            );
            expect(
              tester.getSize(find.widgetWithText(TextButton, first)).height,
              FormControlMetrics.denseHeight,
            );
            expect(tester.getSize(find.byType(IconButton)), const Size(28, 28));
            expect(
              tester.getSize(find.byType(InlineSwitch)).height,
              greaterThanOrEqualTo(FormControlMetrics.standardHeight),
            );
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );
}
