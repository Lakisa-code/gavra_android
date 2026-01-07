import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_service.dart';
import 'huawei_push_service.dart';
import 'push_token_service.dart';

/// 📱 Servis za registraciju push tokena putnika
/// Koristi unificirani PushTokenService za registraciju
class PutnikPushService {
  static final _supabase = Supabase.instance.client;

  /// Registruje push token za putnika u push_tokens tabelu
  /// Koristi unificirani PushTokenService
  static Future<bool> registerPutnikToken(dynamic putnikId) async {
    try {
      String? token;
      String? provider;

      // Prvo pokušaj FCM (GMS uređaji)
      token = await FirebaseService.getFCMToken();
      if (token != null && token.isNotEmpty) {
        provider = 'fcm';
      } else {
        // Fallback na HMS (Huawei uređaji)
        token = await HuaweiPushService().initialize();
        if (token != null && token.isNotEmpty) {
          provider = 'huawei';
        }
      }

      if (token == null || provider == null) {
        return false;
      }

      // Dohvati ime putnika za user_id
      final putnikData =
          await _supabase.from('registrovani_putnici').select('putnik_ime').eq('id', putnikId).maybeSingle();

      final putnikIme = putnikData?['putnik_ime'] as String?;

      // Koristi unificirani PushTokenService
      return await PushTokenService.registerToken(
        token: token,
        provider: provider,
        userType: 'putnik',
        userId: putnikIme,
        putnikId: putnikId?.toString(),
      );
    } catch (e) {
      return false;
    }
  }

  /// Briše push token za putnika iz push_tokens tabele
  /// Koristi unificirani PushTokenService
  static Future<void> clearPutnikToken(dynamic putnikId) async {
    await PushTokenService.clearToken(putnikId: putnikId?.toString());
  }

  /// Dohvata tokene za listu putnika iz push_tokens tabele
  /// Delegira na PushTokenService.getTokensForUsers
  static Future<Map<String, Map<String, String>>> getTokensForPutnici(
    List<String> putnikImena,
  ) async {
    if (putnikImena.isEmpty) return {};

    try {
      final tokens = await PushTokenService.getTokensForUsers(putnikImena);

      final result = <String, Map<String, String>>{};
      for (final t in tokens) {
        final ime = t['user_id'];
        if (ime != null && ime.isNotEmpty) {
          result[ime] = {'token': t['token']!, 'provider': t['provider']!};
        }
      }

      return result;
    } catch (e) {
      return {};
    }
  }
}
