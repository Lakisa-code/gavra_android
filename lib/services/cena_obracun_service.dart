import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/registrovani_putnik.dart';

/// 💰 Servis za obračun mesečne cene za putnike
///
/// PRAVILA: Cena se MORA manuelno postaviti od strane admina - više nema default cena!
/// - RADNIK: Admin postavlja cenu (nema default-a)
/// - UČENIK: Admin postavlja cenu (nema default-a)
/// - DNEVNI: Admin postavlja cenu (nema default-a)
/// - POŠILJKA: Admin postavlja cenu (osim "ZUBI" koji ima fiksnih 300 RSD)
class CenaObracunService {
  static SupabaseClient get _supabase => supabase;

  /// Dobija cenu po danu za putnika (SAMO custom cena)
  static double getCenaPoDanu(RegistrovaniPutnik putnik) {
    // 1. Ako ima postavljenu custom cenu - koristi je
    if (putnik.cenaPoDanu != null && putnik.cenaPoDanu! > 0) {
      return putnik.cenaPoDanu!;
    }

    final tipLower = putnik.tip.toLowerCase();
    final imeLower = putnik.putnikIme.toLowerCase();

    // 2. STROGO FIKSNE CENE samo za specijalne slučajeve
    if (tipLower == 'posiljka' && imeLower.contains('zubi')) {
      return 300.0;
    }

    // 3. Ako nema custom cene - više nema default cena, vraća 0.0
    return 0.0;
  }

  /// Dobija default cenu po danu samo na osnovu tipa (String) - VRAĆA 0.0
  static double getDefaultCenaByTip(String tip) {
    return 0.0;
  }

  /// Izračunaj mesečnu cenu za putnika na osnovu pokupljenja
  ///
  /// [putnik] - RegistrovaniPutnik objekat
  /// [mesec] - Mesec za koji se računa (1-12)
  /// [godina] - Godina za koju se računa
  ///
  /// Vraća: broj_jedinica * cena_po_jedinici
  static Future<double> izracunajMesecnuCenu({
    required RegistrovaniPutnik putnik,
    required int mesec,
    required int godina,
  }) async {
    final brojJedinica = await _prebrojJediniceObracuna(
      putnikId: putnik.id,
      tip: putnik.tip,
      mesec: mesec,
      godina: godina,
    );

    final cenaPoJedinici = getCenaPoDanu(putnik);
    return brojJedinica * cenaPoJedinici;
  }

  /// Prebroji broj jedinica za obračun
  /// Pravilo: Jedno ili više pokupljenja u istom danu = jedna vožnja/jedinica obračuna.
  /// Važi za SVE tipove putnika (Radnik, Učenik, Dnevni).
  static Future<int> _prebrojJediniceObracuna({
    required String putnikId,
    required String tip,
    required int mesec,
    required int godina,
  }) async {
    try {
      final pocetakMeseca = DateTime(godina, mesec, 1);
      final krajMeseca = DateTime(godina, mesec + 1, 0);

      // Koristi voznje_log za brojanje vožnji
      final response = await _supabase
          .from('voznje_log')
          .select('datum, broj_mesta') // Dodat broj_mesta
          .eq('putnik_id', putnikId)
          .eq('tip', 'voznja')
          .gte('datum', pocetakMeseca.toIso8601String().split('T')[0])
          .lte('datum', krajMeseca.toIso8601String().split('T')[0]);

      final records = response as List;

      if (records.isEmpty) return 0;

      final jeDnevni = tip.toLowerCase() == 'dnevni';
      final jePosiljka = tip.toLowerCase() == 'posiljka' || tip.toLowerCase() == 'pošiljka';

      // Ako je DNEVNI ili POSILJKA, brojimo SVAKO POKUPLJENJE (ali uzimamo u obzir broj mesta!)
      if (jeDnevni || jePosiljka) {
        int totalUnits = 0;
        for (final record in records) {
          totalUnits += (record['broj_mesta'] as num?)?.toInt() ?? 1;
        }
        return totalUnits;
      }

      // Za ostale (Radnik/Učenik) brojimo UNIKATNE DANE
      // 1 pokupljenje = 1 vožnja, 2 ili 3 pokupljenja = i dalje 1 vožnja (dan)
      // FIX: Ako jedan dan ima više mesta Rezervisano na svim vožnjama, uzimamo MAX broj mesta za taj dan
      final Map<String, int> dailyMaxSeats = {};
      for (final record in records) {
        final datumStr = record['datum'] as String?;
        if (datumStr != null) {
          final datum = datumStr.split('T')[0];
          final bm = (record['broj_mesta'] as num?)?.toInt() ?? 1;
          if (bm > (dailyMaxSeats[datum] ?? 0)) {
            dailyMaxSeats[datum] = bm;
          }
        }
      }

      int totalUnits = 0;
      dailyMaxSeats.forEach((key, value) => totalUnits += value);
      return totalUnits;
    } catch (e) {
      return 0;
    }
  }

  /// Masovni obračun jedinica za listu putnika (optimizovano - jedan upit)
  static Future<Map<String, int>> prebrojJediniceMasovno({
    required List<RegistrovaniPutnik> putnici,
    required int mesec,
    required int godina,
  }) async {
    if (putnici.isEmpty) return {};

    final ids = putnici.map((p) => p.id).toList();
    final pocetakMeseca = DateTime(godina, mesec, 1);
    final krajMeseca = DateTime(godina, mesec + 1, 0);

    try {
      final response = await _supabase
          .from('voznje_log')
          .select('datum, broj_mesta, putnik_id')
          .inFilter('putnik_id', ids)
          .eq('tip', 'voznja')
          .gte('datum', pocetakMeseca.toIso8601String().split('T')[0])
          .lte('datum', krajMeseca.toIso8601String().split('T')[0]);

      final records = response as List;
      final Map<String, int> rezultati = {for (var p in putnici) p.id: 0};

      // Grupiši rekorde po putniku
      final Map<String, List<dynamic>> grupisanRekordi = {};
      for (var r in records) {
        final pid = r['putnik_id'] as String;
        grupisanRekordi.putIfAbsent(pid, () => []).add(r);
      }

      for (var p in putnici) {
        final logs = grupisanRekordi[p.id] ?? [];
        if (logs.isEmpty) continue;

        final tipLower = p.tip.toLowerCase();
        final jeDnevni = tipLower == 'dnevni';
        final jePosiljka = tipLower == 'posiljka' || tipLower == 'pošiljka';

        if (jeDnevni || jePosiljka) {
          int totalUnits = 0;
          for (final record in logs) {
            totalUnits += (record['broj_mesta'] as num?)?.toInt() ?? 1;
          }
          rezultati[p.id] = totalUnits;
        } else {
          // Za ostale (Radnik/Učenik) brojimo unikatne dane i uzimamo MAX mesta po danu
          final Map<String, int> dailyMaxSeats = {};
          for (final record in logs) {
            final datumStr = record['datum'] as String?;
            if (datumStr != null) {
              final datum = datumStr.split('T')[0];
              final bm = (record['broj_mesta'] as num?)?.toInt() ?? 1;
              if (bm > (dailyMaxSeats[datum] ?? 0)) {
                dailyMaxSeats[datum] = bm;
              }
            }
          }
          int totalUnits = 0;
          dailyMaxSeats.forEach((key, value) => totalUnits += value);
          rezultati[p.id] = totalUnits;
        }
      }
      return rezultati;
    } catch (e) {
      return {};
    }
  }

  /// Dobij detaljan obračun za putnika
  static Future<Map<String, dynamic>> getDetaljniObracun({
    required RegistrovaniPutnik putnik,
    required int mesec,
    required int godina,
  }) async {
    final brojJedinica = await _prebrojJediniceObracuna(
      putnikId: putnik.id,
      tip: putnik.tip,
      mesec: mesec,
      godina: godina,
    );

    final cenaPoUnit = getCenaPoDanu(putnik);
    final izracunataCena = brojJedinica * cenaPoUnit;
    final imaCustomCenu = putnik.cenaPoDanu != null && putnik.cenaPoDanu! > 0;

    return {
      'putnikId': putnik.id,
      'putnikIme': putnik.putnikIme,
      'tip': putnik.tip,
      'cenaPoDanu': cenaPoUnit,
      'brojDanaSaPokupljenjima': brojJedinica, // Zadržavamo ključ zbog UI kompatibilnosti
      'izracunataCena': izracunataCena,
      'customCenaPoDanu': putnik.cenaPoDanu,
      'imaCustomCenu': imaCustomCenu,
      'konacnaCena': izracunataCena,
      'mesec': mesec,
      'godina': godina,
    };
  }

  /// Postavi custom cenu po danu za putnika
  static Future<bool> postaviCenuPoDanu({
    required String putnikId,
    required double? cenaPoDanu,
  }) async {
    try {
      await _supabase.from('registrovani_putnici').update({
        'cena_po_danu': cenaPoDanu,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', putnikId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Ukloni custom cenu (koristi default cenu po tipu)
  static Future<bool> ukloniCustomCenu(String putnikId) async {
    return postaviCenuPoDanu(putnikId: putnikId, cenaPoDanu: null);
  }
}
