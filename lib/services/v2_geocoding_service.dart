import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeocodingService {
  GeocodingService._();

  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';

  // BATCH PROCESSING VARIABLES
  static final Map<String, Completer<String?>> _pendingRequests = {};
  static final Set<String> _processingRequests = {};

  // OPTIMIZOVANA VERZIJA - SA BATCH PROCESSING
  static Future<String?> getKoordinateZaAdresu(
    String grad,
    String adresa,
  ) async {
    // PROVERI DA LI JE GRAD DOZVOLJEN (samo Bela Crkva i Vrsac)
    if (_isCityBlocked(grad)) return null;

    final requestKey = '${grad}_$adresa';

    // BATCH PROCESSING - Spreči duplikate zahteva
    if (_processingRequests.contains(requestKey)) {
      // Čekaj postojeći zahtev — koristi ?.future ?? Future.value(null) da izbjegnemo NPE
      // ako se Completer ukloni između provjere i await
      return await (_pendingRequests[requestKey]?.future ?? Future.value(null));
    }

    // Dodaj novi zahtev u queue
    final completer = Completer<String?>();
    _pendingRequests[requestKey] = completer;
    _processingRequests.add(requestKey);

    try {
      // PRIMARNO: Photon (Komoot) — bolji za fuzzy pretragu
      String? coords = await _fetchFromPhoton(grad, adresa);

      // Fallback: Nominatim (OSM) — stroga pretraga
      coords ??= await _fetchFromNominatim(grad, adresa);

      _completeRequest(requestKey, coords);
    } catch (e) {
      _completeRequest(requestKey, null);
    }

    return completer.future;
  }

  // Helper — dovrši pending request i ukloni iz mapa
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
            final result = results[0] as Map<String, dynamic>;
            final lat = result['lat'] as String?;
            final lon = result['lon'] as String?;
            if (lat != null && lon != null) return '$lat,$lon';
          }
        }
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
          final feature = features[0] as Map<String, dynamic>;
          final geometry = feature['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List<dynamic>?; // [lon, lat]
          if (coordinates != null && coordinates.length >= 2) {
            final lon = coordinates[0];
            final lat = coordinates[1];
            if (lat != null && lon != null) return '$lat,$lon';
          }
        }
      }
    } catch (e) {
      debugPrint('[GeocodingService] Photon error: $e');
    }
    return null;
  }

  /// Vraca true ako grad NIJE u dozvoljenim opstinama (Vrsac i Bela Crkva)
  static bool _isCityBlocked(String grad) {
    final normalizedGrad = grad.toLowerCase().trim();

    // Dozvoljeni gradovi: samo Vrsac i Bela Crkva opštine
    const allowedCities = [
      // Vrsac OPŠTINA
      'vrsac', 'straza', 'straža', 'vojvodinci', 'potporanj', 'oresac',
      'orešac',
      // BELA CRKVA OPŠTINA
      'bela crkva', 'vracev gaj', 'vraćev gaj', 'dupljaja', 'jasenovo',
      'kruscica', 'kruščica', 'kusic', 'kusić', 'crvena crkva',
    ];
    return !allowedCities.any((allowed) => normalizedGrad.contains(allowed));
  }
}
