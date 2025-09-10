import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'putnik_service.dart';
import 'statistika_service.dart';

class DailyCheckInService {
  static const String _checkInPrefix = 'daily_checkin_';

  // Stream controller za real-time ažuriranje kocke
  static final StreamController<double> _sitanNovacController =
      StreamController<double>.broadcast();

  /// Stream za real-time ažuriranje sitnog novca u UI
  static Stream<double> streamTodayAmount(String vozac) {
    // Odmah pošalji trenutnu vrednost
    getTodayAmount(vozac).then((amount) {
      if (!_sitanNovacController.isClosed) {
        _sitanNovacController.add(amount ?? 0.0);
      }
    });

    return _sitanNovacController.stream;
  }

  /// Proveri da li je vozač već uradio check-in danas
  static Future<bool> hasCheckedInToday(String vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey =
        '${_checkInPrefix}${vozac}_${today.year}_${today.month}_${today.day}';

    return prefs.getBool(todayKey) ?? false;
  }

  /// Sačuvaj daily check-in (sitan novac)
  static Future<void> saveCheckIn(String vozac, double sitanNovac) async {
    final today = DateTime.now();
    final todayKey =
        '${_checkInPrefix}${vozac}_${today.year}_${today.month}_${today.day}';

    try {
      // Sačuvaj u Supabase (ako postoji tabela)
      await _saveToSupabase(vozac, sitanNovac, today);
    } catch (e) {
      // Ako nema tabele, samo nastavi sa lokalnim čuvanjem
      print('Supabase save failed (možda tabela ne postoji): $e');
    }

    // Sačuvaj lokalno u SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(todayKey, true);
    await prefs.setDouble('${todayKey}_amount', sitanNovac);
    await prefs.setString('${todayKey}_timestamp', today.toIso8601String());

    // 🔄 EMIT NOVI IZNOS NA STREAM ZA REAL-TIME UPDATE
    if (!_sitanNovacController.isClosed) {
      _sitanNovacController.add(sitanNovac);
    }
  }

  /// Dohvati iznos za danas
  static Future<double?> getTodayAmount(String vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey =
        '${_checkInPrefix}${vozac}_${today.year}_${today.month}_${today.day}';

    return prefs.getDouble('${todayKey}_amount');
  }

  /// Sačuvaj u Supabase (biće implementirano kada napravimo tabelu)
  static Future<void> _saveToSupabase(
      String vozac, double sitanNovac, DateTime datum) async {
    // Pokušaj da sačuva u tabelu daily_checkins
    final supabase = Supabase.instance.client;

    await supabase.from('daily_checkins').upsert({
      'vozac': vozac,
      'datum': datum.toIso8601String().split('T')[0], // YYYY-MM-DD format
      'kusur_iznos': sitanNovac,
      'created_at': datum.toIso8601String(),
    });
  }

  /// Dohvati istoriju check-in-ova za vozača
  static Future<List<Map<String, dynamic>>> getCheckInHistory(String vozac,
      {int days = 7}) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> history = [];

    final today = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date = today.subtract(Duration(days: i));
      final dateKey =
          '${_checkInPrefix}${vozac}_${date.year}_${date.month}_${date.day}';

      final hasCheckedIn = prefs.getBool(dateKey) ?? false;
      if (hasCheckedIn) {
        final amount = prefs.getDouble('${dateKey}_amount') ?? 0.0;
        final timestampStr = prefs.getString('${dateKey}_timestamp');

        history.add({
          'datum': date,
          'iznos': amount,
          'timestamp':
              timestampStr != null ? DateTime.parse(timestampStr) : date,
        });
      }
    }

    return history;
  }

  /// Reset check-in za testiranje
  static Future<void> resetCheckInForToday(String vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey =
        '${_checkInPrefix}${vozac}_${today.year}_${today.month}_${today.day}';

    await prefs.remove(todayKey);
    await prefs.remove('${todayKey}_amount');
    await prefs.remove('${todayKey}_timestamp');
    await prefs.remove('${todayKey}_popis'); // 📊 NOVI: Ukloni i popis
  }

  /// 📊 NOVI: Sačuvaj kompletan dnevni popis
  static Future<void> saveDailyReport(
      String vozac, DateTime datum, Map<String, dynamic> popisPodaci) async {
    final dateKey =
        '${_checkInPrefix}${vozac}_${datum.year}_${datum.month}_${datum.day}';

    try {
      // Sačuvaj u Supabase (ako postoji tabela)
      await _savePopisToSupabase(vozac, popisPodaci, datum);
    } catch (e) {
      print('Supabase save failed for popis: $e');
    }

    // Sačuvaj lokalno u SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final popisJson = Map<String, String>.from(
        popisPodaci.map((key, value) => MapEntry(key, value.toString())));

    await prefs.setString('${dateKey}_popis', popisJson.toString());
    await prefs.setString(
        '${dateKey}_popis_timestamp', datum.toIso8601String());

    print(
        '✅ Dnevni popis sačuvan za $vozac na dan ${datum.day}.${datum.month}.${datum.year}');
  }

  /// 📊 NOVI: Dohvati poslednji popis za vozača
  static Future<Map<String, dynamic>?> getLastDailyReport(String vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();

    // Proverava poslednja 7 dana
    for (int i = 1; i <= 7; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final dateKey =
          '${_checkInPrefix}${vozac}_${checkDate.year}_${checkDate.month}_${checkDate.day}';

      final popisString = prefs.getString('${dateKey}_popis');
      if (popisString != null) {
        // Parsiraj string nazad u Map
        // TODO: Dodati JSON parsing ako bude potrebno
        return {
          'datum': checkDate,
          'popis': popisString,
        };
      }
    }

    return null;
  }

  /// 📊 NOVI: Proveri da li treba prikazati popis iz prethodnog dana
  static Future<bool> shouldShowPreviousDayReport(String vozac) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    final yesterdayKey =
        '${_checkInPrefix}${vozac}_${yesterday.year}_${yesterday.month}_${yesterday.day}';
    final todayKey =
        '${_checkInPrefix}${vozac}_${today.year}_${today.month}_${today.day}';

    // Ako je juče imao popis, a danas se prvi put uloguje
    final hadReportYesterday = prefs.getString('${yesterdayKey}_popis') != null;
    final checkedInToday = prefs.getBool(todayKey) ?? false;

    return hadReportYesterday && !checkedInToday;
  }

  /// 📊 AUTOMATSKO GENERISANJE POPISA ZA PRETHODNI DAN
  static Future<Map<String, dynamic>?> generateAutomaticReport(
      String vozac, DateTime targetDate) async {
    try {
      // Uvoz potrebnih servisa
      final PutnikService putnikService = PutnikService();

      // 1. OSNOVNI PODACI ZA CILJANI DATUM
      final dayStart =
          DateTime(targetDate.year, targetDate.month, targetDate.day);
      final dayEnd = DateTime(
          targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

      // 2. KOMBINOVANI PUTNICI ZA DATUM (iz realtime)
      final putnici = await putnikService.streamKombinovaniPutnici().first;

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
        kilometraza =
            await StatistikaService.getKilometrazu(vozac, dayStart, dayEnd);
        print(
            '🚗 GPS kilometraža za $vozac za ${targetDate.day}.${targetDate.month}: ${kilometraza.toStringAsFixed(1)} km');
      } catch (e) {
        print('⚠️ Greška pri GPS računanju kilometraže: $e');
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
      print('Greška pri automatskom generisanju popisa: $e');
      return null;
    }
  }

  /// 📊 HELPER: Sačuvaj popis u Supabase
  static Future<void> _savePopisToSupabase(
      String vozac, Map<String, dynamic> popisPodaci, DateTime datum) async {
    final supabase = Supabase.instance.client;

    await supabase.from('daily_reports').upsert({
      'vozac': vozac,
      'datum': datum.toIso8601String().split('T')[0],
      'ukupan_pazar': popisPodaci['ukupanPazar'],
      'sitan_novac': popisPodaci['sitanNovac'],
      'broj_putnika': popisPodaci['brojPutnika'],
      'broj_naplacenih': popisPodaci['brojNaplacenih'],
      'broj_dugova': popisPodaci['brojDugova'],
      'kilometraza': popisPodaci['kilometraza'],
      'pazar_obicni': popisPodaci['pazarObicni'],
      'pazar_mesecne': popisPodaci['pazarMesecne'],
      'created_at': datum.toIso8601String(),
    });
  }
}
