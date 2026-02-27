import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';

  // 🚀 BATCH PROCESSING VARIABLES
  static final Map<String, Completer<String?>> _pendingRequests = {};
  static final Set<String> _processingRequests = {};

  // 🚀 OPTIMIZOVANA VERZIJA - SA BATCH PROCESSING
  static Future<String?> getKoordinateZaAdresu(
    String grad,
    String adresa,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      // PROVERI DA LI JE GRAD DOZVOLJEN (samo Bela Crkva i Vrsac)
      if (_isCityBlocked(grad)) {
        return null;
      }

      final requestKey = '${grad}_$adresa';

      // 🔄 BATCH PROCESSING - Spreči duplikate zahteva
      if (_processingRequests.contains(requestKey)) {
        // Čekaj postojeći zahtev
        if (_pendingRequests.containsKey(requestKey)) {
          return await _pendingRequests[requestKey]!.future;
        }
      }

      // Dodaj novi zahtev u queue
      final completer = Completer<String?>();
      _pendingRequests[requestKey] = completer;
      _processingRequests.add(requestKey);

      // 1. Idi direktno na API
      try {
        // PRIMARNO: Photon (Komoot)
        // Bolji za fuzzy pretragu ("Šipad", "Pumpa"...)
        String? coords = await _fetchFromPhoton(grad, adresa);

        // Fallback: Nominatim (OSM)
        // Ako Photon ne nađe, probamo strogu pretragu
        coords ??= await _fetchFromNominatim(grad, adresa);

        if (coords != null) {
          _completeRequest(requestKey, coords);
        } else {
          _completeRequest(requestKey, null);
        }
      } catch (e) {
        _completeRequest(requestKey, null);
      }

      return await completer.future;
    } finally {
      stopwatch.stop();
    }
  }

  // 🔄 HELPER - Complete pending request
  static void _completeRequest(String requestKey, String? result) {
    final completer = _pendingRequests.remove(requestKey);
    _processingRequests.remove(requestKey);
    completer?.complete(result);
  }

  // Pozovi Nominatim API sa retry logikom
  static Future<String?> _fetchFromNominatim(String grad, String adresa) async {
    const int maxRetries = 3;
    const Duration timeout = Duration(seconds: 10);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final query = '$adresa, $grad, Serbia';
        final encodedQuery = Uri.encodeComponent(query);
        final url = '$_baseUrl?q=$encodedQuery&format=json&limit=1&countrycodes=rs';

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'GavraAndroidApp/1.0 (transport app)',
          },
        ).timeout(timeout);

        if (response.statusCode == 200) {
          final List<dynamic> results = json.decode(response.body) as List<dynamic>;

          if (results.isNotEmpty) {
            final result = results[0];
            final lat = result['lat'];
            final lon = result['lon'];
            final coords = '$lat,$lon';

            return coords;
          } else {}
        } else {}
      } catch (e) {
        if (attempt < maxRetries) {
          await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }

    return null;
  }

  // Pozovi Photon API (Komoot) kao fallback
  // Mnogo tolerantniji na greške u kucanju i lokalne nazive
  static Future<String?> _fetchFromPhoton(String grad, String adresa) async {
    try {
      // Photon zahteva jedan query string
      // Format: "Adresa, Grad"
      final query = '$adresa, $grad';
      final encodedQuery = Uri.encodeComponent(query);

      // Ograničimo pretragu na Srbiju (bias)
      // bbox for Serbia roughly: 18.82,41.85,23.01,46.19
      // Ovo sprečava da "Prima pumpa" vrati London ili Bosnu
      const String bbox = '&bbox=18.82,41.85,23.01,46.19';

      final url = 'https://photon.komoot.io/api/?q=$encodedQuery&limit=1$bbox';

      // Photon zahteva User-Agent da ne bi vraćao 403
      final headers = {'User-Agent': 'GavraAndroid/1.0'};

      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>?;

        if (features != null && features.isNotEmpty) {
          final feature = features[0];
          final geometry = feature['geometry'];
          final coordinates = geometry['coordinates'] as List<dynamic>; // [lon, lat]

          final lon = coordinates[0];
          final lat = coordinates[1];

          return '$lat,$lon';
        }
      }
    } catch (e) {
      // Silently ignore errors
    }
    return null;
  }

  /// 🚫 PROVERI DA LI JE GRAD VAN DOZVOLJENE RELACIJE
  static bool _isCityBlocked(String grad) {
    final normalizedGrad = grad.toLowerCase().trim();

    // ✅ DOZVOLJENI GRADOVI: SAMO Bela Crkva i Vrsac opštine
    final allowedCities = [
      // Vrsac OPŠTINA
      'vrsac', 'straza', 'straža', 'vojvodinci', 'potporanj', 'oresac',
      'orešac',
      // BELA CRKVA OPŠTINA
      'bela crkva', 'vracev gaj', 'vraćev gaj', 'dupljaja', 'jasenovo',
      'kruscica', 'kruščica', 'kusic', 'kusić', 'crvena crkva',
    ];
    return !allowedCities.any(
      (allowed) => normalizedGrad.contains(allowed) || allowed.contains(normalizedGrad),
    );
  }
}
