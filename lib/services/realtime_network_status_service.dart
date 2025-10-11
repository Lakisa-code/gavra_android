import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// 🚥 REALTIME NETWORK STATUS SERVICE
/// Prati network stanje i stream health u realnom vremenu

enum NetworkStatus {
  excellent, // 🟢 Sve radi savršeno
  good, // 🟡 Mali problemi, ali funkcionalno
  poor, // 🟠 Veliki problemi
  offline, // 🔴 Nema interneta uopšte
}

class RealtimeNetworkStatusService {
  RealtimeNetworkStatusService._internal();
  static RealtimeNetworkStatusService? _instance;
  static RealtimeNetworkStatusService get instance {
    _instance ??= RealtimeNetworkStatusService._internal();
    return _instance!;
  }

  // 🚥 STATUS TRACKING
  final ValueNotifier<NetworkStatus> _networkStatus = ValueNotifier(NetworkStatus.excellent);
  ValueNotifier<NetworkStatus> get networkStatus => _networkStatus;

  // 📊 METRICS TRACKING
  final Map<String, DateTime> _lastResponseTimes = {};
  final Map<String, int> _errorCounts = {};
  final List<Duration> _recentResponseTimes = [];

  // 🔗 CONNECTIVITY
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _healthCheckTimer;
  Timer? _pingTimer;

  // 📈 PERFORMANCE METRICS
  bool _isConnected = true;
  double _averageResponseTime = 0.0;
  int _totalErrors = 0;
  DateTime? _lastSuccessfulPing;

  /// 🚀 INICIJALIZACIJA SERVISA
  Future<void> initialize() async {
    _startConnectivityMonitoring();
    _startHealthChecking();
    _startPeriodicPing();
    await _checkInitialConnectivity();
  }

  /// 🔌 CONNECTIVITY MONITORING
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      _isConnected = !result.contains(ConnectivityResult.none);
      _updateNetworkStatus();

      if (kDebugMode) {
        print('🚥 [NETWORK] Connectivity changed: $result');
      }
    });
  }

  /// ⏱️ HEALTH CHECK TIMER
  void _startHealthChecking() {
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _performHealthCheck();
    });
  }

  /// 🏓 PERIODIC PING TEST
  void _startPeriodicPing() {
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _performPingTest();
    });
  }

  /// 🌐 INITIAL CONNECTIVITY CHECK
  Future<void> _checkInitialConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _isConnected = !result.contains(ConnectivityResult.none);
      await _performPingTest();
      _updateNetworkStatus();
    } catch (e) {
      _isConnected = false;
      _updateNetworkStatus();
    }
  }

  /// 📊 REGISTER STREAM RESPONSE
  void registerStreamResponse(String streamName, Duration responseTime, {bool hasError = false}) {
    _lastResponseTimes[streamName] = DateTime.now();

    if (hasError) {
      _errorCounts[streamName] = (_errorCounts[streamName] ?? 0) + 1;
      _totalErrors++;
    } else {
      // Reset error count on success
      _errorCounts[streamName] = 0;

      // Track response time
      _recentResponseTimes.add(responseTime);
      if (_recentResponseTimes.length > 10) {
        _recentResponseTimes.removeAt(0); // Keep only recent 10
      }

      // Calculate average response time
      if (_recentResponseTimes.isNotEmpty) {
        final total = _recentResponseTimes.map((d) => d.inMilliseconds).reduce((a, b) => a + b);
        _averageResponseTime = total / _recentResponseTimes.length;
      }
    }

    _updateNetworkStatus();
  }

  /// 🔍 HEALTH CHECK LOGIC
  void _performHealthCheck() {
    final now = DateTime.now();
    bool hasStaleStreams = false;
    bool hasFrequentErrors = false;

    // Check for stale streams (older than 60 seconds)
    for (final entry in _lastResponseTimes.entries) {
      if (now.difference(entry.value).inSeconds > 60) {
        hasStaleStreams = true;
        break;
      }
    }

    // Check for frequent errors (more than 3 per stream)
    for (final errorCount in _errorCounts.values) {
      if (errorCount > 3) {
        hasFrequentErrors = true;
        break;
      }
    }

    if (kDebugMode) {
      print(
        '🚥 [HEALTH] Stale: $hasStaleStreams, Errors: $hasFrequentErrors, AvgTime: ${_averageResponseTime.toStringAsFixed(1)}ms',
      );
    }

    _updateNetworkStatus();
  }

  /// 🏓 PING TEST TO CHECK REAL CONNECTIVITY
  Future<void> _performPingTest() async {
    try {
      final stopwatch = Stopwatch()..start();

      // Try to reach Google DNS
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 5),
      );

      stopwatch.stop();

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _lastSuccessfulPing = DateTime.now();
        final pingTime = stopwatch.elapsedMilliseconds;

        if (kDebugMode) {
          print('🏓 [PING] Success: ${pingTime}ms');
        }

        // Add ping time to response times for overall health
        _recentResponseTimes.add(Duration(milliseconds: pingTime));
        if (_recentResponseTimes.length > 10) {
          _recentResponseTimes.removeAt(0);
        }
      } else {
        throw Exception('No address found');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🏓 [PING] Failed: $e');
      }
      _lastSuccessfulPing = null;
    }

    _updateNetworkStatus();
  }

  /// 🚥 UPDATE NETWORK STATUS BASED ON ALL METRICS
  void _updateNetworkStatus() {
    final now = DateTime.now();

    // If no connectivity, always offline
    if (!_isConnected) {
      _networkStatus.value = NetworkStatus.offline;
      return;
    }

    // If no successful ping in last 2 minutes, consider offline
    if (_lastSuccessfulPing == null || now.difference(_lastSuccessfulPing!).inMinutes > 2) {
      _networkStatus.value = NetworkStatus.offline;
      return;
    }

    // Count recent errors and stale streams
    int recentErrors = 0;
    int staleStreams = 0;

    for (final entry in _errorCounts.entries) {
      if (entry.value > 0) recentErrors++;
    }

    for (final entry in _lastResponseTimes.entries) {
      if (now.difference(entry.value).inSeconds > 45) {
        staleStreams++;
      }
    }

    // Determine status based on metrics
    if (recentErrors == 0 && staleStreams == 0 && _averageResponseTime < 2000) {
      _networkStatus.value = NetworkStatus.excellent;
    } else if (recentErrors <= 1 && staleStreams <= 1 && _averageResponseTime < 5000) {
      _networkStatus.value = NetworkStatus.good;
    } else if (recentErrors <= 2 && staleStreams <= 2 && _averageResponseTime < 10000) {
      _networkStatus.value = NetworkStatus.poor;
    } else {
      _networkStatus.value = NetworkStatus.offline;
    }

    if (kDebugMode) {
      print(
        '🚥 [STATUS] ${_networkStatus.value} - Errors: $recentErrors, Stale: $staleStreams, AvgTime: ${_averageResponseTime.toStringAsFixed(1)}ms',
      );
    }
  }

  /// 📊 GET DETAILED STATUS INFO
  Map<String, dynamic> getDetailedStatus() {
    return {
      'status': _networkStatus.value.toString(),
      'isConnected': _isConnected,
      'averageResponseTime': _averageResponseTime,
      'totalErrors': _totalErrors,
      'lastSuccessfulPing': _lastSuccessfulPing?.toIso8601String(),
      'streamCount': _lastResponseTimes.length,
      'errorCounts': Map<String, dynamic>.from(_errorCounts),
      'lastResponseTimes': _lastResponseTimes.map((k, v) => MapEntry(k, v.toIso8601String())),
    };
  }

  /// 🧹 CLEANUP
  void dispose() {
    _connectivitySubscription?.cancel();
    _healthCheckTimer?.cancel();
    _pingTimer?.cancel();
    _networkStatus.dispose();
  }
}
