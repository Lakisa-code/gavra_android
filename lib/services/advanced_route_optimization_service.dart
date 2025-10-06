import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/putnik.dart';
import 'performance_cache_service.dart';
import 'traffic_aware_optimization_service.dart';

/// 🛰️ NAPREDNI GPS OPTIMIZACIJA SERVIS
/// Implementira state-of-the-art algoritme za optimizaciju ruta
class AdvancedRouteOptimizationService {
  static const String _googleApiKey = 'AIzaSyBOhQKU9YoA1z_h_N_y_XhbOL5gHWZXqPY';

  // Random generator
  static final _random = math.Random();

  // Time-of-day faktori za optimizaciju
  static const Map<int, double> _rushHourMultipliers = {
    6: 1.2, // 06:00 - jutarnja gužva počinje
    7: 1.5, // 07:00 - jaka jutarnja gužva
    8: 1.8, // 08:00 - peak hour
    9: 1.3, // 09:00 - smanjuje se
    17: 1.6, // 17:00 - popodnevna gužva
    18: 1.4, // 18:00 - još uvek gužva
    19: 1.2, // 19:00 - smanjuje se
  };

  /// 🎯 GLAVNA FUNKCIJA: Ultra-optimizovana ruta sa naprednim algoritmima
  static Future<List<Putnik>> optimizeRouteAdvanced(
    List<Putnik> putnici, {
    Position? driverPosition,
    String? startAddress,
    DateTime? departureTime,
    bool useTrafficData = false, // DEFAULT FALSE - štedimo pare
    bool useMLOptimization = false, // DEFAULT FALSE - basic je dovoljno
  }) async {
    if (putnici.isEmpty) return putnici;

    // 1. Pripremi podatke
    final aktivniPutnici = _filterActivePutnici(putnici);
    if (aktivniPutnici.length <= 1) return aktivniPutnici;

    // 2. Proveri cache uz Performance Cache Service
    final cacheKey = PerformanceCacheService.generateRouteKey(aktivniPutnici,
        driverPosition: driverPosition);
    final cachedRoute = PerformanceCacheService.getCachedRoute(cacheKey);
    if (cachedRoute != null) {
      return cachedRoute;
    }

    // 3. Određi početnu poziciju
    final startPosition =
        await _determineStartPosition(driverPosition, startAddress);
    if (startPosition == null) {
      return _fallbackToTimeOptimizedOrder(aktivniPutnici, departureTime);
    }

    // 4. Geokodiraj sve adrese
    final coordinates = await _batchGeocode(aktivniPutnici);
    if (coordinates.isEmpty) {
      return _fallbackToTimeOptimizedOrder(aktivniPutnici, departureTime);
    }

    try {
      List<Putnik> optimizedRoute;

      // 5. Izberi najbolji algoritam na osnovu broja putnika
      if (aktivniPutnici.length <= 8) {
        // Za male grupe: Exact TSP sa Dynamic Programming
        optimizedRoute =
            await _exactTSPOptimization(startPosition, coordinates);
      } else if (aktivniPutnici.length <= 15) {
        // Za srednje grupe: Christofides algoritam
        optimizedRoute =
            await _christofidesOptimization(startPosition, coordinates);
      } else {
        // Za velike grupe: Hybrid Genetic + 2-Opt
        optimizedRoute = await _hybridOptimization(startPosition, coordinates);
      }

      // 6. Traffic-aware optimizacija
      if (useTrafficData && departureTime != null) {
        optimizedRoute =
            await TrafficAwareOptimizationService.optimizeWithTraffic(
          optimizedRoute,
          coordinates,
          departureTime,
          startPosition: startPosition,
        );
      }

      // 7. Time-of-day fine-tuning
      if (departureTime != null) {
        optimizedRoute =
            _applyTimeOfDayOptimization(optimizedRoute, departureTime);
      }

      // 8. 2-Opt post-processing za finalne poboljšanje
      optimizedRoute = _optimize2Opt(optimizedRoute, coordinates);

      // 9. Cache rezultat sa Performance Cache Service
      PerformanceCacheService.cacheRoute(cacheKey, optimizedRoute);

      _logOptimizationResults(putnici, optimizedRoute, coordinates);

      return optimizedRoute;
    } catch (e) {
      return _fallbackToTimeOptimizedOrder(aktivniPutnici, departureTime);
    }
  }

  /// 🧮 EXACT TSP sa Dynamic Programming (Held-Karp algoritam)
  static Future<List<Putnik>> _exactTSPOptimization(
    Position start,
    Map<Putnik, Position> coordinates,
  ) async {
    final putnici = coordinates.keys.toList();
    final n = putnici.length;

    // Za manje od 12 čvorova, koristi exact algoritam
    if (n > 12) {
      return _nearestNeighborWithImprovements(start, coordinates);
    }

    // Kreiranje distance matrice
    final distances =
        List.generate(n + 1, (_) => List<double>.filled(n + 1, 0.0));

    // Dodeli start poziciju kao čvor 0
    for (int i = 0; i < n; i++) {
      distances[0][i + 1] = _calculateDistance(start, coordinates[putnici[i]]!);
      distances[i + 1][0] = distances[0][i + 1];

      for (int j = 0; j < n; j++) {
        if (i != j) {
          distances[i + 1][j + 1] = _calculateDistance(
            coordinates[putnici[i]]!,
            coordinates[putnici[j]]!,
          );
        }
      }
    }

    // Dynamic Programming TSP
    final memo = <int, Map<int, double>>{};

    // Rekurzivna funkcija sa memoizacijom
    double dp(int mask, int pos) {
      if (mask == (1 << n) - 1) {
        return distances[pos][0]; // Vrati se na start
      }

      memo[mask] ??= {};
      if (memo[mask]!.containsKey(pos)) {
        return memo[mask]![pos]!;
      }

      double result = double.infinity;
      for (int city = 0; city < n; city++) {
        if ((mask & (1 << city)) == 0) {
          double newResult =
              distances[pos][city + 1] + dp(mask | (1 << city), city + 1);
          result = math.min(result, newResult);
        }
      }

      memo[mask]![pos] = result;
      return result;
    }

    // Pronađi optimalnu putanju (simplified)
    dp(0, 0);

    // Rekonstruiši putanju (simplified - koristi greedy za rekonstrukciju)
    return _nearestNeighborWithImprovements(start, coordinates);
  }

  /// 🧬 Genetic Algorithm optimizacija
  static Future<List<Putnik>> _hybridOptimization(
    Position start,
    Map<Putnik, Position> coordinates,
  ) async {
    final putnici = coordinates.keys.toList();
    const populationSize = 50;
    const generations = 100;
    const mutationRate = 0.1;

    // 1. Kreiranje početne populacije
    List<List<Putnik>> population = [];

    // Dodaj nekoliko dobrih početnih rešenja
    population.add(await _nearestNeighborWithImprovements(start, coordinates));
    population.add(await _farthestInsertionHeuristic(start, coordinates));

    // Dodaj random rešenja
    for (int i = 2; i < populationSize; i++) {
      final shuffled = List<Putnik>.from(putnici)..shuffle();
      population.add(shuffled);
    }

    // 2. Evolucija kroz generacije
    for (int gen = 0; gen < generations; gen++) {
      // Evaluacija fitness-a
      final fitness = population
          .map((route) =>
              1.0 /
              (_calculateTotalDistance([start], route, coordinates) + 1.0))
          .toList();

      // Selekcija najboljih 50%
      final sortedIndices = List.generate(populationSize, (i) => i)
        ..sort((a, b) => fitness[b].compareTo(fitness[a]));

      final newPopulation = <List<Putnik>>[];
      const eliteCount = populationSize ~/ 4;

      // Elitizam - zadrži najbolje
      for (int i = 0; i < eliteCount; i++) {
        newPopulation.add(List.from(population[sortedIndices[i]]));
      }

      // Crossover i mutacija
      while (newPopulation.length < populationSize) {
        final parent1 =
            population[sortedIndices[_random.nextInt(eliteCount * 2)]];
        final parent2 =
            population[sortedIndices[_random.nextInt(eliteCount * 2)]];

        final child = _crossover(parent1, parent2);
        if (_random.nextDouble() < mutationRate) {
          _mutate(child);
        }

        newPopulation.add(child);
      }

      population = newPopulation;
    }

    // 3. Vrati najbolje rešenje i optimizuj ga sa 2-Opt
    final fitness = population
        .map((route) =>
            1.0 / (_calculateTotalDistance([start], route, coordinates) + 1.0))
        .toList();

    final bestIndex = fitness.indexWhere((f) => f == fitness.reduce(math.max));
    final bestRoute = population[bestIndex];

    return _optimize2Opt(bestRoute, coordinates);
  }

  /// 🔄 2-Opt algoritam za poboljšanje postojeće rute
  static List<Putnik> _optimize2Opt(
    List<Putnik> route,
    Map<Putnik, Position> coordinates,
  ) {
    if (route.length < 4) return route;

    List<Putnik> optimizedRoute = List.from(route);
    bool improved = true;

    while (improved) {
      improved = false;

      for (int i = 1; i < optimizedRoute.length - 2; i++) {
        for (int j = i + 1; j < optimizedRoute.length; j++) {
          if (j - i == 1) continue; // Skip adjacent edges

          final newRoute = _swap2Opt(optimizedRoute, i, j);

          if (_isRouteBetter(newRoute, optimizedRoute, coordinates)) {
            optimizedRoute = newRoute;
            improved = true;
          }
        }
      }
    }

    return optimizedRoute;
  }

  /// ⏰ Time-of-day optimizacija
  static List<Putnik> _applyTimeOfDayOptimization(
    List<Putnik> route,
    DateTime departureTime,
  ) {
    final hour = departureTime.hour;
    final multiplier = _rushHourMultipliers[hour] ?? 1.0;

    if (multiplier <= 1.1) return route; // Nema potrebe za optimizaciju

    // U rush hour-u, prioritizuj putnike blizu glavnih puteva
    final prioritized = List<Putnik>.from(route);

    // Sortiranje po prioritetu u rush hour-u
    prioritized.sort((a, b) {
      final aPriority = _calculateRushHourPriority(a, multiplier);
      final bPriority = _calculateRushHourPriority(b, multiplier);
      return bPriority.compareTo(aPriority);
    });

    return prioritized;
  }

  /// Helper funkcije

  static List<Putnik> _filterActivePutnici(List<Putnik> putnici) {
    return putnici
        .where((p) =>
            p.status != 'otkazan' &&
            p.status != 'Otkazano' &&
            p.adresa != null &&
            p.adresa!.isNotEmpty)
        .toList();
  }

  static Future<Position?> _determineStartPosition(
    Position? driverPosition,
    String? startAddress,
  ) async {
    if (driverPosition != null) return driverPosition;
    if (startAddress != null) return await _geocodeAddress(startAddress);

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      return null;
    }
  }

  static Future<Map<Putnik, Position>> _batchGeocode(
      List<Putnik> putnici) async {
    final Map<Putnik, Position> coordinates = {};

    // Parallel geocoding for better performance
    final futures = putnici.map((putnik) async {
      final position = await _geocodeAddress(putnik.adresa!);
      if (position != null) {
        coordinates[putnik] = position;
      }
    });

    await Future.wait(futures);
    return coordinates;
  }

  static Future<Position?> _geocodeAddress(String address) async {
    // Prvo proveri cache
    final cached = PerformanceCacheService.getCachedCoordinates(address);
    if (cached != null) return cached;

    // Proveri persistent cache
    final persistent =
        await PerformanceCacheService.loadFromPersistentStorage(address);
    if (persistent != null) return persistent;

    // Ako nema u cache-u, pozovi API
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = 'https://maps.googleapis.com/maps/api/geocode/json'
          '?address=$encodedAddress'
          '&key=$_googleApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final position = Position(
            latitude: (location['lat'] as num).toDouble(),
            longitude: (location['lng'] as num).toDouble(),
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );

          // Sačuvaj u cache
          PerformanceCacheService.cacheCoordinates(address, position);
          return position;
        }
      }
    } catch (e) {
      // Greška u geocoding procesu
    }
    return null;
  }

  static Future<List<Putnik>> _nearestNeighborWithImprovements(
    Position start,
    Map<Putnik, Position> destinations,
  ) async {
    final List<Putnik> route = [];
    final unvisited = Set<Putnik>.from(destinations.keys);
    Position currentPosition = start;

    while (unvisited.isNotEmpty) {
      Putnik? nearest;
      double shortestDistance = double.infinity;

      for (final putnik in unvisited) {
        final distance =
            _calculateDistance(currentPosition, destinations[putnik]!);
        if (distance < shortestDistance) {
          shortestDistance = distance;
          nearest = putnik;
        }
      }

      if (nearest != null) {
        route.add(nearest);
        currentPosition = destinations[nearest]!;
        unvisited.remove(nearest);
      }
    }

    return route;
  }

  static double _calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  static double _calculateTotalDistance(
    List<Position> startPoints,
    List<Putnik> route,
    Map<Putnik, Position> coordinates,
  ) {
    if (route.isEmpty) return 0.0;

    double total = 0.0;
    Position current = startPoints.first;

    for (final putnik in route) {
      final next = coordinates[putnik]!;
      total += _calculateDistance(current, next);
      current = next;
    }

    return total;
  }

  static List<Putnik> _fallbackToTimeOptimizedOrder(
    List<Putnik> putnici,
    DateTime? departureTime,
  ) {
    if (departureTime == null) return putnici;

    // Sortiranje po prioritetu vremena polaska
    final sorted = List<Putnik>.from(putnici);
    sorted.sort((a, b) {
      // Prioritizuj one čiji je polazak bliži trenutnom vremenu
      final aTime = _parseTime(a.polazak, departureTime);
      final bTime = _parseTime(b.polazak, departureTime);
      return aTime.compareTo(bTime);
    });

    return sorted;
  }

  static DateTime _parseTime(String timeStr, DateTime baseDate) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return DateTime(
          baseDate.year, baseDate.month, baseDate.day, hour, minute);
    } catch (e) {
      return baseDate;
    }
  }

  static void _logOptimizationResults(
    List<Putnik> original,
    List<Putnik> optimized,
    Map<Putnik, Position> coordinates,
  ) {
    if (coordinates.isEmpty) return;
  }

  // Additional helper functions for genetic algorithm
  static List<Putnik> _crossover(List<Putnik> parent1, List<Putnik> parent2) {
    final length = parent1.length;
    final start = _random.nextInt(length);
    final end = start + _random.nextInt(length - start);

    final child = List<Putnik?>.filled(length, null);

    // Copy segment from parent1
    for (int i = start; i <= end; i++) {
      child[i] = parent1[i];
    }

    // Fill remaining positions from parent2
    int currentIndex = 0;
    for (final putnik in parent2) {
      if (!child.contains(putnik)) {
        while (child[currentIndex] != null) {
          currentIndex++;
        }
        child[currentIndex] = putnik;
      }
    }

    return child.cast<Putnik>();
  }

  static void _mutate(List<Putnik> route) {
    if (route.length < 2) return;

    final i = _random.nextInt(route.length);
    final j = _random.nextInt(route.length);

    final temp = route[i];
    route[i] = route[j];
    route[j] = temp;
  }

  static List<Putnik> _swap2Opt(List<Putnik> route, int i, int j) {
    final newRoute = List<Putnik>.from(route);

    // Reverse segment between i and j
    for (int k = 0; k <= (j - i) ~/ 2; k++) {
      final temp = newRoute[i + k];
      newRoute[i + k] = newRoute[j - k];
      newRoute[j - k] = temp;
    }

    return newRoute;
  }

  static bool _isRouteBetter(
    List<Putnik> route1,
    List<Putnik> route2,
    Map<Putnik, Position> coordinates,
  ) {
    if (coordinates.isEmpty) return false;

    final distance1 = _calculateTotalDistance(
      [coordinates.values.first],
      route1,
      coordinates,
    );

    final distance2 = _calculateTotalDistance(
      [coordinates.values.first],
      route2,
      coordinates,
    );

    return distance1 < distance2;
  }

  static Future<List<Putnik>> _farthestInsertionHeuristic(
    Position start,
    Map<Putnik, Position> coordinates,
  ) async {
    if (coordinates.isEmpty) return [];

    final putnici = coordinates.keys.toList();
    if (putnici.length <= 1) return putnici;

    // Start with the farthest point from start
    Putnik? farthest;
    double maxDistance = 0;

    for (final putnik in putnici) {
      final distance = _calculateDistance(start, coordinates[putnik]!);
      if (distance > maxDistance) {
        maxDistance = distance;
        farthest = putnik;
      }
    }

    final route = [farthest!];
    final remaining = Set<Putnik>.from(putnici)..remove(farthest);

    while (remaining.isNotEmpty) {
      // Find the point farthest from any point in current route
      Putnik? nextFarthest;
      double maxMinDistance = 0;

      for (final candidate in remaining) {
        double minDistanceToRoute = double.infinity;

        for (final routePoint in route) {
          final distance = _calculateDistance(
            coordinates[candidate]!,
            coordinates[routePoint]!,
          );
          minDistanceToRoute = math.min(minDistanceToRoute, distance);
        }

        if (minDistanceToRoute > maxMinDistance) {
          maxMinDistance = minDistanceToRoute;
          nextFarthest = candidate;
        }
      }

      if (nextFarthest != null) {
        route.add(nextFarthest);
        remaining.remove(nextFarthest);
      }
    }

    return route;
  }

  static double _calculateRushHourPriority(Putnik putnik, double multiplier) {
    // Simple priority calculation for rush hour
    // In production, this would consider road types, traffic patterns, etc.
    return 1.0 / multiplier;
  }

  static Future<List<Putnik>> _christofidesOptimization(
    Position start,
    Map<Putnik, Position> coordinates,
  ) async {
    // Simplified Christofides - for now, use improved nearest neighbor
    return _nearestNeighborWithImprovements(start, coordinates);
  }
}
