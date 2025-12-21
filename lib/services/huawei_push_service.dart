import 'dart:async';

import 'package:huawei_push/huawei_push.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_manager.dart';

/// Lightweight wrapper around the `huawei_push` plugin.
///
/// Responsibilities:
/// - initialize HMS runtime hooks
/// - obtain device token (HMS) and register it with the backend (via Supabase function)
class HuaweiPushService {
  static final HuaweiPushService _instance = HuaweiPushService._internal();
  factory HuaweiPushService() => _instance;
  HuaweiPushService._internal();

  StreamSubscription<String?>? _tokenSub;

  /// Initialize and request token. This method is safe to call even when
  /// HMS is not available on the device — it will simply return null.
  Future<String?> initialize() async {
    try {
      // Subscribe for token stream — the plugin emits tokens when available or after
      // a successful registration with Huawei HMS. The plugin APIs vary across
      // versions, so the stream-based approach is resilient.
      _tokenSub?.cancel();
      _tokenSub = Push.getTokenStream.listen((String? newToken) async {
        if (newToken != null) await _registerTokenWithServer(newToken);
      });

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

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    _tokenSub = null;
  }

  /// Calls a Supabase Edge Function (register-push-token) to store token.
  /// The server-side function should validate and persist tokens securely.
  ///
  /// NAPOMENA: Ako Edge Function ne postoji (404), token se čuva lokalno
  /// i može se registrovati kasnije kada funkcija bude dostupna.
  Future<void> _registerTokenWithServer(String token) async {
    try {
      final supabase = Supabase.instance.client;

      // Send token to server for safe storage; provider identifies 'huawei'
      // Try to attach current driver/user id if set in app session so server
      // can map tokens to users. This helps routing pushes to specific drivers.
      String? driverName;
      try {
        driverName = await AuthManager.getCurrentDriver();
      } catch (_) {
        driverName = null;
      }

      final payload = {
        'provider': 'huawei',
        'token': token,
        'user_id': driverName, // nullable
      };

      try {
        await supabase.functions.invoke('register-push-token', body: payload);
      } on FunctionException catch (e) {
        // Edge Function ne postoji ili vraća grešku
        if (e.status == 404) {
          // 404 = Edge Function ne postoji - ovo je očekivano ako nije deploy-ovana
        }
        // Sačuvaj token lokalno za kasnije
        await _savePendingToken(token);
      }
    } catch (e) {
      // Sačuvaj token lokalno za kasnije
      await _savePendingToken(token);
    }
  }

  /// Sačuvaj token lokalno za kasniju registraciju
  Future<void> _savePendingToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_huawei_token', token);
    } catch (e) {
      // 🔇 Ignore
    }
  }

  /// Attempt to register a pending token saved while Supabase wasn't initialized.
  Future<void> tryRegisterPendingToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('pending_huawei_token');
      if (token == null) return;
      // Remove the pending key early to avoid re-trying repeatedly if
      // something consistently fails on server side.
      await prefs.remove('pending_huawei_token');
      await _registerTokenWithServer(token);
    } catch (e) {
      // 🔇 Ignore
    }
  }
}
