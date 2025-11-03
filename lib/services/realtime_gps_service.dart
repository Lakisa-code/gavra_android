import 'dart:async';
import 'package:geolocator/geolocator.dart';

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
      // Proveri dozvole
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'GPS dozvole odbačene';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'GPS dozvole trajno odbačene';
      }

      // Konfiguriši GPS settings za visoku preciznost
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update svakih 5 metara
      );

      // Pokreni tracking
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        _positionController.add(position);

        // Kalkuliši brzinu (km/h)
        final speedMps = position.speed; // meters per second
        final speedKmh = speedMps * 3.6; // convert to km/h
        _speedController.add(speedKmh);
      });
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
        desiredAccuracy: LocationAccuracy.high,
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
