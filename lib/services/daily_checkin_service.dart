import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dnevni_kusur_service.dart';
import 'putnik_service.dart';
import 'realtime_service.dart';
import 'simplified_kusur_service.dart';
import 'statistika_service.dart';

class DailyCheckInService {
  static const String _checkInPrefix = 'daily_checkin_';
  // Stream controller za real-time ažuriranje kocke
  static final StreamController<double> _sitanNovacController = StreamController<double>.broadcast();

  /// Stream za real-time ažuriranje sitnog novca u UI
  static Stream<double> streamTodayAmount(String vozac) {
    // ✅ FIX: Koristi direktan SimplifiedKusurService stream za realtime ažuriranje
    return SimplifiedKusurService.streamKusurForVozac(vozac).map((kusurFromBaza) {
      // Ako nema kusura u bazi, pokušaj SharedPreferences kao fallback
      if (kusurFromBaza > 0) {
        return kusurFromBaza;
      } else {
        // Async fallback - pozovi getTodayAmount ali vrati trenutnu vrednost
        getTodayAmount(vozac).then((localAmount) {
          if (localAmount != null && localAmount > 0) {
            if (!_sitanNovacController.isClosed) {
              _sitanNovacController.add(localAmount);
            }
          }
        });
        return kusurFromBaza; // Vrati vrednost iz baze (možda 0)
      }
    });
  }

  /// Helper: Dobij kusur iz oba izvora - prioritet ima KusurService
  static Future<double> getAmountFromBothSources(String vozac) async {
    try {
      // 1. Pokušaj SimplifiedKusurService (baza) - prioritet
      final kusurFromBaza = await SimplifiedKusurService.getKusurForVozac(vozac);
      if (kusurFromBaza > 0) return kusurFromBaza;
    } catch (e) {
      // Ignoriši grešku KusurService
    }

    // 2. Fallback na SharedPreferences
    final localAmount = await getTodayAmount(vozac);
    return localAmount ?? 0.0;
  }

  /// Inicijalizuj realtime stream za vozača tako da kocka prati bazu
  static StreamSubscription<dynamic> initializeRealtimeForDriver(String vozac) {
    // Start centralized realtime subscriptions for this driver
    try {
      RealtimeService.instance.startForDriver(vozac);
    } catch (e) {
      // RealtimeService.startForDriver failed
    }
    // Return a dummy subscription since daily_checkins functionality is removed
    // ignore: prefer_const_constructors
    return Stream<dynamic>.empty().listen((_) {});
  }

  /// Zaustavi centralizovane realtime pretplate za vozača
  static Future<void> stopRealtimeForDriver() async {
    try {
      await RealtimeService.instance.stopForDriver();
    } catch (e) {
      // stopRealtimeForDriver failed
    }
  }

  /// Pokušaj prvo pročitati vrednost iz Supabase; fallback na SharedPreferences
  static Future<double?> getTodayAmountRemote(String vozac) async {
    // Čitaj iz SharedPreferences umesto da vraćaš 0.0
    return await getTodayAmount(vozac);
  }

  /// Proveri da li je vozač već uradio check-in danas
  static Future<bool> hasCheckedInToday(String vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '$_checkInPrefix${vozac}_${today.year}_${today.month}_${today.day}';
    return prefs.getBool(todayKey) ?? false;
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
    try {
      final currentHour = today.hour;

      // Kusur se može uneti samo u jutarnjim satima (5:00 - 12:00) ili uveče (20:00 - 23:00)
      if ((currentHour >= 5 && currentHour <= 12) || (currentHour >= 20 && currentHour <= 23)) {
        // Koristi novi DnevniKusurService
        await DnevniKusurService.unesiJutarnjiKusur(vozac, sitanNovac);
      }
    } catch (e) {
      // Nastavi sa lokalnim čuvanjem čak i ako baza ne radi
    } // 📥 LOKALNO ČUVANJE - prioritet jer je brže i pouzdanije
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

    // 🌐 REMOTE ČUVANJE - asinhrono u pozadini sa timeout-om
    // HITNO ONEMOGUĆENO
    // try {
    //   await _saveToSupabase(vozac, sitanNovac, today, dnevniPazari: dnevniPazari).timeout(const Duration(seconds: 5));
    // } catch (e) {
    //   // Ako remote save ne uspe, ali lokalna je OK, nastavi dalje
    // }
  }

  /// 🚨 EMERGENCY LOCAL SAVE - kada se sve ostalo zaglavi!
  static Future<void> saveLokalno(
    String vozac,
    double sitanNovac, {
    double dnevniPazari = 0.0,
  }) async {
    final today = DateTime.now();
    final todayKey = '$_checkInPrefix${vozac}_${today.year}_${today.month}_${today.day}';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(todayKey, true);
    await prefs.setDouble('${todayKey}_amount', sitanNovac);
    await prefs.setDouble('${todayKey}_pazari', dnevniPazari);
    await prefs.setString('${todayKey}_timestamp', today.toIso8601String());

    // Emituj update za stream
    if (!_sitanNovacController.isClosed) {
      _sitanNovacController.add(sitanNovac);
    }
  }

  /// Dohvati iznos za danas
  static Future<double?> getTodayAmount(String vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '$_checkInPrefix${vozac}_${today.year}_${today.month}_${today.day}';
    return prefs.getDouble('${todayKey}_amount');
  }

  /// Dohvati dnevne pazare za danas
  static Future<double?> getTodayPazari(String vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '$_checkInPrefix${vozac}_${today.year}_${today.month}_${today.day}';
    return prefs.getDouble('${todayKey}_pazari');
  }

  /// Dohvati kompletne podatke za danas (kusur + pazari)
  static Future<Map<String, double?>> getTodayData(String vozac) async {
    final kusur = await getTodayAmount(vozac);
    final pazari = await getTodayPazari(vozac);
    return {
      'kusur': kusur,
      'pazari': pazari,
    };
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
  // HITNO ONEMOGUĆENO - može blokirati UI
  /*
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
  */

  /// Kreiraj tabelu daily_checkins ako ne postoji
  // HITNO ONEMOGUĆENO
  /*
  static Future<void> _createDailyCheckinsTable() async {
    try {
      final supabase = Supabase.instance.client;
      // Pokušaj kreiranje preko RPC ako postoji
      await supabase.rpc<void>('create_daily_checins_table_if_not_exists');
    } catch (e) {
      // Ne bacaj grešku jer tabela možda postoji ali RPC ne radi
    }
  }
  */

  /// 🛠️ FORSIRAJ KREIRANJE TABELE - za ekstremne slučajeve
  static Future<bool> forceCreateTable() async {
    try {
      final supabase = Supabase.instance.client;

      // 1. Test da li tabela postoji
      try {
        await supabase.from('daily_checkins').select('id').limit(1);
        return true; // Tabela već postoji
      } catch (e) {
        // Tabela ne postoji, nastavi sa kreiranjem
      }

      // 2. Pokušaj RPC kreiranje
      try {
        await supabase.rpc<void>('create_daily_checkins_table_if_not_exists');

        // Test ponovo
        await Future<void>.delayed(const Duration(seconds: 2));
        await supabase.from('daily_checkins').select('id').limit(1);
        return true;
      } catch (e) {
        // RPC neuspešan
      }

      // 3. Pokušaj direktno SQL preko exec_sql
      try {
        const sqlCreate = '''
          CREATE TABLE IF NOT EXISTS public.daily_checkins (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            vozac TEXT NOT NULL,
            datum DATE NOT NULL,
            sitan_novac DECIMAL(10,2) DEFAULT 0.0,
            dnevni_pazari DECIMAL(10,2) DEFAULT 0.0,
            ukupno DECIMAL(10,2) DEFAULT 0.0,
            checkin_vreme TIMESTAMPTZ DEFAULT now(),
            created_at TIMESTAMPTZ DEFAULT now(),
            updated_at TIMESTAMPTZ DEFAULT now(),
            UNIQUE(vozac, datum)
          );
          
          CREATE INDEX IF NOT EXISTS idx_daily_checkins_vozac ON public.daily_checkins(vozac);
          CREATE INDEX IF NOT EXISTS idx_daily_checkins_datum ON public.daily_checkins(datum);
          
          ALTER TABLE public.daily_checkins ENABLE ROW LEVEL SECURITY;
          
          DROP POLICY IF EXISTS "daily_checkins_read_policy" ON public.daily_checkins;
          CREATE POLICY "daily_checkins_read_policy" ON public.daily_checkins FOR SELECT TO authenticated USING (true);
          
          DROP POLICY IF EXISTS "daily_checkins_insert_policy" ON public.daily_checkins;
          CREATE POLICY "daily_checkins_insert_policy" ON public.daily_checkins FOR INSERT TO authenticated WITH CHECK (true);
          
          DROP POLICY IF EXISTS "daily_checkins_update_policy" ON public.daily_checkins;
          CREATE POLICY "daily_checkins_update_policy" ON public.daily_checkins FOR UPDATE TO authenticated USING (true);
          
          GRANT SELECT, INSERT, UPDATE, DELETE ON public.daily_checkins TO authenticated;
        ''';

        await supabase.rpc<void>('exec_sql', params: {'query': sqlCreate});

        // Test ponovo
        await Future<void>.delayed(const Duration(seconds: 2));
        await supabase.from('daily_checkins').select('id').limit(1);
        return true;
      } catch (e) {
        // SQL neuspešan
      }

      return false; // Sve je neuspešno
    } catch (e) {
      return false;
    }
  }

  /// Dohvati istoriju check-in-ova za vozača
  static Future<List<Map<String, dynamic>>> getCheckInHistory(
    String vozac, {
    int days = 7,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> history = [];
    final today = DateTime.now();
    for (int i = 0; i < days; i++) {
      final date = today.subtract(Duration(days: i));
      final dateKey = '$_checkInPrefix${vozac}_${date.year}_${date.month}_${date.day}';
      final hasCheckedIn = prefs.getBool(dateKey) ?? false;
      if (hasCheckedIn) {
        final amount = prefs.getDouble('${dateKey}_amount') ?? 0.0;
        final timestampStr = prefs.getString('${dateKey}_timestamp');
        history.add({
          'datum': date,
          'iznos': amount,
          'timestamp': timestampStr != null ? DateTime.parse(timestampStr) : date,
        });
      }
    }
    return history;
  }

  /// Reset check-in za testiranje
  static Future<void> resetCheckInForToday(String vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '$_checkInPrefix${vozac}_${today.year}_${today.month}_${today.day}';
    await prefs.remove(todayKey);
    await prefs.remove('${todayKey}_amount');
    await prefs.remove('${todayKey}_timestamp');
    await prefs.remove('${todayKey}_popis'); // 📊 NOVI: Ukloni i popis
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
    } catch (e) {}
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

  /// 📊 NOVI: Proveri da li treba prikazati popis iz prethodnog dana
  static Future<bool> shouldShowPreviousDayReport(String vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayKey = '$_checkInPrefix${vozac}_${yesterday.year}_${yesterday.month}_${yesterday.day}';
    final todayKey = '$_checkInPrefix${vozac}_${today.year}_${today.month}_${today.day}';
    // Ako je juče imao popis, a danas se prvi put uloguje
    final hadReportYesterday = prefs.getString('${yesterdayKey}_popis') != null;
    final checkedInToday = prefs.getBool(todayKey) ?? false;
    return hadReportYesterday && !checkedInToday;
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
        ukupanPazar = await StatistikaService.streamPazarSvihVozaca(
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
        sitanNovac = await getAmountFromBothSources(vozac);
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
