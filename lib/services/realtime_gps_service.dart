import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'permission_service.dart';

/// 🛰️ REAL-TIME GPS POSITION SERVICE
class RealtimeGpsService {
  static final _positionController = StreamController<Position>.broadcast();
  static final _speedController = StreamController<double>.broadcast();
  static StreamSubscription<Position>? _positionSubscription;

  /// 📍 STREAM GPS POZICIJE
  static Stream<Position> get positionStream => _positionController.stream;

  /// 🏃 STREAM BRZINE
  static Stream<double> get speedStream => _speedController.stream;

  /// 🛰️ START GPS TRACKING
  static Future<void> startTracking() async {
    try {
      // 🔐 CENTRALIZOVANA PROVERA GPS DOZVOLA
      final hasPermission = await PermissionService.ensureGpsForNavigation();
      if (!hasPermission) {
        throw 'GPS dozvole nisu odobrene';
      }

      // Konfiguriši GPS settings — update TAČNO svakih 30 sekundi.
      // distanceFilter: 0 → ne šalje po metražu, samo po timeru.
      // Bez ovog, vozač koji brzo vozi bi trigerovao update i pre timera
      // što bi zajedno sa _locationTimer-om pravilo duple DB upise.
      final androidSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // Samo timer, bez metražnog triggera
        intervalDuration: const Duration(seconds: 30), // Update svakih 30 sekundi
      );

      // Pokreni tracking
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: androidSettings,
      ).listen(
        (Position position) {
          _positionController.add(position);

          // Kalkuliši brzinu (km/h)
          final speedMps = position.speed; // meters per second
          final speedKmh = speedMps * 3.6; // convert to km/h
          _speedController.add(speedKmh);
        },
        onError: (error) {
          debugPrint('🔴 [RealtimeGpsService] Position stream error: $error');
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  /// 🛑 STOP GPS TRACKING
  static Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// 🛑 DISPOSE RESOURCES
  static void dispose() {
    stopTracking();
    _positionController.close();
    _speedController.close();
  }
}
