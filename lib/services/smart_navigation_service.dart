import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/putnik.dart';
import 'geocoding_service.dart';

/// 🎯 SMART NAVIGATION SERVICE
/// Implementira pravu GPS navigaciju sa optimizovanim redosledom putnika
/// Koristi OpenStreetMap / self-hosted OSRM/Valhalla ili platform-specific aplikacije za otvaranje rute.
class SmartNavigationService {
  /// 🚗 GLAVNA FUNKCIJA - Otvori mapu sa optimizovanom rutom (preferirano OSM/OSRM)
  static Future<NavigationResult> startOptimizedNavigation({
    required List<Putnik> putnici,
    required String startCity, // 'Bela Crkva' ili 'Vršac'
    bool optimizeForTime = true, // true = vreme, false = distanca
    bool useTrafficData = false, // 🚦 NOVO: traffic-aware routing
  }) async {
    try {
      // freeMode reference removed.
      // 1. DOBIJ TRENUTNU GPS POZICIJU VOZAČA
      final currentPosition = await _getCurrentPosition();

      // 2. DOBIJ KOORDINATE ZA SVE ADRESE
      final Map<Putnik, Position> coordinates = await _getCoordinatesForPutnici(putnici);

      if (coordinates.isEmpty) {
        return NavigationResult.error(
          '❌ Nijedan putnik nema validnu adresu za navigaciju',
        );
      }

      // 3. OPTIMIZUJ REDOSLED PUTNIKA
      List<Putnik> optimizedRoute;

      if (useTrafficData) {
        // 🚦 TRAFFIC-AWARE OPTIMIZACIJA

        // DISABLED: Google APIs too expensive - use standard optimization instead
        optimizedRoute = await _optimizeRoute(
          startPosition: currentPosition,
          coordinates: coordinates,
          optimizeForTime: optimizeForTime,
        );
      } else {
        // 🎯 STANDARDNA TSP OPTIMIZACIJA
        optimizedRoute = await _optimizeRoute(
          startPosition: currentPosition,
          coordinates: coordinates,
          optimizeForTime: optimizeForTime,
        );
      }

      // 4. OTVORI RUTU U PREFERIRANOJ NAVIGACIONOJ APLIKACIJI (OpenStreetMap/OSM)
      final success = await _openOSMNavigation(
        currentPosition,
        optimizedRoute,
        startCity,
        useTrafficData: useTrafficData, // 🚦 Prosledi traffic parametar
      );

      if (success) {
        return NavigationResult.success(
          message: '🎯 Navigacija pokrenuta sa ${optimizedRoute.length} putnika',
          optimizedPutnici: optimizedRoute,
          totalDistance: await _calculateTotalDistance(
            currentPosition,
            optimizedRoute,
            coordinates,
          ),
        );
      } else {
        return NavigationResult.error('❌ Greška pri otvaranju navigacije');
      }
    } catch (e) {
      return NavigationResult.error('❌ Greška pri navigaciji: $e');
    }
  }

  /// 📍 Dobij trenutnu GPS poziciju vozača
  static Future<Position> _getCurrentPosition() async {
    // Proveri dozvole
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('GPS dozvole nisu odobrene');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('GPS dozvole su trajno odbačene');
    }

    // Dobij poziciju sa visokom tačnošću
    return await Geolocator.getCurrentPosition(
        // desiredAccuracy: deprecated, use settings parameter
        // timeLimit: const Duration(seconds: 10), // deprecated, use settings parameter
        );
  }

  /// 🗺️ Dobij koordinate za sve putnike
  static Future<Map<Putnik, Position>> _getCoordinatesForPutnici(
    List<Putnik> putnici,
  ) async {
    final Map<Putnik, Position> coordinates = {};

    for (final putnik in putnici) {
      if (putnik.adresa == null || putnik.adresa!.trim().isEmpty) continue;

      try {
        // Poboljšaj adresu za geocoding
        final improvedAddress = _improveAddressForGeocoding(putnik.adresa!, putnik.grad);

        // Dobij koordinate preko GeocodingService
        final coordsString = await GeocodingService.getKoordinateZaAdresu(
          putnik.grad,
          improvedAddress,
        );

        if (coordsString != null && coordsString.contains(',')) {
          final parts = coordsString.split(',');
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());

          if (lat != null && lng != null) {
            coordinates[putnik] = Position(
              latitude: lat,
              longitude: lng,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            );
          }
        }
      } catch (e) {
        // Greška u geocoding procesu
      }
    }

    return coordinates;
  }

  /// 🎯 Optimizuj redosled putnika (TSP algoritam)
  static Future<List<Putnik>> _optimizeRoute({
    required Position startPosition,
    required Map<Putnik, Position> coordinates,
    bool optimizeForTime = true,
  }) async {
    final putnici = coordinates.keys.toList();

    if (putnici.length <= 1) return putnici;

    // Za manje od 8 putnika koristi brute force, inače nearest neighbor
    if (putnici.length <= 8) {
      return await _bruteForceOptimization(
        startPosition,
        coordinates,
        optimizeForTime,
      );
    } else {
      return await _nearestNeighborOptimization(
        startPosition,
        coordinates,
        optimizeForTime,
      );
    }
  }

  /// 🔥 Brute force optimizacija (za <= 8 putnika)
  static Future<List<Putnik>> _bruteForceOptimization(
    Position start,
    Map<Putnik, Position> coordinates,
    bool optimizeForTime,
  ) async {
    final putnici = coordinates.keys.toList();
    double bestDistance = double.infinity;
    List<Putnik> bestRoute = [];

    // Generiši sve permutacije
    final permutations = _generatePermutations(putnici);

    for (final route in permutations) {
      final distance = await _calculateRouteDistance(
        start,
        route,
        coordinates,
        optimizeForTime,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        bestRoute = List.from(route);
      }
    }

    return bestRoute;
  }

  /// ⚡ Nearest neighbor optimizacija (za >8 putnika)
  static Future<List<Putnik>> _nearestNeighborOptimization(
    Position start,
    Map<Putnik, Position> coordinates,
    bool optimizeForTime,
  ) async {
    final unvisited = coordinates.keys.toList();
    final route = <Putnik>[];
    Position currentPosition = start;

    while (unvisited.isNotEmpty) {
      Putnik? nearest;
      double shortestDistance = double.infinity;

      // Nađi najbliži neposećen grad
      for (final putnik in unvisited) {
        final distance = _calculateDistance(currentPosition, coordinates[putnik]!);
        if (distance < shortestDistance) {
          shortestDistance = distance;
          nearest = putnik;
        }
      }

      if (nearest != null) {
        route.add(nearest);
        currentPosition = coordinates[nearest]!;
        unvisited.remove(nearest);
      }
    }

    return route;
  }

  /// 📊 Izračunaj ukupnu distancu rute
  static Future<double> _calculateRouteDistance(
    Position start,
    List<Putnik> route,
    Map<Putnik, Position> coordinates,
    bool optimizeForTime,
  ) async {
    if (route.isEmpty) return 0.0;

    double totalDistance = 0.0;
    Position currentPos = start;

    for (final putnik in route) {
      final nextPos = coordinates[putnik]!;
      totalDistance += _calculateDistance(currentPos, nextPos);
      currentPos = nextPos;
    }

    // Za optimizaciju vremena, dodaj penalty za gušće saobraćaj u određeno doba
    if (optimizeForTime) {
      final hour = DateTime.now().hour;
      double timePenalty = 1.0;

      // Rush hour penalties
      if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
        timePenalty = 1.3; // 30% duže u špicu
      } else if (hour >= 22 || hour <= 6) {
        timePenalty = 0.8; // 20% brže noću
      }

      totalDistance *= timePenalty;
    }

    return totalDistance;
  }

  /// 📐 Izračunaj distancu između dve pozicije (Haversine formula)
  static double _calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  /// 🗺️ Otvori OpenStreetMap sa optimizovanom rutom
  static Future<bool> _openOSMNavigation(
    Position startPosition,
    List<Putnik> optimizedRoute,
    String startCity, {
    bool useTrafficData = false, // 🚦 DODATO za traffic parametere
  }) async {
    try {
      // Kreiraj OpenStreetMap URL za navigaciju (koristi osmand ili maps.me)
      String osmNavigationUrl = 'https://www.openstreetmap.org/directions?';

      // Dodaj početnu poziciju
      osmNavigationUrl += 'from=${startPosition.latitude}%2C${startPosition.longitude}';

      // Za OpenStreetMap, koristimo prvi i poslednji destination
      if (optimizedRoute.isNotEmpty) {
        final lastPutnik = optimizedRoute.last;
        if (lastPutnik.adresa != null && lastPutnik.adresa!.isNotEmpty) {
          final improvedAddress = _improveAddressForGeocoding(lastPutnik.adresa!, lastPutnik.grad);
          final encodedAddress = Uri.encodeComponent(
            '$improvedAddress, ${lastPutnik.grad}, Serbia',
          );
          osmNavigationUrl += '&to=$encodedAddress';
        }
      }

      // Dodaj parametre za navigaciju
      osmNavigationUrl += '&route=car';

      final Uri uri = Uri.parse(osmNavigationUrl);

      // Pokušaj da otvoriš OpenStreetMap ili navigaciju
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Otvori u navigacionoj aplikaciji
        );
      } else {
        throw Exception('Ne mogu da otvorim navigaciju');
      }
    } catch (e) {
      return false;
    }
  }

  /// 🛠️ Poboljšaj adresu za geocoding
  static String _improveAddressForGeocoding(String address, String grad) {
    // Normalizuj adresu
    String improved = address.trim();

    // Dodaj grad ako nije prisutan
    if (!improved.toLowerCase().contains(grad.toLowerCase()) &&
        !improved.toLowerCase().contains('serbia') &&
        !improved.toLowerCase().contains('srbija')) {
      improved = '$improved, $grad';
    }

    return improved;
  }

  /// 🔢 Generiši sve permutacije (za brute force)
  static List<List<Putnik>> _generatePermutations(List<Putnik> list) {
    if (list.length <= 1) return [list];

    final permutations = <List<Putnik>>[];

    for (int i = 0; i < list.length; i++) {
      final element = list[i];
      final remaining = [...list]..removeAt(i);

      for (final perm in _generatePermutations(remaining)) {
        permutations.add([element, ...perm]);
      }
    }

    return permutations;
  }

  /// 📊 Izračunaj ukupnu distancu optimizovane rute
  static Future<double> _calculateTotalDistance(
    Position start,
    List<Putnik> route,
    Map<Putnik, Position> coordinates,
  ) async {
    if (route.isEmpty) return 0.0;

    double totalDistance = 0.0;
    Position currentPos = start;

    for (final putnik in route) {
      final nextPos = coordinates[putnik]!;
      totalDistance += _calculateDistance(currentPos, nextPos);
      currentPos = nextPos;
    }

    return totalDistance / 1000; // Konvertuj u kilometre
  }
}

/// 📊 Rezultat navigacije
class NavigationResult {
  NavigationResult._({
    required this.success,
    required this.message,
    this.optimizedPutnici,
    this.totalDistance,
  });

  factory NavigationResult.success({
    required String message,
    required List<Putnik> optimizedPutnici,
    double? totalDistance,
  }) {
    return NavigationResult._(
      success: true,
      message: message,
      optimizedPutnici: optimizedPutnici,
      totalDistance: totalDistance,
    );
  }

  factory NavigationResult.error(String message) {
    return NavigationResult._(
      success: false,
      message: message,
    );
  }
  final bool success;
  final String message;
  final List<Putnik>? optimizedPutnici;
  final double? totalDistance;
}
