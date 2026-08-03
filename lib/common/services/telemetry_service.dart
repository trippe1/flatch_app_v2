import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flatch/common/services/age_gate_service.dart';

/// Anonymous usage telemetry (Firebase Analytics) + crash reporting
/// (Crashlytics). Both are COPPA-gated: on an age-blocked (under-13) device,
/// collection is fully disabled and every event is a no-op — so we still learn
/// activation rates for eligible guests without collecting anything from kids.
class Telemetry {
  Telemetry._();
  static final Telemetry instance = Telemetry._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Apply collection consent from the age-gate flag. Call once at startup
  /// (after AgeGateService.preload) and again right after a device is blocked.
  Future<void> applyConsent() async {
    final blocked = await AgeGateService.instance.isBlocked();
    try {
      await _analytics.setAnalyticsCollectionEnabled(!blocked);
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        !blocked,
      );
    } catch (_) {}
  }

  Future<void> log(String event, [Map<String, Object>? params]) async {
    if (AgeGateService.instance.isBlockedCached) return;
    try {
      await _analytics.logEvent(name: event, parameters: params);
    } catch (_) {}
  }

  // ---- activation funnel ----
  Future<void> appOpen() => log('app_open');
  Future<void> deviceConnected() => log('device_connected');
  Future<void> stockSoundSynced() => log('stock_sound_synced');
  Future<void> signupStarted() => log('signup_started');
  Future<void> signupCompleted() => log('signup_completed');
}
