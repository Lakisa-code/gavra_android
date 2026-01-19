import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_manager.dart';
import 'local_notification_service.dart';
import 'notification_navigation_service.dart';

class RealtimeNotificationService {
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

      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'send-push-notification',
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

  /// 🔐 Pošalji notifikaciju samo adminima (Bojan, Svetlana)
  static Future<void> sendNotificationToAdmins({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // Dohvati tokene admina
      final response =
          await supabase.from('push_tokens').select('token, provider').inFilter('user_id', ['Bojan', 'Svetlana']);

      if ((response as List).isEmpty) return;

      // Formatiraj tokene za slanje
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
      // Ignoriši greške - notifikacija nije kritična
    }
  }

  /// 📲 Pošalji push notifikaciju putniku (za potvrdu termina)
  /// Šalje push notifikaciju direktno na token putnika - radi čak i kad je app zatvoren
  static Future<bool> sendNotificationToPutnik({
    required String putnikId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // Dohvati token putnika
      final response =
          await supabase.from('push_tokens').select('token, provider').eq('user_id', putnikId).maybeSingle();

      if (response == null) {
        // Putnik nema token - prikaži lokalnu notifikaciju kao fallback
        await LocalNotificationService.showRealtimeNotification(
          title: title,
          body: body,
          payload: jsonEncode(data ?? {}),
        );
        return false;
      }

      // Formatiraj token za slanje
      final tokens = [
        {
          'token': response['token'] as String,
          'provider': response['provider'] as String,
        }
      ];

      return await sendPushNotification(
        title: title,
        body: body,
        tokens: tokens,
        data: data,
      );
    } catch (e) {
      // Ako push ne uspe, prikaži lokalnu notifikaciju kao fallback
      try {
        await LocalNotificationService.showRealtimeNotification(
          title: title,
          body: body,
          payload: jsonEncode(data ?? {}),
        );
      } catch (_) {}
      return false;
    }
  }

  /// 🎯 Pošalji notifikaciju svim vozačima (broadcast)
  /// Push notifikacija se šalje preko Supabase Edge funkcije koja sama prikazuje notifikaciju
  /// Lokalna notifikacija se prikazuje SAMO ako push ne uspe (fallback u sendPushNotification)
  static Future<void> sendNotificationToAllDrivers({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? excludeSender,
  }) async {
    try {
      // Lista vozača - SAMO ONI dobijaju broadcast notifikacije
      const vozaci = ['Bojan', 'Svetlana', 'Bilevski', 'Bruda', 'Ivan'];

      final supabase = Supabase.instance.client;

      // Dohvati tokene SAMO za vozače
      var query = supabase.from('push_tokens').select('token, provider, user_id').inFilter('user_id', vozaci);

      final response = await query;

      if ((response as List).isEmpty) return;

      // Filtriraj exclude_sender
      final filteredTokens = response.where((t) {
        if (excludeSender == null) return true;
        final userId = t['user_id'] as String?;
        return userId?.toLowerCase() != excludeSender.toLowerCase();
      }).toList();

      if (filteredTokens.isEmpty) return;

      // Formatiraj tokene za slanje
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
      // Ako broadcast ne uspe, prikaži lokalnu notifikaciju kao fallback
      try {
        final currentDriver = await AuthManager.getCurrentDriver();
        final shouldShowLocal = excludeSender == null ||
            currentDriver == null ||
            currentDriver.toLowerCase() != excludeSender.toLowerCase();

        if (shouldShowLocal) {
          await LocalNotificationService.showRealtimeNotification(
            title: title,
            body: body,
            payload: jsonEncode(data ?? {}),
          );
        }
      } catch (_) {}
    }
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

        // Izvuci title i body - prvo notification payload, pa data payload
        final title = message.notification?.title ?? data['title'] as String? ?? 'Gavra Notification';
        final body =
            message.notification?.body ?? data['body'] as String? ?? data['message'] as String? ?? 'Nova poruka';

        // Prikaži notifikaciju za SVE poruke (bez filtriranja po tipu/datumu)
        LocalNotificationService.showRealtimeNotification(
          title: title,
          body: body,
          payload: data.isNotEmpty ? data.toString() : 'firebase_foreground',
        );
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

      // 🔐 Za "pin_zahtev" - otvori PIN zahtevi ekran (admin)
      if (notificationType == 'pin_zahtev') {
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
      // Ignoriši greške pri navigaciji
    }
  }
}
