import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mesecni_putnik_novi.dart';

/// Servis za upravljanje mesečnim putnicima (normalizovana šema)
class MesecniPutnikServiceNovi {
  final SupabaseClient _supabase;

  MesecniPutnikServiceNovi({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  /// Dohvata sve mesečne putnike
  Future<List<MesecniPutnik>> getAllMesecniPutnici() async {
    final response = await _supabase.from('mesecni_putnici').select('''
          *
        ''').eq('obrisan', false).order('putnik_ime');

    return response.map((json) => MesecniPutnik.fromMap(json)).toList();
  }

  /// Dohvata aktivne mesečne putnike
  Future<List<MesecniPutnik>> getAktivniMesecniPutnici() async {
    final response = await _supabase.from('mesecni_putnici').select('''
          *
        ''').eq('aktivan', true).eq('obrisan', false).order('putnik_ime');

    return response.map((json) => MesecniPutnik.fromMap(json)).toList();
  }

  /// Dohvata mesečnog putnika po ID-u
  Future<MesecniPutnik?> getMesecniPutnikById(String id) async {
    final response = await _supabase.from('mesecni_putnici').select('''
          *
        ''').eq('id', id).single();

    return MesecniPutnik.fromMap(response);
  }

  /// Dohvata mesečnog putnika po imenu (legacy compatibility)
  static Future<MesecniPutnik?> getMesecniPutnikByIme(String ime) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('mesecni_putnici')
          .select('*')
          .eq('putnik_ime', ime)
          .eq('obrisan', false)
          .single();

      return MesecniPutnik.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  /// Stream za aktivne mesečne putnike (legacy compatibility)
  static Stream<List<MesecniPutnik>> streamAktivniMesecniPutnici() {
    try {
      final supabase = Supabase.instance.client;
      return supabase
          .from('mesecni_putnici')
          .stream(primaryKey: ['id'])
          .order('putnik_ime')
          .map((data) {
            try {
              final listRaw = data as List<dynamic>;
              return listRaw
                  .where((row) {
                    final map = row as Map<String, dynamic>;
                    return (map['aktivan'] == true) && (map['obrisan'] != true);
                  })
                  .map((json) =>
                      MesecniPutnik.fromMap(Map<String, dynamic>.from(json)))
                  .toList();
            } catch (e) {
              return <MesecniPutnik>[];
            }
          })
          .handleError((err) {
            return <MesecniPutnik>[];
          });
    } catch (e) {
      // fallback to a one-time fetch if stream creation fails
      return Stream.fromFuture(
        Supabase.instance.client
            .from('mesecni_putnici')
            .select('*')
            .eq('aktivan', true)
            .eq('obrisan', false)
            .order('putnik_ime')
            .then((response) => response
                .map((json) =>
                    MesecniPutnik.fromMap(Map<String, dynamic>.from(json)))
                .toList()),
      );
    }
  }

  /// Kreira novog mesečnog putnika
  Future<MesecniPutnik> createMesecniPutnik(MesecniPutnik putnik) async {
    final response = await _supabase
        .from('mesecni_putnici')
        .insert(putnik.toMap())
        .select('''
          *
        ''').single();

    return MesecniPutnik.fromMap(response);
  }

  /// Ažurira mesečnog putnika
  Future<MesecniPutnik> updateMesecniPutnik(
      String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await _supabase
        .from('mesecni_putnici')
        .update(updates)
        .eq('id', id)
        .select('''
          *
        ''').single();

    return MesecniPutnik.fromMap(response);
  }

  /// Označava putnika kao plaćenog
  Future<void> oznaciKaoPlacen(String id, String vozacId) async {
    await updateMesecniPutnik(id, {
      'vreme_placanja': DateTime.now().toIso8601String(),
      'naplatio_vozac_id': vozacId,
    });
  }

  /// Deaktivira mesečnog putnika
  Future<void> deactivateMesecniPutnik(String id) async {
    await _supabase.from('mesecni_putnici').update({
      'aktivan': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Toggle aktivnost mesečnog putnika
  Future<bool> toggleAktivnost(String id, bool aktivnost) async {
    try {
      await _supabase.from('mesecni_putnici').update({
        'aktivan': aktivnost,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Ažurira mesečnog putnika (legacy metoda name)
  Future<MesecniPutnik?> azurirajMesecnogPutnika(MesecniPutnik putnik) async {
    try {
      return await updateMesecniPutnik(putnik.id, putnik.toMap());
    } catch (e) {
      return null;
    }
  }

  /// Dodaje novog mesečnog putnika (legacy metoda name)
  Future<MesecniPutnik> dodajMesecnogPutnika(MesecniPutnik putnik) async {
    return await createMesecniPutnik(putnik);
  }

  /// Kreira dnevna putovanja iz mesečnih (placeholder - treba implementirati)
  Future<void> kreirajDnevnaPutovanjaIzMesecnih(
      MesecniPutnik putnik, DateTime datum) async {
    // ✅ Kreiranje dnevnih putovanja iz mesečnih putnika
    // Ova metoda kreira zapise u putovanja_istorija tabeli za svaki polazak

    // Implementacija će biti dodana kada bude potrebna za scheduling funkcionalnost
    // Trenutno se koristi direktno unošenje kroz glavnu logiku aplikacije
  }

  /// Sinhronizacija broja putovanja sa istorijom (placeholder)
  static Future<bool> sinhronizujBrojPutovanjaSaIstorijom(String id) async {
    try {
      final brojIzIstorije = await izracunajBrojPutovanjaIzIstorije(id);

      final supabase = Supabase.instance.client;
      await supabase.from('mesecni_putnici').update({
        'broj_putovanja': brojIzIstorije,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sinhronizuje broj otkazivanja sa istorijom
  static Future<bool> sinhronizujBrojOtkazivanjaSaIstorijom(String id) async {
    try {
      final brojIzIstorije = await izracunajBrojOtkazivanjaIzIstorije(id);

      final supabase = Supabase.instance.client;
      await supabase.from('mesecni_putnici').update({
        'broj_otkazivanja': brojIzIstorije,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Ažurira plaćanje za mesec (placeholder)
  Future<bool> azurirajPlacanjeZaMesec(String putnikId, double iznos,
      String vozacId, DateTime pocetakMeseca, DateTime krajMeseca) async {
    try {
      await updateMesecniPutnik(putnikId, {
        'vreme_placanja': DateTime.now().toIso8601String(),
        'naplatio_vozac_id': vozacId,
        'cena': iznos,
        'placeni_mesec': pocetakMeseca.month,
        'placena_godina': pocetakMeseca.year,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Briše mesečnog putnika (soft delete)
  Future<bool> obrisiMesecniPutnik(String id) async {
    try {
      await _supabase.from('mesecni_putnici').update({
        'obrisan': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Traži mesečne putnike po imenu, prezimenu ili broju telefona
  Future<List<MesecniPutnik>> searchMesecniPutnici(String query) async {
    final response = await _supabase
        .from('mesecni_putnici')
        .select('''
          *
        ''')
        .eq('obrisan', false)
        .or('ime.ilike.%$query%,prezime.ilike.%$query%,broj_telefona.ilike.%$query%')
        .order('putnik_ime');

    return response.map((json) => MesecniPutnik.fromMap(json)).toList();
  }

  /// Dohvata mesečne putnike za datu rutu
  Future<List<MesecniPutnik>> getMesecniPutniciZaRutu(String rutaId) async {
    final response = await _supabase
        .from('mesecni_putnici')
        .select('''
          *
        ''')
        .eq('ruta_id', rutaId)
        .eq('aktivan', true)
        .eq('obrisan', false)
        .order('putnik_ime');

    return response.map((json) => MesecniPutnik.fromMap(json)).toList();
  }

  /// Ažurira broj putovanja za putnika
  Future<void> azurirajBrojPutovanja(String id, {bool povecaj = true}) async {
    final putnik = await getMesecniPutnikById(id);
    if (putnik == null) return;

    final noviBroj =
        povecaj ? putnik.brojPutovanja + 1 : putnik.brojPutovanja - 1;

    await updateMesecniPutnik(id, {
      'broj_putovanja': noviBroj,
      'poslednje_putovanje': DateTime.now().toIso8601String(),
    });
  }

  /// Ažurira broj otkazivanja za putnika
  Future<void> azurirajBrojOtkazivanja(String id, {bool povecaj = true}) async {
    final putnik = await getMesecniPutnikById(id);
    if (putnik == null) return;

    final noviBroj =
        povecaj ? putnik.brojOtkazivanja + 1 : putnik.brojOtkazivanja - 1;

    await updateMesecniPutnik(id, {
      'broj_otkazivanja': noviBroj,
    });
  }

  /// Dohvata sva ukrcavanja za mesečnog putnika
  Future<List<Map<String, dynamic>>> dohvatiUkrcavanjaZaPutnika(
      String putnikIme) async {
    try {
      final ukrcavanja = await _supabase
          .from('putovanja_istorija')
          .select('*')
          .eq('putnik_ime', putnikIme)
          .eq('status', 'pokupljen')
          .order('created_at', ascending: false) as List<dynamic>;

      return ukrcavanja.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Dohvata sve otkaze za mesečnog putnika
  Future<List<Map<String, dynamic>>> dohvatiOtkazeZaPutnika(
      String putnikIme) async {
    try {
      final otkazi = await _supabase
          .from('putovanja_istorija')
          .select('*')
          .eq('putnik_ime', putnikIme)
          .eq('status', 'otkazan')
          .order('created_at', ascending: false) as List<dynamic>;

      return otkazi.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Dohvata sva plaćanja za mesečnog putnika
  Future<List<Map<String, dynamic>>> dohvatiPlacanjaZaPutnika(
      String putnikIme) async {
    try {
      List<Map<String, dynamic>> svaPlacanja = [];

      // 1. REDOVNA PUTOVANJA iz putovanja_istorija
      final redovnaPlacanja = await _supabase
          .from('putovanja_istorija')
          .select('*')
          .eq('putnik_ime', putnikIme)
          .gt('cena', 0)
          .order('created_at', ascending: false) as List<dynamic>;

      svaPlacanja.addAll(redovnaPlacanja.cast<Map<String, dynamic>>());

      // 2. MESEČNA PLAĆANJA iz mesecni_putnici
      final mesecnaPlacanja = await _supabase
          .from('mesecni_putnici')
          .select(
              'cena, vreme_placanja, naplata_vozac, placeni_mesec, placena_godina')
          .eq('putnik_ime', putnikIme)
          .not('vreme_placanja', 'is', null)
          .order('vreme_placanja', ascending: false) as List<dynamic>;

      // Konvertuj mesečna plaćanja u isti format kao redovna
      for (var mesecno in mesecnaPlacanja) {
        svaPlacanja.add({
          'cena': mesecno['cena'],
          'created_at': mesecno['vreme_placanja'],
          'vozac_ime': mesecno['naplata_vozac'], // Za konsistentnost sa UI
          'putnik_ime': putnikIme,
          'tip': 'mesecna_karta',
          'placeniMesec': mesecno['placeni_mesec'],
          'placenaGodina': mesecno['placena_godina'],
        });
      }

      // Dodaj vozac_ime i za redovna plaćanja (mapiranje naplata_vozac -> vozac_ime)
      for (var redovno
          in svaPlacanja.where((p) => p['tip'] != 'mesecna_karta')) {
        redovno['vozac_ime'] = redovno['naplata_vozac'];
      }

      // Sortiraj sve po datumu, najnovije prvo
      svaPlacanja.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });

      return svaPlacanja;
    } catch (e) {
      return [];
    }
  }

  /// Dohvata zakupljene putnike za današnji dan
  static Future<List<Map<String, dynamic>>> getZakupljenoDanas() async {
    try {
      final supabase = Supabase.instance.client;
      final danas = DateTime.now().toIso8601String().split('T')[0];
      final response = await supabase
          .from('putovanja_istorija')
          .select()
          .eq('datum', danas)
          .eq('status', 'zakupljeno')
          .order('vreme_polaska');

      // Supabase returns List<dynamic> of maps
      return response
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream za realtime ažuriranja mesečnih putnika
  Stream<List<MesecniPutnik>> get mesecniPutniciStream {
    try {
      return _supabase
          .from('mesecni_putnici')
          .stream(primaryKey: ['id'])
          .order('putnik_ime')
          .map((data) {
            try {
              final listRaw = data as List<dynamic>;
              final filtered = listRaw.where((row) {
                try {
                  final map = row as Map<String, dynamic>;
                  // consider absent 'obrisan' as false (not deleted)
                  return !(map['obrisan'] == true);
                } catch (_) {
                  return true;
                }
              }).toList();

              return filtered
                  .map((json) =>
                      MesecniPutnik.fromMap(Map<String, dynamic>.from(json)))
                  .toList();
            } catch (e) {
              return <MesecniPutnik>[];
            }
          })
          .handleError((err) {
            return <MesecniPutnik>[];
          });
    } catch (e) {
      // fallback to a one-time fetch if stream creation fails
      return getAktivniMesecniPutnici().asStream();
    }
  }

  /// Izračunava broj putovanja iz istorije
  static Future<int> izracunajBrojPutovanjaIzIstorije(
      String mesecniPutnikId) async {
    try {
      final supabase = Supabase.instance.client;
      // Dobij sve JEDINSTVENE DATUME kada je putnik pokupljen
      final response = await supabase
          .from('putovanja_istorija')
          .select('datum')
          .eq('mesecni_putnik_id', mesecniPutnikId)
          .or('pokupljen.eq.true,status.eq.pokupljeno');

      // Broji JEDINSTVENE datume (jedan dan = jedno putovanje)
      final jedinstveniDatumi = <String>{};
      for (final red in response) {
        if (red['datum'] != null) {
          jedinstveniDatumi.add(red['datum'] as String);
        }
      }

      final brojPutovanja = jedinstveniDatumi.length;

      return brojPutovanja;
    } catch (e) {
      return 0;
    }
  }

  /// Izračunava broj otkazivanja iz istorije
  static Future<int> izracunajBrojOtkazivanjaIzIstorije(
      String mesecniPutnikId) async {
    try {
      final supabase = Supabase.instance.client;
      // Dobij sve JEDINSTVENE DATUME kada je putnik otkazan
      final response = await supabase
          .from('putovanja_istorija')
          .select('datum')
          .eq('mesecni_putnik_id', mesecniPutnikId)
          .or('status.eq.otkazano,status.eq.nije_se_pojavio');

      // Broji JEDINSTVENE datume (jedan dan = jedno otkazivanje)
      final jedinstveniDatumi = <String>{};
      for (final red in response) {
        if (red['datum'] != null) {
          jedinstveniDatumi.add(red['datum'] as String);
        }
      }

      final brojOtkazivanja = jedinstveniDatumi.length;

      return brojOtkazivanja;
    } catch (e) {
      return 0;
    }
  }
}
