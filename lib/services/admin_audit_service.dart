import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/constants.dart';
import '../globals.dart';

/// 🕵️ ADMIN AUDIT SERVICE
/// Beleži sve akcije admina radi sigurnosti i istorije promena.
class AdminAuditService {
  static SupabaseClient get _supabase => supabase;

  /// Loguje admin akciju
  static Future<void> logAction({
    required String adminName,
    required String actionType,
    required String details,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _supabase.from('admin_audit_logs').insert({
        'admin_name': adminName,
        'action_type': actionType,
        'details': details,
        'metadata': metadata,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      // Ne printamo ovde da ne bi spamovali konzolu, log je u bazi.
    } catch (e) {
      // Ako log ne uspe, ne smemo da srušimo aplikaciju, samo ispišemo grešku
      print('⚠️ Failed to write audit log: $e');
    }
  }

  // 👇 PREDEFINISANE POMOĆNE METODE ZA ESTETIKU KODA 👇

  /// Loguje promenu kapaciteta
  static Future<void> logCapacityChange({
    required String adminName,
    required String datum,
    required String vreme,
    required int oldCap,
    required int newCap,
  }) async {
    await logAction(
      adminName: adminName,
      actionType: AppConstants.logTypePromenaKapaciteta, // Koristi konstantu!
      details: 'Promena kapaciteta za $datum $vreme: $oldCap -> $newCap',
      metadata: {
        'datum': datum,
        'vreme': vreme,
        'old_value': oldCap,
        'new_value': newCap,
      },
    );
  }

  /// Loguje brisanje korisnika/vožnje
  static Future<void> logDeletion({
    required String adminName,
    required String targetName,
    required String reason,
  }) async {
    await logAction(
      adminName: adminName,
      actionType: 'DELETE_USER',
      details: 'Obrisan putnik $targetName. Razlog: $reason',
      metadata: {
        'target_user': targetName,
      },
    );
  }
}
