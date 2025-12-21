import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_notification_service.dart';
import 'realtime_notification_service.dart';

class FirebaseService {
  static String? _currentDriver;

  /// Inicijalizuje Firebase
  static Future<void> initialize() async {
    try {
      // Safe to call from UI code. Request permissions where appropriate.
      // Note: Background handler is registered in main.dart to avoid duplication.
      if (Firebase.apps.isEmpty) return;

      final messaging = FirebaseMessaging.instance;

      // Request notification permission (harmless on Android but useful for iOS)
      try {
        await messaging.requestPermission();
      } catch (_) {}
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
      if (Firebase.apps.isEmpty) return null;
      final messaging = FirebaseMessaging.instance;
      return await messaging.getToken();
    } catch (e) {
      return null;
    }
  }

  /// 🔒 Flag da sprečimo višestruko registrovanje FCM listenera
  static bool _fcmListenerRegistered = false;

  /// Postavlja FCM listener
  static void setupFCMListeners() {
    // ✅ Sprečava višestruko registrovanje (duplirane notifikacije)
    if (_fcmListenerRegistered) return;
    _fcmListenerRegistered = true;

    if (Firebase.apps.isEmpty) return;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Show a local notification when app is foreground
      try {
        final title = message.notification?.title ?? 'Gavra Notification';
        final body = message.notification?.body ?? message.data['message'] ?? 'Nova notifikacija';
        LocalNotificationService.showRealtimeNotification(
            title: title, body: body, payload: message.data.isNotEmpty ? message.data.toString() : null);
      } catch (_) {}
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      try {
        // Navigate or handle tap
        RealtimeNotificationService.handleInitialMessage(message.data);
      } catch (_) {}
    });
  }
}
