import 'dart:async';

import 'package:flutter/foundation.dart';

/// 🛑 FAIL-FAST STREAM DISPOSAL MANAGER
/// Prati sve stream subscription-e i omogućava fail-fast cleanup

class FailFastStreamManager {
  FailFastStreamManager._internal();
  static FailFastStreamManager? _instance;
  static FailFastStreamManager get instance {
    _instance ??= FailFastStreamManager._internal();
    return _instance!;
  }

  // 📋 TRACKING SUBSCRIPTIONS
  final Map<String, StreamSubscription<dynamic>> _activeSubscriptions = {};
  final Map<String, DateTime> _subscriptionStartTimes = {};
  final Map<String, int> _subscriptionErrorCounts = {};

  // 🚨 ERROR HANDLING
  final Map<String, void Function(Object error, StackTrace? stackTrace)?> _errorHandlers = {};
  bool _failFastMode = true; // Ako je true, bilo koja greška prekida sve

  // 📊 STATISTICS
  int _totalSubscriptions = 0;
  int _totalDisposals = 0;
  int _totalErrors = 0;

  /// 🚀 REGISTER STREAM SUBSCRIPTION
  void registerSubscription<T>(
    String subscriptionId,
    StreamSubscription<T> subscription, {
    void Function(Object error, StackTrace? stackTrace)? onError,
    bool critical = false, // Ako je critical=true, greška prekida sve
  }) {
    // Cancel existing subscription sa istim ID
    if (_activeSubscriptions.containsKey(subscriptionId)) {
      _cancelSubscription(subscriptionId, reason: 'Replacing existing subscription');
    }

    _activeSubscriptions[subscriptionId] = subscription;
    _subscriptionStartTimes[subscriptionId] = DateTime.now();
    _subscriptionErrorCounts[subscriptionId] = 0;
    _errorHandlers[subscriptionId] = onError;
    _totalSubscriptions++;

    if (kDebugMode) {
      print('🚀 [STREAM_MANAGER] Registered: $subscriptionId (Total: ${_activeSubscriptions.length})');
    }

    // Wrap original error handler with fail-fast logic
    subscription.onError((Object error, StackTrace stackTrace) {
      _handleSubscriptionError(subscriptionId, error, stackTrace, critical);
    });
  }

  /// 🚨 HANDLE SUBSCRIPTION ERROR
  void _handleSubscriptionError(
    String subscriptionId,
    Object error,
    StackTrace? stackTrace,
    bool critical,
  ) {
    _totalErrors++;
    _subscriptionErrorCounts[subscriptionId] = (_subscriptionErrorCounts[subscriptionId] ?? 0) + 1;

    if (kDebugMode) {
      print('🚨 [STREAM_MANAGER] Error in $subscriptionId: $error');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }

    // Call custom error handler if provided
    final customHandler = _errorHandlers[subscriptionId];
    if (customHandler != null) {
      try {
        customHandler(error, stackTrace);
      } catch (handlerError) {
        if (kDebugMode) {
          print('🚨 [STREAM_MANAGER] Error handler failed for $subscriptionId: $handlerError');
        }
      }
    }

    // FAIL-FAST LOGIC
    if (_failFastMode && critical) {
      if (kDebugMode) {
        print('🛑 [STREAM_MANAGER] FAIL-FAST triggered by critical error in $subscriptionId');
      }
      disposeAll(reason: 'FAIL-FAST: Critical error in $subscriptionId');
      throw Exception('FAIL-FAST: Critical error in $subscriptionId - $error'); // Throw instead of rethrow
    }

    // If too many errors in single subscription, dispose it
    if ((_subscriptionErrorCounts[subscriptionId] ?? 0) >= 3) {
      if (kDebugMode) {
        print('🛑 [STREAM_MANAGER] Disposing $subscriptionId due to excessive errors');
      }
      _cancelSubscription(subscriptionId, reason: 'Excessive errors (${_subscriptionErrorCounts[subscriptionId]})');

      // In fail-fast mode, dispose all if any subscription fails
      if (_failFastMode) {
        disposeAll(reason: 'FAIL-FAST: Excessive errors in $subscriptionId');
      }
    }
  }

  /// ❌ CANCEL SINGLE SUBSCRIPTION
  void _cancelSubscription(String subscriptionId, {String? reason}) {
    final subscription = _activeSubscriptions[subscriptionId];
    if (subscription != null) {
      try {
        subscription.cancel();
        _totalDisposals++;

        if (kDebugMode) {
          final duration = DateTime.now().difference(_subscriptionStartTimes[subscriptionId] ?? DateTime.now());
          print(
            '❌ [STREAM_MANAGER] Cancelled $subscriptionId after ${duration.inSeconds}s. Reason: ${reason ?? "Manual"}',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('🚨 [STREAM_MANAGER] Error cancelling $subscriptionId: $e');
        }
        // In fail-fast mode, don't swallow dispose errors
        if (_failFastMode) {
          throw Exception('Failed to cancel subscription $subscriptionId: $e');
        }
      } finally {
        _activeSubscriptions.remove(subscriptionId);
        _subscriptionStartTimes.remove(subscriptionId);
        _subscriptionErrorCounts.remove(subscriptionId);
        _errorHandlers.remove(subscriptionId);
      }
    }
  }

  /// 🛑 DISPOSE SINGLE SUBSCRIPTION (PUBLIC API)
  void disposeSubscription(String subscriptionId, {String? reason}) {
    _cancelSubscription(subscriptionId, reason: reason ?? 'Manual disposal');
  }

  /// 💥 DISPOSE ALL SUBSCRIPTIONS
  void disposeAll({String? reason}) {
    if (kDebugMode) {
      print(
        '💥 [STREAM_MANAGER] Disposing ALL subscriptions (${_activeSubscriptions.length}). Reason: ${reason ?? "Manual"}',
      );
    }

    final subscriptionIds = List<String>.from(_activeSubscriptions.keys);

    for (final id in subscriptionIds) {
      _cancelSubscription(id, reason: reason ?? 'Mass disposal');
    }

    if (kDebugMode) {
      print('✅ [STREAM_MANAGER] All subscriptions disposed');
    }
  }

  /// 🔄 SET FAIL-FAST MODE
  void setFailFastMode(bool enabled) {
    _failFastMode = enabled;
    if (kDebugMode) {
      print('🔄 [STREAM_MANAGER] Fail-fast mode: ${enabled ? "ENABLED" : "DISABLED"}');
    }
  }

  /// 📊 GET MANAGER STATUS
  Map<String, dynamic> getStatus() {
    final now = DateTime.now();
    final subscriptionDetails = <String, Map<String, dynamic>>{};

    for (final entry in _activeSubscriptions.entries) {
      final startTime = _subscriptionStartTimes[entry.key] ?? now;
      final duration = now.difference(startTime);
      final errorCount = _subscriptionErrorCounts[entry.key] ?? 0;

      subscriptionDetails[entry.key] = {
        'duration_seconds': duration.inSeconds,
        'error_count': errorCount,
        'start_time': startTime.toIso8601String(),
        'has_custom_handler': _errorHandlers[entry.key] != null,
      };
    }

    return {
      'active_subscriptions': _activeSubscriptions.length,
      'total_subscriptions_created': _totalSubscriptions,
      'total_disposals': _totalDisposals,
      'total_errors': _totalErrors,
      'fail_fast_mode': _failFastMode,
      'subscription_details': subscriptionDetails,
    };
  }

  /// 🏥 HEALTH CHECK
  bool isHealthy() {
    // Check if any subscription has too many errors
    for (final errorCount in _subscriptionErrorCounts.values) {
      if (errorCount >= 3) {
        return false;
      }
    }

    // Check if any subscription is running too long (potential memory leak)
    final now = DateTime.now();
    for (final startTime in _subscriptionStartTimes.values) {
      if (now.difference(startTime).inHours >= 24) {
        return false; // 24 hours is too long for mobile app
      }
    }

    return true;
  }

  /// 🧹 CLEANUP ON APP SHUTDOWN
  void shutdown() {
    if (kDebugMode) {
      print('🧹 [STREAM_MANAGER] Shutting down...');
    }

    disposeAll(reason: 'Application shutdown');

    // Reset all counters
    _totalSubscriptions = 0;
    _totalDisposals = 0;
    _totalErrors = 0;

    if (kDebugMode) {
      print('✅ [STREAM_MANAGER] Shutdown complete');
    }
  }

  /// 🔍 FIND PROBLEMATIC SUBSCRIPTIONS
  List<String> getProblematicSubscriptions() {
    final problematic = <String>[];

    for (final entry in _subscriptionErrorCounts.entries) {
      if (entry.value >= 2) {
        // 2 or more errors
        problematic.add(entry.key);
      }
    }

    return problematic;
  }

  /// ⏰ GET LONGEST RUNNING SUBSCRIPTIONS
  List<Map<String, dynamic>> getLongestRunningSubscriptions({int limit = 5}) {
    final now = DateTime.now();
    final subscriptions = <Map<String, dynamic>>[];

    for (final entry in _subscriptionStartTimes.entries) {
      final duration = now.difference(entry.value);
      subscriptions.add({
        'id': entry.key,
        'duration_seconds': duration.inSeconds,
        'duration_formatted': '${duration.inHours}h ${duration.inMinutes % 60}m ${duration.inSeconds % 60}s',
        'error_count': _subscriptionErrorCounts[entry.key] ?? 0,
      });
    }

    // Sort by duration (longest first)
    subscriptions.sort((a, b) => (b['duration_seconds'] as int).compareTo(a['duration_seconds'] as int));

    return subscriptions.take(limit).toList();
  }
}
