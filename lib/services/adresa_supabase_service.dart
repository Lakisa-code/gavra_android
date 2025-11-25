import '../globals.dart';
import '../models/adresa.dart';

/// Servis za rad sa normalizovanim adresama iz Supabase tabele
/// 🎯 KORISTI UUID REFERENCE umesto TEXT polja
class AdresaSupabaseService {
  /// Cache za brže učitavanje
  static final Map<String, Adresa> _cache = {};
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 10);

  /// Dobija adresu po UUID-u
  static Future<Adresa?> getAdresaByUuid(String uuid) async {
    // Proveri cache prvo
    if (_cache.containsKey(uuid) && _isCacheValid()) {
      return _cache[uuid];
    }

    try {
      final response = await supabase
          .from('adrese')
          .select('id, naziv, grad, koordinate, created_at, updated_at')
          .eq('id', uuid)
          .single();

      final adresa = Adresa.fromMap(response);
      _cache[uuid] = adresa;
      return adresa;
    } catch (e) {
      return null;
    }
  }

  /// Dobija naziv adrese po UUID-u (optimizovano za UI)
  static Future<String?> getNazivAdreseByUuid(String? uuid) async {
    if (uuid == null || uuid.isEmpty) return null;

    final adresa = await getAdresaByUuid(uuid);
    return adresa?.naziv;
  }

  /// Dobija sve adrese za određeni grad
  static Future<List<Adresa>> getAdreseZaGrad(String grad) async {
    try {
      final response =
          await supabase.from('adrese').select('id, naziv, grad, koordinate').eq('grad', grad).order('naziv');

      return response.map((json) => Adresa.fromMap(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Pronađi adresu po nazivu i gradu
  static Future<Adresa?> findAdresaByNazivAndGrad(String naziv, String grad) async {
    try {
      print('🔍 Finding address: naziv="$naziv", grad="$grad"');
      final response = await supabase
          .from('adrese')
          .select('id, naziv, grad, ulica, broj, koordinate, created_at, updated_at')
          .eq('naziv', naziv)
          .eq('grad', grad)
          .maybeSingle();

      print('🔍 Search response: $response');
      if (response != null) {
        final adresa = Adresa.fromMap(response);
        _cache[adresa.id] = adresa;
        print('🔍 Found address: ${adresa.id}');
        return adresa;
      }
      print('🔍 No address found');
      return null;
    } catch (e) {
      print('❌ Error finding address: $e');
      return null;
    }
  }

  /// Kreira novu adresu ili vraća postojeću
  static Future<Adresa?> createOrGetAdresa({
    required String naziv,
    required String grad,
    String? ulica,
    String? broj,
    double? lat,
    double? lng,
  }) async {
    print('🏠 createOrGetAdresa called with: naziv="$naziv", grad="$grad"');

    // Prvo pokušaj da pronađeš postojeću
    try {
      print('🏠 Searching for existing address...');
      final postojeca = await findAdresaByNazivAndGrad(naziv, grad);
      if (postojeca != null) {
        print('🏠 Found existing address: ${postojeca.id}');
        return postojeca;
      }
      print('🏠 No existing address found, creating new...');
    } catch (e) {
      print('❌ Error searching for existing address: $e');
    }

    // Kreiraj novu
    try {
      print('🏠 Inserting new address...');
      final response = await supabase
          .from('adrese')
          .insert({
            'naziv': naziv,
            'grad': grad,
            'ulica': ulica ?? naziv,
            'broj': broj,
            // Dodaj koordinate kao JSONB objekat ako su dostupne
            if (lat != null && lng != null) 'koordinate': {'lat': lat, 'lng': lng},
          })
          .select('id, naziv, grad, ulica, broj, koordinate, created_at, updated_at')
          .single();

      print('🏠 Insert response: $response');
      final adresa = Adresa.fromMap(response);
      _cache[adresa.id] = adresa;
      print('🏠 Successfully created address: ${adresa.id}');
      return adresa;
    } catch (e) {
      print('❌ Error creating new address: $e');
      return null;
    }
  }

  /// Pretraži adrese po nazivu (za autocomplete)
  static Future<List<Adresa>> searchAdrese(String query, {String? grad}) async {
    try {
      var queryBuilder = supabase.from('adrese').select().ilike('naziv', '%$query%');

      if (grad != null) {
        queryBuilder = queryBuilder.eq('grad', grad);
      }

      final response = await queryBuilder.order('naziv').limit(20);

      return response.map((json) => Adresa.fromMap(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Očisti cache
  static void clearCache() {
    _cache.clear();
    _lastCacheUpdate = null;
  }

  /// Proveri da li je cache valjan
  static bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiry;
  }

  /// Refresuj cache
  static Future<void> refreshCache() async {
    clearCache();
    _lastCacheUpdate = DateTime.now();
  }

  /// Helper metoda za dobijanje adresa u formatu za dropdown
  static Future<List<Map<String, dynamic>>> getAdreseDropdownData(String grad) async {
    final adrese = await getAdreseZaGrad(grad);
    return adrese
        .map((adresa) => {'id': adresa.id, 'naziv': adresa.naziv, 'displayText': adresa.displayAddress})
        .toList();
  }

  /// Batch učitavanje adresa (za optimizaciju)
  static Future<Map<String, Adresa>> getAdreseByUuids(List<String> uuids) async {
    final Map<String, Adresa> result = {};

    // Proveri cache prvo
    final List<String> needToFetch = [];
    for (final uuid in uuids) {
      if (_cache.containsKey(uuid) && _isCacheValid()) {
        result[uuid] = _cache[uuid]!;
      } else {
        needToFetch.add(uuid);
      }
    }

    // Učitaj one koji nisu u cache-u
    if (needToFetch.isNotEmpty) {
      try {
        // Učitaj jedan po jedan zbog ograničenja Supabase filtera
        for (final uuid in needToFetch) {
          final adresa = await getAdresaByUuid(uuid);
          if (adresa != null) {
            result[uuid] = adresa;
          }
        }
      } catch (e) {
        // Ignoriši greške
      }
    }

    return result;
  }

  /// 🎯 NOVO: Ažuriraj koordinate za postojeću adresu
  /// Koristi se kada Nominatim pronađe koordinate za adresu koja ih nema u bazi
  static Future<bool> updateKoordinate(
    String uuid, {
    required double lat,
    required double lng,
  }) async {
    try {
      await supabase.from('adrese').update({
        'koordinate': {'lat': lat, 'lng': lng},
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uuid);

      // Ažuriraj cache ako postoji
      if (_cache.containsKey(uuid)) {
        final existing = _cache[uuid]!;
        _cache[uuid] = existing.withCoordinates(lat, lng);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 🎯 NOVO: Pronađi adrese bez koordinata (za batch geocoding)
  static Future<List<Adresa>> getAdreseBezKoordinata({int limit = 50}) async {
    try {
      final response = await supabase
          .from('adrese')
          .select('id, naziv, grad, ulica, broj, koordinate, created_at, updated_at')
          .isFilter('koordinate', null)
          .limit(limit);

      return response.map((json) => Adresa.fromMap(json)).toList();
    } catch (e) {
      return [];
    }
  }
}
