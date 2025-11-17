import 'package:flutter/material.dart';

import '../models/putnik.dart';
import '../widgets/putnik_list.dart';
import '../widgets/real_time_navigation_widget.dart';

/// Container widget za putnik listu i navigaciju
class PutnikListContainer extends StatelessWidget {
  const PutnikListContainer({
    Key? key,
    required this.finalPutnici,
    required this.isRouteOptimized,
    required this.isListReordered,
    required this.optimizedRoute,
    required this.isGpsTracking,
    required this.useAdvancedNavigation,
    required this.currentDriver,
    required this.onRouteUpdate,
    required this.onStatusUpdate,
  }) : super(key: key);

  final List<Putnik> finalPutnici;
  final bool isRouteOptimized;
  final bool isListReordered;
  final List<Putnik> optimizedRoute;
  final bool isGpsTracking;
  final bool useAdvancedNavigation;
  final String? currentDriver;
  final Function(List<Putnik>) onRouteUpdate;
  final Function(String) onStatusUpdate;

  @override
  Widget build(BuildContext context) {
    if (finalPutnici.isEmpty) {
      return const Center(
        child: Text(
          'Nema putnika za izabrani polazak',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Column(
      children: [
        // Optimized route indicator
        if (isRouteOptimized)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isGpsTracking ? Colors.blue[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isGpsTracking ? Colors.blue[300]! : Colors.green[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isGpsTracking ? Icons.gps_fixed : Icons.route,
                  color: isGpsTracking ? Colors.blue : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isGpsTracking
                        ? '🛰️ GPS praćenje aktivno - lista optimizovana'
                        : '🎯 Lista putnika optimizovana (server) za putanju!',
                    style: TextStyle(
                      fontSize: 12,
                      color: isGpsTracking ? Colors.blue : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Real-time navigation widget
        if (useAdvancedNavigation && optimizedRoute.isNotEmpty)
          RealTimeNavigationWidget(
            optimizedRoute: optimizedRoute,
            onStatusUpdate: onStatusUpdate,
            onRouteUpdate: onRouteUpdate,
          ),

        // Main putnik list
        Expanded(
          child: PutnikList(
            putnici: finalPutnici,
            useProvidedOrder: isListReordered,
            currentDriver: currentDriver,
            bcVremena: const [
              '5:00',
              '6:00',
              '7:00',
              '8:00',
              '9:00',
              '11:00',
              '12:00',
              '13:00',
              '14:00',
              '15:30',
              '18:00',
            ],
            vsVremena: const [
              '6:00',
              '7:00',
              '8:00',
              '10:00',
              '11:00',
              '12:00',
              '13:00',
              '14:00',
              '15:30',
              '17:00',
              '19:00',
            ],
          ),
        ),
      ],
    );
  }
}
