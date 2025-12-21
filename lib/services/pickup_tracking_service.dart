import 'dart:async';
import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/putnik.dart';
import 'permission_service.dart';

/// 🎯 PICKUP TRACKING SERVICE
class PickupTrackingService {
  static final PickupTrackingService _instance = PickupTrackingService._internal();
  factory PickupTrackingService() => _instance;
  PickupTrackingService._internal();

  // 📍 KONSTANTE
  static const double proximityThresholdMeters = 100.0;
  static const Duration trackingInterval = Duration(seconds: 10);

  // 🔔 NOTIFICATION IDs
  static const int pickupNotificationId = 1001;
  static const String channelId = 'gavra_pickup_channel';
  static const String channelName = 'Pickup Notifikacije';

  // 📊 STATE
  List<Putnik> _activePutnici = [];
  Map<Putnik, Position> _putnikCoordinates = {};
  int _currentPutnikIndex = 0;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionSubscription;

  // 🔔 NOTIFICATIONS
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // 📡 CALLBACKS
  Function(Putnik, String)? onPutnikPickedUp;
  Function(Putnik)? onPutnikSkipped;
  Function(Putnik, double)? onApproachingPutnik;
  Function()? onAllPutniciCompleted;

  /// 🚀 INITIALIZE NOTIFICATION PLUGIN
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    const androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'Notifikacije za pokupljene putnike',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// 🎯 START TRACKING
  Future<bool> startTracking({
    required List<Putnik> putnici,
    required Map<Putnik, Position> coordinates,
    Function(Putnik, String)? onPickedUp,
    Function(Putnik)? onSkipped,
    Function(Putnik, double)? onApproaching,
    Function()? onCompleted,
  }) async {
    if (putnici.isEmpty || coordinates.isEmpty) {
      return false;
    }

    // 🔐 CENTRALIZOVANA PROVERA GPS DOZVOLA
    final hasPermission = await PermissionService.ensureGpsForNavigation();
    if (!hasPermission) {
      return false;
    }

    _activePutnici = List.from(putnici);
    _putnikCoordinates = Map.from(coordinates);
    _currentPutnikIndex = 0;
    _isTracking = true;

    onPutnikPickedUp = onPickedUp;
    onPutnikSkipped = onSkipped;
    onApproachingPutnik = onApproaching;
    onAllPutniciCompleted = onCompleted;

    await _saveTrackingState();

    _startGpsStream();
    return true;
  }

  /// ⏹️ STOP TRACKING
  Future<void> stopTracking() async {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _activePutnici.clear();
    _putnikCoordinates.clear();
    _currentPutnikIndex = 0;

    await _notifications.cancel(pickupNotificationId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pickup_tracking_active');
  }

  /// 📍 START GPS STREAM
  void _startGpsStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (error) {},
    );
  }

  /// 📍 POSITION UPDATE HANDLER
  void _onPositionUpdate(Position driverPosition) {
    if (!_isTracking || _activePutnici.isEmpty) return;
    if (_currentPutnikIndex >= _activePutnici.length) {
      onAllPutniciCompleted?.call();
      stopTracking();
      return;
    }

    final currentPutnik = _activePutnici[_currentPutnikIndex];
    final putnikPosition = _putnikCoordinates[currentPutnik];

    if (putnikPosition == null) {
      _moveToNextPutnik();
      return;
    }

    final distanceMeters = _calculateDistance(
      driverPosition.latitude,
      driverPosition.longitude,
      putnikPosition.latitude,
      putnikPosition.longitude,
    );
    onApproachingPutnik?.call(currentPutnik, distanceMeters);

    if (distanceMeters <= proximityThresholdMeters) {
      _showPickupNotification(currentPutnik, distanceMeters);
    }
  }

  /// 🔔 SHOW PICKUP NOTIFICATION
  Future<void> _showPickupNotification(Putnik putnik, double distance) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notifikacije za pokupljene putnike',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      actions: [
        const AndroidNotificationAction(
          'pokupio',
          '✅ Pokupio sam',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'preskoci',
          '⏭️ Preskoči',
          showsUserInterface: true,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      pickupNotificationId,
      '📍 Blizu: ${putnik.ime}',
      '${putnik.adresa} (${distance.toStringAsFixed(0)}m)\nDa li ste pokupili putnika?',
      details,
      payload: putnik.id.toString(),
    );
  }

  /// 🔔 HANDLE NOTIFICATION RESPONSE
  void _handleNotificationResponse(NotificationResponse response) {
    final action = response.actionId;
    if (_currentPutnikIndex >= _activePutnici.length) return;
    final currentPutnik = _activePutnici[_currentPutnikIndex];

    if (action == 'pokupio') {
      onPutnikPickedUp?.call(currentPutnik, 'picked_up');
      _moveToNextPutnik();
    } else if (action == 'preskoci') {
      onPutnikSkipped?.call(currentPutnik);
      _moveToNextPutnik();
    }
  }

  /// ➡️ MOVE TO NEXT PUTNIK
  void _moveToNextPutnik() {
    _currentPutnikIndex++;

    if (_currentPutnikIndex >= _activePutnici.length) {
      _notifications.cancel(pickupNotificationId);
      onAllPutniciCompleted?.call();
      stopTracking();
    } else {
      final nextPutnik = _activePutnici[_currentPutnikIndex];
      _updateToNextPutnikNotification(nextPutnik);
    }

    _saveTrackingState();
  }

  /// 🔔 UPDATE NOTIFICATION FOR NEXT PUTNIK
  Future<void> _updateToNextPutnikNotification(Putnik nextPutnik) async {
    final remaining = _activePutnici.length - _currentPutnikIndex;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notifikacije za pokupljene putnike',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: true,
      autoCancel: false,
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      pickupNotificationId,
      '🚗 Sledeći: ${nextPutnik.ime}',
      '${nextPutnik.adresa}\nOstalo: $remaining putnika',
      details,
    );
  }

  /// 📏 CALCULATE DISTANCE (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) + cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  /// 💾 SAVE TRACKING STATE
  Future<void> _saveTrackingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pickup_tracking_active', _isTracking);
    await prefs.setInt('pickup_current_index', _currentPutnikIndex);
  }

  /// ❓ IS TRACKING ACTIVE
  bool get isTracking => _isTracking;

  /// 📊 GET CURRENT PUTNIK
  Putnik? get currentPutnik {
    if (_currentPutnikIndex < _activePutnici.length) {
      return _activePutnici[_currentPutnikIndex];
    }
    return null;
  }

  /// 📊 GET REMAINING COUNT
  int get remainingCount => _activePutnici.length - _currentPutnikIndex;

  /// 📊 GET PROGRESS
  double get progress {
    if (_activePutnici.isEmpty) return 0.0;
    return _currentPutnikIndex / _activePutnici.length;
  }

  /// 🔧 MANUALLY MARK PUTNIK AS PICKED UP
  void markCurrentAsPickedUp() {
    if (_currentPutnikIndex < _activePutnici.length) {
      final putnik = _activePutnici[_currentPutnikIndex];
      onPutnikPickedUp?.call(putnik, 'manual');
      _moveToNextPutnik();
    }
  }

  /// 🔧 MANUALLY SKIP CURRENT PUTNIK
  void skipCurrentPutnik() {
    if (_currentPutnikIndex < _activePutnici.length) {
      final putnik = _activePutnici[_currentPutnikIndex];
      onPutnikSkipped?.call(putnik);
      _moveToNextPutnik();
    }
  }
}
