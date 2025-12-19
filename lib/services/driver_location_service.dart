import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
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

  // Konfiguracija
  static const Duration _updateInterval = Duration(seconds: 15);
  static const Duration _etaUpdateInterval = Duration(minutes: 1); // Realtime ETA osvežavanje
  static const double _minDistanceMeters = 50; // Minimalna udaljenost za update

  // State
  Timer? _locationTimer;
  Timer? _etaTimer; // 🆕 Timer za realtime ETA
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  bool _isTracking = false;
  String? _currentVozacId;
  String? _currentVozacIme;
  String? _currentGrad;
  String? _currentVremePolaska;
  String? _currentSmer; // BC_VS ili VS_BC
  Map<String, int>? _currentPutniciEta; // ETA za svakog putnika (iz OSRM)
  Map<String, Position>? _putniciCoordinates; // 🆕 Koordinate putnika za realtime ETA
  List<String>? _putniciRedosled; // 🆕 Redosled putnika (optimizovan)
  VoidCallback? _onAllPassengersPickedUp; // Callback za auto-stop

  // Getteri
  bool get isTracking => _isTracking;
  String? get currentVozacId => _currentVozacId;
  int get remainingPassengers => _currentPutniciEta?.length ?? 0;

  /// Pokreni praćenje lokacije za vozača
  /// [putniciEta] - Mapa ime_putnika -> ETA u minutama (iz OSRM)
  /// [putniciCoordinates] - Koordinate putnika za realtime ETA osvežavanje
  /// [putniciRedosled] - Optimizovan redosled putnika
  /// [onAllPassengersPickedUp] - Callback kada su svi putnici pokupljeni (auto-stop)
  Future<bool> startTracking({
    required String vozacId,
    required String vozacIme,
    required String grad,
    String? vremePolaska,
    String? smer, // BC_VS ili VS_BC
    Map<String, int>? putniciEta,
    Map<String, Position>? putniciCoordinates, // 🆕 Za realtime ETA
    List<String>? putniciRedosled, // 🆕 Optimizovan redosled
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

    // Proveri dozvole za lokaciju
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

    // Odmah pošalji trenutnu lokaciju
    await _sendCurrentLocation();

    // Pokreni periodično slanje lokacije
    _locationTimer = Timer.periodic(_updateInterval, (_) => _sendCurrentLocation());

    // 🆕 Pokreni periodično osvežavanje ETA (svakih 2 min)
    if (_putniciCoordinates != null && _putniciRedosled != null) {
      _etaTimer = Timer.periodic(_etaUpdateInterval, (_) => _refreshRealtimeEta());
    }

    // Alternativno: stream-based tracking sa distance filter
    // _startStreamTracking();

    return true;
  }

  /// Zaustavi praćenje lokacije
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _locationTimer?.cancel();
    _locationTimer = null;

    _etaTimer?.cancel(); // 🆕 Zaustavi ETA timer
    _etaTimer = null;

    await _positionSubscription?.cancel();
    _positionSubscription = null;

    // Označi vozača kao neaktivnog u bazi
    await _setInactive();

    _isTracking = false;
    _currentVozacId = null;
    _currentVozacIme = null;
    _currentGrad = null;
    _currentVremePolaska = null;
    _currentSmer = null;
    _currentPutniciEta = null;
    _putniciCoordinates = null; // 🆕
    _putniciRedosled = null; // 🆕
    _onAllPassengersPickedUp = null;
    _lastPosition = null;
  }

  /// 🔄 REALTIME FIX: Ažuriraj ETA za putnike bez ponovnog pokretanja trackinga
  /// Poziva se nakon reoptimizacije rute kada se doda/otkaže putnik
  Future<void> updatePutniciEta(Map<String, int> newPutniciEta) async {
    if (!_isTracking) return;

    _currentPutniciEta = Map.from(newPutniciEta);
    // Odmah pošalji ažurirani ETA u Supabase
    await _sendCurrentLocation();
  }

  /// 🆕 REALTIME ETA: Osvežava ETA pozivom OpenRouteService API
  /// Poziva se svakih 2 minuta tokom vožnje
  Future<void> _refreshRealtimeEta() async {
    if (!_isTracking || _lastPosition == null) return;
    if (_putniciCoordinates == null || _putniciRedosled == null) return;

    // Filtriraj samo aktivne putnike (ETA >= 0)
    final aktivniPutnici = _putniciRedosled!
        .where((ime) =>
            _currentPutniciEta != null && _currentPutniciEta!.containsKey(ime) && _currentPutniciEta![ime]! >= 0)
        .toList();

    if (aktivniPutnici.isEmpty) return;

    // Pozovi OpenRouteService Directions API
    final result = await OpenRouteService.getRealtimeEta(
      currentPosition: _lastPosition!,
      putnikImena: aktivniPutnici,
      putnikCoordinates: _putniciCoordinates!,
    );

    if (result.success && result.putniciEta != null) {
      // Ažuriraj ETA za aktivne putnike
      for (final entry in result.putniciEta!.entries) {
        _currentPutniciEta![entry.key] = entry.value;
      }
      // Pošalji ažurirani ETA u bazu
      await _sendCurrentLocation();
    }
  }

  /// 🆕 Označi putnika kao pokupljenог (ETA = -1)
  /// Automatski zaustavlja tracking ako su svi pokupljeni
  void removePassenger(String putnikIme) {
    if (_currentPutniciEta == null) return;

    // Umesto brisanja, postavi ETA na -1 što znači "pokupljen"
    // Tako widget može da prikaže "Pokupljen" umesto "Čekanje..."
    _currentPutniciEta![putnikIme] = -1;

    // AUTO-STOP: Ako su svi putnici pokupljeni (svi imaju ETA = -1)
    final aktivniPutnici = _currentPutniciEta!.values.where((v) => v >= 0).length;
    if (aktivniPutnici == 0) {
      _onAllPassengersPickedUp?.call();
      stopTracking();
    }
  }

  /// Proveri i zatraži dozvole za lokaciju - CENTRALIZOVANO
  Future<bool> _checkLocationPermission() async {
    return await PermissionService.ensureGpsForNavigation();
  }

  /// Pošalji trenutnu lokaciju u Supabase
  Future<void> _sendCurrentLocation() async {
    if (!_isTracking || _currentVozacId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Proveri da li se dovoljno pomerio
      if (_lastPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        if (distance < _minDistanceMeters) {
          return;
        }
      }

      _lastPosition = position;

      // ETA se koristi iz OSRM (tačan, po rutama) - NE računamo vazdušnu liniju!

      // 🔄 Delete + Insert umesto upsert (nema unique constraint na vozac_id)
      // Prvo obriši stare zapise za ovog vozača
      await Supabase.instance.client.from('vozac_lokacije').delete().eq('vozac_id', _currentVozacId!);

      // Zatim umetni novi zapis
      await Supabase.instance.client.from('vozac_lokacije').insert({
        'vozac_id': _currentVozacId,
        'vozac_ime': _currentVozacIme,
        'lat': position.latitude,
        'lng': position.longitude,
        'grad': _currentGrad,
        'vreme_polaska': _currentVremePolaska,
        'smer': _currentSmer,
        'aktivan': true,
        'putnici_eta': _currentPutniciEta, // Dinamički ažuriran ETA
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      // Error sending location
    }
  }

  /// Označi vozača kao neaktivnog
  Future<void> _setInactive() async {
    if (_currentVozacId == null) return;

    try {
      await Supabase.instance.client.from('vozac_lokacije').update({'aktivan': false}).eq('vozac_id', _currentVozacId!);
    } catch (e) {
      // Error setting inactive
    }
  }

  /// Stream praćenje sa distance filterom (alternativa timer-u)
  // ignore: unused_element
  void _startStreamTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50, // Update na svakih 50m
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
        'putnici_eta': _currentPutniciEta, // 🆕 ETA za svakog putnika
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
      var query = Supabase.instance.client.from('vozac_lokacije').select().eq('aktivan', true).eq('grad', grad);

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
