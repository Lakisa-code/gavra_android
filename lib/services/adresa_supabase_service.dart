import 'dart:async';

import '../globals.dart';
import '../models/adresa.dart';
import 'geocoding_service.dart';
import 'realtime/realtime_manager.dart';

/// Servis za rad sa normalizovanim adresama iz Supabase tabele
/// 🎯 KORISTI UUID REFERENCE umesto TEXT polja
class AdresaSupabaseService {
  /// Cache za brže učitavanje
  static final Map<String, Adresa> _cache = {};
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 10);

  static StreamSubscription? _adreseSubscription;
  static final StreamController<List<Adresa>> _adreseController = StreamController<List<Adresa>>.broadcast();

  /// Dobija adresu po UUID-u
  static Future<Adresa?> getAdresaByUuid(String uuid) async {
    if (_cache.containsKey(uuid) && _isCacheValid()) {
      return _cache[uuid];
    }

    try {
      final response =
          await supabase.from('adrese').select('id, naziv, grad, gps_lat, gps_lng').eq('id', uuid).single();

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
          await supabase.from('adrese').select('id, naziv, grad, gps_lat, gps_lng').eq('grad', grad).order('naziv');

      return response.map((json) => Adresa.fromMap(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Dobija sve adrese
  static Future<List<Adresa>> getSveAdrese() async {
    try {
      final response =
          await supabase.from('adrese').select('id, naziv, grad, gps_lat, gps_lng').order('grad').order('naziv');
      return response.map((json) => Adresa.fromMap(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 🛰️ REALTIME STREAM: Prati promene u tabeli 'adrese'
  static Stream<List<Adresa>> streamSveAdrese() {
    if (_adreseSubscription == null) {
      _adreseSubscription = RealtimeManager.instance.subscribe('adrese').listen((payload) {
        _refreshAdreseStream();
      });
      // Inicijalno učitavanje
      _refreshAdreseStream();
    }
    return _adreseController.stream;
  }

  static void _refreshAdreseStream() async {
    final adrese = await getSveAdrese();
    if (!_adreseController.isClosed) {
      _adreseController.add(adrese);
    }
  }

  /// Pronađi adresu po nazivu i gradu
  static Future<Adresa?> findAdresaByNazivAndGrad(String naziv, String grad) async {
    try {
      final response = await supabase
          .from('adrese')
          .select('id, naziv, grad, ulica, broj, gps_lat, gps_lng')
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
      // 🔇 Ignore
    }

    // 🚫 NE KREIRAJ NOVU ADRESU - vrati null
    // Nove adrese može dodati samo admin direktno u Supabase
    return null;
  }

  /// 🌍 Geocodira adresu i ažurira u bazi
  static Future<Adresa?> _geocodeAndUpdateAdresa(Adresa adresa, String grad) async {
    try {
      final coordsString = await GeocodingService.getKoordinateZaAdresu(
        grad,
        adresa.naziv,
      );

      if (coordsString != null) {
        final parts = coordsString.split(',');
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0]);
          final lng = double.tryParse(parts[1]);

          if (lat != null && lng != null) {
            // Ažuriraj u bazi
            final response = await supabase
                .from('adrese')
                .update({
                  'gps_lat': lat, // Direct column
                  'gps_lng': lng, // Direct column
                })
                .eq('id', adresa.id)
                .select('id, naziv, grad, ulica, broj, gps_lat, gps_lng')
                .single();

            final updatedAdresa = Adresa.fromMap(response);
            _cache[updatedAdresa.id] = updatedAdresa;
            return updatedAdresa;
          }
        }
      }
    } catch (_) {
      // 🔇 Ignore
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

    final List<String> needToFetch = [];
    for (final uuid in uuids) {
      if (_cache.containsKey(uuid) && _isCacheValid()) {
        result[uuid] = _cache[uuid]!;
      } else {
        needToFetch.add(uuid);
      }
    }

    if (needToFetch.isNotEmpty) {
      try {
        for (final uuid in needToFetch) {
          final adresa = await getAdresaByUuid(uuid);
          if (adresa != null) {
            result[uuid] = adresa;
          }
        }
      } catch (e) {
        // 🔇 Ignore
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
        'gps_lat': lat, // Direct column
        'gps_lng': lng, // Direct column
      }).eq('id', uuid);

      if (_cache.containsKey(uuid)) {
        final existing = _cache[uuid]!;
        _cache[uuid] = existing.withCoordinates(lat, lng);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 🧹 Čisti realtime cache i subscription
  static void dispose() {
    _adreseSubscription?.cancel();
    _adreseSubscription = null;
    _adreseController.close();
  }
}
