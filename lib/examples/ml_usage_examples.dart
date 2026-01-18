/// 📝 PRIMERI KORIŠĆENJA ML SERVICE
///
/// Ovi primeri pokazuju kako integrisati MLService u postojeći kod.
/// Svi primeri su advisory only - ne menjaju ništa automatski.

import 'package:flutter/material.dart';

import '../config/calendar_config.dart';
import '../services/local_notification_service.dart';
import '../services/ml_service.dart';

// ====================================================================
// PRIMER 1: Prikaži predviđeni broj putnika u KapacitetScreen
// ====================================================================

class KapacitetScreenWithML extends StatelessWidget {
  final String grad;
  final String vreme;
  final DateTime datum;

  const KapacitetScreenWithML({
    super.key,
    required this.grad,
    required this.vreme,
    required this.datum,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text('$grad $vreme'),

          // Postojeći prikaz kapaciteta...

          // ✨ NOVO: ML predviđanje
          FutureBuilder<double>(
            future: MLService.predictOccupancy(
              grad: grad,
              vreme: vreme,
              date: datum,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              final predicted = snapshot.data!;

              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Colors.blue, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'ML predviđa: ${predicted.toStringAsFixed(0)} putnika',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// PRIMER 2: Calendar Alert u DanasScreen
// ====================================================================

class CalendarAlertWidget extends StatelessWidget {
  const CalendarAlertWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    // Proveri calendar status
    if (CalendarConfig.kombijNijeRadanDan(today)) {
      return _buildAlert(
        icon: Icons.warning,
        color: Colors.red,
        message: '⚠️ Kombiji NE VOZE danas (${CalendarConfig.getOpis(today)})',
      );
    }

    if (CalendarConfig.isSkolskiRaspust(today)) {
      return _buildAlert(
        icon: Icons.info,
        color: Colors.blue,
        message: '📚 Školski raspust - očekujte manji broj putnika',
      );
    }

    final nextPraznik = CalendarConfig.getNextPraznik(today);
    if (nextPraznik != null && nextPraznik.key.difference(today).inDays == 1) {
      return _buildAlert(
        icon: Icons.celebration,
        color: Colors.orange,
        message: '🎉 Sutra je ${nextPraznik.value} - kombiji ne voze!',
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildAlert({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

// ====================================================================
// PRIMER 3: Payment Risk Indicator u PutnikCard
// ====================================================================

class PutnikCardWithRisk extends StatelessWidget {
  final String putnikId;
  final String putnikIme;

  const PutnikCardWithRisk({
    super.key,
    required this.putnikId,
    required this.putnikIme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(putnikIme),

        // Postojeći prikaz...

        // ✨ NOVO: Payment risk badge
        trailing: FutureBuilder<double>(
          future: MLService.predictPaymentRisk(putnikId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();

            final risk = snapshot.data!;

            if (risk < 0.3) return const SizedBox.shrink(); // Low risk - ne prikazuj

            final color = risk > 0.7 ? Colors.red : Colors.orange;
            final label = risk > 0.7 ? 'HIGH RISK' : 'MEDIUM RISK';

            return Chip(
              label: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              backgroundColor: color,
              padding: EdgeInsets.zero,
            );
          },
        ),
      ),
    );
  }
}

// ====================================================================
// PRIMER 4: Smart Notification za admin
// ====================================================================
//
// KAKO KORISTITI:
// 1. Pozovi MLNotificationService.checkAndNotify() svaki dan u određeno vreme
// 2. Najbolje vreme: 18:00 uveče (priprema za sutrašnji dan)
// 3. Može se pozvati iz background job-a ili scheduled task-a
//
// PRIMER POZIVA:
// - U main.dart inicijalizaciji dodaj daily scheduled task
// - Ili u admin screen dodaj button "Check ML Alerts"
// - Ili automatski svake večeri u 18:00
//
// INSTALACIJA (opciono - za background job):
// 1. Dodaj workmanager paket u pubspec.yaml
// 2. Registruj task u main.dart
// 3. Pozovi MLNotificationService.checkAndNotify() u background

class MLNotificationService {
  /// Proveri da li treba poslati notifikaciju adminu
  static Future<void> checkAndNotify() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    // Provera 1: Da li je sutra praznik?
    if (CalendarConfig.kombijNijeRadanDan(tomorrow)) {
      _sendNotification(
        title: 'Sutra je praznik',
        body: 'Kombiji ne voze sutra (${CalendarConfig.getOpis(tomorrow)})',
      );
      return;
    }

    // Provera 2: Da li je početak raspusta?
    final nextRaspust = CalendarConfig.getNextRaspust(DateTime.now());
    if (nextRaspust != null && nextRaspust.key.difference(DateTime.now()).inDays == 1) {
      _sendNotification(
        title: 'Sutra počinje raspust',
        body: '📚 ${nextRaspust.value} - očekujte smanjen broj putnika',
      );
      return;
    }

    // Provera 3: Da li se očekuje prebuking?
    final predictions = await MLService.predictNext3Hours();
    for (final pred in predictions) {
      if (pred.predicted > 18) {
        // Kapacitet je 20
        _sendNotification(
          title: 'Upozorenje: Možda prebuking',
          body: '${pred.grad} ${pred.vreme} - ML predviđa ${pred.predicted.toStringAsFixed(0)} putnika',
        );
      }
    }
  }

  static void _sendNotification({required String title, required String body}) {
    LocalNotificationService.showRealtimeNotification(
      title: title,
      body: body,
      payload: '{"type":"ml_alert","timestamp":"${DateTime.now().toIso8601String()}"}',
    );
  }
}

// ====================================================================
// PRIMER 4B: Manual Trigger Button u ML Lab Settings Tab
// ====================================================================

class MLAlertTriggerButton extends StatelessWidget {
  const MLAlertTriggerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.notifications_active),
      label: const Text('Check ML Alerts Now'),
      onPressed: () async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proveravam ML alerts...')),
        );

        await MLNotificationService.checkAndNotify();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ ML alerts provera završena')),
          );
        }
      },
    );
  }
}

// ====================================================================
// PRIMER 5: ML Dashboard Widget za AdminScreen
// ====================================================================

class MLDashboardWidget extends StatelessWidget {
  const MLDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ModelMetrics>(
      future: MLService.getModelMetrics(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.science),
              title: Text('ML System'),
              subtitle: Text('Loading...'),
            ),
          );
        }

        final metrics = snapshot.data!;

        return Card(
          child: InkWell(
            onTap: () {
              // Navigate to ML Lab
              Navigator.pushNamed(context, '/ml-lab');
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.science, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('ML System Status', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Model Accuracy', style: TextStyle(fontSize: 12)),
                          Text(
                            metrics.accuracyPercent,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Samples', style: TextStyle(fontSize: 12)),
                          Text(
                            '${metrics.sampleSize}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
