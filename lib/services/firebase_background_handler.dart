import 'package:firebase_messaging/firebase_messaging.dart';

import 'local_notification_service.dart';

// This file exposes two background handlers:
//  - firebaseMessagingBackgroundHandler(RemoteMessage) which is registered
//    with Firebase Messaging plugin for FCM background delivery.
//  - backgroundNotificationHandler(Map<String,dynamic>) which is provider
//    agnostic and can be used for Huawei or other push providers.

// Top-level background handler required by Firebase Messaging plugin
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    final payload = Map<String, dynamic>.from(message.data);
    await backgroundNotificationHandler(payload);
  } catch (_) {
    // Ignore background handling failures
  }
}

// Generic background notification handler used for non-Firebase pushes.
// Accepts a plain JSON payload map to remain provider-agnostic.
Future<void> backgroundNotificationHandler(Map<String, dynamic> payload) async {
  try {
    final title = payload['title'] as String? ?? 'Gavra Notification';
    final body = payload['body'] as String? ?? (payload['message'] as String?) ?? 'Nova notifikacija';
    final rawData = payload['data'];

    await LocalNotificationService.showNotificationFromBackground(
      title: title,
      body: body,
      payload: rawData != null ? rawData.toString() : null,
    );
  } catch (_) {
    // Swallow errors in background handler — background execution is best-effort.
  }
}
