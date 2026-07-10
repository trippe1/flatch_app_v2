import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App theme controller. The chosen mode is persisted so it survives restarts
/// (it previously reset to dark every launch), and `ThemeMode.system` is
/// supported for honoring the OS setting.
class ThemeController {
  static const _key = 'theme_mode';

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.dark,
  );

  /// Loads the saved preference. Call once before `runApp()`.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      switch (prefs.getString(_key)) {
        case 'light':
          themeMode.value = ThemeMode.light;
        case 'system':
          themeMode.value = ThemeMode.system;
        case 'dark':
          themeMode.value = ThemeMode.dark;
        default:
          break; // no saved preference — keep the default (dark)
      }
    } catch (_) {
      // ignore storage errors; fall back to the in-memory default
    }
  }

  /// Sets an explicit mode (Light / Dark / System) and persists it.
  static Future<void> setMode(ThemeMode mode) async {
    themeMode.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {}
  }

  /// Binary flip used by the settings switch; also persists.
  static void toggleTheme() {
    setMode(
      themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}
