import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daily_checkin_service.dart';
import 'local_notification_service.dart';
import 'voznje_log_service.dart';

/// 📊 SERVIS ZA AUTOMATSKI POPIS U 21:00
/// Generiše popis za sve aktivne vozače svakog radnog dana u 21:00
class ScheduledPopisService {
  static Timer? _dailyTimer;
  static bool _isInitialized = false;
  static const String _lastPopisDateKey = 'last_auto_popis_date';

  /// Lista aktivnih vozača
  static const List<String> _aktivniVozaci = ['Bojan', 'Bilevski', 'Bruda', 'Ivan'];

  /// Inicijalizuj servis - pozovi iz main.dart ili welcome_screen
  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    debugPrint('📊 [ScheduledPopis] Inicijalizacija servisa...');

    // Proveri da li treba odmah generisati popis (propušten)
    await _checkMissedPopis();

    // Pokreni timer za 21:00
    _scheduleNextPopis();
  }

  /// Proveri da li je propušten popis za danas
  static Future<void> _checkMissedPopis() async {
    try {
      final now = DateTime.now();

      // Preskači vikend
      if (now.weekday == 6 || now.weekday == 7) {
        debugPrint('📊 [ScheduledPopis] Vikend - preskačem proveru');
        return;
      }

      // Ako je posle 21:00, proveri da li je popis već generisan danas
      if (now.hour >= 21) {
        final todayStr = now.toIso8601String().split('T')[0];
        final prefs = await SharedPreferences.getInstance();
        final lastPopisDate = prefs.getString(_lastPopisDateKey);

        if (lastPopisDate != todayStr) {
          debugPrint('📊 [ScheduledPopis] Propušten popis za danas - generiram sada');
          await _generatePopisForAllVozaci(now);
        }
      }
    } catch (e) {
      debugPrint('❌ [ScheduledPopis] Greška pri proveri propuštenog popisa: $e');
    }
  }

  /// Zakaži sledeći popis za 21:00
  static void _scheduleNextPopis() {
    _dailyTimer?.cancel();

    final now = DateTime.now();
    var next21 = DateTime(now.year, now.month, now.day, 21, 0, 0);

    // Ako je već prošlo 21:00, zakaži za sutra
    if (now.isAfter(next21)) {
      next21 = next21.add(const Duration(days: 1));
    }

    // Preskoči vikend
    while (next21.weekday == 6 || next21.weekday == 7) {
      next21 = next21.add(const Duration(days: 1));
    }

    final duration = next21.difference(now);
    debugPrint(
        '📊 [ScheduledPopis] Sledeći popis zakazan za: $next21 (za ${duration.inHours}h ${duration.inMinutes % 60}min)');

    _dailyTimer = Timer(duration, () async {
      await _executeDailyPopis();
      // Zakaži sledeći
      _scheduleNextPopis();
    });
  }

  /// Izvrši dnevni popis
  static Future<void> _executeDailyPopis() async {
    final now = DateTime.now();

    // Dodatna provera za vikend (za svaki slučaj)
    if (now.weekday == 6 || now.weekday == 7) {
      debugPrint('📊 [ScheduledPopis] Vikend - preskačem popis');
      return;
    }

    debugPrint('📊 [ScheduledPopis] Pokrećem automatski popis u 21:00');
    await _generatePopisForAllVozaci(now);
  }

  /// Generiši popis za sve vozače
  static Future<void> _generatePopisForAllVozaci(DateTime datum) async {
    int uspesno = 0;
    int neuspesno = 0;

    for (final vozac in _aktivniVozaci) {
      try {
        // Dohvati statistike za vozača
        final stats = await VoznjeLogService.getStatistikePoVozacu(
          vozacIme: vozac,
          datum: datum,
        );

        final pokupljeni = stats['voznje'] as int? ?? 0;
        final otkazani = stats['otkazivanja'] as int? ?? 0;
        final uplate = stats['uplate'] as int? ?? 0;
        final pazar = stats['pazar'] as double? ?? 0.0;

        // Dohvati broj dužnika (pokupljeni ali neplaćeni)
        final duznici = await VoznjeLogService.getBrojDuznikaPoVozacu(
          vozacIme: vozac,
          datum: datum,
        );

        // Sitan novac za vozača
        final sitanNovac = await DailyCheckInService.getTodayAmount(vozac) ?? 0.0;

        // Kreiraj popis
        final popisData = {
          'vozac': vozac,
          'datum': datum.toIso8601String(),
          'ukupanPazar': pazar,
          'sitanNovac': sitanNovac,
          'otkazaniPutnici': otkazani,
          'naplaceniPutnici': uplate,
          'pokupljeniPutnici': pokupljeni,
          'dugoviPutnici': duznici,
          'mesecneKarte': uplate,
          'kilometraza': 0.0,
          'automatskiGenerisan': true,
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Sačuvaj u bazu
        await DailyCheckInService.saveDailyReport(vozac, datum, popisData);
        uspesno++;

        debugPrint(
            '✅ [ScheduledPopis] Popis za $vozac: pokupljeni=$pokupljeni, otkazani=$otkazani, duznici=$duznici, pazar=$pazar');
      } catch (e) {
        neuspesno++;
        debugPrint('❌ [ScheduledPopis] Greška za $vozac: $e');
      }
    }

    // Sačuvaj datum poslednjeg popisa
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastPopisDateKey, datum.toIso8601String().split('T')[0]);
    } catch (_) {}

    // Prikaži notifikaciju o završenom popisu
    if (uspesno > 0) {
      await LocalNotificationService.showRealtimeNotification(
        title: '📊 Automatski popis završen',
        body: 'Generisani popisi za $uspesno vozača (${datum.day}.${datum.month}.${datum.year})',
      );
    }

    debugPrint('📊 [ScheduledPopis] Završeno: $uspesno uspešno, $neuspesno neuspešno');
  }

  /// Ručno pokreni popis (za testiranje)
  static Future<void> manualTrigger() async {
    debugPrint('📊 [ScheduledPopis] Ručno pokretanje popisa...');
    await _generatePopisForAllVozaci(DateTime.now());
  }

  /// Zaustavi servis
  static void dispose() {
    _dailyTimer?.cancel();
    _dailyTimer = null;
    _isInitialized = false;
    debugPrint('📊 [ScheduledPopis] Servis zaustavljen');
  }
}
