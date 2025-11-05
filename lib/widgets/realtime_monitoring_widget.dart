import 'dart:async';

import 'package:flutter/material.dart';

import '../services/memory_management_service.dart';
import '../services/optimized_kusur_service.dart';
import '../services/optimized_realtime_service.dart';
import '../utils/widget_performance_mixin.dart';

/// 🚀 REALTIME MONITORING WIDGET
/// Monitor realtime service health and performance
class RealtimeMonitoringWidget extends OptimizedStatefulWidget {
  const RealtimeMonitoringWidget({super.key});

  @override
  State<RealtimeMonitoringWidget> createState() => _RealtimeMonitoringWidgetState();
}

class _RealtimeMonitoringWidgetState extends OptimizedState<RealtimeMonitoringWidget> {
  Map<String, dynamic> _realtimeStats = {};
  Map<String, dynamic> _kusurStats = {};
  Map<String, dynamic> _memoryStats = {};
  Timer? _refreshTimer;
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  @override
  void dispose() {
    _stopMonitoring();
    super.dispose();
  }

  void _startMonitoring() {
    optimizedSetState(() {
      _isMonitoring = true;
    });

    _refreshStats();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshStats();
    });
  }

  void _stopMonitoring() {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    if (mounted) {
      optimizedSetState(() {
        _isMonitoring = false;
      });
    }
  }

  void _refreshStats() {
    if (!mounted) return;

    try {
      final realtimeService = OptimizedRealtimeService();
      final kusurService = OptimizedKusurService.instance;
      final memoryService = MemoryManagementService();

      optimizedSetState(() {
        _realtimeStats = realtimeService.getStatistics();
        _kusurStats = kusurService.getStatistics();
        _memoryStats = memoryService.getMemoryStats();
      });
    } catch (e) {
      // Handle errors silently
    }
  }

  @override
  Widget buildOptimized(BuildContext context) {
    return Card(
      elevation: 8,
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (_isMonitoring) ...[
            _buildRealtimeSection(),
            _buildKusurSection(),
            _buildMemorySection(),
          ] else
            _buildStoppedIndicator(),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isMonitoring ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Icon(
            _isMonitoring ? Icons.monitor_heart : Icons.monitor,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ConstText(
              _isMonitoring ? '🔄 Realtime Monitoring (Live)' : '⏸️ Monitoring Paused',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_isMonitoring)
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRealtimeSection() {
    final isHealthy = _realtimeStats['initialized'] == true;

    return _buildSection(
      title: '🌊 Realtime Service',
      healthStatus: isHealthy ? 'Healthy' : 'Issues',
      healthColor: isHealthy ? Colors.green : Colors.red,
      child: Column(
        children: [
          _buildStatRow('Initialized', _realtimeStats['initialized']?.toString() ?? 'false'),
          _buildStatRow('Active Subscriptions', _realtimeStats['active_subscriptions']?.toString() ?? '0'),
          _buildStatRow('Last Activity', _formatTime(_realtimeStats['last_activity'] as String?)),
          _buildEventCounts(_realtimeStats['event_counts'] as Map<String, int>?),
        ],
      ),
    );
  }

  Widget _buildKusurSection() {
    final isHealthy = _kusurStats['initialized'] == true && _kusurStats['controller_closed'] != true;

    return _buildSection(
      title: '💰 Kusur Service',
      healthStatus: isHealthy ? 'Healthy' : 'Issues',
      healthColor: isHealthy ? Colors.green : Colors.orange,
      child: Column(
        children: [
          _buildStatRow('Initialized', _kusurStats['initialized']?.toString() ?? 'false'),
          _buildStatRow('Controller Status', _kusurStats['controller_closed'] == true ? 'Closed' : 'Open'),
          _buildStatRow('Has Listeners', _kusurStats['has_listeners']?.toString() ?? 'false'),
        ],
      ),
    );
  }

  Widget _buildMemorySection() {
    final totalResources = _memoryStats['total_resources'] as int? ?? 0;
    final isCritical = totalResources > 50;

    return _buildSection(
      title: '💾 Memory Management',
      healthStatus: isCritical ? 'Critical' : 'Normal',
      healthColor: isCritical ? Colors.red : Colors.green,
      child: Column(
        children: [
          _buildStatRow('Stream Controllers', _memoryStats['active_stream_controllers']?.toString() ?? '0'),
          _buildStatRow('Active Timers', _memoryStats['active_timers']?.toString() ?? '0'),
          _buildStatRow('Subscriptions', _memoryStats['active_subscriptions']?.toString() ?? '0'),
          _buildStatRow('Total Resources', totalResources.toString()),
          _buildStatRow('Memory (MB)', _memoryStats['current_rss_mb']?.toString() ?? 'N/A'),
          _buildStatRow('Warnings', _memoryStats['memory_warnings_count']?.toString() ?? '0'),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String healthStatus,
    required Color healthColor,
    required Widget child,
  }) {
    return ConstContainer(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ConstText(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: healthColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: healthColor),
                ),
                child: ConstText(
                  healthStatus,
                  style: TextStyle(
                    color: healthColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return ConstPadding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: ConstText(
              label,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          ConstText(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCounts(Map<String, int>? events) {
    if (events == null || events.isEmpty) {
      return _buildStatRow('Event Counts', 'No events');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ConstText(
          'Recent Events:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        ...events.entries.take(5).map(
              (entry) => _buildStatRow('  ${entry.key}', entry.value.toString()),
            ),
      ],
    );
  }

  Widget _buildStoppedIndicator() {
    return ConstContainer(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.pause_circle_outline, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            ConstText(
              'Monitoring Stopped',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            ConstText(
              'Click Start to begin monitoring',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return ConstPadding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
              icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
              label: ConstText(_isMonitoring ? 'Stop' : 'Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isMonitoring ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _refreshStats,
            icon: const Icon(Icons.refresh),
            label: const ConstText('Refresh'),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'Never';

    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return '${difference.inSeconds}s ago';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else {
        return '${difference.inHours}h ago';
      }
    } catch (e) {
      return 'Invalid';
    }
  }
}
