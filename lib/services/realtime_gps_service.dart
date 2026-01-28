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

      // Konfiguriši GPS settings - update svakih 30 sekundi (štedi bateriju i API)
      final androidSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100, // Ili svakih 100 metara ako brže
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

  /// 📍 GET CURRENT POSITION (one-time)
  static Future<Position> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
          // desiredAccuracy: deprecated, use settings parameter
          );
    } catch (e) {
      rethrow;
    }
  }

  /// 📏 CALCULATE DISTANCE TO DESTINATION
  static double calculateDistance(Position from, double toLat, double toLng) {
    return Geolocator.distanceBetween(
          from.latitude,
          from.longitude,
          toLat,
          toLng,
        ) /
        1000; // Convert to kilometers
  }

  /// 🧭 CALCULATE BEARING TO DESTINATION
  static double calculateBearing(Position from, double toLat, double toLng) {
    return Geolocator.bearingBetween(
      from.latitude,
      from.longitude,
      toLat,
      toLng,
    );
  }

  /// 🛑 DISPOSE RESOURCES
  static void dispose() {
    stopTracking();
    _positionController.close();
    _speedController.close();
  }
}
