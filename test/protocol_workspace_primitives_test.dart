import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/ui/core/theme/app_theme.dart';
import 'package:sendreq/ui/core/theme/chakra_tokens.dart';
import 'package:sendreq/ui/core/widgets/protocol_workspace_primitives.dart';

void main() {
  testWidgets('status bar exposes a live semantic status and stable height', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProtocolStatusBar(
            label: 'Connected',
            detail: 'ws://127.0.0.1:8080/ws',
            tone: ProtocolTone.success,
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(ProtocolStatusBar));
    expect(semantics.label, contains('Connected: ws://127.0.0.1:8080/ws'));
    expect(
      tester.getSize(find.byType(ProtocolStatusBar)).height,
      greaterThanOrEqualTo(42),
    );
  });

  testWidgets('event rows keep scan columns stable on a narrow workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProtocolEventRow(
            time: '12:01:02',
            kind: 'Inbound',
            summary: '{"status":"received"}',
            tone: ProtocolTone.inbound,
          ),
        ),
      ),
    );

    final row = tester.getSize(find.byType(ProtocolEventRow));
    expect(row.width, 375);
    expect(row.height, greaterThanOrEqualTo(34));
    expect(find.text('Inbound'), findsOneWidget);
  });

  testWidgets('safe session chip supplies a descriptive tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SafeSessionChip(label: 'Auth', value: 'Bearer token'),
        ),
      ),
    );

    await tester.longPress(find.byType(SafeSessionChip));
    await tester.pumpAndSettle();
    expect(find.text('Auth'), findsOneWidget);
    final element = tester.element(find.byType(SafeSessionChip));
    final tokens = element.chakra;
    expect(tokens.colorPaletteFocusRing, isNot(tokens.bg));
  });

  testWidgets(
    'protocol workspace states remain usable across viewports and themes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          final reconnectFocus = FocusNode(debugLabel: 'reconnect-$width');
          addTearDown(reconnectFocus.dispose);
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;

          await tester.pumpWidget(
            MaterialApp(
              theme: brightness == Brightness.light
                  ? SendreqTheme.light()
                  : SendreqTheme.dark(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ProtocolStatusBar(
                        label: 'Streaming',
                        detail: 'WatchOrders is receiving server events',
                        tone: ProtocolTone.progress,
                      ),
                      const ProtocolEventRow(
                        time: '12:01:02',
                        kind: 'Inbound',
                        summary: '{"sequence": 1, "status": "received"}',
                        tone: ProtocolTone.inbound,
                      ),
                      ProtocolStateNotice(
                        title: 'No events yet',
                        message: 'Start the call to receive server events.',
                        tone: ProtocolTone.neutral,
                        action: TextButton(
                          focusNode: reconnectFocus,
                          onPressed: () {},
                          child: const Text('Reconnect'),
                        ),
                      ),
                      const ProtocolStateNotice(
                        title: 'Loading stream',
                        message: 'Waiting for the server response.',
                        tone: ProtocolTone.progress,
                      ),
                      const ProtocolStateNotice(
                        title: 'Connection failed',
                        message: 'Check the endpoint and try again.',
                        tone: ProtocolTone.danger,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(find.text('Streaming'), findsOneWidget);
          expect(find.text('Inbound'), findsOneWidget);
          expect(find.text('No events yet'), findsOneWidget);
          expect(find.text('Loading stream'), findsOneWidget);
          expect(find.text('Connection failed'), findsOneWidget);
          expect(find.text('Reconnect'), findsOneWidget);
          expect(
            tester.getSize(find.byType(ProtocolStatusBar)).height,
            greaterThanOrEqualTo(42),
          );
          expect(
            tester.getSize(find.byType(ProtocolEventRow)).height,
            greaterThanOrEqualTo(34),
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(reconnectFocus.hasFocus, isTrue);
        }
      }
    },
  );
}
