import 'package:flutter/material.dart';

import '../utils/device_utils.dart';
import '../utils/navigation_provider.dart';
import '../utils/navigation_url_builder.dart';

/// 🧭 NAVIGATION DIALOGS
/// Dialozi za navigaciju - koristi se isključivo HERE WeGo

class NavigationDialogs {
  // ═══════════════════════════════════════════════════════════════════════
  // 📱 HERE WEGO INSTALACIJA DIALOG
  // ═══════════════════════════════════════════════════════════════════════

  /// Prikaži dialog za instalaciju HERE WeGo ako nije instaliran
  ///
  /// Returns: NavigationProvider.hereWeGo ili null za odustajanje
  static Future<NavigationProvider?> showInstallHereWeGoDialog(
    BuildContext context,
  ) async {
    // Proveri da li je HERE WeGo instaliran
    final isInstalled = await DeviceUtils.isAppInstalled(NavigationProvider.hereWeGo);

    if (isInstalled) {
      return NavigationProvider.hereWeGo;
    }

    if (!context.mounted) return null;

    return showDialog<NavigationProvider>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _InstallHereWeGoDialog(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🔀 SEGMENT NASTAVAK DIALOG
  // ═══════════════════════════════════════════════════════════════════════

  /// Prikaži dialog za nastavak navigacije kada ima više segmenata
  ///
  /// Returns: true ako korisnik želi da nastavi, false za odustajanje
  static Future<bool> showSegmentContinueDialog(
    BuildContext context, {
    required int currentSegment,
    required int totalSegments,
    required int remainingPutnici,
    required NavigationProvider provider,
  }) async {
    if (!context.mounted) return false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _SegmentContinueDialog(
            currentSegment: currentSegment,
            totalSegments: totalSegments,
            remainingPutnici: remainingPutnici,
            provider: provider,
          ),
        ) ??
        false;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 📱 NEMA NAVIGACIJE DIALOG (preusmereno na HERE WeGo)
  // ═══════════════════════════════════════════════════════════════════════

  /// Prikaži dialog kada HERE WeGo nije instaliran
  static Future<NavigationProvider?> showNoNavigationAppDialog(
    BuildContext context, {
    bool isHuawei = false, // ignorisano - uvek HERE WeGo
  }) async {
    return showInstallHereWeGoDialog(context);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 📱 INSTALL HERE WEGO DIALOG WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class _InstallHereWeGoDialog extends StatelessWidget {
  const _InstallHereWeGoDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.navigation, color: Colors.green),
          SizedBox(width: 8),
          Expanded(child: Text('HERE WeGo potreban')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Za navigaciju je potreban HERE WeGo.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // HERE WeGo info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'HERE WeGo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Besplatan\n'
                    '• Offline mape dostupne\n'
                    '• Radi na svim uređajima\n'
                    '• Poštuje redosled putnika\n'
                    '• Do 10 waypointa',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Odustani'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            await NavigationUrlBuilder.openStore(NavigationProvider.hereWeGo);
            // Ne zatvaraj dialog - korisnik treba da instalira app
          },
          icon: const Icon(Icons.download),
          label: const Text('Instaliraj'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🔀 SEGMENT CONTINUE DIALOG WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class _SegmentContinueDialog extends StatelessWidget {
  const _SegmentContinueDialog({
    required this.currentSegment,
    required this.totalSegments,
    required this.remainingPutnici,
    required this.provider,
  });

  final int currentSegment;
  final int totalSegments;
  final int remainingPutnici;
  final NavigationProvider provider;

  @override
  Widget build(BuildContext context) {
    final nextSegment = currentSegment + 1;
    final isLastSegment = nextSegment == totalSegments;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.route, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Navigacija - Deo $nextSegment/$totalSegments',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLastSegment
                ? 'Završili ste deo $currentSegment. Preostalo je još $remainingPutnici putnika.'
                : 'Završili ste deo $currentSegment. Preostalo je $remainingPutnici putnika u ${totalSegments - currentSegment} delova.',
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Koristi se ${provider.displayName} (max ${provider.maxWaypoints} putnika po delu)',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Završi'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.navigation),
          label: Text(isLastSegment ? 'Poslednji deo' : 'Nastavi ($remainingPutnici)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 📱 NO NAVIGATION APP DIALOG WIDGET (DEPRECATED - koristi _InstallHereWeGoDialog)
// ═══════════════════════════════════════════════════════════════════════════

// Uklonjen - sada se koristi samo _InstallHereWeGoDialog
