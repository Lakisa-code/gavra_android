import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/putnik.dart';
import '../services/statistika_service.dart';
import '../services/putnik_service.dart'; // 🔄 DODANO za realtime
import '../utils/vozac_boja.dart'; // 🎯 DODANO za konzistentne boje

import '../widgets/custom_back_button.dart';

class StatistikaDetailScreen extends StatefulWidget {
  const StatistikaDetailScreen({Key? key}) : super(key: key);

  @override
  State<StatistikaDetailScreen> createState() => _StatistikaDetailScreenState();
}

class _StatistikaDetailScreenState extends State<StatistikaDetailScreen> {
  DateTimeRange? _selectedRange;
  // Uklonjen _allPutnici jer koristimo StreamBuilder

  @override
  void initState() {
    super.initState();
    // Podesiti početni period - poslednja 7 dana
    final now = DateTime.now();
    _selectedRange = DateTimeRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    // Ovo bi trebalo da učita iz servisa
    // _allPutnici = await _putnikService.getAllPutnici();
    setState(() {});
  }

  // ...existing code...

  // ...existing code...

  Future<double> _kmZaVozaca(String vozac, DateTimeRange? range) async {
    if (range == null) return 0;
    final response = await Supabase.instance.client
        .from('gps_lokacije')
        .select()
        .eq('name', vozac)
        .gte('timestamp', range.start.toIso8601String())
        .lte('timestamp', range.end.toIso8601String());
    final lokacije = (response as List).cast<Map<String, dynamic>>();
    lokacije.sort((a, b) =>
        (a['timestamp'] as String).compareTo(b['timestamp'] as String));
    double ukupno = 0;
    for (int i = 1; i < lokacije.length; i++) {
      ukupno += _distanceKm(
        (lokacije[i - 1]['lat'] as num).toDouble(),
        (lokacije[i - 1]['lng'] as num).toDouble(),
        (lokacije[i]['lat'] as num).toDouble(),
        (lokacije[i]['lng'] as num).toDouble(),
      );
    }
    return ukupno;
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;
    double dLat = (lat2 - lat1) * pi / 180.0;
    double dLon = (lon2 - lon1) * pi / 180.0;
    double a = 0.5 -
        cos(dLat) / 2 +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * (1 - cos(dLon)) / 2;
    return R * 2 * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const GradientBackButton(),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x304F7EFC),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
              BoxShadow(
                color: Color(0x204F7EFC),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
        ),
        title: const Text('Detaljne statistike',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          // Period selector
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedRange != null
                          ? 'Period: ${_formatDate(_selectedRange!.start)} - ${_formatDate(_selectedRange!.end)}'
                          : 'Izaberite period',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _selectDateRange,
                    child: const Text('Promeni'),
                  ),
                ],
              ),
            ),
          ),

          // 🔄 POBOLJŠANO: StreamBuilder + FutureBuilder za REALTIME
          Expanded(
            child: _selectedRange == null
                ? const Center(
                    child: Text('Nema podataka za izabrani period'),
                  )
                : StreamBuilder<List<Putnik>>(
                    stream: PutnikService()
                        .streamKombinovaniPutniciFiltered(), // ✅ Server-filtered combined stream
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return FutureBuilder<Map<String, Map<String, dynamic>>>(
                        future: StatistikaService.detaljneStatistikePoVozacima(
                          snapshot.data!,
                          _selectedRange!.start,
                          _selectedRange!.end,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final statistike =
                              snapshot.data ?? <String, Map<String, dynamic>>{};

                          if (statistike.isEmpty) {
                            return const Center(
                              child: Text('Nema podataka za izabrani period'),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: statistike.length,
                            itemBuilder: (context, index) {
                              final vozac = statistike.keys.elementAt(index);
                              final stats = statistike[vozac]!;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getVozacColor(vozac),
                                    child: Text(
                                      vozac[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    vozac,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Ukupno: ${stats['dodati']} putnika | Pazar: ${stats['ukupnoPazar'].toStringAsFixed(0)} RSD',
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _StatRow(
                                                  icon: Icons.person_add,
                                                  color: Colors.green,
                                                  label: 'Dodati',
                                                  value: '${stats['dodati']}',
                                                ),
                                              ),
                                              Expanded(
                                                child: _StatRow(
                                                  icon: Icons.cancel,
                                                  color: Colors.red,
                                                  label: 'Otkazani',
                                                  value: '${stats['otkazani']}',
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _StatRow(
                                                  icon: Icons.payment,
                                                  color: Colors.blue,
                                                  label: 'Naplaćeni',
                                                  value:
                                                      '${stats['naplaceni']}',
                                                ),
                                              ),
                                              Expanded(
                                                child: _StatRow(
                                                  icon: Icons.check_circle,
                                                  color: Colors.orange,
                                                  label: 'Pokupljeni',
                                                  value:
                                                      '${stats['pokupljeni']}',
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _StatRow(
                                                  icon: Icons.credit_card,
                                                  color: Colors.purple,
                                                  label: 'Mesečne karte',
                                                  value:
                                                      '${stats['mesecneKarte']}',
                                                ),
                                              ),
                                              Expanded(
                                                child: _StatRow(
                                                  icon: Icons.warning,
                                                  color: Colors.red[700]!,
                                                  label: 'Dugovi',
                                                  value: '${stats['dugovi']}',
                                                ),
                                              ),
                                            ],
                                          ),
                                          Builder(
                                            builder: (context) {
                                              return FutureBuilder<double>(
                                                future: _kmZaVozaca(
                                                    vozac, _selectedRange),
                                                builder: (context, snapshot) {
                                                  String km;
                                                  Color color = Colors.blueGrey;
                                                  if (snapshot
                                                          .connectionState ==
                                                      ConnectionState.waiting) {
                                                    km = '0';
                                                    color = Colors.grey;
                                                  } else if (snapshot
                                                      .hasError) {
                                                    km = '0';
                                                    color = Colors.grey;
                                                  } else if (snapshot.hasData) {
                                                    km = snapshot.data!
                                                        .toStringAsFixed(1);
                                                  } else {
                                                    km = '0';
                                                    color = Colors.grey;
                                                  }
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 8.0),
                                                    child: _StatRow(
                                                      icon: Icons.route,
                                                      color: color,
                                                      label:
                                                          'Ukupna kilometraža',
                                                      value: '$km km',
                                                      isTotal: true,
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                          const Divider(),
                                          _StatRow(
                                            icon: Icons.account_balance_wallet,
                                            color: Colors.green[700]!,
                                            label: 'Ukupan pazar',
                                            value:
                                                '${stats['ukupnoPazar'].toStringAsFixed(0)} RSD',
                                            isTotal: true,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ); // 🔹 ZATVARAMO ListView.builder
                        }, // 🔹 ZATVARAMO FutureBuilder builder
                      ); // 🔹 ZATVARAMO FutureBuilder
                    }, // 🔹 ZATVARAMO StreamBuilder builder
                  ), // 🔹 ZATVARAMO StreamBuilder
          ), // 🔹 ZATVARAMO Expanded
        ], // 🔹 ZATVARAMO Column children
      ), // 🔹 ZATVARAMO Column
    ); // 🔹 ZATVARAMO Scaffold
  }

  Color _getVozacColor(String vozac) {
    // 🎯 KORISTI CENTRALIZOVANE BOJE VOZAČA
    return VozacBoja.get(vozac);
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange,
    );

    if (picked != null) {
      setState(() {
        _selectedRange = picked;
      });
      _loadData();
    }
  }

  // ...existing code...
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool isTotal;

  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 16 : 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
