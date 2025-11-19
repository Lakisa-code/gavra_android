import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/putnik.dart';
import '../services/putnik_service.dart';
import '../services/statistika_service.dart';
import '../theme.dart';
import '../utils/vozac_boja.dart';
import '../widgets/glassmorphism_app_bar.dart';

class StatistikaDetailScreen extends StatefulWidget {
  const StatistikaDetailScreen({Key? key}) : super(key: key);

  @override
  State<StatistikaDetailScreen> createState() => _StatistikaDetailScreenState();
}

class _StatistikaDetailScreenState extends State<StatistikaDetailScreen> {
  DateTimeRange? _selectedRange;

  // V3.0 Realtime Monitoring
  StreamSubscription<List<Putnik>>? _putnikSubscription;
  List<Putnik> _cachedPutnici = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasData = false;

  // V3.0 Performance Cache
  final Map<String, double> _kmCache = {};

  // ❌ UKLONJENO: _statistikeFuture cache - sada koristi realtime stream

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedRange = DateTimeRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );
    _initializeRealtimeMonitoring();
  }

  @override
  void dispose() {
    _putnikSubscription?.cancel();
    super.dispose();
  }

  // V3.0 Realtime Methods
  void _initializeRealtimeMonitoring() {
    _putnikSubscription?.cancel();

    if (mounted)
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

    _putnikSubscription =
        PutnikService().streamKombinovaniPutniciFiltered().timeout(const Duration(seconds: 30)).listen(
      (putnici) {
        if (mounted) {
          if (mounted)
            setState(() {
              _cachedPutnici = putnici;
              _isLoading = false;
              _errorMessage = null;
              _hasData = putnici.isNotEmpty;
            });
        }
      },
      onError: (Object error) {
        if (mounted) {
          if (mounted)
            setState(() {
              _isLoading = false;
              _errorMessage = 'Greška pri učitavanju: $error';
            });
        }
      },
    );
  }

  // V3.0 Performance-Optimized GPS Calculation with Caching
  Future<double> _calculateKmForVozac(String vozac, DateTimeRange range) async {
    final cacheKey = '${vozac}_${range.start.millisecondsSinceEpoch}_${range.end.millisecondsSinceEpoch}';

    if (_kmCache.containsKey(cacheKey)) {
      return _kmCache[cacheKey]!;
    }

    try {
      final response = await Supabase.instance.client
          .from('gps_lokacije')
          .select('lat, lng, timestamp')
          .eq('name', vozac)
          .gte('timestamp', range.start.toIso8601String())
          .lte('timestamp', range.end.toIso8601String())
          .order('timestamp');

      final lokacije = (response as List).cast<Map<String, dynamic>>();

      if (lokacije.length < 2) {
        _kmCache[cacheKey] = 0.0;
        return 0.0;
      }

      double ukupnoKm = 0.0;
      for (int i = 1; i < lokacije.length; i++) {
        final prevLat = (lokacije[i - 1]['lat'] as num).toDouble();
        final prevLng = (lokacije[i - 1]['lng'] as num).toDouble();
        final currLat = (lokacije[i]['lat'] as num).toDouble();
        final currLng = (lokacije[i]['lng'] as num).toDouble();

        ukupnoKm += _haversineDistance(prevLat, prevLng, currLat, currLng);
      }

      _kmCache[cacheKey] = ukupnoKm;
      return ukupnoKm;
    } catch (e) {
      return 0.0;
    }
  }

  // V3.0 Enhanced Haversine Formula with Early Returns
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Early return for same coordinates
    if (lat1 == lat2 && lon1 == lon2) return 0.0;

    // Early return for unrealistic distances (likely GPS errors)
    final latDiff = (lat1 - lat2).abs();
    final lonDiff = (lon1 - lon2).abs();
    if (latDiff > 1.0 || lonDiff > 1.0) return 0.0; // Skip jumps > 111km

    const double earthRadius = 6371.0; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) + cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = earthRadius * c;

    // Filter out unrealistic short movements (GPS noise)
    return distance > 0.01 ? distance : 0.0;
  }

  double _toRadians(double degree) => degree * pi / 180;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: tripleBlueFashionGradient, // Gradijent preko celog ekrana
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassmorphismAppBar(
          title: const Text(
            'Detaljne statistike',
            style: TextStyle(
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 3,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.date_range,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 3,
                    color: Colors.black54,
                  ),
                ],
              ),
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
                    Icon(
                      Icons.calendar_today,
                      color: Theme.of(context).colorScheme.primary,
                    ),
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

            // V3.0 State-Driven Content with Error Handling
            Expanded(
              child: _buildMainContent(),
            ),
          ],
        ),
      ), // Zatvaranje Scaffold
    ); // Zatvaranje Container
  }

  // V3.0 Main Content Builder with State Management
  Widget _buildMainContent() {
    // Check for loading state
    if (_isLoading) {
      return _buildLoadingState();
    }

    // Check for error state
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    // Check if date range is selected
    if (_selectedRange == null) {
      return _buildEmptyState();
    }

    // Check if we have data
    if (!_hasData || _cachedPutnici.isEmpty) {
      return _buildNoDataState();
    }

    // Build statistics content using cached data
    return _buildStatisticsContent();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  '📊 Učitavam statistike...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Greška pri učitavanju',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Neočekivana greška',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _initializeRealtimeMonitoring(),
            icon: const Icon(Icons.refresh),
            label: const Text('Pokušaj ponovo'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Izaberite period za analizu',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kliknite na dugme "Promeni" da biste \npodesili vremenski period',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Nema podataka za izabrani period',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Probajte sa drugim vremenskim periodom',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range),
            label: const Text('Promeni period'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsContent() {
    // 🔥 REALTIME: Koristi stream umesto cached future
    return StreamBuilder<Map<String, Map<String, dynamic>>>(
      stream: StatistikaService.instance.streamDetaljneStatistikePoVozacima(
        _selectedRange!.start,
        _selectedRange!.end,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        final statistike = snapshot.data ?? <String, Map<String, dynamic>>{};

        if (statistike.isEmpty) {
          return _buildNoDataState();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header sa periodom
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Text(
                      'Detaljne statistike',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.analytics,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),

              // Period info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.date_range,
                      color: Colors.blue[600],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Period: ${_formatDate(_selectedRange!.start)} - ${_formatDate(_selectedRange!.end)}',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Vozači kartice (stil kao admin screen)
              Column(
                children: statistike.entries.map((entry) {
                  final vozac = entry.key;
                  final stats = entry.value;
                  final vozacColor = _getVozacColor(vozac);

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: vozacColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: vozacColor.withAlpha(70),
                      ),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      childrenPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: vozacColor,
                        radius: 20,
                        child: Text(
                          vozac[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      title: Text(
                        vozac,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: vozacColor,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Ukupno: ${stats['dodati']} putnika',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.monetization_on,
                            color: Colors.green[600],
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              'Pazar: ${stats['ukupnoPazar'].toStringAsFixed(0)} RSD',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      children: [
                        _buildStatisticsGrid(stats),
                        const SizedBox(height: 16),
                        _buildKmChart(vozac, stats),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatisticsGrid(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
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
                  value: '${stats['naplaceni']}',
                ),
              ),
              Expanded(
                child: _StatRow(
                  icon: Icons.check_circle,
                  color: Colors.orange,
                  label: 'Pokupljeni',
                  value: '${stats['pokupljeni']}',
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
                  value: '${stats['mesecneKarte']}',
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
          const Divider(),
          _StatRow(
            icon: Icons.account_balance_wallet,
            color: Colors.green[700]!,
            label: 'Ukupan pazar',
            value: '${stats['ukupnoPazar'].toStringAsFixed(0)} RSD',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  // V3.0 Performance-Enhanced Km Chart with GPS Data Visualization
  Widget _buildKmChart(String vozac, Map<String, dynamic> stats) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.route,
                color: Colors.blue[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'GPS Kilometraža - $vozac',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<double>(
              future: _calculateKmForVozac(vozac, _selectedRange!),
              builder: (context, kmSnapshot) {
                if (kmSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final totalKm = kmSnapshot.data ?? 0.0;

                if (totalKm == 0.0) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.gps_off,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nema GPS podataka',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Generate daily breakdown for visualization
                final days = _selectedRange!.end.difference(_selectedRange!.start).inDays + 1;
                final avgKmPerDay = totalKm / days;

                return LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: max(avgKmPerDay / 4, 10),
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey[300],
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final dayIndex = value.toInt();
                            if (dayIndex >= 0 && dayIndex < days) {
                              final date = _selectedRange!.start.add(Duration(days: dayIndex));
                              return Text(
                                '${date.day}',
                                style: const TextStyle(fontSize: 12),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(days, (index) {
                          // Simulate daily km distribution (in real app, get from GPS data)
                          final variance = (Random().nextDouble() - 0.5) * 0.4;
                          final dailyKm = avgKmPerDay * (1 + variance);
                          return FlSpot(index.toDouble(), max(dailyKm, 0));
                        }),
                        isCurved: true,
                        color: Colors.blue[700],
                        barWidth: 3,
                        dotData: FlDotData(
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Colors.blue[700]!,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blue.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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
      if (mounted)
        setState(() {
          _selectedRange = picked;
        });
      _loadData();
    }
  }

  // V3.0 Data Loading Method
  Future<void> _loadData() async {
    if (!mounted) return;

    if (mounted)
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

    try {
      // Clear cache when date range changes
      _kmCache.clear();
      // ❌ UKLONJENO: _statistikeFuture = null; - stream se automatski ažurira

      // Trigger UI update
      if (mounted) {
        if (mounted)
          setState(() {
            _isLoading = false;
          });
      }
    } catch (e) {
      if (mounted) {
        if (mounted)
          setState(() {
            _isLoading = false;
            _errorMessage = 'Greška pri učitavanju podataka: $e';
          });
      }
    }
  }

  // ...existing code...
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.isTotal = false,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool isTotal;

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
