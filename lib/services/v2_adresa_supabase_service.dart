import 'dart:async';

import '../globals.dart';
import '../models/adresa.dart';
import 'geocoding_service.dart';
import 'realtime/realtime_manager.dart';

/// Servis za rad sa normalizovanim adresama iz Supabase tabele
/// ðŸŽ¯ KORISTI UUID REFERENCE umesto TEXT polja
class V2AdresaSupabaseService {
  static StreamSubscription? _adreseSubscription;
  static final StreamController<List<Adresa>> _adreseController = StreamController<List<Adresa>>.broadcast();
  static List<Adresa> _cachedAdrese = []; // ðŸš€ Cache za brÅ¾e uÄitavanje

  /// Dobija adresu po UUID-u
  static Future<Adresa?> getAdresaByUuid(String uuid) async {
    try {
      final response =
          await supabase.from('v2_adrese').select('id, naziv, grad, gps_lat, gps_lng').eq('id', uuid).single();

      final adresa = Adresa.fromMap(response);
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

  /// Dobija sve adrese za odreÄ‘eni grad
  static Future<List<Adresa>> getAdreseZaGrad(String grad) async {
    try {
      final response =
          await supabase.from('v2_adrese').select('id, naziv, grad, gps_lat, gps_lng').eq('grad', grad).order('naziv');

      return response.map((json) => Adresa.fromMap(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Dobija sve adrese
  static Future<List<Adresa>> getSveAdrese() async {
    try {
      final response =
          await supabase.from('v2_adrese').select('id, naziv, grad, gps_lat, gps_lng').order('grad').order('naziv');
      return response.map((json) => Adresa.fromMap(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// ðŸ›°ï¸ REALTIME STREAM: Prati promene u tabeli 'v2_adrese'
  static Stream<List<Adresa>> streamSveAdrese() {
    if (_adreseSubscription == null) {
      // UÄitaj prvi put (ako nema cache)
      if (_cachedAdrese.isEmpty) {
        _refreshAdreseStream();
      } else {
        // Emituj iz cache-a odmah
        if (!_adreseController.isClosed) {
          _adreseController.add(_cachedAdrese);
        }
      }

      _adreseSubscription = RealtimeManager.instance.subscribe('v2_adrese').listen((payload) {
        _refreshAdreseStream(); // AÅ¾uriraj samo na promenu
      });
    }
    return _adreseController.stream;
  }

  static void _refreshAdreseStream() async {
    final adrese = await getSveAdrese();
    _cachedAdrese = adrese; // ðŸ’¾ ÄŒuva se u memoriji
    if (!_adreseController.isClosed) {
      _adreseController.add(adrese);
    }
  }

  /// PronaÄ‘i adresu po nazivu i gradu
  static Future<Adresa?> findAdresaByNazivAndGrad(String naziv, String grad) async {
    try {
      final response = await supabase
          .from('v2_adrese')
          .select('id, naziv, grad, ulica, broj, gps_lat, gps_lng')
          .eq('naziv', naziv)
          .eq('grad', grad)
          .maybeSingle();
      if (response != null) {
        final adresa = Adresa.fromMap(response);
        return adresa;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Pronalazi postojeÄ‡u adresu - NE KREIRA NOVE
  /// ðŸš« ZAKLJUÄŒANO: Nove adrese moÅ¾e dodati samo admin direktno u bazi
  static Future<Adresa?> createOrGetAdresa({
    required String naziv,
    required String grad,
    String? ulica,
    String? broj,
    double? lat,
    double? lng,
  }) async {
    // ðŸ”’ Samo pronaÄ‘i postojeÄ‡u adresu - NE KREIRAJ NOVU
    try {
      final postojeca = await findAdresaByNazivAndGrad(naziv, grad);
      if (postojeca != null) {
        // Ako postojeÄ‡a adresa NEMA koordinate ali imamo ih, aÅ¾uriraj
        if (!postojeca.hasValidCoordinates && lat != null && lng != null) {
          final updatedAdresa = await _geocodeAndUpdateAdresa(postojeca, grad);
          if (updatedAdresa != null) {
            return updatedAdresa;
          }
        }
        return postojeca;
      }
    } catch (_) {
      // ðŸ”‡ Ignore
    }

    // ðŸš« NE KREIRAJ NOVU ADRESU - vrati null
    // Nove adrese moÅ¾e dodati samo admin direktno u Supabase
    return null;
  }

  /// ðŸŒ Geocodira adresu i aÅ¾urira u bazi
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
            // AÅ¾uriraj u bazi
            final response = await supabase
                .from('v2_adrese')
                .update({
                  'gps_lat': lat, // Direct column
                  'gps_lng': lng, // Direct column
                })
                .eq('id', adresa.id)
                .select('id, naziv, grad, ulica, broj, gps_lat, gps_lng')
                .single();

            final updatedAdresa = Adresa.fromMap(response);
            return updatedAdresa;
          }
        }
      }
    } catch (_) {
      // ðŸ”‡ Ignore
    }
    return null;
  }

  /// Batch uÄitavanje adresa
  static Future<Map<String, Adresa>> getAdreseByUuids(List<String> uuids) async {
    final Map<String, Adresa> result = {};

    for (final uuid in uuids) {
      final adresa = await getAdresaByUuid(uuid);
      if (adresa != null) {
        result[uuid] = adresa;
      }
    }

    return result;
  }

  /// ðŸŽ¯ NOVO: AÅ¾uriraj koordinate za postojeÄ‡u adresu
  /// Koristi se kada Nominatim pronaÄ‘e koordinate za adresu koja ih nema u bazi
  static Future<bool> updateKoordinate(
    String uuid, {
    required double lat,
    required double lng,
  }) async {
    try {
      await supabase.from('v2_adrese').update({
        'gps_lat': lat, // Direct column
        'gps_lng': lng, // Direct column
      }).eq('id', uuid);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// ðŸ§¹ ÄŒisti realtime subscription
  static void dispose() {
    _adreseSubscription?.cancel();
    _adreseSubscription = null;
    _adreseController.close();
  }
}
