import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../config/route_config.dart';
import '../models/putnik.dart';
import 'multi_provider_navigation_service.dart';
import 'osrm_service.dart'; // 🎯 OSRM za pravu TSP optimizaciju
import 'permission_service.dart';
import 'unified_geocoding_service.dart'; // 🎯 REFACTORED: Centralizovani geocoding

/// 🎯 SMART NAVIGATION SERVICE
/// Implementira pravu GPS navigaciju sa optimizovanim redosledom putnika
/// Koristi OSRM za optimizaciju rute i HERE WeGo za navigaciju
///
/// 🧭 HERE WEGO ONLY:
/// - HERE WeGo (10 waypoints) - besplatno, radi na svim uređajima
/// - Automatska segmentacija rute kada prelazi limit waypoinata
/// - Offline mape, poštuje redosled putnika
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
    try {
      // 1. DOBIJ TRENUTNU GPS POZICIJU VOZAČA
      final currentPosition = await _getCurrentPosition();

      // 🏁 Odredi krajnju destinaciju (suprotni grad)
      final endDestination = _getEndDestination(startCity);

      // 2. 🎯 KORISTI OSRM ZA PRAVU TSP OPTIMIZACIJU (sa fallback na lokalni algoritam)
      final osrmResult = await OsrmService.optimizeRoute(
        startPosition: currentPosition,
        putnici: putnici,
        endDestination: endDestination,
      );

      // ❌ OSRM neuspešan - vrati grešku
      if (!osrmResult.success || osrmResult.optimizedPutnici == null) {
        return NavigationResult.error(osrmResult.message);
      }

      // ✅ OSRM uspešan
      final List<Putnik> optimizedRoute = osrmResult.optimizedPutnici!;
      final Map<Putnik, Position> coordinates = osrmResult.coordinates ?? {};

      // 🆕 Nađi preskočene putnike (nemaju koordinate)
      final skipped = putnici.where((p) => !coordinates.containsKey(p)).toList();

      // 3. VRATI OPTIMIZOVANU RUTU
      return NavigationResult.success(
        message: '✅ Ruta optimizovana',
        optimizedPutnici: optimizedRoute,
        totalDistance: osrmResult.totalDistanceKm != null
            ? osrmResult.totalDistanceKm! * 1000 // km -> m
            : await _calculateTotalDistance(currentPosition, optimizedRoute, coordinates),
        skippedPutnici: skipped.isNotEmpty ? skipped : null,
        cachedCoordinates: coordinates,
        putniciEta: osrmResult.putniciEta,
      );
    } catch (e) {
      return NavigationResult.error('❌ Greška pri optimizaciji: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🧭 HERE WEGO NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════

  /// 🧭 GLAVNA FUNKCIJA - HERE WeGo navigacija
  /// Koristi isključivo HERE WeGo - besplatno, radi na svim uređajima
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
    try {
      // 1. DOBIJ KOORDINATE
      Map<Putnik, Position> coordinates;
      if (cachedCoordinates != null && cachedCoordinates.isNotEmpty) {
        coordinates = cachedCoordinates;
      } else {
        coordinates = await UnifiedGeocodingService.getCoordinatesForPutnici(putnici);
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
      return NavigationResult.error('❌ Greška: $e');
    }
  }

  /// 📊 Proveri status navigacionih aplikacija na uređaju
  static Future<NavigationStatus> checkNavigationStatus() async {
    return MultiProviderNavigationService.checkNavigationStatus();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 📐 HELPER FUNKCIJE
  // ═══════════════════════════════════════════════════════════════════════

  /// 📍 Dobij trenutnu GPS poziciju vozača
  static Future<Position> _getCurrentPosition() async {
    // 🔐 CENTRALIZOVANA PROVERA GPS DOZVOLA (uključuje i GPS service check)
    final hasPermission = await PermissionService.ensureGpsForNavigation();
    if (!hasPermission) {
      throw Exception('GPS dozvole nisu odobrene ili GPS nije uključen');
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
    this.putniciEta, // 🆕 ETA za svakog putnika
  });

  factory NavigationResult.success({
    required String message,
    required List<Putnik> optimizedPutnici,
    double? totalDistance,
    List<Putnik>? skippedPutnici,
    Map<Putnik, Position>? cachedCoordinates,
    Map<String, int>? putniciEta, // 🆕 ETA za svakog putnika
  }) {
    return NavigationResult._(
      success: true,
      message: message,
      optimizedPutnici: optimizedPutnici,
      totalDistance: totalDistance,
      skippedPutnici: skippedPutnici,
      cachedCoordinates: cachedCoordinates,
      putniciEta: putniciEta,
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
  final List<Putnik>? skippedPutnici;
  final Map<Putnik, Position>? cachedCoordinates;
  final Map<String, int>? putniciEta; // 🆕 ime_putnika -> ETA u minutama
}
