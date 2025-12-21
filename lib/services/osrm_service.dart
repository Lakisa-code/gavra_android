import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/route_config.dart';
import '../models/putnik.dart';
import 'adresa_supabase_service.dart';
import 'unified_geocoding_service.dart';

/// 🗺️ OSRM SERVICE - OpenStreetMap Routing Machine
class OsrmService {
  OsrmService._();

  /// 🎯 GLAVNA FUNKCIJA: Optimizuj rutu pomoću OSRM Trip API
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
      // 🧹 Očisti cache pre geocodinga da dobijemo sveže koordinate iz baze
      AdresaSupabaseService.clearCache();

      final coordinates = await UnifiedGeocodingService.getCoordinatesForPutnici(
        putnici,
        onProgress: onGeocodingProgress,
      );

      if (coordinates.isEmpty) {
        return OsrmResult.error('Nijedan putnik nema validne koordinate');
      }

      final coordsList = <String>[];

      coordsList.add('${startPosition.longitude},${startPosition.latitude}');

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

      final osrmResponse = await _callOsrmWithRetry(coordsString, hasEndDestination: hasEndDestination);

      if (osrmResponse == null) {
        return OsrmResult.error('OSRM server nije dostupan. Proverite internet konekciju.');
      }

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

        print('🌐 OSRM response: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;

          if (data['code'] == 'Ok' && data['trips'] != null && (data['trips'] as List).isNotEmpty) {
            return data;
          }
        }
      } catch (e) {
        print('❌ OSRM attempt $attempt failed: $e');
      }

      if (attempt < RouteConfig.osrmMaxRetries) {
        final delay = RouteConfig.getRetryDelay(attempt);
        await Future.delayed(delay);
      }
    }

    return null;
  }

  /// 🎯 ISPRAVNO PARSIRANJE OSRM ODGOVORA
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
      final legs = trip['legs'] as List?;

      if (waypoints == null || waypoints.isEmpty) return null;

      final waypointsToProcess = hasEndDestination ? waypoints.length - 1 : waypoints.length;

      final indexByWaypointIndex = <int, int>{};
      for (int i = 1; i < waypointsToProcess; i++) {
        final wp = waypoints[i] as Map<String, dynamic>;
        final waypointIndex = wp['waypoint_index'] as int;
        indexByWaypointIndex[waypointIndex] = i - 1;
      }

      final sortedWaypointIndices = indexByWaypointIndex.keys.toList()..sort();

      final orderedPutnici = <Putnik>[];
      for (final wpIndex in sortedWaypointIndices) {
        final putnikIndex = indexByWaypointIndex[wpIndex]!;
        if (putnikIndex >= 0 && putnikIndex < putniciWithCoords.length) {
          orderedPutnici.add(putniciWithCoords[putnikIndex]);
        }
      }

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

        final legsToProcess = hasEndDestination ? legs.length - 1 : legs.length;

        for (int i = 0; i < legsToProcess && i < orderedPutnici.length; i++) {
          final leg = legs[i] as Map<String, dynamic>;
          final legDuration = (leg['duration'] as num?)?.toDouble() ?? 0;
          cumulativeDurationSec += legDuration;

          final putnik = orderedPutnici[i];
          final etaMinutes = (cumulativeDurationSec / 60).round();
          putniciEta[putnik.ime] = etaMinutes;
        }
      }

      final distance = (trip['distance'] as num).toDouble() / 1000;
      final duration = (trip['duration'] as num).toDouble() / 60;

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
}

class _OsrmParseResult {
  const _OsrmParseResult({
    required this.orderedPutnici,
    required this.distanceKm,
    required this.durationMin,
    required this.putniciEta,
  });

  final List<Putnik> orderedPutnici;
  final double distanceKm;
  final double durationMin;
  final Map<String, int> putniciEta;
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
    this.putniciEta,
  });

  factory OsrmResult.success({
    required List<Putnik> optimizedPutnici,
    required double totalDistanceKm,
    required double totalDurationMin,
    Map<Putnik, Position>? coordinates,
    Map<String, int>? putniciEta,
  }) {
    return OsrmResult._(
      success: true,
      message: '✅ Ruta optimizovana (OSRM)',
      optimizedPutnici: optimizedPutnici,
      totalDistanceKm: totalDistanceKm,
      totalDurationMin: totalDurationMin,
      coordinates: coordinates,
      putniciEta: putniciEta,
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
  final Map<String, int>? putniciEta;
}
