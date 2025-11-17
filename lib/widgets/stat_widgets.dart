import 'package:flutter/material.dart';

import '../services/simplified_daily_checkin.dart';
import '../services/statistika_service.dart';

/// Widget za prikaz pazara vozača
class PazarStatWidget extends StatelessWidget {
  const PazarStatWidget({
    Key? key,
    required this.currentDriver,
    required this.dayStart,
    required this.dayEnd,
  }) : super(key: key);

  final String? currentDriver;
  final DateTime dayStart;
  final DateTime dayEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 69,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: StreamBuilder<double>(
        stream: StatistikaService.streamPazarZaVozaca(
          currentDriver ?? '',
          from: dayStart,
          to: dayEnd,
        ),
        builder: (context, snapshot) {
          final pazar = snapshot.data ?? 0.0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Pazar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                pazar.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Widget za prikaz mesečnih karata
class MesecneStatWidget extends StatelessWidget {
  const MesecneStatWidget({
    Key? key,
    required this.currentDriver,
    required this.dayStart,
    required this.dayEnd,
  }) : super(key: key);

  final String? currentDriver;
  final DateTime dayStart;
  final DateTime dayEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 69,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple[300]!),
      ),
      child: StreamBuilder<int>(
        stream: StatistikaService.streamBrojMesecnihKarataZaVozaca(
          currentDriver ?? '',
          from: dayStart,
          to: dayEnd,
        ),
        builder: (context, snapshot) {
          final brojMesecnih = snapshot.data ?? 0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Mesečne',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                brojMesecnih.toString(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Widget za prikaz dugova
class DugoviStatWidget extends StatelessWidget {
  const DugoviStatWidget({
    Key? key,
    required this.filteredDuznici,
    required this.currentDriver,
    required this.onTap,
  }) : super(key: key);

  final List<dynamic> filteredDuznici;
  final String? currentDriver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 69,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Dugovi',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              filteredDuznici.length.toString(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget za prikaz kusura
class KusurStatWidget extends StatelessWidget {
  const KusurStatWidget({
    Key? key,
    required this.currentDriver,
  }) : super(key: key);

  final String? currentDriver;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 69,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: StreamBuilder<double>(
        stream: SimplifiedDailyCheckInService.streamTodayAmount(
          currentDriver ?? '',
        ),
        builder: (context, snapshot) {
          final sitanNovac = snapshot.data ?? 0.0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kusur',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sitanNovac > 0 ? sitanNovac.toStringAsFixed(0) : '-',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Container widget za sve statistike
class StatsRowWidget extends StatelessWidget {
  const StatsRowWidget({
    Key? key,
    required this.currentDriver,
    required this.dayStart,
    required this.dayEnd,
    required this.filteredDuznici,
    required this.onDugoviTap,
  }) : super(key: key);

  final String? currentDriver;
  final DateTime dayStart;
  final DateTime dayEnd;
  final List<dynamic> filteredDuznici;
  final VoidCallback onDugoviTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      height: 85, // Fixed height to provide constraints
      child: Row(
        children: [
          Expanded(
            child: PazarStatWidget(
              currentDriver: currentDriver,
              dayStart: dayStart,
              dayEnd: dayEnd,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: MesecneStatWidget(
              currentDriver: currentDriver,
              dayStart: dayStart,
              dayEnd: dayEnd,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: DugoviStatWidget(
              filteredDuznici: filteredDuznici,
              currentDriver: currentDriver,
              onTap: onDugoviTap,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: KusurStatWidget(
              currentDriver: currentDriver,
            ),
          ),
        ],
      ),
    );
  }
}
