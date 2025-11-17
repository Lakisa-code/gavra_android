import 'package:firebase_messaging/firebase_messaging.dart';

import 'local_notification_service.dart';

// Top-level background handler required by Firebase Messaging plugin
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // We cannot run complex UI logic here; show a basic notification
    final title = message.notification?.title ?? 'Gavra Notification';
    final body = message.notification?.body ??
        message.data['message'] ??
        'Nova notifikacija';

    // Use LocalNotificationService background-safe method
    await LocalNotificationService.showNotificationFromBackground(
      title: title,
      body: body,
      payload: message.data.isNotEmpty ? message.data.toString() : null,
    );
  } catch (e) {
    // Swallow errors in background handler
  }
}
