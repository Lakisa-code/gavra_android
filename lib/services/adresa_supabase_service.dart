import '../globals.dart';
import '../models/adresa.dart';
import 'advanced_geocoding_service.dart';

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
      final response = await supabase
          .from('adrese')
          .select('id, naziv, grad, ulica, broj, koordinate, created_at, updated_at')
          .eq('naziv', naziv)
          .eq('grad', grad)
          .maybeSingle();
      if (response != null) {
        final adresa = Adresa.fromMap(response);
        _cache[adresa.id] = adresa;
        return adresa;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Pronalazi postojeću adresu - NE KREIRA NOVE
  /// 🚫 ZAKLJUČANO: Nove adrese može dodati samo admin direktno u bazi
  static Future<Adresa?> createOrGetAdresa({
    required String naziv,
    required String grad,
    String? ulica,
    String? broj,
    double? lat,
    double? lng,
  }) async {
    // 🔒 Samo pronađi postojeću adresu - NE KREIRAJ NOVU
    try {
      final postojeca = await findAdresaByNazivAndGrad(naziv, grad);
      if (postojeca != null) {
        // Ako postojeća adresa NEMA koordinate ali imamo ih, ažuriraj
        if (!postojeca.hasValidCoordinates && lat != null && lng != null) {
          final updatedAdresa = await _geocodeAndUpdateAdresa(postojeca, grad);
          if (updatedAdresa != null) {
            return updatedAdresa;
          }
        }
        return postojeca;
      }
    } catch (_) {
      // Greška pri pretrazi adrese
    }

    // 🚫 NE KREIRAJ NOVU ADRESU - vrati null
    // Nove adrese može dodati samo admin direktno u Supabase
    return null;
  }

  /// 🌍 Geocodira adresu i ažurira u bazi
  static Future<Adresa?> _geocodeAndUpdateAdresa(Adresa adresa, String grad) async {
    try {
      final geocodeResult = await AdvancedGeocodingService.getAdvancedCoordinates(
        grad: grad,
        adresa: adresa.naziv,
      );

      if (geocodeResult != null && geocodeResult.confidence > 50) {
        // Ažuriraj u bazi
        final response = await supabase
            .from('adrese')
            .update({
              'koordinate': {'lat': geocodeResult.latitude, 'lng': geocodeResult.longitude},
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', adresa.id)
            .select('id, naziv, grad, ulica, broj, koordinate, created_at, updated_at')
            .single();

        final updatedAdresa = Adresa.fromMap(response);
        _cache[updatedAdresa.id] = updatedAdresa;
        return updatedAdresa;
      } else {
        // Low confidence
      }
    } catch (_) {
      // Geocoding greška
    }
    return null;
  }

  /// Pretraži adrese po nazivu (za autocomplete)
  static Future<List<Adresa>> searchAdrese(String query, {String? grad}) async {
    try {
      var queryBuilder = supabase.from('adrese').select().ilike('naziv', '%$query%');

      if (grad != null) {
        queryBuilder = queryBuilder.eq('grad', grad);
      }

      final response = await queryBuilder.order('naziv').limit(20);

      // DEBUG: Print response
      print('🔍 searchAdrese query="$query" grad="$grad"');
      print('🔍 searchAdrese response count: ${response.length}');
      if (response.isNotEmpty) {
        print('🔍 searchAdrese first item: ${response.first}');
      }

      return response.map((json) => Adresa.fromMap(json)).toList();
    } catch (e, stack) {
      print('❌ searchAdrese error: $e');
      print('❌ searchAdrese stack: $stack');
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

  /// 📊 NOVO: Dobij najčešće korišćene adrese (na osnovu putovanja_istorija)
  /// Vraća listu adresa sa brojem putovanja, sortiranu po popularnosti
  static Future<List<Map<String, dynamic>>> getNajcesceKorisceneAdrese({
    int limit = 10,
    String? grad,
  }) async {
    try {
      // Dohvati sve adrese koje imaju putovanja
      var query = supabase
          .from('putovanja_istorija')
          .select('adresa_id, adrese!inner(id, naziv, grad, koordinate)')
          .not('adresa_id', 'is', null);

      if (grad != null) {
        query = query.eq('adrese.grad', grad);
      }

      final response = await query;

      // Prebroj koliko puta se svaka adresa pojavljuje
      final Map<String, Map<String, dynamic>> adresaCounts = {};

      for (final row in response) {
        final adresaId = row['adresa_id'] as String?;
        if (adresaId == null) continue;

        final adresaData = row['adrese'] as Map<String, dynamic>?;
        if (adresaData == null) continue;

        if (adresaCounts.containsKey(adresaId)) {
          adresaCounts[adresaId]!['count'] = (adresaCounts[adresaId]!['count'] as int) + 1;
        } else {
          final adresa = Adresa.fromMap(adresaData);
          adresaCounts[adresaId] = {
            'adresa': adresa,
            'count': 1,
            'icon': adresa.addressIcon,
            'naziv': adresa.naziv,
            'grad': adresa.grad,
          };
        }
      }

      // Sortiraj po broju putovanja (najviše korišćene prvo)
      final sortedList = adresaCounts.values.toList()..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      // Vrati samo prvih N
      return sortedList.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  /// 📊 NOVO: Dobij statistiku adresa sa ikonama
  /// Vraća formatirani string za prikaz (npr. "🏥 Ambulanta Jasenovo (45 putovanja)")
  static Future<List<String>> getNajcesceKorisceneAdreseFormatted({
    int limit = 10,
    String? grad,
  }) async {
    final adrese = await getNajcesceKorisceneAdrese(limit: limit, grad: grad);

    return adrese.map((data) {
      final icon = data['icon'] as String;
      final naziv = data['naziv'] as String;
      final gradAdrese = data['grad'] as String?;
      final count = data['count'] as int;

      if (gradAdrese != null && gradAdrese.isNotEmpty) {
        return '$icon $naziv, $gradAdrese ($count putovanja)';
      }
      return '$icon $naziv ($count putovanja)';
    }).toList();
  }

  /// 📍 GPS LEARN: Ažuriraj koordinate adrese na osnovu GPS lokacije pri pokupljenju
  /// Ova funkcija se poziva kada vozač pokupi putnika - pamti tačnu lokaciju
  static Future<bool> updateKoordinateFromGps({
    required String adresaId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Validacija koordinata za Srbiju (širina: 42-46.5, dužina: 18-23)
      if (latitude < 42.0 || latitude > 46.5 || longitude < 18.0 || longitude > 23.0) {
        return false;
      }

      // Proveri da li adresa već ima koordinate naučene iz GPS-a
      final existing = await getAdresaByUuid(adresaId);
      if (existing?.hasValidCoordinates == true) {
        // Već ima koordinate, ne prepisuj ih
        return false;
      }

      // Kreiraj JSONB koordinate
      final koordinate = {
        'lat': latitude,
        'lng': longitude,
        'source': 'gps_learn', // Oznaka da su koordinate naučene iz GPS-a
        'learned_at': DateTime.now().toIso8601String(),
      };

      // Ažuriraj u bazi
      await supabase.from('adrese').update({
        'koordinate': koordinate,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', adresaId);

      // Invalidate cache
      _cache.remove(adresaId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 📍 GPS LEARN: Pokušaj reverse geocoding da dobiješ tačnu adresu
  /// Koristi Nominatim za pretvaranje koordinata u ulicu i broj
  static Future<String?> reverseGeocodeFromGps({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1',
      );

      final response = await supabase.functions.invoke(
        'nominatim-proxy',
        body: {'url': url.toString()},
      );

      if (response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final road = address['road'] as String?;
          final houseNumber = address['house_number'] as String?;

          if (road != null) {
            if (houseNumber != null) {
              return '$road $houseNumber';
            }
            return road;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
