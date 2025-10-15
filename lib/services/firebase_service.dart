import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseService {
  static String? _currentDriver;

  /// Inicijalizuje Firebase
  static Future<void> initialize() async {
    try {
      // Avoid duplicate initialization when app already initialized
      // Firebase.apps is only available on platforms that support it; use try/catch to be safe
      final alreadyInitialized = Firebase.apps.isNotEmpty;
      if (!alreadyInitialized) {
        await Firebase.initializeApp();
      }
    } catch (e) {
      // If initialization fails because it's already initialized, ignore the error
      // This makes initialization idempotent and safe to call from multiple places
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
  }

  /// Briše trenutnog vozača
  static Future<void> clearCurrentDriver() async {
    _currentDriver = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_driver');
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





