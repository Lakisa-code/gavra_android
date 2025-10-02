import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mesecni_putnik_novi.dart';

/// Servis za upravljanje mesečnim putnicima (normalizovana šema)
class MesecniPutnikService {
  final SupabaseClient _supabase;

  MesecniPutnikService({SupabaseClient? supabaseClient})
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
  Future<void> toggleAktivnost(String id, bool aktivnost) async {
    await _supabase.from('mesecni_putnici').update({
      'aktivan': aktivnost,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Ažurira mesečnog putnika (legacy metoda name)
  Future<void> azurirajMesecnogPutnika(MesecniPutnik putnik) async {
    await updateMesecniPutnik(putnik.id, putnik.toMap());
  }

  /// Dodaje novog mesečnog putnika (legacy metoda name)
  Future<MesecniPutnik> dodajMesecnogPutnika(MesecniPutnik putnik) async {
    return await createMesecniPutnik(putnik);
  }

  /// Kreira dnevna putovanja iz mesečnih (placeholder - treba implementirati)
  Future<void> kreirajDnevnaPutovanjaIzMesecnih(
      MesecniPutnik putnik, DateTime datum) async {
    // TODO: Implementirati kreiranje dnevnih putovanja iz mesečnog putnika
    // Ova metoda treba da kreira zapise u putovanja_istorija tabeli
    print('TODO: Implementirati kreirajDnevnaPutovanjaIzMesecnih');
  }

  /// Sinhronizacija broja putovanja sa istorijom (placeholder)
  Future<void> sinhronizujBrojPutovanjaSaIstorijom(String id) async {
    // TODO: Implementirati sinhronizaciju sa putovanja_istorija tabelom
    print('TODO: Implementirati sinhronizujBrojPutovanjaSaIstorijom');
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
  Future<void> obrisiMesecniPutnik(String id) async {
    await _supabase.from('mesecni_putnici').update({
      'obrisan': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
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
}
