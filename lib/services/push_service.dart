import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// We use a method channel to optionally call Huawei Push plugin methods if available in the host app.
final MethodChannel _huaweiChannel =
    const MethodChannel('com.huawei.hms.flutter.push/push');
// Huawei push plugin may not be present on all setups; import guarded by conditional
// import 'package:huawei_push/huawei_push.dart' as hms;

class PushService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static String? _fcmToken;
  // ignore: unused_field
  static String? _hmsToken;

  static Future<void> initialize() async {
    // Firebase Messaging init
    try {
      _fcmToken = await _fcm.getToken();
      if (_fcmToken != null) {
        await _registerToken(
            'fcm', _fcmToken!, Platform.isAndroid ? 'android' : 'ios');
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        _fcmToken = token;
        await _registerToken(
            'fcm', token, Platform.isAndroid ? 'android' : 'ios');
      });
    } catch (e) {
      debugPrint('PushService: FCM init error: $e');
    }

    // Huawei Push init (optional)
    try {
      if (Platform.isAndroid) {
        // Try to query Huawei token via method channel (`getToken`) and register it.
        try {
          // First attempt: use the huawei_push plugin directly (if available)
          try {
            // NOTE: Some versions of the Huawei plugin expose push token via callbacks
            // and/or method channel instead of returning it from `getToken` synchronously.
            // To keep compatibility with more versions, use the method channel fallback
            // below that invokes 'getToken' and listens for 'onToken' events.
          } catch (pluginErr) {
            // Fallback: use the method channel if the direct plugin call isn't available
            debugPrint(
                'PushService: HMS plugin direct call failed, falling back to method channel: $pluginErr');
            final String? token =
                await _huaweiChannel.invokeMethod<String>('getToken');
            if (token != null && token.isNotEmpty) {
              _hmsToken = token;
              await _registerToken('huawei', token, 'android');
            }
          }
          // Token handled above in fallback code

          // Listen to token refresh events if the plugin dispatches them via method calls
          _huaweiChannel.setMethodCallHandler((call) async {
            if (call.method == 'onToken') {
              final token = call.arguments as String?;
              if (token != null && token.isNotEmpty) {
                _hmsToken = token;
                await _registerToken('huawei', token, 'android');
              }
            }
          });
        } catch (e) {
          debugPrint(
              'PushService: HMS plugin not present or not initialized: $e');
        }
      }
    } catch (e) {
      debugPrint('PushService: HMS init error: $e');
    }
  }

  static Future<void> _registerToken(
      String provider, String token, String platform) async {
    try {
      final supabase = Supabase.instance.client;
      // Insert or upsert into push_players
      await supabase.from('push_players').upsert({
        'driver_id': supabase
            .auth.currentUser?.id, // driver id normally numeric; if not, adapt
        'player_id': token,
        'provider': provider,
        'platform': platform,
        'is_active': true,
      }, onConflict: 'player_id');
      debugPrint('PushService: upserted token for $provider');
    } catch (e) {
      debugPrint('PushService: registerToken error: $e');
    }
  }

  static Future<void> removeAllTokens() async {
    try {
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;
      // Soft-delete tokens for the user: set removed_at and is_active=false
      await supabase.from('push_players').update({
        'is_active': false,
        'removed_at': DateTime.now().toIso8601String(),
      }).eq('driver_id', uid);
    } catch (e) {
      debugPrint('PushService: removeAllTokens error: $e');
    }
  }

  /// Associate current tokens for the authenticated user with a driver id (e.g., driver name)
  static Future<void> bindDriver(String driverId) async {
    try {
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;

      // Update tokens that have driver_id equal to auth uid OR null
      await supabase.from('push_players').update({'driver_id': driverId}).or(
          'driver_id.eq.${uid},driver_id.is.null');
    } catch (e) {
      debugPrint('PushService: bindDriver error: $e');
    }
  }
}
