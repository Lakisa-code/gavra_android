import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static FirebaseAnalytics? _analytics;
  static FirebaseAnalyticsObserver? _observer;

  /// Inicijalizuje Analytics
  static Future<void> initialize() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
    } catch (e) {
      // Ignoriši greške u analytics
    }
  }

  /// Dobija observer za Navigator
  static FirebaseAnalyticsObserver? get observer => _observer;

  /// 👤 LOGIRANJE VOZAČA
  static Future<void> logVozacPrijavljen(String vozac) async {
    try {
      await _analytics?.logEvent(
        name: 'vozac_prijavljen',
        parameters: {
          'vozac': vozac,
          'vreme': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      // Ignoriši greške
    }
  }

  static Future<void> logVozacOdjavljen(String vozac) async {
    try {
      await _analytics?.logEvent(
        name: 'vozac_odjavljen',
        parameters: {
          'vozac': vozac,
          'vreme': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      // Ignoriši greške
    }
  }

  /// 🚗 LOGIRANJE POLAZAKA
  static Future<void> logPolazakKreiran(String vozac, String? destinacija) async {
    try {
      await _analytics?.logEvent(
        name: 'polazak_kreiran',
        parameters: {
          'vozac': vozac,
          'destinacija': destinacija ?? 'nepoznata',
          'vreme': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      // Ignoriši greške
    }
  }

  static Future<void> logPolazakObrisan(String vozac) async {
    try {
      await _analytics?.logEvent(
        name: 'polazak_obrisan',
        parameters: {
          'vozac': vozac,
          'vreme': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      // Ignoriši greške
    }
  }

  /// 🔔 LOGIRANJE NOTIFIKACIJA
  static Future<void> logNotifikacijaPoslana(String tip, String? primalac) async {
    try {
      await _analytics?.logEvent(
        name: 'notifikacija_poslana',
        parameters: {
          'tip': tip,
          'primalac': primalac ?? 'svi',
          'vreme': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      // Ignoriši greške
    }
  }

  /// 🎨 LOGIRANJE TEME
  static Future<void> logTemaPromenjena(bool nocniRezim) async {
    try {
      await _analytics?.logEvent(
        name: 'tema_promenjena',
        parameters: {
          'nova_tema': nocniRezim ? 'tamna' : 'svetla',
          'vreme': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      // Ignoriši greške
    }
  }

  /// 📱 LOGIRANJE EKRANA
  static Future<void> logScreenView(String screenName, String? screenClass) async {
    try {
      await _analytics?.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      // Ignoriši greške
    }
  }

  /// 🎵 LOGIRANJE AUDIO DOGAĐAJA
  static Future<void> logAudioPustenj(String audioFile, String vozac) async {
    try {
      await _analytics?.logEvent(
        name: 'audio_pusteno',
        parameters: {
          'fajl': audioFile,
          'vozac': vozac,
          'vreme': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      // Ignoriši greške
    }
  }

  /// ⚙️ LOGIRANJE GREŠAKA
  static Future<void> logGreska(String greska, String? kontekst) async {
    try {
      await _analytics?.logEvent(
        name: 'greska_aplikacije',
        parameters: {
          'greska': greska,
          'kontekst': kontekst ?? 'nepoznat',
          'vreme': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      // Ignoriši greške
    }
  }

  /// 📊 LOGIRANJE CUSTOM DOGAĐAJA
  static Future<void> logCustomEvent(String eventName, Map<String, Object>? parameters) async {
    try {
      await _analytics?.logEvent(
        name: eventName,
        parameters: parameters ?? {},
      );
    } catch (e) {
      // Ignoriši greške
    }
  }

  /// 👥 POSTAVLJANJE USER SVOJSTAVA
  static Future<void> setUserProperty(String name, String? value) async {
    try {
      await _analytics?.setUserProperty(name: name, value: value);
    } catch (e) {
      // Ignoriši greške
    }
  }

  /// 🆔 POSTAVLJANJE USER ID
  static Future<void> setUserId(String userId) async {
    try {
      await _analytics?.setUserId(id: userId);
    } catch (e) {
      // Ignoriši greške
    }
  }
}
