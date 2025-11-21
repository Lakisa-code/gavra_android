import 'package:flutter/material.dart';

import '../utils/smart_colors.dart'; // 🎨 PAMETNE BOJE!

/// 🚨 REALTIME ERROR WIDGETS
/// Specijalizovani widget-i za različite tipove realtime grešaka

class StreamErrorWidget extends StatelessWidget {
  const StreamErrorWidget({
    Key? key,
    required this.streamName,
    this.errorMessage,
    this.onRetry,
  }) : super(key: key);
  final String streamName;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.smartErrorContainer,
        border: Border.all(
          color: Theme.of(context).colorScheme.smartError.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.stream,
            color: Theme.of(context).colorScheme.smartError,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Stream Greška',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.smartError,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Stream: $streamName',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Pokušaj ponovo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NetworkErrorWidget extends StatelessWidget {
  const NetworkErrorWidget({
    Key? key,
    this.message,
    this.onRetry,
  }) : super(key: key);
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off,
            color: Colors.orange.shade600,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Network Greška',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message ?? 'Nema internet konekcije',
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.wifi, size: 16),
              label: const Text('Ponovni pokušaj'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DataErrorWidget extends StatelessWidget {
  const DataErrorWidget({
    Key? key,
    required this.dataType,
    this.reason,
    this.onRefresh,
  }) : super(key: key);
  final String dataType;
  final String? reason;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        border: Border.all(color: Colors.purple.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.data_object,
            color: Colors.purple.shade600,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Data Greška',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tip: $dataType',
            style: TextStyle(
              fontSize: 12,
              color: Colors.purple.shade600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reason ?? 'Neispravni podaci iz baze',
            style: TextStyle(
              fontSize: 14,
              color: Colors.purple.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRefresh != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Osvezi podatke'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 💡 MINI ERROR WIDGETS - za AppBar ili mala mesta
class MiniStreamErrorWidget extends StatelessWidget {
  const MiniStreamErrorWidget({
    Key? key,
    required this.streamName,
    this.onTap,
  }) : super(key: key);
  final String streamName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, color: Colors.white, size: 12),
            SizedBox(width: 4),
            Text(
              'ERR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MiniNetworkErrorWidget extends StatelessWidget {
  const MiniNetworkErrorWidget({
    Key? key,
    this.onTap,
  }) : super(key: key);
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.shade700,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 12),
            SizedBox(width: 4),
            Text(
              'NET',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
