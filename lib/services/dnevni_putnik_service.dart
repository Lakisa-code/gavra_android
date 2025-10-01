import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dnevni_putnik.dart';

/// Servis za upravljanje dnevnim putnicima
class DnevniPutnikService {
  final SupabaseClient _supabase;

  DnevniPutnikService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  /// Dohvata sve dnevne putnike za dati datum
  Future<List<DnevniPutnik>> getDnevniPutniciZaDatum(DateTime datum) async {
    final datumString = datum.toIso8601String().split('T')[0];

    final response = await _supabase.from('dnevni_putnici').select('''
          *
        ''').eq('datum', datumString).eq('obrisan', false).order('polazak');

    return response.map((json) => DnevniPutnik.fromMap(json)).toList();
  }

  /// Dohvata dnevnog putnika po ID-u
  Future<DnevniPutnik?> getDnevniPutnikById(String id) async {
    final response = await _supabase.from('dnevni_putnici').select('''
          *
        ''').eq('id', id).single();

    return DnevniPutnik.fromMap(response);
  }

  /// Kreira novog dnevnog putnika
  Future<DnevniPutnik> createDnevniPutnik(DnevniPutnik putnik) async {
    final response =
        await _supabase.from('dnevni_putnici').insert(putnik.toMap()).select('''
          *
        ''').single();

    return DnevniPutnik.fromMap(response);
  }

  /// Ažurira dnevnog putnika
  Future<DnevniPutnik> updateDnevniPutnik(
      String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await _supabase
        .from('dnevni_putnici')
        .update(updates)
        .eq('id', id)
        .select('''
          *
        ''').single();

    return DnevniPutnik.fromMap(response);
  }

  /// Označava putnika kao pokupljenog
  Future<void> oznaciKaoPokupio(String id, String vozacId) async {
    await updateDnevniPutnik(id, {
      'status': 'pokupljen',
      'vreme_pokupljenja': DateTime.now().toIso8601String(),
      'pokupio_vozac_id': vozacId,
    });
  }

  /// Označava putnika kao plaćenog
  Future<void> oznaciKaoPlacen(String id, String vozacId) async {
    await updateDnevniPutnik(id, {
      'vreme_placanja': DateTime.now().toIso8601String(),
      'naplatio_vozac_id': vozacId,
    });
  }

  /// Otkaži putnika
  Future<void> otkaziPutnika(String id, String vozacId) async {
    await updateDnevniPutnik(id, {
      'status': 'otkazan',
      'otkazao_vozac_id': vozacId,
      'vreme_otkazivanja': DateTime.now().toIso8601String(),
    });
  }

  /// Briše putnika (soft delete)
  Future<void> obrisiPutnika(String id) async {
    await _supabase.from('dnevni_putnici').update({
      'obrisan': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Traži dnevne putnike po imenu, prezimenu ili broju telefona
  Future<List<DnevniPutnik>> searchDnevniPutnici(String query,
      {DateTime? datum}) async {
    var queryBuilder = _supabase
        .from('dnevni_putnici')
        .select('''
          *
        ''')
        .eq('obrisan', false)
        .or('ime.ilike.%$query%,prezime.ilike.%$query%,broj_telefona.ilike.%$query%');

    if (datum != null) {
      final datumString = datum.toIso8601String().split('T')[0];
      queryBuilder = queryBuilder.eq('datum', datumString);
    }

    final response = await queryBuilder.order('polazak');
    return response.map((json) => DnevniPutnik.fromMap(json)).toList();
  }

  /// Dohvata putnike za datu rutu i datum
  Future<List<DnevniPutnik>> getPutniciZaRutu(
      String rutaId, DateTime datum) async {
    final datumString = datum.toIso8601String().split('T')[0];

    final response = await _supabase
        .from('dnevni_putnici')
        .select('''
          *
        ''')
        .eq('ruta_id', rutaId)
        .eq('datum', datumString)
        .eq('obrisan', false)
        .order('polazak');

    return response.map((json) => DnevniPutnik.fromMap(json)).toList();
  }

  /// Stream za realtime ažuriranja dnevnih putnika
  Stream<List<DnevniPutnik>> dnevniPutniciStreamZaDatum(DateTime datum) {
    final datumString = datum.toIso8601String().split('T')[0];

    return _supabase
        .from('dnevni_putnici')
        .stream(primaryKey: ['id'])
        .order('polazak')
        .map((data) => data
            .where((putnik) =>
                putnik['datum'] == datumString && putnik['obrisan'] == false)
            .map((json) => DnevniPutnik.fromMap(json))
            .toList());
  }
}
