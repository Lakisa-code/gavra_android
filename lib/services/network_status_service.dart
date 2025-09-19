import 'dart:async';
import 'dart:io';
import '../utils/logging.dart';

/// 📡 NETWORK STATUS SERVICE
/// Jednostavan network monitoring bez dodatnih paketa
class NetworkStatusService {
  static final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();

  static bool _isOnline = true;
  static Timer? _checkTimer;

  /// 📡 STREAM NETWORK STATUS
  static Stream<bool> get statusStream => _statusController.stream;

  /// 📊 TRENUTNO STANJE
  static bool get isOnline => _isOnline;

  /// 🚀 START MONITORING
  static void startMonitoring() {
    dlog('📡 [NETWORK STATUS] Pokretam monitoring...');

    // Proveri odmah
    _checkNetworkStatus();

    // Zatim svakih 10 sekundi
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkNetworkStatus();
    });
  }

  /// 🔍 PROVERI NETWORK STATUS
  static Future<void> _checkNetworkStatus() async {
    try {
      // Brza provera preko Google DNS
      final result = await InternetAddress.lookup('8.8.8.8')
          .timeout(const Duration(seconds: 3));

      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _updateStatus(isConnected);
    } catch (e) {
      _updateStatus(false);
    }
  }

  /// 📊 UPDATE STATUS
  static void _updateStatus(bool isConnected) {
    if (_isOnline != isConnected) {
      _isOnline = isConnected;
      _statusController.add(isConnected);

      final status = isConnected ? 'ONLINE' : 'OFFLINE';
      dlog('📡 [NETWORK STATUS] $status');
    }
  }

  /// 🧹 CLEANUP
  static void dispose() {
    _checkTimer?.cancel();
    _statusController.close();
  }
}
