import 'package:shared_preferences/shared_preferences.dart';

/// Feature flags for toggling app-wide features.
/// - FREE_MODE: Disables all paid/commercial providers and uses open-source/free alternatives.
class FeatureFlags {
  // Build-time constant (can be passed via dart-define: -DFREE_MODE=true)
  static const bool _buildFreeMode = bool.fromEnvironment('FREE_MODE', defaultValue: false);

  // Runtime override - loads from SharedPreferences on app startup
  static bool freeMode = _buildFreeMode;

  /// Initialize feature flags from persistent storage (call at app start).
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('free_mode')) {
        freeMode = prefs.getBool('free_mode') ?? freeMode;
      }
    } catch (_) {
      // ignore
    }
  }

  /// Set runtime free mode override and persist it.
  static Future<void> setFreeMode(bool enabled) async {
    freeMode = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('free_mode', enabled);
    } catch (_) {
      // ignore
    }
  }
}
