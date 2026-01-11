import 'package:flutter/services.dart';

/// 📱 Servis za paljenje ekrana kada stigne notifikacija
/// Koristi native Android WakeLock API
class WakeLockService {
  static const MethodChannel _channel = MethodChannel('com.gavra013.gavra_android/wakelock');

  /// Pali ekran na određeno vreme (default 5 sekundi)
  /// Koristi se kada stigne push notifikacija dok je telefon zaključan
  static Future<bool> wakeScreen({int durationMs = 5000}) async {
    try {
      final result = await _channel.invokeMethod<bool>('wakeScreen', {
        'duration': durationMs,
      });
      return result ?? false;
    } catch (e) {
      // WakeLock nije dostupan ili greška
      return false;
    }
  }

  /// Oslobađa WakeLock ručno (obično nije potrebno jer ima timeout)
  static Future<bool> releaseWakeLock() async {
    try {
      final result = await _channel.invokeMethod<bool>('releaseWakeLock');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}
