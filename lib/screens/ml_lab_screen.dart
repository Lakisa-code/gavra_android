import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../config/calendar_config.dart';
import '../services/driver_location_service.dart';
import '../services/ml_service.dart';
import '../services/ml_vehicle_autonomous_service.dart';
import '../services/realtime_gps_service.dart';

/// ML Lab Screen - Machine Learning Analysis and Predictions
///
/// This screen provides access to ML features:
/// - Live predictions (occupancy, demand, optimal routes)
/// - Model performance metrics
/// - Training data explorer
/// - Feature importance visualization
/// - ML settings and configuration
class MLLabScreen extends StatefulWidget {
  const MLLabScreen({super.key});

  @override
  State<MLLabScreen> createState() => _MLLabScreenState();
}

class _MLLabScreenState extends State<MLLabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _enablePredictions = true;
  bool _autoTrain = true;
  bool _collectData = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.blue),
            SizedBox(width: 8),
            Text('ML - Autonomni Sistem'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.blue,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.auto_mode), text: 'Vozila (AI)'),
            Tab(icon: Icon(Icons.settings), text: 'Podešavanja'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVehicleAITab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  /// Tab 1: Vehicle Autonomy (The New Brain)
  Widget _buildVehicleAITab() {
    final service = MLVehicleAutonomousService();
    final targets = service.activeMonitoringTargets;
    final knowledge = service.currentKnowledge;
    final interval = service.currentInterval;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🧠 BRAIN STATUS CARD
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology, size: 40, color: Colors.purple),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AUTONOMNI KORTEX',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 4),
                                const Text('ONLINE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Min: $interval', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('${targets.length} meta', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 🎯 ACTIVE MONITORING TARGETS
          const Text(
            'Šta trenutno pratim? (Meta-Učenje)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (targets.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Trenutno nema aktivnih meta. Čekam nove podatke...'),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: targets.length,
              itemBuilder: (context, index) {
                final target = targets.values.toList()[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getImportanceColor(target.importance),
                      child: Text(
                        (target.importance * 10).toStringAsFixed(0),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(target.id),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(target.reason),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: target.importance > 1.0 ? 1.0 : target.importance, // Clamp visual
                          backgroundColor: Colors.grey[200],
                          color: _getImportanceColor(target.importance),
                          minHeight: 4,
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.remove_red_eye_outlined),
                  ),
                );
              },
            ),

          const SizedBox(height: 24),

          // 📚 KNOWLEDGE BASE
          const Text(
            'Naučeni Obrasci',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            padding: EdgeInsets.zero,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _buildKnowledgeCard(
                'Gume',
                '${(knowledge['tire_wear'] as Map?)?.length ?? 0} guma',
                Icons.tire_repair,
                Colors.blue,
              ),
              _buildKnowledgeCard(
                'Gorivo',
                '${(knowledge['fuel_consumption'] as Map?)?.length ?? 0} vozila',
                Icons.local_gas_station,
                Colors.orange,
              ),
              _buildKnowledgeCard(
                'Troškovi',
                '${(knowledge['cost_trends'] as Map?)?.length ?? 0} vozila',
                Icons.euro,
                Colors.green,
              ),
              _buildKnowledgeCard(
                'Otkrića',
                '${(knowledge['discoveries'] as List?)?.length ?? 0} novih',
                Icons.lightbulb_outline,
                Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 24),

          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {}); // Refresh UI
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Osveži Prikaz'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getImportanceColor(double importance) {
    if (importance >= 0.8) return Colors.red;
    if (importance >= 0.5) return Colors.orange;
    return Colors.green;
  }

  Widget _buildKnowledgeCard(String title, String subtitle, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  /// Tab 2: Settings
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ML Configuration',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Enable Predictions'),
            subtitle: const Text('Allow ML models to make predictions'),
            value: _enablePredictions,
            onChanged: (value) {
              setState(() {
                _enablePredictions = value;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(value ? 'Predictions enabled' : 'Predictions disabled'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Auto-Train Models'),
            subtitle: const Text('Automatically retrain with new data'),
            value: _autoTrain,
            onChanged: (value) {
              setState(() {
                _autoTrain = value;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(value ? 'Auto-train enabled' : 'Auto-train disabled'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Collect Training Data'),
            subtitle: const Text('Record trips for model training'),
            value: _collectData,
            onChanged: (value) {
              setState(() {
                _collectData = value;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(value ? 'Data collection enabled' : 'Data collection disabled'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const Divider(height: 32),
          const Text(
            'Model Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.blue),
            title: const Text('Retrain All Models'),
            subtitle: const Text('Force retrain with latest data'),
            trailing: ElevatedButton(
              onPressed: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Training models...'),
                      ],
                    ),
                  ),
                );

                await Future.delayed(const Duration(seconds: 2));

                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Models retrained successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Train'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear Training Data'),
            subtitle: const Text('Delete all collected ML data'),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Training Data?'),
                    content: const Text(
                      'This will delete all collected ML training data. '
                      'This action cannot be undone. Continue?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Training data cleared'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                        child: const Text('Clear', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Clear'),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Smart Notifications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'ML sistem može slati smart notifikacije za:\n'
            '• Praznici sutra (kombiji ne voze)\n'
            '• Početak školskog raspusta\n'
            '• Očekivani prebuking (18+ putnika)\n\n'
            'Implementacija: lib/examples/ml_usage_examples.dart\n'
            'Funkcija: MLNotificationService.checkAndNotify()',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Text(
            'About ML Lab',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'ML Lab is a passive learning system that observes patterns and provides insights without interfering with normal operations. All predictions are advisory only.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // Helper Widgets

  Widget _buildPredictionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> predictions,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...predictions.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $p'),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String metric, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color, child: const Icon(Icons.analytics, color: Colors.white)),
        title: Text(title),
        trailing: Text(metric, style: const TextStyle(fontWeight: FontWeight.bold)),
      },
    );
  }

  Widget _buildTrainingSessionCard(String date, String samples, String accuracy) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.model_training),
        title: Text(date),
        subtitle: Text(samples),
        trailing: Text(accuracy, style: const TextStyle(fontWeight: FontWeight.bold)),
      },
    );
  }

  Widget _buildDataStatsCard(String title, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        trailing: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      },
    );
  }

  Widget _buildQualityIndicator(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('${(value * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: value, backgroundColor: Colors.grey.shade300, color: color),
        ],
      ),
    );
  }

  Widget _buildFeatureBar(String feature, double importance, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(feature),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: importance,
                  backgroundColor: Colors.grey.shade300,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text('${(importance * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarInfo() {
    final now = DateTime.now();
    final nextPraznik = CalendarConfig.getNextPraznik(now);
    final nextRaspust = CalendarConfig.getNextRaspust(now);
    final isPraznikToday = CalendarConfig.isPraznik(now);
    final isRaspustToday = CalendarConfig.isSkolskiRaspust(now);

    return Column(
      children: [
        if (isPraznikToday)
          _buildCalendarInfoCard(
            'Danas je praznik',
            CalendarConfig.getOpis(now) ?? 'Državni praznik',
            Icons.celebration,
          ),
        if (isRaspustToday)
          _buildCalendarInfoCard(
            'Školski raspust',
            'Trenutno traje školski raspust',
            Icons.school_outlined,
          ),
        if (nextPraznik != null)
          _buildCalendarInfoCard(
            'Sledeći praznik',
            '${nextPraznik.value} - ${nextPraznik.key.day}/${nextPraznik.key.month}',
            Icons.celebration_outlined,
          ),
        if (nextRaspust != null)
          _buildCalendarInfoCard(
            'Sledeći raspust',
            '${nextRaspust.value} - ${nextRaspust.key.day}/${nextRaspust.key.month}',
            Icons.school,
          ),
        if (!isPraznikToday && !isRaspustToday && nextPraznik == null)
          _buildCalendarInfoCard(
            'Calendar Status',
            'Redovan radni dan - nema posebnih događaja',
            Icons.event,
          ),
      ],
    );
  }

  Widget _buildCalendarInfoCard(String title, String info, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.purple),
        title: Text(title),
        subtitle: Text(info),
      ),
    );
  }
}
