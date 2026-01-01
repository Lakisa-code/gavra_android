import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🧹 Servis za čišćenje nevalidnih push tokena
/// Automatski briše tokene koji su UNREGISTERED ili invalid
class TokenCleanupService {
  /// 🗑️ Obriši nevalidne tokene na osnovu rezultata slanja
  /// Poziva se nakon što Edge funkcija vrati listu neuspešnih tokena
  static Future<int> cleanupInvalidTokens(List<dynamic> results) async {
    if (results.isEmpty) return 0;

    int deletedCount = 0;

    for (final result in results) {
      try {
        final success = result['success'] as bool? ?? true;
        final error = result['error'] as String? ?? '';
        final token = result['token'] as String? ?? '';

        // Proveri da li je token nevalidan
        if (!success && _isUnregisteredError(error) && token.isNotEmpty) {
          // Obriši token iz baze
          final deleted = await _deleteToken(token);
          if (deleted) {
            deletedCount++;
            if (kDebugMode) {
              debugPrint('🧹 [TokenCleanup] Obrisan nevalidan token: ${token.substring(0, 20)}...');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ [TokenCleanup] Greška pri obradi rezultata: $e');
        }
      }
    }

    if (deletedCount > 0 && kDebugMode) {
      debugPrint('🧹 [TokenCleanup] Ukupno obrisano $deletedCount nevalidnih tokena');
    }

    return deletedCount;
  }

  /// 🔍 Proveri da li je greška UNREGISTERED tip
  static bool _isUnregisteredError(String error) {
    final lowerError = error.toLowerCase();
    return lowerError.contains('unregistered') ||
        lowerError.contains('invalid') ||
        lowerError.contains('not found') ||
        lowerError.contains('all the tokens are invalid');
  }

  /// 🗑️ Obriši token iz baze po vrednosti tokena
  static Future<bool> _deleteToken(String token) async {
    try {
      // Token u bazi može biti pun, a mi imamo samo prvih 20 karaktera
      // Koristimo LIKE pretragu
      final tokenPrefix = token.length > 20 ? token.substring(0, 20) : token;
      final supabase = Supabase.instance.client;

      await supabase.from('push_tokens').delete().like('token', '$tokenPrefix%');

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [TokenCleanup] Greška pri brisanju tokena: $e');
      }
      return false;
    }
  }

  /// 🧹 Ručno pokreni čišćenje svih nevalidnih tokena
  /// Šalje tihu notifikaciju i briše tokene koji ne rade
  static Future<Map<String, int>> runFullCleanup() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'send-push-notification',
        body: {
          'title': 'Token Validation',
          'body': 'Silent check',
          'broadcast': true,
          'data': {'type': 'token_validation', 'silent': true},
        },
      );

      if (response.data != null && response.data['results'] != null) {
        final results = response.data['results'] as List<dynamic>;
        final validCount = results.where((r) => r['success'] == true).length;
        final invalidCount = results.where((r) => r['success'] == false).length;

        // Očisti nevalidne
        final deletedCount = await cleanupInvalidTokens(results);

        return {
          'valid': validCount,
          'invalid': invalidCount,
          'deleted': deletedCount,
        };
      }

      return {'valid': 0, 'invalid': 0, 'deleted': 0};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [TokenCleanup] Greška pri čišćenju: $e');
      }
      return {'valid': 0, 'invalid': 0, 'deleted': 0, 'error': 1};
    }
  }
}
