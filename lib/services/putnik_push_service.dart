import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import 'firebase_service.dart';
import 'huawei_push_service.dart';
import 'push_token_service.dart';

/// 📱 Servis za registraciju push tokena putnika
/// Koristi unificirani PushTokenService za registraciju
class PutnikPushService {
  static SupabaseClient get _supabase => supabase;

  /// Registruje push token za putnika u push_tokens tabelu
  /// Koristi unificirani PushTokenService
  static Future<bool> registerPutnikToken(dynamic putnikId) async {
    try {
      if (kDebugMode) {
        debugPrint('📱 [PutnikPush] Registrujem token za putnika: $putnikId');
      }

      String? token;
      String? provider;

      // Prvo pokušaj FCM (GMS uređaji)
      token = await FirebaseService.getFCMToken();
      if (token != null && token.isNotEmpty) {
        provider = 'fcm';
        if (kDebugMode) {
          debugPrint('✅ [PutnikPush] FCM token dobijen: ${token.substring(0, 20)}...');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [PutnikPush] FCM token nije dostupan, pokušavam HMS...');
        }
        // Fallback na HMS (Huawei uređaji)
        token = await HuaweiPushService().initialize();
        if (token != null && token.isNotEmpty) {
          provider = 'huawei';
          if (kDebugMode) {
            debugPrint('✅ [PutnikPush] HMS token dobijen: ${token.substring(0, 20)}...');
          }
        }
      }

      if (token == null || provider == null) {
        if (kDebugMode) {
          debugPrint('❌ [PutnikPush] Nijedan push provider nije dostupan!');
        }
        return false;
      }

      // Dohvati ime putnika za user_id
      final putnikData =
          await _supabase.from('registrovani_putnici').select('putnik_ime').eq('id', putnikId).maybeSingle();

      final putnikIme = putnikData?['putnik_ime'] as String?;
      if (kDebugMode) debugPrint('📝 [PutnikPush] Ime putnika: $putnikIme');

      // Koristi unificirani PushTokenService
      final success = await PushTokenService.registerToken(
        token: token,
        provider: provider,
        userType: 'putnik',
        userId: putnikIme,
        putnikId: putnikId?.toString(),
      );

      if (kDebugMode) {
        debugPrint('${success ? "✅" : "❌"} [PutnikPush] Registracija ${success ? "uspešna" : "neuspešna"}');
      }
      return success;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [PutnikPush] Greška pri registraciji: $e');
      return false;
    }
  }
}
