import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'cache_service.dart';
import 'geocoding_stats_service.dart';

/// 🚀 ADVANCED GEOCODING SERVICE - Multiple providers, AI matching, auto-correction
/// 100% BESPLATNO sa enterprise-level funkcionalnostima!
class AdvancedGeocodingService {
  static const String _cachePrefix = 'advanced_geocoding_';
  static final Logger _logger = Logger();

  // 🌍 MULTIPLE FREE GEOCODING PROVIDERS - failover sistem
  static const Map<String, String> _providers = {
    'nominatim': 'https://nominatim.openstreetmap.org/search',
    'photon': 'https://photon.komoot.io/api/',
    'mapbox_free': 'https://api.mapbox.com/geocoding/v5/mapbox.places',
  };

  // 🎯 SERBIAN CITY ALIASES - samo Bela Crkva i Vršac opštine
  static const Map<String, List<String>> _cityAliases = {
    'Bela Crkva': ['BC', 'Bela', 'Бела Црква', 'bela crkva', 'BELA CRKVA'],
    'Vršac': ['Vrsac', 'VS', 'Вршац', 'vrsac', 'VRSAC'],
    // 🚫 OSTALI GRADOVI SU UKLONJENI - samo BC-Vršac relacija
  };

  // 🤖 AI FUZZY MATCHING - auto-ispravka grešaka
  static const Map<String, String> _commonTypos = {
    'ulica': 'ulica',
    'ulitse': 'ulice',
    'bul': 'bulevar',
    'blv': 'bulevar',
    'tr': 'trg',
    'bb': 'bez broja',
  };

  /// 🚀 MAIN GEOCODING FUNCTION - Enterprise level sa fallback
  static Future<GeocodeResult?> getAdvancedCoordinates({
    required String grad,
    required String adresa,
    bool useCache = true,
    bool enableFuzzyMatching = true,
    bool enableAutoCorrection = true,
    int maxRetries = 3,
  }) async {
    // 🚫 BLOKIRANJE: Samo Bela Crkva i Vršac opštine dozvoljene
    if (_isCityOutsideServiceArea(grad)) {
      _logger.w(
          '🚫 Advanced geocoding blokiran za $grad - van servisne oblasti BC/Vršac');
      return null;
    }

    try {
      // 1. 🧹 PREPROCESSING - čišćenje i normalizacija
      final processedGrad = _preprocessCity(grad);
      final processedAdresa = _preprocessAddress(adresa);
      final cacheKey = '${processedGrad}_$processedAdresa';

      // 2. 💾 CHECK CACHE FIRST
      if (useCache) {
        final cached = await _getCachedResult(cacheKey);
        if (cached != null) {
          await GeocodingStatsService.incrementCacheHits();
          _logger.i('✅ Cache hit: $cacheKey -> ${cached.confidence}%');
          return cached;
        }
      }

      // 3. 🔍 MULTI-PROVIDER SEARCH - probaj sve provider-e
      GeocodeResult? bestResult;
      double bestScore = 0.0;

      for (final providerName in _providers.keys) {
        try {
          final result = await _searchWithProvider(
            providerName,
            processedGrad,
            processedAdresa,
            enableFuzzyMatching: enableFuzzyMatching,
          );

          if (result != null && result.confidence > bestScore) {
            bestResult = result;
            bestScore = result.confidence;

            // Ako imamo high-confidence rezultat, prekini pretragu
            if (bestScore >= 85.0) break;
          }
        } catch (e) {
          _logger.w('⚠️ Provider $providerName failed: $e');
          continue;
        }
      }

      // 4. 🤖 AUTO-CORRECTION - pokušaj sa ispravkama
      if (bestResult == null || bestScore < 70.0) {
        if (enableAutoCorrection) {
          final correctedResult =
              await _tryAutoCorrection(processedGrad, processedAdresa);
          if (correctedResult != null &&
              correctedResult.confidence > bestScore) {
            bestResult = correctedResult;
          }
        }
      }

      // 5. 💾 SAVE TO CACHE
      if (bestResult != null && useCache) {
        await _cacheResult(cacheKey, bestResult);
        await GeocodingStatsService.incrementApiCalls();
        await GeocodingStatsService.addPopularLocation(cacheKey);
      }

      return bestResult;
    } catch (e) {
      _logger.e('❌ Advanced geocoding failed: $e');
      return null;
    }
  }

  /// 🔍 BATCH GEOCODING - optimizovano za više adresa odjednom
  static Future<Map<String, GeocodeResult?>> batchGeocode({
    required Map<String, String> addresses, // key -> address
    int batchSize = 10,
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    final results = <String, GeocodeResult?>{};
    final batches = _createBatches(addresses, batchSize);

    for (int i = 0; i < batches.length; i++) {
      final batch = batches[i];
      _logger.i(
          '📦 Processing batch ${i + 1}/${batches.length} (${batch.length} items)');

      // Paralelno geocoding za batch
      final futures = batch.map((entry) async {
        final parts = entry.value.split(',');
        if (parts.length >= 2) {
          final grad = parts[1].trim();
          final adresa = parts[0].trim();
          return MapEntry(entry.key,
              await getAdvancedCoordinates(grad: grad, adresa: adresa));
        }
        return MapEntry(entry.key, null);
      });

      final batchResults = await Future.wait(futures);
      for (final result in batchResults) {
        results[result.key] = result.value;
      }

      // Rate limiting
      if (i < batches.length - 1) {
        await Future<void>.delayed(delay);
      }
    }

    return results;
  }

  /// 🧹 PREPROCESS CITY - normalizacija i alias handling
  static String _preprocessCity(String city) {
    final normalized = city.trim();

    // Pronađi alias
    for (final entry in _cityAliases.entries) {
      if (entry.value
          .any((alias) => alias.toLowerCase() == normalized.toLowerCase())) {
        return entry.key;
      }
    }

    return normalized;
  }

  /// 🧹 PREPROCESS ADDRESS - čišćenje i normalizacija
  static String _preprocessAddress(String address) {
    var processed = address.trim().toLowerCase();

    // Auto-korekcije čestih grešaka
    for (final entry in _commonTypos.entries) {
      processed = processed.replaceAll(entry.key, entry.value);
    }

    // Ukloni dupli space
    processed = processed.replaceAll(RegExp(r'\s+'), ' ');

    return processed;
  }

  /// 🔍 SEARCH WITH SPECIFIC PROVIDER
  static Future<GeocodeResult?> _searchWithProvider(
    String providerName,
    String grad,
    String adresa, {
    bool enableFuzzyMatching = true,
  }) async {
    switch (providerName) {
      case 'nominatim':
        return await _searchNominatim(grad, adresa, enableFuzzyMatching);
      case 'photon':
        return await _searchPhoton(grad, adresa, enableFuzzyMatching);
      case 'mapbox_free':
        return await _searchMapboxFree(grad, adresa, enableFuzzyMatching);
      default:
        return null;
    }
  }

  /// 🌍 NOMINATIM SEARCH - enhanced sa fuzzy matching
  static Future<GeocodeResult?> _searchNominatim(
      String grad, String adresa, bool fuzzy) async {
    const timeout = Duration(seconds: 8);
    // 🎯 OGRANIČI QUERY na Bela Crkva/Vršac oblast
    final query = '$adresa, $grad, Južno-banatski okrug, Serbia';

    final url = '${_providers['nominatim']}?'
        'q=${Uri.encodeComponent(query)}&'
        'format=json&'
        'addressdetails=1&'
        'limit=3&'
        'accept-language=sr,en&'
        'countrycodes=rs&'
        'bounded=1&'
        'viewbox=20.8,44.7,21.8,45.2'; // Bounding box za BC/Vršac region

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'GavraAdvancedTransport/2.0 (geocoding@gavra.rs)',
        'Accept': 'application/json',
      },
    ).timeout(timeout);

    if (response.statusCode == 200) {
      final List<dynamic> results = json.decode(response.body) as List<dynamic>;
      if (results.isNotEmpty) {
        final best = results.first;
        final confidence = _calculateConfidence(
            adresa, grad, best as Map<String, dynamic>, 'nominatim');

        return GeocodeResult(
          latitude: double.parse(best['lat'] as String),
          longitude: double.parse(best['lon'] as String),
          formattedAddress: best['display_name'] as String,
          confidence: confidence,
          provider: 'nominatim',
          components: _parseNominatimComponents(best),
        );
      }
    }

    return null;
  }

  /// ⚡ PHOTON SEARCH - ultra-fast European geocoding
  static Future<GeocodeResult?> _searchPhoton(
      String grad, String adresa, bool fuzzy) async {
    const timeout = Duration(seconds: 5);
    final query = '$adresa $grad';

    final url = '${_providers['photon']}?'
        'q=${Uri.encodeComponent(query)}&'
        'limit=3&'
        'lang=sr&'
        'lon=21.4&lat=44.9&' // Vršac/Bela Crkva region bias
        'osm_tag=highway&osm_tag=building&osm_tag=amenity';

    final response = await http.get(Uri.parse(url)).timeout(timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final features = data['features'] as List<dynamic>?;

      if (features != null && features.isNotEmpty) {
        final best = features.first;
        final coords = best['geometry']['coordinates'];
        final props = best['properties'];

        final confidence = _calculateConfidence(
            adresa, grad, props as Map<String, dynamic>, 'photon');

        return GeocodeResult(
          latitude: (coords[1] as num).toDouble(),
          longitude: (coords[0] as num).toDouble(),
          formattedAddress:
              (props['name'] ?? props['label'] ?? '$adresa, $grad') as String,
          confidence: confidence,
          provider: 'photon',
          components: _parsePhotonComponents(props),
        );
      }
    }

    return null;
  }

  /// 🗺️ MAPBOX FREE SEARCH - 100k requests/month besplatno
  static Future<GeocodeResult?> _searchMapboxFree(
      String grad, String adresa, bool fuzzy) async {
    // NAPOMENA: Dodaj svoj Mapbox free token u environment
    const mapboxToken =
        String.fromEnvironment('MAPBOX_TOKEN', defaultValue: '');
    if (mapboxToken.isEmpty) return null;

    const timeout = Duration(seconds: 6);
    final query = '$adresa $grad Serbia';

    final url = '${_providers['mapbox_free']}/'
        '${Uri.encodeComponent(query)}.json?'
        'access_token=$mapboxToken&'
        'country=rs&'
        'proximity=21.4,44.9&' // Bias towards Vršac region
        'limit=3';

    final response = await http.get(Uri.parse(url)).timeout(timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final features = data['features'] as List<dynamic>?;

      if (features != null && features.isNotEmpty) {
        final best = features.first;
        final coords = best['geometry']['coordinates'];
        final props = best['properties'];

        final confidence = _calculateConfidence(
            adresa, grad, props as Map<String, dynamic>, 'mapbox');

        return GeocodeResult(
          latitude: (coords[1] as num).toDouble(),
          longitude: (coords[0] as num).toDouble(),
          formattedAddress: best['place_name'] as String,
          confidence: confidence,
          provider: 'mapbox',
          components: _parseMapboxComponents(best as Map<String, dynamic>),
        );
      }
    }

    return null;
  }

  /// 🤖 AUTO-CORRECTION - pokušava sa čestim greškama
  static Future<GeocodeResult?> _tryAutoCorrection(
      String grad, String adresa) async {
    final corrections = [
      adresa
          .replaceAll('č', 'c')
          .replaceAll('ć', 'c')
          .replaceAll('ž', 'z')
          .replaceAll('š', 's')
          .replaceAll('đ', 'd'),
      adresa.replaceAll(' ', ''), // bez space-ova
      adresa.replaceAll(RegExp(r'\d+'), ''), // bez brojeva
      '$adresa bb', // dodaj "bez broja"
    ];

    for (final correction in corrections) {
      if (correction != adresa) {
        final result = await _searchNominatim(grad, correction, false);
        if (result != null && result.confidence > 60.0) {
          // Kreiraj novi rezultat sa penalty za korekciju
          final correctedResult = GeocodeResult(
            latitude: result.latitude,
            longitude: result.longitude,
            formattedAddress: result.formattedAddress,
            confidence:
                math.max(result.confidence - 10, 0), // penalty za korekciju
            provider: result.provider,
            components: result.components,
            autocorrected: true,
            originalQuery: adresa,
          );
          return correctedResult;
        }
      }
    }

    return null;
  }

  /// 🧮 CALCULATE CONFIDENCE - AI scoring algorithm
  static double _calculateConfidence(
      String query, String city, Map<String, dynamic> result, String provider) {
    double score = 50.0; // base score

    // Provider reliability
    switch (provider) {
      case 'nominatim':
        score += 15;
        break;
      case 'photon':
        score += 10;
        break;
      case 'mapbox':
        score += 20;
        break;
    }

    // Address matching
    final resultText =
        (result['display_name'] ?? result['name'] ?? result['label'] ?? '')
            .toString()
            .toLowerCase();
    final queryLower = query.toLowerCase();

    if (resultText.contains(queryLower)) {
      score += 20;
    } else if (_fuzzyMatch(queryLower, resultText) > 0.7) {
      score += 15;
    }

    // City matching
    if (resultText.contains(city.toLowerCase())) {
      score += 10;
    }

    // Country check
    if (resultText.contains('serbia') || resultText.contains('srbija')) {
      score += 5;
    }

    return math.min(score, 100.0);
  }

  /// 🔤 FUZZY MATCHING - Levenshtein distance algorithm
  static double _fuzzyMatch(String a, String b) {
    if (a.isEmpty) return b.isEmpty ? 1.0 : 0.0;
    if (b.isEmpty) return 0.0;

    final matrix =
        List.generate(a.length + 1, (i) => List<int>.filled(b.length + 1, 0));

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = math.min(
          math.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
          matrix[i - 1][j - 1] + cost,
        );
      }
    }

    final distance = matrix[a.length][b.length];
    return 1.0 - (distance / math.max(a.length, b.length));
  }

  // Helper methods za parsing provider responses
  static Map<String, String> _parseNominatimComponents(
      Map<String, dynamic> result) {
    final address = result['address'] as Map<String, dynamic>? ?? {};
    return {
      'house_number': address['house_number']?.toString() ?? '',
      'road': address['road']?.toString() ?? '',
      'city': address['city']?.toString() ?? address['town']?.toString() ?? '',
      'postcode': address['postcode']?.toString() ?? '',
    };
  }

  static Map<String, String> _parsePhotonComponents(
      Map<String, dynamic> props) {
    return {
      'name': props['name']?.toString() ?? '',
      'street': props['street']?.toString() ?? '',
      'city': props['city']?.toString() ?? '',
      'postcode': props['postcode']?.toString() ?? '',
    };
  }

  static Map<String, String> _parseMapboxComponents(
      Map<String, dynamic> feature) {
    final context = feature['context'] as List<dynamic>? ?? [];
    final components = <String, String>{};

    for (final item in context) {
      final id = item['id']?.toString() ?? '';
      final text = item['text']?.toString() ?? '';

      if (id.startsWith('address')) components['house_number'] = text;
      if (id.startsWith('place')) components['city'] = text;
      if (id.startsWith('postcode')) components['postcode'] = text;
    }

    return components;
  }

  /// 💾 CACHE MANAGEMENT
  static Future<GeocodeResult?> _getCachedResult(String key) async {
    final cached = await CacheService.getFromDisk<String>(_cachePrefix + key,
        maxAge: const Duration(days: 30));
    if (cached != null) {
      try {
        return GeocodeResult.fromJson(
            json.decode(cached) as Map<String, dynamic>);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<void> _cacheResult(String key, GeocodeResult result) async {
    await CacheService.saveToDisk(
        _cachePrefix + key, json.encode(result.toJson()));
  }

  /// 📦 BATCH UTILITIES
  static List<List<MapEntry<String, String>>> _createBatches(
      Map<String, String> items, int batchSize) {
    final entries = items.entries.toList();
    final batches = <List<MapEntry<String, String>>>[];

    for (int i = 0; i < entries.length; i += batchSize) {
      batches.add(entries.sublist(i, math.min(i + batchSize, entries.length)));
    }

    return batches;
  }

  /// 🧹 CACHE MANAGEMENT
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_cachePrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  static Future<int> getCacheSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys().where((key) => key.startsWith(_cachePrefix)).length;
  }
}

/// 📍 GEOCODE RESULT CLASS - napredna struktura rezultata
class GeocodeResult {
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final double confidence; // 0-100
  final String provider;
  final Map<String, String> components;
  bool autocorrected;
  String? originalQuery;
  DateTime timestamp;

  GeocodeResult({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    required this.confidence,
    required this.provider,
    required this.components,
    this.autocorrected = false,
    this.originalQuery,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'formattedAddress': formattedAddress,
        'confidence': confidence,
        'provider': provider,
        'components': components,
        'autocorrected': autocorrected,
        'originalQuery': originalQuery,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GeocodeResult.fromJson(Map<String, dynamic> json) => GeocodeResult(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        formattedAddress: json['formattedAddress'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        provider: json['provider'] as String,
        components: Map<String, String>.from(json['components'] as Map),
        autocorrected: (json['autocorrected'] ?? false) as bool,
        originalQuery: json['originalQuery'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  @override
  String toString() =>
      '$formattedAddress (${confidence.toStringAsFixed(1)}% via $provider)';
}

/// 🚫 HELPER FUNKCIJA - proveri da li je grad van servisne oblasti
bool _isCityOutsideServiceArea(String grad) {
  final normalizedGrad = grad
      .toLowerCase()
      .trim()
      .replaceAll('š', 's')
      .replaceAll('đ', 'd')
      .replaceAll('č', 'c')
      .replaceAll('ć', 'c')
      .replaceAll('ž', 'z');

  // ✅ SERVISNA OBLAST: SAMO Bela Crkva i Vršac opštine
  final serviceAreaCities = [
    // VRŠAC OPŠTINA
    'vrsac', 'straza', 'vojvodinci', 'potporanj', 'oresac',
    // BELA CRKVA OPŠTINA
    'bela crkva', 'vracev gaj', 'vraćev gaj', 'dupljaja', 'jasenovo',
    'kruscica', 'kusic', 'crvena crkva'
  ];
  return !serviceAreaCities.any(
      (city) => normalizedGrad.contains(city) || city.contains(normalizedGrad));
}
