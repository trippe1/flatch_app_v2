import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// COPPA-safe age gate.
///
/// Records whether this device has been blocked at the age gate (someone
/// entered an under-13 birthdate). The flag lives in the platform secure store:
/// on iOS the Keychain survives app reinstalls (so a blocked device stays
/// blocked); on Android it is best-effort and is cleared on uninstall.
///
/// Once [isBlocked] is true the app must suppress: account creation, all social
/// features (feed/upload/comment/vote/profile), microphone access, and any
/// personal-data collection (analytics included).
class AgeGateService {
  AgeGateService._();
  static final AgeGateService instance = AgeGateService._();

  /// Minimum age to create an account / use social + microphone features.
  static const int minAgeYears = 13;

  static const String _key = 'age_gate_blocked_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool? _cache;

  /// Load the flag into the in-memory cache once at startup so [isBlockedCached]
  /// can be read synchronously by permission/UI gates.
  Future<bool> preload() => isBlocked();

  Future<bool> isBlocked() async {
    if (_cache != null) return _cache!;
    try {
      _cache = (await _storage.read(key: _key)) == 'true';
    } catch (_) {
      _cache = false;
    }
    return _cache!;
  }

  /// Synchronous view of the flag. Safe (defaults to false) but only accurate
  /// after [preload]/[isBlocked] has run — use for cheap UI/permission guards.
  bool get isBlockedCached => _cache ?? false;

  /// Permanently block this device (best-effort on Android). Irreversible by
  /// design — a blocked device cannot retry the gate by reinstalling on iOS.
  Future<void> block() async {
    _cache = true;
    try {
      await _storage.write(key: _key, value: 'true');
    } catch (_) {
      // best-effort; the in-memory flag still blocks this session
    }
  }

  /// Whether [birthDate] is at least [minAgeYears] old as of [now].
  static bool meetsMinimumAge(DateTime birthDate, {DateTime? now}) {
    final today = now ?? DateTime.now();
    var age = today.year - birthDate.year;
    final hadBirthdayThisYear =
        today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hadBirthdayThisYear) age--;
    return age >= minAgeYears;
  }
}
