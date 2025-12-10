import '../globals.dart';

/// Čisti StatistikaService koji izbegava duplikate
/// Koristi samo registrovani_putnici kao primarni izvor
class CleanStatistikaService {
  /// Dohvati ukupne statistike (samo iz registrovani_putnici)
  static Future<Map<String, dynamic>> dohvatiUkupneStatistike() async {
    final registrovaniPutnici = await supabase.from('registrovani_putnici').select().eq('obrisan', false);

    // Standalone putovanja (bez mesecni_putnik_id)
    final standalonePutovanja =
        await supabase.from('putovanja_istorija').select().eq('obrisan', false).isFilter('mesecni_putnik_id', null);

    double ukupnoRegistrovani = 0;
    double ukupnoStandalone = 0;

    registrovaniPutnici.forEach((Map<String, dynamic> mp) {
      if (mp['cena'] != null) {
        ukupnoRegistrovani += (mp['cena'] as num).toDouble();
      }
    });

    standalonePutovanja.forEach((Map<String, dynamic> sp) {
      if (sp['cena'] != null) {
        ukupnoStandalone += (sp['cena'] as num).toDouble();
      }
    });

    return {
      'ukupno_registrovani': ukupnoRegistrovani,
      'ukupno_standalone': ukupnoStandalone,
      'ukupno_sve': ukupnoRegistrovani + ukupnoStandalone,
      'broj_registrovanih': registrovaniPutnici.length,
      'broj_standalone': standalonePutovanja.length,
      'broj_ukupno': registrovaniPutnici.length + standalonePutovanja.length,
      'no_duplicates': true,
    };
  }

  /// Dohvati mesečne statistike
  static Future<Map<String, dynamic>> dohvatiMesecneStatistike(int mesec, int godina) async {
    final registrovaniPutnici = await supabase
        .from('registrovani_putnici')
        .select()
        .eq('obrisan', false)
        .eq('mesec', mesec)
        .eq('godina', godina);

    double ukupnoRegistrovani = 0;
    registrovaniPutnici.forEach((mp) {
      if (mp['cena'] != null) {
        ukupnoRegistrovani += (mp['cena'] as num).toDouble();
      }
    });

    return {
      'mesec': mesec,
      'godina': godina,
      'ukupno_registrovani': ukupnoRegistrovani,
      'broj_registrovanih': registrovaniPutnici.length,
      'no_duplicates': true,
    };
  }

  /// Lista svih putnika bez duplikata
  static Future<List<Map<String, dynamic>>> dohvatiSvePutnikeClean() async {
    final registrovaniPutnici = await supabase
        .from('registrovani_putnici')
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

    // Dodaj registrovane putnike (radnik/ucenik)
    registrovaniPutnici.forEach((mp) {
      sviPutnici.add({
        'id': mp['id'],
        'putnik_ime': mp['putnik_ime'] ?? mp['ime'],
        'tip_putnika': mp['tip'] ?? 'radnik', // ✅ FIX: Koristi stvarni tip iz baze
        'iznos': mp['cena'],
        'datum_placanja': mp['datum_placanja'],
        'mesec': mp['mesec'],
        'godina': mp['godina'],
        'status': mp['status'],
        'izvor': 'registrovani_putnici',
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
