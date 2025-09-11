import 'package:flutter/material.dart';
import '../services/real_time_statistika_service.dart';
import '../utils/vozac_boja.dart';

/// 🔧 TEST WIDGET - Prikazuje real-time statistike za troubleshooting
class StatistikeTesterWidget extends StatefulWidget {
  const StatistikeTesterWidget({super.key});

  @override
  State<StatistikeTesterWidget> createState() => _StatistikeTesterWidgetState();
}

class _StatistikeTesterWidgetState extends State<StatistikeTesterWidget> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Real-Time Statistike Test'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              // Očisti cache da testiramo freshly
              RealTimeStatistikaService.instance.clearCache();
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💰 PAZAR STREAM TEST
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💰 REAL-TIME PAZAR (Danas)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<Map<String, double>>(
                      stream: RealTimeStatistikaService.instance.getPazarStream(
                        from: today,
                        to: todayEnd,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Text(
                            '❌ Greška: ${snapshot.error}',
                            style: TextStyle(color: Colors.red.shade700),
                          );
                        }

                        final pazarMap = snapshot.data ?? <String, double>{};
                        final ukupno = pazarMap['_ukupno'] ?? 0.0;

                        return Column(
                          children: [
                            // Ukupan pazar
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.green.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '🏆 UKUPNO:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '${ukupno.toStringAsFixed(0)} RSD',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Pazar po vozačima
                            ...VozacBoja.boje.keys.map((vozac) {
                              final vozacPazar = pazarMap[vozac] ?? 0.0;
                              final boja = VozacBoja.get(vozac);

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: boja,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          vozac,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${vozacPazar.toStringAsFixed(0)} RSD',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: boja,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 📊 DETALJNE STATISTIKE TEST
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📊 DETALJNE STATISTIKE (Danas)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<Map<String, Map<String, dynamic>>>(
                      stream: RealTimeStatistikaService.instance
                          .getDetaljneStatistikeStream(
                        from: today,
                        to: todayEnd,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Text(
                            '❌ Greška: ${snapshot.error}',
                            style: TextStyle(color: Colors.red.shade700),
                          );
                        }

                        final statsMap =
                            snapshot.data ?? <String, Map<String, dynamic>>{};

                        if (statsMap.isEmpty) {
                          return const Text(
                            '📭 Nema podataka za danas',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          );
                        }

                        return Column(
                          children: VozacBoja.boje.keys.map((vozac) {
                            final vozacStats = statsMap[vozac] ?? {};
                            final boja = VozacBoja.get(vozac);

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: boja,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          vozac,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 4,
                                      children: [
                                        _buildStatChip(
                                            'Dodati',
                                            vozacStats['dodati'] ?? 0,
                                            Colors.blue),
                                        _buildStatChip(
                                            'Naplaćeni',
                                            vozacStats['naplaceni'] ?? 0,
                                            Colors.green),
                                        _buildStatChip(
                                            'Pokupljeni',
                                            vozacStats['pokupljeni'] ?? 0,
                                            Colors.orange),
                                        _buildStatChip(
                                            'Otkazani',
                                            vozacStats['otkazani'] ?? 0,
                                            Colors.red),
                                        _buildStatChip(
                                            'Mesečne',
                                            vozacStats['mesecneKarte'] ?? 0,
                                            Colors.purple),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 🚀 CACHE INFO
            Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔧 DEBUG INFO',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Real-Time Statistika Servis je aktivan\n'
                      '• Stream cache je implementiran\n'
                      '• Automatsko sinhronizovanje sa bazom\n'
                      '• Poslednje ažuriranje: ${DateTime.now().toString().substring(0, 19)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, int count, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade300),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: color.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
