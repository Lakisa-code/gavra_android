import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  static const double _minDistanceMeters = 50; // Minimalna udaljenost za update

  // State
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  bool _isTracking = false;
  String? _currentVozacId;
  String? _currentVozacIme;
  String? _currentGrad;
  String? _currentVremePolaska;
  String? _currentSmer; // BC_VS ili VS_BC
  Map<String, int>? _currentPutniciEta; // ETA za svakog putnika (iz OSRM)
  VoidCallback? _onAllPassengersPickedUp; // Callback za auto-stop

  // Getteri
  bool get isTracking => _isTracking;
  String? get currentVozacId => _currentVozacId;
  int get remainingPassengers => _currentPutniciEta?.length ?? 0;

  /// Pokreni praćenje lokacije za vozača
  /// [putniciEta] - Mapa ime_putnika -> ETA u minutama (iz OSRM)
  /// [onAllPassengersPickedUp] - Callback kada su svi putnici pokupljeni (auto-stop)
  Future<bool> startTracking({
    required String vozacId,
    required String vozacIme,
    required String grad,
    String? vremePolaska,
    String? smer, // BC_VS ili VS_BC
    Map<String, int>? putniciEta,
    @Deprecated('Ne koristi se više - ETA dolazi iz OSRM') Map<String, Position>? putniciCoordinates,
    VoidCallback? onAllPassengersPickedUp,
  }) async {
    if (_isTracking) {
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
    _onAllPassengersPickedUp = onAllPassengersPickedUp;
    _isTracking = true;

    // Odmah pošalji trenutnu lokaciju
    await _sendCurrentLocation();

    // Pokreni periodično slanje
    _locationTimer = Timer.periodic(_updateInterval, (_) => _sendCurrentLocation());

    // Alternativno: stream-based tracking sa distance filter
    // _startStreamTracking();

    return true;
  }

  /// Zaustavi praćenje lokacije
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _locationTimer?.cancel();
    _locationTimer = null;

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
    _onAllPassengersPickedUp = null;
    _lastPosition = null;
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

  /// Stream lokacije vozača (realtime za putnika)
  static Stream<Map<String, dynamic>?> streamDriverLocation({
    required String grad,
    String? vremePolaska,
    String? smer,
  }) {
    return Supabase.instance.client.from('vozac_lokacije').stream(primaryKey: ['id']).eq('grad', grad).map((list) {
          if (list.isEmpty) return null;
          // Filtriraj aktivne
          var active = list.where((l) => l['aktivan'] == true).toList();
          if (active.isEmpty) return null;

          // Filtriraj po smeru ako je zadat
          if (smer != null) {
            active = active.where((l) => l['smer'] == smer).toList();
            if (active.isEmpty) return null;
          }

          // Ako ima vreme polaska filter
          if (vremePolaska != null) {
            final filtered = active.where((l) => l['vreme_polaska'] == vremePolaska).toList();
            return filtered.isNotEmpty ? filtered.first : active.first;
          }
          return active.first;
        });
  }
}
