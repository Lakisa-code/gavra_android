import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 📱 Unificirani servis za registraciju push tokena
/// Zamenjuje dupliciranu logiku iz FirebaseService, HuaweiPushService i PutnikPushService
///
/// Svi tokeni (FCM i HMS, vozači i putnici) se registruju na isti način:
/// - Direktan UPSERT u push_tokens tabelu
/// - Pending token mehanizam za offline scenarije
class PushTokenService {
  static final _supabase = Supabase.instance.client;

  /// Ključ za čuvanje pending tokena u SharedPreferences
  static const _pendingTokenKey = 'pending_push_token';

  /// 📲 Registruje push token direktno u Supabase bazu
  ///
  /// [token] - FCM ili HMS token
  /// [provider] - 'fcm' za Firebase ili 'huawei' za HMS
  /// [userType] - 'vozac' ili 'putnik'
  /// [userId] - ime vozača ili putnika (opciono)
  /// [putnikId] - ID putnika iz registrovani_putnici tabele (samo za putnike)
  static Future<bool> registerToken({
    required String token,
    required String provider,
    String userType = 'vozac',
    String? userId,
    String? putnikId,
  }) async {
    try {
      if (token.isEmpty) {
        if (kDebugMode) debugPrint('⚠️ [PushToken] Prazan token, preskačem registraciju');
        return false;
      }

      await _supabase.from('push_tokens').upsert(
        {
          'token': token,
          'provider': provider,
          'user_type': userType,
          'user_id': userId,
          'putnik_id': putnikId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'token',
      );

      if (kDebugMode) {
        debugPrint('✅ [PushToken] Token registrovan: $provider/$userType/${token.substring(0, 20)}...');
      }

      // Obriši pending token ako postoji (uspešno registrovan)
      await _clearPendingToken();

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [PushToken] Greška pri registraciji: $e');

      // Sačuvaj kao pending za kasnije
      await savePendingToken(
        token: token,
        provider: provider,
        userType: userType,
        userId: userId,
        putnikId: putnikId,
      );

      return false;
    }
  }

  /// 💾 Sačuvaj token lokalno za kasniju registraciju
  /// Koristi se kada Supabase nije dostupan (offline, greška)
  static Future<void> savePendingToken({
    required String token,
    required String provider,
    String userType = 'vozac',
    String? userId,
    String? putnikId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = jsonEncode({
        'token': token,
        'provider': provider,
        'user_type': userType,
        'user_id': userId,
        'putnik_id': putnikId,
        'saved_at': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_pendingTokenKey, pendingData);

      if (kDebugMode) {
        debugPrint('💾 [PushToken] Pending token sačuvan: $provider/$userType');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [PushToken] Greška pri čuvanju pending tokena: $e');
    }
  }

  /// 🔄 Pokušaj registrovati pending token
  /// Poziva se nakon što Supabase postane dostupan
  static Future<bool> tryRegisterPendingToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = prefs.getString(_pendingTokenKey);

      if (pendingData == null) return false;

      final data = jsonDecode(pendingData) as Map<String, dynamic>;
      final token = data['token'] as String?;
      final provider = data['provider'] as String?;

      if (token == null || provider == null) {
        await _clearPendingToken();
        return false;
      }

      if (kDebugMode) {
        debugPrint('🔄 [PushToken] Pokušavam registrovati pending token: $provider');
      }

      // Pokušaj registraciju
      final success = await registerToken(
        token: token,
        provider: provider,
        userType: data['user_type'] as String? ?? 'vozac',
        userId: data['user_id'] as String?,
        putnikId: data['putnik_id'] as String?,
      );

      return success;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [PushToken] Greška pri registraciji pending tokena: $e');
      return false;
    }
  }

  /// 🗑️ Obriši pending token iz SharedPreferences
  static Future<void> _clearPendingToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingTokenKey);
    } catch (_) {}
  }

  /// 🗑️ Obriši token iz baze (logout, deregistracija)
  ///
  /// Može se brisati po:
  /// - [token] - specifičan token
  /// - [userId] - svi tokeni za korisnika
  /// - [putnikId] - svi tokeni za putnika
  static Future<bool> clearToken({
    String? token,
    String? userId,
    String? putnikId,
  }) async {
    try {
      if (token != null) {
        await _supabase.from('push_tokens').delete().eq('token', token);
      } else if (putnikId != null) {
        await _supabase.from('push_tokens').delete().eq('putnik_id', putnikId);
      } else if (userId != null) {
        await _supabase.from('push_tokens').delete().eq('user_id', userId);
      } else {
        return false;
      }

      if (kDebugMode) {
        debugPrint('🗑️ [PushToken] Token obrisan');
      }

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [PushToken] Greška pri brisanju tokena: $e');
      return false;
    }
  }

  /// 📊 Dohvati tokene za listu korisnika
  /// Koristi se za slanje notifikacija specifičnim korisnicima
  static Future<List<Map<String, String>>> getTokensForUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      final response =
          await _supabase.from('push_tokens').select('user_id, token, provider').inFilter('user_id', userIds);

      return (response as List)
          .map<Map<String, String>>((row) {
            return {
              'user_id': row['user_id'] as String? ?? '',
              'token': row['token'] as String? ?? '',
              'provider': row['provider'] as String? ?? '',
            };
          })
          .where((t) => t['token']!.isNotEmpty)
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [PushToken] Greška pri dohvatanju tokena: $e');
      return [];
    }
  }

  /// 📊 Dohvati tokene za listu putnika (po putnik_id)
  static Future<List<Map<String, String>>> getTokensForPutnici(List<String> putnikIds) async {
    if (putnikIds.isEmpty) return [];

    try {
      final response = await _supabase
          .from('push_tokens')
          .select('putnik_id, token, provider')
          .eq('user_type', 'putnik')
          .inFilter('putnik_id', putnikIds);

      return (response as List)
          .map<Map<String, String>>((row) {
            return {
              'putnik_id': row['putnik_id']?.toString() ?? '',
              'token': row['token'] as String? ?? '',
              'provider': row['provider'] as String? ?? '',
            };
          })
          .where((t) => t['token']!.isNotEmpty)
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [PushToken] Greška pri dohvatanju tokena putnika: $e');
      return [];
    }
  }
}
