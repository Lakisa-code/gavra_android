import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// Firebase messaging removed for this branch; notification delivery is
// handled server-side (Supabase functions) and platform-specific clients
// (Huawei Push). This service focuses on server-side/in-app notification
// helpers and local fallback notifications.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_notification_service.dart';
import 'notification_navigation_service.dart';

class RealtimeNotificationService {
  /// IMPORTANT: Do NOT store provider REST/API keys in the client app.
  /// This app uses FCM + Huawei Push; provider keys must be stored server-side as Supabase secrets.

  /// 🔒 SIGURNO: Pošalji Push notifikaciju (FCM/Huawei) putem Supabase Edge Function
  static Future<bool> sendPushNotification({
    required String title,
    required String body,
    String? playerId, // Ako želiš da šalješ pojedinačno
    List<String>? externalUserIds,
    List<String>? driverIds,
    List<Map<String, dynamic>>? tokens, // [{token, provider}]
    String? segment, // Ili segment (npr. "All")
    Map<String, dynamic>? data,
  }) async {
    try {
      final payload = {
        if (playerId != null) 'player_id': playerId,
        if (externalUserIds != null) 'external_user_ids': externalUserIds,
        if (driverIds != null) 'driver_ids': driverIds,
        if (tokens != null) 'tokens': tokens,
        if (segment != null) 'segment': segment,
        'title': title,
        'body': body,
        'data': data ?? {},
      };

      // 🌐 Pozovi Supabase Edge Function umesto direktnog REST poziva
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'send-push-notification',
        body: payload,
      );

      if (response.data != null && response.data['success'] == true) {
        return true;
      } else {
        // Try local fallback
        await LocalNotificationService.showRealtimeNotification(
            title: title, body: body, payload: jsonEncode(data ?? {}));
        return false;
      }
    } catch (e) {
      try {
        await LocalNotificationService.showRealtimeNotification(
            title: title, body: body, payload: jsonEncode(data ?? {}));
      } catch (_) {}
      return false;
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

    // 2. Server-side push (send-push-notification) to all active push players (FCM + Huawei)
    notifications.add(
      RealtimeNotificationService.sendPushNotification(
        title: title,
        body: body,
        segment: 'All',
        data: data,
      ).then((_) {}),
    );
    //    If 'send-push-notification' supports 'segment: All' future enhancement can move here.

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

  /// 🎯 Pošalji notifikaciju specifičnom vozaču (via server-side push)
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

    // 2. Server-side push for targeted driver tokens
    notifications.add(
      sendPushNotification(
        title: title,
        body: body,
        driverIds: [driverId],
        data: data,
      ),
    );
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
  static Future<void> handleInitialMessage(Map<String, dynamic>? messageData) async {
    if (messageData == null) return;
    try {
      await _handleNotificationTap(messageData);
    } catch (e) {
      // ignore
    }
  }

  /// Initialize service with real-time notifications only
  static Future<void> initialize() async {
    try {
      // If Firebase hasn't been initialized (eg: no GMS on device) bail out
      // — accessing FirebaseMessaging.instance will throw if no default app.
      // No-op: Firebase messaging removed. Leave permission management to
      // platform-specific push helpers (HuaweiPushService) or local notification
      // permission flows.
    } catch (e) {
      // ignore
    }
  }

  /// Setup foreground Firebase message listeners for real-time notifications
  static void listenForForegroundNotifications(BuildContext context) {
    // Initialize Firebase listeners if available.
    if (Firebase.apps.isEmpty) return;

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      try {
        final data = message.data;

        // Filtriraj notifikacije: samo za današnji dan i za tip "dodat"/"novi_putnik" ili "otkazan"/"otkazan_putnik"
        final type = (data['type'] ?? '').toString().toLowerCase();
        final datumString = (data['datum'] ?? data['date'] ?? '') as String;
        final danas = DateTime.now();
        bool isToday = false;
        if (datumString.isNotEmpty) {
          try {
            final datum = DateTime.parse(datumString);
            isToday = datum.year == danas.year && datum.month == danas.month && datum.day == danas.day;
          } catch (_) {
            isToday = false;
          }
        }

        if ((type == 'dodat' || type == 'novi_putnik' || type == 'otkazan' || type == 'otkazan_putnik') && isToday) {
          LocalNotificationService.showRealtimeNotification(
            title: message.notification?.title ?? 'Gavra Notification',
            body: message.notification?.body ?? 'Nova poruka',
            payload: (data['type'] as String?) ?? 'firebase_foreground',
          );
        }
      } catch (_) {}
    });

    // Listen for message taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      try {
        _handleNotificationTap(message.data);
      } catch (_) {}
    });
  }

  /// Subscribe to Firebase topics for driver-specific notifications
  static Future<void> subscribeToDriverTopics(String? driverId) async {
    if (driverId == null || driverId.isEmpty) {
      // Logger removed
      return;
    }

    try {
      // No-op — topic subscription is provider-specific and removed for now.
      // Logger removed

      // Subscribe to general topic
      // Topic subscription removed — handled server-side or via provider SDK.

      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }

  /// Real-time notifications using Firebase + Huawei + Local notifications (server-side push via Supabase functions)
  static Future<void> sendRealtimeNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    // Logger removed

    try {
      // 1. Send local notification immediately (highest priority)
      // Convert data to JSON string payload for notification
      final String payloadJson = jsonEncode(data);

      await LocalNotificationService.showRealtimeNotification(
        title: title,
        body: body,
        payload: payloadJson,
      );
      // Logger removed

      // 2. Firebase Cloud Messaging (server-side implementation needed)
      // Note: FCM sending is typically done from server, not client
      // Logger removed

      // 3. Server-side: FCM topic/broadcast
      await RealtimeNotificationService.sendFCMNotification(
        title: title,
        body: body,
        targetType: 'topic',
        targetValue: 'gavra_all_drivers',
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
      // Messaging SDK removed; we don't expose per-provider permission status
      // here. Return false so callers can run their own permission checks.
      return false;
    } catch (e) {
      // Logger removed
      return false;
    }
  }

  /// Request notification permissions for Firebase
  static Future<bool> requestNotificationPermissions() async {
    // Logger removed
    try {
      // Requesting permissions is provider-specific (Huawei/FCM/Local). For
      // the simplified branch return false to indicate the app should
      // request permissions through platform-specific helpers when needed.
      return false;
    } catch (e) {
      // Logger removed
      // Return false but don't crash the app
      return false;
    }
  }

  /// Handle Firebase notification tap - navigate to specific passenger
  static Future<void> _handleNotificationTap(Map<String, dynamic> messageData) async {
    try {
      // Logger removed

      // Extract notification type and passenger data from payload
      final notificationType = messageData['type'] ?? 'unknown';
      final putnikDataString = messageData['putnik'] as String?;

      if (putnikDataString != null) {
        // Parse passenger data from JSON string
        final Map<String, dynamic> putnikData = jsonDecode(putnikDataString) as Map<String, dynamic>;

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
