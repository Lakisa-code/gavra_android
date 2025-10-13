import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'putnik_service.dart';
import 'realtime_service.dart';
import 'statistika_service.dart';

class DailyCheckInService {
  static const String _checkInPrefix = 'daily_checkin_';
  // Stream controller za real-time ažuriranje kocke
  static final StreamController<double> _sitanNovacController = StreamController<double>.broadcast();

  /// Stream za real-time ažuriranje sitnog novca u UI
  static Stream<double> streamTodayAmount(String vozac) {
    // Odmah pošalji trenutnu vrednost (remote-first)
    getTodayAmountRemote(vozac).then((amount) {
      if (!_sitanNovacController.isClosed) {
        _sitanNovacController.add(amount ?? 0.0);
      }
    });
    return _sitanNovacController.stream;
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
    // Daily checkins functionality removed - return 0.0
    return 0.0;
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
    try {
      // Sačuvaj u Supabase (ako postoji tabela)
      final savedRow = await _saveToSupabase(
        vozac,
        sitanNovac,
        today,
        dnevniPazari: dnevniPazari,
      );
      // Ako smo dobili potvrdu sa servera, emituj vrednost iz servera
      if (savedRow != null) {
        final serverVal = savedRow['kusur_iznos'];
        double emitVal = 0.0;
        if (serverVal is num) emitVal = serverVal.toDouble();
        if (serverVal is String) emitVal = double.tryParse(serverVal) ?? 0.0;
        if (!_sitanNovacController.isClosed) {
          _sitanNovacController.add(emitVal);
        }
      }
    } catch (e) {
      // Ako je RLS blokirao ili tabela ne postoji, nastavi sa lokalnim čuvanjem
      // Ne prosleđuj grešku dalje - lokalno čuvanje je dovoljno
    }
    try {
      // Sačuvaj lokalno u SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(todayKey, true);
      await prefs.setDouble('${todayKey}_amount', sitanNovac);
      await prefs.setDouble('${todayKey}_pazari', dnevniPazari);
      await prefs.setString('${todayKey}_timestamp', today.toIso8601String());
      // 🔄 Ako remote nije potvrdio ranije, emitujemo lokalnu vrednost
      if (!_sitanNovacController.isClosed) {
        _sitanNovacController.add(sitanNovac);
      }
    } catch (e) {
      // Ovo je ozbiljna greška - lokalno čuvanje mora da radi
      rethrow; // Proslijedi grešku jer je kritična
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
            'kusur_iznos': sitanNovac,
            'dnevni_pazari': dnevniPazari,
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
              'kusur_iznos': sitanNovac,
              'dnevni_pazari': dnevniPazari,
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
      // Filtriraj putnice za ciljani datum i vozača
      final putnicZaDatum = putnici.where((putnik) {
        // Proveri datum
        final datum = putnik.vremeDodavanja ?? putnik.vremePokupljenja;
        final datumOk = datum != null &&
            datum.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
            datum.isBefore(dayEnd.add(const Duration(seconds: 1)));
        // Proveri vozača
        final vozacOk = putnik.vozac == vozac;
        return datumOk && vozacOk;
      }).toList();
      // 3. KALKULACIJE - ISTE KAO U _showPopisDana()
      double ukupanPazar = 0.0;
      double sitanNovac = 0.0;
      int dodatiPutnici = putnicZaDatum.length;
      int otkazaniPutnici = 0;
      int naplaceniPutnici = 0;
      int pokupljeniPutnici = 0;
      int dugoviPutnici = 0;
      int mesecneKarte = 0;
      double kilometraza = 0.0;
      // Obradi putnice
      for (final putnik in putnicZaDatum) {
        // Status analize
        if (putnik.jeOtkazan) {
          otkazaniPutnici++;
        } else if (putnik.jePokupljen) {
          pokupljeniPutnici++;
          ukupanPazar += putnik.iznosPlacanja ?? 0.0;
        }
        if (putnik.jePlacen) {
          naplaceniPutnici++;
          ukupanPazar += putnik.iznosPlacanja ?? 0.0;
        }
        // Dugovi (nisu naplaćeni a nisu otkazani)
        if (!putnik.jePlacen && !putnik.jeOtkazan && !putnik.jePokupljen) {
          dugoviPutnici++;
        }
        // Mesečne karte
        if (putnik.mesecnaKarta == true) {
          mesecneKarte++;
        }
      }
      // 4. SITAN NOVAC (procena 10% od ukupnog pazara)
      sitanNovac = ukupanPazar * 0.1;
      // 5. KILOMETRAŽA (REALTIME GPS CALCULATION)
      try {
        kilometraza = await StatistikaService.getKilometrazu(vozac, dayStart, dayEnd);
      } catch (e) {
        kilometraza = 0.0; // Fallback na 0 umesto dummy vrednost
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
