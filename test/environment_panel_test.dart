import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/ui/features/requests/environment/manager/widgets/environment_panel.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';

import 'support/workspace_view_model_test_factory.dart';

void main() {
  testWidgets('browsing is clean and using an environment stays explicit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final viewModel = workspaceViewModel();
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(_EnvironmentHost(viewModel: viewModel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Production'));
    await tester.pump();

    expect(viewModel.activeEnvironment.id, 'staging');
    expect(viewModel.editingEnvironment.id, 'production');
    expect(viewModel.hasEnvironmentChanges, isFalse);
    expect(find.byKey(const Key('save-environment-changes')), findsNothing);
    expect(
      find.byKey(const Key('use-environment-for-requests')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('use-environment-for-requests')));
    await tester.pump();

    expect(viewModel.activeEnvironment.id, 'production');
    expect(viewModel.editingEnvironment.id, 'production');
    expect(viewModel.hasEnvironmentChanges, isFalse);

    viewModel.updateEnvironmentVariable(
      id: 'production-base-url',
      value: 'https://draft.test',
    );
    await tester.pump();

    expect(find.text('Unsaved environment changes'), findsOneWidget);
    expect(find.byKey(const Key('save-environment-changes')), findsOneWidget);
    expect(
      find.byKey(const Key('discard-environment-changes')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('discard-environment-changes')));
    await tester.pumpAndSettle();
    expect(find.text('Discard environment changes?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Discard changes'));
    await tester.pumpAndSettle();

    expect(viewModel.hasEnvironmentChanges, isFalse);
    expect(
      viewModel.variables
          .singleWhere((item) => item.id == 'production-base-url')
          .displayValue,
      'https://api.sendreq.io',
    );
    expect(find.byKey(const Key('save-environment-changes')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('environment edit commands wrap without overflow when narrow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final viewModel = workspaceViewModel();
    addTearDown(viewModel.dispose);
    viewModel.updateEnvironmentVariable(
      id: 'staging-base-url',
      value: 'https://draft.test',
    );

    await tester.pumpWidget(_EnvironmentHost(viewModel: viewModel));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('environment-edit-commands')), findsOneWidget);
    expect(find.byKey(const Key('save-environment-changes')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _EnvironmentHost extends StatelessWidget {
  const _EnvironmentHost({required this.viewModel});

  final WorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => EnvironmentPanel(viewModel: viewModel),
      ),
    ),
  );
}
