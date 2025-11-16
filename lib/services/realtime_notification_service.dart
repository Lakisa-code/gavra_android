import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_notification_service.dart';
import 'notification_navigation_service.dart';

class RealtimeNotificationService {
  /// IMPORTANT: Do NOT store your OneSignal REST API key in the client app.
  ///
  /// OneSignal konfiguracija direktno u aplikaciji
  /// App ID: 4fd57af1-568a-45e0-a737-3b3918c4e92a
  /// REST Key je sada SAKRIVEN na server-side (Supabase Edge Function)

  /// 🔒 SIGURNO: Pošalji OneSignal notifikaciju putem Supabase Edge Function
  static Future<void> sendOneSignalNotification({
    required String title,
    required String body,
    String? playerId, // Ako želiš da šalješ pojedinačno
    String? segment, // Ili segment (npr. "All")
    Map<String, dynamic>? data,
  }) async {
    // 🔒 SIGURNO: REST API ključ je na server-side (Supabase Edge Function)
    const String appId = '4fd57af1-568a-45e0-a737-3b3918c4e92a';

    try {
      final payload = {
        'app_id': appId,
        'title': title,
        'body': body,
        if (playerId != null) 'player_id': playerId,
        if (segment != null) 'segment': segment,
        if (data != null) 'data': data,
      };

      // 🌐 Pozovi Supabase Edge Function umesto direktnog REST poziva
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'send-onesignal-notification',
        body: payload,
      );

      if (response.data != null && response.data['success'] == true) {
        // Logger removed - successful OneSignal send
      } else {
        // Logger removed - OneSignal send failed
      }
    } catch (e) {
      // Fallback to local notification if OneSignal fails
      try {
        await LocalNotificationService.showRealtimeNotification(
          title: title,
          body: body,
          payload: jsonEncode(data ?? {}),
        );
      } catch (fallbackError) {
        // Logger removed - both OneSignal and local notification failed
      }
    }
  }

  /// 🔥 SIGURNO: Pošalji FCM notifikaciju putem Supabase Edge Function
  static Future<bool> sendFCMNotification({
    required String title,
    required String body,
    required String targetType, // 'token', 'topic', 'condition'
    required String targetValue, // device token, topic name, ili condition
    Map<String, dynamic>? data,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      final payload = {
        'title': title,
        'body': body,
        'data': data ?? {},
        'target': {
          'type': targetType,
          'value': targetValue,
        },
      };

      final response = await supabase.functions.invoke(
        'send-fcm-notification',
        body: payload,
      );

      if (response.data != null && response.data['success'] == true) {
        // Logger removed - FCM sent successfully
        return true;
      } else {
        // Logger removed - FCM send failed
        return false;
      }
    } catch (e) {
      // Logger removed - FCM function call failed
      return false;
    }
  }

  /// 🎯 Pošalji notifikaciju svim vozačima
  static Future<void> sendNotificationToAllDrivers({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Multi-channel strategija
    final List<Future<void>> notifications = [];

    // 1. FCM - pošalji svim pretplatnicima topic-a
    notifications.add(
      sendFCMNotification(
        title: title,
        body: body,
        targetType: 'topic',
        targetValue: 'gavra_all_drivers',
        data: data,
      ).then((_) {}), // Convert Future<bool> to Future<void>
    );

    // 2. OneSignal - pošalji svim korisnicima
    notifications.add(
      sendOneSignalNotification(
        title: title,
        body: body,
        segment: 'All',
        data: data,
      ),
    );

    // 3. Local notification kao fallback
    notifications.add(
      LocalNotificationService.showRealtimeNotification(
        title: title,
        body: body,
        payload: jsonEncode(data ?? {}),
      ),
    );

    // Pokreni sve paralelno
    await Future.wait(notifications);
  }

  /// 🎯 Pošalji notifikaciju specifičnom vozaču
  static Future<void> sendNotificationToDriver({
    required String driverId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Multi-channel strategija za specifičnog vozača
    final List<Future<void>> notifications = [];

    // 1. FCM - topic za specifičnog vozača
    notifications.add(
      sendFCMNotification(
        title: title,
        body: body,
        targetType: 'topic',
        targetValue: 'gavra_driver_${driverId.toLowerCase()}',
        data: data,
      ).then((_) {}),
    );

    // 2. Možete dodati OneSignal targeting po User ID-u
    // 3. Local notification
    notifications.add(
      LocalNotificationService.showRealtimeNotification(
        title: title,
        body: body,
        payload: jsonEncode(data ?? {}),
      ),
    );

    await Future.wait(notifications);
  }

  /// Public helper to handle an initial/cold-start RemoteMessage (from getInitialMessage)
  static Future<void> handleInitialMessage(RemoteMessage? message) async {
    if (message == null) return;
    try {
      await _handleFirebaseNotificationTap(message);
    } catch (e) {
      // Logger removed
    }
  }

  /// Initialize service with full multi-channel support (Firebase + OneSignal + Local)
  static Future<void> initialize() async {}

  /// Setup foreground Firebase message listeners for real-time notifications
  static void listenForForegroundNotifications(BuildContext context) {
    // Logger removed

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Logger removed

      // Filtriraj notifikacije: samo za današnji dan i za tip "dodat"/"novi_putnik" ili "otkazan"/"otkazan_putnik"
      final data = message.data;
      final type = (data['type'] ?? '').toString().toLowerCase();
      final datumString = (data['datum'] ?? data['date'] ?? '') as String;
      final danas = DateTime.now();
      bool isToday = false;
      if (datumString.isNotEmpty) {
        try {
          final datum = DateTime.parse(datumString);
          isToday = datum.year == danas.year &&
              datum.month == danas.month &&
              datum.day == danas.day;
        } catch (_) {
          isToday = false;
        }
      }

      if ((type == 'dodat' ||
              type == 'novi_putnik' ||
              type == 'otkazan' ||
              type == 'otkazan_putnik') &&
          isToday) {
        LocalNotificationService.showRealtimeNotification(
          title: message.notification?.title ?? 'Gavra Notification',
          body: message.notification?.body ?? 'Nova poruka',
          payload: (message.data['type'] as String?) ?? 'firebase_foreground',
        );
      } else {}
    });

    // Listen for message taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Logger removed
      // Handle navigation based on message data
      _handleFirebaseNotificationTap(message);
    });
  }

  /// Subscribe to Firebase topics for driver-specific notifications
  static Future<void> subscribeToDriverTopics(String? driverId) async {
    if (driverId == null || driverId.isEmpty) {
      // Logger removed
      return;
    }

    try {
      // Logger removed

      // Subscribe to general topic
      await FirebaseMessaging.instance.subscribeToTopic('gavra_all_drivers');

      // Subscribe to driver-specific topic
      await FirebaseMessaging.instance
          .subscribeToTopic('gavra_driver_${driverId.toLowerCase()}');

      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }

  /// Real-time notifications using Firebase + OneSignal + Local notifications
  static void sendRealtimeNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) {
    // Logger removed

    try {
      // 1. Send local notification immediately (highest priority)
      // Convert data to JSON string payload for notification
      final String payloadJson = jsonEncode(data);

      LocalNotificationService.showRealtimeNotification(
        title: title,
        body: body,
        payload: payloadJson,
      );
      // Logger removed

      // 2. Firebase Cloud Messaging (server-side implementation needed)
      // Note: FCM sending is typically done from server, not client
      // Logger removed

      // 3. OneSignal notification (REST API poziv iz klijenta)
      // Slanje svima u segmentu "All" (ili koristi playerId za pojedinačne korisnike)
      RealtimeNotificationService.sendOneSignalNotification(
        title: title,
        body: body,
        segment: 'All',
        data: data,
      );
    } catch (e) {
      // Logger removed
    }
  }

  /// Test notification functionality with multi-channel support
  static Future<void> sendTestNotification(String message) async {
    // Show local notification
    await LocalNotificationService.showRealtimeNotification(
      title: 'Gavra Test - Multi Channel',
      body: message,
      payload: 'test_notification',
    );
  }

  /// Check notification permissions for Firebase
  static Future<bool> hasNotificationPermissions() async {
    // Logger removed
    try {
      NotificationSettings settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      bool hasPermission =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      // Logger removed
      return hasPermission;
    } catch (e) {
      // Logger removed
      return false;
    }
  }

  /// Request notification permissions for Firebase
  static Future<bool> requestNotificationPermissions() async {
    // Logger removed
    try {
      // Check if Firebase is available first
      if (!Firebase.apps.isNotEmpty) {
        // Logger removed
        return false;
      }

      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission()
          .timeout(const Duration(seconds: 10));

      bool granted =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      // Logger removed
      return granted;
    } catch (e) {
      // Logger removed
      // Return false but don't crash the app
      return false;
    }
  }

  /// Handle Firebase notification tap - navigate to specific passenger
  static Future<void> _handleFirebaseNotificationTap(
    RemoteMessage message,
  ) async {
    try {
      // Logger removed

      // Extract notification type and passenger data from Firebase message
      final notificationType = message.data['type'] ?? 'unknown';
      final putnikDataString = message.data['putnik'] as String?;

      if (putnikDataString != null) {
        // Parse passenger data from JSON string
        final Map<String, dynamic> putnikData =
            jsonDecode(putnikDataString) as Map<String, dynamic>;

        // Use NotificationNavigationService to show popup and navigate
        await NotificationNavigationService.navigateToPassenger(
          type: notificationType as String,
          putnikData: putnikData,
        );
      } else {
        // Logger removed
      }
    } catch (e) {
      // Logger removed
    }
  }
}
