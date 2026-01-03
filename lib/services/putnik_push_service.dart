import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_service.dart';
import 'huawei_push_service.dart';

/// 📱 Servis za registraciju push tokena putnika
/// Svi tokeni (vozači + putnici) idu u push_tokens tabelu
class PutnikPushService {
  static final _supabase = Supabase.instance.client;

  /// Registruje push token za putnika u push_tokens tabelu
  static Future<bool> registerPutnikToken(dynamic putnikId) async {
    try {
      String? token;
      String? provider;

      token = await FirebaseService.getFCMToken();
      if (token != null && token.isNotEmpty) {
        provider = 'fcm';
      } else {
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

      // UPSERT u push_tokens tabelu
      await _supabase.from('push_tokens').upsert({
        'token': token,
        'provider': provider,
        'user_type': 'putnik',
        'putnik_id': putnikId,
        'user_id': putnikIme,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Briše push token za putnika iz push_tokens tabele
  static Future<void> clearPutnikToken(dynamic putnikId) async {
    try {
      await _supabase.from('push_tokens').delete().eq('putnik_id', putnikId);
    } catch (e) {
      // ❌ Greška pri brisanju tokena
    }
  }

  /// Dohvata tokene za listu putnika iz push_tokens tabele
  static Future<Map<String, Map<String, String>>> getTokensForPutnici(
    List<String> putnikImena,
  ) async {
    if (putnikImena.isEmpty) return {};

    try {
      final response = await _supabase
          .from('push_tokens')
          .select('user_id, token, provider')
          .eq('user_type', 'putnik')
          .inFilter('user_id', putnikImena);

      final result = <String, Map<String, String>>{};
      for (final row in response as List) {
        final ime = row['user_id'] as String?;
        final token = row['token'] as String?;
        final provider = row['provider'] as String?;

        if (ime != null && token != null && provider != null) {
          result[ime] = {'token': token, 'provider': provider};
        }
      }

      return result;
    } catch (e) {
      return {};
    }
  }
}
