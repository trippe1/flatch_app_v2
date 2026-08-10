import 'package:flatch/cubits/accident_counter/accident_counter_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccidentCounterCubit.daysSinceFor', () {
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    test('null / empty / malformed input returns null', () {
      expect(AccidentCounterCubit.daysSinceFor(null), isNull);
      expect(AccidentCounterCubit.daysSinceFor(''), isNull);
      expect(AccidentCounterCubit.daysSinceFor('not-a-date'), isNull);
      expect(AccidentCounterCubit.daysSinceFor('2026-13'), isNull);
    });

    test('today is 0 days', () {
      expect(AccidentCounterCubit.daysSinceFor(iso(DateTime.now())), 0);
    });

    test('yesterday is 1 day', () {
      final y = DateTime.now().subtract(const Duration(days: 1));
      expect(AccidentCounterCubit.daysSinceFor(iso(y)), 1);
    });

    test('counts whole local days regardless of time-of-day', () {
      final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));
      expect(AccidentCounterCubit.daysSinceFor(iso(tenDaysAgo)), 10);
    });

    test('a future date clamps to 0 (never negative)', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(AccidentCounterCubit.daysSinceFor(iso(tomorrow)), 0);
    });
  });
}
