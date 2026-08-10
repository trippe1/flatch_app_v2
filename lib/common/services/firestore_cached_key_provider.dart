import 'package:cloud_functions/cloud_functions.dart';
import 'package:flatch/common/services/device_key_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Production device-key source: cache-on-phone.
///
/// Flow for a given device MAC:
///  1. Look in the phone's secure storage (iOS Keychain / Android Keystore).
///  2. On a miss, call the `getDeviceKey` Cloud Function (App Check + auth
///     gated) to fetch that device's key, and cache it.
///  3. Compute the HMAC locally (see [DeviceKeyService]).
///
/// So the key crosses the network only ONCE per device — every reconnect after
/// that works offline. The key is never in the app binary and is never
/// client-readable in Firestore; the function is the only path to it.
class FirestoreCachedKeyProvider implements DeviceKeyProvider {
  const FirestoreCachedKeyProvider();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String _cacheKey(String mac) => 'flatch_device_key_$mac';

  @override
  Future<String?> keyForMac(String mac) async {
    // 1. Cached?
    try {
      final cached = await _storage.read(key: _cacheKey(mac));
      if (cached != null && cached.isNotEmpty) return cached;
    } catch (_) {
      // Secure storage read can fail (e.g. keychain locked) — fall through to
      // the network path rather than blocking the user.
    }

    // 2. Fetch once from the server.
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('getDeviceKey');
      final result = await callable.call<Map<String, dynamic>>({'mac': mac});
      final key = result.data['key'] as String?;
      if (key == null || key.isEmpty) return null;

      // 3. Cache for offline reconnects (best-effort).
      try {
        await _storage.write(key: _cacheKey(mac), value: key);
      } catch (_) {}
      return key;
    } on FirebaseFunctionsException {
      // not-found (unregistered device), unauthenticated, App Check failure,
      // or offline with no cached key. The caller shows "device not recognized".
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Removes the cached key for [mac] — e.g. after a device is de-registered or
  /// re-keyed, so the next pair re-fetches.
  Future<void> forget(String mac) async {
    try {
      await _storage.delete(key: _cacheKey(mac));
    } catch (_) {}
  }
}
