import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/putnik.dart';

/// 🚦 TRAFFIC-AWARE ROUTING SERVICE
/// Integriše podatke o saobraćaju u optimizaciju rute
/// 🚗 OPTIMIZOVANO ZA KOMERCIJALNA VOZILA
class TrafficAwareRoutingService {
  /// 🗺️ GOOGLE MAPS API UKLONJEN - koristi se lokalna optimizacija
  // static const String _googleMapsApiKey = 'REMOVED_FOR_SECURITY';

  /// 🚗 KONFIGURACIJA ZA KOMERCIJALNA VOZILA
  static const double _maxTrafficDelayThreshold =
      1.5; // 50% više vremena = previše gužve
  static const double _commercialVehicleSpeedFactor =
      0.85; // Kombi sporiji 15% od automobila
  static const int _maxDetourPercentage =
      25; // Maksimalno 25% duža ruta da bi izbegao gužve

  /// 🚦 Dobij podatke o saobraćaju između dve tačke
  static Future<TrafficData> getTrafficData({
    required Position start,
    required Position destination,
    DateTime? departureTime,
  }) async {
    try {
      departureTime ??= DateTime.now();

      final url =
          Uri.parse('https://maps.googleapis.com/maps/api/directions/json'
              '?origin=${start.latitude},${start.longitude}'
              '&destination=${destination.latitude},${destination.longitude}'
              '&departure_time=${departureTime.millisecondsSinceEpoch ~/ 1000}'
              '&traffic_model=best_guess'
              '&key=REMOVED_FOR_SECURITY');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['status'] as String == 'OK' &&
            (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          // Vreme bez saobraćaja
          final normalDuration = leg['duration']['value'] as int;

          // Vreme sa saobraćajem (ako postoji)
          final trafficDuration =
              leg['duration_in_traffic']?['value'] as int? ?? normalDuration;

          return TrafficData(
            normalDurationSeconds: normalDuration,
            trafficDurationSeconds: trafficDuration,
            distanceMeters: leg['distance']['value'] as int,
            trafficLevel:
                _calculateTrafficLevel(normalDuration, trafficDuration),
            route: route['overview_polyline']['points'] as String,
          );
        }
      }

      // Fallback - proceni na osnovu vremena dana
      return _estimateTrafficFromTimeOfDay(start, destination, departureTime);
    } catch (e) {
      return _estimateTrafficFromTimeOfDay(start, destination, departureTime!);
    }
  }

  /// 🚦 Optimizuj rutu sa traffic podacima
  static Future<List<Putnik>> optimizeRouteWithTraffic({
    required Position startPosition,
    required List<Putnik> putnici,
    required Map<Putnik, Position> coordinates,
    DateTime? departureTime,
  }) async {
    departureTime ??= DateTime.now();

    // Kreiraj matricu vremena putovanja sa traffic podacima
    final trafficMatrix = <String, TrafficData>{};

    // Dobij traffic podatke za sve kombinacije
    final allPositions = [startPosition, ...coordinates.values];
    final allKeys = ['START', ...putnici.map((p) => p.id.toString())];

    for (int i = 0; i < allPositions.length; i++) {
      for (int j = 0; j < allPositions.length; j++) {
        if (i != j) {
          final key = '${allKeys[i]}_${allKeys[j]}';
          trafficMatrix[key] = await getTrafficData(
            start: allPositions[i],
            destination: allPositions[j],
            departureTime: departureTime,
          );

          // Dodaj delay između API poziva
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }

    // Optimizuj redosled na osnovu traffic podataka
    return _tspWithTraffic(putnici, coordinates, trafficMatrix, startPosition);
  }

  /// 🧮 TSP algoritam sa traffic podacima
  static List<Putnik> _tspWithTraffic(
    List<Putnik> putnici,
    Map<Putnik, Position> coordinates,
    Map<String, TrafficData> trafficMatrix,
    Position startPosition,
  ) {
    if (putnici.length <= 1) return putnici;

    // Za manje grupe koristi brute force sa traffic podacima
    if (putnici.length <= 6) {
      return _bruteForceTSPWithTraffic(putnici, trafficMatrix);
    }

    // Za veće grupe koristi nearest neighbor sa traffic prioritetom
    return _nearestNeighborWithTraffic(putnici, trafficMatrix, startPosition);
  }

  /// 🔄 Brute force TSP sa traffic podacima
  static List<Putnik> _bruteForceTSPWithTraffic(
    List<Putnik> putnici,
    Map<String, TrafficData> trafficMatrix,
  ) {
    List<Putnik> bestRoute = List.from(putnici);
    int bestTime = _calculateTotalTrafficTime(bestRoute, trafficMatrix);

    // Generiši sve permutacije
    _generatePermutations(List<Putnik>.from(putnici), 0, (route) {
      final typedRoute = route.cast<Putnik>(); // Eksplicitno kastovanje
      final time = _calculateTotalTrafficTime(typedRoute, trafficMatrix);
      if (time < bestTime) {
        bestTime = time;
        bestRoute = List.from(typedRoute);
      }
    });

    return bestRoute;
  }

  /// 🎯 Nearest neighbor sa traffic prioritetom ZA KOMERCIJALNA VOZILA
  static List<Putnik> _nearestNeighborWithTraffic(
    List<Putnik> putnici,
    Map<String, TrafficData> trafficMatrix,
    Position startPosition,
  ) {
    final result = <Putnik>[];
    final remaining = List<Putnik>.from(putnici);
    String currentKey = 'START';

    while (remaining.isNotEmpty) {
      Putnik? nearest;
      double bestScore = double.maxFinite;

      for (final putnik in remaining) {
        final key = '${currentKey}_${putnik.id}';
        final trafficData = trafficMatrix[key];

        if (trafficData != null) {
          // 🚗 KOMERCIJALNI VOZILA LOGIKA:
          // Balansiranje između brzine i bezbednosti
          final normalTime = trafficData.normalDurationSeconds;
          final trafficTime = trafficData.trafficDurationSeconds;
          final distance = trafficData.distanceMeters;

          // Ako je gužva previše intenzivna, penalizuj rutu
          final trafficRatio = trafficTime / normalTime;
          final isHeavyTraffic = trafficRatio > _maxTrafficDelayThreshold;

          // Računaj score za komercijalna vozila
          double score = trafficTime * _commercialVehicleSpeedFactor;

          // Penalizuj težak saobraćaj
          if (isHeavyTraffic) {
            score *= 1.3; // 30% penalizacija za teške gužve
          }

          // Penalizuj previše dugačke detour rute
          const averageDistance = 3000; // Prosečna distanca u gradu
          final detourRatio = (distance / averageDistance - 1) * 100;
          final isLongDetour = detourRatio > _maxDetourPercentage;
          final detourPenalty = isLongDetour ? 1.2 : 1.0; // 20% za dugačke rute
          score *= detourPenalty;

          if (score < bestScore) {
            bestScore = score;
            nearest = putnik;
          }
        }
      }

      if (nearest != null) {
        result.add(nearest);
        remaining.remove(nearest);
        currentKey = nearest.id.toString();
      } else {
        // Fallback
        result.add(remaining.removeAt(0));
      }
    }

    return result;
  }

  /// ⏱️ Računaj ukupno vreme sa traffic podacima
  static int _calculateTotalTrafficTime(
    List<Putnik> route,
    Map<String, TrafficData> trafficMatrix,
  ) {
    int totalTime = 0;
    String currentKey = 'START';

    for (final putnik in route) {
      final key = '${currentKey}_${putnik.id}';
      final trafficData = trafficMatrix[key];

      if (trafficData != null) {
        totalTime += trafficData.trafficDurationSeconds;
      }

      currentKey = putnik.id.toString();
    }

    return totalTime;
  }

  /// 🕐 Proceni saobraćaj na osnovu vremena dana
  static TrafficData _estimateTrafficFromTimeOfDay(
    Position start,
    Position destination,
    DateTime departureTime,
  ) {
    final hour = departureTime.hour;
    final minute = departureTime.minute;
    final timeDecimal = hour + minute / 60.0;

    // Bela Crkva -> Vršac špic sati
    double trafficMultiplier = 1.0;

    if (timeDecimal >= 6.5 && timeDecimal <= 9.0) {
      // Jutarnji špic 6:30-9:00
      trafficMultiplier = 1.8;
    } else if (timeDecimal >= 16.0 && timeDecimal <= 18.5) {
      // Popodnevni špic 16:00-18:30
      trafficMultiplier = 1.6;
    } else if (timeDecimal >= 13.0 && timeDecimal <= 14.0) {
      // Ručak 13:00-14:00
      trafficMultiplier = 1.3;
    }

    // Proceni osnovnu distancu
    final distance = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      destination.latitude,
      destination.longitude,
    );

    // Proceni vreme (60 km/h u gradu, 80 km/h van grada)
    final baseTime = (distance / 1000) * 45; // 45 sekundi po kilometru
    final trafficTime = baseTime * trafficMultiplier;

    return TrafficData(
      normalDurationSeconds: baseTime.round(),
      trafficDurationSeconds: trafficTime.round(),
      distanceMeters: distance.round(),
      trafficLevel:
          _calculateTrafficLevel(baseTime.round(), trafficTime.round()),
      route: '', // Nema polyline
    );
  }

  /// 🚦 Računaj nivo saobraćaja
  static TrafficLevel _calculateTrafficLevel(
    int normalDuration,
    int trafficDuration,
  ) {
    final ratio = trafficDuration / normalDuration;

    if (ratio >= 2.0) return TrafficLevel.heavy;
    if (ratio >= 1.5) return TrafficLevel.moderate;
    if (ratio >= 1.2) return TrafficLevel.light;
    return TrafficLevel.free;
  }

  /// 🔄 Generiši permutacije
  static void _generatePermutations<T>(
    List<T> list,
    int index,
    void Function(List<T>) callback,
  ) {
    if (index == list.length) {
      callback(list);
      return;
    }

    for (int i = index; i < list.length; i++) {
      // Swap
      final temp = list[index];
      list[index] = list[i];
      list[i] = temp;

      _generatePermutations(list, index + 1, callback);

      // Swap back
      list[i] = list[index];
      list[index] = temp;
    }
  }
}

/// 📊 Traffic podaci za rutu
class TrafficData {
  // Polyline za prikaz na mapi

  TrafficData({
    required this.normalDurationSeconds,
    required this.trafficDurationSeconds,
    required this.distanceMeters,
    required this.trafficLevel,
    required this.route,
  });
  final int normalDurationSeconds;
  final int trafficDurationSeconds;
  final int distanceMeters;
  final TrafficLevel trafficLevel;
  final String route;

  /// ⏱️ Procenat dodatnog vremena zbog saobraćaja
  double get trafficDelayPercentage =>
      ((trafficDurationSeconds - normalDurationSeconds) /
          normalDurationSeconds) *
      100;

  /// 🚦 Da li ima značajnu gužvu
  bool get hasSignificantTraffic => trafficLevel != TrafficLevel.free;

  /// ⏰ Vreme u minutima
  double get trafficDurationMinutes => trafficDurationSeconds / 60.0;

  /// 📏 Distanca u kilometrima
  double get distanceKm => distanceMeters / 1000.0;
}

/// 🚦 Nivoi saobraćaja
enum TrafficLevel {
  free, // Bez gužve
  light, // Lagana gužva
  moderate, // Umerena gužva
  heavy, // Jaka gužva
}

extension TrafficLevelExtension on TrafficLevel {
  String get displayName {
    switch (this) {
      case TrafficLevel.free:
        return '🟢 Bez gužve';
      case TrafficLevel.light:
        return '🟡 Lagana gužva';
      case TrafficLevel.moderate:
        return '🟠 Umerena gužva';
      case TrafficLevel.heavy:
        return '🔴 Jaka gužva';
    }
  }

  String get emoji {
    switch (this) {
      case TrafficLevel.free:
        return '🟢';
      case TrafficLevel.light:
        return '🟡';
      case TrafficLevel.moderate:
        return '🟠';
      case TrafficLevel.heavy:
        return '🔴';
    }
  }
}





