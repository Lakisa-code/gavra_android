import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/putnik.dart';
import 'unified_geocoding_service.dart'; // 🎯 REFACTORED: Centralizovani geocoding

/// 🎯 SMART NAVIGATION SERVICE
/// Implementira pravu GPS navigaciju sa optimizovanim redosledom putnika
/// Koristi OpenStreetMap / self-hosted OSRM/Valhalla ili platform-specific aplikacije za otvaranje rute.
class SmartNavigationService {
  /// 🎯 SAMO OPTIMIZACIJA RUTE (bez otvaranja mape) - za "Pokreni" dugme
  static Future<NavigationResult> optimizeRouteOnly({
    required List<Putnik> putnici,
    required String startCity,
    bool optimizeForTime = true,
  }) async {
    print('');
    print('🚀🚀🚀 ===== OPTIMIZE ROUTE ONLY STARTED ===== 🚀🚀🚀');
    print('🚀 Broj putnika: ${putnici.length}');
    print('🚀 Start city: $startCity');
    print('');
    try {
      // 1. DOBIJ TRENUTNU GPS POZICIJU VOZAČA
      final currentPosition = await _getCurrentPosition();
      print('📍 VOZAČ POZICIJA: lat=${currentPosition.latitude}, lng=${currentPosition.longitude}');

      // 2. DOBIJ KOORDINATE ZA SVE ADRESE (REFACTORED: koristi UnifiedGeocodingService)
      final Map<Putnik, Position> coordinates = await UnifiedGeocodingService.getCoordinatesForPutnici(
        putnici,
        onProgress: (completed, total, address) {
          print('📍 Geocoding: $completed/$total - $address');
        },
      );

      // 🆕 Nađi preskočene putnike (nemaju koordinate)
      final skipped = putnici.where((p) => !coordinates.containsKey(p)).toList();

      if (coordinates.isEmpty) {
        return NavigationResult.error(
          '❌ Nijedan putnik nema validnu adresu za navigaciju',
        );
      }

      // 3. OPTIMIZUJ REDOSLED PUTNIKA SA 2-OPT (REFACTORED: koristi UnifiedGeocodingService)
      final optimizedRoute = await UnifiedGeocodingService.fallbackOptimization(
        startPosition: currentPosition,
        putnici: coordinates.keys.toList(),
        coordinates: coordinates,
        use2opt: true, // 🎯 AKTIVIRANO: 2-opt poboljšava rutu za 10-15%
      );

      // 🔍 DEBUG: Prikaži distance za svakog putnika
      print('📊 === DISTANCE OD VOZAČA ===');
      for (final putnik in coordinates.keys) {
        final pos = coordinates[putnik]!;
        final distance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          pos.latitude,
          pos.longitude,
        );
        print('   📍 ${putnik.ime}: ${distance.toStringAsFixed(0)}m (lat=${pos.latitude}, lng=${pos.longitude})');
      }
      print('📊 ========================');

      // 4. VRATI OPTIMIZOVANU RUTU BEZ OTVARANJA MAPE
      return NavigationResult.success(
        message: '✅ Ruta optimizovana',
        optimizedPutnici: optimizedRoute,
        totalDistance: await _calculateTotalDistance(
          currentPosition,
          optimizedRoute,
          coordinates,
        ),
        skippedPutnici: skipped.isNotEmpty ? skipped : null,
      );
    } catch (e) {
      return NavigationResult.error('❌ Greška pri optimizaciji: $e');
    }
  }

  /// 🚗 GLAVNA FUNKCIJA - Otvori mapu sa optimizovanom rutom (preferirano OSM/OSRM)
  /// 🎯 skipOptimization=true: koristi prosleđenu listu bez re-optimizacije (za NAV dugme)
  static Future<NavigationResult> startOptimizedNavigation({
    required List<Putnik> putnici,
    required String startCity, // 'Bela Crkva' ili 'Vršac'
    bool optimizeForTime = true, // true = vreme, false = distanca
    bool useTrafficData = false, // 🚦 NOVO: traffic-aware routing
    bool skipOptimization = true, // 🎯 NOVO: preskoči re-optimizaciju ako je ruta već optimizovana
  }) async {
    print('');
    print('🗺️🗺️🗺️ ===== START OPTIMIZED NAVIGATION ===== 🗺️🗺️🗺️');
    print('🗺️ Broj putnika: ${putnici.length}');
    print('🗺️ Start city: $startCity');
    print('🗺️ useTrafficData: $useTrafficData');
    print('🗺️ skipOptimization: $skipOptimization');
    print('');
    try {
      // 1. DOBIJ TRENUTNU GPS POZICIJU VOZAČA
      final currentPosition = await _getCurrentPosition();

      // 2. DOBIJ KOORDINATE ZA SVE ADRESE (REFACTORED: koristi UnifiedGeocodingService)
      final Map<Putnik, Position> coordinates = await UnifiedGeocodingService.getCoordinatesForPutnici(
        putnici,
        onProgress: (completed, total, address) {
          print('📍 Geocoding: $completed/$total - $address');
        },
      );

      if (coordinates.isEmpty) {
        return NavigationResult.error(
          '❌ Nijedan putnik nema validnu adresu za navigaciju',
        );
      }

      // 3. OPTIMIZUJ REDOSLED PUTNIKA (ili koristi već optimizovanu listu)
      List<Putnik> optimizedRoute;

      if (skipOptimization) {
        // 🎯 KORISTI VEĆ OPTIMIZOVANU LISTU (od "Ruta" dugmeta)
        print('🎯 Koristi već optimizovanu rutu (skipOptimization=true)');
        optimizedRoute = putnici;
      } else {
        // 🎯 OPTIMIZACIJA SA 2-OPT (REFACTORED: koristi UnifiedGeocodingService)
        optimizedRoute = await UnifiedGeocodingService.fallbackOptimization(
          startPosition: currentPosition,
          putnici: coordinates.keys.toList(),
          coordinates: coordinates,
          use2opt: true, // 🎯 2-opt poboljšava Nearest Neighbor za 10-15%
        );
      }

      // 4. OTVORI RUTU U GOOGLE MAPS SA WAYPOINT-IMA (max 10)
      final success = await _openGoogleMapsNavigation(
        currentPosition,
        optimizedRoute,
        startCity,
        useTrafficData: useTrafficData,
      );

      // Informacija o broju putnika
      final maxWaypoints = 10;
      final shownCount = optimizedRoute.length > maxWaypoints ? maxWaypoints : optimizedRoute.length;
      final remainingCount = optimizedRoute.length > maxWaypoints ? optimizedRoute.length - maxWaypoints : 0;

      if (success) {
        String message = '🎯 Google Maps: $shownCount putnika';
        if (remainingCount > 0) {
          message += ' (još $remainingCount posle)';
        }
        return NavigationResult.success(
          message: message,
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
    // Proveri da li je GPS uključen
    bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationEnabled) {
      // Otvori sistemski dialog za uključivanje GPS-a (jedan klik!)
      isLocationEnabled = await Geolocator.openLocationSettings();

      // Sačekaj malo da se GPS uključi
      await Future.delayed(const Duration(seconds: 2));

      // Proveri ponovo
      isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationEnabled) {
        throw Exception('GPS nije uključen');
      }
    }

    // Dozvole su već odobrene pri instalaciji, ali proveri za svaki slučaj
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('GPS dozvole nisu odobrene');
    }

    // Dobij poziciju sa visokom tačnošću
    return await Geolocator.getCurrentPosition();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 📐 HELPER FUNKCIJE
  // ═══════════════════════════════════════════════════════════════════════

  /// 📐 Izračunaj distancu između dve pozicije (Haversine formula)
  static double _calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  /// 🗺️ Otvori Google Maps sa svim putnicima
  /// Google sam optimizuje rutu - uzima u obzir puteve, saobraćaj, jednosmerne ulice
  static Future<bool> _openGoogleMapsNavigation(
    Position startPosition,
    List<Putnik> optimizedRoute,
    String startCity, {
    bool useTrafficData = false,
  }) async {
    try {
      if (optimizedRoute.isEmpty) {
        print('❌ Nema putnika za navigaciju');
        return false;
      }

      // 🎯 Google Maps podržava max 10 waypoint-a
      final maxWaypoints = 10;
      final putnici = optimizedRoute.take(maxWaypoints).toList();

      print('🗺️ Otvaram Google Maps sa ${putnici.length} putnika');

      // 🎯 Dobij koordinate za sve putnike (REFACTORED: koristi UnifiedGeocodingService)
      final coordinates = await UnifiedGeocodingService.getCoordinatesForPutnici(putnici);

      if (coordinates.isEmpty) {
        print('❌ Nema koordinata za putnike');
        return false;
      }

      // 🎯 Kreiraj Google Maps URL sa svim putnicima
      // Format: google.navigation sa waypoints - čuva NAŠ redosled!
      final destination = coordinates[putnici.last]!;

      // Waypoints su svi osim poslednjeg (koji je destinacija)
      final waypointsList = <String>[];
      for (int i = 0; i < putnici.length - 1; i++) {
        final putnik = putnici[i];
        if (coordinates.containsKey(putnik)) {
          final pos = coordinates[putnik]!;
          waypointsList.add('${pos.latitude},${pos.longitude}');
          print('   📍 WP${i + 1}: ${putnik.ime}: ${pos.latitude},${pos.longitude}');
        }
      }
      print('   🏁 DEST: ${putnici.last.ime}: ${destination.latitude},${destination.longitude}');

      // Google Maps intent format - ČUVA REDOSLED waypointa!
      String googleMapsUrl = 'google.navigation:q=${destination.latitude},${destination.longitude}';
      if (waypointsList.isNotEmpty) {
        googleMapsUrl += '&waypoints=${waypointsList.join('|')}';
      }
      googleMapsUrl += '&mode=d'; // d = driving

      print('🗺️ Google Maps URL: $googleMapsUrl');

      final Uri uri = Uri.parse(googleMapsUrl);

      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (launched && optimizedRoute.length > maxWaypoints) {
          print('⚠️ Ima još ${optimizedRoute.length - maxWaypoints} putnika posle ovih ${maxWaypoints}');
        }

        return launched;
      } else {
        throw Exception('Ne mogu da otvorim Google Maps');
      }
    } catch (e) {
      print('❌ Greška pri otvaranju Google Maps: $e');
      return false;
    }
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
    this.skippedPutnici,
  });

  factory NavigationResult.success({
    required String message,
    required List<Putnik> optimizedPutnici,
    double? totalDistance,
    List<Putnik>? skippedPutnici,
  }) {
    return NavigationResult._(
      success: true,
      message: message,
      optimizedPutnici: optimizedPutnici,
      totalDistance: totalDistance,
      skippedPutnici: skippedPutnici,
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
  final List<Putnik>? skippedPutnici; // 🆕 Putnici bez koordinata
}
