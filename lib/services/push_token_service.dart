import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';

/// 📱 Unificirani servis za registraciju push tokena
/// Zamenjuje dupliciranu logiku iz FirebaseService, HuaweiPushService i PutnikPushService
///
/// Svi tokeni (FCM i HMS, vozači i putnici) se registruju na isti način:
/// - Direktan UPSERT u push_tokens tabelu
/// - Pending token mehanizam za offline scenarije
class PushTokenService {
  /// Lazy getter - pristupa Supabase tek kada je potrebno i inicijalizovan
  static SupabaseClient get _supabase => supabase;

  /// Proveri da li je Supabase inicijalizovan
  static bool get _isSupabaseReady => isSupabaseReady;

  /// Ključ za čuvanje pending tokena u SharedPreferences
  static const _pendingTokenKey = 'pending_push_token';

  /// 📲 Registruje push token direktno u Supabase bazu
  ///
  /// [token] - FCM ili HMS token
  /// [provider] - 'fcm' za Firebase ili 'huawei' za HMS
  /// [userType] - 'vozac' ili 'putnik'
  /// [userId] - ime vozača ili putnika (opciono)
  /// [vozacId] - UUID vozača iz vozaci tabele (samo za vozače)
  /// [putnikId] - ID putnika iz registrovani_putnici tabele (samo za putnike)
  static Future<bool> registerToken({
    required String token,
    required String provider,
    String userType = 'vozac',
    String? userId,
    String? vozacId,
    String? putnikId,
    int retryCount = 0,
  }) async {
    try {
      if (token.isEmpty) {
        if (kDebugMode) debugPrint('⚠️ [PushToken] Prazan token, preskačem registraciju');
        return false;
      }

      // ⏳ Proveri da li je Supabase spreman - ako nije, sačuvaj kao pending
      if (!_isSupabaseReady) {
        if (kDebugMode) debugPrint('⏳ [PushToken] Supabase nije spreman, čuvam kao pending');
        await savePendingToken(
          token: token,
          provider: provider,
          userType: userType,
          userId: userId,
          vozacId: vozacId,
          putnikId: putnikId,
        );
        return false;
      }

      // 🧹 PRVO: Obriši stare tokene za ovog korisnika da izbegnemo duplikate
      // Koristimo Timeout da ne bismo čekali večno ako je mreža loša
      final timeout = const Duration(seconds: 15);

      // Obriši stare tokene za istog putnika
      if (putnikId != null && putnikId.isNotEmpty) {
        await _supabase.from('push_tokens').delete().eq('putnik_id', putnikId).timeout(timeout).catchError((e) => null);
      }

      // Obriši stare tokene za istog vozača
      if (vozacId != null && vozacId.isNotEmpty) {
        await _supabase.from('push_tokens').delete().eq('vozac_id', vozacId).timeout(timeout).catchError((e) => null);
      }

      // Obriši stare tokene za istog vozača (po user_id)
      if (userId != null && userId.isNotEmpty) {
        await _supabase.from('push_tokens').delete().eq('user_id', userId).timeout(timeout).catchError((e) => null);
      }

      // ✅ UPSERT novi token (ako token već postoji, ažuriraće ga, ako ne, insertovaće)
      // Ovo je mnogo otpornije na "duplicate key" greške nego delete+insert
      await _supabase.from('push_tokens').upsert({
        'token': token,
        'provider': provider,
        'user_type': userType,
        'user_id': userId,
        'vozac_id': vozacId,
        'putnik_id': putnikId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token').timeout(timeout);

      if (kDebugMode) {
        debugPrint('✅ [PushToken] Token registrovan: $provider/$userType/${token.substring(0, 20)}...');
      }

      // Obriši pending token ako postoji (uspešno registrovan)
      await _clearPendingToken();

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [PushToken] Greška pri registraciji (pokušaj ${retryCount + 1}): $e');

      // 🔄 RETRY LOGIKA za 503/Timeout greške
      final errorStr = e.toString().toLowerCase();
      if ((errorStr.contains('503') || errorStr.contains('timeout') || errorStr.contains('upstream')) &&
          retryCount < 2) {
        await Future.delayed(Duration(seconds: 2 * (retryCount + 1))); // Eksperimentalni backoff
        return registerToken(
          token: token,
          provider: provider,
          userType: userType,
          userId: userId,
          vozacId: vozacId,
          putnikId: putnikId,
          retryCount: retryCount + 1,
        );
      }

      // Ako ni retries ne pomognu, sačuvaj kao pending
      await savePendingToken(
        token: token,
        provider: provider,
        userType: userType,
        userId: userId,
        vozacId: vozacId,
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
    String? vozacId,
    String? putnikId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = jsonEncode({
        'token': token,
        'provider': provider,
        'user_type': userType,
        'user_id': userId,
        'vozac_id': vozacId,
        'putnik_id': putnikId,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
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
        vozacId: data['vozac_id'] as String?,
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

  /// 📊 Dohvati tokene za jednog putnika (po putnik_id)
  /// Vraća listu jer putnik može imati više uređaja (roditelj + dete)
  static Future<List<Map<String, String>>> getTokensForPutnik(String putnikId) async {
    return getTokensForPutnici([putnikId]);
  }

  /// 🚗 Dohvati tokene za sve vozače
  /// Koristi se za slanje vremenskih upozorenja i drugih vozačkih notifikacija
  static Future<List<Map<String, String>>> getTokensForVozaci() async {
    try {
      final response = await _supabase.from('push_tokens').select('user_id, token, provider').eq('user_type', 'vozac');

      return (response as List)
          .map<Map<String, String>>((row) {
            return {
              'user_id': row['user_id']?.toString() ?? '',
              'token': row['token'] as String? ?? '',
              'provider': row['provider'] as String? ?? '',
            };
          })
          .where((t) => t['token']!.isNotEmpty)
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [PushToken] Greška pri dohvatanju vozačkih tokena: $e');
      return [];
    }
  }
}
