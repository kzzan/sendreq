import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/ui/core/theme/app_theme.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/theme/workspace_layout_metrics.dart';
import 'package:sendreq/ui/core/widgets/workspace_navigation_rail.dart';

void main() {
  testWidgets('navigation rail keeps its header and selected row stable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: SendreqTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: WorkspaceNavigationRail(
              child: Column(
                children: [
                  const NavigationRailHeader(
                    title: 'Resources',
                    subtitle: '2 available',
                    leading: Icon(Icons.folder_outlined),
                  ),
                  NavigationRailItem(
                    key: const Key('navigation-rail-selected'),
                    selected: true,
                    onTap: () => taps += 1,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 9),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Selected resource'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('navigation-rail-selected')));
    await tester.pump();

    expect(taps, 1);
    expect(find.text('Resources'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('navigation-rail-selected'))).height,
      WorkspaceLayoutMetrics.resourceRowHeight,
    );
    expect(WorkspaceLayoutMetrics.toolRailWidth, 184);
    expect(WorkspaceLayoutMetrics.compactToolRailWidth, 56);
    expect(WorkspaceLayoutMetrics.toolRailItemHeight, 40);
    expect(WorkspaceLayoutMetrics.fieldHeight, 34);
    final element = tester.element(find.byType(WorkspaceNavigationRail));
    expect(
      Theme.of(element).extension<ChakraSemanticTokens>()!.bgSubtle,
      ChakraSemanticTokens.dark.bgSubtle,
    );
  });

  testWidgets(
    'navigation rail focus is visible without changing row geometry',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SendreqTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: WorkspaceNavigationRail(
                child: NavigationRailItem(
                  key: const Key('navigation-rail-focusable'),
                  selected: false,
                  onTap: () {},
                  child: const Text('Focusable resource'),
                ),
              ),
            ),
          ),
        ),
      );

      final before = tester.getSize(
        find.byKey(const Key('navigation-rail-focusable')),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(
        before,
        tester.getSize(find.byKey(const Key('navigation-rail-focusable'))),
      );
      final element = tester.element(
        find.byKey(const Key('navigation-rail-focusable')),
      );
      expect(
        Theme.of(
          element,
        ).extension<ChakraSemanticTokens>()!.colorPaletteFocusRing,
        const Color(0xFF14B8A6),
      );
    },
  );
}
