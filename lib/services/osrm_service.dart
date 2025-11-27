import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/putnik.dart';
import 'adresa_supabase_service.dart';
import 'geocoding_service.dart';

/// 🗺️ OSRM SERVICE - OpenStreetMap Routing Machine
/// Koristi javni OSRM API za optimizaciju ruta
/// OSRM Trip API automatski rešava TSP problem i vraća optimalnu rutu
class OsrmService {
  // 🌐 Javni OSRM server (besplatan, bez API ključa)
  static const String _osrmBaseUrl = 'https://router.project-osrm.org';
  
  // ⏱️ Timeout za API pozive
  static const Duration _timeout = Duration(seconds: 15);

  /// 🎯 GLAVNA FUNKCIJA: Optimizuj rutu pomoću OSRM Trip API
  /// OSRM Trip API rešava TSP problem i vraća optimalnu rutu
  /// https://project-osrm.org/docs/v5.24.0/api/#trip-service
  static Future<OsrmResult> optimizeRoute({
    required Position startPosition,
    required List<Putnik> putnici,
  }) async {
    if (putnici.isEmpty) {
      return OsrmResult.error('Nema putnika za optimizaciju');
    }

    try {
      // 1. Dobij koordinate za sve putnike
      final coordinates = await getCoordinatesForPutnici(putnici);
      
      if (coordinates.isEmpty) {
        return OsrmResult.error('Nijedan putnik nema validne koordinate');
      }

      // 2. Pripremi koordinate za OSRM API (format: lng,lat;lng,lat;...)
      final coordsList = <String>[];
      
      // Dodaj startnu poziciju
      coordsList.add('${startPosition.longitude},${startPosition.latitude}');
      
      // Dodaj sve putnike sa koordinatama
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
      
      // 3. Pozovi OSRM Trip API
      // source=first znači da počinjemo od prve tačke (vozač)
      // roundtrip=false znači da ne treba da se vraćamo na početak
      final url = '$_osrmBaseUrl/trip/v1/driving/$coordsString'
          '?source=first'
          '&roundtrip=false'
          '&geometries=polyline'
          '&overview=simplified'
          '&annotations=distance,duration';
      
      print('🗺️ OSRM Trip API URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        print('❌ OSRM API greška: ${response.statusCode}');
        return OsrmResult.error('OSRM API greška: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      if (data['code'] != 'Ok') {
        print('❌ OSRM API kod: ${data['code']}');
        return OsrmResult.error('OSRM greška: ${data['code']}');
      }

      // 4. Parsiraj rezultat
      final trips = data['trips'] as List;
      if (trips.isEmpty) {
        return OsrmResult.error('OSRM nije vratio rutu');
      }

      final trip = trips[0];
      final waypoints = data['waypoints'] as List;
      
      // OSRM vraća waypoint_index koji pokazuje optimalni redosled
      // Index 0 je startna pozicija (vozač), ostali su putnici
      final orderedPutnici = <Putnik>[];
      
      // Sortiraj waypoint-e po trip_index (optimalni redosled)
      final sortedWaypoints = List<Map<String, dynamic>>.from(waypoints);
      sortedWaypoints.sort((a, b) => 
          (a['waypoint_index'] as int).compareTo(b['waypoint_index'] as int));
      
      for (final wp in sortedWaypoints) {
        final wpIndex = wp['waypoint_index'] as int;
        // Preskoči index 0 (to je startna pozicija vozača)
        if (wpIndex > 0 && wpIndex <= putniciWithCoords.length) {
          orderedPutnici.add(putniciWithCoords[wpIndex - 1]);
        }
      }

      // Ako OSRM nije vratio sve putnike, koristi originalni redosled
      if (orderedPutnici.length != putniciWithCoords.length) {
        print('⚠️ OSRM vratio ${orderedPutnici.length} od ${putniciWithCoords.length} putnika');
        // Dodaj one koji nedostaju na kraj
        for (final p in putniciWithCoords) {
          if (!orderedPutnici.contains(p)) {
            orderedPutnici.add(p);
          }
        }
      }

      // 5. Izračunaj ukupnu distancu i vreme
      final distance = (trip['distance'] as num).toDouble() / 1000; // u km
      final duration = (trip['duration'] as num).toDouble() / 60; // u minutima

      print('✅ OSRM optimizacija uspešna:');
      print('   📏 Distanca: ${distance.toStringAsFixed(1)} km');
      print('   ⏱️ Vreme: ${duration.toStringAsFixed(0)} min');
      print('   👥 Putnici: ${orderedPutnici.map((p) => p.ime).join(' → ')}');

      return OsrmResult.success(
        optimizedPutnici: orderedPutnici,
        totalDistanceKm: distance,
        totalDurationMin: duration,
        coordinates: coordinates,
      );
    } catch (e) {
      print('❌ OSRM greška: $e');
      return OsrmResult.error('Greška pri optimizaciji: $e');
    }
  }

  /// 🗺️ Dobij koordinate za sve putnike (isto kao SmartNavigationService)
  /// Javna metoda za korišćenje u drugim servisima
  static Future<Map<Putnik, Position>> getCoordinatesForPutnici(
    List<Putnik> putnici,
  ) async {
    final Map<Putnik, Position> coordinates = {};

    // Koordinate centra gradova - za proveru
    const double belaCrkvaLat = 44.9013448;
    const double belaCrkvaLng = 21.4240519;
    const double vrsacLat = 45.1167;
    const double vrsacLng = 21.3;
    const double tolerance = 0.001;

    bool isCityCenterCoordinate(double? lat, double? lng) {
      if (lat == null || lng == null) {
        return false;
      }
      if ((lat - belaCrkvaLat).abs() < tolerance && 
          (lng - belaCrkvaLng).abs() < tolerance) {
        return true;
      }
      if ((lat - vrsacLat).abs() < tolerance && 
          (lng - vrsacLng).abs() < tolerance) {
        return true;
      }
      return false;
    }

    for (final putnik in putnici) {
      if (putnik.adresa == null || putnik.adresa!.trim().isEmpty) {
        continue;
      }

      try {
        Position? position;

        // PRIORITET 1: Koordinate iz baze
        if (putnik.adresaId != null && putnik.adresaId!.isNotEmpty) {
          final adresaFromDb = await AdresaSupabaseService.getAdresaByUuid(
            putnik.adresaId!,
          );
          if (adresaFromDb != null &&
              adresaFromDb.latitude != null &&
              adresaFromDb.longitude != null &&
              !isCityCenterCoordinate(adresaFromDb.latitude, adresaFromDb.longitude)) {
            position = Position(
              latitude: adresaFromDb.latitude!,
              longitude: adresaFromDb.longitude!,
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

        // PRIORITET 2: Geocoding preko Nominatim
        if (position == null) {
          final coordsString = await GeocodingService.getKoordinateZaAdresu(
            putnik.grad,
            putnik.adresa!,
          );

          if (coordsString != null && coordsString.contains(',')) {
            final parts = coordsString.split(',');
            final lat = double.tryParse(parts[0].trim());
            final lng = double.tryParse(parts[1].trim());

            if (lat != null && lng != null) {
              position = Position(
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

              // Sačuvaj u bazu za sledeći put
              if (putnik.adresaId != null && putnik.adresaId!.isNotEmpty) {
                await AdresaSupabaseService.updateKoordinate(
                  putnik.adresaId!,
                  lat: lat,
                  lng: lng,
                );
              }
            }
          }
        }

        if (position != null) {
          coordinates[putnik] = position;
        }
      } catch (e) {
        // Ignoriši greške za pojedinačne putnike
      }
    }

    return coordinates;
  }

  /// 📏 Izračunaj distancu između dve tačke (Haversine formula) 
  /// Koristi se kao fallback ako OSRM ne radi
  static double calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  /// 🔄 Fallback optimizacija (Nearest Neighbor) ako OSRM ne radi
  static Future<List<Putnik>> fallbackOptimization({
    required Position startPosition,
    required List<Putnik> putnici,
    required Map<Putnik, Position> coordinates,
  }) async {
    final unvisited = putnici.where((p) => coordinates.containsKey(p)).toList();
    final route = <Putnik>[];
    Position currentPosition = startPosition;

    while (unvisited.isNotEmpty) {
      Putnik? nearest;
      double shortestDistance = double.infinity;

      for (final putnik in unvisited) {
        final distance = calculateDistance(currentPosition, coordinates[putnik]!);
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
  });

  factory OsrmResult.success({
    required List<Putnik> optimizedPutnici,
    required double totalDistanceKm,
    required double totalDurationMin,
    Map<Putnik, Position>? coordinates,
  }) {
    return OsrmResult._(
      success: true,
      message: '✅ Ruta optimizovana',
      optimizedPutnici: optimizedPutnici,
      totalDistanceKm: totalDistanceKm,
      totalDurationMin: totalDurationMin,
      coordinates: coordinates,
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
}
