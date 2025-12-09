import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'permission_service.dart';

/// 🛰️ GPS MANAGER - CENTRALIZOVANI GPS SINGLETON
///
/// Zamenjuje fragmentirane GPS servise:
/// - RealtimeGpsService (stream pozicija)
/// - LocationService.getCurrentPosition()
/// - GpsService GPS deo
/// - SmartNavigationService._getCurrentPosition()
/// - BackgroundGpsService GPS deo
///
/// Korišćenje:
/// ```dart
/// // Dobij singleton instancu
/// final gps = GpsManager.instance;
///
/// // Stream pozicija
/// gps.positionStream.listen((position) => ...);
///
/// // Stream brzine
/// gps.speedStream.listen((speedKmh) => ...);
///
/// // Jedna pozicija
/// final pos = await gps.getCurrentPosition();
/// ```
class GpsManager {
  // ═══════════════════════════════════════════════════════════════════════
  // 🔒 SINGLETON PATTERN
  // ═══════════════════════════════════════════════════════════════════════

  static final GpsManager _instance = GpsManager._internal();
  static GpsManager get instance => _instance;

  factory GpsManager() => _instance;

  GpsManager._internal();

  // ═══════════════════════════════════════════════════════════════════════
  // 📡 STREAM CONTROLLERS
  // ═══════════════════════════════════════════════════════════════════════

  final _positionController = StreamController<Position>.broadcast();
  final _speedController = StreamController<double>.broadcast();
  final _trackingStateController = StreamController<bool>.broadcast();

  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;
  Position? _lastPosition;

  // ═══════════════════════════════════════════════════════════════════════
  // 📍 PUBLIC STREAMS
  // ═══════════════════════════════════════════════════════════════════════

  /// Stream GPS pozicija (real-time updates)
  Stream<Position> get positionStream => _positionController.stream;

  /// Stream brzine u km/h
  Stream<double> get speedStream => _speedController.stream;

  /// Stream tracking state (true/false)
  Stream<bool> get trackingStateStream => _trackingStateController.stream;

  /// Da li je GPS tracking aktivan
  bool get isTracking => _isTracking;

  /// Poslednja poznata pozicija (null ako nikad nije dobijena)
  Position? get lastPosition => _lastPosition;

  // ═══════════════════════════════════════════════════════════════════════
  // 🔐 PERMISSION HANDLING - CENTRALIZOVANO KROZ PermissionService
  // ═══════════════════════════════════════════════════════════════════════

  /// Proveri i zatraži sve potrebne dozvole
  /// Vraća true ako su sve dozvole odobrene
  Future<bool> ensurePermissions() async {
    return await PermissionService.ensureGpsForNavigation();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🛰️ GPS TRACKING
  // ═══════════════════════════════════════════════════════════════════════

  /// Pokreni GPS tracking
  /// [distanceFilter] - minimalna promena u metrima za novi update (default 5m)
  /// [accuracy] - preciznost GPS-a (default high)
  Future<bool> startTracking({
    int distanceFilter = 5,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    if (_isTracking) {
      return true;
    }

    try {
      // Proveri dozvole
      final hasPermission = await ensurePermissions();
      if (!hasPermission) {
        return false;
      }

      // Konfiguriši GPS settings
      final locationSettings = LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );

      // Pokreni tracking
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _lastPosition = position;
          _positionController.add(position);

          // Kalkuliši brzinu (km/h)
          final speedKmh = position.speed * 3.6;
          _speedController.add(speedKmh);
        },
        onError: (error) {},
      );

      _isTracking = true;
      _trackingStateController.add(true);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Zaustavi GPS tracking
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    _trackingStateController.add(false);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 📍 SINGLE POSITION
  // ═══════════════════════════════════════════════════════════════════════

  /// Dobij trenutnu poziciju (jednokratno)
  /// [timeout] - maksimalno vreme čekanja (default 15s)
  /// [accuracy] - preciznost (default high)
  Future<Position?> getCurrentPosition({
    Duration timeout = const Duration(seconds: 15),
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    try {
      // Proveri dozvole
      final hasPermission = await ensurePermissions();
      if (!hasPermission) {
        return _lastPosition; // Vrati poslednju ako postoji
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy),
      ).timeout(timeout);

      _lastPosition = position;
      return position;
    } catch (e) {
      return _lastPosition; // Vrati poslednju ako postoji
    }
  }

  /// Dobij poslednju poznatu poziciju (bez čekanja na GPS)
  Future<Position?> getLastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        _lastPosition = position;
      }
      return position ?? _lastPosition;
    } catch (e) {
      return _lastPosition;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 📐 DISTANCE & BEARING CALCULATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Izračunaj distancu između dve tačke u metrima
  double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Izračunaj distancu od trenutne pozicije do destinacije u km
  double? distanceToDestination(double destLat, double destLng) {
    if (_lastPosition == null) return null;
    return distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          destLat,
          destLng,
        ) /
        1000; // Convert to km
  }

  /// Izračunaj bearing (smer) prema destinaciji
  double bearingTo(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.bearingBetween(startLat, startLng, endLat, endLng);
  }

  /// Izračunaj bearing od trenutne pozicije do destinacije
  double? bearingToDestination(double destLat, double destLng) {
    if (_lastPosition == null) return null;
    return bearingTo(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      destLat,
      destLng,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🧹 CLEANUP
  // ═══════════════════════════════════════════════════════════════════════

  /// Oslobodi resurse (pozovi pri zatvaranju app-a)
  void dispose() {
    stopTracking();
    _positionController.close();
    _speedController.close();
    _trackingStateController.close();
  }
}
