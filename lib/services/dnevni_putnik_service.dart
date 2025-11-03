import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/adresa.dart';
import '../models/dnevni_putnik.dart';
import '../models/putnik.dart';
import '../models/ruta.dart';
import 'adresa_service.dart';

/// Servis za upravljanje dnevnim putnicima
class DnevniPutnikService {
  DnevniPutnikService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;
  final SupabaseClient _supabase;

  // Logger instance - koristićemo dlog funkciju iz logging.dart
  // static final // Logger removed;

  // Cache za adrese i rute
  final Map<String, Adresa> _adresaCache = {};
  final Map<String, Ruta> _rutaCache = {};

  // Instanciranje servisa
  late final AdresaService _adresaService = AdresaService();

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
    String id,
    Map<String, dynamic> updates,
  ) async {
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
  Future<List<DnevniPutnik>> searchDnevniPutnici(
    String query, {
    DateTime? datum,
  }) async {
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
    String rutaId,
    DateTime datum,
  ) async {
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
        .map(
          (data) => data
              .where(
                (putnik) =>
                    putnik['datum'] == datumString &&
                    putnik['obrisan'] == false,
              )
              .map((json) => DnevniPutnik.fromMap(json))
              .toList(),
        );
  }

  // ✅ RELATIONSHIP HELPER METODE

  /// Dohvata adresu po ID-u sa cache-om
  Future<Adresa?> _getAdresaById(String adresaId) async {
    if (_adresaCache.containsKey(adresaId)) {
      return _adresaCache[adresaId];
    }

    try {
      final adresa = await _adresaService.getAdresaById(adresaId);
      if (adresa != null) {
        _adresaCache[adresaId] = adresa;
      }
      return adresa;
    } catch (e) {
      return null;
    }
  }

  /// Dohvata rutu po ID-u sa cache-om
  Future<Ruta?> _getRutaById(String rutaId) async {
    if (_rutaCache.containsKey(rutaId)) {
      return _rutaCache[rutaId];
    }

    try {
      final response =
          await _supabase.from('rute').select().eq('id', rutaId).single();

      final ruta = Ruta.fromMap(response);
      _rutaCache[rutaId] = ruta;
      return ruta;
    } catch (e) {
      return null;
    }
  }

  /// Konvertuje DnevniPutnik u Putnik sa relationship podacima
  Future<Putnik?> dnevniPutnikToPutnik(DnevniPutnik dnevniPutnik) async {
    try {
      final adresa = await _getAdresaById(dnevniPutnik.adresaId);
      final ruta = await _getRutaById(dnevniPutnik.rutaId);

      if (adresa == null || ruta == null) {
        return null;
      }

      return dnevniPutnik.toPutnikWithRelations(adresa, ruta);
    } catch (e) {
      return null;
    }
  }

  /// Dohvata dnevne putnike kao Putnik objekte sa relationship podacima
  Future<List<Putnik>> getDnevniPutniciKaoPutnici(DateTime datum) async {
    try {
      final dnevniPutnici = await getDnevniPutniciZaDatum(datum);
      final List<Putnik> putnici = [];

      for (final dnevniPutnik in dnevniPutnici) {
        final putnik = await dnevniPutnikToPutnik(dnevniPutnik);
        if (putnik != null) {
          putnici.add(putnik);
        }
      }
      return putnici;
    } catch (e) {
      return [];
    }
  }

  /// Batch operacije - dodavanje više putnika odjednom
  Future<List<DnevniPutnik>> dodajViseputnika(
    List<DnevniPutnik> putnici,
  ) async {
    try {
      final List<Map<String, dynamic>> data =
          putnici.map((p) => p.toMap()).toList();

      final response =
          await _supabase.from('dnevni_putnici').insert(data).select();

      final dodatiPutnici =
          response.map((json) => DnevniPutnik.fromMap(json)).toList();

      return dodatiPutnici;
    } catch (e) {
      rethrow;
    }
  }

  /// Dohvata statistike za dnevne putnike
  Future<Map<String, dynamic>> getStatistike(DateTime datum) async {
    try {
      final putnici = await getDnevniPutniciZaDatum(datum);

      final ukupno = putnici.length;
      final pokupljeni = putnici.where((p) => p.isPokupljen).length;
      final placeni = putnici.where((p) => p.isPlacen).length;
      final otkazani =
          putnici.where((p) => p.status == DnevniPutnikStatus.otkazan).length;
      final ukupnaZarada =
          putnici.fold<double>(0, (sum, p) => sum + (p.isPlacen ? p.cena : 0));

      return {
        'ukupno': ukupno,
        'pokupljeni': pokupljeni,
        'placeni': placeni,
        'otkazani': otkazani,
        'ukupna_zarada': ukupnaZarada,
        'procenat_pokupljenosti':
            ukupno > 0 ? (pokupljeni / ukupno * 100).round() : 0,
        'procenat_placenos': ukupno > 0 ? (placeni / ukupno * 100).round() : 0,
      };
    } catch (e) {
      return {};
    }
  }

  /// Čisti cache (korisno za memory management)
  void clearCache() {
    _adresaCache.clear();
    _rutaCache.clear();
  }

  /// Validacija pre dodavanja novog putnika
  Future<bool> validateNoviPutnik(DnevniPutnik putnik) async {
    if (!putnik.isValid) {
      return false;
    }

    // Proveri da li adresa i ruta postoje
    final adresa = await _getAdresaById(putnik.adresaId);
    final ruta = await _getRutaById(putnik.rutaId);

    if (adresa == null) {
      return false;
    }

    if (ruta == null) {
      return false;
    }

    // Proveri duplikate za isti datum i vreme
    final postojeciPutnici =
        await getDnevniPutniciZaDatum(putnik.datumPutovanja);
    final duplikat = postojeciPutnici.any(
      (p) =>
          p.ime.toLowerCase() == putnik.ime.toLowerCase() &&
          p.vremePolaska == putnik.vremePolaska &&
          p.adresaId == putnik.adresaId,
    );

    if (duplikat) {
      return false;
    }

    return true;
  }
}
