import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'realtime/realtime_manager.dart';
import 'statistika_service.dart';
import 'voznje_log_service.dart';

class DailyCheckInService {
  // 🔧 SINGLETON PATTERN za kusur stream - koristi JEDAN RealtimeManager channel za sve vozače
  static final Map<String, StreamController<double>> _kusurControllers = {};
  static final Map<String, double> _kusurCache = {}; // 💾 Cache poslednje vrednosti
  static StreamSubscription? _globalSubscription;
  static bool _isSubscribed = false;

  /// Stream za real-time ažuriranje kusura - SINGLETON sa RealtimeManager
  static Stream<double> streamTodayAmount(String vozac) {
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Ako već postoji aktivan controller za ovog vozača, koristi ga
    if (_kusurControllers.containsKey(vozac) && !_kusurControllers[vozac]!.isClosed) {
      debugPrint('📊 [DailyCheckInService] Reusing existing kusur stream for $vozac');
      final controller = _kusurControllers[vozac]!;

      // 🔥 FIX: UVEK fetchuj podatke kada se stream reuse-uje
      // Ovo osigurava da novi StreamBuilder dobije trenutnu vrednost
      _fetchKusurForVozac(vozac, today, controller);

      return controller.stream;
    }

    debugPrint('🆕 [DailyCheckInService] Creating NEW kusur stream for $vozac');
    final controller = StreamController<double>.broadcast();
    _kusurControllers[vozac] = controller;

    debugPrint('📅 [DailyCheckInService] Today date: $today');

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
      debugPrint('🔍 [Kusur] Fetching kusur for vozac=$vozac, datum=$today');
      final data = await supabase
          .from('daily_reports')
          .select('sitan_novac')
          .eq('vozac', vozac)
          .eq('datum', today)
          .maybeSingle();

      debugPrint('🔍 [Kusur] Query result: $data');
      if (!controller.isClosed) {
        final amount = (data?['sitan_novac'] as num?)?.toDouble() ?? 0.0;
        debugPrint('🔍 [Kusur] Adding amount to stream: $amount');
        _kusurCache[vozac] = amount; // 💾 Sačuvaj u cache
        controller.add(amount);
      }
    } catch (e) {
      debugPrint('❌ [Kusur] Fetch error: $e');
    }
  }

  /// 🔌 Osiguraj globalni subscription preko RealtimeManager
  static void _ensureGlobalSubscription(String today) {
    if (_isSubscribed && _globalSubscription != null) {
      debugPrint('♻️ [DailyCheckInService] Realtime subscription already exists');
      return;
    }

    debugPrint('🔌 [DailyCheckInService] Creating realtime subscription for daily_reports');

    // Koristi centralizovani RealtimeManager - JEDAN channel za sve vozače!
    _globalSubscription = RealtimeManager.instance.subscribe('daily_reports').listen((payload) {
      debugPrint('🔔 [DailyCheckInService] Realtime event received: ${payload.eventType}');

      // Osvježi sve aktivne vozače - UVEK KORISTI TRENUTNI DATUM!
      final currentDate = DateTime.now().toIso8601String().split('T')[0];
      debugPrint('🔄 [DailyCheckInService] Refreshing ${_kusurControllers.length} vozac streams');

      for (final entry in _kusurControllers.entries) {
        final vozac = entry.key;
        final controller = entry.value;
        if (!controller.isClosed) {
          debugPrint('🔄 [DailyCheckInService] Refreshing kusur for $vozac');
          _fetchKusurForVozac(vozac, currentDate, controller);
        }
      }
    });

    _isSubscribed = true;
  }

  /// 🧹 Čisti kusur cache za vozača
  static void clearKusurCache(String vozac) {
    _kusurControllers[vozac]?.close();
    _kusurControllers.remove(vozac);
    _kusurCache.remove(vozac); // 💾 Obriši i cached vrednost

    // Ako nema više aktivnih controllera, zatvori globalni subscription
    if (_kusurControllers.isEmpty && _globalSubscription != null) {
      _globalSubscription?.cancel();
      RealtimeManager.instance.unsubscribe('daily_reports');
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
    _kusurCache.clear(); // 💾 Obriši sve cached vrednosti

    // Zatvori globalni subscription
    _globalSubscription?.cancel();
    RealtimeManager.instance.unsubscribe('daily_reports');
    _globalSubscription = null;
    _isSubscribed = false;
  }

  /// Initialize stream with current value
  static Future<void> initializeStreamForVozac(String vozac) async {
    final currentAmount = await getTodayAmount(vozac) ?? 0.0;
    if (_kusurControllers.containsKey(vozac) && !_kusurControllers[vozac]!.isClosed) {
      _kusurControllers[vozac]!.add(currentAmount);
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
          .from('daily_reports')
          .select('sitan_novac')
          .eq('vozac', vozac)
          .eq('datum', todayStr)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));

      if (response != null) {
        // Emituj update za stream
        final sitanNovac = (response['sitan_novac'] as num?)?.toDouble() ?? 0.0;
        _kusurCache[vozac] = sitanNovac; // 💾 Sačuvaj u cache
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

  /// Sačuvaj daily check-in (sitan novac)
  static Future<void> saveCheckIn(
    String vozac,
    double sitanNovac,
  ) async {
    final today = DateTime.now();

    // 🌐 DIREKTNO U BAZU - upsert će ažurirati ako već postoji za danas
    try {
      await _saveToSupabase(vozac, sitanNovac, today).timeout(const Duration(seconds: 8));

      // Ažuriraj stream za UI
      _kusurCache[vozac] = sitanNovac; // 💾 Sačuvaj u cache
      if (_kusurControllers.containsKey(vozac) && !_kusurControllers[vozac]!.isClosed) {
        _kusurControllers[vozac]!.add(sitanNovac);
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
          .from('daily_reports')
          .select('sitan_novac')
          .eq('vozac', vozac)
          .eq('datum', today)
          .maybeSingle();
      return (data?['sitan_novac'] as num?)?.toDouble();
    } catch (e) {
      return null;
    }
  }

  /// Sačuvaj u Supabase tabelu daily_reports
  static Future<Map<String, dynamic>?> _saveToSupabase(
    String vozac,
    double sitanNovac,
    DateTime datum,
  ) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('daily_reports')
          .upsert(
            {
              'vozac': vozac,
              'datum': datum.toIso8601String().split('T')[0], // YYYY-MM-DD format
              'sitan_novac': sitanNovac,
              'checkin_vreme': DateTime.now().toIso8601String(),
            },
            onConflict: 'vozac,datum', // 🎯 Ključno za upsert!
          )
          .select()
          .maybeSingle();

      if (response is Map<String, dynamic>) return response;
      return null;
    } catch (e) {
      rethrow;
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
  /// ✅ FIX: Koristi VoznjeLogService direktno za tačne statistike
  static Future<Map<String, dynamic>?> generateAutomaticReport(
    String vozac,
    DateTime targetDate,
  ) async {
    try {
      // 🚫 PRESKAČI VIKENDE - ne radi se subotom i nedeljom
      if (targetDate.weekday == 6 || targetDate.weekday == 7) {
        return null;
      }

      // 1. OSNOVNI PODACI ZA CILJANI DATUM
      final dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final dayEnd = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

      // 2. ✅ DIREKTNE STATISTIKE IZ VOZNJE_LOG - tačni podaci
      final stats = await VoznjeLogService.getStatistikePoVozacu(
        vozacIme: vozac,
        datum: targetDate,
      );

      final pokupljeniPutnici = stats['voznje'] as int? ?? 0;
      final otkazaniPutnici = stats['otkazivanja'] as int? ?? 0;
      final mesecneKarte = stats['uplate'] as int? ?? 0;
      final ukupanPazar = stats['pazar'] as double? ?? 0.0;

      // 3. SITAN NOVAC - UČITAJ RUČNO UNET KUSUR
      double sitanNovac;
      try {
        sitanNovac = await getTodayAmount(vozac) ?? 0.0;
      } catch (e) {
        sitanNovac = 0.0;
      }

      // 4. KILOMETRAŽA
      double kilometraza;
      try {
        kilometraza = await StatistikaService.instance.getKilometrazu(vozac, dayStart, dayEnd);
      } catch (e) {
        kilometraza = 0.0;
      }

      // 5. DUŽNICI - dnevni putnici koji su pokupljeni ali nisu platili
      final dugoviPutnici = await VoznjeLogService.getBrojDuznikaPoVozacu(
        vozacIme: vozac,
        datum: targetDate,
      );

      // 6. KREIRAJ POPIS OBJEKAT
      final automatskiPopis = {
        'vozac': vozac,
        'datum': targetDate.toIso8601String(),
        'ukupanPazar': ukupanPazar,
        'sitanNovac': sitanNovac,
        'otkazaniPutnici': otkazaniPutnici,
        'naplaceniPutnici': mesecneKarte,
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
      await supabase.from('daily_reports').upsert(
        {
          'vozac': vozac,
          'datum': datum.toIso8601String().split('T')[0],
          'ukupan_pazar': popisPodaci['ukupanPazar'] ?? 0.0,
          'sitan_novac': popisPodaci['sitanNovac'] ?? 0.0,
          'checkin_vreme': DateTime.now().toIso8601String(),
          'otkazani_putnici': popisPodaci['otkazaniPutnici'] ?? 0,
          'naplaceni_putnici': popisPodaci['naplaceniPutnici'] ?? 0,
          'pokupljeni_putnici': popisPodaci['pokupljeniPutnici'] ?? 0,
          'dugovi_putnici': popisPodaci['dugoviPutnici'] ?? 0,
          'mesecne_karte': popisPodaci['mesecneKarte'] ?? 0,
          'kilometraza': popisPodaci['kilometraza'] ?? 0.0,
          'automatski_generisan': popisPodaci['automatskiGenerisan'] ?? true,
          'created_at': datum.toIso8601String(),
        },
        onConflict: 'vozac,datum', // 🎯 Ključno za upsert - sprečava duplikate!
      );
    } catch (e) {
      rethrow;
    }
  }
}
