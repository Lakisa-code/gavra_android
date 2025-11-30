import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/route_config.dart';
import '../models/putnik.dart';
import 'multi_provider_navigation_service.dart';
import 'osrm_service.dart'; // 🎯 OSRM za pravu TSP optimizaciju
import 'unified_geocoding_service.dart'; // 🎯 REFACTORED: Centralizovani geocoding

/// 🎯 SMART NAVIGATION SERVICE
/// Implementira pravu GPS navigaciju sa optimizovanim redosledom putnika
/// Koristi OpenStreetMap / self-hosted OSRM/Valhalla ili platform-specific aplikacije za otvaranje rute.
///
/// 🧭 MULTI-PROVIDER SUPPORT (v2.0):
/// - Google Maps (10 waypoints) - prioritet za GMS uređaje
/// - HERE WeGo (10 waypoints) - preporučeno za Huawei
/// - Petal Maps (5 waypoints) - fallback za Huawei
/// - Automatska segmentacija rute kada prelazi limit waypoinata
class SmartNavigationService {
  /// 🏁 Vrati krajnju destinaciju na osnovu startCity
  /// Ako krećeš iz Bele Crkve, krajnja destinacija je Vršac i obrnuto
  static Position? _getEndDestination(String startCity) {
    final normalized = startCity.toLowerCase().trim();

    if (normalized.contains('bela') || normalized.contains('bc')) {
      // Kreće iz Bele Crkve -> krajnja destinacija je Vršac
      return Position(
        latitude: RouteConfig.vrsacLat,
        longitude: RouteConfig.vrsacLng,
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

    if (normalized.contains('vrsac') || normalized.contains('vršac') || normalized.contains('vs')) {
      // Kreće iz Vršca -> krajnja destinacija je Bela Crkva
      return Position(
        latitude: RouteConfig.belaCrkvaLat,
        longitude: RouteConfig.belaCrkvaLng,
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

    return null; // Nije prepoznat grad
  }

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

      // 🏁 Odredi krajnju destinaciju (suprotni grad)
      final endDestination = _getEndDestination(startCity);
      if (endDestination != null) {
        print('🏁 KRAJNJA DESTINACIJA: ${startCity.contains('Bela') ? 'Vršac' : 'Bela Crkva'}');
      }

      // 2. 🎯 KORISTI OSRM ZA PRAVU TSP OPTIMIZACIJU (sa fallback na lokalni algoritam)
      final osrmResult = await OsrmService.optimizeRoute(
        startPosition: currentPosition,
        putnici: putnici,
        endDestination: endDestination,
        onGeocodingProgress: (completed, total, address) {
          print('📍 Geocoding: $completed/$total - $address');
        },
      );

      if (!osrmResult.success || osrmResult.optimizedPutnici == null) {
        return NavigationResult.error(osrmResult.message);
      }

      final optimizedRoute = osrmResult.optimizedPutnici!;
      final coordinates = osrmResult.coordinates ?? {};

      // 🆕 Nađi preskočene putnike (nemaju koordinate)
      final skipped = putnici.where((p) => !coordinates.containsKey(p)).toList();

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

      // 3. VRATI OPTIMIZOVANU RUTU BEZ OTVARANJA MAPE
      // 🎯 Vraćamo i koordinate za kasniju upotrebu (Google Maps export)
      return NavigationResult.success(
        message: osrmResult.usedFallback ? '✅ Ruta optimizovana (lokalno)' : '✅ Ruta optimizovana (OSRM)',
        optimizedPutnici: optimizedRoute,
        totalDistance: osrmResult.totalDistanceKm != null
            ? osrmResult.totalDistanceKm! * 1000 // km -> m
            : await _calculateTotalDistance(currentPosition, optimizedRoute, coordinates),
        skippedPutnici: skipped.isNotEmpty ? skipped : null,
        cachedCoordinates: coordinates, // 🎯 NOVO: keširanje koordinata
      );
    } catch (e) {
      return NavigationResult.error('❌ Greška pri optimizaciji: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🧭 MULTI-PROVIDER NAVIGATION (v2.0)
  // ═══════════════════════════════════════════════════════════════════════

  /// 🧭 NOVA GLAVNA FUNKCIJA - Multi-provider navigacija
  /// Automatski bira Google Maps, HERE WeGo ili Petal Maps
  /// Podržava Huawei uređaje i automatsku segmentaciju rute
  ///
  /// [context] - BuildContext za dijaloge
  /// [putnici] - Lista optimizovanih putnika
  /// [cachedCoordinates] - Keširane koordinate iz optimizeRouteOnly
  /// [startCity] - Početni grad (za krajnju destinaciju)
  static Future<NavigationResult> startMultiProviderNavigation({
    required BuildContext context,
    required List<Putnik> putnici,
    required String startCity,
    Map<Putnik, Position>? cachedCoordinates,
  }) async {
    print('');
    print('🧭🧭🧭 ===== MULTI-PROVIDER NAVIGATION ===== 🧭🧭🧭');
    print('🧭 Putnici: ${putnici.length}');
    print('🧭 Start city: $startCity');
    print('');

    try {
      // 1. DOBIJ KOORDINATE
      Map<Putnik, Position> coordinates;
      if (cachedCoordinates != null && cachedCoordinates.isNotEmpty) {
        coordinates = cachedCoordinates;
      } else {
        coordinates = await UnifiedGeocodingService.getCoordinatesForPutnici(
          putnici,
          onProgress: (completed, total, address) {
            print('📍 Geocoding: $completed/$total - $address');
          },
        );
      }

      if (coordinates.isEmpty) {
        return NavigationResult.error('❌ Nijedan putnik nema validnu adresu');
      }

      // 2. ODREDI KRAJNJU DESTINACIJU
      final endDestination = _getEndDestination(startCity);

      // 3. POKRENI MULTI-PROVIDER NAVIGACIJU
      if (!context.mounted) {
        return NavigationResult.error('❌ Context nije više aktivan');
      }
      final result = await MultiProviderNavigationService.startNavigation(
        context: context,
        putnici: putnici,
        coordinates: coordinates,
        endDestination: endDestination,
      );

      // 4. KONVERTUJ REZULTAT
      if (result.success) {
        return NavigationResult.success(
          message: result.message,
          optimizedPutnici: result.launchedPutnici ?? putnici,
          cachedCoordinates: coordinates,
        );
      } else {
        return NavigationResult.error(result.message);
      }
    } catch (e) {
      print('❌ Greška pri multi-provider navigaciji: $e');
      return NavigationResult.error('❌ Greška: $e');
    }
  }

  /// 📊 Proveri status navigacionih aplikacija na uređaju
  static Future<NavigationStatus> checkNavigationStatus() async {
    return MultiProviderNavigationService.checkNavigationStatus();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🗺️ LEGACY: GOOGLE MAPS ONLY (za backward compatibility)
  // ═══════════════════════════════════════════════════════════════════════

  /// 🚗 GLAVNA FUNKCIJA - Otvori mapu sa optimizovanom rutom (preferirano OSM/OSRM)
  /// 🎯 skipOptimization=true: koristi prosleđenu listu bez re-optimizacije (za NAV dugme)
  /// 🎯 cachedCoordinates: prosleđene koordinate iz optimizeRouteOnly (izbegava duplo geocodiranje)
  ///
  /// ⚠️ DEPRECATED: Koristi startMultiProviderNavigation za podršku Huawei uređaja
  @Deprecated('Koristi startMultiProviderNavigation za podršku Huawei uređaja')
  static Future<NavigationResult> startOptimizedNavigation({
    required List<Putnik> putnici,
    required String startCity, // 'Bela Crkva' ili 'Vršac'
    bool optimizeForTime = true, // true = vreme, false = distanca
    bool useTrafficData = false, // 🚦 NOVO: traffic-aware routing
    bool skipOptimization = true, // 🎯 NOVO: preskoči re-optimizaciju ako je ruta već optimizovana
    Map<Putnik, Position>? cachedCoordinates, // 🎯 NOVO: keširane koordinate
  }) async {
    print('');
    print('🗺️🗺️🗺️ ===== START OPTIMIZED NAVIGATION ===== 🗺️🗺️🗺️');
    print('🗺️ Broj putnika: ${putnici.length}');
    print('🗺️ Start city: $startCity');
    print('🗺️ useTrafficData: $useTrafficData');
    print('🗺️ skipOptimization: $skipOptimization');
    print('🗺️ cachedCoordinates: ${cachedCoordinates != null ? "${cachedCoordinates.length} keširanih" : "nema"}');
    print('');
    try {
      // 1. DOBIJ TRENUTNU GPS POZICIJU VOZAČA
      final currentPosition = await _getCurrentPosition();

      // 2. 🎯 KORISTI KEŠIRANE KOORDINATE ILI GEOCODIRAJ
      Map<Putnik, Position> coordinates;

      if (cachedCoordinates != null && cachedCoordinates.isNotEmpty) {
        // ✅ Koristi keširane koordinate (brže, bez API poziva)
        print('✅ Koristi keširane koordinate');
        coordinates = cachedCoordinates;
      } else {
        // Geocodiraj putnike (fallback)
        coordinates = await UnifiedGeocodingService.getCoordinatesForPutnici(
          putnici,
          onProgress: (completed, total, address) {
            print('📍 Geocoding: $completed/$total - $address');
          },
        );
      }

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
        // 🏁 Odredi krajnju destinaciju (suprotni grad)
        final endDestination = _getEndDestination(startCity);

        // 🎯 KORISTI OSRM ZA OPTIMIZACIJU
        final osrmResult = await OsrmService.optimizeRoute(
          startPosition: currentPosition,
          putnici: putnici,
          endDestination: endDestination,
        );
        if (osrmResult.success && osrmResult.optimizedPutnici != null) {
          optimizedRoute = osrmResult.optimizedPutnici!;
          coordinates = osrmResult.coordinates ?? coordinates;
        } else {
          // Fallback - koristi input listu
          optimizedRoute = putnici;
        }
      }

      // 4. OTVORI RUTU U GOOGLE MAPS SA WAYPOINT-IMA (max 10)
      // 🎯 Prosleđujemo keširane koordinate da izbegnemo duplo geocodiranje
      final success = await _openGoogleMapsNavigationWithCoords(
        currentPosition,
        optimizedRoute,
        coordinates,
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
          cachedCoordinates: coordinates,
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

  /// 🗺️ Otvori Google Maps sa keširanim koordinatama
  /// 🎯 REFACTORED: Prima koordinate direktno, ne geocoduje ponovo
  static Future<bool> _openGoogleMapsNavigationWithCoords(
    Position startPosition,
    List<Putnik> optimizedRoute,
    Map<Putnik, Position> coordinates,
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

      print('🗺️ Otvaram Google Maps sa ${putnici.length} putnika (koristi keširane koordinate)');

      // 🎯 Filtriraj samo putnike koji imaju koordinate
      final putniciWithCoords = putnici.where((p) => coordinates.containsKey(p)).toList();

      if (putniciWithCoords.isEmpty) {
        print('❌ Nema koordinata za putnike');
        return false;
      }

      // 🎯 Kreiraj Google Maps URL sa svim putnicima
      // Format: google.navigation sa waypoints - čuva NAŠ redosled!
      final destination = coordinates[putniciWithCoords.last]!;

      // Waypoints su svi osim poslednjeg (koji je destinacija)
      final waypointsList = <String>[];
      for (int i = 0; i < putniciWithCoords.length - 1; i++) {
        final putnik = putniciWithCoords[i];
        final pos = coordinates[putnik]!;
        waypointsList.add('${pos.latitude},${pos.longitude}');
        print('   📍 WP${i + 1}: ${putnik.ime}: ${pos.latitude},${pos.longitude}');
      }
      print('   🏁 DEST: ${putniciWithCoords.last.ime}: ${destination.latitude},${destination.longitude}');

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
    this.cachedCoordinates,
  });

  factory NavigationResult.success({
    required String message,
    required List<Putnik> optimizedPutnici,
    double? totalDistance,
    List<Putnik>? skippedPutnici,
    Map<Putnik, Position>? cachedCoordinates, // 🎯 Keširane koordinate za Google Maps
  }) {
    return NavigationResult._(
      success: true,
      message: message,
      optimizedPutnici: optimizedPutnici,
      totalDistance: totalDistance,
      skippedPutnici: skippedPutnici,
      cachedCoordinates: cachedCoordinates,
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
  final Map<Putnik, Position>? cachedCoordinates; // 🎯 Keširane koordinate
}
