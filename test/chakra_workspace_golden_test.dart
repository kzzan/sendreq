import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/app/sendreq_app.dart';
import 'package:sendreq/data/repositories/in_memory_workspace_preference_store.dart';
import 'package:sendreq/domain/preferences/workspace_preferences.dart';
import 'package:sendreq/ui/shell/views/workspace_view.dart';

import 'support/workspace_view_model_test_factory.dart';

void main() {
  for (final appearance in const [
    AppearancePreference.light,
    AppearancePreference.dark,
  ]) {
    for (final width in const [375.0, 768.0, 1024.0, 1440.0]) {
      for (final tool in _GoldenTool.values) {
        testWidgets(
          '${tool.name} ${appearance.name} ${width.toInt()} Chakra workspace',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              SendreqApp(
                workspaceDependencies: workspaceTestDependencies(
                  preferenceStore: InMemoryWorkspacePreferenceStore(
                    WorkspacePreferences(appearance: appearance),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            if (tool != _GoldenTool.requests) {
              await tester.tap(
                find.byKey(ValueKey('tool-navigation-${tool.name}')),
              );
              await tester.pumpAndSettle();
            }
            if (tool == _GoldenTool.mock) {
              await tester.tap(
                find.byKey(const Key('mock-create-manual-action')),
              );
              await tester.pumpAndSettle();
            }

            expect(find.byType(WorkspaceView), findsOneWidget);
            expect(tester.takeException(), isNull);
            await expectLater(
              find.byType(WorkspaceView),
              matchesGoldenFile(
                'goldens/chakra-${tool.name}-${appearance.name}-${width.toInt()}x900.png',
              ),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

enum _GoldenTool { requests, mock, settings }
