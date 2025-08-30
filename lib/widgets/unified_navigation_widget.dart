import 'package:flutter/material.dart';
import '../models/putnik.dart';

class UnifiedNavigationWidget extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final putniciSaAdresom =
        putnici.where((p) => p.adresa != null && p.adresa!.isNotEmpty).toList();

    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isNavigating
              ? [
                  const Color(0xFFFF9800), // Narandžasta kada navigira
                  const Color(0xFFFF5722),
                ]
              : [
                  const Color(0xFF00D4FF), // Tirkiz kada nije
                  const Color(0xFF0077BE),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isNavigating
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF00D4FF))
                .withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: putnici.isEmpty ? null : _handleTap,
          onLongPress:
              putnici.isEmpty ? null : () => _showNavigationMenu(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isNavigating ? Icons.navigation : Icons.explore,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isNavigating ? 'NAVIGIRAM' : 'NAVIGACIJA',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (putniciSaAdresom.isNotEmpty)
                      Text(
                        '${putniciSaAdresom.length}',
                        style: const TextStyle(
                          color: Colors.white,
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
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.stop,
                        color: Colors.white,
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

  void _handleTap() {
    if (isNavigating) {
      // Ako navigira, otvori novu rutu
      onOptimizeAllRoutes();
    } else {
      // Ako ne navigira, počni navigaciju
      onOptimizeAllRoutes();
    }
  }

  void _showNavigationMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Navigacija Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),
            _buildMenuOption(
              icon: Icons.map,
              title: 'Google Maps Ruta',
              subtitle: 'Otvori optimizovanu rutu u Google Maps',
              onTap: () {
                Navigator.pop(context);
                onOptimizeAllRoutes();
              },
            ),
            _buildMenuOption(
              icon: Icons.gps_fixed,
              title: 'GPS Tracking',
              subtitle: 'Pokreni realtime praćenje',
              onTap: () {
                Navigator.pop(context);
                onStartGPSTracking();
              },
            ),
            _buildMenuOption(
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
                icon: Icons.stop,
                title: 'Završi Navigaciju',
                subtitle: 'Prekini trenutnu navigaciju',
                color: Colors.red,
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
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.blue[600]),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      onTap: onTap,
    );
  }
}

