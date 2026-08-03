import 'package:flatch/common/services/age_gate_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fixed "now" so tests are deterministic.
  final now = DateTime(2026, 7, 10);

  bool ok(int y, int m, int d) =>
      AgeGateService.meetsMinimumAge(DateTime(y, m, d), now: now);

  group('AgeGateService.meetsMinimumAge (threshold 13)', () {
    test('comfortably over 13 passes', () {
      expect(ok(2000, 1, 1), isTrue);
    });

    test('exactly 13 today passes', () {
      expect(ok(2013, 7, 10), isTrue);
    });

    test('turns 13 tomorrow is blocked', () {
      expect(ok(2013, 7, 11), isFalse);
    });

    test('turned 13 yesterday passes', () {
      expect(ok(2013, 7, 9), isTrue);
    });

    test('12 years old is blocked', () {
      expect(ok(2014, 7, 10), isFalse);
    });

    test('birthday later this month is blocked (still 12)', () {
      expect(ok(2013, 7, 31), isFalse);
    });

    test('birthday earlier this year passed (is 13)', () {
      expect(ok(2013, 1, 1), isTrue);
    });
  });
}
