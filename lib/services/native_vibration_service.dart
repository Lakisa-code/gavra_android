import 'package:flutter/services.dart';

/// 📳 Native Vibration Service
/// Koristi Platform Channel za direktan pristup Android Vibrator API
/// Radi na svim Android uređajima uključujući Huawei
class NativeVibrationService {
  static const MethodChannel _channel = MethodChannel('com.gavra013.gavra_android/vibration');

  /// Proveri status vibratora na uređaju
  static Future<Map<String, dynamic>> checkVibrator() async {
    try {
      final result = await _channel.invokeMethod('checkVibrator');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Vibriraj određeno vreme (u milisekundama)
  static Future<bool> vibrate({int duration = 200}) async {
    try {
      final result = await _channel.invokeMethod('vibrate', {
        'duration': duration,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Vibriraj po patternu [pauza, vibracija, pauza, vibracija, ...]
  static Future<bool> vibratePattern({List<int>? pattern}) async {
    try {
      final result = await _channel.invokeMethod('vibratePattern', {
        'pattern': pattern ?? [0, 100, 50, 100, 50, 100],
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Kratka vibracija za potvrdu akcije
  static Future<bool> tick() => vibrate(duration: 50);

  /// Srednja vibracija za uspešnu akciju
  static Future<bool> success() => vibratePattern(pattern: [0, 100, 50, 100]);

  /// Duga vibracija za pokupljanje putnika
  static Future<bool> pickup() => vibrate(duration: 300);
}
