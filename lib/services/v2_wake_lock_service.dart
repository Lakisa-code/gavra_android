import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Servis za paljenje ekrana kada stigne notifikacija.
/// Koristi native Android WakeLock API.
class V2WakeLockService {
  V2WakeLockService._();

  static const MethodChannel _channel = MethodChannel('com.gavra013.gavra_android/wakelock');

  /// Pali ekran na određeno vreme (default 5 sekundi).
  /// Koristi se kada stigne push notifikacija dok je telefon zaključan.
  static Future<bool> wakeScreen({int durationMs = 5000}) async {
    try {
      final result = await _channel.invokeMethod<bool>('wakeScreen', {
        'duration': durationMs,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('[V2WakeLockService] WakeLock nije dostupan ili greška: $e');
      return false;
    }
  }
}
