import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/danas_screen.dart';
import 'dart:convert';

class NotificationNavigationService {
  /// Navigate to a specific passenger when notification is tapped
  static Future<void> navigateToPassenger({
    required String type,
    required Map<String, dynamic> putnikData,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      // Parse putnik data
      final putnikIme = putnikData['ime'] ?? 'Nepoznat putnik';
      final putnikDan = putnikData['dan'] ?? '';
      final mesecnaKarta = putnikData['mesecnaKarta'] ?? false;

      // Show a popup with passenger info and navigation options
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  type == 'novi_putnik'
                      ? Icons.person_add
                      : Icons.person_remove,
                  color: type == 'novi_putnik' ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    type == 'novi_putnik'
                        ? 'Novi putnik dodat'
                        : 'Putnik otkazan',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '👤 $putnikIme',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (putnikDan.isNotEmpty)
                  Text(
                    '📅 Dan: $putnikDan',
                    style: const TextStyle(fontSize: 14),
                  ),
                if (putnikData['polazak'] != null)
                  Text(
                    '🕐 Polazak: ${putnikData['polazak']}',
                    style: const TextStyle(fontSize: 14),
                  ),
                if (putnikData['grad'] != null)
                  Text(
                    '🏘️ Destinacija: ${putnikData['grad']}',
                    style: const TextStyle(fontSize: 14),
                  ),
                if (mesecnaKarta)
                  const Text(
                    '💳 Mesečna karta',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Vreme: ${DateTime.now().toString().substring(0, 19)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Zatvori'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToAppropriateScreen(
                      context, type, putnikData, mesecnaKarta);
                },
                child: const Text('Otvori'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      // Error parsing notification data
      if (context.mounted) {
        _showErrorDialog(context, 'Greška pri otvaranju putnika: $e');
      }
    }
  }

  /// Navigate to appropriate screen based on passenger type
  static void _navigateToAppropriateScreen(
    BuildContext context,
    String type,
    Map<String, dynamic> putnikData,
    bool mesecnaKarta,
  ) {
    // Always navigate to today's screen for all notification types
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DanasScreen(),
      ),
    );
  }

  /// Show error dialog
  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Greška'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('U redu'),
            ),
          ],
        );
      },
    );
  }

  /// Parse notification payload and extract putnik data
  static Map<String, dynamic>? parseNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;

    try {
      // Try to parse as JSON
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      // If not JSON, try to parse string format
      return _parseStringPayload(payload);
    }
  }

  /// Parse string-format payload (fallback)
  static Map<String, dynamic>? _parseStringPayload(String payload) {
    try {
      // Extract data from string like: {type: novi_putnik, putnik: {...}}
      final typeMatch = RegExp(r'type:\s*([^,}]+)').firstMatch(payload);
      final putnikMatch = RegExp(r'putnik:\s*(\{[^}]+\})').firstMatch(payload);

      if (typeMatch != null && putnikMatch != null) {
        final type = typeMatch.group(1)?.trim();
        final putnikStr = putnikMatch.group(1)?.trim();

        if (type != null && putnikStr != null) {
          try {
            final putnikData = jsonDecode(putnikStr);
            return {
              'type': type,
              'putnik': putnikData,
            };
          } catch (e) {
            // JSON parse error
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
