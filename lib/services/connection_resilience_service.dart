import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🌐 CONNECTION RESILIENCE SERVICE
/// Automatski reconnect, network monitoring, fallback strategije (FIXED VERSION)
class ConnectionResilienceService {
  static final _supabase = Supabase.instance.client;

  // Stream kontroleri
  static final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  static final StreamController<String> _connectionStatusController =
      StreamController<String>.broadcast();

  // Stanje konekcije
  static bool _isOnline = true;
  static bool _isSupabaseConnected = true;
  static Timer? _reconnectTimer;
  static Timer? _healthCheckTimer;
  static Timer? _networkMonitorTimer;

  // Retry konfiguracija
  static const int _maxRetries = 5;
  static const Duration _baseRetryDelay = Duration(seconds: 2);
  static const Duration _healthCheckInterval = Duration(seconds: 30);
  static const Duration _networkCheckInterval = Duration(seconds: 10);

  // Getteri za stream-ove
  static Stream<bool> get connectionStateStream =>
      _connectionStateController.stream;
  static Stream<String> get connectionStatusStream =>
      _connectionStatusController.stream;

  // Getteri za trenutno stanje
  static bool get isOnline => _isOnline;
  static bool get isSupabaseConnected => _isSupabaseConnected;
  static bool get isFullyConnected => _isOnline && _isSupabaseConnected;

  /// 🚀 INICIJALIZACIJA SERVISA
  static Future<void> initialize() async {
    debugPrint('🌐 [CONNECTION RESILIENCE] Inicijalizujem servis...');

    // Proveri početno stanje konekcije
    await _checkInitialConnectivity();

    // Pokreni monitoring konekcije
    _startNetworkMonitoring();

    // Pokreni health check
    _startHealthCheck();

    debugPrint('✅ [CONNECTION RESILIENCE] Servis inicijalizovan');
  }

  /// 📡 PROVERA POČETNE KONEKCIJE
  static Future<void> _checkInitialConnectivity() async {
    try {
      final isConnected = await _checkNetworkConnection();
      _updateConnectionState(isConnected);

      if (isConnected) {
        await _checkSupabaseConnection();
      }
    } catch (e) {
      debugPrint('❌ [CONNECTION RESILIENCE] Greška provere konekcije: $e');
      _updateConnectionState(false);
    }
  }

  /// 🌐 PROVERA NETWORK KONEKCIJE
  static Future<bool> _checkNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('❌ [CONNECTION RESILIENCE] Network check failed: $e');
      return false;
    }
  }

  /// 👂 MONITORING NETWORK KONEKCIJE
  static void _startNetworkMonitoring() {
    _networkMonitorTimer = Timer.periodic(_networkCheckInterval, (timer) async {
      final wasOnline = _isOnline;
      final isConnected = await _checkNetworkConnection();

      if (wasOnline != isConnected) {
        debugPrint(
            '🔄 [CONNECTION RESILIENCE] Network status changed: ${isConnected ? "ONLINE" : "OFFLINE"}');

        _updateConnectionState(isConnected);

        if (isConnected && !_isSupabaseConnected) {
          // Network je vraćen, pokušaj reconnect na Supabase
          await _attemptSupabaseReconnect();
        }
      }
    });
  }

  /// 🏥 HEALTH CHECK ZA SUPABASE
  static void _startHealthCheck() {
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) async {
      if (_isOnline) {
        await _checkSupabaseConnection();
      }
    });
  }

  /// 🔍 PROVERA SUPABASE KONEKCIJE
  static Future<void> _checkSupabaseConnection() async {
    try {
      // Jednostavan test query
      await _supabase
          .from('mesecni_putnici')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 10));

      if (!_isSupabaseConnected) {
        debugPrint('✅ [CONNECTION RESILIENCE] Supabase reconnected!');
        _updateSupabaseState(true);
      }
    } catch (e) {
      debugPrint('❌ [CONNECTION RESILIENCE] Supabase check failed: $e');
      _updateSupabaseState(false);

      if (_isOnline) {
        // Network je OK ali Supabase ne, pokušaj reconnect
        _scheduleSupabaseReconnect();
      }
    }
  }

  /// 🔄 POKUŠAJ SUPABASE RECONNECT
  static Future<void> _attemptSupabaseReconnect() async {
    debugPrint('🔄 [CONNECTION RESILIENCE] Pokušavam Supabase reconnect...');

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        await _checkSupabaseConnection();

        if (_isSupabaseConnected) {
          debugPrint(
              '✅ [CONNECTION RESILIENCE] Reconnect uspešan nakon $attempt pokušaja');
          return;
        }
      } catch (e) {
        debugPrint(
            '❌ [CONNECTION RESILIENCE] Reconnect pokušaj $attempt/$_maxRetries failed: $e');
      }

      if (attempt < _maxRetries) {
        final delay = _baseRetryDelay * attempt;
        debugPrint(
            '⏳ [CONNECTION RESILIENCE] Čekam ${delay.inSeconds}s pre sledećeg pokušaja...');
        await Future.delayed(delay);
      }
    }

    debugPrint('💥 [CONNECTION RESILIENCE] Svi reconnect pokušaji neuspešni');
  }

  /// ⏰ ZAKAŽI SUPABASE RECONNECT
  static void _scheduleSupabaseReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _attemptSupabaseReconnect();
    });
  }

  /// 📊 UPDATE NETWORK STATE
  static void _updateConnectionState(bool isConnected) {
    if (_isOnline != isConnected) {
      _isOnline = isConnected;
      _connectionStateController.add(isConnected);

      final status = isConnected ? 'Online' : 'Offline';
      _connectionStatusController.add(status);

      debugPrint('🌐 [CONNECTION RESILIENCE] Network: $status');
    }
  }

  /// 📊 UPDATE SUPABASE STATE
  static void _updateSupabaseState(bool isConnected) {
    if (_isSupabaseConnected != isConnected) {
      _isSupabaseConnected = isConnected;

      final status =
          isConnected ? 'Supabase Connected' : 'Supabase Disconnected';
      _connectionStatusController.add(status);

      debugPrint('🗄️ [CONNECTION RESILIENCE] Supabase: $status');
    }
  }

  /// 🧪 FORSIRAJ RECONNECT TEST
  static Future<void> forceReconnectTest() async {
    debugPrint('🧪 [CONNECTION RESILIENCE] Force reconnect test...');
    await _attemptSupabaseReconnect();
  }

  /// 🔄 MANUAL REFRESH KONEKCIJE
  static Future<bool> refreshConnection() async {
    debugPrint('🔄 [CONNECTION RESILIENCE] Manual refresh...');

    await _checkInitialConnectivity();
    return isFullyConnected;
  }

  /// 🧹 CLEANUP
  static void dispose() {
    debugPrint('🧹 [CONNECTION RESILIENCE] Cleanup...');

    _reconnectTimer?.cancel();
    _healthCheckTimer?.cancel();
    _networkMonitorTimer?.cancel();

    _connectionStateController.close();
    _connectionStatusController.close();
  }
}
