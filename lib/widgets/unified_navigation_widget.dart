import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/putnik.dart';

class UnifiedNavigationWidget extends StatelessWidget {
  const UnifiedNavigationWidget({
    Key? key,
    required this.putnici,
    required this.selectedVreme,
    required this.selectedGrad,
    required this.isNavigating,
    required this.lastPassengerCount,
    required this.onOptimizeAllRoutes,
    required this.onStopNavigation,
    required this.onStartGPSTracking,
    required this.onOptimizeCurrentRoute,
    required this.isRouteOptimized,
  }) : super(key: key);
  final List<Putnik> putnici;
  final String selectedVreme;
  final String selectedGrad;
  final bool isNavigating;
  final int lastPassengerCount;
  final VoidCallback onOptimizeAllRoutes;
  final VoidCallback onStopNavigation;
  final VoidCallback onStartGPSTracking;
  final VoidCallback onOptimizeCurrentRoute;
  final bool isRouteOptimized;

  @override
  Widget build(BuildContext context) {
    final putniciSaAdresom =
        putnici.where((p) => p.adresa != null && p.adresa!.isNotEmpty).toList();

    return Row(
      children: [
        // DUGME 1: OPTIMIZUJ (samo reorganizuj listu)
        _buildOptimizeButton(context, putniciSaAdresom),
        const SizedBox(width: 8),
        // 🗺️ DUGME 2: NAVIGACIJA (otvori mapu - OpenStreetMap)
        _buildNavigationButton(context, putniciSaAdresom),
      ],
    );
  }

  /// OPTIMIZUJ dugme - samo reorganizuje listu putnika
  Widget _buildOptimizeButton(
    BuildContext context,
    List<Putnik> putniciSaAdresom,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isRouteOptimized
              ? [
                  const Color(0xFF4CAF50), // Zelena kada je optimizovano
                  const Color(0xFF66BB6A),
                ]
              : [
                  const Color(0xFF00D4FF), // Tirkiz kada nije
                  const Color(0xFF0077BE),
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isRouteOptimized
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF00D4FF))
                .withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: putniciSaAdresom.isEmpty ? null : onOptimizeCurrentRoute,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isRouteOptimized ? Icons.check_circle : Icons.sort,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isRouteOptimized ? 'OPTIMIZOVANO' : 'OPTIMIZUJ',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (putniciSaAdresom.isNotEmpty)
                      Text(
                        '${putniciSaAdresom.length}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🗺️ NAVIGACIJA dugme - otvara mapu (OpenStreetMap ili lokalna navigaciona aplikacija)
  Widget _buildNavigationButton(
    BuildContext context,
    List<Putnik> putniciSaAdresom,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isNavigating
              ? [
                  const Color(0xFFFF9800), // Narandžasta kada navigira
                  const Color(0xFFFF5722),
                ]
              : [
                  const Color(0xFF673AB7), // Ljubičasta za Maps
                  const Color(0xFF9C27B0),
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isNavigating
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF673AB7))
                .withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: putniciSaAdresom.isEmpty
              ? null
              : () => _openOSMNavigation(context, putniciSaAdresom),
          onLongPress: putniciSaAdresom.isEmpty
              ? null
              : () => _showNavigationMenu(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isNavigating ? Icons.navigation : Icons.map,
                  color: Theme.of(context).colorScheme.onSecondary,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isNavigating ? 'NAVIGIRAM' : 'NAVIGACIJA',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (putniciSaAdresom.isNotEmpty)
                      Text(
                        '${putniciSaAdresom.length}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                if (isNavigating) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onStopNavigation,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.stop,
                        color: Theme.of(context).colorScheme.onError,
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🗺️ Otvara mapu (OpenStreetMap) sa TRENUTNIM redosledom (bez dodatne optimizacije)
  void _openOSMNavigation(BuildContext context, List<Putnik> putnici) async {
    if (putnici.isEmpty) return;

    try {
      // VAŽNO: Koristi TRENUTNI redosled putnika (ne optimizuj ponovo!)
      // Direktno kreiraj OpenStreetMap URL sa trenutnim redosledom

      // 1. Dobij trenutnu poziciju
      final currentPosition = await Geolocator.getCurrentPosition(
          // desiredAccuracy: deprecated, use settings parameter
          );

      // 2. Kreiraj OpenStreetMap URL sa TRENUTNIM redosledom putnika
      String osmUrl = 'https://www.openstreetmap.org/directions?';
      osmUrl +=
          'from=${currentPosition.latitude}%2C${currentPosition.longitude}';

      // 3. Dodaj poslednju destinaciju (OSM URL ne podržava multiple waypoints na isti način kao neke provajdere)
      if (putnici.isNotEmpty) {
        final lastPutnik = putnici.last;
        if (lastPutnik.adresa != null && lastPutnik.adresa!.isNotEmpty) {
          final encodedAddress = Uri.encodeComponent(
            '${lastPutnik.adresa}, ${lastPutnik.grad}, Serbia',
          );
          osmUrl += '&to=$encodedAddress';
        }
      }

      // 4. Dodaj parametre za navigaciju
      osmUrl += '&route=car'; // Driving mode

      // 5. Otvori OpenStreetMap
      final uri = Uri.parse(osmUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        // Pokreni GPS tracking
        onStartGPSTracking();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('🗺️ OpenStreetMap otvoren sa rutom'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Ne mogu da otvorim navigaciju'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri pokretanju navigacije: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showNavigationMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Navigacija Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            _buildMenuOption(
              context: context,
              icon: Icons.map,
              title: 'Reorganizuj Listu',
              subtitle: 'Optimizuj redosled putnika u aplikaciji',
              onTap: () {
                Navigator.pop(context);
                onOptimizeAllRoutes();
              },
            ),
            _buildMenuOption(
              context: context,
              icon: Icons.navigation,
              title: 'OpenStreetMap Ruta',
              subtitle:
                  'Otvori kompletnu rutu u OpenStreetMap ili pretraživaču',
              onTap: () {
                Navigator.pop(context);
                final putniciSaAdresom = putnici
                    .where((p) => p.adresa != null && p.adresa!.isNotEmpty)
                    .toList();
                _openOSMNavigation(context, putniciSaAdresom);
              },
            ),
            _buildMenuOption(
              context: context,
              icon: Icons.gps_fixed,
              title: 'GPS Tracking',
              subtitle: 'Pokreni realtime praćenje',
              onTap: () {
                Navigator.pop(context);
                onStartGPSTracking();
              },
            ),
            _buildMenuOption(
              context: context,
              icon: isRouteOptimized ? Icons.route : Icons.alt_route,
              title: 'Lokalna Optimizacija',
              subtitle: 'Optimizuj redosled putnika',
              onTap: () {
                Navigator.pop(context);
                onOptimizeCurrentRoute();
              },
            ),
            if (isNavigating)
              _buildMenuOption(
                context: context,
                icon: Icons.stop,
                title: 'Završi Navigaciju',
                subtitle: 'Prekini trenutnu navigaciju',
                color: Theme.of(context).colorScheme.error,
                onTap: () {
                  Navigator.pop(context);
                  onStopNavigation();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading:
          Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      onTap: onTap,
    );
  }
}
