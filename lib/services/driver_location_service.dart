import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'openrouteservice.dart';
import 'permission_service.dart';

/// Servis za slanje GPS lokacije vozača u realtime
/// Putnici mogu pratiti lokaciju kombija dok čekaju
class DriverLocationService {
  static final DriverLocationService _instance = DriverLocationService._internal();
  factory DriverLocationService() => _instance;
  DriverLocationService._internal();

  static DriverLocationService get instance => _instance;

  static const Duration _updateInterval = Duration(seconds: 30);
  static const Duration _etaUpdateInterval = Duration(minutes: 1);

  // State
  Timer? _locationTimer;
  Timer? _etaTimer;
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  bool _isTracking = false;
  String? _currentVozacId;
  String? _currentVozacIme;
  String? _currentGrad;
  String? _currentVremePolaska;
  String? _currentSmer;
  Map<String, int>? _currentPutniciEta;
  Map<String, Position>? _putniciCoordinates;
  List<String>? _putniciRedosled; // 🆕 Redosled putnika (optimizovan)
  VoidCallback? _onAllPassengersPickedUp; // Callback za auto-stop

  // 🚗 GPS Statistics (for ML Lab)
  double _todayDistance = 0.0; // in meters
  double _maxSpeed = 0.0; // in m/s
  DateTime? _trackingStartTime;
  final List<LatLng> _todayPositions = [];

  // Getteri
  bool get isTracking => _isTracking;
  String? get currentVozacId => _currentVozacId;
  double get todayDistanceKm => _todayDistance / 1000;
  double get maxSpeedKmh => _maxSpeed * 3.6;
  Duration get trackingDuration => _trackingStartTime != null ? DateTime.now().difference(_trackingStartTime!) : Duration.zero;
  double get averageSpeedKmh => trackingDuration.inSeconds > 0 ? (todayDistanceKm / trackingDuration.inHours) : 0.0;
  List<LatLng> get todayPositions => List.unmodifiable(_todayPositions);

  /// Broj preostalih putnika za pokupiti (ETA >= 0)
  int get remainingPassengers => _currentPutniciEta?.values.where((v) => v >= 0).length ?? 0;

  /// Pokreni praćenje lokacije za vozača
  Future<bool> startTracking({
    required String vozacId,
    required String vozacIme,
    required String grad,
    String? vremePolaska,
    String? smer,
    Map<String, int>? putniciEta,
    Map<String, Position>? putniciCoordinates,
    List<String>? putniciRedosled,
    VoidCallback? onAllPassengersPickedUp,
  }) async {
    // 🔄 REALTIME FIX: Ako je tracking već aktivan, samo ažuriraj ETA
    if (_isTracking) {
      if (putniciEta != null) {
        _currentPutniciEta = Map.from(putniciEta);
        // Odmah pošalji ažurirani ETA u Supabase
        await _sendCurrentLocation();
      }
      return true;
    }

    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      return false;
    }

    _currentVozacId = vozacId;
    _currentVozacIme = vozacIme;
    _currentGrad = grad;
    _currentVremePolaska = vremePolaska;
    _currentSmer = smer;
    _currentPutniciEta = putniciEta != null ? Map.from(putniciEta) : null;
    _putniciCoordinates = putniciCoordinates != null ? Map.from(putniciCoordinates) : null;
    _putniciRedosled = putniciRedosled != null ? List.from(putniciRedosled) : null;
    _onAllPassengersPickedUp = onAllPassengersPickedUp;
    _isTracking = true;

    // 🚗 Reset daily statistics
    _trackingStartTime = DateTime.now();
    _todayDistance = 0.0;
    _maxSpeed = 0.0;
    _todayPositions.clear();

    await _sendCurrentLocation();

    _locationTimer = Timer.periodic(_updateInterval, (_) => _sendCurrentLocation());

    if (_putniciCoordinates != null && _putniciRedosled != null) {
      _etaTimer = Timer.periodic(_etaUpdateInterval, (_) => _refreshRealtimeEta());
    }

    return true;
  }

  /// Zaustavi praćenje lokacije
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    // 🆕 Sačuvaj vozacId pre cleanup-a
    final vozacIdToDeactivate = _currentVozacId;

    _locationTimer?.cancel();
    _locationTimer = null;

    _etaTimer?.cancel();
    _etaTimer = null;

    await _positionSubscription?.cancel();
    _positionSubscription = null;

    // 🆕 Deaktiviraj vozača u Supabase - putnici više neće videti stari ETA
    if (vozacIdToDeactivate != null) {
      try {
        debugPrint('🛑 Deaktiviram vozača: $vozacIdToDeactivate');
        await Supabase.instance.client.from('vozac_lokacije').update({
          'aktivan': false,
          'putnici_eta': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('vozac_id', vozacIdToDeactivate);
        debugPrint('✅ Vozač deaktiviran uspešno');
      } catch (e) {
        debugPrint('❌ Greška pri deaktivaciji vozača: $e');
      }
    }

    _isTracking = false;
    _currentVozacId = null;
    _currentVozacIme = null;
    _currentGrad = null;
    _currentVremePolaska = null;
    _currentSmer = null;
    _currentPutniciEta = null;
    _putniciCoordinates = null;
    _putniciRedosled = null;
    _onAllPassengersPickedUp = null;
    _lastPosition = null;
  }

  /// 🔄 REALTIME FIX: Ažuriraj ETA za putnike bez ponovnog pokretanja trackinga
  /// Poziva se nakon reoptimizacije rute kada se doda/otkaže putnik
  Future<void> updatePutniciEta(Map<String, int> newPutniciEta) async {
    if (!_isTracking) return;

    _currentPutniciEta = Map.from(newPutniciEta);
    await _sendCurrentLocation();

    // 🆕 Check if all finished
    final activeCount = _currentPutniciEta!.values.where((v) => v >= 0).length;
    if (activeCount == 0 && _isTracking) {
      debugPrint('✅ Svi putnici završeni (ETA update) - zaustavljam tracking');
      _onAllPassengersPickedUp?.call();
      stopTracking();
    }
  }

  /// 🆕 REALTIME ETA: Osvežava ETA pozivom OpenRouteService API
  /// Poziva se svakih 2 minuta tokom vožnje
  Future<void> _refreshRealtimeEta() async {
    if (!_isTracking || _lastPosition == null) return;
    if (_putniciCoordinates == null || _putniciRedosled == null) return;

    final aktivniPutnici = _putniciRedosled!
        .where((ime) =>
            _currentPutniciEta != null && _currentPutniciEta!.containsKey(ime) && _currentPutniciEta![ime]! >= 0)
        .toList();

    if (aktivniPutnici.isEmpty) return;

    final result = await OpenRouteService.getRealtimeEta(
      currentPosition: _lastPosition!,
      putnikImena: aktivniPutnici,
      putnikCoordinates: _putniciCoordinates!,
    );

    if (result.success && result.putniciEta != null) {
      for (final entry in result.putniciEta!.entries) {
        _currentPutniciEta![entry.key] = entry.value;
      }
      await _sendCurrentLocation();
    }
  }

  /// 🆕 Označi putnika kao pokupljenог (ETA = -1)
  /// Automatski zaustavlja tracking ako su svi pokupljeni
  Future<void> removePassenger(String putnikIme) async {
    if (_currentPutniciEta == null) return;

    _currentPutniciEta![putnikIme] = -1;

    // 🔄 Odmah pošalji ažurirani status u Supabase
    await _sendCurrentLocation();

    final aktivniPutnici = _currentPutniciEta!.values.where((v) => v >= 0).length;
    if (aktivniPutnici == 0) {
      _onAllPassengersPickedUp?.call();
      stopTracking();
    }
  }

  /// Proveri i zatraži dozvole za lokaciju - CENTRALIZOVANO
  /// Forsiraj slanje trenutne lokacije (npr. kada se pokupi putnik)
  Future<void> forceLocationUpdate({Position? knownPosition}) async {
    await _sendCurrentLocation(knownPosition: knownPosition);
  }

  Future<bool> _checkLocationPermission() async {
    return await PermissionService.ensureGpsForNavigation();
  }

  /// Pošalji trenutnu lokaciju u Supabase
  Future<void> _sendCurrentLocation({Position? knownPosition}) async {
    if (!_isTracking || _currentVozacId == null) return;

    try {
      final position = knownPosition ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );

      if (_lastPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        // Log distance za debugging ako treba
        debugPrint('🚐 GPS: pomeraj ${distance.toStringAsFixed(0)}m');
        
        // 🚗 Update daily statistics
        _todayDistance += distance;
      }

      _lastPosition = position;
      
      // 🚗 Track max speed
      if (position.speed > _maxSpeed) {
        _maxSpeed = position.speed;
      }
      
      // 🚗 Add position to history
      _todayPositions.add(LatLng(position.latitude, position.longitude));

      await Supabase.instance.client.from('vozac_lokacije').upsert({
        'vozac_id': _currentVozacId,
        'vozac_ime': _currentVozacIme,
        'lat': position.latitude,
        'lng': position.longitude,
        'grad': _currentGrad,
        'vreme_polaska': _currentVremePolaska,
        'smer': _currentSmer,
        'aktivan': true,
        'putnici_eta': _currentPutniciEta,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'vozac_id');
    } catch (e) {
      // Error sending location
    }
  }

  /// Stream praćenje sa distance filterom (alternativa timer-u)
  // ignore: unused_element
  void _startStreamTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50,
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _lastPosition = position;
        _sendPositionToSupabase(position);
      },
      onError: (e) {
        // GPS Stream error
      },
    );
  }

  Future<void> _sendPositionToSupabase(Position position) async {
    if (!_isTracking || _currentVozacId == null) return;

    try {
      await Supabase.instance.client.from('vozac_lokacije').upsert({
        'vozac_id': _currentVozacId,
        'vozac_ime': _currentVozacIme,
        'lat': position.latitude,
        'lng': position.longitude,
        'grad': _currentGrad,
        'vreme_polaska': _currentVremePolaska,
        'smer': _currentSmer,
        'aktivan': true,
        'putnici_eta': _currentPutniciEta,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'vozac_id');
    } catch (e) {
      // Error upserting location
    }
  }

  /// Dohvati aktivnu lokaciju vozača (za putnika)
  static Future<Map<String, dynamic>?> getActiveDriverLocation({
    required String grad,
    String? vremePolaska,
    String? smer,
  }) async {
    try {
      var query = Supabase.instance.client
          .from('vozac_lokacije')
          .select()
          .eq('aktivan', true) // ✅ Filtrira samo aktivne vozače
          .eq('grad', grad);

      if (vremePolaska != null) {
        query = query.eq('vreme_polaska', vremePolaska);
      }

      if (smer != null) {
        query = query.eq('smer', smer);
      }

      final response = await query.maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }
}
