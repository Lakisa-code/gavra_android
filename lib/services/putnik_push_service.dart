import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_service.dart';
import 'huawei_push_service.dart';

/// 📱 Servis za registraciju push tokena mesečnih putnika
/// Omogućava slanje notifikacija putnicima kada vozač krene
class PutnikPushService {
  static final _supabase = Supabase.instance.client;

  /// Registruj push token za putnika pri loginu
  /// Vraća true ako je uspešno registrovan
  static Future<bool> registerPutnikToken(dynamic putnikId) async {
    try {
      String? token;
      String? provider;

      // Probaj FCM prvo (Google)
      token = await FirebaseService.getFCMToken();
      if (token != null && token.isNotEmpty) {
        provider = 'fcm';
      } else {
        // Probaj Huawei HMS
        token = await HuaweiPushService().initialize();
        if (token != null && token.isNotEmpty) {
          provider = 'huawei';
        }
      }

      if (token == null || provider == null) {
        debugPrint('⚠️ PutnikPushService: Nema dostupnog push tokena');
        return false;
      }

      // Sačuvaj u bazu
      await _supabase.from('registrovani_putnici').update({
        'push_token': token,
        'push_provider': provider,
      }).eq('id', putnikId);

      debugPrint('✅ PutnikPushService: Token registrovan za putnika $putnikId ($provider)');
      return true;
    } catch (e) {
      debugPrint('❌ PutnikPushService greška: $e');
      return false;
    }
  }

  /// Obriši push token (pri logout-u)
  static Future<void> clearPutnikToken(dynamic putnikId) async {
    try {
      await _supabase.from('registrovani_putnici').update({
        'push_token': null,
        'push_provider': null,
      }).eq('id', putnikId);

      debugPrint('🗑️ PutnikPushService: Token obrisan za putnika $putnikId');
    } catch (e) {
      debugPrint('❌ PutnikPushService clearToken greška: $e');
    }
  }

  /// Dohvati tokene za listu putnika (po imenu)
  /// Vraća mapu: ime -> {token, provider}
  static Future<Map<String, Map<String, String>>> getTokensForPutnici(
    List<String> putnikImena,
  ) async {
    if (putnikImena.isEmpty) return {};

    try {
      final response = await _supabase
          .from('registrovani_putnici')
          .select('putnik_ime, push_token, push_provider')
          .inFilter('putnik_ime', putnikImena)
          .not('push_token', 'is', null);

      final result = <String, Map<String, String>>{};
      for (final row in response as List) {
        final ime = row['putnik_ime'] as String?;
        final token = row['push_token'] as String?;
        final provider = row['push_provider'] as String?;

        if (ime != null && token != null && provider != null) {
          result[ime] = {'token': token, 'provider': provider};
        }
      }

      debugPrint('📋 PutnikPushService: Pronađeno ${result.length} tokena za ${putnikImena.length} putnika');
      return result;
    } catch (e) {
      debugPrint('❌ PutnikPushService getTokens greška: $e');
      return {};
    }
  }
}
