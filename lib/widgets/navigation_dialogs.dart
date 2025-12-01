import 'package:flutter/material.dart';

import '../utils/device_utils.dart';
import '../utils/navigation_provider.dart';
import '../utils/navigation_url_builder.dart';

/// 🧭 NAVIGATION DIALOGS
/// Dialozi za navigaciju - Huawei preporuka i segment nastavak

class NavigationDialogs {
  // ═══════════════════════════════════════════════════════════════════════
  // 📱 HUAWEI HERE WEGO PREPORUKA DIALOG
  // ═══════════════════════════════════════════════════════════════════════

  /// Prikaži dialog za Huawei korisnike sa preporukom za HERE WeGo
  /// Prikazuje se samo jednom (SharedPreferences)
  ///
  /// Returns: NavigationProvider koji korisnik želi da koristi, ili null za odustajanje
  static Future<NavigationProvider?> showHuaweiRecommendationDialog(
    BuildContext context, {
    required List<NavigationProvider> installedApps,
  }) async {
    // Proveri da li je dialog već prikazan
    if (await DeviceUtils.wasHuaweiDialogShown()) {
      // Vrati preferiranu aplikaciju ili prvu dostupnu
      return await DeviceUtils.getPreferredNavigationProvider() ??
          (installedApps.isNotEmpty ? installedApps.first : null);
    }

    // Označi da je dialog prikazan
    await DeviceUtils.markHuaweiDialogShown();

    if (!context.mounted) return null;

    return showDialog<NavigationProvider>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _HuaweiRecommendationDialog(installedApps: installedApps),
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
  // 📱 NEMA NAVIGACIJE DIALOG
  // ═══════════════════════════════════════════════════════════════════════

  /// Prikaži dialog kada nema instalirane navigacione aplikacije
  static Future<NavigationProvider?> showNoNavigationAppDialog(
    BuildContext context, {
    required bool isHuawei,
  }) async {
    if (!context.mounted) return null;

    return showDialog<NavigationProvider>(
      context: context,
      builder: (context) => _NoNavigationAppDialog(isHuawei: isHuawei),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 📱 HUAWEI RECOMMENDATION DIALOG WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class _HuaweiRecommendationDialog extends StatelessWidget {
  const _HuaweiRecommendationDialog({required this.installedApps});

  final List<NavigationProvider> installedApps;

  @override
  Widget build(BuildContext context) {
    final hasHereWeGo = installedApps.contains(NavigationProvider.hereWeGo);
    final hasPetalMaps = installedApps.contains(NavigationProvider.petalMaps);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.phone_android, color: Colors.red),
          SizedBox(width: 8),
          Expanded(child: Text('Huawei uređaj detektovan')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Google Maps nije dostupan na Huawei uređajima bez Google servisa.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // HERE WeGo preporuka
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
                        'Preporučeno: HERE WeGo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Podržava 10 waypointa\n'
                    '• Offline mape dostupne\n'
                    '• Odličan za Huawei uređaje',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Petal Maps info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.map, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Alternativa: Petal Maps',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Fabrički instaliran\n'
                    '• Ograničen na 5 waypointa\n'
                    '• Zahteva više segmenata',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // HERE WeGo dugme
        if (hasHereWeGo)
          ElevatedButton.icon(
            onPressed: () {
              DeviceUtils.setPreferredNavigationProvider(NavigationProvider.hereWeGo);
              Navigator.of(context).pop(NavigationProvider.hereWeGo);
            },
            icon: const Icon(Icons.navigation),
            label: const Text('Koristi HERE WeGo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: () async {
              await NavigationUrlBuilder.openStore(NavigationProvider.hereWeGo);
              // Ne zatvaraj dialog - korisnik treba da instalira app
            },
            icon: const Icon(Icons.download),
            label: const Text('Instaliraj HERE WeGo'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
          ),

        // Petal Maps dugme
        if (hasPetalMaps)
          TextButton(
            onPressed: () {
              DeviceUtils.setPreferredNavigationProvider(NavigationProvider.petalMaps);
              Navigator.of(context).pop(NavigationProvider.petalMaps);
            },
            child: const Text('Koristi Petal Maps'),
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
// 📱 NO NAVIGATION APP DIALOG WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class _NoNavigationAppDialog extends StatelessWidget {
  const _NoNavigationAppDialog({required this.isHuawei});

  final bool isHuawei;

  @override
  Widget build(BuildContext context) {
    final recommendedApp = isHuawei ? NavigationProvider.hereWeGo : NavigationProvider.googleMaps;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(child: Text('Navigacija nije dostupna')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nema instalirane navigacione aplikacije na vašem uređaju.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Text(
            'Preporučujemo instalaciju ${recommendedApp.displayName}:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isHuawei
                ? '• HERE WeGo - najbolje za Huawei uređaje\n'
                    '• Podržava offline mape\n'
                    '• Do 10 waypointa'
                : '• Google Maps - najpopularnija navigacija\n'
                    '• Real-time traffic info\n'
                    '• Do 10 waypointa',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Odustani'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            await NavigationUrlBuilder.openStore(recommendedApp);
            if (context.mounted) {
              Navigator.of(context).pop(recommendedApp);
            }
          },
          icon: const Icon(Icons.download),
          label: Text('Instaliraj ${recommendedApp.displayName}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
