import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/route_config.dart';
import '../models/putnik.dart';
import 'adresa_supabase_service.dart';
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
      // 🧹 Očisti cache pre geocodinga da dobijemo sveže koordinate iz baze
      AdresaSupabaseService.clearCache();

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
        return OsrmResult.error('OSRM server nije dostupan. Proverite internet konekciju.');
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
        }
      } catch (e) {
        // OSRM pokušaj neuspešan - nastavi sa retry
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
  /// OSRM Trip API vraća:
  /// - data['waypoints'] - waypoints u ULAZNOM redosledu, sa waypoint_index koji pokazuje poziciju u optimalnoj ruti
  /// - trips[0]['legs'] - segmenti u OPTIMIZOVANOM redosledu
  ///
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
      final legs = trip['legs'] as List?;

      if (waypoints == null || waypoints.isEmpty) return null;

      // 🎯 KLJUČNO: waypoint_index pokazuje poziciju u OPTIMIZOVANOJ ruti
      // waypoints su u ULAZNOM redosledu, ali waypoint_index daje optimalni redosled
      //
      // Primer:
      // Input: start, putnikA, putnikB, putnikC
      // waypoints[0] (start):    waypoint_index=0
      // waypoints[1] (putnikA):  waypoint_index=2  -> treći u optimalnoj ruti
      // waypoints[2] (putnikB):  waypoint_index=1  -> drugi u optimalnoj ruti
      // waypoints[3] (putnikC):  waypoint_index=3  -> četvrti u optimalnoj ruti
      // Optimalni redosled: start(0) -> putnikB(1) -> putnikA(2) -> putnikC(3)

      // 🎯 Ako imamo krajnju destinaciju, poslednji waypoint je destinacija, ne putnik!
      final waypointsToProcess = hasEndDestination ? waypoints.length - 1 : waypoints.length;

      // Kreiraj mapu: waypoint_index -> index putnika u putniciWithCoords
      // Preskačemo waypoints[0] jer je to startna pozicija
      final indexByWaypointIndex = <int, int>{};
      for (int i = 1; i < waypointsToProcess; i++) {
        final wp = waypoints[i] as Map<String, dynamic>;
        final waypointIndex = wp['waypoint_index'] as int;
        indexByWaypointIndex[waypointIndex] = i - 1; // Index putnika (0-based)
      }

      // Sortiraj waypoint_index vrednosti da dobijemo optimalni redosled
      final sortedWaypointIndices = indexByWaypointIndex.keys.toList()..sort();

      // Mapiraj nazad na putnike u sortiranom redosledu
      final orderedPutnici = <Putnik>[];
      for (final wpIndex in sortedWaypointIndices) {
        final putnikIndex = indexByWaypointIndex[wpIndex]!;
        if (putnikIndex >= 0 && putnikIndex < putniciWithCoords.length) {
          orderedPutnici.add(putniciWithCoords[putnikIndex]);
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
