import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/route_config.dart';
import '../models/putnik.dart';
import 'osrm_service.dart';
import 'unified_geocoding_service.dart';

/// 🎯 SMART NAVIGATION SERVICE
/// Implementira pravu GPS navigaciju sa optimizovanim redosledom putnika
/// Koristi OSRM (OpenStreetMap Routing Machine) za pravu optimizaciju ruta
/// 
/// REFACTORED: Koristi UnifiedGeocodingService i RouteConfig
class SmartNavigationService {
  SmartNavigationService._();

  /// 🎯 SAMO OPTIMIZACIJA RUTE (bez otvaranja mape) - za "Pokreni" dugme
  static Future<NavigationResult> optimizeRouteOnly({
    required List<Putnik> putnici,
    required String startCity,
    bool optimizeForTime = true,
    GeocodingProgressCallback? onProgress,
  }) async {
    print('');
    print('🚀🚀🚀 ===== OPTIMIZE ROUTE ONLY (OSRM) ===== 🚀🚀🚀');
    print('🚀 Broj putnika: ${putnici.length}');
    print('🚀 Start city: $startCity');
    print('');
    try {
      // 1. DOBIJ TRENUTNU GPS POZICIJU VOZAČA
      final currentPosition = await _getCurrentPosition();
      print('📍 VOZAČ POZICIJA: lat=${currentPosition.latitude}, lng=${currentPosition.longitude}');

      // 2. 🗺️ KORISTI OSRM ZA OPTIMIZACIJU (sa progress callback)
      final osrmResult = await OsrmService.optimizeRoute(
        startPosition: currentPosition,
        putnici: putnici,
        onGeocodingProgress: onProgress,
      );

      if (osrmResult.success && osrmResult.optimizedPutnici != null) {
        print('✅ Optimizacija uspešna${osrmResult.usedFallback ? " (fallback)" : ""}');
        
        // Nađi preskočene putnike
        final skipped = putnici.where((p) => 
            !osrmResult.optimizedPutnici!.contains(p)).toList();

        return NavigationResult.success(
          message: osrmResult.message,
          optimizedPutnici: osrmResult.optimizedPutnici!,
          totalDistance: osrmResult.totalDistanceKm,
          skippedPutnici: skipped.isNotEmpty ? skipped : null,
        );
      }

      // 3. FALLBACK: Ako OSRM ne radi, koristi UnifiedGeocodingService
      print('⚠️ OSRM nije dostupan, koristim fallback');
      
      final coordinates = await UnifiedGeocodingService.getCoordinatesForPutnici(
        putnici,
        onProgress: onProgress,
      );
      final skipped = putnici.where((p) => !coordinates.containsKey(p)).toList();

      if (coordinates.isEmpty) {
        return NavigationResult.error(
          '❌ Nijedan putnik nema validnu adresu za navigaciju',
        );
      }

      // Fallback na Nearest Neighbor + 2-opt
      final optimizedRoute = await UnifiedGeocodingService.fallbackOptimization(
        startPosition: currentPosition,
        putnici: putnici,
        coordinates: coordinates,
        use2opt: true,
      );

      return NavigationResult.success(
        message: '✅ Ruta optimizovana (lokalno)',
        optimizedPutnici: optimizedRoute,
        totalDistance: _calculateTotalDistance(
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

  /// 🚗 GLAVNA FUNKCIJA - Otvori mapu sa optimizovanom rutom
  /// 🎯 skipOptimization=true: koristi prosleđenu listu bez re-optimizacije (za NAV dugme)
  static Future<NavigationResult> startOptimizedNavigation({
    required List<Putnik> putnici,
    required String startCity,
    bool optimizeForTime = true,
    bool useTrafficData = false,
    bool skipOptimization = true,
    GeocodingProgressCallback? onProgress,
  }) async {
    print('');
    print('🗺️🗺️🗺️ ===== START NAVIGATION (OSRM) ===== 🗺️🗺️🗺️');
    print('🗺️ Broj putnika: ${putnici.length}');
    print('🗺️ Start city: $startCity');
    print('🗺️ skipOptimization: $skipOptimization');
    print('');
    try {
      // 1. DOBIJ TRENUTNU GPS POZICIJU VOZAČA
      final currentPosition = await _getCurrentPosition();

      // 2. OPTIMIZUJ REDOSLED PUTNIKA (ili koristi već optimizovanu listu)
      List<Putnik> optimizedRoute;
      double? totalDistanceKm;

      if (skipOptimization) {
        // 🎯 KORISTI VEĆ OPTIMIZOVANU LISTU (od "Ruta" dugmeta)
        print('🎯 Koristi već optimizovanu rutu (skipOptimization=true)');
        optimizedRoute = putnici;
      } else {
        // 🗺️ KORISTI OSRM ZA OPTIMIZACIJU
        final osrmResult = await OsrmService.optimizeRoute(
          startPosition: currentPosition,
          putnici: putnici,
          onGeocodingProgress: onProgress,
        );

        if (osrmResult.success && osrmResult.optimizedPutnici != null) {
          optimizedRoute = osrmResult.optimizedPutnici!;
          totalDistanceKm = osrmResult.totalDistanceKm;
          print('✅ Optimizacija uspešna: ${totalDistanceKm?.toStringAsFixed(1)} km');
        } else {
          // Fallback: koristi UnifiedGeocodingService
          final coordinates = await UnifiedGeocodingService.getCoordinatesForPutnici(
            putnici,
            onProgress: onProgress,
          );
          if (coordinates.isEmpty) {
            return NavigationResult.error('❌ Nijedan putnik nema validnu adresu');
          }
          optimizedRoute = await UnifiedGeocodingService.fallbackOptimization(
            startPosition: currentPosition,
            putnici: putnici,
            coordinates: coordinates,
            use2opt: true,
          );
        }
      }

      // 3. OTVORI RUTU U GOOGLE MAPS SA WAYPOINT-IMA (max 10)
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
          totalDistance: totalDistanceKm,
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
    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever) {
      throw Exception('GPS dozvole nisu odobrene');
    }

    // Dobij poziciju sa visokom tačnošću
    return await Geolocator.getCurrentPosition();
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
      const maxWaypoints = RouteConfig.googleMapsMaxWaypoints;
      final putnici = optimizedRoute.take(maxWaypoints).toList();
      
      print('🗺️ Otvaram Google Maps sa ${putnici.length} putnika');

      // 🎯 Dobij koordinate za sve putnike (koristi UnifiedGeocodingService)
      final coordinates = await UnifiedGeocodingService.getCoordinatesForPutnici(putnici);
      
      if (coordinates.isEmpty) {
        print('❌ Nema koordinata za putnike');
        return false;
      }

      // 🎯 Kreiraj Google Maps URL sa svim putnicima
      // Format: /dir/origin/wp1/wp2/.../destination
      String googleMapsUrl = 'https://www.google.com/maps/dir/${startPosition.latitude},${startPosition.longitude}';

      for (final putnik in putnici) {
        if (coordinates.containsKey(putnik)) {
          final pos = coordinates[putnik]!;
          googleMapsUrl += '/${pos.latitude},${pos.longitude}';
          print('   📍 ${putnik.ime}: ${pos.latitude},${pos.longitude}');
        }
      }

      googleMapsUrl += '?travelmode=driving';

      print('🗺️ Google Maps URL: $googleMapsUrl');

      final Uri uri = Uri.parse(googleMapsUrl);

      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (launched && optimizedRoute.length > maxWaypoints) {
          print('⚠️ Ima još ${optimizedRoute.length - maxWaypoints} putnika posle ovih $maxWaypoints');
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
  static double _calculateTotalDistance(
    Position start,
    List<Putnik> route,
    Map<Putnik, Position> coordinates,
  ) {
    if (route.isEmpty) return 0.0;

    double totalDistance = 0.0;
    Position currentPos = start;

    for (final putnik in route) {
      if (coordinates.containsKey(putnik)) {
        final nextPos = coordinates[putnik]!;
        totalDistance += _calculateDistance(currentPos, nextPos);
        currentPos = nextPos;
      }
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
