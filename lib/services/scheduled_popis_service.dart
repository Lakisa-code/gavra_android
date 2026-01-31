import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../globals.dart';
import 'auth_manager.dart';
import 'popis_service.dart';
import 'vozac_mapping_service.dart';
import 'vozac_service.dart';

/// 📊 SERVIS ZA AUTOMATSKI POPIS U 21:00
/// Generiše popis za sve aktivne vozače svakog radnog dana u 21:00
/// ✅ Popup dialog za ulogovanog vozača
class ScheduledPopisService {
  static Timer? _dailyTimer;
  static bool _isInitialized = false;
  static const String _lastPopisDateKey = 'last_auto_popis_date';

  /// Lista aktivnih vozača - 🔧 FIX: Dinamičko učitavanje umesto hardkodirane liste
  static Future<List<String>> _getAktivniVozaci() async {
    try {
      final vozacService = VozacService();
      final vozaci = await vozacService.getAllVozaci();
      // Za sada vraćamo sve vozače, ali možemo dodati filter za aktivne
      return vozaci.map((v) => v.ime).toList();
    } catch (e) {
      // Fallback na hardkodiranu listu ako dođe do greške
      return ['Bojan', 'Bilevski', 'Bruda', 'Ivan'];
    }
  }

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
      // 🔧 FIX: Osiguraj da je VozacMappingService inicijalizovan
      await VozacMappingService.initialize();

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
    // 🔧 FIX: Osiguraj da je VozacMappingService inicijalizovan pre dohvatanja statistika!
    // Bez ovoga, getVozacUuidSync() vraća null i sve statistike su 0
    await VozacMappingService.initialize();

    // 🔧 FIX: Dinamičko učitavanje aktivnih vozača
    final aktivniVozaci = await _getAktivniVozaci();

    int uspesno = 0;
    int neuspesno = 0;

    for (final vozac in aktivniVozaci) {
      try {
        // 🔄 KORISTI CENTRALIZOVAN PopisService ZA KONZISTENTNOST
        final popisDataRaw = await PopisService.loadPopisData(
          vozac: vozac,
          selectedGrad: '', // Nije bitno za statistike
          selectedVreme: '', // Nije bitno za statistike
        );

        // Obeleži kao automatski
        final popisData = PopisData(
          vozac: popisDataRaw.vozac,
          datum: datum,
          ukupanPazar: popisDataRaw.ukupanPazar,
          sitanNovac: popisDataRaw.sitanNovac,
          otkazaniPutnici: popisDataRaw.otkazaniPutnici,
          pokupljeniPutnici: popisDataRaw.pokupljeniPutnici,
          naplaceniDnevni: popisDataRaw.naplaceniDnevni,
          naplaceniMesecni: popisDataRaw.naplaceniMesecni,
          dugoviPutnici: popisDataRaw.dugoviPutnici,
          kilometraza: popisDataRaw.kilometraza,
          automatskiGenerisan: true,
        );

        // Sačuvaj u bazu koristeći zajednički servis
        await PopisService.savePopis(popisData);
        uspesno++;

        // 📊 POPUP DIALOG - za ulogovanog vozača (vizuelno isti kao ručni)
        final currentDriver = await AuthManager.getCurrentDriver();
        if (currentDriver != null && currentDriver == vozac) {
          final context = navigatorKey.currentContext;
          if (context != null) {
            PopisService.showPopisDialog(context, popisData, isAutomatic: true);
          }
        }

        debugPrint('✅ [ScheduledPopis] Popis za $vozac sačuvan (Automatski)');
      } catch (e) {
        neuspesno++;
        debugPrint('❌ [ScheduledPopis] Greška za $vozac: $e');
      }
    }

    // Sačuvaj datum poslednjeg popisa
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastPopisDateKey, datum.toIso8601String().split('T')[0]);
    } catch (e) {
      debugPrint('⚠️ Error in scheduled popis: $e');
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
