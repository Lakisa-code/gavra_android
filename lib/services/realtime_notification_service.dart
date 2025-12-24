import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_notification_service.dart';
import 'notification_navigation_service.dart';

class RealtimeNotificationService {
  static Future<bool> sendPushNotification({
    required String title,
    required String body,
    String? playerId,
    List<String>? externalUserIds,
    List<String>? driverIds,
    List<Map<String, dynamic>>? tokens,
    String? topic,
    Map<String, dynamic>? data,
  }) async {
    try {
      final payload = {
        if (playerId != null) 'player_id': playerId,
        if (externalUserIds != null) 'external_user_ids': externalUserIds,
        if (driverIds != null) 'driver_ids': driverIds,
        if (tokens != null) 'tokens': tokens,
        if (topic != null) 'topic': topic,
        'title': title,
        'body': body,
        'data': data ?? {},
      };

      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'send_fcm',
        body: payload,
      );

      if (response.data != null && response.data['success'] == true) {
        return true;
      } else {
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

  /// 🎯 Pošalji notifikaciju svim vozačima
  static Future<void> sendNotificationToAllDrivers({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final List<Future<void>> notifications = [];

    notifications.add(
      sendPushNotification(
        title: title,
        body: body,
        topic: 'gavra_all_drivers',
        data: data,
      ).then((_) {}),
    );

    notifications.add(
      LocalNotificationService.showRealtimeNotification(
        title: title,
        body: body,
        payload: jsonEncode(data ?? {}),
      ),
    );

    await Future.wait(notifications);
  }

  static Future<void> handleInitialMessage(Map<String, dynamic>? messageData) async {
    if (messageData == null) return;
    try {
      await _handleNotificationTap(messageData);
    } catch (e) {
      // Ignoriši greške pri rukovanju inicijalnom porukom
    }
  }

  static Future<void> initialize() async {
    try {
      // Firebase messaging inicijalizacija - no-op
    } catch (e) {
      // Ignoriši greške
    }
  }

  static bool _foregroundListenerRegistered = false;

  static void listenForForegroundNotifications(BuildContext context) {
    if (_foregroundListenerRegistered) return;
    _foregroundListenerRegistered = true;

    if (Firebase.apps.isEmpty) return;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      try {
        final data = message.data;

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

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      try {
        _handleNotificationTap(message.data);
      } catch (_) {}
    });
  }

  static Future<void> subscribeToDriverTopics(String? driverId) async {
    if (driverId == null || driverId.isEmpty) {
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        return;
      }

      final messaging = FirebaseMessaging.instance;

      await messaging.subscribeToTopic('gavra_driver_${driverId.toLowerCase()}');

      await messaging.subscribeToTopic('gavra_all_drivers');
    } catch (e) {
      // Ignoriši greške pri pretplati na topic
    }
  }

  /// Request notification permissions for Firebase
  static Future<bool> requestNotificationPermissions() async {
    try {
      if (Firebase.apps.isEmpty) return false;

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      return granted;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _handleNotificationTap(Map<String, dynamic> messageData) async {
    try {
      final notificationType = messageData['type'] ?? 'unknown';

      // 🚐 Za "transport_started" - otvori putnikov profil ekran
      if (notificationType == 'transport_started') {
        await NotificationNavigationService.navigateToPassengerProfile();
        return;
      }

      final putnikDataString = messageData['putnik'] as String?;

      if (putnikDataString != null) {
        final Map<String, dynamic> putnikData = jsonDecode(putnikDataString) as Map<String, dynamic>;

        await NotificationNavigationService.navigateToPassenger(
          type: notificationType as String,
          putnikData: putnikData,
        );
      }
    } catch (e) {
      // Ignoriši greške pri navigaciji
    }
  }
}
