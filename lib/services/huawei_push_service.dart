import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:huawei_push/huawei_push.dart';

import 'auth_manager.dart';
import 'local_notification_service.dart';
import 'push_token_service.dart';
import 'realtime_notification_service.dart'; // <--- Dodato ovde

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
  String? _currentToken;

  // 🛡️ ZAŠTITA OD VIŠESTRUKOG POZIVANJA
  bool _initialized = false;
  bool _initializing = false;

  /// Dohvati trenutni HMS token ako postoji
  Future<String?> getHMSToken() async {
    if (_currentToken != null && _currentToken!.isNotEmpty) {
      return _currentToken;
    }
    // Ako nemamo token, pokušaj ponovo inicijalizaciju (koja vraća token ako ga dobije brzo)
    return await initialize();
  }

  /// Initialize and request token. This method is safe to call even when
  /// HMS is not available on the device — it will simply return null.
  Future<String?> initialize() async {
    // 🍎 iOS ne podržava Huawei Push - preskoči
    if (Platform.isIOS) {
      debugPrint('📱 [HuaweiPush] iOS detected, skipping Huawei Push');
      return null;
    }

    // 🛡️ Provera da li je HMS dostupan (zaštita od HMSSDK logova na non-Huawei uređajima)
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final manufacturer = androidInfo.manufacturer.toLowerCase();
        final brand = androidInfo.brand.toLowerCase();

        // Ako nije Huawei/Honor, preskačemo HMS inicijalizaciju
        if (!manufacturer.contains('huawei') &&
            !brand.contains('huawei') &&
            !manufacturer.contains('honor') &&
            !brand.contains('honor')) {
          _initialized = true;
          return null;
        }
      }
    } catch (e) {
      debugPrint('📱 [HuaweiPush] Error checking manufacturer: $e');
    }

    // 🛡️ Ako je već inicijalizovan, vrati null
    if (_initialized) {
      debugPrint('📱 [HuaweiPush] Already initialized');
      return null;
    }

    // 🛡️ Ako je inicijalizacija u toku, sačekaj
    if (_initializing) {
      debugPrint('📱 [HuaweiPush] Initialization already in progress...');
      // Čekaj do 5 sekundi da se završi tekuća inicijalizacija
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_initialized) return null;
      }
      return null;
    }

    debugPrint('📱 [HuaweiPush] Starting Huawei Push initialization...');
    _initializing = true;

    try {
      // Subscribe for token stream — the plugin emits tokens when available or after
      // a successful registration with Huawei HMS. The plugin APIs vary across
      // versions, so the stream-based approach is resilient.
      _tokenSub?.cancel();
      _tokenSub = Push.getTokenStream.listen((String? newToken) async {
        if (newToken != null && newToken.isNotEmpty) {
          _currentToken = newToken;
          await _registerTokenWithServer(newToken);
        }
      });

      // 🔔 SUBSCRIBE TO MESSAGE STREAM - slušaj dolazne push notifikacije
      _setupMessageListener();

      // The plugin can return a token synchronously via `Push.getToken()` or
      // asynchronously via the `getTokenStream` — call both paths explicitly so
      // that we can log any token and register it immediately.
      // First, try to get token directly (synchronous return from SDK)
      try {
        debugPrint('📱 [HuaweiPush] Reading App ID and AGConnect values...');
        // Read the App ID and AGConnect values from `agconnect-services.json`
        try {
          final appId = await Push.getAppId();
          debugPrint('📱 [HuaweiPush] App ID: $appId');
        } catch (e) {
          debugPrint('📱 [HuaweiPush] Failed to get App ID: $e');
        }

        try {
          await Push.getAgConnectValues();
          debugPrint('📱 [HuaweiPush] AGConnect values loaded successfully');
        } catch (e) {
          debugPrint('📱 [HuaweiPush] Failed to get AGConnect values: $e');
        }

        // Request the token explicitly: the Push.getToken requires a scope
        // parameter and does not return the token; the token is emitted on
        // Push.getTokenStream. Requesting the token explicitly increases the
        // chance of getting a token quickly.
        // 🛡️ POZIVA SE SAMO JEDNOM PRI PRVOJ INICIJALIZACIJI
        try {
          debugPrint('📱 [HuaweiPush] Requesting token with HCM scope...');
          Push.getToken('HCM');
        } catch (e) {
          debugPrint('📱 [HuaweiPush] Failed to request token: $e');
          // If we get error 907135000, HMS is not available
          if (e.toString().contains('907135000')) {
            debugPrint(
                '📱 [HuaweiPush] HMS Core not available (error 907135000), skipping Huawei Push');
            _initialized = true;
            _initializing = false;
            return null;
          }
        }
      } catch (e) {
        debugPrint('📱 [HuaweiPush] General error during token setup: $e');
      }

      // The plugin emits tokens asynchronously on the stream. Wait a short while for the first
      // non-null stream value so that initialization can report a token when
      // one is available immediately after startup.
      try {
        debugPrint(
            '📱 [HuaweiPush] Waiting for token on stream (5s timeout)...');
        // Wait longer for the token to appear on the stream, as the SDK may
        // emit the token with a delay while contacting Huawei servers.
        // 🛡️ SMANJEN TIMEOUT sa 15 na 5 sekundi
        final firstValue =
            await Push.getTokenStream.first.timeout(const Duration(seconds: 5));
        if (firstValue.isNotEmpty) {
          debugPrint(
              '📱 [HuaweiPush] Token received on stream: ${firstValue.substring(0, 10)}...');
          _currentToken = firstValue;
          await _registerTokenWithServer(firstValue);
          _initialized = true;
          _initializing = false;
          return firstValue;
        } else {
          debugPrint('📱 [HuaweiPush] Empty token received on stream');
        }
      } catch (e) {
        debugPrint('📱 [HuaweiPush] No token received on stream within 5s: $e');
        // If HMS is not available, don't keep trying
        if (e.toString().contains('907135000') ||
            e.toString().contains('HMS')) {
          debugPrint(
              '📱 [HuaweiPush] HMS not available, marking as initialized (null token)');
          _initialized = true;
          _initializing = false;
          return null;
        }
        // No token arriving quickly — that's OK, the long-lived stream will
        // still handle tokens once they become available.
      }

      _initialized = true;
      _initializing = false;
      return null;
    } catch (e) {
      // Non-fatal: plugin may throw if not configured on device.
      _initializing = false;
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
      _messageSub =
          Push.onMessageReceivedStream.listen((RemoteMessage message) async {
        try {
          // Emituj dogadjaj unutar aplikacije
          Map<String, dynamic> data = {};
          if (message.data != null) {
            try {
              data = jsonDecode(message.data!);
            } catch (_) {
              // Ako nije JSON, možda je direktno mapa u nekoj verziji plugina
              // ali huawei_push obično šalje string
            }
          }

          RealtimeNotificationService.onForegroundNotification(data);

          // Get notification details
          final title = message.notification?.title ??
              data['title'] ??
              'Gavra Notification';
          final body = message.notification?.body ??
              data['body'] ??
              data['message'] ??
              'Nova notifikacija';

          // Prikaži lokalnu notifikaciju
          await LocalNotificationService.showRealtimeNotification(
            title: title,
            body: body,
            payload: jsonEncode(data),
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

  /// Registruje HMS token u push_tokens tabelu
  /// Koristi unificirani PushTokenService
  Future<void> _registerTokenWithServer(String token) async {
    String? driverName;
    try {
      driverName = await AuthManager.getCurrentDriver();
    } catch (_) {
      driverName = null;
    }

    // Registruj samo ako je vozač ulogovan
    if (driverName == null || driverName.isEmpty) {
      debugPrint(
          '⚠️ [HuaweiPushService] Vozač nije ulogovan - preskačem HMS registraciju');
      return;
    }

    await PushTokenService.registerToken(
      token: token,
      provider: 'huawei',
      userType: 'vozac',
      userId: driverName,
    );
  }

  /// Pokušaj registracije pending tokena (ako postoji)
  Future<void> tryRegisterPendingToken() async {
    // Delegiraj na PushTokenService
    await PushTokenService.tryRegisterPendingToken();
  }
}
