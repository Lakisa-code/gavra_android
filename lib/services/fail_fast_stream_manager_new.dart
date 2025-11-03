import 'dart:async';

import 'package:flutter/foundation.dart';

/// 🚨 FAIL-FAST STREAM MANAGER
/// Upravlja stream subscription-ima sa fail-fast pristupom
/// BEZ try-catch koji guta greške - sve greške se prenose direktno

class FailFastStreamManager {
  FailFastStreamManager._internal();
  static FailFastStreamManager? _instance;
  static FailFastStreamManager get instance {
    _instance ??= FailFastStreamManager._internal();
    return _instance!;
  }

  // 📊 STREAM TRACKING
  final Map<String, StreamSubscription<dynamic>> _activeSubscriptions = {};
  final Map<String, DateTime> _subscriptionStartTimes = {};
  final Map<String, int> _errorCounts = {};
  final Set<String> _criticalStreams = {};

  // 🎯 FAIL-FAST SETTINGS
  static const int maxErrorsBeforeFail = 3;
  static const Duration maxSubscriptionAge = Duration(hours: 2);
  static const Duration errorResetInterval = Duration(minutes: 5);

  /// 🚀 REGISTER CRITICAL STREAM (must not fail)
  void registerCriticalStream(String streamName) {
    _criticalStreams.add(streamName);
  }

  /// 📡 ADD STREAM SUBSCRIPTION WITH FAIL-FAST
  void addSubscription<T>(
    String streamName,
    Stream<T> stream, {
    required void Function(T data) onData,
    required void Function(Object error, StackTrace stackTrace) onError,
    void Function()? onDone,
    bool isCritical = false,
  }) {
    // Cancel existing if exists
    cancelSubscription(streamName);

    if (isCritical) {
      registerCriticalStream(streamName);
    }

    final subscription = stream.listen(
      (data) {
        // Reset error count on successful data
        _errorCounts[streamName] = 0;
        onData(data);
      },
      onError: (Object error, StackTrace stackTrace) {
        _handleStreamError(streamName, error, stackTrace);

        // FAIL-FAST: Pass error directly without catching
        onError(error, stackTrace);
      },
      onDone: () {
        _cleanupSubscription(streamName);
        onDone?.call();
      },
    );

    _activeSubscriptions[streamName] = subscription;
    _subscriptionStartTimes[streamName] = DateTime.now();
    _errorCounts[streamName] = 0;
  }

  /// 🚨 HANDLE STREAM ERROR WITH FAIL-FAST LOGIC
  void _handleStreamError(
    String streamName,
    Object error,
    StackTrace stackTrace,
  ) {
    _errorCounts[streamName] = (_errorCounts[streamName] ?? 0) + 1;
    final errorCount = _errorCounts[streamName]!;

    // FAIL-FAST for critical streams
    if (_criticalStreams.contains(streamName) &&
        errorCount >= maxErrorsBeforeFail) {
      // Cancel all subscriptions and terminate app
      _emergencyShutdown(streamName, error, stackTrace);
      return;
    }

    // Regular streams - cancel after max errors
    if (errorCount >= maxErrorsBeforeFail) {
      cancelSubscription(streamName);
    }
  }

  /// 💥 EMERGENCY SHUTDOWN FOR CRITICAL STREAM FAILURES
  void _emergencyShutdown(
    String streamName,
    Object error,
    StackTrace stackTrace,
  ) {
    // Cancel all subscriptions immediately
    disposeAll();

    // Log critical failure

    // In production, this could trigger app restart or emergency mode
    // For now, we just clean up everything
    throw Exception('CRITICAL STREAM FAILURE: $streamName - $error');
  }

  /// ❌ CANCEL SPECIFIC SUBSCRIPTION
  void cancelSubscription(String streamName) {
    final subscription = _activeSubscriptions.remove(streamName);
    subscription?.cancel();

    _cleanupSubscription(streamName);

    if (kDebugMode && subscription != null) {}
  }

  /// 🧹 CLEANUP SUBSCRIPTION DATA
  void _cleanupSubscription(String streamName) {
    _subscriptionStartTimes.remove(streamName);
    _errorCounts.remove(streamName);
    _criticalStreams.remove(streamName);
  }

  /// 🔍 CHECK FOR STALE SUBSCRIPTIONS
  void checkForStaleSubscriptions() {
    final now = DateTime.now();
    final staleStreams = <String>[];

    for (final entry in _subscriptionStartTimes.entries) {
      if (now.difference(entry.value) > maxSubscriptionAge) {
        staleStreams.add(entry.key);
      }
    }

    for (final streamName in staleStreams) {
      cancelSubscription(streamName);
    }
  }

  /// 📊 GET SUBSCRIPTION STATUS
  Map<String, dynamic> getSubscriptionStatus() {
    final now = DateTime.now();

    return {
      'activeCount': _activeSubscriptions.length,
      'criticalCount': _criticalStreams.length,
      'totalErrors': _errorCounts.values.fold(0, (sum, count) => sum + count),
      'subscriptions': _activeSubscriptions.keys.map((name) {
        final startTime = _subscriptionStartTimes[name];
        final age =
            startTime != null ? now.difference(startTime) : Duration.zero;

        return {
          'name': name,
          'isCritical': _criticalStreams.contains(name),
          'errorCount': _errorCounts[name] ?? 0,
          'ageSeconds': age.inSeconds,
          'isStale': age > maxSubscriptionAge,
        };
      }).toList(),
    };
  }

  /// 🧹 DISPOSE ALL SUBSCRIPTIONS
  void disposeAll() {
    for (final subscription in _activeSubscriptions.values) {
      subscription.cancel();
    }

    _activeSubscriptions.clear();
    _subscriptionStartTimes.clear();
    _errorCounts.clear();
    _criticalStreams.clear();
  }

  /// 🔄 RESET ERROR COUNTS (called periodically)
  void resetErrorCounts() {
    final resetCount = _errorCounts.length;
    _errorCounts.clear();

    if (kDebugMode && resetCount > 0) {}
  }

  /// 📈 GET HEALTH METRICS
  bool get isHealthy {
    final totalErrors =
        _errorCounts.values.fold(0, (sum, count) => sum + count);
    final hasStaleSubscriptions = _subscriptionStartTimes.values.any(
      (startTime) => DateTime.now().difference(startTime) > maxSubscriptionAge,
    );

    return totalErrors < maxErrorsBeforeFail && !hasStaleSubscriptions;
  }

  /// 🎯 GET CRITICAL STREAMS STATUS
  bool get criticalStreamsHealthy {
    for (final streamName in _criticalStreams) {
      final errorCount = _errorCounts[streamName] ?? 0;
      if (errorCount >= maxErrorsBeforeFail) {
        return false;
      }
    }
    return true;
  }
}
