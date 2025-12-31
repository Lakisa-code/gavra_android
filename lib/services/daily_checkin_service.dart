import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'putnik_service.dart';
import 'realtime/realtime_manager.dart';
import 'statistika_service.dart';

class DailyCheckInService {
  static const String _checkInPrefix = 'daily_checkin_';
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

  /// Initialize stream with current value from SharedPreferences
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
  /// Proverava LOKALNO I SUPABASE - za sinhronizaciju između uređaja!
  /// 🔧 POBOLJŠANO: Povećan timeout, retry logika, bolje logovanje
  static Future<bool> hasCheckedInToday(String vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '$_checkInPrefix${vozac}_${today.year}_${today.month}_${today.day}';

    // 1️⃣ PRVO: Proveri lokalno
    final localCheckedIn = prefs.getBool(todayKey) ?? false;
    if (localCheckedIn) {
      return true;
    }

    // 2️⃣ DRUGO: Proveri Supabase bazu (sa retry logikom)
    final todayStr = today.toIso8601String().split('T')[0]; // YYYY-MM-DD

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final supabase = Supabase.instance.client;

        final response = await supabase
            .from('daily_checkins')
            .select('sitan_novac, dnevni_pazari, checkin_vreme')
            .eq('vozac', vozac)
            .eq('datum', todayStr)
            .maybeSingle()
            .timeout(const Duration(seconds: 6)); // 🔧 Povećan timeout sa 3s na 6s

        if (response != null) {
          // ✅ VOZAČ JE VEĆ URADIO CHECK-IN SA DRUGOG UREĐAJA!
          // 🔄 Sinhronizuj lokalno sa Supabase podacima
          final sitanNovac = (response['sitan_novac'] as num?)?.toDouble() ?? 0.0;
          final dnevniPazari = (response['dnevni_pazari'] as num?)?.toDouble() ?? 0.0;

          await prefs.setBool(todayKey, true);
          await prefs.setDouble('${todayKey}_amount', sitanNovac);
          await prefs.setDouble('${todayKey}_pazari', dnevniPazari);
          await prefs.setString('${todayKey}_timestamp', today.toIso8601String());

          // Emituj update za stream
          if (!_sitanNovacController.isClosed) {
            _sitanNovacController.add(sitanNovac);
          }

          // Ažuriraj i kusur controller ako postoji
          if (_kusurControllers.containsKey(vozac) && !_kusurControllers[vozac]!.isClosed) {
            _kusurControllers[vozac]!.add(sitanNovac);
          }

          print(
              '✅ [DailyCheckIn] Vozač $vozac već uradio check-in danas (kusur: $sitanNovac) - sinhronizovano sa drugog uređaja');
          return true;
        }

        // Ako nema zapisa, vozač nije uradio check-in
        break;
      } catch (e) {
        print('⚠️ [DailyCheckIn] Pokušaj $attempt/2 - Greška pri proveri Supabase: $e');
        if (attempt < 2) {
          // Sačekaj pre retry-a
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
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
    final todayKey = '$_checkInPrefix${vozac}_${today.year}_${today.month}_${today.day}';

    // 🚫 JEDNOSTAVNA VALIDACIJA - vozač može uneti kusur samo jednom dnevno
    final prefs = await SharedPreferences.getInstance();
    final alreadyChecked = prefs.getBool(todayKey) ?? false;

    // 📥 LOKALNO ČUVANJE - UVEK (i prvi put i ako je već čekiran)
    try {
      await prefs.setBool(todayKey, true);
      await prefs.setDouble('${todayKey}_amount', sitanNovac);
      await prefs.setDouble('${todayKey}_pazari', dnevniPazari);
      await prefs.setString('${todayKey}_timestamp', today.toIso8601String());

      if (!_sitanNovacController.isClosed) {
        _sitanNovacController.add(sitanNovac);
      }
    } catch (e) {
      rethrow;
    }

    // 🛑 Ako je već čekiran danas, ne čuvaj ponovo u bazu (samo lokalno)
    if (alreadyChecked) {
      return;
    }

    // 🌐 REMOTE ČUVANJE - samo prvi put danas
    try {
      await _saveToSupabase(vozac, sitanNovac, today, dnevniPazari: dnevniPazari).timeout(const Duration(seconds: 5));
      // Ažuriraj kusur u vozaci tabeli
      await Supabase.instance.client.from('vozaci').update({'kusur': sitanNovac}).eq('ime', vozac);
    } catch (e) {
      print('❌ DailyCheckInService: Greška pri čuvanju u Supabase: $e');
    }
  }

  /// Dohvati iznos za danas
  static Future<double?> getTodayAmount(String vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '$_checkInPrefix${vozac}_${today.year}_${today.month}_${today.day}';
    return prefs.getDouble('${todayKey}_amount');
  }

  /// Dohvati kompletne podatke za danas kao Map<String, dynamic> (za kompatibilnost)
  static Future<Map<String, dynamic>> getTodayCheckIn(String vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '$_checkInPrefix${vozac}_${today.year}_${today.month}_${today.day}';

    final sitanNovac = prefs.getDouble('${todayKey}_amount') ?? 0.0;
    final dnevniPazari = prefs.getDouble('${todayKey}_pazari') ?? 0.0;
    final hasCheckedIn = prefs.getBool(todayKey) ?? false;
    final timestampStr = prefs.getString('${todayKey}_timestamp');

    return {
      'sitan_novac': sitanNovac,
      'dnevni_pazari': dnevniPazari,
      'has_checked_in': hasCheckedIn,
      'timestamp': timestampStr != null ? DateTime.parse(timestampStr) : null,
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

  /// 📊 NOVI: Sačuvaj kompletan dnevni popis
  static Future<void> saveDailyReport(
    String vozac,
    DateTime datum,
    Map<String, dynamic> popisPodaci,
  ) async {
    final dateKey = '$_checkInPrefix${vozac}_${datum.year}_${datum.month}_${datum.day}';
    try {
      // Sačuvaj u Supabase (ako postoji tabela)
      await _savePopisToSupabase(vozac, popisPodaci, datum);
    } catch (e) {
      // 🔇 Ignore
    }
    // Sačuvaj lokalno u SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    // Sačuvaj `popis` kao JSON string da bismo ga kasnije pouzdano parsirali
    final popisJsonString = jsonEncode(popisPodaci);
    await prefs.setString('${dateKey}_popis', popisJsonString);
    await prefs.setString(
      '${dateKey}_popis_timestamp',
      datum.toIso8601String(),
    );
  }

  /// 📊 NOVI: Dohvati poslednji popis za vozača
  static Future<Map<String, dynamic>?> getLastDailyReport(String vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    for (int i = 1; i <= 7; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final dateKey = '$_checkInPrefix${vozac}_${checkDate.year}_${checkDate.month}_${checkDate.day}';
      final popisString = prefs.getString('${dateKey}_popis');
      if (popisString != null) {
        try {
          final decoded = jsonDecode(popisString) as Map<String, dynamic>;
          return {
            'datum': checkDate,
            'popis': decoded,
          };
        } catch (e) {
          return {
            'datum': checkDate,
            'popis': popisString,
          };
        }
      }
    }
    return null;
  }

  /// 📊 NOVI: Dohvati popis za specifičan datum
  static Future<Map<String, dynamic>?> getDailyReportForDate(String vozac, DateTime datum) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = '$_checkInPrefix${vozac}_${datum.year}_${datum.month}_${datum.day}';
    final popisString = prefs.getString('${dateKey}_popis');
    if (popisString != null) {
      try {
        final decoded = jsonDecode(popisString) as Map<String, dynamic>;
        return {
          'datum': datum,
          'popis': decoded,
        };
      } catch (e) {
        return {
          'datum': datum,
          'popis': popisString,
        };
      }
    }
    return null;
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
      // 6. KREIRAJ POPIS OBJEKAT
      final automatskiPopis = {
        'vozac': vozac,
        'datum': targetDate.toIso8601String(),
        'ukupanPazar': ukupanPazar,
        'sitanNovac': sitanNovac,
        'otkazaniPutnici': otkazaniPutnici,
        'pokupljeniPutnici': pokupljeniPutnici,
        'dugoviPutnici': dugoviPutnici,
        'mesecneKarte': mesecneKarte,
        'kilometraza': kilometraza,
        'automatskiGenerisal': true,
        'timestamp': DateTime.now().toIso8601String(),
      };
      // 7. SAČUVAJ AUTOMATSKI POPIS
      await saveDailyReport(vozac, targetDate, automatskiPopis);
      return automatskiPopis;
    } catch (e) {
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
        'automatski_generisan': popisPodaci['automatskiGenerisal'] ?? true,
        'created_at': datum.toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }
}
