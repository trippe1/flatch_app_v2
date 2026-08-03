import 'package:flatch/common/services/device_key_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks the app's device-auth response to the firmware's expectation, using
/// the exact values the device printed in its own debug log. If this passes,
/// the phone and the ESP32 agree without needing hardware in the loop.
void main() {
  // Straight from the device serial log (device_001).
  const mac = '20:6e:f1:2e:81:a8';
  const challengeHex = '0163d9e047af5a85cdbf6fa8229839dc';
  const deviceExpected =
      'a51d2863ea3abe9016b1ff0989dd2596e8c4d2141709e23f1718a8841534c475';

  group('DeviceKeyService', () {
    test('response matches the firmware for the logged challenge', () async {
      final resp = await DeviceKeyService.computeResponse(
        challengeHex: challengeHex,
        mac: mac,
      );
      expect(resp, deviceExpected);
    });

    test('parses AUTH_CHAL "<challenge>,<MAC>"', () {
      final p =
          DeviceKeyService.parseChallenge('$challengeHex,$mac');
      expect(p!.challengeHex, challengeHex);
      expect(p.mac, mac);
    });

    test('MAC lookup is case-insensitive', () async {
      final resp = await DeviceKeyService.computeResponse(
        challengeHex: challengeHex,
        mac: mac.toUpperCase(),
      );
      expect(resp, deviceExpected);
    });

    test('unknown device returns null (no key on file)', () async {
      final resp = await DeviceKeyService.computeResponse(
        challengeHex: challengeHex,
        mac: 'aa:bb:cc:dd:ee:ff',
      );
      expect(resp, isNull);
    });

    test('legacy challenge with no MAC still parses', () {
      final p = DeviceKeyService.parseChallenge(challengeHex);
      expect(p!.challengeHex, challengeHex);
      expect(p.mac, '');
    });
  });
}
