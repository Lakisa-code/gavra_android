import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/registrovani_putnik.dart';

/// 💰 Servis za obračun mesečne cene za putnike
///
/// Pravila:
/// - RADNIK: 700 RSD po danu (default)
/// - UČENIK: 600 RSD po danu (default)
/// - DNEVNI: Po dogovoru (mora imati custom cenu)
/// - CUSTOM CENA PO DANU: Ako putnik ima postavljenu custom cenu, koristi se ona
class CenaObracunService {
  static SupabaseClient get _supabase => supabase;

  /// Default cenovnik po tipu putnika (po danu)
  static const double defaultCenaRadnikPoDanu = 700.0;
  static const double defaultCenaUcenikPoDanu = 600.0;
  static const double defaultCenaDnevniPoDanu = 0.0; // Dnevni mora imati custom cenu

  /// Dobija cenu po danu za putnika (custom ili default)
  static double getCenaPoDanu(RegistrovaniPutnik putnik) {
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
  /// Vraća: broj_dana * cena_po_danu
  static Future<double> izracunajMesecnuCenu({
    required RegistrovaniPutnik putnik,
    required int mesec,
    required int godina,
  }) async {
    final brojDana = await _prebrojDaneSaPokupljenjima(
      putnikId: putnik.id,
      mesec: mesec,
      godina: godina,
    );

    final cenaPoDanu = getCenaPoDanu(putnik);
    return brojDana * cenaPoDanu;
  }

  /// Prebroji broj dana sa pokupljenjima u mesecu
  /// (jedno ili više pokupljenja u danu = 1 dan)
  static Future<int> _prebrojDaneSaPokupljenjima({
    required String putnikId,
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

      // Prebroji UNIKALNE dane
      final Set<String> uniqueDays = {};
      for (final record in response) {
        final datum = record['datum'] as String?;
        if (datum != null) {
          uniqueDays.add(datum.split('T')[0]); // Samo datum bez vremena
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
    final brojDana = await _prebrojDaneSaPokupljenjima(
      putnikId: putnik.id,
      mesec: mesec,
      godina: godina,
    );

    final cenaPoDanu = getCenaPoDanu(putnik);
    final izracunataCena = brojDana * cenaPoDanu;
    final imaCustomCenu = putnik.cenaPoDanu != null && putnik.cenaPoDanu! > 0;

    return {
      'putnikId': putnik.id,
      'putnikIme': putnik.putnikIme,
      'tip': putnik.tip,
      'cenaPoDanu': cenaPoDanu,
      'brojDanaSaPokupljenjima': brojDana,
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
    required int brojDana,
    double? customCenaPoDanu,
  }) {
    final cenaPoDanuValue = customCenaPoDanu ?? _getDefaultCenaPoDanu(tip);
    if (customCenaPoDanu != null) {
      return '${cena.toStringAsFixed(0)} RSD ($brojDana dana x ${cenaPoDanuValue.toStringAsFixed(0)} RSD - specijalna cena)';
    }
    return '${cena.toStringAsFixed(0)} RSD ($brojDana dana x ${cenaPoDanuValue.toStringAsFixed(0)} RSD)';
  }
}
