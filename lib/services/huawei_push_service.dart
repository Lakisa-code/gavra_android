import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:huawei_push/huawei_push.dart';

import 'auth_manager.dart';
import 'local_notification_service.dart';
import 'push_token_service.dart';

/// Lightweight wrapper around the `huawei_push` plugin.
///
/// Responsibilities:
/// - initialize HMS runtime hooks
/// - obtain device token (HMS) and register it with the backend (via Supabase function)
/// - listen for incoming push messages and display local notifications
class HuaweiPushService {
  static final HuaweiPushService _instance = HuaweiPushService._internal();
  factory HuaweiPushService() => _instance;
  HuaweiPushService._internal();

  StreamSubscription<String?>? _tokenSub;
  StreamSubscription<RemoteMessage>? _messageSub;
  bool _messageListenerRegistered = false;

  /// Initialize and request token. This method is safe to call even when
  /// HMS is not available on the device — it will simply return null.
  Future<String?> initialize() async {
    // 🍎 iOS ne podržava Huawei Push - preskoči
    if (Platform.isIOS) {
      return null;
    }
    
    try {
      // Subscribe for token stream — the plugin emits tokens when available or after
      // a successful registration with Huawei HMS. The plugin APIs vary across
      // versions, so the stream-based approach is resilient.
      _tokenSub?.cancel();
      _tokenSub = Push.getTokenStream.listen((String? newToken) async {
        if (newToken != null) await _registerTokenWithServer(newToken);
      });

      // 🔔 SUBSCRIBE TO MESSAGE STREAM - slušaj dolazne push notifikacije
      _setupMessageListener();

      // The plugin can return a token synchronously via `Push.getToken()` or
      // asynchronously via the `getTokenStream` — call both paths explicitly so
      // that we can log any token and register it immediately.
      // First, try to get token directly (synchronous return from SDK)
      try {
        // Read the App ID and AGConnect values from `agconnect-services.json`
        try {
          await Push.getAppId();
        } catch (e) {
          // 🔇 Ignore - HMS not available
        }

        try {
          await Push.getAgConnectValues();
        } catch (e) {
          // 🔇 Ignore - HMS not available
        }

        // Request the token explicitly: the Push.getToken requires a scope
        // parameter and does not return the token; the token is emitted on
        // Push.getTokenStream. Requesting the token explicitly increases the
        // chance of getting a token quickly.
        try {
          Push.getToken('HCM');
        } catch (e) {
          // 🔇 Ignore - HMS not available
        }
      } catch (e) {
        // 🔇 Ignore - HMS not available
      }

      // The plugin emits tokens asynchronously on the stream. Wait a short while for the first
      // non-null stream value so that initialization can report a token when
      // one is available immediately after startup.
      try {
        // Wait longer for the token to appear on the stream, as the SDK may
        // emit the token with a delay while contacting Huawei servers.
        final firstValue = await Push.getTokenStream.first.timeout(const Duration(seconds: 15));
        if (firstValue.isNotEmpty) {
          await _registerTokenWithServer(firstValue);
          return firstValue;
        }
      } catch (_) {
        // No token arriving quickly — that's OK, the long-lived stream will
        // still handle tokens once they become available.
      }

      return null;
    } catch (e) {
      // Non-fatal: plugin may throw if not configured on device.
      return null;
    }
  }

  /// 🔔 SETUP MESSAGE LISTENER - sluša dolazne Huawei push poruke
  void _setupMessageListener() {
    if (_messageListenerRegistered) return;
    _messageListenerRegistered = true;

    try {
      // Listen for data messages (foreground + background when app is running)
      _messageSub?.cancel();
      _messageSub = Push.onMessageReceivedStream.listen((RemoteMessage message) async {
        try {
          if (kDebugMode) {
            debugPrint('📱 [HuaweiPush] Primljena poruka: ${message.data}');
          }

          // Izvuci title i body iz poruke
          final data = message.dataOfMap ?? {};
          final title = (data['title'] ?? 'Gavra Notification').toString();
          final body = (data['body'] ?? data['message'] ?? 'Nova notifikacija').toString();

          // Prikaži lokalnu notifikaciju
          await LocalNotificationService.showRealtimeNotification(
            title: title,
            body: body,
            payload: data.toString(),
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ [HuaweiPush] Greška pri obradi poruke: $e');
          }
        }
      });

      if (kDebugMode) {
        debugPrint('✅ [HuaweiPush] Message listener registrovan');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [HuaweiPush] Greška pri registraciji listenera: $e');
      }
    }
  }

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    _tokenSub = null;
    await _messageSub?.cancel();
    _messageSub = null;
  }

  /// Registruje HMS token u push_tokens tabelu
  /// Koristi unificirani PushTokenService
  Future<void> _registerTokenWithServer(String token) async {
    String? driverName;
    try {
      driverName = await AuthManager.getCurrentDriver();
    } catch (_) {
      driverName = null;
    }

    await PushTokenService.registerToken(
      token: token,
      provider: 'huawei',
      userType: 'vozac',
      userId: driverName,
    );
  }

  /// Attempt to register a pending token saved while Supabase wasn't initialized.
  /// Delegira na PushTokenService
  Future<void> tryRegisterPendingToken() async {
    await PushTokenService.tryRegisterPendingToken();
  }
}
