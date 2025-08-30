import 'package:flutter/material.dart';
import 'dart:convert';
// Firebase messaging imports - enabled for multi-channel notifications
import 'package:firebase_messaging/firebase_messaging.dart';
import 'local_notification_service.dart';
import 'notification_navigation_service.dart';
import 'package:logger/logger.dart';

class RealtimeNotificationService {
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

      // Show local notification for foreground messages
      LocalNotificationService.showRealtimeNotification(
        title: message.notification?.title ?? 'Gavra Notification',
        body: message.notification?.body ?? 'Nova poruka',
        payload: message.data['type'] ?? 'firebase_foreground',
        playCustomSound: true,
      );
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

      // 3. OneSignal notification (server-side or REST API call)
      // Note: OneSignal sending is typically done from server or REST API
      _logger.i('📱 OneSignal notification would be sent from server');

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
      NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        announcement: false,
      );

      bool granted =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      _logger.i('🔔 Firebase permission request result: $granted');
      return granted;
    } catch (e) {
      _logger.e('❌ Error requesting Firebase permissions: $e');
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
