import 'package:flutter/material.dart';

import '../services/realtime_network_status_service.dart';

/// 🚥 NETWORK STATUS INDICATOR WIDGET
/// Prikazuje realtime network status kao colored dot

class NetworkStatusIndicator extends StatelessWidget {
  const NetworkStatusIndicator({
    Key? key,
    this.showLabel = false,
    this.size = 12.0,
  }) : super(key: key);
  final bool showLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NetworkStatus>(
      valueListenable: RealtimeNetworkStatusService.instance.networkStatus,
      builder: (context, status, child) {
        return GestureDetector(
          onTap: () => _showNetworkStatusDialog(context, status),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor(status).withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (showLabel) ...[
                  const SizedBox(width: 4),
                  Text(
                    _getStatusLabel(status),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 🎨 GET STATUS COLOR
  Color _getStatusColor(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.excellent:
        return Colors.green.shade600;
      case NetworkStatus.good:
        return Colors.yellow.shade600;
      case NetworkStatus.poor:
        return Colors.orange.shade600;
      case NetworkStatus.offline:
        return Colors.red.shade600;
    }
  }

  /// 📝 GET STATUS LABEL
  String _getStatusLabel(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.excellent:
        return 'EXC';
      case NetworkStatus.good:
        return 'GOOD';
      case NetworkStatus.poor:
        return 'POOR';
      case NetworkStatus.offline:
        return 'OFF';
    }
  }

  /// 📊 SHOW DETAILED STATUS DIALOG
  void _showNetworkStatusDialog(BuildContext context, NetworkStatus status) {
    final service = RealtimeNetworkStatusService.instance;
    final details = service.getDetailedStatus();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text('Network Status: ${_getStatusLabel(status)}'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusRow(
                'Connectivity',
                (details['isConnected'] as bool? ?? false)
                    ? 'CONNECTED'
                    : 'DISCONNECTED',
              ),
              _buildStatusRow('Avg Response',
                  '${details['averageResponseTime'].toStringAsFixed(0)}ms'),
              _buildStatusRow('Total Errors', '${details['totalErrors']}'),
              _buildStatusRow('Active Streams', '${details['streamCount']}'),
              if (details['lastSuccessfulPing'] != null)
                _buildStatusRow('Last Ping',
                    _formatTimestamp(details['lastSuccessfulPing'] as String?)),
              const SizedBox(height: 16),
              const Text(
                'Stream Errors:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ..._buildStreamErrorsList(
                  details['errorCounts'] as Map<String, dynamic>? ?? {}),
              const SizedBox(height: 16),
              const Text(
                'Status Legend:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              _buildLegendItem(
                  Colors.green.shade600, 'EXCELLENT', 'Sve radi savršeno'),
              _buildLegendItem(Colors.yellow.shade600, 'GOOD', 'Mali problemi'),
              _buildLegendItem(
                  Colors.orange.shade600, 'POOR', 'Veliki problemi'),
              _buildLegendItem(
                  Colors.red.shade600, 'OFFLINE', 'Nema konekcije'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  /// 📋 BUILD STATUS ROW
  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 📊 BUILD STREAM ERRORS LIST
  List<Widget> _buildStreamErrorsList(Map<String, dynamic> errorCounts) {
    if (errorCounts.isEmpty) {
      return [
        const Text(
          'Nema grešaka 🎉',
          style: TextStyle(
            color: Colors.green,
            fontStyle: FontStyle.italic,
          ),
        ),
      ];
    }

    return errorCounts.entries.map((entry) {
      final count = entry.value as int;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              entry.key,
              style: const TextStyle(fontSize: 12),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: count > 0 ? Colors.red.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color:
                      count > 0 ? Colors.red.shade700 : Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// 🏷️ BUILD LEGEND ITEM
  Widget _buildLegendItem(Color color, String status, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// ⏰ FORMAT TIMESTAMP
  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Nikad';

    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) {
        return 'Pre ${diff.inSeconds}s';
      } else if (diff.inHours < 1) {
        return 'Pre ${diff.inMinutes}m';
      } else {
        return 'Pre ${diff.inHours}h';
      }
    } catch (e) {
      return 'Nepoznato';
    }
  }
}

/// 🔲 MINI NETWORK STATUS WIDGET - za AppBar
class MiniNetworkStatusWidget extends StatelessWidget {
  const MiniNetworkStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const NetworkStatusIndicator(
      size: 8.0,
    );
  }
}
