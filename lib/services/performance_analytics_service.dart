import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

import 'advanced_caching_service.dart';

// Use centralized logger (no local alias)

/// 📊 PERFORMANCE ANALYTICS DASHBOARD - Enterprise Monitoring
/// Real-time metrics, A/B testing, user behavior tracking
/// 100% BESPLATNO - bolje od Google Analytics!
class PerformanceAnalyticsService {
  // 📊 METRICS COLLECTORS
  static final Map<String, PerformanceMetric> _metrics = {};
  static final Map<String, List<DataPoint>> _timeSeries = {};
  static final Map<String, UserBehaviorEvent> _userBehavior = {};
  static final Map<String, ABTestResult> _abTestResults = {};

  // ⚙️ ANALYTICS CONFIGURATION
  static const String _metricsPrefix = 'analytics_metrics_';
  static const Duration _flushInterval = Duration(minutes: 5);

  // 🎯 PERFORMANCE THRESHOLDS
  static const Map<String, double> _performanceThresholds = {
    'app_startup_time': 3.0, // seconds
    'geocoding_response_time': 2.0, // seconds
    'route_calculation_time': 5.0, // seconds
    'ui_render_time': 16.67, // milliseconds (60fps)
    'api_response_time': 1.5, // seconds
    'cache_hit_ratio': 0.8, // 80%
    'memory_usage': 100.0, // MB
    'crash_rate': 0.01, // 1%
  };

  /// 🚀 INITIALIZE ANALYTICS SYSTEM
  static Future<void> initialize() async {
    try {
      // Logger removed

      // Load persisted metrics
      await _loadPersistedMetrics();

      // Start background flushing
      _startBackgroundFlush();

      // Initialize standard metrics
      _initializeStandardMetrics();

      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }

  /// ⏱️ RECORD PERFORMANCE METRIC
  static void recordPerformanceMetric(
    String metricName,
    double value, {
    Map<String, dynamic>? metadata,
    bool isError = false,
  }) {
    try {
      final now = DateTime.now();

      // Update metric
      if (!_metrics.containsKey(metricName)) {
        _metrics[metricName] = PerformanceMetric(metricName);
      }

      _metrics[metricName]!.addValue(value, isError: isError, metadata: metadata);

      // Add to time series
      if (!_timeSeries.containsKey(metricName)) {
        _timeSeries[metricName] = <DataPoint>[];
      }

      _timeSeries[metricName]!.add(DataPoint(now, value, metadata));

      // Maintain time series size (keep last 1000 points)
      if (_timeSeries[metricName]!.length > 1000) {
        _timeSeries[metricName]!.removeAt(0);
      }

      // Check for performance alerts
      _checkPerformanceAlert(metricName, value);
    } catch (e) {
      // Logger removed
    }
  }

  /// 👤 TRACK USER BEHAVIOR EVENT
  static void trackUserBehavior(
    String eventName,
    String action, {
    Map<String, dynamic>? properties,
    String? userId,
    String? sessionId,
  }) {
    try {
      final eventId = '${eventName}_${DateTime.now().millisecondsSinceEpoch}';

      _userBehavior[eventId] = UserBehaviorEvent(
        eventName: eventName,
        action: action,
        timestamp: DateTime.now(),
        properties: properties ?? {},
        userId: userId,
        sessionId: sessionId,
      );

      // Maintain behavior events size
      if (_userBehavior.length > 5000) {
        final oldestKey = _userBehavior.keys.first;
        _userBehavior.remove(oldestKey);
      }
    } catch (e) {
      // Logger removed
    }
  }

  /// 🧪 A/B TEST METHODS
  static void recordABTestResult(
    String testName,
    String variant,
    String outcome,
    double value, {
    String? userId,
    Map<String, dynamic>? metadata,
  }) {
    try {
      final resultId = '${testName}_${variant}_${DateTime.now().millisecondsSinceEpoch}';

      _abTestResults[resultId] = ABTestResult(
        testName: testName,
        variant: variant,
        outcome: outcome,
        value: value,
        timestamp: DateTime.now(),
        userId: userId,
        metadata: metadata ?? {},
      );
    } catch (e) {
      // Logger removed
    }
  }

  static String getABTestVariant(String testName, String userId) {
    // Simple hash-based variant assignment
    final hash = userId.hashCode.abs();
    final variants = ['A', 'B', 'C']; // Up to 3 variants
    return variants[hash % variants.length];
  }

  /// 📊 GET PERFORMANCE DASHBOARD DATA
  static PerformanceDashboard getDashboardData() {
    final dashboard = PerformanceDashboard();

    try {
      // 📈 PERFORMANCE METRICS
      dashboard.metrics = _metrics.values.map((metric) => metric.toSummary()).toList();

      // ⚡ REAL-TIME STATUS
      dashboard.systemStatus = _generateSystemStatus();

      // 📊 CACHE PERFORMANCE
      final cacheStats = AdvancedCachingService.getStats();
      dashboard.cachePerformance = CachePerformanceSummary(
        hitRatio: cacheStats.hitRatio,
        totalRequests: cacheStats.totalRequests,
        avgResponseTime: cacheStats.avgResponseTimeMicros / 1000, // Convert to ms
        l1HitRatio:
            cacheStats.totalRequests > 0 ? (cacheStats.toJson()['l1_hits'] as num) / cacheStats.totalRequests : 0,
      );

      // 👥 USER BEHAVIOR ANALYTICS
      dashboard.userBehaviorSummary = _generateUserBehaviorSummary();

      // 🧪 A/B TEST RESULTS
      dashboard.abTestSummary = _generateABTestSummary();

      // 📈 PERFORMANCE TRENDS
      dashboard.performanceTrends = _generatePerformanceTrends();

      // 🚨 ALERTS AND RECOMMENDATIONS
      dashboard.alerts = _generateAlerts();
      dashboard.recommendations = _generateRecommendations();
    } catch (e) {
      // Logger removed
    }

    return dashboard;
  }

  /// 📊 GET SPECIFIC METRIC DETAILS
  static MetricDetails getMetricDetails(String metricName) {
    if (!_metrics.containsKey(metricName)) {
      return MetricDetails.empty(metricName);
    }

    final metric = _metrics[metricName]!;
    final timeSeries = _timeSeries[metricName] ?? [];

    return MetricDetails(
      name: metricName,
      summary: metric.toSummary(),
      timeSeries: timeSeries,
      histogram: _generateHistogram(timeSeries),
      percentiles: _calculatePercentiles(timeSeries),
      trend: _calculateTrend(timeSeries),
    );
  }

  /// 📈 EXPORT ANALYTICS DATA
  static Future<String> exportAnalyticsData({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? metricNames,
    String format = 'json',
  }) async {
    try {
      final exportData = <String, dynamic>{};

      // Filter data by date range
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 7));
      final end = endDate ?? DateTime.now();

      // Export metrics
      final metricsToExport = metricNames ?? _metrics.keys.toList();
      exportData['metrics'] = <String, dynamic>{};

      for (final metricName in metricsToExport) {
        if (_metrics.containsKey(metricName)) {
          final timeSeries = _timeSeries[metricName]
                  ?.where(
                    (point) => point.timestamp.isAfter(start) && point.timestamp.isBefore(end),
                  )
                  .toList() ??
              [];

          exportData['metrics'][metricName] = {
            'summary': _metrics[metricName]!.toSummary().toJson(),
            'data_points': timeSeries.map((point) => point.toJson()).toList(),
          };
        }
      }

      // Export user behavior
      final behaviorEvents = _userBehavior.values
          .where(
            (event) => event.timestamp.isAfter(start) && event.timestamp.isBefore(end),
          )
          .map((event) => event.toJson())
          .toList();
      exportData['user_behavior'] = behaviorEvents;

      // Export A/B test results
      final abTestEvents = _abTestResults.values
          .where(
            (result) => result.timestamp.isAfter(start) && result.timestamp.isBefore(end),
          )
          .map((result) => result.toJson())
          .toList();
      exportData['ab_tests'] = abTestEvents;

      // Add metadata
      exportData['metadata'] = {
        'export_timestamp': DateTime.now().toIso8601String(),
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String(),
        'total_metrics': metricsToExport.length,
        'total_behavior_events': behaviorEvents.length,
        'total_ab_test_results': abTestEvents.length,
      };

      return format == 'json' ? const JsonEncoder.withIndent('  ').convert(exportData) : _convertToCsv(exportData);
    } catch (e) {
      // Logger removed
      return '{"error": "Export failed: $e"}';
    }
  }

  // 🛠️ INTERNAL HELPER METHODS

  static void _initializeStandardMetrics() {
    // Initialize common performance metrics
    final standardMetrics = [
      'app_startup_time',
      'geocoding_response_time',
      'route_calculation_time',
      'ui_render_time',
      'api_response_time',
      'cache_hit_ratio',
      'memory_usage',
      'user_session_duration',
    ];

    for (final metricName in standardMetrics) {
      if (!_metrics.containsKey(metricName)) {
        _metrics[metricName] = PerformanceMetric(metricName);
      }
    }
  }

  static SystemStatus _generateSystemStatus() {
    // Calculate overall system health score
    double healthScore = 100.0;
    final issues = <String>[];

    _metrics.forEach((name, metric) {
      if (_performanceThresholds.containsKey(name)) {
        final threshold = _performanceThresholds[name]!;
        final currentAvg = metric.average;

        if (name == 'cache_hit_ratio') {
          if (currentAvg < threshold) {
            healthScore -= 10;
            issues.add(
              'Low cache hit ratio: ${(currentAvg * 100).toStringAsFixed(1)}%',
            );
          }
        } else {
          if (currentAvg > threshold) {
            healthScore -= 15;
            issues.add('High $name: ${currentAvg.toStringAsFixed(2)}');
          }
        }
      }
    });

    return SystemStatus(
      overallHealth: healthScore.clamp(0, 100),
      status: healthScore > 80
          ? 'Healthy'
          : healthScore > 60
              ? 'Warning'
              : 'Critical',
      issues: issues,
      lastUpdated: DateTime.now(),
    );
  }

  static UserBehaviorSummary _generateUserBehaviorSummary() {
    final events = _userBehavior.values.toList();
    final uniqueUsers = events.map((e) => e.userId).where((id) => id != null).toSet().length;

    // Count events by type
    final eventCounts = <String, int>{};
    for (final event in events) {
      eventCounts[event.eventName] = (eventCounts[event.eventName] ?? 0) + 1;
    }

    // Find most common user flows
    final userFlows = <String, int>{};
    // Simplified user flow tracking

    return UserBehaviorSummary(
      totalEvents: events.length,
      uniqueUsers: uniqueUsers,
      topEvents: eventCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
      commonUserFlows: userFlows.entries.take(5).toList(),
    );
  }

  static ABTestSummary _generateABTestSummary() {
    final results = _abTestResults.values.toList();
    final testsByName = <String, List<ABTestResult>>{};

    for (final result in results) {
      if (!testsByName.containsKey(result.testName)) {
        testsByName[result.testName] = [];
      }
      testsByName[result.testName]!.add(result);
    }

    final testSummaries = <ABTestSummaryItem>[];
    testsByName.forEach((testName, testResults) {
      final variantResults = <String, List<ABTestResult>>{};

      for (final result in testResults) {
        if (!variantResults.containsKey(result.variant)) {
          variantResults[result.variant] = [];
        }
        variantResults[result.variant]!.add(result);
      }

      final variantSummaries = <String, ABTestVariantSummary>{};
      variantResults.forEach((variant, results) {
        variantSummaries[variant] = ABTestVariantSummary(
          variant: variant,
          sampleSize: results.length,
          averageValue: results.map((r) => r.value).reduce((a, b) => a + b) / results.length,
          conversionRate: results.where((r) => r.outcome == 'success').length / results.length,
        );
      });

      testSummaries.add(
        ABTestSummaryItem(
          testName: testName,
          status: 'active',
          variants: variantSummaries,
          totalSampleSize: testResults.length,
        ),
      );
    });

    return ABTestSummary(
      activeTests: testSummaries.where((t) => t.status == 'active').length,
      totalTests: testSummaries.length,
      testSummaries: testSummaries,
    );
  }

  static List<PerformanceTrend> _generatePerformanceTrends() {
    final trends = <PerformanceTrend>[];

    _timeSeries.forEach((metricName, dataPoints) {
      if (dataPoints.length >= 10) {
        // Need at least 10 points for trend
        final trend = _calculateTrend(dataPoints);
        trends.add(
          PerformanceTrend(
            metricName: metricName,
            direction: trend > 0.1
                ? 'improving'
                : trend < -0.1
                    ? 'degrading'
                    : 'stable',
            changePercent: trend * 100,
            significance: trend.abs() > 0.2
                ? 'high'
                : trend.abs() > 0.1
                    ? 'medium'
                    : 'low',
          ),
        );
      }
    });

    return trends;
  }

  static List<PerformanceAlert> _generateAlerts() {
    final alerts = <PerformanceAlert>[];

    _metrics.forEach((name, metric) {
      if (_performanceThresholds.containsKey(name)) {
        final threshold = _performanceThresholds[name]!;
        final currentValue = metric.average;
        final isHigherBetter = name == 'cache_hit_ratio';

        if (isHigherBetter) {
          if (currentValue < threshold) {
            alerts.add(
              PerformanceAlert(
                type: 'warning',
                message:
                    'Low $name: ${(currentValue * 100).toStringAsFixed(1)}% (target: ${(threshold * 100).toStringAsFixed(1)}%)',
                severity: currentValue < threshold * 0.8 ? 'high' : 'medium',
                timestamp: DateTime.now(),
              ),
            );
          }
        } else {
          if (currentValue > threshold) {
            alerts.add(
              PerformanceAlert(
                type: 'warning',
                message: 'High $name: ${currentValue.toStringAsFixed(2)} (threshold: ${threshold.toStringAsFixed(2)})',
                severity: currentValue > threshold * 1.5 ? 'high' : 'medium',
                timestamp: DateTime.now(),
              ),
            );
          }
        }
      }
    });

    return alerts;
  }

  static List<String> _generateRecommendations() {
    final recommendations = <String>[];

    // Cache performance recommendations
    final cacheStats = AdvancedCachingService.getStats();
    if (cacheStats.hitRatio < 0.8) {
      recommendations.add(
        '🔄 Consider increasing cache size or adjusting TTL values to improve cache hit ratio',
      );
    }

    // Performance recommendations based on metrics
    _metrics.forEach((name, metric) {
      if (_performanceThresholds.containsKey(name)) {
        final threshold = _performanceThresholds[name]!;
        final currentValue = metric.average;

        if (name == 'geocoding_response_time' && currentValue > threshold) {
          recommendations.add(
            '🗺️ Optimize geocoding by enabling more caching or using batch requests',
          );
        }

        if (name == 'memory_usage' && currentValue > threshold) {
          recommendations.add(
            '🧠 Consider implementing more aggressive memory cleanup or reduce cache sizes',
          );
        }
      }
    });

    return recommendations;
  }

  static void _checkPerformanceAlert(String metricName, double value) {
    if (_performanceThresholds.containsKey(metricName)) {
      final threshold = _performanceThresholds[metricName]!;
      final isHigherBetter = metricName == 'cache_hit_ratio';

      bool isAlert = isHigherBetter ? value < threshold * 0.5 : value > threshold * 2;

      if (isAlert) {
        // In production, send to monitoring service
      }
    }
  }

  // Utility methods for calculations
  static double _calculateTrend(List<DataPoint> dataPoints) {
    if (dataPoints.length < 2) return 0.0;

    final firstHalf = dataPoints.take(dataPoints.length ~/ 2).map((p) => p.value).toList();
    final secondHalf = dataPoints.skip(dataPoints.length ~/ 2).map((p) => p.value).toList();

    final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

    return (secondAvg - firstAvg) / firstAvg;
  }

  static Map<String, int> _generateHistogram(List<DataPoint> dataPoints) {
    // Simple histogram generation
    final histogram = <String, int>{};
    if (dataPoints.isEmpty) return histogram;

    final values = dataPoints.map((p) => p.value).toList()..sort();
    final min = values.first;
    final max = values.last;
    const bucketCount = 10;
    final bucketSize = (max - min) / bucketCount;

    for (int i = 0; i < bucketCount; i++) {
      final bucketMin = min + i * bucketSize;
      final bucketMax = min + (i + 1) * bucketSize;
      final key = '${bucketMin.toStringAsFixed(1)}-${bucketMax.toStringAsFixed(1)}';

      histogram[key] = values.where((v) => v >= bucketMin && v < bucketMax).length;
    }

    return histogram;
  }

  static Map<String, double> _calculatePercentiles(List<DataPoint> dataPoints) {
    if (dataPoints.isEmpty) return {};

    final values = dataPoints.map((p) => p.value).toList()..sort();

    return {
      'p50': _percentile(values, 50),
      'p90': _percentile(values, 90),
      'p95': _percentile(values, 95),
      'p99': _percentile(values, 99),
    };
  }

  static double _percentile(List<double> sortedValues, int percentile) {
    if (sortedValues.isEmpty) return 0.0;

    final index = (percentile / 100.0) * (sortedValues.length - 1);
    if (index == index.floor()) {
      return sortedValues[index.toInt()];
    } else {
      final lower = sortedValues[index.floor()];
      final upper = sortedValues[index.ceil()];
      return lower + (upper - lower) * (index - index.floor());
    }
  }

  // Background processes
  static void _startBackgroundFlush() {
    Future.delayed(_flushInterval, () {
      _flushAnalyticsData();
      _startBackgroundFlush();
    });
  }

  static Future<void> _flushAnalyticsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Persist metrics
      for (final metric in _metrics.values) {
        await prefs.setString(
          '$_metricsPrefix${metric.name}',
          json.encode(metric.toJson()),
        );
      }

      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }

  static Future<void> _loadPersistedMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_metricsPrefix));

      for (final key in keys) {
        final metricJson = prefs.getString(key);
        if (metricJson != null) {
          try {
            final metricData = json.decode(metricJson);
            final metric = PerformanceMetric.fromJson(metricData as Map<String, dynamic>);
            _metrics[metric.name] = metric;
          } catch (e) {
            // Logger removed
          }
        }
      }
    } catch (e) {
      // Logger removed
    }
  }

  static String _convertToCsv(Map<String, dynamic> data) {
    // Simple CSV conversion for metrics
    final lines = <String>[];
    lines.add('metric_name,timestamp,value,metadata');

    final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
    metrics.forEach((metricName, metricData) {
      final dataPoints = metricData['data_points'] as List<dynamic>? ?? [];
      for (final point in dataPoints) {
        final metadata = point['metadata']?.toString().replaceAll(',', ';') ?? '';
        lines.add(
          '$metricName,${point['timestamp']},${point['value']},$metadata',
        );
      }
    });

    return lines.join('\n');
  }
}

// 📊 DATA CLASSES

class PerformanceMetric {
  PerformanceMetric(this.name);

  factory PerformanceMetric.fromJson(Map<String, dynamic> json) {
    final metric = PerformanceMetric(json['name'] as String);
    final values = (json['values'] as List<dynamic>).map((v) => (v as num).toDouble()).toList();
    final timestamps = (json['timestamps'] as List<dynamic>).map((t) => DateTime.parse(t as String)).toList();
    final metadata = (json['metadata'] as List<dynamic>).map((m) => Map<String, dynamic>.from(m as Map)).toList();

    for (int i = 0; i < values.length; i++) {
      metric._values.add(values[i]);
      metric._timestamps.add(timestamps[i]);
      metric._metadata.add(metadata[i]);
    }

    metric._errorCount = (json['error_count'] ?? 0) as int;
    return metric;
  }
  final String name;
  final List<double> _values = [];
  final List<DateTime> _timestamps = [];
  final List<Map<String, dynamic>> _metadata = [];
  int _errorCount = 0;

  void addValue(
    double value, {
    bool isError = false,
    Map<String, dynamic>? metadata,
  }) {
    _values.add(value);
    _timestamps.add(DateTime.now());
    _metadata.add(metadata ?? {});

    if (isError) _errorCount++;

    // Keep only last 1000 values
    if (_values.length > 1000) {
      _values.removeAt(0);
      _timestamps.removeAt(0);
      _metadata.removeAt(0);
    }
  }

  double get average => _values.isEmpty ? 0.0 : _values.reduce((a, b) => a + b) / _values.length;
  double get min => _values.isEmpty ? 0.0 : _values.reduce(math.min);
  double get max => _values.isEmpty ? 0.0 : _values.reduce(math.max);
  int get count => _values.length;
  int get errorCount => _errorCount;
  DateTime? get lastUpdated => _timestamps.isEmpty ? null : _timestamps.last;

  PerformanceMetricSummary toSummary() {
    return PerformanceMetricSummary(
      name: name,
      count: count,
      average: average,
      min: min,
      max: max,
      errorCount: errorCount,
      lastUpdated: lastUpdated,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'values': _values,
        'timestamps': _timestamps.map((t) => t.toIso8601String()).toList(),
        'metadata': _metadata,
        'error_count': _errorCount,
      };
}

class DataPoint {
  DataPoint(this.timestamp, this.value, this.metadata);
  final DateTime timestamp;
  final double value;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'value': value,
        'metadata': metadata,
      };
}

class UserBehaviorEvent {
  UserBehaviorEvent({
    required this.eventName,
    required this.action,
    required this.timestamp,
    required this.properties,
    this.userId,
    this.sessionId,
  });
  final String eventName;
  final String action;
  final DateTime timestamp;
  final Map<String, dynamic> properties;
  final String? userId;
  final String? sessionId;

  Map<String, dynamic> toJson() => {
        'event_name': eventName,
        'action': action,
        'timestamp': timestamp.toIso8601String(),
        'properties': properties,
        'user_id': userId,
        'session_id': sessionId,
      };
}

class ABTestResult {
  ABTestResult({
    required this.testName,
    required this.variant,
    required this.outcome,
    required this.value,
    required this.timestamp,
    this.userId,
    required this.metadata,
  });
  final String testName;
  final String variant;
  final String outcome;
  final double value;
  final DateTime timestamp;
  final String? userId;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'test_name': testName,
        'variant': variant,
        'outcome': outcome,
        'value': value,
        'timestamp': timestamp.toIso8601String(),
        'user_id': userId,
        'metadata': metadata,
      };
}

// Dashboard data structures
class PerformanceDashboard {
  List<PerformanceMetricSummary> metrics = [];
  SystemStatus? systemStatus;
  CachePerformanceSummary? cachePerformance;
  UserBehaviorSummary? userBehaviorSummary;
  ABTestSummary? abTestSummary;
  List<PerformanceTrend> performanceTrends = [];
  List<PerformanceAlert> alerts = [];
  List<String> recommendations = [];
}

class PerformanceMetricSummary {
  PerformanceMetricSummary({
    required this.name,
    required this.count,
    required this.average,
    required this.min,
    required this.max,
    required this.errorCount,
    this.lastUpdated,
  });
  final String name;
  final int count;
  final double average;
  final double min;
  final double max;
  final int errorCount;
  final DateTime? lastUpdated;

  Map<String, dynamic> toJson() => {
        'name': name,
        'count': count,
        'average': average,
        'min': min,
        'max': max,
        'error_count': errorCount,
        'last_updated': lastUpdated?.toIso8601String(),
      };
}

class SystemStatus {
  SystemStatus({
    required this.overallHealth,
    required this.status,
    required this.issues,
    required this.lastUpdated,
  });
  final double overallHealth;
  final String status;
  final List<String> issues;
  final DateTime lastUpdated;
}

class CachePerformanceSummary {
  CachePerformanceSummary({
    required this.hitRatio,
    required this.totalRequests,
    required this.avgResponseTime,
    required this.l1HitRatio,
  });
  final double hitRatio;
  final int totalRequests;
  final double avgResponseTime;
  final double l1HitRatio;
}

class UserBehaviorSummary {
  UserBehaviorSummary({
    required this.totalEvents,
    required this.uniqueUsers,
    required this.topEvents,
    required this.commonUserFlows,
  });
  final int totalEvents;
  final int uniqueUsers;
  final List<MapEntry<String, int>> topEvents;
  final List<MapEntry<String, int>> commonUserFlows;
}

class ABTestSummary {
  ABTestSummary({
    required this.activeTests,
    required this.totalTests,
    required this.testSummaries,
  });
  final int activeTests;
  final int totalTests;
  final List<ABTestSummaryItem> testSummaries;
}

class ABTestSummaryItem {
  ABTestSummaryItem({
    required this.testName,
    required this.status,
    required this.variants,
    required this.totalSampleSize,
  });
  final String testName;
  final String status;
  final Map<String, ABTestVariantSummary> variants;
  final int totalSampleSize;
}

class ABTestVariantSummary {
  ABTestVariantSummary({
    required this.variant,
    required this.sampleSize,
    required this.averageValue,
    required this.conversionRate,
  });
  final String variant;
  final int sampleSize;
  final double averageValue;
  final double conversionRate;
}

class PerformanceTrend {
  // high, medium, low

  PerformanceTrend({
    required this.metricName,
    required this.direction,
    required this.changePercent,
    required this.significance,
  });
  final String metricName;
  final String direction; // improving, degrading, stable
  final double changePercent;
  final String significance;
}

class PerformanceAlert {
  PerformanceAlert({
    required this.type,
    required this.message,
    required this.severity,
    required this.timestamp,
  });
  final String type;
  final String message;
  final String severity;
  final DateTime timestamp;
}

class MetricDetails {
  MetricDetails({
    required this.name,
    required this.summary,
    required this.timeSeries,
    required this.histogram,
    required this.percentiles,
    required this.trend,
  });

  factory MetricDetails.empty(String name) {
    return MetricDetails(
      name: name,
      summary: PerformanceMetricSummary(
        name: name,
        count: 0,
        average: 0,
        min: 0,
        max: 0,
        errorCount: 0,
      ),
      timeSeries: [],
      histogram: {},
      percentiles: {},
      trend: 0,
    );
  }
  final String name;
  final PerformanceMetricSummary summary;
  final List<DataPoint> timeSeries;
  final Map<String, int> histogram;
  final Map<String, double> percentiles;
  final double trend;
}
