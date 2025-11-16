import '../globals.dart';

/// Čisti StatistikaService koji izbegava duplikate
/// Koristi samo mesecni_putnici kao primarni izvor
class CleanStatistikaService {
  /// Dohvati ukupne statistike (samo iz mesecni_putnici)
  static Future<Map<String, dynamic>> dohvatiUkupneStatistike() async {
    final mesecniPutnici =
        await supabase.from('mesecni_putnici').select().eq('obrisan', false);

    // Standalone putovanja (bez mesecni_putnik_id)
    final standalonePutovanja = await supabase
        .from('putovanja_istorija')
        .select()
        .eq('obrisan', false)
        .isFilter('mesecni_putnik_id', null);

    double ukupnoMesecni = 0;
    double ukupnoStandalone = 0;

    mesecniPutnici.forEach((Map<String, dynamic> mp) {
      if (mp['cena'] != null) {
        ukupnoMesecni += (mp['cena'] as num).toDouble();
      }
    });

    standalonePutovanja.forEach((Map<String, dynamic> sp) {
      if (sp['cena'] != null) {
        ukupnoStandalone += (sp['cena'] as num).toDouble();
      }
    });

    return {
      'ukupno_mesecni': ukupnoMesecni,
      'ukupno_standalone': ukupnoStandalone,
      'ukupno_sve': ukupnoMesecni + ukupnoStandalone,
      'broj_mesecnih': mesecniPutnici.length,
      'broj_standalone': standalonePutovanja.length,
      'broj_ukupno': mesecniPutnici.length + standalonePutovanja.length,
      'no_duplicates': true,
    };
  }

  /// Dohvati mesečne statistike
  static Future<Map<String, dynamic>> dohvatiMesecneStatistike(
      int mesec, int godina) async {
    final mesecniPutnici = await supabase
        .from('mesecni_putnici')
        .select()
        .eq('obrisan', false)
        .eq('mesec', mesec)
        .eq('godina', godina);

    double ukupnoMesecni = 0;
    mesecniPutnici.forEach((mp) {
      if (mp['cena'] != null) {
        ukupnoMesecni += (mp['cena'] as num).toDouble();
      }
    });

    return {
      'mesec': mesec,
      'godina': godina,
      'ukupno_mesecni': ukupnoMesecni,
      'broj_mesecnih': mesecniPutnici.length,
      'no_duplicates': true,
    };
  }

  /// Lista svih putnika bez duplikata
  static Future<List<Map<String, dynamic>>> dohvatiSvePutnikeClean() async {
    final mesecniPutnici = await supabase
        .from('mesecni_putnici')
        .select()
        .eq('obrisan', false)
        .order('datum_placanja', ascending: false);

    final standalonePutovanja = await supabase
        .from('putovanja_istorija')
        .select()
        .eq('obrisan', false)
        .isFilter('mesecni_putnik_id', null)
        .order('datum_placanja', ascending: false);

    List<Map<String, dynamic>> sviPutnici = [];

    // Dodaj mesečne
    mesecniPutnici.forEach((mp) {
      sviPutnici.add({
        'id': mp['id'],
        'putnik_ime': mp['putnik_ime'] ?? mp['ime'],
        'tip_putnika': 'mesecni',
        'iznos': mp['cena'],
        'datum_placanja': mp['datum_placanja'],
        'mesec': mp['mesec'],
        'godina': mp['godina'],
        'status': mp['status'],
        'izvor': 'mesecni_putnici',
      });
    });

    // Dodaj standalone
    standalonePutovanja.forEach((Map<String, dynamic> sp) {
      sviPutnici.add({
        'id': sp['id'],
        'putnik_ime': sp['putnik_ime'],
        'tip_putnika': sp['tip_putnika'] ?? 'dnevni',
        'iznos': sp['cena'],
        'datum_placanja': sp['datum_placanja'],
        'mesec': null,
        'godina': null,
        'status': sp['status'],
        'izvor': 'putovanja_istorija',
      });
    });

    return sviPutnici;
  }
}
