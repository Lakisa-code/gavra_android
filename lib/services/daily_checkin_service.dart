import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// import 'dnevni_kusur_service.dart';
import 'putnik_service.dart';
import 'realtime_hub_service.dart';
// import 'simplified_kusur_service.dart';
import 'statistika_service.dart';

class DailyCheckInService {
  static const String _checkInPrefix = 'daily_checkin_';
  // Stream controller za real-time ažuriranje kocke
  static final StreamController<double> _sitanNovacController = StreamController<double>.broadcast();

  /// Stream za real-time ažuriranje kusura
  static Stream<double> streamTodayAmount(String vozac) {
    return RealtimeHubService.instance.streamKusurZaVozaca(vozac);
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
    // Supabase realtime se koristi direktno gde je potrebno
    // Return a dummy subscription since daily_checkins functionality is removed
    // ignore: prefer_const_constructors
    return Stream<dynamic>.empty().listen((_) {});
  }

  /// Proveri da li je vozač već uradio check-in danas
  /// Proverava LOKALNO I SUPABASE - za sinhronizaciju između uređaja!
  static Future<bool> hasCheckedInToday(String vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '$_checkInPrefix${vozac}_${today.year}_${today.month}_${today.day}';

    // 1. Prvo proveri lokalno
    final localCheckedIn = prefs.getBool(todayKey) ?? false;
    if (localCheckedIn) {
      return true;
    }

    // 2. Ako lokalno nema, proveri Supabase (za drugi uređaj)
    try {
      final supabase = Supabase.instance.client;
      final todayStr = today.toIso8601String().split('T')[0]; // YYYY-MM-DD

      final response = await supabase
          .from('daily_checkins')
          .select('sitan_novac, dnevni_pazari')
          .eq('vozac', vozac)
          .eq('datum', todayStr)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));

      if (response != null) {
        // 🔄 SINHRONIZUJ lokalno sa Supabase podacima!
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

        return true;
      }
    } catch (e) {
      // Supabase nije dostupan - nastavi sa lokalnom proverom
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

    if (alreadyChecked) {
      // Već je uneo kusur danas - samo ažuriraj lokalnu vrednost
      await prefs.setDouble('${todayKey}_amount', sitanNovac);
      if (!_sitanNovacController.isClosed) {
        _sitanNovacController.add(sitanNovac);
      }
      return;
    }

    // 🌅 PRVI PUT DANAS - sačuvaj kusur koji vozač ima za smenu
    // ❌ DEPRECATED: Use MasterRealtimeStream instead
    // try {
    //   await DnevniKusurService.unesiJutarnjiKusur(vozac, sitanNovac);
    // } catch (e) {
    //   // Nastavi sa lokalnim čuvanjem čak i ako baza ne radi
    // }
    // 📥 LOKALNO ČUVANJE - prioritet jer je brže i pouzdanije
    try {
      await prefs.setBool(todayKey, true);
      await prefs.setDouble('${todayKey}_amount', sitanNovac);
      await prefs.setDouble('${todayKey}_pazari', dnevniPazari);
      await prefs.setString('${todayKey}_timestamp', today.toIso8601String());

      // Emituj update za stream
      if (!_sitanNovacController.isClosed) {
        _sitanNovacController.add(sitanNovac);
      }
    } catch (e) {
      // Ovo je kritična greška - lokalno čuvanje mora da radi
      rethrow;
    }

    // 🌐 REMOTE ČUVANJE
    try {
      await _saveToSupabase(vozac, sitanNovac, today, dnevniPazari: dnevniPazari).timeout(const Duration(seconds: 5));
      // Ažuriraj kusur u vozaci tabeli
      await Supabase.instance.client.from('vozaci').update({'kusur': sitanNovac}).eq('ime', vozac);
    } catch (e) {
      // Ako remote save ne uspe, ali lokalna je OK, nastavi dalje
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
      // Prvo pokušaj da sačuvaš u tabelu
      final response = await supabase
          .from('daily_checkins')
          .upsert({
            'vozac': vozac,
            'datum': datum.toIso8601String().split('T')[0], // YYYY-MM-DD format
            'sitan_novac': sitanNovac,
            'dnevni_pazari': dnevniPazari,
            'ukupno': sitanNovac + dnevniPazari,
            'checkin_vreme': DateTime.now().toIso8601String(),
            'created_at': datum.toIso8601String(),
          })
          .select()
          .maybeSingle();

      // Vrati eventualno sačuvani red kako bi pozivalac mogao da koristi potvrđene vrednosti
      if (response is Map<String, dynamic>) return response;
      return null;
    } on PostgrestException catch (e) {
      // Ako je tabela missing, pokušaj da je kreiraš
      if (e.code == 'PGRST106' || e.message.contains('does not exist') || e.code == '404') {
        await _createDailyCheckinsTable();
        // Ponovi pokušaj čuvanja nakon kreiranja tabele
        final response = await supabase
            .from('daily_checkins')
            .upsert({
              'vozac': vozac,
              'datum': datum.toIso8601String().split('T')[0],
              'sitan_novac': sitanNovac,
              'dnevni_pazari': dnevniPazari,
              'ukupno': sitanNovac + dnevniPazari,
              'checkin_vreme': DateTime.now().toIso8601String(),
              'created_at': datum.toIso8601String(),
            })
            .select()
            .maybeSingle();

        if (response is Map<String, dynamic>) return response;
        return null;
      } else {
        rethrow; // Proslijedi dalju grešku
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Kreiraj tabelu daily_checkins ako ne postoji
  static Future<void> _createDailyCheckinsTable() async {
    try {
      final supabase = Supabase.instance.client;
      // Pokušaj kreiranje preko RPC ako postoji
      await supabase.rpc<void>('create_daily_checkins_table_if_not_exists');
    } catch (e) {
      // Ne bacaj grešku jer tabela možda postoji ali RPC ne radi
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
      // Silently ignore - fallback to SharedPreferences
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
    // Proverava poslednja 7 dana
    for (int i = 1; i <= 7; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final dateKey = '$_checkInPrefix${vozac}_${checkDate.year}_${checkDate.month}_${checkDate.day}';
      final popisString = prefs.getString('${dateKey}_popis');
      if (popisString != null) {
        // Parsiraj JSON nazad u Map<String, dynamic>
        try {
          final decoded = jsonDecode(popisString) as Map<String, dynamic>;
          return {
            'datum': checkDate,
            'popis': decoded,
          };
        } catch (e) {
          // Ako parsing padne, vrati raw string kao fallback
          return {
            'datum': checkDate,
            'popis': popisString,
          };
        }
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
      // Uvoz potrebnih servisa
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
        ukupanPazar = 0.0; // Fallback vrednost
      }

      // 6. MAPIRANJE PODATAKA - IDENTIČNO SA STATISTIKA SCREEN
      final dodatiPutnici = (vozacStats['dodati'] ?? 0) as int;
      final otkazaniPutnici = (vozacStats['otkazani'] ?? 0) as int;
      final naplaceniPutnici = (vozacStats['naplaceni'] ?? 0) as int;
      final pokupljeniPutnici = (vozacStats['pokupljeni'] ?? 0) as int;
      final dugoviPutnici = (vozacStats['dugovi'] ?? 0) as int;
      final mesecneKarte = (vozacStats['mesecneKarte'] ?? 0) as int;

      // 5. SITAN NOVAC - UČITAJ RUČNO UNET KUSUR (ne kalkuliši automatski)
      double sitanNovac;
      try {
        // Pokušaj da učitaš ručno unet kusur za taj dan
        sitanNovac = await getTodayAmount(vozac) ?? 0.0;
      } catch (e) {
        sitanNovac = 0.0; // Fallback ako nema unetog kusura
      }
      // 🚗 REALTIME GPS KILOMETRAŽA - IDENTIČNO SA _showPopisDana()
      double kilometraza;
      try {
        kilometraza = await StatistikaService.instance.getKilometrazu(vozac, dayStart, dayEnd);
      } catch (e) {
        kilometraza = 0.0; // Fallback vrednost
      }
      // 6. KREIRAJ POPIS OBJEKAT
      final automatskiPopis = {
        'vozac': vozac,
        'datum': targetDate.toIso8601String(),
        'ukupanPazar': ukupanPazar,
        'sitanNovac': sitanNovac,
        'dodatiPutnici': dodatiPutnici,
        'otkazaniPutnici': otkazaniPutnici,
        'naplaceniPutnici': naplaceniPutnici,
        'pokupljeniPutnici': pokupljeniPutnici,
        'dugoviPutnici': dugoviPutnici,
        'mesecneKarte': mesecneKarte,
        'kilometraza': kilometraza,
        'automatskiGenerisal': true, // Marker da je automatski
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
        'dodati_putnici': popisPodaci['dodatiPutnici'] ?? 0,
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
      // Tabela daily_reports možda ne postoji - potrebno je kreirati ručno
      rethrow;
    }
  }
}
