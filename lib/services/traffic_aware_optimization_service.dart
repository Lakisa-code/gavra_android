import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gavra_android/geolocator.dart';
import '../models/putnik.dart';

/// 🚦 TRAFFIC-AWARE OPTIMIZACIJA
/// Koristi Google Traffic API za real-time optimizaciju ruta
class TrafficAwareOptimizationService {
  static const String _googleApiKey = 'AIzaSyBOhQKU9YoA1z_h_N_y_XhbOL5gHWZXqPY';
  static const String _distanceMatrixApiUrl =
      'https://maps.googleapis.com/maps/api/distancematrix/json';

  // Cache za traffic podatke (važi 10 minuta)
  static final Map<String, Map<String, dynamic>> _trafficCache = {};
  static final Map<String, DateTime> _trafficCacheTimestamps = {};
  static const int _trafficCacheValidityMinutes = 10;

  /// 🚦 Optimizuj rutu uzimajući u obzir trenutno stanje saobraćaja
  static Future<List<Putnik>> optimizeWithTraffic(
    List<Putnik> route,
    Map<Putnik, Position> coordinates,
    DateTime departureTime, {
    Position? startPosition,
  }) async {
    if (route.length <= 1) return route;

    try {
      // 1. Dobij traffic matrix za sve parove lokacija
      final trafficMatrix = await _getTrafficMatrix(
        route,
        coordinates,
        departureTime,
        startPosition: startPosition,
      );

      if (trafficMatrix.isEmpty) {
        return route;
      }

      // 2. Optimizuj rutu na osnovu traffic podataka
      final optimizedRoute = await _optimizeRouteWithTrafficData(
        route,
        coordinates,
        trafficMatrix,
        startPosition: startPosition,
      );

      // 3. Loguj poboljšanja
      await _logTrafficOptimizationResults(
          route, optimizedRoute, trafficMatrix);

      return optimizedRoute;
    } catch (e) {
      return route;
    }
  }

  /// 📊 Dobij traffic matrix između svih lokacija
  static Future<Map<String, Map<String, dynamic>>> _getTrafficMatrix(
    List<Putnik> putnici,
    Map<Putnik, Position> coordinates,
    DateTime departureTime, {
    Position? startPosition,
  }) async {
    // Kreiraj listu svih lokacija (start + putnici)
    final allLocations = <String>[];
    final locationToIndex = <String, int>{};

    // Dodaj start poziciju
    if (startPosition != null) {
      final startCoord = '${startPosition.latitude},${startPosition.longitude}';
      allLocations.add(startCoord);
      locationToIndex['START'] = 0;
    }

    // Dodaj koordinate putnika
    for (final putnik in putnici) {
      final position = coordinates[putnik];
      if (position != null) {
        final coord = '${position.latitude},${position.longitude}';
        allLocations.add(coord);
        locationToIndex[putnik.id.toString()] = allLocations.length - 1;
      }
    }

    if (allLocations.length < 2) return {};

    // Proveri cache
    final cacheKey = _generateTrafficCacheKey(allLocations, departureTime);
    final cached = _getTrafficFromCache(cacheKey);
    if (cached != null) {
      return cached;
    }

    try {
      // Google Distance Matrix API poziv
      final origins = allLocations.join('|');
      final destinations = allLocations.join('|');

      final departureTimeSeconds = departureTime.millisecondsSinceEpoch ~/ 1000;

      final url = Uri.parse('$_distanceMatrixApiUrl?'
          'origins=$origins&'
          'destinations=$destinations&'
          'departure_time=$departureTimeSeconds&'
          'traffic_model=best_guess&'
          'units=metric&'
          'key=$_googleApiKey');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final trafficMatrix =
              _parseTrafficMatrix(data, allLocations, locationToIndex);

          // Cache rezultat
          _cacheTrafficData(cacheKey, trafficMatrix);

          return trafficMatrix;
        } else {
          // Response je prazan ili nema sadržaj
        }
      } else {
        // Status kod nije 200
      }
    } catch (e) {
      // Greška u pozivu API-ja
    }

    return {};
  }

  /// 🧮 Optimizuj rutu koristeći traffic podatke
  static Future<List<Putnik>> _optimizeRouteWithTrafficData(
    List<Putnik> route,
    Map<Putnik, Position> coordinates,
    Map<String, Map<String, dynamic>> trafficMatrix, {
    Position? startPosition,
  }) async {
    if (route.length <= 1) return route;

    // Implementiraj modified nearest neighbor sa traffic faktorima
    final optimizedRoute = <Putnik>[];
    final unvisited = Set<Putnik>.from(route);
    String currentLocation = 'START';

    while (unvisited.isNotEmpty) {
      Putnik? nextBest;
      double bestScore = double.infinity;

      for (final candidate in unvisited) {
        final candidateId = candidate.id.toString();

        // Dobij traffic podatke između trenutne i kandidat lokacije
        final trafficInfo = trafficMatrix[currentLocation]?[candidateId];

        if (trafficInfo != null) {
          // Kombinuj distancu, vreme i traffic faktor
          final distance = trafficInfo['distance'] ?? 1000.0;
          final duration = trafficInfo['duration'] ?? 600.0;
          final trafficDuration =
              trafficInfo['duration_in_traffic'] ?? duration;

          // Izračunaj traffic delay faktor
          final trafficDelay = trafficDuration / duration;

          // Composite score: kombinuje distancu i traffic delay
          final score = distance * trafficDelay;

          if (score < bestScore) {
            bestScore = score;
            nextBest = candidate;
          }
        }
      }

      // Fallback na nearest neighbor ako nema traffic podataka
      if (nextBest == null && unvisited.isNotEmpty) {
        nextBest = unvisited.first;
      }

      if (nextBest != null) {
        optimizedRoute.add(nextBest);
        currentLocation = nextBest.id.toString();
        unvisited.remove(nextBest);
      }
    }

    return optimizedRoute;
  }

  /// 📈 Parsiraj Google Distance Matrix odgovor
  static Map<String, Map<String, dynamic>> _parseTrafficMatrix(
    Map<String, dynamic> apiResponse,
    List<String> locations,
    Map<String, int> locationToIndex,
  ) {
    final matrix = <String, Map<String, dynamic>>{};

    try {
      final rows = apiResponse['rows'] as List;

      for (int i = 0; i < rows.length; i++) {
        final fromKey = i == 0 ? 'START' : (i - 1).toString();
        matrix[fromKey] = {};

        final elements = rows[i]['elements'] as List;

        for (int j = 0; j < elements.length; j++) {
          final toKey = j == 0 ? 'START' : (j - 1).toString();
          final element = elements[j];

          if (element['status'] == 'OK') {
            matrix[fromKey]![toKey] = {
              'distance': element['distance']['value'].toDouble(),
              'duration': element['duration']['value'].toDouble(),
              'duration_in_traffic':
                  element['duration_in_traffic']?['value']?.toDouble() ??
                      element['duration']['value'].toDouble(),
            };
          }
        }
      }
    } catch (e) {
      // Greška u parsiranju traffic matrix podataka
    }

    return matrix;
  }

  /// 🏎️ Traffic cache funkcije
  static String _generateTrafficCacheKey(
      List<String> locations, DateTime departureTime) {
    final locationsHash = locations.join('|');
    final timeKey =
        '${departureTime.hour}:${(departureTime.minute ~/ 15) * 15}'; // Round to 15min
    return 'traffic_${locationsHash.hashCode}_$timeKey';
  }

  static Map<String, Map<String, dynamic>>? _getTrafficFromCache(
      String cacheKey) {
    final cached = _trafficCache[cacheKey];
    final timestamp = _trafficCacheTimestamps[cacheKey];

    if (cached != null && timestamp != null) {
      final isValid = DateTime.now().difference(timestamp).inMinutes <
          _trafficCacheValidityMinutes;
      if (isValid) {
        return Map<String, Map<String, dynamic>>.from(cached);
      } else {
        _trafficCache.remove(cacheKey);
        _trafficCacheTimestamps.remove(cacheKey);
      }
    }

    return null;
  }

  static void _cacheTrafficData(
      String cacheKey, Map<String, Map<String, dynamic>> data) {
    _trafficCache[cacheKey] = data;
    _trafficCacheTimestamps[cacheKey] = DateTime.now();

    // Cleanup old cache if too big
    if (_trafficCache.length > 20) {
      final oldestKey = _trafficCacheTimestamps.entries
          .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
          .key;
      _trafficCache.remove(oldestKey);
      _trafficCacheTimestamps.remove(oldestKey);
    }
  }

  /// 📊 Loguj rezultate optimizacije
  static Future<void> _logTrafficOptimizationResults(
    List<Putnik> originalRoute,
    List<Putnik> optimizedRoute,
    Map<String, Map<String, dynamic>> trafficMatrix,
  ) async {
    try {
      // Log optimization results for monitoring when needed
      // Traffic-aware optimization completed successfully
    } catch (e) {
      // Greška u logovanju rezultata optimizacije
    }
  }

  /// 🧹 Očisti traffic cache
  static void clearTrafficCache() {
    _trafficCache.clear();
    _trafficCacheTimestamps.clear();
  }

  /// 📊 Traffic cache statistike
  static Map<String, dynamic> getTrafficCacheStats() {
    return {
      'cacheSize': _trafficCache.length,
      'validEntries': _trafficCache.keys.where((key) {
        final timestamp = _trafficCacheTimestamps[key];
        return timestamp != null &&
            DateTime.now().difference(timestamp).inMinutes <
                _trafficCacheValidityMinutes;
      }).length,
      'maxCacheSize': 20,
    };
  }

  /// 🚨 Dobij trenutne traffic alerts za rutu
  static Future<List<String>> getTrafficAlerts(
    List<Putnik> route,
    Map<Putnik, Position> coordinates,
  ) async {
    final alerts = <String>[];

    try {
      // Simplified traffic alerts - u produkciji bi se koristio Google Traffic API
      for (int i = 0; i < route.length - 1; i++) {
        final current = coordinates[route[i]];
        final next = coordinates[route[i + 1]];

        if (current != null && next != null) {
          // Simuliraj traffic alert na osnovu udaljenosti i vremena
          final distance = Geolocator.distanceBetween(
            current.latitude,
            current.longitude,
            next.latitude,
            next.longitude,
          );

          // Ako je udaljenost velika, možda ima gužve
          if (distance > 5000) {
            // 5km+
            alerts.add(
                '⚠️ Duži segment između ${route[i].ime} i ${route[i + 1].ime} - možda ima gužve');
          }
        }
      }
    } catch (e) {
      // Greška u generisanju traffic alerts
    }

    return alerts;
  }
}
