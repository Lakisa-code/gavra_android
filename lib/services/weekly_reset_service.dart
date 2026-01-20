import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../globals.dart';

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

    // Proveri da li treba odmah resetovati (propušten reset)
    await _checkMissedReset();

    // Pokreni timer za petak ponoć
    _scheduleNextReset();
  }

  /// Proveri da li je propušten reset
  static Future<void> _checkMissedReset() async {
    try {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final lastResetDate = prefs.getString(_lastResetDateKey);

      // Izračunaj datum poslednjeg petka
      final daysSinceFriday = (now.weekday - 5) % 7;
      final lastFriday = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: daysSinceFriday == 0 && now.hour < 0 ? 7 : daysSinceFriday));
      final lastFridayStr = lastFriday.toIso8601String().split('T')[0];

      // Ako je subota ili nedelja i nismo resetovali u petak
      if ((now.weekday == 6 || now.weekday == 7) && lastResetDate != lastFridayStr) {
        debugPrint('🔄 [WeeklyReset] Propušten reset za petak $lastFridayStr - resetujem sada');
        await _executeWeeklyReset();
      }
    } catch (e) {
      debugPrint('❌ [WeeklyReset] Greška pri proveri propuštenog reseta: $e');
    }
  }

  /// Zakaži sledeći reset za petak u ponoć (00:00 subota)
  static void _scheduleNextReset() {
    _weeklyTimer?.cancel();

    final now = DateTime.now();

    // Pronađi sledeći petak u ponoć (zapravo subota 00:00)
    var nextFridayMidnight = DateTime(now.year, now.month, now.day, 0, 0, 0);

    // Dodaj dane do subote (weekday 6)
    int daysUntilSaturday = (6 - now.weekday) % 7;
    if (daysUntilSaturday == 0 && now.hour >= 0) {
      // Već je subota, zakaži za sledeću
      daysUntilSaturday = 7;
    }
    nextFridayMidnight = nextFridayMidnight.add(Duration(days: daysUntilSaturday));

    final duration = nextFridayMidnight.difference(now);
    debugPrint(
        '🔄 [WeeklyReset] Sledeći reset zakazan za: $nextFridayMidnight (za ${duration.inDays}d ${duration.inHours % 24}h)');

    _weeklyTimer = Timer(duration, () async {
      await _executeWeeklyReset();
      // Zakaži sledeći
      _scheduleNextReset();
    });
  }

  /// Izvrši nedeljni reset
  static Future<void> _executeWeeklyReset() async {
    debugPrint('🔄 [WeeklyReset] Pokrećem nedeljni reset rasporeda...');

    try {
      // Učitaj sve aktivne putnike - dodao i 'tip' za selektivni reset
      final putnici =
          await supabase.from('registrovani_putnici').select('id, polasci_po_danu, tip').eq('aktivan', true);

      int resetCount = 0;

      for (final putnik in putnici) {
        final putnikId = putnik['id'] as String;
        final polasci = putnik['polasci_po_danu'] as Map<String, dynamic>? ?? {};
        final tip = putnik['tip'] as String? ?? 'radnik';

        if (polasci.isEmpty) continue;

        // ODREDI DA LI SE BRIŠE RASPORED (za promenljive putnike)
        // Radnici zadržavaju raspored, učenici i dnevni kreću ispočetka
        final shouldClearSchedule = tip == 'ucenik' || tip == 'dnevni';

        // Očisti statuse i otkazivanja za svaki dan
        final resetPolasci = <String, dynamic>{};
        for (final dan in polasci.keys) {
          final danData = polasci[dan] as Map<String, dynamic>? ?? {};

          if (shouldClearSchedule) {
            // 🧹 ZA UČENIKE I DNEVNE: Brišemo i vremena polazaka
            resetPolasci[dan] = {
              'bc': null,
              'vs': null,
            };
          } else {
            // 👷 ZA RADNIKE: Zadržavamo postojeća vremena
            resetPolasci[dan] = {
              'bc': danData['bc'],
              'vs': danData['vs'],
              // Briše: bc_status, vs_status, bc_otkazano, vs_otkazano, itd.
            };
          }
        }

        // Ažuriraj u bazi
        await supabase.from('registrovani_putnici').update({
          'polasci_po_danu': resetPolasci,
        }).eq('id', putnikId);

        resetCount++;
      }

      // Sačuvaj datum reseta
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setString(_lastResetDateKey, todayStr);

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
