import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../globals.dart';
import 'notification_navigation_service.dart';
import 'vozac_service.dart';

class RealtimeNotificationService {
  // ⚡ STREAM ZA IN-APP NOTIFIKACIJE
  static final StreamController<Map<String, dynamic>> _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get notificationStream => _notificationStreamController.stream;

  /// 📲 Poziva se kada stigne notifikacija dok je aplikacija u foreground-u
  static void onForegroundNotification(Map<String, dynamic> data) {
    _notificationStreamController.add(data);
  }

  /// 📱 Pošalji push notifikaciju na specifične tokene
  static Future<bool> sendPushNotification({
    required String title,
    required String body,
    String? playerId,
    List<String>? externalUserIds,
    List<String>? driverIds,
    List<Map<String, dynamic>>? tokens,
    String? topic,
    Map<String, dynamic>? data,
    bool broadcast = false,
    String? excludeSender,
  }) async {
    try {
      final payload = {
        if (tokens != null && tokens.isNotEmpty) 'tokens': tokens,
        if (topic != null) 'topic': topic,
        if (broadcast) 'broadcast': true,
        if (excludeSender != null) 'exclude_sender': excludeSender,
        'title': title,
        'body': body,
        'data': data ?? {},
      };

      final response = await supabase.functions.invoke(
        'send-push-notification',
        body: payload,
      );

      if (response.data != null && response.data['success'] == true) {
        return true;
      } else {
        // 🔕 UKLONJENO: Fallback na lokalnu notifikaciju (korisnik želi isključivo Supabase/Push)
        // await LocalNotificationService.showRealtimeNotification(
        //    title: title, body: body, payload: jsonEncode(data ?? {}));
        return false;
      }
    } catch (e) {
      debugPrint('🔴 [RealtimeNotification.sendPushNotification] Error: $e');
      return false;
    }
  }

  /// 🔐 Pošalji notifikaciju samo adminima (Bojan)
  static Future<void> sendNotificationToAdmins({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 🔧 FIX: Dinamičko učitavanje admin vozača
      const adminNames = ['Bojan'];
      final vozacService = VozacService();
      final allVozaci = await vozacService.getAllVozaci();
      final adminVozaci = allVozaci.where((v) => adminNames.contains(v.ime)).map((v) => v.ime).toList();

      final response = await supabase.from('push_tokens').select('token, provider').inFilter('user_id', adminVozaci);

      if ((response as List).isEmpty) return;

      final tokens = (response)
          .map<Map<String, dynamic>>((t) => {
                'token': t['token'] as String,
                'provider': t['provider'] as String,
              })
          .toList();

      await sendPushNotification(
        title: title,
        body: body,
        tokens: tokens,
        data: data,
      );
    } catch (e) {
      debugPrint('🔴 [RealtimeNotification.sendNotificationToAdmins] Error: $e');
    }
  }

  /// 📲 Pošalji push notifikaciju putniku
  static Future<bool> sendNotificationToPutnik({
    required String putnikId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await supabase.from('push_tokens').select('token, provider').eq('putnik_id', putnikId);

      if ((response as List).isEmpty) {
        debugPrint('⚠️ [RealtimeNotification] Nema tokena za putnika $putnikId');
        return false;
      }

      final tokens = (response)
          .map<Map<String, dynamic>>((t) => {
                'token': t['token'] as String,
                'provider': t['provider'] as String,
              })
          .toList();

      return await sendPushNotification(
        title: title,
        body: body,
        tokens: tokens,
        data: data,
      );
    } catch (e) {
      debugPrint('🔴 [RealtimeNotification.sendNotificationToPutnik] Error: $e');
      return false;
    }
  }

  /// 🎯 Pošalji notifikaciju svim vozačima
  static Future<void> sendNotificationToAllDrivers({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? excludeSender,
  }) async {
    try {
      // 🔧 FIX: Dinamičko učitavanje vozača umesto hardkodirane liste
      final vozacService = VozacService();
      final allVozaci = await vozacService.getAllVozaci();
      final vozaci = allVozaci.map((v) => v.ime).toList();

      final response =
          await supabase.from('push_tokens').select('token, provider, user_id').inFilter('user_id', vozaci);

      if ((response as List).isEmpty) return;

      final filteredTokens = response.where((t) {
        if (excludeSender == null) return true;
        final userId = t['user_id'] as String?;
        return userId?.toLowerCase() != excludeSender.toLowerCase();
      }).toList();

      if (filteredTokens.isEmpty) return;

      final tokens = filteredTokens
          .map<Map<String, dynamic>>((t) => {
                'token': t['token'] as String,
                'provider': t['provider'] as String,
              })
          .toList();

      await sendPushNotification(
        title: title,
        body: body,
        tokens: tokens,
        data: data,
      );
    } catch (e) {
      debugPrint('🔴 [RealtimeNotification.sendNotificationToAllDrivers] Error: $e');
    }
  }

  static Future<void> handleInitialMessage(Map<String, dynamic>? messageData) async {
    if (messageData == null) return;
    try {
      // Emituj dogadjaj i za tap ako smo u foreground-u/background-u
      onForegroundNotification(messageData);
      
      await _handleNotificationTap(messageData);
    } catch (e) {
      debugPrint('🔴 [RealtimeNotification.handleInitialMessage] Error: $e');
    }
  }

  static Future<void> initialize() async {
    // Inicijalizacija se vrši u FirebaseService
  }

  static bool _foregroundListenerRegistered = false;

  /// ⚠️ DEPRECATED: Notifikacije se sada inicijalizuju globalno u FirebaseService/HuaweiPushService.
  /// Ova metoda ne radi ništa kako bi se sprečili dupli listeneri.
  static void listenForForegroundNotifications(BuildContext context) {
    if (_foregroundListenerRegistered) return;
    _foregroundListenerRegistered = true;
    debugPrint('ℹ️ [RealtimeNotification] Globalni listener je već postavljen u main.dart, preskačem lokalni.');
  }

  static Future<void> subscribeToDriverTopics(String? driverId) async {
    if (driverId == null || driverId.isEmpty) return;
    try {
      if (Firebase.apps.isEmpty) return;
      final messaging = FirebaseMessaging.instance;
      await messaging.subscribeToTopic('gavra_driver_${driverId.toLowerCase()}');
      await messaging.subscribeToTopic('gavra_all_drivers');
    } catch (e) {
      debugPrint('🔴 [RealtimeNotification.subscribeToDriverTopics] Error: $e');
    }
  }

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
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('🔴 [RealtimeNotification.requestNotificationPermissions] Error: $e');
      return false;
    }
  }

  static Future<void> _handleNotificationTap(Map<String, dynamic> messageData) async {
    try {
      final notificationType = messageData['type'] ?? 'unknown';

      if (notificationType == 'transport_started' ||
          notificationType == 'seat_request_approved' ||
          notificationType == 'seat_request_rejected' ||
          notificationType == 'seat_request_alternatives') {
        await NotificationNavigationService.navigateToPassengerProfile();
        return;
      }

      if (notificationType == 'pin_zahtev' || notificationType == 'seat_request_manual') {
        await NotificationNavigationService.navigateToPinZahtevi();
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
      debugPrint('🔴 [RealtimeNotification._handleNotificationTap] Error: $e');
    }
  }
}
