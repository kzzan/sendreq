import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendreq/ui/core/widgets/listenable_selector.dart';

void main() {
  testWidgets('rebuilds only when the selected projection changes', (
    tester,
  ) async {
    final source = ValueNotifier<int>(0);
    addTearDown(source.dispose);
    var builds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ListenableSelector<bool>(
          listenable: source,
          select: () => source.value.isEven,
          builder: (context, isEven, child) {
            builds++;
            return Text(isEven ? 'even' : 'odd');
          },
        ),
      ),
    );

    expect(builds, 1);
    source.value = 2;
    await tester.pump();
    expect(builds, 1);

    source.value = 3;
    await tester.pump();
    expect(builds, 2);
    expect(find.text('odd'), findsOneWidget);
  });
}
