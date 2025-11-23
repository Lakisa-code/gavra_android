import 'dart:async';

import 'package:flutter/material.dart';
import 'package:huawei_push/huawei_push.dart';
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

      // Some plugin versions provide a synchronous token fetch method. We'll try
      // to call it, but ignore errors — the stream listener will catch updates.
      try {
        // Many versions of the plugin expose a getToken method; if its signature
        // differs this call may throw and that's fine — we rely on the stream.
        final dynamic maybeToken = await (Push as dynamic).getToken('');
        if (maybeToken is String && maybeToken.isNotEmpty) {
          await _registerTokenWithServer(maybeToken);
          return maybeToken;
        }
      } catch (_) {
        // Ignore - stream handler will pick up tokens when available
      }

      return null;
    } catch (e) {
      // Non-fatal: plugin may throw if not configured on device.
      debugPrint('HuaweiPushService.initialize failed: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    _tokenSub = null;
  }

  /// Calls a Supabase Edge Function (register-push-token) to store token.
  /// The server-side function should validate and persist tokens securely.
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

      await supabase.functions.invoke('register-push-token', body: payload);
      debugPrint('Huawei token registered with server (masked). user=${driverName ?? 'null'}');
    } catch (e) {
      debugPrint('Failed to register Huawei token with server: $e');
    }
  }
}
