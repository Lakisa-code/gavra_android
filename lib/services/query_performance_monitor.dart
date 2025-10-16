import '../utils/logging.dart';

/// 📊 QUERY PERFORMANCE MONITOR
/// Prati performance database query-jeva u realnom vremenu
class QueryPerformanceMonitor {
  static final Map<String, QueryStats> _stats = {};
  static const int slowQueryThreshold = 1000; // 1 second
  static bool _isEnabled = true;

  /// Prati izvršavanje query-ja i meri performance
  static Future<T> trackQuery<T>(
    String queryName,
    Future<T> Function() query, {
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isEnabled) return await query();

    final stopwatch = Stopwatch()..start();

    try {
      final result = await query();
      final duration = stopwatch.elapsedMilliseconds;

      _recordSuccess(queryName, duration, metadata);

      if (duration > slowQueryThreshold) {
        _alertSlowQuery(queryName, duration, metadata);
      }

      return result;
    } catch (e) {
      final duration = stopwatch.elapsedMilliseconds;
      _recordError(queryName, duration, e, metadata);
      rethrow;
    }
  }

  /// Beleži uspešan query
  static void _recordSuccess(String queryName, int duration, Map<String, dynamic>? metadata) {
    final stats = _stats.putIfAbsent(queryName, () => QueryStats(queryName));
    stats.addSuccess(duration);

    dlog('📊 [QUERY MONITOR] $queryName: ${duration}ms ${metadata != null ? metadata.toString() : ''}');
  }

  /// Beleži query sa greškom
  static void _recordError(String queryName, int duration, dynamic error, Map<String, dynamic>? metadata) {
    final stats = _stats.putIfAbsent(queryName, () => QueryStats(queryName));
    stats.addError(duration, error);

    dlog('❌ [QUERY MONITOR] $queryName ERROR (${duration}ms): $error');
  }

  /// Upozorava na spore query-jeve
  static void _alertSlowQuery(String queryName, int duration, Map<String, dynamic>? metadata) {
    dlog('🐌 [SLOW QUERY ALERT] $queryName: ${duration}ms (threshold: ${slowQueryThreshold}ms)');

    // Možda dodati notifikaciju ili log u Supabase
    final stats = _stats[queryName];
    if (stats != null && stats.averageDuration > slowQueryThreshold) {
      dlog('⚠️ [PATTERN ALERT] $queryName consistently slow: ${stats.averageDuration.toInt()}ms avg');
    }
  }

  /// Dobija statistike za sve query-jeve
  static Map<String, QueryStats> getAllStats() {
    return Map.unmodifiable(_stats);
  }

  /// Dobija statistike za specifičan query
  static QueryStats? getQueryStats(String queryName) {
    return _stats[queryName];
  }

  /// Reset statistike
  static void resetStats() {
    _stats.clear();
    dlog('🧹 [QUERY MONITOR] Stats reset');
  }

  /// Dobija top 10 najsporijih query-jeva
  static List<QueryStats> getTopSlowQueries({int limit = 10}) {
    final allStats = _stats.values.toList();
    allStats.sort((a, b) => b.averageDuration.compareTo(a.averageDuration));
    return allStats.take(limit).toList();
  }

  /// Dobija query-jeve sa visokim error rate-om
  static List<QueryStats> getHighErrorQueries({double errorThreshold = 0.1}) {
    return _stats.values.where((stats) => stats.errorRate > errorThreshold).toList();
  }

  /// Generiše performance report
  static String generatePerformanceReport() {
    final buffer = StringBuffer();
    buffer.writeln('📊 DATABASE PERFORMANCE REPORT');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln();

    // Top slow queries
    final slowQueries = getTopSlowQueries(limit: 5);
    if (slowQueries.isNotEmpty) {
      buffer.writeln('🐌 TOP 5 SLOWEST QUERIES:');
      for (int i = 0; i < slowQueries.length; i++) {
        final stats = slowQueries[i];
        buffer.writeln(
          '  ${i + 1}. ${stats.queryName}: ${stats.averageDuration.toInt()}ms avg (${stats.totalCalls} calls)',
        );
      }
      buffer.writeln();
    }

    // High error queries
    final errorQueries = getHighErrorQueries();
    if (errorQueries.isNotEmpty) {
      buffer.writeln('❌ QUERIES WITH HIGH ERROR RATE:');
      for (final stats in errorQueries) {
        buffer.writeln('  • ${stats.queryName}: ${(stats.errorRate * 100).toStringAsFixed(1)}% errors');
      }
      buffer.writeln();
    }

    // Overall stats
    final totalQueries = _stats.values.fold<int>(0, (sum, stats) => sum + stats.totalCalls);
    final totalErrors = _stats.values.fold<int>(0, (sum, stats) => sum + stats.errorCount);
    final avgDuration = _stats.values.isEmpty
        ? 0.0
        : _stats.values.fold<double>(0, (sum, stats) => sum + stats.averageDuration) / _stats.values.length;

    buffer.writeln('📈 OVERALL STATISTICS:');
    buffer.writeln('  • Total queries tracked: $totalQueries');
    buffer.writeln('  • Total errors: $totalErrors');
    buffer.writeln('  • Average duration: ${avgDuration.toInt()}ms');
    buffer.writeln('  • Error rate: ${totalQueries > 0 ? (totalErrors / totalQueries * 100).toStringAsFixed(1) : 0}%');

    return buffer.toString();
  }

  /// Enable/disable monitoring
  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
    dlog('📊 [QUERY MONITOR] ${enabled ? 'Enabled' : 'Disabled'}');
  }
}

/// 📊 Query statistike za jedan query tip
class QueryStats {
  QueryStats(this.queryName);

  final String queryName;
  int totalCalls = 0;
  int errorCount = 0;
  double totalDuration = 0;
  double minDuration = double.infinity;
  double maxDuration = 0;
  final List<String> recentErrors = [];
  DateTime? lastCall;

  void addSuccess(int duration) {
    totalCalls++;
    totalDuration += duration;
    minDuration = duration < minDuration ? duration.toDouble() : minDuration;
    maxDuration = duration > maxDuration ? duration.toDouble() : maxDuration;
    lastCall = DateTime.now();
  }

  void addError(int duration, dynamic error) {
    totalCalls++;
    errorCount++;
    totalDuration += duration;

    // Keep only last 5 errors
    final errorMsg = error.toString();
    recentErrors.add(errorMsg);
    if (recentErrors.length > 5) {
      recentErrors.removeAt(0);
    }

    lastCall = DateTime.now();
  }

  double get averageDuration => totalCalls > 0 ? totalDuration / totalCalls : 0;
  double get errorRate => totalCalls > 0 ? errorCount / totalCalls : 0;
  int get successCount => totalCalls - errorCount;

  Map<String, dynamic> toJson() {
    return {
      'queryName': queryName,
      'totalCalls': totalCalls,
      'successCount': successCount,
      'errorCount': errorCount,
      'errorRate': errorRate,
      'averageDuration': averageDuration,
      'minDuration': minDuration == double.infinity ? 0 : minDuration,
      'maxDuration': maxDuration,
      'lastCall': lastCall?.toIso8601String(),
      'recentErrors': recentErrors,
    };
  }
}
