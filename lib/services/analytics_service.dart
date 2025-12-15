// import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  // static FirebaseAnalytics? _analytics;
  // static FirebaseAnalyticsObserver? _observer;

  /// Inicijalizuje Analytics
  static Future<void> initialize() async {
    try {
      // _analytics = FirebaseAnalytics.instance;
      // _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
    } catch (e) {
      // Ignoriši greške u analytics
    }
  }

  /// Dobija observer za Navigator
  static dynamic get observer => null; // _observer;

  /// 👤 LOGIRANJE VOZAČA
  static Future<void> logVozacPrijavljen(String vozac) async {
    try {
      // await _analytics?.logEvent(
      //   name: 'vozac_prijavljen',
      //   parameters: {
      //     'vozac': vozac,
      //     'vreme': DateTime.now().toIso8601String(),
      //   },
      // );
    } catch (e) {
      // Ignoriši greške
    }
  }

  static Future<void> logVozacOdjavljen(String vozac) async {
    try {
      // await _analytics?.logEvent(
      //   name: 'vozac_odjavljen',
      //   parameters: {
      //     'vozac': vozac,
      //     'vreme': DateTime.now().toIso8601String(),
      //   },
      // );
    } catch (e) {
      // Ignoriši greške
    }
  }

  /// 📊 LOGIRANJE CUSTOM DOGAĐAJA
  static Future<void> logCustomEvent(
    String eventName,
    Map<String, Object>? parameters,
  ) async {
    try {
      // await _analytics?.logEvent(
      //   name: eventName,
      //   parameters: parameters ?? {},
      // );
    } catch (e) {
      // Ignoriši greške
    }
  }
}
