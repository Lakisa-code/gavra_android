import 'package:flutter/material.dart';

/// 🎨 UNIFICIRANI UI SERVIS ZA PORUKE I DIJALOGE
/// Centralizovano mesto za upravljanje svim obaveštenjima u aplikaciji.
class GavraUI {
  /// 📲 Prikazuje uniformisanu SnackBar poruku na dnu ekrana
  static void showSnackBar(
    BuildContext context, {
    required String message,
    GavraNotificationType type = GavraNotificationType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    Color bgColor;
    IconData icon;

    switch (type) {
      case GavraNotificationType.success:
        bgColor = Colors.green.shade700;
        icon = Icons.check_circle_outline;
        break;
      case GavraNotificationType.warning:
        bgColor = Colors.orange.shade800;
        icon = Icons.warning_amber_rounded;
        break;
      case GavraNotificationType.error:
        bgColor = Colors.red.shade700;
        icon = Icons.error_outline;
        break;
      case GavraNotificationType.info:
        bgColor = Colors.blue.shade700;
        icon = Icons.info_outline;
        break;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  /// 📅 Prikazuje uniformisani informativni dijalog
  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    Color iconColor = Colors.blue,
    String buttonText = 'RAZUMEM',
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              buttonText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// ❓ Prikazuje uniformisani dijalog za potvrdu akcije
  static Future<bool> showActionDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'POTVRDI',
    String cancelText = 'ODUSTANI',
    Color confirmColor = Colors.blue,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText, style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(confirmText, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

enum GavraNotificationType { success, info, warning, error }
