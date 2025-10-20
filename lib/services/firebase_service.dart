import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';

class FirebaseService {
  static String? _currentDriver;

  /// Inicijalizuje Firebase
  static Future<void> initialize() async {
    try {
      // Firebase je već inicijalizovan u main.dart sa pravilnim opcijama
      // Ova metoda se zadržava za kompatibilnost
      final messaging = FirebaseMessaging.instance;

      // Traži dozvole za notifikacije
      await messaging.requestPermission();
    } catch (e) {
      // Ignoriši greške
    }
  }

  /// Dobija trenutnog vozača iz SharedPreferences
  static Future<String?> getCurrentDriver() async {
    if (_currentDriver != null) return _currentDriver;

    final prefs = await SharedPreferences.getInstance();
    _currentDriver = prefs.getString('current_driver');
    return _currentDriver;
  }

  /// Postavlja trenutnog vozača
  static Future<void> setCurrentDriver(String driver) async {
    _currentDriver = driver;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_driver', driver);

    // 📊 Analytics - vozač se prijavio
    await AnalyticsService.logVozacPrijavljen(driver);
  }

  /// Briše trenutnog vozača
  static Future<void> clearCurrentDriver() async {
    final oldDriver = _currentDriver;
    _currentDriver = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_driver');

    // 📊 Analytics - vozač se odjavio
    if (oldDriver != null) {
      await AnalyticsService.logVozacOdjavljen(oldDriver);
    }
  }

  /// Dobija FCM token
  static Future<String?> getFCMToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      return await messaging.getToken();
    } catch (e) {
      return null;
    }
  }

  /// Postavlja FCM listener
  static void setupFCMListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {}
    });
  }
}
