import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../globals.dart';
import 'user_audit_service.dart';
import 'voznje_log_service.dart';

/// 🔄 SERVIS ZA NEDELJNI RESET RASPOREDA
/// U petak u ponoć (00:00 subota) resetuje polasci_po_danu za sve putnike
/// - Briše bc_otkazano, vs_otkazano, bc_status, vs_status
/// - Zadržava bc i vs vremena (standardni raspored)
class WeeklyResetService {
  static Timer? _weeklyTimer;
  static bool _isInitialized = false;
  static const String _lastResetDateKey = 'last_weekly_reset_date';

  /// Inicijalizuj servis - pozovi iz main.dart
  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    debugPrint('🔄 [WeeklyReset] Inicijalizacija servisa...');

    // AUTOMATSKI RESET UKLONJEN - termini ostaju sačuvani između nedelja
    // await _checkMissedReset();

    // AUTOMATSKI TIMER JE ONEMOGUĆEN - sada se koristi samo ručni reset
    // _scheduleNextReset();
  }

  /// Izvrši nedeljni reset
  static Future<void> _executeWeeklyReset() async {
    debugPrint('🔄 [WeeklyReset] Pokrećem nedeljni reset rasporeda...');

    try {
      // Učitaj sve aktivne putnike - dodao i 'tip' za selektivni reset
      final putnici = await supabase
          .from('registrovani_putnici')
          .select('id, polasci_po_danu, tip')
          .eq('aktivan', true)
          .eq('obrisan', false)
          .eq('is_duplicate', false);

      int resetCount = 0;

      for (final putnik in putnici) {
        final putnikId = putnik['id'] as String;
        final rawPolasci = putnik['polasci_po_danu'];

        Map<String, dynamic> polasci = {};

        if (rawPolasci is String) {
          try {
            polasci = json.decode(rawPolasci) as Map<String, dynamic>? ?? {};
          } catch (e) {
            debugPrint('⚠️ Error decoding polasci_po_danu JSON: $e');
          }
        } else if (rawPolasci is Map) {
          polasci = Map<String, dynamic>.from(rawPolasci);
        }

        if (polasci.isEmpty) continue;

        // 🧹 RESETUJEMO SVE PODATKE (vremena, statuse, otkazivanja) ZA NOVU NEDELJU
        final resetPolasci = <String, dynamic>{};
        for (final dan in polasci.keys) {
          // Kreiramo potpuno prazan objekat za svaki dan tako da putnik mora ponovo da unese vreme
          resetPolasci[dan] = {};
        }

        // Ažuriraj u bazi
        await supabase.from('registrovani_putnici').update({
          'polasci_po_danu': resetPolasci,
          'aktivan': true, // Osiguravamo da ostane aktivan kako bi mogao sam da zakaže
        }).eq('id', putnikId);

        resetCount++;
      }

      // 📝 LOGOVANJE AKCIJE U DNEVNIK
      if (resetCount > 0) {
        await VoznjeLogService.logGeneric(
          tip: 'nedeljni_reset',
          detalji: 'Automatski nedeljni reset rasporeda (prazna polja) za $resetCount putnika.',
        );
      }

      // Sačuvaj datum reseta
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setString(_lastResetDateKey, todayStr);

      // 🧹 Clean up old audit records
      await UserAuditService().cleanupOldRecords();

      debugPrint('🔄 [WeeklyReset] ✅ Uspešno resetovano $resetCount putnika');
    } catch (e) {
      debugPrint('❌ [WeeklyReset] Greška pri resetu: $e');
    }
  }

  /// Zaustavi timer
  static void dispose() {
    _weeklyTimer?.cancel();
    _weeklyTimer = null;
    _isInitialized = false;
    debugPrint('🔄 [WeeklyReset] Servis zaustavljen');
  }

  /// Ručni reset (za testiranje)
  static Future<void> manualReset() async {
    debugPrint('🔄 [WeeklyReset] Ručni reset pokrenut...');
    await _executeWeeklyReset();
  }
}
