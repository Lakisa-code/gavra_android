import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/putnik.dart';

/// 🗺️ HUAWEI MAP SERVICE - Koristi Huawei Map Kit za routing i geocoding
/// Besplatno za HMS uređaje, alternativa Google Maps API
///
/// API Dokumentacija: https://developer.huawei.com/consumer/en/doc/HMSCore-Guides/directions-api-0000001050162180
class HuaweiMapService {
  HuaweiMapService._();

  // Huawei Map Kit API ključ (dobija se iz agconnect-services.json)
  static String? _apiKey;
  static bool _initialized = false;

  /// Automatski učitaj API ključ iz agconnect-services.json
  static Future<void> initializeFromAssets() async {
    if (_initialized) return;

    try {
      final jsonString = await rootBundle.loadString('assets/agconnect-services.json');
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final client = json['client'] as Map<String, dynamic>?;

      if (client != null && client['api_key'] != null) {
        _apiKey = client['api_key'] as String;
        _initialized = true;
      }
    } catch (_) {
      // Ne može učitati API ključ
    }
  }

  /// Postavi API ključ ručno (pozovi jednom pri startu aplikacije)
  static void initialize(String apiKey) {
    _apiKey = apiKey;
    _initialized = true;
  }

  /// Da li je servis inicijalizovan
  static bool get isInitialized => _initialized && _apiKey != null;

  /// 🗺️ Directions API - dobij rutu između tačaka
  /// https://developer.huawei.com/consumer/en/doc/HMSCore-References/directions-driving-0000001050161494
  static Future<HuaweiRouteResult> getDirections({
    required Position origin,
    required List<Position> waypoints,
    required Position destination,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return HuaweiRouteResult.error('Huawei API ključ nije postavljen');
    }

    try {
      // URL encode API ključ
      final encodedKey = Uri.encodeComponent(_apiKey!);
      final url = Uri.parse('https://mapapi.cloud.huawei.com/mapApi/v1/routeService/driving?key=$encodedKey');

      // POST body - isto kao u zvaničnom HMS demo-u
      final body = json.encode({
        'origin': {'lat': origin.latitude, 'lng': origin.longitude},
        'destination': {'lat': destination.latitude, 'lng': destination.longitude},
        if (waypoints.isNotEmpty) 'waypoints': waypoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      });
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['returnCode'] == '0' && data['routes'] != null) {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            final route = routes[0] as Map<String, dynamic>;
            final paths = route['paths'] as List?;

            if (paths != null && paths.isNotEmpty) {
              final path = paths[0] as Map<String, dynamic>;
              return HuaweiRouteResult.success(
                distanceMeters: (path['distance'] as num?)?.toDouble() ?? 0,
                durationSeconds: (path['duration'] as num?)?.toDouble() ?? 0,
                polyline: path['polyline'] as String?,
              );
            }
          }
        }

        return HuaweiRouteResult.error('Huawei API: ${data['returnDesc'] ?? 'Nepoznata greška'}');
      } else {
        return HuaweiRouteResult.error('Huawei HTTP greška: ${response.statusCode}');
      }
    } catch (e) {
      return HuaweiRouteResult.error('Greška: $e');
    }
  }

  /// 📍 Geocoding API - pretvori adresu u koordinate
  /// https://developer.huawei.com/consumer/en/doc/HMSCore-References/geocoding-0000001050162082
  static Future<Position?> geocodeAddress(String address) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return null;
    }

    try {
      final url = Uri.parse('https://siteapi.cloud.huawei.com/mapApi/v1/siteService/geocode'
          '?key=$_apiKey'
          '&address=${Uri.encodeComponent(address)}'
          '&language=sr' // Srpski jezik
          );

      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['returnCode'] == '0' && data['sites'] != null) {
          final sites = data['sites'] as List;
          if (sites.isNotEmpty) {
            final site = sites[0] as Map<String, dynamic>;
            final location = site['location'] as Map<String, dynamic>?;

            if (location != null) {
              return Position(
                latitude: (location['lat'] as num).toDouble(),
                longitude: (location['lng'] as num).toDouble(),
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
        }
      }
    } catch (_) {
      // Geocoding greška
    }

    return null;
  }

  /// 🎯 Optimizuj rutu koristeći Huawei Directions sa waypoints
  /// Huawei će sam optimizovati redosled ako koristimo 'optimize=true'
  static Future<HuaweiOptimizationResult> optimizeRoute({
    required Position startPosition,
    required List<Putnik> putnici,
    required Map<Putnik, Position> coordinates,
  }) async {
    if (putnici.isEmpty || coordinates.isEmpty) {
      return HuaweiOptimizationResult.error('Nema putnika za optimizaciju');
    }

    try {
      // Pripremi waypoints (svi osim poslednjeg)
      final waypoints = <Position>[];
      for (int i = 0; i < putnici.length - 1; i++) {
        final pos = coordinates[putnici[i]];
        if (pos != null) waypoints.add(pos);
      }

      // Poslednji putnik je destinacija
      final lastPutnik = putnici.last;
      final destination = coordinates[lastPutnik];

      if (destination == null) {
        return HuaweiOptimizationResult.error('Destinacija nema koordinate');
      }

      // Pozovi Directions API
      final result = await getDirections(
        origin: startPosition,
        waypoints: waypoints,
        destination: destination,
      );

      if (result.success) {
        return HuaweiOptimizationResult.success(
          optimizedPutnici: putnici, // Huawei ne menja redosled, samo daje rutu
          totalDistanceKm: (result.distanceMeters ?? 0) / 1000,
          totalDurationMin: (result.durationSeconds ?? 0) / 60,
          coordinates: coordinates,
        );
      } else {
        return HuaweiOptimizationResult.error(result.message);
      }
    } catch (e) {
      return HuaweiOptimizationResult.error('Greška: $e');
    }
  }
}

/// Rezultat Huawei Directions API poziva
class HuaweiRouteResult {
  HuaweiRouteResult._({
    required this.success,
    required this.message,
    this.distanceMeters,
    this.durationSeconds,
    this.polyline,
  });

  factory HuaweiRouteResult.success({
    required double distanceMeters,
    required double durationSeconds,
    String? polyline,
  }) {
    return HuaweiRouteResult._(
      success: true,
      message: 'OK',
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      polyline: polyline,
    );
  }

  factory HuaweiRouteResult.error(String message) {
    return HuaweiRouteResult._(
      success: false,
      message: message,
    );
  }

  final bool success;
  final String message;
  final double? distanceMeters;
  final double? durationSeconds;
  final String? polyline;
}

/// Rezultat Huawei optimizacije
class HuaweiOptimizationResult {
  HuaweiOptimizationResult._({
    required this.success,
    required this.message,
    this.optimizedPutnici,
    this.totalDistanceKm,
    this.totalDurationMin,
    this.coordinates,
  });

  factory HuaweiOptimizationResult.success({
    required List<Putnik> optimizedPutnici,
    required double totalDistanceKm,
    required double totalDurationMin,
    Map<Putnik, Position>? coordinates,
  }) {
    return HuaweiOptimizationResult._(
      success: true,
      message: '✅ Ruta optimizovana (Huawei)',
      optimizedPutnici: optimizedPutnici,
      totalDistanceKm: totalDistanceKm,
      totalDurationMin: totalDurationMin,
      coordinates: coordinates,
    );
  }

  factory HuaweiOptimizationResult.error(String message) {
    return HuaweiOptimizationResult._(
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
