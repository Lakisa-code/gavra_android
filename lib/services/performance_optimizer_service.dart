import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

/// 🚀 PERFORMANCE OPTIMIZER SERVICE
/// Centralizovani servis za optimizaciju performansi aplikacije
class PerformanceOptimizerService {
  factory PerformanceOptimizerService() => _instance;
  PerformanceOptimizerService._internal();
  static final PerformanceOptimizerService _instance =
      PerformanceOptimizerService._internal();

  // 📊 PERFORMANCE METRICS
  final Map<String, int> _operationCounts = {};
  final Map<String, Duration> _operationDurations = {};
  final Queue<String> _recentOperations = Queue<String>();

  // 🔄 BATCH OPERATIONS QUEUE
  final Map<String, List<Function>> _batchOperations = {};
  final Map<String, Timer> _batchTimers = {};

  // ⚡ OPTIMIZACIJA KONSTANTE
  static const int _maxRecentOperations = 100;
  static const Duration _batchDelay = Duration(milliseconds: 100);

  /// 📈 Track operation performance
  void trackOperation(String operationName, Duration duration) {
    _operationCounts[operationName] =
        (_operationCounts[operationName] ?? 0) + 1;
    _operationDurations[operationName] = duration;

    _recentOperations.add('$operationName: ${duration.inMilliseconds}ms');
    if (_recentOperations.length > _maxRecentOperations) {
      _recentOperations.removeFirst();
    }
  }

  /// 🔄 Add operation to batch queue
  void addToBatch(String batchKey, Function operation) {
    _batchOperations.putIfAbsent(batchKey, () => <Function>[]);
    _batchOperations[batchKey]!.add(operation);

    // Cancel existing timer and create new one
    _batchTimers[batchKey]?.cancel();
    _batchTimers[batchKey] = Timer(_batchDelay, () => _executeBatch(batchKey));
  }

  /// ⚡ Execute batched operations
  void _executeBatch(String batchKey) {
    final operations = _batchOperations[batchKey];
    if (operations == null || operations.isEmpty) return;

    final stopwatch = Stopwatch()..start();

    try {
      for (final operation in operations) {
        operation();
      }
    } catch (e) {
      // Log error but continue
    } finally {
      stopwatch.stop();
      trackOperation('batch_$batchKey', stopwatch.elapsed);

      // Clear batch
      _batchOperations[batchKey]?.clear();
      _batchTimers[batchKey]?.cancel();
      _batchTimers.remove(batchKey);
    }
  }

  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'operation_counts': Map<String, int>.from(_operationCounts),
      'operation_durations': _operationDurations.map(
        (key, value) => MapEntry(key, value.inMilliseconds),
      ),
      'recent_operations': List<String>.from(_recentOperations),
      'active_batches': _batchOperations.keys.toList(),
    };
  }

  /// 🧹 Clear metrics
  void clearMetrics() {
    _operationCounts.clear();
    _operationDurations.clear();
    _recentOperations.clear();
  }

  /// 🚫 Dispose all resources
  void dispose() {
    for (final timer in _batchTimers.values) {
      timer.cancel();
    }
    _batchTimers.clear();
    _batchOperations.clear();
    clearMetrics();
  }

  /// ⚡ Optimized database query batching
  static void batchDatabaseOperation(String operation, Function dbCall) {
    _instance.addToBatch('database_operations', dbCall);
  }

  /// 🔄 Optimized UI update batching
  static void batchUIUpdate(String component, Function uiUpdate) {
    _instance.addToBatch('ui_updates_$component', uiUpdate);
  }

  /// 📊 Quick performance check
  static bool isPerformanceOptimal() {
    final metrics = _instance.getPerformanceMetrics();
    final operationCounts = metrics['operation_counts'] as Map<String, int>;

    // Check if any operation is called too frequently
    for (final entry in operationCounts.entries) {
      if (entry.value > 1000) {
        // Više od 1000 poziva
        return false;
      }
    }

    return true;
  }
}

/// 🚀 PERFORMANCE MONITOR MIXIN
/// Dodaj ovaj mixin u State klase za automatsko praćenje performansi
mixin PerformanceMixin<T extends StatefulWidget> on State<T> {
  late Stopwatch _buildStopwatch;
  late String _widgetName;

  @override
  void initState() {
    super.initState();
    _widgetName = T.toString();
    _buildStopwatch = Stopwatch();
  }

  @override
  Widget build(BuildContext context) {
    _buildStopwatch.reset();
    _buildStopwatch.start();

    final widget = buildOptimized(context);

    _buildStopwatch.stop();
    PerformanceOptimizerService().trackOperation(
      'build_$_widgetName',
      _buildStopwatch.elapsed,
    );

    return widget;
  }

  /// Override this instead of build()
  Widget buildOptimized(BuildContext context);

  @override
  void dispose() {
    _buildStopwatch.stop();
    super.dispose();
  }
}
