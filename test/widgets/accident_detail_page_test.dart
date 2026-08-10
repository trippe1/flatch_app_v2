import 'package:flatch/cubits/accident_counter/accident_counter_cubit.dart';
import 'package:flatch/views/accident/accident_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Renders the real detail page that ships in the app and confirms the TODAY
// button is actually laid out (the release regression: stretch alignment made
// it infinite-height and invisible). The cubit runs offline via SharedPrefs;
// its Firebase calls are guarded so no live backend is needed.
void main() {
  testWidgets('detail page renders the TODAY button with a visible size',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'flatch_last_accident_date': '2026-08-05',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AccidentCounterCubit>(
          create: (_) => AccidentCounterCubit(),
          child: const AccidentDetailPage(),
        ),
      ),
    );
    // Let _load + the roll animation run (roll is up to ~5s).
    await tester.pump(const Duration(seconds: 6));

    expect(find.text('TODAY'), findsOneWidget);

    final size = tester.getSize(find.text('TODAY'));
    expect(size.width, greaterThan(0), reason: 'button collapsed horizontally');
    expect(size.height, greaterThan(0), reason: 'button collapsed vertically');
    expect(size.height.isFinite, isTrue,
        reason: 'infinite height = the release bug is back');

    // The date field and helper text are present too.
    expect(find.text('Enter day of last accident'), findsOneWidget);
    expect(find.text('Date can be corrected after pressing TODAY.'),
        findsOneWidget);

    // Dispose so the cubit's midnight timer is cancelled before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
