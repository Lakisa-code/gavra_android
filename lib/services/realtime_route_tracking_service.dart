import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/putnik.dart';
import '../models/realtime_route_data.dart';
import 'gps_service.dart';
import 'local_notification_service.dart';

/// 🚗 REALTIME ROUTE TRACKING SERVICE
/// Kontinuirano praćenje vozača tokom vožnje sa dinamičkim rerautovanjem
class RealtimeRouteTrackingService {
  static final Logger _logger = Logger();

  // Google APIs
  static const String _googleApiKey = 'AIzaSyBOhQKU9YoA1z_h_N_y_XhbOL5gHWZXqPY';
  static const String _directionsApiUrl =
      'https://maps.googleapis.com/maps/api/directions/json';
  static const String _trafficApiUrl =
      'https://maps.googleapis.com/maps/api/distancematrix/json';

  // Stream kontroleri za realtime podatke
  static final StreamController<RealtimeRouteData> _routeDataController =
      StreamController<RealtimeRouteData>.broadcast();
  static final StreamController<List<String>> _trafficAlertsController =
      StreamController<List<String>>.broadcast();

  // Tracking stanje
  static bool _isTrackingActive = false;
  static Timer? _trackingTimer;
  static Timer? _trafficTimer;
  static String? _currentDriverId;
  static List<Putnik> _currentRoute = [];
  static Position? _lastKnownPosition;
  static String? _currentOptimalRoute;

  // Getteri za stream-ove
  static Stream<RealtimeRouteData> get routeDataStream =>
      _routeDataController.stream;
  static Stream<List<String>> get trafficAlertsStream =>
      _trafficAlertsController.stream;

  /// 🚀 Pokreni kontinuirano praćenje rute
  static Future<void> startRouteTracking({
    required String driverId,
    required List<Putnik> route,
  }) async {
    _logger.i('🎯 Pokretam realtime route tracking za vozača: $driverId');

    _currentDriverId = driverId;
    _currentRoute = route;
    _isTrackingActive = true;

    // Dobij početnu poziciju
    try {
      _lastKnownPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      _logger.e('❌ Greška dobijanja početne pozicije: $e');
      return;
    }

    // Izračunaj početnu optimalnu rutu
    await _calculateOptimalRoute();

    // Pokreni kontinuirano praćenje pozicije (svakih 30 sekundi)
    _trackingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateDriverPosition();
    });

    // Pokreni praćenje saobraćaja (svakih 2 minuta)
    _trafficTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _checkTrafficConditions();
    });

    _logger.i('✅ Realtime tracking pokrenut uspešno');

    // Pošalji početnu notifikaciju
    await LocalNotificationService.showRealtimeNotification(
      title: '🗺️ Praćenje rute aktivno',
      body: 'Kontinuirano praćenje pozicije i optimizacija rute je pokrenuto',
      payload: 'route_tracking_started',
    );
  }

  /// ⏹️ Zaustavi kontinuirano praćenje
  static void stopRouteTracking() {
    _logger.i('⏹️ Zaustavljam realtime route tracking');

    _isTrackingActive = false;
    _trackingTimer?.cancel();
    _trafficTimer?.cancel();
    _currentDriverId = null;
    _currentRoute.clear();
    _lastKnownPosition = null;
    _currentOptimalRoute = null;

    _logger.i('✅ Tracking zaustavljen');
  }

  /// 📍 Ažuriraj poziciju vozača i proveri da li treba rerautovanje
  static Future<void> _updateDriverPosition() async {
    if (!_isTrackingActive || _currentDriverId == null) return;

    try {
      // Dobij trenutnu poziciju
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Pošalji GPS u bazu (postojeći servis)
      await GpsService.sendCurrentLocation(vozacId: _currentDriverId!);

      // Proveri da li je vozač značajno promenio poziciju
      if (_lastKnownPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastKnownPosition!.latitude,
          _lastKnownPosition!.longitude,
          currentPosition.latitude,
          currentPosition.longitude,
        );

        // Ako je pomeranje veće od 500m, izračunaj novu optimalnu rutu
        if (distance > 500) {
          _logger.i('📍 Značajno pomeranje detektovano: ${distance.toInt()}m');
          await _recalculateRoute(currentPosition);
        }
      }

      _lastKnownPosition = currentPosition;

      // Ažuriraj realtime podatke
      _updateRealtimeData();
    } catch (e) {
      _logger.e('❌ Greška ažuriranja pozicije: $e');
    }
  }

  /// 🔄 Dinamičko rerautovanje na osnovu nove pozicije
  static Future<void> _recalculateRoute(Position newPosition) async {
    _logger.i('🔄 Rekalkuišem rutu na osnovu nove pozicije...');

    // Filtriraj samo ne-pokupljene putnike
    final remainingPassengers = _currentRoute
        .where((p) =>
            p.vremePokupljenja == null &&
            !p.jeOtkazan &&
            p.adresa != null &&
            p.adresa!.isNotEmpty)
        .toList();

    if (remainingPassengers.isEmpty) {
      _logger.i('✅ Svi putnici pokupljeni - nema potrebe za rerautovanjem');
      return;
    }

    // Izračunaj novu optimalnu rutu
    final newOptimalRoute = await _calculateOptimalRouteFromPosition(
        newPosition, remainingPassengers);

    if (newOptimalRoute != _currentOptimalRoute) {
      _currentOptimalRoute = newOptimalRoute;

      _logger.i('🚨 Nova optimalna ruta kalkulisana!');

      // Pošalji notifikaciju o novoj ruti
      await LocalNotificationService.showRealtimeNotification(
        title: '🔄 Nova optimalna ruta!',
        body:
            'Ruta je automatski optimizovana na osnovu vaše trenutne pozicije',
        payload: 'route_recalculated',
      );

      // Ažuriraj stream sa novim podacima
      _updateRealtimeData();
    }
  }

  /// 🚦 Proveri saobraćajne uslove i predloži alternativne rute
  static Future<void> _checkTrafficConditions() async {
    if (!_isTrackingActive || _lastKnownPosition == null) return;

    _logger.i('🚦 Proveravam saobraćajne uslove...');

    try {
      final trafficAlerts = <String>[];

      // Proveri saobraćaj za svaku destinaciju
      for (final putnik in _currentRoute) {
        if (putnik.vremePokupljenja != null || putnik.adresa == null) continue;

        final trafficData = await _getTrafficData(
          _lastKnownPosition!,
          putnik.adresa!,
        );

        if (trafficData != null) {
          // Analiziraj saobraćajne podatke
          final duration = trafficData['duration_in_traffic']?['value'] ?? 0;
          final normalDuration = trafficData['duration']?['value'] ?? 0;

          // Ako je gužva značajna (više od 20% duže)
          if (duration > normalDuration * 1.2) {
            final delayMinutes = ((duration - normalDuration) / 60).round();
            trafficAlerts.add(
                '🚦 Gužva prema ${putnik.ime} (${putnik.adresa}): +$delayMinutes min');
          }
        }
      }

      if (trafficAlerts.isNotEmpty) {
        _trafficAlertsController.add(trafficAlerts);

        // Pošalji notifikaciju o gužvi
        await LocalNotificationService.showRealtimeNotification(
          title: '🚦 Saobraćajno upozorenje',
          body:
              'Detektovane su gužve na vašoj ruti. Proverite preporučene alternative.',
          payload: 'traffic_alert',
        );
      }
    } catch (e) {
      _logger.e('❌ Greška proveravanja saobraćaja: $e');
    }
  }

  /// 🗺️ Dobij saobraćajne podatke od Google Maps API
  static Future<Map<String, dynamic>?> _getTrafficData(
    Position origin,
    String destination,
  ) async {
    try {
      final url = Uri.parse('$_trafficApiUrl?'
          'origins=${origin.latitude},${origin.longitude}&'
          'destinations=${Uri.encodeComponent(destination)}&'
          'departure_time=now&'
          'traffic_model=best_guess&'
          'key=$_googleApiKey');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' &&
            data['rows'] != null &&
            data['rows'].isNotEmpty &&
            data['rows'][0]['elements'] != null &&
            data['rows'][0]['elements'].isNotEmpty) {
          return data['rows'][0]['elements'][0];
        }
      }
    } catch (e) {
      _logger.e('❌ Greška API poziva za saobraćaj: $e');
    }

    return null;
  }

  /// 🧮 Izračunaj optimalnu rutu iz trenutne pozicije
  static Future<String?> _calculateOptimalRouteFromPosition(
    Position currentPosition,
    List<Putnik> passengers,
  ) async {
    if (passengers.isEmpty) return null;

    try {
      // Kreiraj waypoints string za Google Directions API
      final waypoints =
          passengers.map((p) => Uri.encodeComponent(p.adresa!)).join('|');

      final url = Uri.parse('$_directionsApiUrl?'
          'origin=${currentPosition.latitude},${currentPosition.longitude}&'
          'destination=${Uri.encodeComponent(passengers.last.adresa!)}&'
          'waypoints=optimize:true|$waypoints&'
          'departure_time=now&'
          'traffic_model=best_guess&'
          'key=$_googleApiKey');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          // Vrati optimizovanu rutu kao string
          final route = data['routes'][0];
          final waypointOrder = route['waypoint_order'] ?? [];

          final optimizedPassengers = <Putnik>[];
          for (final index in waypointOrder) {
            if (index < passengers.length) {
              optimizedPassengers.add(passengers[index]);
            }
          }

          return optimizedPassengers.map((p) => p.ime).join(' → ');
        }
      }
    } catch (e) {
      _logger.e('❌ Greška kalkulacije optimalne rute: $e');
    }

    return null;
  }

  /// 🔄 Izračunaj početnu optimalnu rutu
  static Future<void> _calculateOptimalRoute() async {
    if (_lastKnownPosition == null) return;

    _currentOptimalRoute = await _calculateOptimalRouteFromPosition(
      _lastKnownPosition!,
      _currentRoute,
    );
  }

  /// 📊 Ažuriraj realtime podatke u stream-u
  static void _updateRealtimeData() {
    if (!_isTrackingActive || _lastKnownPosition == null) return;

    final realtimeData = RealtimeRouteData(
      currentPosition: _lastKnownPosition!,
      currentRoute: _currentRoute,
      optimalRoute: _currentOptimalRoute,
      isTrackingActive: _isTrackingActive,
      driverId: _currentDriverId!,
      timestamp: DateTime.now(),
    );

    _routeDataController.add(realtimeData);
  }

  /// 🛑 Cleanup na disposal
  static void dispose() {
    stopRouteTracking();
    _routeDataController.close();
    _trafficAlertsController.close();
  }
}
