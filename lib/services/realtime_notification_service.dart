import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'local_notification_service.dart';
import 'notification_navigation_service.dart';
import 'package:logger/logger.dart';

class RealtimeNotificationService {
  /// OneSignal REST API endpoint
  static const String _oneSignalApiUrl =
      'https://onesignal.com/api/v1/notifications';

  /// TODO: Unesi svoj OneSignal REST API ključ ovde
  static const String _oneSignalRestApiKey = 'dymepwhpkubkfxhqhc4mlh2x7';

  /// Pošalji OneSignal notifikaciju putem REST API-ja
  static Future<void> sendOneSignalNotification({
    required String title,
    required String body,
    String? playerId, // Ako želiš da šalješ pojedinačno
    String? segment, // Ili segment (npr. "All")
    Map<String, dynamic>? data,
  }) async {
    if (_oneSignalRestApiKey.isEmpty) {
      _logger.w(
          '❗ OneSignal REST API ključ nije postavljen. Notifikacija nije poslata.');
      return;
    }
    try {
      final payload = {
        'app_id': '4fd57af1-568a-45e0-a737-3b3918c4e92a',
        'headings': {'en': title},
        'contents': {'en': body},
        if (playerId != null) 'include_player_ids': [playerId],
        if (segment != null) 'included_segments': [segment],
        if (data != null) 'data': data,
      };
      final req = await HttpClient().postUrl(Uri.parse(_oneSignalApiUrl));
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Authorization', 'Basic $_oneSignalRestApiKey');
      req.add(utf8.encode(jsonEncode(payload)));
      final httpResponse = await req.close();
      final responseBody = await utf8.decoder.bind(httpResponse).join();
      if (httpResponse.statusCode == 200) {
        _logger.i('✅ OneSignal notifikacija poslata: $responseBody');
      } else {
        _logger.e('❌ Greška pri slanju OneSignal notifikacije: $responseBody');
      }
    } catch (e) {
      _logger.e('❌ Exception pri slanju OneSignal notifikacije: $e');
    }
  }

  static final Logger _logger = Logger();

  /// Initialize service with full multi-channel support (Firebase + OneSignal + Local)
  static Future<void> initialize() async {
    _logger.i(
        '🔔 RealtimeNotificationService initialized - multi-channel: Firebase + OneSignal + Local');
  }

  /// Setup foreground Firebase message listeners for real-time notifications
  static void listenForForegroundNotifications(BuildContext context) {
    _logger.i('🔔 Setting up Firebase foreground message listeners...');

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger
          .i('📱 Foreground Firebase message: ${message.notification?.title}');

      // Filtriraj notifikacije: samo za današnji dan i za tip "dodat" ili "otkazan"
      final data = message.data;
      final type = (data['type'] ?? '').toString().toLowerCase();
      final datumString = data['datum'] ?? data['date'] ?? '';
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

      if ((type == 'dodat' || type == 'otkazan') && isToday) {
        LocalNotificationService.showRealtimeNotification(
          title: message.notification?.title ?? 'Gavra Notification',
          body: message.notification?.body ?? 'Nova poruka',
          payload: message.data['type'] ?? 'firebase_foreground',
          playCustomSound: true,
        );
      } else {
        _logger.i(
            '🔕 Notifikacija ignorisana (nije za danas ili nije tip dodat/otkazan)');
      }
    });

    // Listen for message taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.i('📱 Firebase message opened: ${message.notification?.title}');
      // Handle navigation based on message data
      _handleFirebaseNotificationTap(message);
    });
  }

  /// Subscribe to Firebase topics for driver-specific notifications
  static Future<void> subscribeToDriverTopics(String? driverId) async {
    if (driverId == null || driverId.isEmpty) {
      _logger.w('🔔 Driver ID is null, skipping Firebase topic subscription');
      return;
    }

    try {
      _logger.i('🔔 Subscribing to Firebase topics for driver: $driverId');

      // Subscribe to general topic
      await FirebaseMessaging.instance.subscribeToTopic('gavra_all_drivers');

      // Subscribe to driver-specific topic
      await FirebaseMessaging.instance
          .subscribeToTopic('gavra_driver_${driverId.toLowerCase()}');

      _logger.i('✅ Firebase topic subscriptions completed for $driverId');
    } catch (e) {
      _logger.e('❌ Firebase topic subscription failed: $e');
    }
  }

  /// Real-time notifications using Firebase + OneSignal + Local notifications
  static void sendRealtimeNotification(
      String title, String body, Map<String, dynamic> data) {
    _logger.i('🔔 Sending multi-channel notification: $title - $body');

    try {
      // 1. Send local notification immediately (highest priority)
      // Convert data to JSON string payload for notification
      final String payloadJson = jsonEncode(data);

      LocalNotificationService.showRealtimeNotification(
        title: title,
        body: body,
        payload: payloadJson,
        playCustomSound: true,
      );
      _logger.i('✅ Local notification sent');

      // 2. Firebase Cloud Messaging (server-side implementation needed)
      // Note: FCM sending is typically done from server, not client
      _logger.i('📡 Firebase notification would be sent from server');

      // 3. OneSignal notification (REST API poziv iz klijenta)
      // Slanje svima u segmentu "All" (ili koristi playerId za pojedinačne korisnike)
      RealtimeNotificationService.sendOneSignalNotification(
        title: title,
        body: body,
        segment: 'All',
        data: data,
      );

      _logger.i(
          '🎯 Multi-channel notification completed: Firebase + OneSignal + Local');
    } catch (e) {
      _logger.e('❌ Error sending notifications: $e');
    }
  }

  /// Test notification functionality with multi-channel support
  static Future<void> sendTestNotification(String message) async {
    _logger.i(
        '🔔 Test notification: $message (multi-channel: Firebase + OneSignal + Local)');

    // Show local notification
    await LocalNotificationService.showRealtimeNotification(
      title: 'Gavra Test - Multi Channel',
      body: message,
      payload: 'test_notification',
      playCustomSound: true,
    );
  }

  /// Check notification permissions for Firebase
  static Future<bool> hasNotificationPermissions() async {
    _logger.i('🔔 Checking Firebase notification permissions...');
    try {
      NotificationSettings settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      bool hasPermission =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      _logger.i('🔔 Firebase notification permission status: $hasPermission');
      return hasPermission;
    } catch (e) {
      _logger.e('❌ Error checking Firebase permissions: $e');
      return false;
    }
  }

  /// Request notification permissions for Firebase
  static Future<bool> requestNotificationPermissions() async {
    _logger.i('🔔 Requesting Firebase notification permissions...');
    try {
      // Check if Firebase is available first
      if (!Firebase.apps.isNotEmpty) {
        _logger.w('⚠️ Firebase not initialized, skipping permission request');
        return false;
      }

      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            announcement: false,
          )
          .timeout(const Duration(seconds: 10));

      bool granted =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      _logger.i('🔔 Firebase permission request result: $granted');
      return granted;
    } catch (e) {
      _logger.e('❌ Error requesting Firebase permissions: $e');
      // Return false but don't crash the app
      return false;
    }
  }

  /// Handle Firebase notification tap - navigate to specific passenger
  static Future<void> _handleFirebaseNotificationTap(
      RemoteMessage message) async {
    try {
      _logger.i('🔔 Handling Firebase notification tap...');

      // Extract notification type and passenger data from Firebase message
      final notificationType = message.data['type'] ?? 'unknown';
      final putnikDataString = message.data['putnik'];

      if (putnikDataString != null) {
        // Parse passenger data from JSON string
        final Map<String, dynamic> putnikData = jsonDecode(putnikDataString);

        // Use NotificationNavigationService to show popup and navigate
        await NotificationNavigationService.navigateToPassenger(
          type: notificationType,
          putnikData: putnikData,
        );
      } else {
        _logger.w('🔔 No passenger data in Firebase notification');
      }
    } catch (e) {
      _logger.e('❌ Error handling Firebase notification tap: $e');
    }
  }
}
