import 'dart:async';

import '../globals.dart';
import 'performance_optimizer_service.dart';

/// 🚀 BATCH DATABASE SERVICE
/// Optimizovani servis za batch database operacije
class BatchDatabaseService {
  factory BatchDatabaseService() => _instance;
  BatchDatabaseService._internal();
  static final BatchDatabaseService _instance =
      BatchDatabaseService._internal();

  // 🔄 BATCH OPERATION QUEUES
  final Map<String, List<Map<String, dynamic>>> _insertBatches = {};
  final Map<String, List<Map<String, dynamic>>> _updateBatches = {};
  final Map<String, Timer> _batchTimers = {};

  // ⚡ OPTIMIZACIJA KONSTANTE
  static const Duration _batchDelay = Duration(milliseconds: 200);
  static const int _maxBatchSize = 100;

  /// 🔄 Add INSERT operation to batch
  void addInsertToBatch(String tableName, Map<String, dynamic> data) {
    _insertBatches.putIfAbsent(tableName, () => <Map<String, dynamic>>[]);
    _insertBatches[tableName]!.add(data);

    _scheduleBatchExecution(tableName, 'insert');

    // Execute immediately if batch is full
    if (_insertBatches[tableName]!.length >= _maxBatchSize) {
      _executeBatch(tableName, 'insert');
    }
  }

  /// 🔄 Add UPDATE operation to batch
  void addUpdateToBatch(String tableName, Map<String, dynamic> data) {
    _updateBatches.putIfAbsent(tableName, () => <Map<String, dynamic>>[]);
    _updateBatches[tableName]!.add(data);

    _scheduleBatchExecution(tableName, 'update');

    // Execute immediately if batch is full
    if (_updateBatches[tableName]!.length >= _maxBatchSize) {
      _executeBatch(tableName, 'update');
    }
  }

  /// ⏰ Schedule batch execution
  void _scheduleBatchExecution(String tableName, String operation) {
    final timerKey = '${tableName}_$operation';

    _batchTimers[timerKey]?.cancel();
    _batchTimers[timerKey] = Timer(_batchDelay, () {
      _executeBatch(tableName, operation);
    });
  }

  /// ⚡ Execute batched operations
  Future<void> _executeBatch(String tableName, String operation) async {
    final stopwatch = Stopwatch()..start();

    try {
      List<Map<String, dynamic>>? batch;

      if (operation == 'insert') {
        batch = _insertBatches[tableName];
        _insertBatches[tableName]?.clear();
      } else if (operation == 'update') {
        batch = _updateBatches[tableName];
        _updateBatches[tableName]?.clear();
      }

      if (batch == null || batch.isEmpty) return;

      if (operation == 'insert') {
        await _executeBatchInsert(tableName, batch);
      } else if (operation == 'update') {
        await _executeBatchUpdate(tableName, batch);
      }
    } catch (e) {
      // Log error but don't throw to prevent breaking the app
    } finally {
      stopwatch.stop();
      final batchToProcess = operation == 'insert'
          ? _insertBatches[tableName]
          : _updateBatches[tableName];
      PerformanceOptimizerService().trackOperation(
        'batch_${operation}_${tableName}_${batchToProcess?.length ?? 0}',
        stopwatch.elapsed,
      );

      // Clean up timer
      _batchTimers.remove('${tableName}_$operation');
    }
  }

  /// 📥 Execute batch INSERT
  Future<void> _executeBatchInsert(
      String tableName, List<Map<String, dynamic>> batch) async {
    if (batch.isEmpty) return;

    try {
      // Supabase supports batch inserts natively
      await supabase.from(tableName).insert(batch);
    } catch (e) {
      // If batch fails, try individual inserts
      for (final item in batch) {
        try {
          await supabase.from(tableName).insert(item);
        } catch (individualError) {
          // Log individual errors but continue
        }
      }
    }
  }

  /// 📝 Execute batch UPDATE (more complex - needs individual handling)
  Future<void> _executeBatchUpdate(
      String tableName, List<Map<String, dynamic>> batch) async {
    if (batch.isEmpty) return;

    // Group updates by primary key for efficiency
    final Map<String, Map<String, dynamic>> groupedUpdates = {};

    for (final item in batch) {
      final id = item['id']?.toString();
      if (id != null) {
        groupedUpdates[id] = item;
      }
    }

    // Execute grouped updates
    for (final entry in groupedUpdates.entries) {
      try {
        await supabase.from(tableName).update(entry.value).eq('id', entry.key);
      } catch (e) {
        // Log error but continue with other updates
      }
    }
  }

  /// 🚀 Optimized SELECT with specific columns
  Future<List<Map<String, dynamic>>> selectOptimized(
    String tableName, {
    List<String>? columns,
    String? where,
    dynamic whereValue,
    int? limit,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      dynamic queryBuilder = supabase.from(tableName);

      // Select specific columns only
      if (columns != null && columns.isNotEmpty) {
        queryBuilder = queryBuilder.select(columns.join(', '));
      } else {
        queryBuilder = queryBuilder.select();
      }

      // Add WHERE condition if specified
      if (where != null && whereValue != null) {
        queryBuilder = queryBuilder.eq(where, whereValue);
      }

      // Add LIMIT if specified
      if (limit != null) {
        queryBuilder = queryBuilder.limit(limit);
      }

      final response = await queryBuilder;
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      return [];
    } finally {
      stopwatch.stop();
      PerformanceOptimizerService().trackOperation(
        'select_optimized_$tableName',
        stopwatch.elapsed,
      );
    }
  }

  /// 📊 Get batch statistics
  Map<String, dynamic> getBatchStatistics() {
    final stats = <String, dynamic>{};

    for (final entry in _insertBatches.entries) {
      stats['${entry.key}_insert_pending'] = entry.value.length;
    }

    for (final entry in _updateBatches.entries) {
      stats['${entry.key}_update_pending'] = entry.value.length;
    }

    stats['active_timers'] = _batchTimers.length;

    return stats;
  }

  /// 🚫 Force execute all pending batches
  Future<void> flushAllBatches() async {
    final futures = <Future<void>>[];

    // Execute all pending insert batches
    for (final entry in _insertBatches.entries) {
      if (entry.value.isNotEmpty) {
        futures.add(_executeBatch(entry.key, 'insert'));
      }
    }

    // Execute all pending update batches
    for (final entry in _updateBatches.entries) {
      if (entry.value.isNotEmpty) {
        futures.add(_executeBatch(entry.key, 'update'));
      }
    }

    await Future.wait(futures);
  }

  /// 🧹 Clean up resources
  void dispose() {
    // Cancel all timers
    for (final timer in _batchTimers.values) {
      timer.cancel();
    }
    _batchTimers.clear();

    // Clear all batches
    _insertBatches.clear();
    _updateBatches.clear();
  }
}

/// 🚀 BATCH DATABASE MIXIN
/// Dodaj ovaj mixin u servise za automatsko batch processing
mixin BatchDatabaseMixin {
  BatchDatabaseService get _batchService => BatchDatabaseService();

  /// Insert with automatic batching
  void batchInsert(String tableName, Map<String, dynamic> data) {
    _batchService.addInsertToBatch(tableName, data);
  }

  /// Update with automatic batching
  void batchUpdate(String tableName, Map<String, dynamic> data) {
    _batchService.addUpdateToBatch(tableName, data);
  }

  /// Optimized select with performance tracking
  Future<List<Map<String, dynamic>>> selectOptimized(
    String tableName, {
    List<String>? columns,
    String? where,
    dynamic whereValue,
    int? limit,
  }) {
    return _batchService.selectOptimized(
      tableName,
      columns: columns,
      where: where,
      whereValue: whereValue,
      limit: limit,
    );
  }
}
