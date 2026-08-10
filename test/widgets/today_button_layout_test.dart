import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression guard for the detail-page date row. The TODAY button lives in a
// Stack beside a fixed-width date field inside a scroll view; using
// CrossAxisAlignment.stretch there forces infinite height on the button and
// makes it vanish in release builds. This reproduces that row and asserts the
// button lays out with a real, visible size and no layout exception.
Widget _dateRow() {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          children: [
            const SizedBox(height: 200),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: TextEditingController(),
                    decoration: const InputDecoration(hintText: 'MM/DD/YYYY'),
                  ),
                ),
                const SizedBox(width: 10),
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    const SizedBox.shrink(),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('TODAY'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('TODAY button lays out with a visible size (no infinite height)',
      (tester) async {
    await tester.pumpWidget(_dateRow());
    expect(tester.takeException(), isNull);
    expect(find.text('TODAY'), findsOneWidget);
    final size = tester.getSize(find.text('TODAY'));
    expect(size.width, greaterThan(0));
    expect(size.height, greaterThan(0));
    expect(size.height.isFinite, isTrue);
  });
}
