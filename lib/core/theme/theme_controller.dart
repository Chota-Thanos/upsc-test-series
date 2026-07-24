import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's theme preference (system / light / dark) and persists it.
///
/// Default is [ThemeMode.system], so the app follows the device's light/dark
/// setting until the user explicitly overrides it. The override is saved to
/// SharedPreferences and restored on next launch.
class ThemeController extends ChangeNotifier {
  static const _prefsKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Loads the saved preference. Call once before runApp so the first frame
  /// already reflects the user's choice (no light-mode flash).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = _decode(prefs.getString(_prefsKey));
    } catch (_) {
      _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _encode(mode));
    } catch (_) {
      // Persistence is best-effort; the in-memory choice still applies.
    }
  }

  static ThemeMode _decode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
