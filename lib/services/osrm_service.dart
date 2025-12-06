import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/route_config.dart';
import '../models/putnik.dart';
import 'huawei_map_service.dart';
import 'unified_geocoding_service.dart';

/// 🗺️ OSRM SERVICE - OpenStreetMap Routing Machine
/// Koristi javni OSRM API za optimizaciju ruta
/// OSRM Trip API automatski rešava TSP problem i vraća optimalnu rutu
///
/// REFACTORED: Koristi RouteConfig i UnifiedGeocodingService
class OsrmService {
  OsrmService._();

  /// 🎯 GLAVNA FUNKCIJA: Optimizuj rutu pomoću OSRM Trip API
  /// OSRM Trip API rešava TSP problem i vraća optimalnu rutu
  /// https://project-osrm.org/docs/v5.24.0/api/#trip-service
  ///
  /// FIXED: Ispravno parsiranje waypoint redosleda + retry logika
  ///
  /// [endDestination] - Opciona fiksna krajnja destinacija (npr. Vršac ili Bela Crkva)
  /// Ako je zadat, OSRM će optimizovati rutu tako da završi na toj lokaciji
  static Future<OsrmResult> optimizeRoute({
    required Position startPosition,
    required List<Putnik> putnici,
    Position? endDestination,
    GeocodingProgressCallback? onGeocodingProgress,
  }) async {
    if (putnici.isEmpty) {
      return OsrmResult.error('Nema putnika za optimizaciju');
    }

    try {
      // 1. Dobij koordinate za sve putnike (koristi UnifiedGeocodingService)
      final coordinates = await UnifiedGeocodingService.getCoordinatesForPutnici(
        putnici,
        onProgress: onGeocodingProgress,
      );

      if (coordinates.isEmpty) {
        return OsrmResult.error('Nijedan putnik nema validne koordinate');
      }

      // 2. Pripremi koordinate za OSRM API (format: lng,lat;lng,lat;...)
      final coordsList = <String>[];

      // Dodaj startnu poziciju
      coordsList.add('${startPosition.longitude},${startPosition.latitude}');

      // Dodaj sve putnike sa koordinatama (čuvaj redosled za mapiranje)
      final putniciWithCoords = <Putnik>[];
      for (final putnik in putnici) {
        if (coordinates.containsKey(putnik)) {
          final pos = coordinates[putnik]!;
          coordsList.add('${pos.longitude},${pos.latitude}');
          putniciWithCoords.add(putnik);
        }
      }

      if (putniciWithCoords.isEmpty) {
        return OsrmResult.error('Nema putnika sa validnim koordinatama');
      }

      // 🎯 Dodaj krajnju destinaciju ako je zadata (Vršac ili Bela Crkva)
      final hasEndDestination = endDestination != null;
      if (hasEndDestination) {
        coordsList.add('${endDestination.longitude},${endDestination.latitude}');
      }

      final coordsString = coordsList.join(';');

      // 3. Pozovi OSRM Trip API SA RETRY LOGIKOM
      final osrmResponse = await _callOsrmWithRetry(coordsString, hasEndDestination: hasEndDestination);

      if (osrmResponse == null) {
        // 🎯 FALLBACK 1: Pokušaj Huawei Map Kit
        final huaweiResult = await _tryHuaweiOptimization(
          startPosition: startPosition,
          putnici: putniciWithCoords,
          coordinates: coordinates,
        );

        if (huaweiResult != null) {
          return huaweiResult;
        }

        // 🎯 FALLBACK 2: Lokalni algoritam
        final fallbackRoute = await UnifiedGeocodingService.fallbackOptimization(
          startPosition: startPosition,
          putnici: putniciWithCoords,
          coordinates: coordinates,
          use2opt: true,
        );

        return OsrmResult.success(
          optimizedPutnici: fallbackRoute,
          totalDistanceKm: _calculateTotalDistance(startPosition, fallbackRoute, coordinates),
          totalDurationMin: 0, // Nepoznato bez OSRM
          coordinates: coordinates,
          usedFallback: true,
        );
      }

      // 4. Parsiraj i validiraj OSRM odgovor
      final parseResult = _parseOsrmResponse(
        osrmResponse,
        putniciWithCoords,
        coordinates,
        hasEndDestination: hasEndDestination,
      );

      if (parseResult == null) {
        return OsrmResult.error('Greška pri parsiranju OSRM odgovora');
      }

      return OsrmResult.success(
        optimizedPutnici: parseResult.orderedPutnici,
        totalDistanceKm: parseResult.distanceKm,
        totalDurationMin: parseResult.durationMin,
        coordinates: coordinates,
        putniciEta: parseResult.putniciEta, // 🆕 ETA za svakog putnika
      );
    } catch (e) {
      return OsrmResult.error('Greška pri optimizaciji: $e');
    }
  }

  /// 🔄 Pozovi OSRM API sa exponential backoff retry
  /// [hasEndDestination] - ako je true, dodaje destination=last parametar
  static Future<Map<String, dynamic>?> _callOsrmWithRetry(
    String coordsString, {
    bool hasEndDestination = false,
  }) async {
    for (int attempt = 1; attempt <= RouteConfig.osrmMaxRetries; attempt++) {
      try {
        // 🎯 Ako imamo fiksnu krajnju destinaciju, dodaj destination=last
        final destinationParam = hasEndDestination ? '&destination=last' : '';
        final url = '${RouteConfig.osrmBaseUrl}/trip/v1/driving/$coordsString'
            '?source=first'
            '&roundtrip=false'
            '$destinationParam'
            '&geometries=polyline'
            '&overview=simplified'
            '&annotations=distance,duration';

        final response = await http.get(
          Uri.parse(url),
          headers: {'Accept': 'application/json'},
        ).timeout(RouteConfig.osrmTimeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;

          // Validiraj odgovor
          if (data['code'] == 'Ok' && data['trips'] != null && (data['trips'] as List).isNotEmpty) {
            return data;
          }
        } else {
          // HTTP greška
        }
      } catch (e) {
        // OSRM pokušaj neuspešan
      }

      // Exponential backoff pre sledećeg pokušaja
      if (attempt < RouteConfig.osrmMaxRetries) {
        final delay = RouteConfig.getRetryDelay(attempt);
        await Future.delayed(delay);
      }
    }

    return null; // Svi pokušaji neuspešni
  }

  /// 🎯 ISPRAVNO PARSIRANJE OSRM ODGOVORA
  /// Koristi trips[0].legs za ETA svakog putnika
  /// [hasEndDestination] - ako je true, ignoriše poslednji waypoint jer je to fiksna destinacija
  static _OsrmParseResult? _parseOsrmResponse(
    Map<String, dynamic> data,
    List<Putnik> putniciWithCoords,
    Map<Putnik, Position> coordinates, {
    bool hasEndDestination = false,
  }) {
    try {
      final trips = data['trips'] as List;
      if (trips.isEmpty) return null;

      final trip = trips[0] as Map<String, dynamic>;
      final waypoints = data['waypoints'] as List?;
      final legs = trip['legs'] as List?; // 🆕 Izvuci legs za ETA

      if (waypoints == null || waypoints.isEmpty) return null;

      // 🎯 Ako imamo krajnju destinaciju, poslednji waypoint je destinacija, ne putnik!
      final waypointsToProcess = hasEndDestination ? waypoints.length - 1 : waypoints.length;

      // Kreiraj listu (waypointIndex, originalIndex) parova
      final waypointMapping = <_WaypointMapping>[];

      for (int i = 0; i < waypointsToProcess; i++) {
        final wp = waypoints[i] as Map<String, dynamic>;
        final waypointIndex = wp['waypoint_index'] as int;
        waypointMapping.add(_WaypointMapping(
          originalIndex: i,
          waypointIndex: waypointIndex,
        ));
      }

      // Sortiraj po waypoint_index da dobijemo optimalni redosled
      waypointMapping.sort((a, b) => a.waypointIndex.compareTo(b.waypointIndex));

      // Mapiraj nazad na putnike (preskoči prvi waypoint koji je start pozicija)
      final orderedPutnici = <Putnik>[];

      for (final mapping in waypointMapping) {
        // originalIndex 0 je startna pozicija vozača - preskoči
        if (mapping.originalIndex > 0 && mapping.originalIndex <= putniciWithCoords.length) {
          orderedPutnici.add(putniciWithCoords[mapping.originalIndex - 1]);
        }
      }

      // Ako nedostaju putnici, dodaj ih na kraj
      if (orderedPutnici.length != putniciWithCoords.length) {
        for (final p in putniciWithCoords) {
          if (!orderedPutnici.contains(p)) {
            orderedPutnici.add(p);
          }
        }
      }

      // 🆕 Izračunaj ETA za svakog putnika iz legs
      final putniciEta = <String, int>{};

      if (legs != null && legs.isNotEmpty) {
        double cumulativeDurationSec = 0;

        // legs[i] je segment od waypoint[i] do waypoint[i+1]
        // legs[0] = vozač -> prvi putnik
        // legs[1] = prvi putnik -> drugi putnik
        // itd.

        final legsToProcess = hasEndDestination
            ? legs.length - 1 // Ignoriši poslednji leg (do destinacije)
            : legs.length;

        for (int i = 0; i < legsToProcess && i < orderedPutnici.length; i++) {
          final leg = legs[i] as Map<String, dynamic>;
          final legDuration = (leg['duration'] as num?)?.toDouble() ?? 0;
          cumulativeDurationSec += legDuration;

          // Dodaj ETA za ovog putnika (u minutama, zaokruženo)
          final putnik = orderedPutnici[i];
          final etaMinutes = (cumulativeDurationSec / 60).round();
          putniciEta[putnik.ime] = etaMinutes;
        }
      }

      // Izračunaj distancu i vreme
      final distance = (trip['distance'] as num).toDouble() / 1000; // u km
      final duration = (trip['duration'] as num).toDouble() / 60; // u minutima

      return _OsrmParseResult(
        orderedPutnici: orderedPutnici,
        distanceKm: distance,
        durationMin: duration,
        putniciEta: putniciEta,
      );
    } catch (e) {
      return null;
    }
  }

  /// 📝 Izračunaj ukupnu distancu rute
  static double _calculateTotalDistance(
    Position start,
    List<Putnik> route,
    Map<Putnik, Position> coordinates,
  ) {
    if (route.isEmpty) return 0;

    double total = 0;
    Position current = start;

    for (final putnik in route) {
      if (coordinates.containsKey(putnik)) {
        total += calculateDistance(current, coordinates[putnik]!);
        current = coordinates[putnik]!;
      }
    }

    return total / 1000; // Konvertuj u km
  }

  /// 🇸🇰 HUAWEI FALLBACK - Pokušaj optimizaciju preko Huawei Map Kit
  static Future<OsrmResult?> _tryHuaweiOptimization({
    required Position startPosition,
    required List<Putnik> putnici,
    required Map<Putnik, Position> coordinates,
  }) async {
    try {
      final huaweiResult = await HuaweiMapService.optimizeRoute(
        startPosition: startPosition,
        putnici: putnici,
        coordinates: coordinates,
      );

      if (huaweiResult.success && huaweiResult.optimizedPutnici != null) {
        return OsrmResult.success(
          optimizedPutnici: huaweiResult.optimizedPutnici!,
          totalDistanceKm: huaweiResult.totalDistanceKm ?? 0,
          totalDurationMin: huaweiResult.totalDurationMin ?? 0,
          coordinates: coordinates,
          usedFallback: true,
        );
      }
    } catch (e) {
      // Huawei Map Kit greška
    }

    return null; // Huawei nije uspešan, nastavi sa sledećim fallback-om
  }

  /// 🗺️ Dobij koordinate za sve putnike
  /// DELEGIRA na UnifiedGeocodingService
  static Future<Map<Putnik, Position>> getCoordinatesForPutnici(
    List<Putnik> putnici, {
    GeocodingProgressCallback? onProgress,
  }) async {
    return UnifiedGeocodingService.getCoordinatesForPutnici(
      putnici,
      onProgress: onProgress,
    );
  }

  /// 📏 Izračunaj distancu između dve tačke (Haversine formula)
  static double calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  /// 🔄 Fallback optimizacija (Nearest Neighbor + 2-opt)
  /// DELEGIRA na UnifiedGeocodingService
  static Future<List<Putnik>> fallbackOptimization({
    required Position startPosition,
    required List<Putnik> putnici,
    required Map<Putnik, Position> coordinates,
  }) async {
    return UnifiedGeocodingService.fallbackOptimization(
      startPosition: startPosition,
      putnici: putnici,
      coordinates: coordinates,
      use2opt: true,
    );
  }
}

/// Helper klasa za waypoint mapiranje
class _WaypointMapping {
  const _WaypointMapping({
    required this.originalIndex,
    required this.waypointIndex,
  });

  final int originalIndex;
  final int waypointIndex;
}

/// Helper klasa za OSRM parse rezultat
class _OsrmParseResult {
  const _OsrmParseResult({
    required this.orderedPutnici,
    required this.distanceKm,
    required this.durationMin,
    required this.putniciEta, // 🆕 ETA za svakog putnika
  });

  final List<Putnik> orderedPutnici;
  final double distanceKm;
  final double durationMin;
  final Map<String, int> putniciEta; // ime_putnika -> ETA u minutama
}

/// 📊 Rezultat OSRM optimizacije
class OsrmResult {
  OsrmResult._({
    required this.success,
    required this.message,
    this.optimizedPutnici,
    this.totalDistanceKm,
    this.totalDurationMin,
    this.coordinates,
    this.putniciEta, // 🆕 ETA za svakog putnika
    this.usedFallback = false,
  });

  factory OsrmResult.success({
    required List<Putnik> optimizedPutnici,
    required double totalDistanceKm,
    required double totalDurationMin,
    Map<Putnik, Position>? coordinates,
    Map<String, int>? putniciEta, // 🆕
    bool usedFallback = false,
  }) {
    return OsrmResult._(
      success: true,
      message: usedFallback ? '✅ Ruta optimizovana (lokalno)' : '✅ Ruta optimizovana (OSRM)',
      optimizedPutnici: optimizedPutnici,
      totalDistanceKm: totalDistanceKm,
      totalDurationMin: totalDurationMin,
      coordinates: coordinates,
      putniciEta: putniciEta,
      usedFallback: usedFallback,
    );
  }

  factory OsrmResult.error(String message) {
    return OsrmResult._(
      success: false,
      message: message,
    );
  }

  final bool success;
  final String message;
  final List<Putnik>? optimizedPutnici;
  final double? totalDistanceKm;
  final double? totalDurationMin;
  final Map<Putnik, Position>? coordinates;
  final Map<String, int>? putniciEta; // 🆕 ime_putnika -> ETA u minutama
  final bool usedFallback;
}
