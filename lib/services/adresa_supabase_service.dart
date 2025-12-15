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
}
