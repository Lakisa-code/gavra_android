import 'package:flutter/material.dart';

import '../models/putnik.dart';
import '../services/putnik_service.dart';
import '../services/slobodna_mesta_service.dart';
import '../utils/date_utils.dart' as app_date_utils;

class LiveMonitorScreen extends StatefulWidget {
  const LiveMonitorScreen({Key? key}) : super(key: key);

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> with SingleTickerProviderStateMixin {
  final PutnikService _putnikService = PutnikService();
  String _lastUpdated = '';
  Map<String, dynamic>? _cachedStats;
  bool _isLoadingStats = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 🔄 REALTIME: Kalkuliše statistiku
  Future<void> _loadStats() async {
    if (_isLoadingStats) return;

    setState(() => _isLoadingStats = true);

    try {
      final now = DateTime.now();

      // 📅 VIKEND LOGIKA: Ako je vikend (Sub/Ned), prikaži Ponedeljak
      DateTime targetDate = now;
      if (now.weekday == DateTime.saturday) {
        targetDate = now.add(const Duration(days: 2));
      } else if (now.weekday == DateTime.sunday) {
        targetDate = now.add(const Duration(days: 1));
      }

      final targetDateStr = targetDate.toIso8601String().split('T')[0];
      final targetDayName = app_date_utils.DateUtils.weekdayToString(targetDate.weekday);
      final dayAbbr = app_date_utils.DateUtils.getDayAbbreviation(targetDayName);

      // 1. Fetch Slots
      final slotsMap = await SlobodnaMestaService.getSlobodnaMesta(datum: targetDateStr);
      final bcSlots = slotsMap['BC'] ?? [];
      final vsSlots = slotsMap['VS'] ?? [];

      // Merge and Sort by Time
      final merged = [...bcSlots, ...vsSlots];
      merged.sort((a, b) {
        final timeA = int.tryParse(a.vreme.replaceAll(':', '')) ?? 0;
        final timeB = int.tryParse(b.vreme.replaceAll(':', '')) ?? 0;
        return timeA.compareTo(timeB);
      });

      // 2. Fetch Stats
      final otisli = await SlobodnaMestaService.getBrojUcenikaKojiSuOtisliUSkolu(dayAbbr);
      final vracaju = await SlobodnaMestaService.getBrojUcenikaKojiSeVracaju(dayAbbr);

      if (mounted) {
        setState(() {
          _cachedStats = {
            'timeline': merged,
            'uceniciOtisli': otisli,
            'uceniciVracaju': vracaju,
          };
          _lastUpdated =
              "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Monitor'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                _lastUpdated,
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'BELA CRKVA', icon: Icon(Icons.location_city)),
            Tab(text: 'VRŠAC', icon: Icon(Icons.location_city)),
          ],
        ),
      ),
      backgroundColor: Colors.grey[100],
      // 🔄 REALTIME: StreamBuilder automatski osvežava kad se promeni putnik
      body: StreamBuilder<List<Putnik>>(
        stream: _putnikService.streamKombinovaniPutniciFiltered(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Greška: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Nema podataka'));
          }

          // 🔄 Osvježi statistike kada stream emituje nove podatke
          if (!_isLoadingStats) {
            _loadStats();
          }

          // Koristi keširane statistike
          if (_cachedStats == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = _cachedStats!;
          final timeline = stats['timeline'] as List<SlobodnaMesta>? ?? [];
          final uceniciOtisli = stats['uceniciOtisli'] as int? ?? 0;
          final uceniciVracaju = stats['uceniciVracaju'] as int? ?? 0;
          final missing = uceniciOtisli - uceniciVracaju;
          final missingColor = missing > 0 ? Colors.orange : (missing < 0 ? Colors.red : Colors.green);

          // Filtriraj timeline po gradovima
          final bcTimeline = timeline.where((slot) => slot.grad == 'BC').toList();
          final vsTimeline = timeline.where((slot) => slot.grad == 'VS').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTabContent(bcTimeline, uceniciOtisli, uceniciVracaju, missing, missingColor),
              _buildTabContent(vsTimeline, uceniciOtisli, uceniciVracaju, missing, missingColor),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabContent(
    List<SlobodnaMesta> timeline,
    int uceniciOtisli,
    int uceniciVracaju,
    int missing,
    Color missingColor,
  ) {
    return Column(
      children: [
        // 📊 UPPER DASHBOARD
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Otišli u školu",
                  uceniciOtisli.toString(),
                  Icons.school,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Planiran povratak",
                  uceniciVracaju.toString(),
                  Icons.bus_alert,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "Razlika",
                  missing > 0 ? "-$missing" : (missing == 0 ? "OK" : "+${missing.abs()}"),
                  Icons.compare_arrows,
                  missingColor,
                  isAlert: missing != 0,
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // 🚦 TIMELINE
        Expanded(
          child: timeline.isEmpty
              ? const Center(
                  child: Text(
                    'Nema polazaka',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: timeline.length,
                  itemBuilder: (context, index) {
                    final slot = timeline[index];
                    return _buildSlotCard(slot, missing);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {bool isAlert = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(SlobodnaMesta slot, int missing) {
    // 🎨 Determine Status Color & Mode
    Color baseColor;
    IconData statusIcon;
    String statusText;

    // Squeeze-in Logic
    final bool isSqueezeInCandidate = missing == 0 && slot.waitingCount == 1 && slot.jePuno;

    if (slot.shouldActivateSecondVan) {
      baseColor = Colors.purple;
      statusIcon = Icons.add_road; // Second van icon
      statusText = "DRUGI KOMBI";
    } else if (isSqueezeInCandidate) {
      baseColor = Colors.amber[800]!;
      statusIcon = Icons.flash_on;
      statusText = "SQUEEZE-IN";
    } else if (slot.waitingCount > 0) {
      baseColor = Colors.orange;
      statusIcon = Icons.hourglass_top;
      statusText = "NA ČEKANJU";
    } else if (slot.jePuno) {
      baseColor = Colors.red;
      statusIcon = Icons.block;
      statusText = "PUNO";
    } else {
      baseColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
      statusText = "SLOBODNO";
    }

    // Special Styling for Rush Hour
    final bool isRush = slot.isRushHour && slot.grad == 'VS'; // Mainly VS rush hour

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: slot.shouldActivateSecondVan || isSqueezeInCandidate
            ? BorderSide(color: baseColor, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 🕒 TIME & CITY
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: slot.grad == 'VS' ? Colors.blue.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    slot.vreme,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: slot.grad == 'VS' ? Colors.blue[900] : Colors.orange[900],
                    ),
                  ),
                  Text(
                    slot.grad,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: slot.grad == 'VS' ? Colors.blue[700] : Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // 📊 PROGRESS & STATS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(statusIcon, size: 16, color: baseColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: baseColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          if (isRush) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: const Text("ŠPIC",
                                  style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                            )
                          ]
                        ],
                      ),
                      Text(
                        "${slot.zauzetaMesta}/${slot.maxMesta}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: slot.jePuno ? Colors.red : Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: slot.maxMesta > 0 ? (slot.zauzetaMesta / slot.maxMesta) : 0,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(baseColor),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),

            // ⚡ NOTIFICATIONS / ALERTS
            if (slot.waitingCount > 0 || slot.uceniciCount > 0) ...[
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (slot.waitingCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[100]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people_alt, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            "+${slot.waitingCount}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.school, size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          "${slot.uceniciCount}",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}
