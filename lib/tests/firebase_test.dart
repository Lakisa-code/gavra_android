import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase_options.dart';

class FirebaseTest {
  /// Test Firebase konekcije
  static Future<Map<String, dynamic>> testFirebase() async {
    Map<String, dynamic> results = {
      'firebase_initialized': false,
      'messaging_available': false,
      'fcm_token': null,
      'project_id': null,
      'app_id': null,
      'error': null,
    };

    try {
      // Test Firebase initialization
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      results['firebase_initialized'] = true;

      // Dobij osnovne informacije o projektu
      final app = Firebase.app();
      results['project_id'] = app.options.projectId;
      results['app_id'] = app.options.appId;

      // Test Firebase Messaging
      try {
        final messaging = FirebaseMessaging.instance;
        results['messaging_available'] = true;

        // Pokušaj da dobijes FCM token
        final token = await messaging.getToken();
        results['fcm_token'] = token;
      } catch (e) {
        results['messaging_error'] = e.toString();
      }
    } catch (e) {
      results['error'] = e.toString();
    }

    return results;
  }

  /// Format rezultata za prikaz
  static String formatResults(Map<String, dynamic> results) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('🔥 FIREBASE TEST REZULTATI:');
    buffer.writeln('═══════════════════════════════════');

    if (results['firebase_initialized'] == true) {
      buffer.writeln('✅ Firebase je uspešno inicijalizovan');
      buffer.writeln('📋 Project ID: ${results['project_id']}');
      buffer.writeln('📱 App ID: ${results['app_id']}');
    } else {
      buffer.writeln('❌ Firebase inicijalizacija neuspešna');
    }

    if (results['messaging_available'] == true) {
      buffer.writeln('✅ Firebase Messaging je dostupan');
      if (results['fcm_token'] != null) {
        final token = results['fcm_token'] as String;
        final shortToken = '${token.substring(0, 20)}...${token.substring(token.length - 10)}';
        buffer.writeln('🔑 FCM Token: $shortToken');
      }
    } else {
      buffer.writeln('❌ Firebase Messaging nije dostupan');
      if (results['messaging_error'] != null) {
        buffer.writeln('   Greška: ${results['messaging_error']}');
      }
    }

    if (results['error'] != null) {
      buffer.writeln('❌ Glavna greška: ${results['error']}');
    }

    return buffer.toString();
  }
}
