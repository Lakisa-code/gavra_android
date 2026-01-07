import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'putnik_service.dart';
import 'realtime/realtime_manager.dart';
import 'statistika_service.dart';

class DailyCheckInService {
  static final StreamController<double> _sitanNovacController = StreamController<double>.broadcast();

  // 🔧 SINGLETON PATTERN za kusur stream - koristi JEDAN RealtimeManager channel za sve vozače
  static final Map<String, StreamController<double>> _kusurControllers = {};
  static StreamSubscription? _globalSubscription;
  static bool _isSubscribed = false;

  /// Stream za real-time ažuriranje kusura - SINGLETON sa RealtimeManager
  static Stream<double> streamTodayAmount(String vozac) {
    // Ako već postoji aktivan controller za ovog vozača, koristi ga
    if (_kusurControllers.containsKey(vozac) && !_kusurControllers[vozac]!.isClosed) {
      // debugPrint('📊 [DailyCheckInService] Reusing existing kusur stream for $vozac'); // Disabled - too spammy
      return _kusurControllers[vozac]!.stream;
    }

    final controller = StreamController<double>.broadcast();
    _kusurControllers[vozac] = controller;

    final today = DateTime.now().toIso8601String().split('T')[0];

    // Učitaj inicijalne podatke
    _fetchKusurForVozac(vozac, today, controller);

    // Osiguraj da postoji globalni subscription (deli se između svih vozača)
    _ensureGlobalSubscription(today);

    return controller.stream;
  }

  /// 🔧 Fetch kusur za vozača
  static Future<void> _fetchKusurForVozac(
    String vozac,
    String today,
    StreamController<double> controller,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('daily_checkins')
          .select('sitan_novac')
          .eq('vozac', vozac)
          .eq('datum', today)
          .maybeSingle();

      if (!controller.isClosed) {
        final amount = (data?['sitan_novac'] as num?)?.toDouble() ?? 0.0;
        controller.add(amount);
      }
    } catch (_) {
      // Fetch error - silent
    }
  }

  /// 🔌 Osiguraj globalni subscription preko RealtimeManager
  static void _ensureGlobalSubscription(String today) {
    if (_isSubscribed && _globalSubscription != null) return;

    // Koristi centralizovani RealtimeManager - JEDAN channel za sve vozače!
    _globalSubscription = RealtimeManager.instance.subscribe('daily_checkins').listen((payload) {
      // Osvježi sve aktivne vozače
      for (final entry in _kusurControllers.entries) {
        final vozac = entry.key;
        final controller = entry.value;
        if (!controller.isClosed) {
          _fetchKusurForVozac(vozac, today, controller);
        }
      }
    });

    _isSubscribed = true;
  }

  /// 🧹 Čisti kusur cache za vozača
  static void clearKusurCache(String vozac) {
    _kusurControllers[vozac]?.close();
    _kusurControllers.remove(vozac);

    // Ako nema više aktivnih controllera, zatvori globalni subscription
    if (_kusurControllers.isEmpty && _globalSubscription != null) {
      _globalSubscription?.cancel();
      RealtimeManager.instance.unsubscribe('daily_checkins');
      _globalSubscription = null;
      _isSubscribed = false;
    }
  }

  /// 🧹 Čisti sve kusur cache-eve
  static void clearAllKusurCache() {
    for (final controller in _kusurControllers.values) {
      controller.close();
    }
    _kusurControllers.clear();

    // Zatvori globalni subscription
    _globalSubscription?.cancel();
    RealtimeManager.instance.unsubscribe('daily_checkins');
    _globalSubscription = null;
    _isSubscribed = false;
  }

  /// Initialize stream with current value
  static Future<void> initializeStreamForVozac(String vozac) async {
    final currentAmount = await getTodayAmount(vozac) ?? 0.0;
    if (!_sitanNovacController.isClosed) {
      _sitanNovacController.add(currentAmount);
    }
  }

  /// Inicijalizuj realtime stream za vozača tako da kocka prati bazu
  static StreamSubscription<dynamic> initializeRealtimeForDriver(String vozac) {
    return Stream<dynamic>.empty().listen((_) {});
  }

  /// Proveri da li je vozač već uradio check-in danas
  /// Proverava DIREKTNO BAZU - source of truth
  static Future<bool> hasCheckedInToday(String vozac) async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD

    try {
      final response = await Supabase.instance.client
          .from('daily_checkins')
          .select('sitan_novac')
          .eq('vozac', vozac)
          .eq('datum', todayStr)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));

      if (response != null) {
        // Emituj update za stream
        final sitanNovac = (response['sitan_novac'] as num?)?.toDouble() ?? 0.0;
        if (!_sitanNovacController.isClosed) {
          _sitanNovacController.add(sitanNovac);
        }
        if (_kusurControllers.containsKey(vozac) && !_kusurControllers[vozac]!.isClosed) {
          _kusurControllers[vozac]!.add(sitanNovac);
        }
        return true;
      }
    } catch (e) {
      // Error handled silently
    }

    return false;
  }

  /// Sačuvaj daily check-in (sitan novac i pazari)
  static Future<void> saveCheckIn(
    String vozac,
    double sitanNovac, {
    double dnevniPazari = 0.0,
  }) async {
    final today = DateTime.now();

    // 🌐 DIREKTNO U BAZU - upsert će ažurirati ako već postoji za danas
    try {
      await _saveToSupabase(vozac, sitanNovac, today, dnevniPazari: dnevniPazari).timeout(const Duration(seconds: 8));

      // Ažuriraj stream za UI
      if (!_sitanNovacController.isClosed) {
        _sitanNovacController.add(sitanNovac);
      }
    } catch (e) {
      rethrow; // Propagiraj grešku da UI zna da nije uspelo
    }
  }

  /// Dohvati iznos za danas - DIREKTNO IZ BAZE
  static Future<double?> getTodayAmount(String vozac) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final data = await Supabase.instance.client
          .from('daily_checkins')
          .select('sitan_novac')
          .eq('vozac', vozac)
          .eq('datum', today)
          .maybeSingle();
      return (data?['sitan_novac'] as num?)?.toDouble();
    } catch (e) {
      return null;
    }
  }

  /// Dohvati kompletne podatke za danas - DIREKTNO IZ BAZE
  static Future<Map<String, dynamic>> getTodayCheckIn(String vozac) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final data = await Supabase.instance.client
          .from('daily_checkins')
          .select()
          .eq('vozac', vozac)
          .eq('datum', today)
          .maybeSingle();

      if (data != null) {
        return {
          'sitan_novac': (data['sitan_novac'] as num?)?.toDouble() ?? 0.0,
          'dnevni_pazari': (data['dnevni_pazari'] as num?)?.toDouble() ?? 0.0,
          'has_checked_in': true,
          'timestamp': data['checkin_vreme'] != null ? DateTime.parse(data['checkin_vreme']) : null,
        };
      }
    } catch (e) {
      // Greška - vrati prazno
    }

    return {
      'sitan_novac': 0.0,
      'dnevni_pazari': 0.0,
      'has_checked_in': false,
      'timestamp': null,
    };
  }

  /// Sačuvaj u Supabase tabelu daily_checkins
  static Future<Map<String, dynamic>?> _saveToSupabase(
    String vozac,
    double sitanNovac,
    DateTime datum, {
    double dnevniPazari = 0.0,
  }) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('daily_checkins')
          .upsert(
            {
              'vozac': vozac,
              'datum': datum.toIso8601String().split('T')[0], // YYYY-MM-DD format
              'sitan_novac': sitanNovac,
              'dnevni_pazari': dnevniPazari,
              'ukupno': sitanNovac + dnevniPazari,
              'checkin_vreme': DateTime.now().toIso8601String(),
              'created_at': datum.toIso8601String(),
            },
            onConflict: 'vozac,datum', // 🎯 Ključno za upsert!
          )
          .select()
          .maybeSingle();

      if (response is Map<String, dynamic>) return response;
      return null;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST106' || e.message.contains('does not exist') || e.code == '404') {
        await _createDailyCheckinsTable();
        final response = await supabase
            .from('daily_checkins')
            .upsert(
              {
                'vozac': vozac,
                'datum': datum.toIso8601String().split('T')[0],
                'sitan_novac': sitanNovac,
                'dnevni_pazari': dnevniPazari,
                'ukupno': sitanNovac + dnevniPazari,
                'checkin_vreme': DateTime.now().toIso8601String(),
                'created_at': datum.toIso8601String(),
              },
              onConflict: 'vozac,datum', // 🎯 Ključno za upsert!
            )
            .select()
            .maybeSingle();

        if (response is Map<String, dynamic>) return response;
        return null;
      } else {
        rethrow;
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Kreiraj tabelu daily_checkins ako ne postoji
  static Future<void> _createDailyCheckinsTable() async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.rpc<void>('create_daily_checkins_table_if_not_exists');
    } catch (e) {
      // 🔇 Ignore
    }
  }

  /// 📊 NOVI: Sačuvaj kompletan dnevni popis - DIREKTNO U BAZU
  static Future<void> saveDailyReport(
    String vozac,
    DateTime datum,
    Map<String, dynamic> popisPodaci,
  ) async {
    try {
      await _savePopisToSupabase(vozac, popisPodaci, datum);
    } catch (e) {
      rethrow;
    }
  }

  /// 📊 NOVI: Dohvati poslednji popis za vozača - DIREKTNO IZ BAZE
  static Future<Map<String, dynamic>?> getLastDailyReport(String vozac) async {
    try {
      final data = await Supabase.instance.client
          .from('daily_reports')
          .select()
          .eq('vozac', vozac)
          .order('datum', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data != null) {
        return {
          'datum': DateTime.parse(data['datum']),
          'popis': _convertDbToPopis(data),
        };
      }
    } catch (e) {
      // Error handled silently
    }
    return null;
  }

  /// 📊 NOVI: Dohvati popis za specifičan datum - DIREKTNO IZ BAZE
  static Future<Map<String, dynamic>?> getDailyReportForDate(String vozac, DateTime datum) async {
    try {
      final datumStr = datum.toIso8601String().split('T')[0];
      final data = await Supabase.instance.client
          .from('daily_reports')
          .select()
          .eq('vozac', vozac)
          .eq('datum', datumStr)
          .maybeSingle();

      if (data != null) {
        return {
          'datum': datum,
          'popis': _convertDbToPopis(data),
        };
      }
    } catch (e) {
      // Error handled silently
    }
    return null;
  }

  /// Helper: Konvertuj DB red u popis format
  static Map<String, dynamic> _convertDbToPopis(Map<String, dynamic> data) {
    return {
      'ukupanPazar': (data['ukupan_pazar'] as num?)?.toDouble() ?? 0.0,
      'sitanNovac': (data['sitan_novac'] as num?)?.toDouble() ?? 0.0,
      'otkazaniPutnici': data['otkazani_putnici'] ?? 0,
      'naplaceniPutnici': data['naplaceni_putnici'] ?? 0,
      'pokupljeniPutnici': data['pokupljeni_putnici'] ?? 0,
      'dugoviPutnici': data['dugovi_putnici'] ?? 0,
      'mesecneKarte': data['mesecne_karte'] ?? 0,
      'kilometraza': (data['kilometraza'] as num?)?.toDouble() ?? 0.0,
      'automatskiGenerisan': data['automatski_generisan'] ?? false,
    };
  }

  /// 📊 AUTOMATSKO GENERISANJE POPISA ZA PRETHODNI DAN
  static Future<Map<String, dynamic>?> generateAutomaticReport(
    String vozac,
    DateTime targetDate,
  ) async {
    try {
      // 🚫 PRESKAČI VIKENDE - ne radi se subotom i nedeljom
      if (targetDate.weekday == 6 || targetDate.weekday == 7) {
        return null;
      }
      final PutnikService putnikService = PutnikService();
      // 1. OSNOVNI PODACI ZA CILJANI DATUM
      final dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final dayEnd = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        23,
        59,
        59,
      );
      // 2. KOMBINOVANI PUTNICI ZA DATUM (iz realtime) - koristimo server-filter
      final isoDate =
          '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
      final putnici = await putnikService.streamKombinovaniPutniciFiltered(isoDate: isoDate).first;
      // ✅ FIX: Koristi StatistikaService umesto manuelne logike - IDENTIČNO SA _showPopisDana()

      // 3. REALTIME DETALJNE STATISTIKE - IDENTIČNE SA STATISTIKA SCREEN
      final detaljneStats = await StatistikaService.instance.detaljneStatistikePoVozacima(
        putnici,
        dayStart,
        dayEnd,
      );
      final vozacStats = detaljneStats[vozac] ?? {};

      // 4. REALTIME PAZAR STREAM - IDENTIČNO SA _showPopisDana()
      double ukupanPazar;
      try {
        ukupanPazar = await StatistikaService.streamPazarZaSveVozace(
          from: dayStart,
          to: dayEnd,
        ).map((pazarMap) => pazarMap[vozac] ?? 0.0).first.timeout(const Duration(seconds: 10));
      } catch (e) {
        ukupanPazar = 0.0;
      }

      // 6. MAPIRANJE PODATAKA - IDENTIČNO SA STATISTIKA SCREEN
      final otkazaniPutnici = (vozacStats['otkazani'] ?? 0) as int;
      final pokupljeniPutnici = (vozacStats['pokupljeni'] ?? 0) as int;
      final dugoviPutnici = (vozacStats['dugovi'] ?? 0) as int;
      final mesecneKarte = (vozacStats['mesecneKarte'] ?? 0) as int;

      // 5. SITAN NOVAC - UČITAJ RUČNO UNET KUSUR (ne kalkuliši automatski)
      double sitanNovac;
      try {
        sitanNovac = await getTodayAmount(vozac) ?? 0.0;
      } catch (e) {
        sitanNovac = 0.0;
      }
      // 🚗 REALTIME GPS KILOMETRAŽA - IDENTIČNO SA _showPopisDana()
      double kilometraza;
      try {
        kilometraza = await StatistikaService.instance.getKilometrazu(vozac, dayStart, dayEnd);
      } catch (e) {
        kilometraza = 0.0;
      }
      // 🆕 NAPLAĆENI PUTNICI
      final naplaceniPutnici = (vozacStats['naplaceni'] ?? 0) as int;

      // 6. KREIRAJ POPIS OBJEKAT
      final automatskiPopis = {
        'vozac': vozac,
        'datum': targetDate.toIso8601String(),
        'ukupanPazar': ukupanPazar,
        'sitanNovac': sitanNovac,
        'otkazaniPutnici': otkazaniPutnici,
        'naplaceniPutnici': naplaceniPutnici,
        'pokupljeniPutnici': pokupljeniPutnici,
        'dugoviPutnici': dugoviPutnici,
        'mesecneKarte': mesecneKarte,
        'kilometraza': kilometraza,
        'automatskiGenerisan': true,
        'timestamp': DateTime.now().toIso8601String(),
      };
      // 7. SAČUVAJ AUTOMATSKI POPIS
      await saveDailyReport(vozac, targetDate, automatskiPopis);
      return automatskiPopis;
    } catch (e) {
      debugPrint('❌ generateAutomaticReport error: $e');
      return null;
    }
  }

  /// 📊 HELPER: Sačuvaj popis u Supabase
  static Future<void> _savePopisToSupabase(
    String vozac,
    Map<String, dynamic> popisPodaci,
    DateTime datum,
  ) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.from('daily_reports').upsert({
        'vozac': vozac,
        'datum': datum.toIso8601String().split('T')[0],
        'ukupan_pazar': popisPodaci['ukupanPazar'] ?? 0.0,
        'sitan_novac': popisPodaci['sitanNovac'] ?? 0.0,
        'dnevni_pazari': popisPodaci['ukupanPazar'] ?? 0.0, // Isti kao ukupan_pazar
        'ukupno': (popisPodaci['sitanNovac'] ?? 0.0) + (popisPodaci['ukupanPazar'] ?? 0.0),
        'checkin_vreme': DateTime.now().toIso8601String(),
        'otkazani_putnici': popisPodaci['otkazaniPutnici'] ?? 0,
        'naplaceni_putnici': popisPodaci['naplaceniPutnici'] ?? 0,
        'pokupljeni_putnici': popisPodaci['pokupljeniPutnici'] ?? 0,
        'dugovi_putnici': popisPodaci['dugoviPutnici'] ?? 0,
        'mesecne_karte': popisPodaci['mesecneKarte'] ?? 0,
        'kilometraza': popisPodaci['kilometraza'] ?? 0.0,
        'automatski_generisan': popisPodaci['automatskiGenerisan'] ?? true,
        'created_at': datum.toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }
}
