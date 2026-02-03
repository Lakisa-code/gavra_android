import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_manager.dart';
import 'firebase_background_handler.dart';
import 'local_notification_service.dart';
import 'push_token_service.dart';
import 'realtime_notification_service.dart';

class FirebaseService {
  static String? _currentDriver;

  /// Inicijalizuje Firebase
  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) return;

      final messaging = FirebaseMessaging.instance;

      // 🌙 Background Handler Registration
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request notification permission
      try {
        await messaging.requestPermission();
      } catch (e) {
        debugPrint('⚠️ Error requesting FCM permission: $e');
      }
    } catch (e) {
      // Ignoriši greške
    }
  }

  /// Dobija trenutnog vozača - DELEGIRA NA AuthManager
  /// AuthManager čita iz Supabase (push_tokens tabela) kao izvor istine
  static Future<String?> getCurrentDriver() async {
    _currentDriver = await AuthManager.getCurrentDriver();
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

  /// 📲 Registruje FCM token na server (push_tokens tabela)
  /// Ovo se mora pozvati pri pokretanju aplikacije
  static Future<String?> initializeAndRegisterToken() async {
    try {
      if (Firebase.apps.isEmpty) return null;

      final messaging = FirebaseMessaging.instance;

      // Request permission
      try {
        await messaging.requestPermission();
      } catch (e) {
        debugPrint('⚠️ Error requesting FCM permission (init): $e');
      }

      // Get token
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerTokenWithServer(token);

        // Listen for token refresh
        messaging.onTokenRefresh.listen(
          (newToken) async {
            await _registerTokenWithServer(newToken);
          },
          onError: (error) {
            debugPrint('🔴 [FirebaseService] Token refresh error: $error');
          },
        );

        return token;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Registruje FCM token u push_tokens tabelu
  /// Koristi unificirani PushTokenService
  static Future<void> _registerTokenWithServer(String token) async {
    String? driverName;
    try {
      driverName = await AuthManager.getCurrentDriver();
    } catch (e) {
      debugPrint('⚠️ Error getting current driver for FCM: $e');
      driverName = null;
    }

    // Registruj samo ako je vozač ulogovan
    if (driverName == null || driverName.isEmpty) {
      debugPrint('⚠️ [FirebaseService] Vozač nije ulogovan - preskačem FCM registraciju');
      return;
    }

    await PushTokenService.registerToken(
      token: token,
      provider: 'fcm',
      userType: 'vozac',
      userId: driverName,
    );
  }

  /// Pokušaj registrovati pending token
  /// Delegira na PushTokenService
  static Future<void> tryRegisterPendingToken() async {
    await PushTokenService.tryRegisterPendingToken();
  }

  /// 🔒 Flag da sprečimo višestruko registrovanje FCM listenera
  static bool _fcmListenerRegistered = false;

  /// Postavlja FCM listener
  static void setupFCMListeners() {
    // ✅ Sprečava višestruko registrovanje (duplirane notifikacije)
    if (_fcmListenerRegistered) return;
    _fcmListenerRegistered = true;

    if (Firebase.apps.isEmpty) return;

    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) {
        // Show a local notification when app is foreground
        try {
          // Prvo pokušaj notification payload, pa data payload
          final title = message.notification?.title ?? message.data['title'] as String? ?? 'Gavra Notification';
          final body = message.notification?.body ??
              message.data['body'] as String? ??
              message.data['message'] as String? ??
              'Nova notifikacija';
          LocalNotificationService.showRealtimeNotification(
              title: title, body: body, payload: message.data.isNotEmpty ? message.data.toString() : null);
        } catch (_) {}
      },
      onError: (error) {
        debugPrint('🔴 [FirebaseService] onMessage stream error: $error');
      },
    );

    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {
        try {
          // Navigate or handle tap
          RealtimeNotificationService.handleInitialMessage(message.data);
        } catch (e) {
          debugPrint('🔴 [FirebaseService] onMessageOpenedApp error: $e');
        }
      },
      onError: (error) {
        debugPrint('🔴 [FirebaseService] onMessageOpenedApp stream error: $error');
      },
    );
  }
}
