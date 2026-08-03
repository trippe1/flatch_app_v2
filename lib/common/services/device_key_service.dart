import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Device authentication (challenge–response).
///
/// The Flatch sends `AUTH_CHAL:<challengeHex>,<MAC>`. The app looks up that
/// device's secret key, computes `HMAC-SHA256(key, challenge)` over the RAW
/// bytes of each (this exactly matches the firmware — verified against the
/// device's own debug log), and replies `AUTH_RESP:<hmacHex>`.
///
/// KEY STORAGE — read this before shipping:
/// The [keyProvider] decides where per-device keys come from. The default
/// bundles them in the app, which is fine for bench testing but must NOT ship:
/// every device's key would live in every install. For production, swap in a
/// provider that calls a Cloud Function so the key never leaves the server
/// (see the class docs on [DeviceKeyProvider]).
class DeviceKeyService {
  DeviceKeyService._();

  static DeviceKeyProvider keyProvider = const BundledDeviceKeyProvider();

  /// Parsed pieces of an `AUTH_CHAL:` payload.
  static ({String challengeHex, String mac})? parseChallenge(String payload) {
    // payload is everything after "AUTH_CHAL:" — "<challengeHex>,<MAC>".
    final comma = payload.indexOf(',');
    if (comma < 0) {
      // Legacy firmware: challenge only, no MAC.
      return (challengeHex: payload.trim(), mac: '');
    }
    return (
      challengeHex: payload.substring(0, comma).trim(),
      mac: payload.substring(comma + 1).trim(),
    );
  }

  /// The `AUTH_RESP` hex to send back, or null if no key is known for [mac].
  static Future<String?> computeResponse({
    required String challengeHex,
    required String mac,
  }) async {
    final keyHex = await keyProvider.keyForMac(_normalizeMac(mac));
    if (keyHex == null || keyHex.isEmpty) return null;

    final key = _hexToBytes(keyHex);
    final challenge = _hexToBytes(challengeHex);
    final digest = Hmac(sha256, key).convert(challenge);
    return _bytesToHex(digest.bytes);
  }

  static String _normalizeMac(String mac) => mac.trim().toLowerCase();

  static Uint8List _hexToBytes(String hex) {
    final clean = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final out = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < out.length; i++) {
      out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Where per-device keys come from. Swap the implementation to change the
/// security posture without touching the auth flow.
///
/// Production recommendation: implement this against a Cloud Function that
/// takes the MAC and returns the key (or, better, takes MAC + challenge and
/// returns the finished HMAC so the key never reaches the phone at all).
abstract class DeviceKeyProvider {
  /// Hex-encoded secret key for [mac] (already lower-cased), or null.
  Future<String?> keyForMac(String mac);
}

/// TEST ONLY — keys compiled into the app. Do not ship with real fleet keys.
class BundledDeviceKeyProvider implements DeviceKeyProvider {
  const BundledDeviceKeyProvider();

  static const Map<String, String> _keys = {
    // device_001 — provided for bench testing the new auth scheme.
    '20:6e:f1:2e:81:a8':
        'a8063b3359a4bf05b55af9fde11f12455d3ddec2001b60a5207d82aed92c2380',
  };

  @override
  Future<String?> keyForMac(String mac) async => _keys[mac];
}
