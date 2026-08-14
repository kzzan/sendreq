import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/domain/module_boundaries/module_ports.dart';
import 'package:sendreq/ui/core/theme/app_theme.dart';
import 'package:sendreq/ui/features/requests/editor/widgets/request_editor_panel.dart';
import 'package:sendreq/ui/features/requests/output/widgets/response_panel.dart';
import 'package:sendreq/ui/shell/view_models/workspace_view_model.dart';
import 'package:sendreq/l10n/generated/app_localizations.dart';

import 'support/workspace_view_model_test_factory.dart';

void main() {
  testWidgets('gRPC workspace keeps protocol labels at target widths', (
    tester,
  ) async {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      final viewModel = workspaceViewModel();
      viewModel.selectRequest('demo-grpc-create-order');

      await tester.pumpWidget(_editorApp(viewModel, width));
      await tester.pumpAndSettle();

      for (final label in ['Message', 'Metadata', 'Auth', 'Proto']) {
        expect(find.text(label), findsOneWidget);
        expect(
          tester.getRect(find.text(label)).right,
          lessThanOrEqualTo(width),
        );
      }
      expect(find.text('Params'), findsNothing);
      expect(tester.takeException(), isNull);
      viewModel.dispose();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('new gRPC workflow shows compact No auth without credentials', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final viewModel = workspaceViewModel();
    addTearDown(viewModel.dispose);
    viewModel.selectRequest('demo-grpc-create-order');

    await tester.pumpWidget(_editorApp(viewModel, 375));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auth'));
    await tester.pumpAndSettle();

    expect(find.text('No auth'), findsWidgets);
    expect(find.byKey(const Key('request-bearer-token-input')), findsNothing);
    expect(find.byKey(const Key('request-basic-username-input')), findsNothing);
    expect(find.byKey(const Key('request-api-key-value-input')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gRPC response workspace is read only', (tester) async {
    final viewModel = workspaceViewModel();
    addTearDown(viewModel.dispose);
    viewModel.selectRequest('demo-grpc-create-order');

    await tester.pumpWidget(_responseApp(viewModel));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('grpc-response-close-request-stream')),
      findsNothing,
    );
    expect(find.byKey(const Key('grpc-response-cancel-call')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gRPC controls keep a usable keyboard traversal order', (
    tester,
  ) async {
    final viewModel = workspaceViewModel();
    addTearDown(viewModel.dispose);
    viewModel.selectRequest('demo-grpc-create-order');

    await tester.pumpWidget(_editorApp(viewModel, 768));
    await tester.pumpAndSettle();
    final urlField = find.descendant(
      of: find.byKey(const Key('request-url-text-field')),
      matching: find.byType(EditableText),
    );
    final focusNode = tester.widget<EditableText>(urlField).focusNode;
    await tester.tap(find.byKey(const Key('request-url-text-field')));
    expect(focusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gRPC workspace matches narrow and desktop screenshots', (
    tester,
  ) async {
    for (final width in [375.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      final viewModel = workspaceViewModel(
        protobufSource: _FixtureProtobufSource(),
      );
      viewModel.selectRequest('demo-grpc-create-order');
      final boundaryKey = ValueKey('grpc-workspace-frame-${width.toInt()}');

      await tester.pumpWidget(
        MaterialApp(
          theme: SendreqTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: RequestEditorPanel(viewModel: viewModel, compact: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(boundaryKey),
        matchesGoldenFile('goldens/grpc-workspace-${width.toInt()}x900.png'),
      );
      expect(find.byKey(const Key('request-action-slot')), findsOneWidget);
      expect(find.byKey(const Key('grpc-message-editor')), findsOneWidget);
      expect(tester.takeException(), isNull);
      viewModel.dispose();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _FixtureProtobufSource implements ProtobufSourcePort {
  _FixtureProtobufSource()
    : _bytes = File('assets/demo/order.pb').readAsBytesSync() {
    _descriptors = ProtobufDescriptorSet.parse(_bytes);
  }

  final Uint8List _bytes;
  late final ProtobufDescriptorSet _descriptors;

  @override
  bool exists(String path) => true;

  @override
  ProtobufDescriptorSet parseDescriptorSet(Uint8List bytes) =>
      ProtobufDescriptorSet.parse(bytes);

  @override
  Future<ProtobufDescriptorSet> parseSourceFile(String path) async =>
      _descriptors;

  @override
  Future<Uint8List> readBytes(String path) async => _bytes;
}

Widget _editorApp(WorkspaceViewModel viewModel, double width) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => SizedBox(
        width: width,
        child: RequestEditorPanel(viewModel: viewModel, compact: true),
      ),
    ),
  ),
);

Widget _responseApp(WorkspaceViewModel viewModel) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => ResponsePanel(viewModel: viewModel),
    ),
  ),
);
