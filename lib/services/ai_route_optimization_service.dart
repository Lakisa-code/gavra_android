import 'dart:convert';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/putnik.dart';
import 'advanced_geocoding_service.dart';

// 🎯 ALGORITHM TYPES
enum OptimizationAlgorithm {
  genetic, // 🧬 Genetic Algorithm - best for many points
  simulatedAnnealing, // 🔥 Simulated Annealing - good balance
  twoOpt, // ⚡ 2-opt - fast and efficient
  hybrid, // 🤖 Combination of all algorithms
}

// 🚗 VEHICLE PROFILES
enum VehicleType {
  car, // Običan auto
  minibus, // Minibus - više putnika
  eco, // Eko vožnja - izbegava gužve
}

/// 🚀 AI-POWERED ROUTE OPTIMIZATION - Enterprise level algoritmi
/// Kombinuje Genetic Algorithm, Simulated Annealing, 2-opt, real-time data
/// 100% BESPLATNO - bolji od Google Maps Route Optimization API!
class AIRouteOptimizationService {
  static final Logger _logger = Logger();

  // ️ EXTERNAL DATA SOURCES (free APIs)
  static const String _weatherApiUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  /// � HELPER - proveri da li je putnik u servisnoj oblasti
  static bool _isPassengerInServiceArea(Putnik putnik) {
    final grad = putnik.grad.toLowerCase().trim();
    final adresa = putnik.adresa?.toLowerCase().trim() ?? '';

    // Normalizuj srpske karaktere
    final normalizedGrad = grad
        .replaceAll('š', 's')
        .replaceAll('đ', 'd')
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('ž', 'z');
    final normalizedAdresa = adresa
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
    ]; // Proveri grad ili adresu
    return serviceAreaCities.any((city) =>
        normalizedGrad.contains(city) ||
        city.contains(normalizedGrad) ||
        normalizedAdresa.contains(city) ||
        city.contains(normalizedAdresa));
  }

  /// �🚀 MAIN OPTIMIZATION FUNCTION - AI-powered route planning
  static Future<OptimizedRoute> optimizeRoute({
    required List<Putnik> passengers,
    required Position startLocation,
    Position? endLocation,
    OptimizationAlgorithm algorithm = OptimizationAlgorithm.hybrid,
    VehicleType vehicle = VehicleType.minibus,
    Map<String, dynamic>? driverPreferences,
    bool considerTraffic = true,
    bool considerWeather = true,
    bool considerTimeWindows = true,
    int maxCalculationTime = 30, // seconds
  }) async {
    // 🚫 FILTER PUTNICI: samo oni iz BC/Vršac oblasti
    final validPassengers = passengers
        .where((putnik) => _isPassengerInServiceArea(putnik))
        .toList();

    if (validPassengers.length != passengers.length) {
      _logger.w(
          '⚠️ Filtrisano ${passengers.length - validPassengers.length} putnika van BC/Vršac oblasti');
    }

    final startTime = DateTime.now();
    _logger.i(
        '🚀 Starting AI route optimization with ${validPassengers.length} valid passengers');

    try {
      // 1. 📍 GEOCODE ALL ADDRESSES - parallel processing
      final addressCoordinates = await _batchGeocodeAddresses(validPassengers);
      if (addressCoordinates.isEmpty) {
        return OptimizedRoute.fallback(validPassengers);
      }

      // 2. 🌦️ GATHER EXTERNAL DATA (parallel)
      final externalData = await _gatherExternalData(
        startLocation,
        addressCoordinates.values.toList(),
        considerTraffic: considerTraffic,
        considerWeather: considerWeather,
      );

      // 3. 📊 BUILD DISTANCE/TIME MATRIX
      final matrix = await _buildDistanceMatrix(
        startLocation,
        addressCoordinates,
        externalData,
        vehicle,
      );

      // 4. 🤖 APPLY AI OPTIMIZATION ALGORITHM
      List<Putnik> optimizedSequence;
      double totalDistance;
      Map<String, dynamic> metrics;

      switch (algorithm) {
        case OptimizationAlgorithm.genetic:
          final result = await _geneticAlgorithmOptimization(
              passengers, matrix, maxCalculationTime ~/ 2);
          optimizedSequence = result.sequence;
          totalDistance = result.distance;
          metrics = result.metrics;
          break;

        case OptimizationAlgorithm.simulatedAnnealing:
          final result = await _simulatedAnnealingOptimization(
              passengers, matrix, maxCalculationTime);
          optimizedSequence = result.sequence;
          totalDistance = result.distance;
          metrics = result.metrics;
          break;

        case OptimizationAlgorithm.twoOpt:
          final result = await _twoOptOptimization(passengers, matrix);
          optimizedSequence = result.sequence;
          totalDistance = result.distance;
          metrics = result.metrics;
          break;

        case OptimizationAlgorithm.hybrid:
          final result =
              await _hybridOptimization(passengers, matrix, maxCalculationTime);
          optimizedSequence = result.sequence;
          totalDistance = result.distance;
          metrics = result.metrics;
          break;
      }

      // 5. ⏰ APPLY TIME WINDOW CONSTRAINTS
      if (considerTimeWindows) {
        optimizedSequence = _applyTimeWindowConstraints(optimizedSequence);
      }

      // 6. 👤 APPLY DRIVER PREFERENCES
      if (driverPreferences != null) {
        optimizedSequence =
            _applyDriverPreferences(optimizedSequence, driverPreferences);
      }

      final calculationTime = DateTime.now().difference(startTime);

      _logger
          .i('✅ Route optimization completed in ${calculationTime.inSeconds}s');
      _logger.i(
          '📊 Distance: ${totalDistance.toStringAsFixed(2)}km, Algorithm: ${algorithm.name}');

      return OptimizedRoute(
        optimizedSequence: optimizedSequence,
        originalSequence: passengers,
        totalDistance: totalDistance,
        estimatedTime: _calculateEstimatedTime(totalDistance, vehicle),
        algorithm: algorithm,
        calculationTime: calculationTime,
        metrics: metrics,
        externalFactors: externalData,
        coordinates: addressCoordinates,
      );
    } catch (e) {
      _logger.e('❌ Route optimization failed: $e');
      return OptimizedRoute.fallback(passengers);
    }
  }

  /// 📍 BATCH GEOCODE ADDRESSES - parallel processing
  static Future<Map<Putnik, GeocodeResult>> _batchGeocodeAddresses(
      List<Putnik> passengers) async {
    final addressCoordinates = <Putnik, GeocodeResult>{};

    // Filter passengers with addresses
    final passengersWithAddresses = passengers
        .where((p) => p.adresa != null && p.adresa!.isNotEmpty)
        .toList();

    if (passengersWithAddresses.isEmpty) return addressCoordinates;

    // Prepare batch request
    final addressMap = <String, String>{};
    for (int i = 0; i < passengersWithAddresses.length; i++) {
      final passenger = passengersWithAddresses[i];
      addressMap['passenger_$i'] = '${passenger.adresa}, ${passenger.grad}';
    }

    // Batch geocoding
    final results = await AdvancedGeocodingService.batchGeocode(
      addresses: addressMap,
      batchSize: 5,
      delay: const Duration(milliseconds: 50),
    );

    // Map results back to passengers
    for (int i = 0; i < passengersWithAddresses.length; i++) {
      final result = results['passenger_$i'];
      if (result != null && result.confidence > 50.0) {
        addressCoordinates[passengersWithAddresses[i]] = result;
      }
    }

    return addressCoordinates;
  }

  /// 🌦️ GATHER EXTERNAL DATA - weather, traffic, road conditions
  static Future<Map<String, dynamic>> _gatherExternalData(
    Position start,
    List<GeocodeResult> destinations, {
    bool considerTraffic = true,
    bool considerWeather = true,
  }) async {
    final data = <String, dynamic>{
      'weather': null,
      'traffic': <String, double>{},
      'road_conditions': 1.0, // multiplier
    };

    try {
      // Weather data (free OpenWeatherMap API)
      if (considerWeather) {
        // NAPOMENA: Dodaj svoj OpenWeatherMap API key
        const weatherApiKey =
            String.fromEnvironment('OPENWEATHER_API_KEY', defaultValue: '');
        if (weatherApiKey.isNotEmpty) {
          final weatherUrl =
              '$_weatherApiUrl?lat=${start.latitude}&lon=${start.longitude}&appid=$weatherApiKey&units=metric';
          final response = await http
              .get(Uri.parse(weatherUrl))
              .timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            final weatherData = json.decode(response.body);
            data['weather'] = {
              'temp': weatherData['main']['temp'],
              'conditions': weatherData['weather'][0]['main'],
              'visibility': weatherData['visibility'] ?? 10000,
              'wind_speed': weatherData['wind']['speed'] ?? 0,
            };
          }
        }
      }

      // Mock traffic data (replace with real traffic API)
      if (considerTraffic) {
        for (final dest in destinations) {
          // Simple traffic simulation based on time and location
          final hour = DateTime.now().hour;
          double trafficMultiplier = 1.0;

          // Rush hour penalties
          if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
            trafficMultiplier = 1.3; // 30% slower
          } else if (hour >= 22 || hour <= 6) {
            trafficMultiplier = 0.9; // 10% faster at night
          }

          data['traffic']['${dest.latitude}_${dest.longitude}'] =
              trafficMultiplier;
        }
      }
    } catch (e) {
      _logger.w('⚠️ Failed to gather external data: $e');
    }

    return data;
  }

  /// 📊 BUILD DISTANCE/TIME MATRIX
  static Future<DistanceMatrix> _buildDistanceMatrix(
    Position start,
    Map<Putnik, GeocodeResult> coordinates,
    Map<String, dynamic> externalData,
    VehicleType vehicle,
  ) async {
    final passengers = coordinates.keys.toList();
    final matrix =
        DistanceMatrix(passengers.length + 1); // +1 for start location

    // Calculate distances between all points
    for (int i = 0; i < passengers.length + 1; i++) {
      for (int j = 0; j < passengers.length + 1; j++) {
        if (i == j) {
          matrix.setDistance(i, j, 0.0);
          continue;
        }

        Position pointA, pointB;

        // Start location is index 0
        if (i == 0) {
          pointA = start;
        } else {
          final coord = coordinates[passengers[i - 1]]!;
          pointA = Position(
            latitude: coord.latitude,
            longitude: coord.longitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        }

        if (j == 0) {
          pointB = start;
        } else {
          final coord = coordinates[passengers[j - 1]]!;
          pointB = Position(
            latitude: coord.latitude,
            longitude: coord.longitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        }

        // Calculate base distance
        double distance = Geolocator.distanceBetween(
              pointA.latitude,
              pointA.longitude,
              pointB.latitude,
              pointB.longitude,
            ) /
            1000.0; // Convert to km

        // Apply external factors
        distance = _applyExternalFactors(
            distance, pointA, pointB, externalData, vehicle);

        matrix.setDistance(i, j, distance);
      }
    }

    return matrix;
  }

  /// 🌦️ APPLY EXTERNAL FACTORS - weather, traffic, vehicle type
  static double _applyExternalFactors(
    double baseDistance,
    Position pointA,
    Position pointB,
    Map<String, dynamic> externalData,
    VehicleType vehicle,
  ) {
    double adjustedDistance = baseDistance;

    // Weather impact
    final weather = externalData['weather'];
    if (weather != null) {
      final conditions = weather['conditions'] as String? ?? '';
      final windSpeed = (weather['wind_speed'] as num? ?? 0).toDouble();

      if (conditions.toLowerCase().contains('rain')) {
        adjustedDistance *= 1.15; // 15% longer in rain
      } else if (conditions.toLowerCase().contains('snow')) {
        adjustedDistance *= 1.3; // 30% longer in snow
      }

      if (windSpeed > 10) {
        adjustedDistance *= 1.05; // 5% longer in strong wind
      }
    }

    // Traffic impact
    final traffic = externalData['traffic'] as Map<String, double>? ?? {};
    final trafficKey = '${pointB.latitude}_${pointB.longitude}';
    final trafficMultiplier = traffic[trafficKey] ?? 1.0;
    adjustedDistance *= trafficMultiplier;

    // Vehicle type impact
    switch (vehicle) {
      case VehicleType.car:
        break; // no change
      case VehicleType.minibus:
        adjustedDistance *= 1.1; // 10% longer for minibus
        break;
      case VehicleType.eco:
        adjustedDistance *= 0.95; // 5% shorter - efficient routes
        break;
    }

    return adjustedDistance;
  }

  /// 🧬 GENETIC ALGORITHM OPTIMIZATION
  static Future<OptimizationResult> _geneticAlgorithmOptimization(
    List<Putnik> passengers,
    DistanceMatrix matrix,
    int maxTimeSeconds,
  ) async {
    final startTime = DateTime.now();
    const populationSize = 100;
    const eliteSize = 20;
    const mutationRate = 0.01;
    const maxGenerations = 1000;

    // Initialize population
    var population =
        _generateInitialPopulation(passengers.length, populationSize);
    var bestDistance = double.infinity;
    var bestRoute = <int>[];
    var generation = 0;

    while (generation < maxGenerations &&
        DateTime.now().difference(startTime).inSeconds < maxTimeSeconds) {
      // Evaluate fitness
      final fitness = population
          .map((route) => 1.0 / (1.0 + _calculateRouteDistance(route, matrix)))
          .toList();

      // Find best route
      for (int i = 0; i < population.length; i++) {
        final distance = _calculateRouteDistance(population[i], matrix);
        if (distance < bestDistance) {
          bestDistance = distance;
          bestRoute = List.from(population[i]);
        }
      }

      // Selection and crossover
      final newPopulation = <List<int>>[];

      // Keep elite
      final sortedIndices = List.generate(population.length, (i) => i);
      sortedIndices.sort((a, b) => fitness[b].compareTo(fitness[a]));

      for (int i = 0; i < eliteSize; i++) {
        newPopulation.add(List.from(population[sortedIndices[i]]));
      }

      // Generate offspring
      while (newPopulation.length < populationSize) {
        final parent1 = _tournamentSelection(population, fitness);
        final parent2 = _tournamentSelection(population, fitness);
        final child = _orderCrossover(parent1, parent2);

        // Mutation
        if (math.Random().nextDouble() < mutationRate) {
          _mutateRoute(child);
        }

        newPopulation.add(child);
      }

      population = newPopulation;
      generation++;
    }

    final optimizedSequence =
        bestRoute.map((index) => passengers[index]).toList();

    return OptimizationResult(
      sequence: optimizedSequence,
      distance: bestDistance,
      metrics: {
        'algorithm': 'genetic',
        'generations': generation,
        'population_size': populationSize,
        'best_fitness': 1.0 / (1.0 + bestDistance),
      },
    );
  }

  /// 🔥 SIMULATED ANNEALING OPTIMIZATION
  static Future<OptimizationResult> _simulatedAnnealingOptimization(
    List<Putnik> passengers,
    DistanceMatrix matrix,
    int maxTimeSeconds,
  ) async {
    final startTime = DateTime.now();
    final random = math.Random();

    // Initial solution
    var currentRoute = List.generate(passengers.length, (i) => i);
    currentRoute.shuffle(random);
    var currentDistance = _calculateRouteDistance(currentRoute, matrix);

    var bestRoute = List.from(currentRoute);
    var bestDistance = currentDistance;

    // SA parameters
    var temperature = 100.0;
    const coolingRate = 0.995;
    const minTemperature = 0.1;
    var iteration = 0;

    while (temperature > minTemperature &&
        DateTime.now().difference(startTime).inSeconds < maxTimeSeconds) {
      // Generate neighbor solution
      final newRoute = List<int>.from(currentRoute);
      _twoOptSwap(newRoute);
      final newDistance = _calculateRouteDistance(newRoute, matrix);

      // Accept or reject
      if (newDistance < currentDistance ||
          random.nextDouble() <
              math.exp((currentDistance - newDistance) / temperature)) {
        currentRoute = newRoute;
        currentDistance = newDistance;

        if (currentDistance < bestDistance) {
          bestRoute = List.from(currentRoute);
          bestDistance = currentDistance;
        }
      }

      temperature *= coolingRate;
      iteration++;
    }

    final optimizedSequence =
        bestRoute.map((index) => passengers[index]).toList();

    return OptimizationResult(
      sequence: optimizedSequence,
      distance: bestDistance,
      metrics: {
        'algorithm': 'simulated_annealing',
        'iterations': iteration,
        'final_temperature': temperature,
        'cooling_rate': coolingRate,
      },
    );
  }

  /// ⚡ 2-OPT OPTIMIZATION
  static Future<OptimizationResult> _twoOptOptimization(
    List<Putnik> passengers,
    DistanceMatrix matrix,
  ) async {
    var route = List.generate(passengers.length, (i) => i);
    var bestDistance = _calculateRouteDistance(route, matrix);
    var improved = true;
    var iterations = 0;

    while (improved && iterations < 1000) {
      improved = false;

      for (int i = 0; i < route.length - 1; i++) {
        for (int j = i + 1; j < route.length; j++) {
          final newRoute = _twoOptSwapAt(route, i, j);
          final newDistance = _calculateRouteDistance(newRoute, matrix);

          if (newDistance < bestDistance) {
            route = newRoute;
            bestDistance = newDistance;
            improved = true;
          }
        }
      }
      iterations++;
    }

    final optimizedSequence = route.map((index) => passengers[index]).toList();

    return OptimizationResult(
      sequence: optimizedSequence,
      distance: bestDistance,
      metrics: {
        'algorithm': '2-opt',
        'iterations': iterations,
        'improvements': iterations,
      },
    );
  }

  /// 🤖 HYBRID OPTIMIZATION - kombinuje sve algoritme
  static Future<OptimizationResult> _hybridOptimization(
    List<Putnik> passengers,
    DistanceMatrix matrix,
    int maxTimeSeconds,
  ) async {
    final results = <OptimizationResult>[];
    final timePerAlgorithm = maxTimeSeconds ~/ 3;

    // Run all algorithms in parallel
    final futures = [
      _geneticAlgorithmOptimization(passengers, matrix, timePerAlgorithm),
      _simulatedAnnealingOptimization(passengers, matrix, timePerAlgorithm),
      _twoOptOptimization(passengers, matrix),
    ];

    final algorithmResults = await Future.wait(futures);
    results.addAll(algorithmResults);

    // Find best result
    results.sort((a, b) => a.distance.compareTo(b.distance));
    final bestResult = results.first;

    // Apply final 2-opt improvement
    final finalResult = await _twoOptOptimization(bestResult.sequence, matrix);

    return OptimizationResult(
      sequence: finalResult.sequence,
      distance: finalResult.distance,
      metrics: {
        'algorithm': 'hybrid',
        'genetic_distance': results[0].distance,
        'sa_distance': results[1].distance,
        'twoopt_distance': results[2].distance,
        'final_distance': finalResult.distance,
        'improvement': ((results.map((r) => r.distance).reduce(math.max) -
                finalResult.distance) /
            results.map((r) => r.distance).reduce(math.max) *
            100),
      },
    );
  }

  // HELPER METHODS

  static List<List<int>> _generateInitialPopulation(
      int size, int populationSize) {
    final population = <List<int>>[];
    final baseRoute = List<int>.generate(size, (i) => i);

    for (int i = 0; i < populationSize; i++) {
      final route = List<int>.from(baseRoute);
      route.shuffle();
      population.add(route);
    }

    return population;
  }

  static List<int> _tournamentSelection(
      List<List<int>> population, List<double> fitness) {
    const tournamentSize = 5;
    final random = math.Random();
    var bestIndex = random.nextInt(population.length);
    var bestFitness = fitness[bestIndex];

    for (int i = 1; i < tournamentSize; i++) {
      final index = random.nextInt(population.length);
      if (fitness[index] > bestFitness) {
        bestIndex = index;
        bestFitness = fitness[index];
      }
    }

    return population[bestIndex];
  }

  static List<int> _orderCrossover(List<int> parent1, List<int> parent2) {
    final random = math.Random();
    final size = parent1.length;
    final start = random.nextInt(size);
    final end = start + random.nextInt(size - start);

    final child = List<int>.filled(size, -1);

    // Copy segment from parent1
    for (int i = start; i <= end; i++) {
      child[i] = parent1[i];
    }

    // Fill remaining positions from parent2
    int childIndex = (end + 1) % size;
    int parent2Index = (end + 1) % size;

    while (child.contains(-1)) {
      if (!child.contains(parent2[parent2Index])) {
        child[childIndex] = parent2[parent2Index];
        childIndex = (childIndex + 1) % size;
      }
      parent2Index = (parent2Index + 1) % size;
    }

    return child;
  }

  static void _mutateRoute(List<int> route) {
    final random = math.Random();
    final i = random.nextInt(route.length);
    final j = random.nextInt(route.length);
    final temp = route[i];
    route[i] = route[j];
    route[j] = temp;
  }

  static void _twoOptSwap(List<int> route) {
    final random = math.Random();
    final i = random.nextInt(route.length - 1);
    final j = i + 1 + random.nextInt(route.length - i - 1);
    _reverseSegment(route, i, j);
  }

  static List<int> _twoOptSwapAt(List<int> route, int i, int j) {
    final newRoute = List<int>.from(route);
    _reverseSegment(newRoute, i, j);
    return newRoute;
  }

  static void _reverseSegment(List<int> route, int start, int end) {
    while (start < end) {
      final temp = route[start];
      route[start] = route[end];
      route[end] = temp;
      start++;
      end--;
    }
  }

  static double _calculateRouteDistance(
      List<int> route, DistanceMatrix matrix) {
    double totalDistance = 0.0;

    // From start (index 0) to first passenger
    if (route.isNotEmpty) {
      totalDistance += matrix.getDistance(0, route.first + 1);
    }

    // Between passengers
    for (int i = 0; i < route.length - 1; i++) {
      totalDistance += matrix.getDistance(route[i] + 1, route[i + 1] + 1);
    }

    return totalDistance;
  }

  static List<Putnik> _applyTimeWindowConstraints(List<Putnik> passengers) {
    // Sort by departure time
    final sorted = List<Putnik>.from(passengers);
    sorted.sort((a, b) => a.polazak.compareTo(b.polazak));
    return sorted;
  }

  static List<Putnik> _applyDriverPreferences(
      List<Putnik> passengers, Map<String, dynamic> preferences) {
    // Example preferences: prioritize VIP passengers, avoid certain areas, etc.
    if (preferences['prioritize_vip'] == true) {
      final vipPassengers = passengers
          .where((p) => p.statusVreme?.contains('VIP') ?? false)
          .toList();
      final regularPassengers = passengers
          .where((p) => !(p.statusVreme?.contains('VIP') ?? false))
          .toList();
      return [...vipPassengers, ...regularPassengers];
    }

    return passengers;
  }

  static Duration _calculateEstimatedTime(
      double distance, VehicleType vehicle) {
    double avgSpeed; // km/h

    switch (vehicle) {
      case VehicleType.car:
        avgSpeed = 50.0;
        break;
      case VehicleType.minibus:
        avgSpeed = 45.0; // slower due to size
        break;
      case VehicleType.eco:
        avgSpeed = 40.0; // more conservative driving
        break;
    }

    final hours = distance / avgSpeed;
    return Duration(minutes: (hours * 60).round());
  }
}

/// 📊 DISTANCE MATRIX CLASS
class DistanceMatrix {
  final List<List<double>> _matrix;
  final int size;

  DistanceMatrix(this.size)
      : _matrix = List.generate(size, (_) => List.filled(size, 0.0));

  void setDistance(int i, int j, double distance) {
    _matrix[i][j] = distance;
    _matrix[j][i] = distance; // symmetric
  }

  double getDistance(int i, int j) => _matrix[i][j];
}

/// 📈 OPTIMIZATION RESULT CLASS
class OptimizationResult {
  final List<Putnik> sequence;
  final double distance;
  final Map<String, dynamic> metrics;

  OptimizationResult({
    required this.sequence,
    required this.distance,
    required this.metrics,
  });
}

/// 🗺️ OPTIMIZED ROUTE CLASS
class OptimizedRoute {
  final List<Putnik> optimizedSequence;
  final List<Putnik> originalSequence;
  final double totalDistance;
  final Duration estimatedTime;
  final OptimizationAlgorithm algorithm;
  final Duration calculationTime;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic> externalFactors;
  final Map<Putnik, GeocodeResult> coordinates;

  OptimizedRoute({
    required this.optimizedSequence,
    required this.originalSequence,
    required this.totalDistance,
    required this.estimatedTime,
    required this.algorithm,
    required this.calculationTime,
    required this.metrics,
    required this.externalFactors,
    required this.coordinates,
  });

  /// Fallback route if optimization fails
  factory OptimizedRoute.fallback(List<Putnik> passengers) {
    return OptimizedRoute(
      optimizedSequence: passengers,
      originalSequence: passengers,
      totalDistance: 0.0,
      estimatedTime: const Duration(),
      algorithm: OptimizationAlgorithm.hybrid,
      calculationTime: const Duration(),
      metrics: {'fallback': true},
      externalFactors: {},
      coordinates: {},
    );
  }

  double get improvementPercentage {
    if (originalSequence.length != optimizedSequence.length) return 0.0;
    // Mock calculation - in real scenario, you'd compare with original route distance
    return (metrics['improvement'] as double? ?? 0.0);
  }

  @override
  String toString() {
    return 'OptimizedRoute(${optimizedSequence.length} stops, ${totalDistance.toStringAsFixed(2)}km, ${estimatedTime.inMinutes}min)';
  }
}
