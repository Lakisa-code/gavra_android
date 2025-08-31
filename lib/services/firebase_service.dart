import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseService {
  static String? _currentDriver;

  /// Inicijalizuje Firebase
  static Future<void> initialize() async {
    await Firebase.initializeApp();
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
      // print('Error getting FCM token: $e'); // Removed for production
      return null;
    }
  }

  /// Postavlja FCM listener
  static void setupFCMListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // print('Got a message whilst in the foreground!'); // Removed for production
      // print('Message data: ${message.data}'); // Removed for production

      if (message.notification != null) {
        // print('Message also contained a notification: ${message.notification}'); // Removed for production
      }
    });
  }
}
