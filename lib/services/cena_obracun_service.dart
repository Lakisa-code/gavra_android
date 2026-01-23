import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/registrovani_putnik.dart';

/// 💰 Servis za obračun mesečne cene za putnike
///
/// Pravila:
/// - RADNIK: 700 RSD po danu (default)
/// - UČENIK: 600 RSD po danu (default)
/// - DNEVNI: Po dogovoru (mora imati custom cenu)
/// - POŠILJKA: 500 RSD po danu (fiksno)
/// - CUSTOM CENA PO DANU: Ako putnik ima postavljenu custom cenu, koristi se ona
class CenaObracunService {
  static SupabaseClient get _supabase => supabase;

  /// Default cenovnik po tipu putnika (po danu)
  static const double defaultCenaRadnikPoDanu = 700.0;
  static const double defaultCenaUcenikPoDanu = 600.0;
  static const double defaultCenaDnevniPoDanu = 600.0;
  static const double defaultCenaPosiljkaPoDanu = 500.0; // Pošiljka je 500 RSD

  /// Dobija cenu po danu za putnika (custom ili default)
  static double getCenaPoDanu(RegistrovaniPutnik putnik) {
    // TIP DNEVNI/POSILJKA uvek ima fiksnu cenu (osim ako je eksplicitno postavljena drugačija)
    if (putnik.tip.toLowerCase() == 'dnevni' || putnik.tip.toLowerCase() == 'posiljka') {
      return putnik.cenaPoDanu ??
          (putnik.tip.toLowerCase() == 'posiljka' ? defaultCenaPosiljkaPoDanu : defaultCenaDnevniPoDanu);
    }

    // Ako ima custom cenu, koristi je
    if (putnik.cenaPoDanu != null && putnik.cenaPoDanu! > 0) {
      return putnik.cenaPoDanu!;
    }
    // Inače koristi default na osnovu tipa
    return _getDefaultCenaPoDanu(putnik.tip);
  }

  /// Dobija default cenu po danu za tip putnika (interna)
  static double _getDefaultCenaPoDanu(String tip) {
    switch (tip.toLowerCase()) {
      case 'ucenik':
      case 'učenik':
        return defaultCenaUcenikPoDanu;
      case 'dnevni':
        return defaultCenaDnevniPoDanu;
      case 'posiljka':
      case 'pošiljka':
        return defaultCenaPosiljkaPoDanu;
      case 'radnik':
      default:
        return defaultCenaRadnikPoDanu;
    }
  }

  /// Dobija default cenu po danu samo na osnovu tipa (String)
  /// Koristi se kada nemamo RegistrovaniPutnik objekat (npr. iz Map)
  static double getDefaultCenaByTip(String tip) {
    return _getDefaultCenaPoDanu(tip);
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
          .select('datum')
          .eq('putnik_id', putnikId)
          .eq('tip', 'voznja')
          .gte('datum', pocetakMeseca.toIso8601String().split('T')[0])
          .lte('datum', krajMeseca.toIso8601String().split('T')[0]);

      final records = response as List;

      if (records.isEmpty) return 0;

      final jeDnevni = tip.toLowerCase() == 'dnevni';

      // Ako je DNEVNI, brojimo SVAKO POKUPLJENJE (600 RSD po puta)
      if (jeDnevni) {
        return records.length;
      }

      // Za ostale (Radnik/Učenik) brojimo UNIKATNE DANE
      // 1 pokupljenje = 1 vožnja, 2 ili 3 pokupljenja = i dalje 1 vožnja (dan)
      final Set<String> uniqueDays = {};
      for (final record in records) {
        final datum = record['datum'] as String?;
        if (datum != null) {
          uniqueDays.add(datum.split('T')[0]);
        }
      }
      return uniqueDays.length;
    } catch (e) {
      return 0;
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

  /// Dobij formatiran tekst za SMS poruku
  static String formatirajCenuZaSms({
    required double cena,
    required String tip,
    required int brojDana, // Zadržavamo naziv parametra zbog kompatibilnosti
    double? customCenaPoDanu,
  }) {
    final jeDnevni = tip.toLowerCase() == 'dnevni';
    final labela = jeDnevni ? 'dana' : 'vožnji';
    final cenaPoUnit = customCenaPoDanu ?? _getDefaultCenaPoDanu(tip);

    if (customCenaPoDanu != null) {
      return '${cena.toStringAsFixed(0)} RSD ($brojDana $labela x ${cenaPoUnit.toStringAsFixed(0)} RSD - specijalna cena)';
    }
    return '${cena.toStringAsFixed(0)} RSD ($brojDana $labela x ${cenaPoUnit.toStringAsFixed(0)} RSD)';
  }
}
