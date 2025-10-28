import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🛰️ BESPLATNO BACKGROUND GPS TRACKING (SIMPLIFIED)
/// Kontinuirani GPS tracking koristeći samo flutter_background_service
class BackgroundGpsService {
  static bool _isInitialized = false;

  /// 🚀 INITIALIZE BACKGROUND GPS SERVICE
  static Future<void> initialize() async {
    if (_isInitialized) return;

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        notificationChannelId: 'gavra_gps_channel',
        initialNotificationTitle: 'Gavra GPS Tracking',
        initialNotificationContent: 'GPS praćenje je aktivno',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    _isInitialized = true;
  }

  /// 🎯 START BACKGROUND GPS TRACKING
  static Future<void> startBackgroundTracking() async {
    if (!_isInitialized) {
      await initialize();
    }

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (!isRunning) {
      await service.startService();
    }

    // Označi da je tracking aktivan
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_gps_active', true);
  }

  /// ⏹️ STOP BACKGROUND GPS TRACKING
  static Future<void> stopBackgroundTracking() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');

    // Označi da tracking nije aktivan
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_gps_active', false);
  }

  /// ❓ CHECK DA LI JE TRACKING AKTIVAN
  static Future<bool> isTrackingActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('background_gps_active') ?? false;
  }

  /// 🔄 ALIAS ZA isTrackingActive (za kompatibilnost)
  static Future<bool> isBackgroundTrackingActive() async {
    return isTrackingActive();
  }
}

/// 🔧 ANDROID BACKGROUND SERVICE START
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  Timer.periodic(const Duration(minutes: 5), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // Update notification
        service.setForegroundNotificationInfo(
          title: 'Gavra GPS Tracking',
          content: 'Praćenje lokacije je aktivno - ${DateTime.now()}',
        );
      }
    }

    // Pokušaj da dobiješ GPS poziciju
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Pošalji na Supabase (ako je moguće)
      await _sendLocationToSupabase(position);

      // Invoke frontend sa novom pozicijom
      service.invoke('update', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // GPS greška - tiho ignoriši
    }
  });

  // Sluša za stop komande
  service.on('stop').listen((event) {
    service.stopSelf();
  });
}

/// 🍎 iOS BACKGROUND SERVICE
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true; // Keep running
}

/// 📡 POŠALJI LOKACIJU NA SUPABASE
Future<void> _sendLocationToSupabase(Position position) async {
  try {
    // Samo ako je Supabase dostupan
    if (Supabase.instance.client.auth.currentUser != null) {
      await Supabase.instance.client.from('gps_tracking').insert({
        'user_id': Supabase.instance.client.auth.currentUser!.id,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  } catch (e) {
    // Ignoriši Supabase greške u background service
    // Tiha greška - background GPS nastavlja rad
  }
}
