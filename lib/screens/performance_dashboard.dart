import 'package:flutter/material.dart';

import '../services/advanced_cache_manager.dart';
import '../services/memory_management_service.dart';
import '../services/performance_optimizer_service.dart';
import '../theme.dart';
import '../utils/widget_performance_mixin.dart';

/// 🚀 PERFORMANCE MONITORING DASHBOARD
/// Dashboard za praćenje performansi aplikacije
class PerformanceDashboard extends OptimizedStatefulWidget {
  const PerformanceDashboard({super.key});

  @override
  State<PerformanceDashboard> createState() => _PerformanceDashboardState();
}

class _PerformanceDashboardState extends OptimizedState<PerformanceDashboard> {
  Map<String, dynamic> _performanceMetrics = {};
  Map<String, dynamic> _memoryStats = {};
  Map<String, dynamic> _cacheStats = {};
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshMetrics();
  }

  Future<void> _refreshMetrics() async {
    if (_isRefreshing) return;

    optimizedSetState(() {
      _isRefreshing = true;
    });

    try {
      _performanceMetrics =
          PerformanceOptimizerService().getPerformanceMetrics();
      _memoryStats = MemoryManagementService().getMemoryStats();
      _cacheStats = AdvancedCacheManager().getStatistics();
    } catch (e) {
      // Handle error silently
    }

    optimizedSetState(() {
      _isRefreshing = false;
    });
  }

  @override
  Widget buildOptimized(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const ConstText('🚀 Performance Dashboard'),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshMetrics,
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).glassContainer,
            border: Border.all(
              color: Theme.of(context).glassBorder,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
      body: _isRefreshing && _performanceMetrics.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshMetrics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPerformanceSection(),
                    const SizedBox(height: 24),
                    _buildMemorySection(),
                    const SizedBox(height: 24),
                    _buildCacheSection(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPerformanceSection() {
    return _buildSection(
      title: '⚡ Performance Metrics',
      child: Column(
        children: [
          _buildMetricRow(
              'Operation Counts', _performanceMetrics['operation_counts']),
          _buildMetricRow('Operation Durations (ms)',
              _performanceMetrics['operation_durations']),
          _buildMetricRow(
              'Recent Operations', _performanceMetrics['recent_operations']),
          _buildMetricRow(
              'Active Batches', _performanceMetrics['active_batches']),
          _buildOptimalityIndicator(),
        ],
      ),
    );
  }

  Widget _buildMemorySection() {
    final isCritical = MemoryManagementService().isMemoryUsageCritical();

    return _buildSection(
      title: '💾 Memory Management',
      child: Column(
        children: [
          if (isCritical)
            const ConstPadding(
              padding: EdgeInsets.only(bottom: 8),
              child: Card(
                color: Colors.red,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: ConstText(
                    '🚨 Critical Memory Usage Detected!',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          _buildMetricRow(
              'Stream Controllers', _memoryStats['active_stream_controllers']),
          _buildMetricRow('Active Timers', _memoryStats['active_timers']),
          _buildMetricRow(
              'Active Subscriptions', _memoryStats['active_subscriptions']),
          _buildMetricRow('Total Resources', _memoryStats['total_resources']),
          _buildMetricRow(
              'Memory Warnings', _memoryStats['memory_warnings_count']),
          _buildMetricRow('Current RSS (MB)', _memoryStats['current_rss_mb']),
        ],
      ),
    );
  }

  Widget _buildCacheSection() {
    return _buildSection(
      title: '🗂️ Cache Statistics',
      child: Column(
        children: [
          _buildMetricRow('Memory Entries', _cacheStats['memory_entries']),
          _buildMetricRow(
              'Memory Usage %', _cacheStats['memory_usage_percent']),
          _buildMetricRow('Hit Rate %', _cacheStats['hit_rate_percent']),
          _buildMetricRow('Hit Count', _cacheStats['hit_count']),
          _buildMetricRow('Miss Count', _cacheStats['miss_count']),
          _buildMetricRow('Evictions', _cacheStats['eviction_count']),
          _buildCacheEfficiencyIndicator(),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Card(
      child: ConstPadding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstText(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, dynamic value) {
    String displayValue;

    if (value == null) {
      displayValue = 'N/A';
    } else if (value is List) {
      displayValue = 'Count: ${value.length}';
    } else if (value is Map) {
      displayValue = 'Items: ${value.length}';
    } else {
      displayValue = value.toString();
    }

    return ConstPadding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: ConstText(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          ConstText(
            displayValue,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimalityIndicator() {
    final isOptimal = PerformanceOptimizerService.isPerformanceOptimal();

    return ConstContainer(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isOptimal ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isOptimal ? Icons.check_circle : Icons.warning,
            color: isOptimal ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          ConstText(
            isOptimal ? 'Performance Optimal' : 'Performance Issues Detected',
            style: TextStyle(
              color: isOptimal ? Colors.green.shade800 : Colors.orange.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheEfficiencyIndicator() {
    final hitRateStr = _cacheStats['hit_rate_percent']?.toString() ?? '0';
    final hitRate = double.tryParse(hitRateStr) ?? 0;

    Color color;
    String status;
    IconData icon;

    if (hitRate >= 80) {
      color = Colors.green;
      status = 'Excellent';
      icon = Icons.trending_up;
    } else if (hitRate >= 60) {
      color = Colors.orange;
      status = 'Good';
      icon = Icons.trending_flat;
    } else {
      color = Colors.red;
      status = 'Poor';
      icon = Icons.trending_down;
    }

    return ConstContainer(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          ConstText(
            'Cache Efficiency: $status ($hitRate%)',
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        const ConstText(
          '🛠️ Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildActionButton(
              'Clear Cache',
              Icons.clear_all,
              () => _showConfirmDialog('Clear all cache?', () async {
                await AdvancedCacheManager().clear();
                _refreshMetrics();
              }),
            ),
            _buildActionButton(
              'Force GC',
              Icons.delete_sweep,
              () => _showConfirmDialog('Force garbage collection?', () {
                MemoryManagementService().forceCleanupAll();
                _refreshMetrics();
              }),
            ),
            _buildActionButton(
              'Reset Metrics',
              Icons.refresh,
              () => _showConfirmDialog('Reset performance metrics?', () {
                PerformanceOptimizerService().clearMetrics();
                _refreshMetrics();
              }),
            ),
            _buildActionButton(
              'View Warnings',
              Icons.warning,
              _showMemoryWarnings,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  void _showConfirmDialog(String message, VoidCallback onConfirm) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const ConstText('Confirm Action'),
        content: ConstText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const ConstText('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const ConstText('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showMemoryWarnings() {
    final warnings = MemoryManagementService().getMemoryWarnings();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const ConstText('Memory Warnings'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: warnings.isEmpty
              ? const Center(child: ConstText('No warnings'))
              : OptimizedListView(
                  itemCount: warnings.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.warning, color: Colors.orange),
                      title: ConstText(
                        warnings[index],
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const ConstText('Close'),
          ),
        ],
      ),
    );
  }
}
