import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/route_config.dart';
import '../models/putnik.dart';
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
  static Future<OsrmResult> optimizeRoute({
    required Position startPosition,
    required List<Putnik> putnici,
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

      final coordsString = coordsList.join(';');
      
      // 3. Pozovi OSRM Trip API SA RETRY LOGIKOM
      final osrmResponse = await _callOsrmWithRetry(coordsString);
      
      if (osrmResponse == null) {
        // Fallback na lokalni algoritam ako OSRM ne radi
        print('⚠️ OSRM nije dostupan, koristim fallback optimizaciju');
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
      );
      
      if (parseResult == null) {
        return OsrmResult.error('Greška pri parsiranju OSRM odgovora');
      }

      return OsrmResult.success(
        optimizedPutnici: parseResult.orderedPutnici,
        totalDistanceKm: parseResult.distanceKm,
        totalDurationMin: parseResult.durationMin,
        coordinates: coordinates,
      );
    } catch (e) {
      print('❌ OSRM greška: $e');
      return OsrmResult.error('Greška pri optimizaciji: $e');
    }
  }

  /// 🔄 Pozovi OSRM API sa exponential backoff retry
  static Future<Map<String, dynamic>?> _callOsrmWithRetry(
    String coordsString,
  ) async {
    for (int attempt = 1; attempt <= RouteConfig.osrmMaxRetries; attempt++) {
      try {
        final url = '${RouteConfig.osrmBaseUrl}/trip/v1/driving/$coordsString'
            '?source=first'
            '&roundtrip=false'
            '&geometries=polyline'
            '&overview=simplified'
            '&annotations=distance,duration';
        
        print('🗺️ OSRM Trip API pokušaj $attempt: $url');
        
        final response = await http.get(
          Uri.parse(url),
          headers: {'Accept': 'application/json'},
        ).timeout(RouteConfig.osrmTimeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          
          // Validiraj odgovor
          if (data['code'] == 'Ok' && 
              data['trips'] != null && 
              (data['trips'] as List).isNotEmpty) {
            return data;
          }
          
          print('⚠️ OSRM vratio nevažeći odgovor: ${data['code']}');
        } else {
          print('⚠️ OSRM HTTP greška: ${response.statusCode}');
        }
      } catch (e) {
        print('⚠️ OSRM pokušaj $attempt neuspešan: $e');
      }
      
      // Exponential backoff pre sledećeg pokušaja
      if (attempt < RouteConfig.osrmMaxRetries) {
        final delay = RouteConfig.getRetryDelay(attempt);
        print('⏳ Čekam ${delay.inMilliseconds}ms pre sledećeg pokušaja...');
        await Future.delayed(delay);
      }
    }
    
    return null; // Svi pokušaji neuspešni
  }

  /// 🎯 ISPRAVNO PARSIRANJE OSRM ODGOVORA
  /// FIXED: Koristi trips[0].legs redosled umesto pogrešnog waypoint_index
  static _OsrmParseResult? _parseOsrmResponse(
    Map<String, dynamic> data,
    List<Putnik> putniciWithCoords,
    Map<Putnik, Position> coordinates,
  ) {
    try {
      final trips = data['trips'] as List;
      if (trips.isEmpty) return null;
      
      final trip = trips[0] as Map<String, dynamic>;
      final waypoints = data['waypoints'] as List?;
      
      if (waypoints == null || waypoints.isEmpty) return null;
      
      // ✅ ISPRAVNO: Koristi waypoints_index za mapiranje optimizovanog redosleda
      // waypoints[i].waypoint_index pokazuje gde je ta tačka u OPTIMIZOVANOJ ruti
      // waypoints[i].trips_index pokazuje koji trip (uvek 0 za nas)
      
      // Kreiraj listu (waypointIndex, originalIndex) parova
      final waypointMapping = <_WaypointMapping>[];
      
      for (int i = 0; i < waypoints.length; i++) {
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
        if (mapping.originalIndex > 0 && 
            mapping.originalIndex <= putniciWithCoords.length) {
          orderedPutnici.add(putniciWithCoords[mapping.originalIndex - 1]);
        }
      }
      
      // Ako nedostaju putnici, dodaj ih na kraj
      if (orderedPutnici.length != putniciWithCoords.length) {
        print('⚠️ OSRM vratio ${orderedPutnici.length} od ${putniciWithCoords.length} putnika');
        for (final p in putniciWithCoords) {
          if (!orderedPutnici.contains(p)) {
            orderedPutnici.add(p);
          }
        }
      }

      // Izračunaj distancu i vreme
      final distance = (trip['distance'] as num).toDouble() / 1000; // u km
      final duration = (trip['duration'] as num).toDouble() / 60; // u minutima

      print('✅ OSRM optimizacija uspešna:');
      print('   📏 Distanca: ${distance.toStringAsFixed(1)} km');
      print('   ⏱️ Vreme: ${duration.toStringAsFixed(0)} min');
      print('   👥 Putnici: ${orderedPutnici.map((p) => p.ime).join(' → ')}');

      return _OsrmParseResult(
        orderedPutnici: orderedPutnici,
        distanceKm: distance,
        durationMin: duration,
      );
    } catch (e) {
      print('❌ Greška pri parsiranju OSRM odgovora: $e');
      return null;
    }
  }

  /// 📏 Izračunaj ukupnu distancu rute
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
  });
  
  final List<Putnik> orderedPutnici;
  final double distanceKm;
  final double durationMin;
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
    this.usedFallback = false,
  });

  factory OsrmResult.success({
    required List<Putnik> optimizedPutnici,
    required double totalDistanceKm,
    required double totalDurationMin,
    Map<Putnik, Position>? coordinates,
    bool usedFallback = false,
  }) {
    return OsrmResult._(
      success: true,
      message: usedFallback ? '✅ Ruta optimizovana (lokalno)' : '✅ Ruta optimizovana (OSRM)',
      optimizedPutnici: optimizedPutnici,
      totalDistanceKm: totalDistanceKm,
      totalDurationMin: totalDurationMin,
      coordinates: coordinates,
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
  final bool usedFallback;
}
