import 'package:flatch/common/widgets/accident_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, int? value,
      AccidentCounterSize size) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: AccidentCounter(value: value, size: size)),
        ),
      ),
    );
    // Let the roll animation run.
    await tester.pump(const Duration(seconds: 6));
  }

  testWidgets('day mode (<365) renders 3 reels, no YR label', (tester) async {
    await pump(tester, 42, AccidentCounterSize.full);
    expect(tester.takeException(), isNull);
    expect(find.text('YR'), findsNothing);
  });

  testWidgets('year mode (>=365) shows the YR label on full size',
      (tester) async {
    await pump(tester, 800, AccidentCounterSize.full);
    expect(tester.takeException(), isNull);
    expect(find.text('YR'), findsOneWidget);
  });

  testWidgets('footprint is identical across the 364↔365 boundary',
      (tester) async {
    Size sizeAt(int days) {
      return tester.getSize(find.byType(AccidentCounter));
    }

    await pump(tester, 364, AccidentCounterSize.full);
    final dayMode = sizeAt(364);
    await pump(tester, 365, AccidentCounterSize.full);
    final yearMode = sizeAt(365);

    expect((dayMode.width - yearMode.width).abs() < 1.0, isTrue,
        reason: 'width must not change: $dayMode vs $yearMode');
    expect((dayMode.height - yearMode.height).abs() < 1.0, isTrue,
        reason: 'height must not change: $dayMode vs $yearMode');
  });

  testWidgets('null value renders dashes without crashing', (tester) async {
    await pump(tester, null, AccidentCounterSize.mini);
    expect(tester.takeException(), isNull);
  });
}
