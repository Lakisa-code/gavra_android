import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mesecni_putnik.dart';

/// Servis za kombinovanje podataka o plaćanjima iz različitih tabela
class PlacanjeService {
  static final _supabase = Supabase.instance.client;

  /// Kombinuje podatke o plaćanju iz mesecni_putnici i putovanja_istorija
  static Future<Map<String, double>> getStvarnaPlacanja(
      List<MesecniPutnik> putnici) async {
    final Map<String, double> rezultat = {};

    try {
      // Preuzmi sva plaćanja iz putovanja_istorija (uključujući sva plaćanja)
      final istorijaPlacanjaResponse = await _supabase
          .from('putovanja_istorija')
          .select('putnik_ime, cena, mesecni_putnik_id, datum_putovanja')
          .eq('status', 'placeno')
          .eq('tip_putnika', 'mesecni')
          .not('cena', 'is', null);

      final List<dynamic> istorijaPlacanjaData =
          istorijaPlacanjaResponse as List;

      // Mapa za brže pronalaženje po ID-u - sabira SVA plaćanja
      final Map<String, double> placanjaPoId = {};
      final Map<String, double> placanjaPoImenu = {};

      for (final placanje in istorijaPlacanjaData) {
        final cena = (placanje['cena'] as num?)?.toDouble() ?? 0.0;
        final mesecniPutnikId = placanje['mesecni_putnik_id'] as String?;
        final putnikIme = placanje['putnik_ime'] as String?;

        if (mesecniPutnikId != null) {
          placanjaPoId[mesecniPutnikId] =
              (placanjaPoId[mesecniPutnikId] ?? 0.0) + cena;
        }

        if (putnikIme != null) {
          placanjaPoImenu[putnikIme] =
              (placanjaPoImenu[putnikIme] ?? 0.0) + cena;
        }
      }

      // Kombinuj podatke za svakog putnika
      for (final putnik in putnici) {
        double iznos = 0.0;

        // 1. Pokušaj prvo po ID-u
        if (placanjaPoId.containsKey(putnik.id)) {
          iznos = placanjaPoId[putnik.id]!;
        }
        // 2. Ako nema po ID-u, pokušaj po imenu
        else if (placanjaPoImenu.containsKey(putnik.putnikIme)) {
          iznos = placanjaPoImenu[putnik.putnikIme]!;
        }
        // 3. Fallback na cenu iz mesecni_putnici
        else if (putnik.cena != null && putnik.cena! > 0) {
          iznos = putnik.cena!;
        }
        // 4. Fallback na ukupnaCenaMeseca
        else if (putnik.ukupnaCenaMeseca > 0) {
          iznos = putnik.ukupnaCenaMeseca;
        }

        rezultat[putnik.id] = iznos;
      }
    } catch (e) {
      // Fallback - koristi podatke iz mesecni_putnici
      for (final putnik in putnici) {
        rezultat[putnik.id] = putnik.cena ?? putnik.ukupnaCenaMeseca;
      }
    }

    return rezultat;
  }

  /// Dobija iznos plaćanja za jednog putnika
  static Future<double> getIznosPlacanja(MesecniPutnik putnik) async {
    final placanja = await getStvarnaPlacanja([putnik]);
    return placanja[putnik.id] ?? 0.0;
  }

  /// Dobija plaćanja za određeni mesec i godinu
  static Future<Map<String, double>> getPlacanjaZaMesec(
    List<MesecniPutnik> putnici,
    int mesec,
    int godina,
  ) async {
    final Map<String, double> rezultat = {};

    try {
      // Kalkuliši početak i kraj meseca
      final pocetakMeseca = DateTime(godina, mesec);
      final krajMeseca = DateTime(godina, mesec + 1, 0, 23, 59, 59);

      // Preuzmi plaćanja za specifičan mesec iz putovanja_istorija
      final placanjaResponse = await _supabase
          .from('putovanja_istorija')
          .select('putnik_ime, cena, mesecni_putnik_id')
          .eq('status', 'placeno')
          .eq('tip_putnika', 'mesecni')
          .gte('datum_putovanja', pocetakMeseca.toIso8601String().split('T')[0])
          .lte('datum_putovanja', krajMeseca.toIso8601String().split('T')[0])
          .not('cena', 'is', null);

      final List<dynamic> placanjaData = placanjaResponse as List;

      // Mapa za sabiranje plaćanja po ID-u
      final Map<String, double> placanjaPoId = {};
      final Map<String, double> placanjaPoImenu = {};

      for (final placanje in placanjaData) {
        final cena = (placanje['cena'] as num?)?.toDouble() ?? 0.0;
        final mesecniPutnikId = placanje['mesecni_putnik_id'] as String?;
        final putnikIme = placanje['putnik_ime'] as String?;

        if (mesecniPutnikId != null) {
          placanjaPoId[mesecniPutnikId] =
              (placanjaPoId[mesecniPutnikId] ?? 0.0) + cena;
        }

        if (putnikIme != null) {
          placanjaPoImenu[putnikIme] =
              (placanjaPoImenu[putnikIme] ?? 0.0) + cena;
        }
      }

      // Kombinuj podatke za svakog putnika
      for (final putnik in putnici) {
        double iznos = 0.0;

        // Pokušaj prvo po ID-u, zatim po imenu
        if (placanjaPoId.containsKey(putnik.id)) {
          iznos = placanjaPoId[putnik.id]!;
        } else if (placanjaPoImenu.containsKey(putnik.putnikIme)) {
          iznos = placanjaPoImenu[putnik.putnikIme]!;
        }

        rezultat[putnik.id] = iznos;
      }
    } catch (e) {
      // Fallback - vrati 0 za sve putnike
      for (final putnik in putnici) {
        rezultat[putnik.id] = 0.0;
      }
    }

    return rezultat;
  }

  /// Sinhronizuje cenu u mesecni_putnici sa podacima iz putovanja_istorija
  static Future<void> sinhronizujPlacanja() async {
    try {
      // Preuzmi sve mesečne putnike
      final putnicResponse = await _supabase.from('mesecni_putnici').select();

      final List<MesecniPutnik> putnici = (putnicResponse as List)
          .map((data) => MesecniPutnik.fromMap(data as Map<String, dynamic>))
          .toList();

      // Dobij stvarna plaćanja
      final stvarnaPlacanja = await getStvarnaPlacanja(putnici);

      // Ažuriraj putnice kod kojih se cena razlikuje
      for (final putnik in putnici) {
        final stvarniIznos = stvarnaPlacanja[putnik.id] ?? 0.0;
        final trenutnaCena = putnik.cena ?? 0.0;

        // Ako se iznosi razlikuju, ažuriraj bazu
        if ((stvarniIznos - trenutnaCena).abs() > 0.01) {
          // tolerance za floating point
          await _supabase.from('mesecni_putnici').update({
            'cena': stvarniIznos,
            'ukupna_cena_meseca': stvarniIznos,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', putnik.id);

          // Sinhronizovano plaćanje - silent update
        }
      }
    } catch (e) {
      // Ignoriši greške u sinhronizaciji
    }
  }

  /// Dobija ukupan iznos svih plaćanja za mesečnog putnika za određeni mesec
  static Future<double> getUkupanIznosZaMesec(
    String putnikId,
    int mesec,
    int godina,
  ) async {
    try {
      final pocetakMeseca = DateTime(godina, mesec);
      final krajMeseca = DateTime(godina, mesec + 1, 0);

      final placanja = await _supabase
          .from('putovanja_istorija')
          .select('cena')
          .eq('mesecni_putnik_id', putnikId)
          .eq('tip_putnika', 'mesecni')
          .gte('datum_putovanja', pocetakMeseca.toIso8601String().split('T')[0])
          .lte('datum_putovanja', krajMeseca.toIso8601String().split('T')[0])
          .eq('status', 'placeno');

      double ukupno = 0.0;
      for (final placanje in placanja) {
        final iznos = (placanje['cena'] as num?)?.toDouble() ?? 0.0;
        ukupno += iznos;
      }

      return ukupno;
    } catch (e) {
      return 0.0;
    }
  }

  /// Dobija detaljnu listu svih plaćanja za mesečnog putnika za određeni mesec
  static Future<List<Map<String, dynamic>>> getDetaljnaPlacanjaZaMesec(
    String putnikId,
    int mesec,
    int godina,
  ) async {
    try {
      final pocetakMeseca = DateTime(godina, mesec);
      final krajMeseca = DateTime(godina, mesec + 1, 0);

      final placanja = await _supabase
          .from('putovanja_istorija')
          .select('cena, datum_putovanja, vozac_id, created_at, napomene')
          .eq('mesecni_putnik_id', putnikId)
          .eq('tip_putnika', 'mesecni')
          .gte('datum_putovanja', pocetakMeseca.toIso8601String().split('T')[0])
          .lte('datum_putovanja', krajMeseca.toIso8601String().split('T')[0])
          .eq('status', 'placeno')
          .order('created_at', ascending: false);

      return (placanja as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
}
