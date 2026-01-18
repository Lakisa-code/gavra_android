import 'dart:async';

import 'package:flutter/material.dart';

import '../services/slobodna_mesta_service.dart';
import '../utils/date_utils.dart' as app_date_utils;

class LiveMonitorScreen extends StatefulWidget {
  const LiveMonitorScreen({Key? key}) : super(key: key);

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> {
  Timer? _timer;
  bool _isLoading = true;
  List<SlobodnaMesta> _timeline = [];
  int _uceniciOtisli = 0;
  int _uceniciVracaju = 0;
  String _lastUpdated = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    // Refresh every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

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

      // Dobij pun naziv dana za ciljni datum (npr. "ponedeljak")
      final targetDayName = app_date_utils.DateUtils.weekdayToString(targetDate.weekday);
      // Dobij skraćenicu (npr. "pon")
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
      // Note: SlobodnaMestaService methods take full day name or abbr?
      // Looking at service code: _isoDateToDayAbbr uses ['pon', ...]
      // passing 'pet' should work if logic uses simple string match.
      final otisli = await SlobodnaMestaService.getBrojUcenikaKojiSuOtisliUSkolu(dayAbbr);
      final vracaju = await SlobodnaMestaService.getBrojUcenikaKojiSeVracaju(dayAbbr);

      if (mounted) {
        setState(() {
          _timeline = merged;
          _uceniciOtisli = otisli;
          _uceniciVracaju = vracaju;
          _lastUpdated =
              "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading live monitor: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Diff calculation
    final missing = _uceniciOtisli - _uceniciVracaju;
    final missingColor = missing > 0 ? Colors.orange : (missing < 0 ? Colors.red : Colors.green);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Monitor'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
      ),
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                          _uceniciOtisli.toString(),
                          Icons.school,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          "Planiran povratak",
                          _uceniciVracaju.toString(),
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
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _timeline.length,
                    itemBuilder: (context, index) {
                      final slot = _timeline[index];
                      return _buildSlotCard(slot);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {bool isAlert = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(SlobodnaMesta slot) {
    // 🎨 Determine Status Color & Mode
    Color baseColor;
    IconData statusIcon;
    String statusText;

    // Squeeze-in Logic
    final int missing = _uceniciOtisli - _uceniciVracaju;
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
