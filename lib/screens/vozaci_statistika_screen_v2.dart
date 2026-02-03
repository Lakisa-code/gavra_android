import 'package:flutter/material.dart';

import '../services/voznje_log_service.dart';
import '../theme.dart';
import '../utils/vozac_boja.dart';

/// 📊 VOZACI STATISTIKA SCREEN V2
class VozaciStatistikaScreenV2 extends StatefulWidget {
  const VozaciStatistikaScreenV2({super.key});

  @override
  State<VozaciStatistikaScreenV2> createState() => _VozaciStatistikaScreenV2State();
}

class _VozaciStatistikaScreenV2State extends State<VozaciStatistikaScreenV2> {
  // Filter opcije
  String _selectedFilter = 'mesec'; // dan, nedelja, mesec, godina
  DateTime _selectedDate = DateTime.now();

  // Fiksni redosled vozača sa emoji
  final Map<String, String> _vozaciEmoji = {
    'Bruda': '🚐',
    'Bilevski': '🚗',
    'Bojan': '🚙',
    'Svetlana': '🚕',
    'Ivan': '🚘',
  };

  List<String> get _vozaciRedosled => _vozaciEmoji.keys.toList();

  @override
  void initState() {
    super.initState();
  }

  /// Računaj datumski opseg na osnovu filtera
  (DateTime, DateTime) _getDateRange() {
    final now = _selectedDate;

    switch (_selectedFilter) {
      case 'dan':
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (start, end);

      case 'nedelja':
        final weekday = now.weekday;
        final monday = now.subtract(Duration(days: weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        final start = DateTime(monday.year, monday.month, monday.day);
        final end = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
        return (start, end);

      case 'mesec':
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return (start, end);

      case 'godina':
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31, 23, 59, 59);
        return (start, end);

      default:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (start, end);
    }
  }

  /// 🛰️ STREAM ZA STATISTIKE - KORISTI REALTIME IZ VoznjeLogService
  Stream<Map<String, VozacStatsV2>> _streamStats() {
    final (from, to) = _getDateRange();

    // Koristi realtime stream iz VoznjeLogService
    return VoznjeLogService.streamDetaljneStatistikePoVozacima(
      from: from,
      to: to,
      vozaciLista: _vozaciRedosled,
    ).map((detaljneStats) {
      // Konvertuj iz Map<String, dynamic> u Map<String, VozacStatsV2>
      final Map<String, VozacStatsV2> stats = {};

      for (final vozac in _vozaciRedosled) {
        if (detaljneStats.containsKey(vozac)) {
          final stat = detaljneStats[vozac];
          stats[vozac] = VozacStatsV2(
            pokupljeni: stat['pokupljeni'] ?? 0,
            otkazani: stat['otkazani'] ?? 0,
            duznici: stat['duznici'] ?? 0,
            pazar: (stat['pazar'] ?? 0.0).toDouble(),
          );
        } else {
          stats[vozac] = VozacStatsV2();
        }
      }

      return stats;
    });
  }

  /// Format datuma za prikaz
  String _formatDateRange() {
    final (from, to) = _getDateRange();

    switch (_selectedFilter) {
      case 'dan':
        return '${from.day}.${from.month}.${from.year}';
      case 'nedelja':
        return '${from.day}.${from.month} - ${to.day}.${to.month}.${to.year}';
      case 'mesec':
        const meseci = [
          '',
          'Januar',
          'Februar',
          'Mart',
          'April',
          'Maj',
          'Jun',
          'Jul',
          'Avgust',
          'Septembar',
          'Oktobar',
          'Novembar',
          'Decembar'
        ];
        return '${meseci[from.month]} ${from.year}';
      case 'godina':
        return '${from.year}';
      default:
        return '';
    }
  }

  /// Promeni datum
  void _changeDate(int delta) {
    setState(() {
      switch (_selectedFilter) {
        case 'dan':
          _selectedDate = _selectedDate.add(Duration(days: delta));
          break;
        case 'nedelja':
          _selectedDate = _selectedDate.add(Duration(days: delta * 7));
          break;
        case 'mesec':
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta, 1);
          break;
        case 'godina':
          _selectedDate = DateTime(_selectedDate.year + delta, 1, 1);
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, VozacStatsV2>>(
      stream: _streamStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        final isLoading = snapshot.connectionState == ConnectionState.waiting && stats.isEmpty;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('📊 Statistike Vozača', style: TextStyle(fontWeight: FontWeight.bold)),
            automaticallyImplyLeading: false,
          ),
          body: Container(
            decoration: BoxDecoration(gradient: Theme.of(context).backgroundGradient),
            child: SafeArea(
              child: Column(
                children: [
                  // Filter header
                  _buildFilterHeader(),

                  // Lista statistika
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : RefreshIndicator(
                            onRefresh: () async {
                              setState(() {}); // Forsira ponovno pokretanje stream-a
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _vozaciRedosled.length,
                              itemBuilder: (context, index) {
                                final vozac = _vozaciRedosled[index];
                                return _buildVozacCard(vozac, stats[vozac] ?? VozacStatsV2());
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      color: Theme.of(context).primaryColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // Filter dugmad
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFilterChip('Dan', 'dan'),
              _buildFilterChip('Nedelja', 'nedelja'),
              _buildFilterChip('Mesec', 'mesec'),
              _buildFilterChip('Godina', 'godina'),
            ],
          ),

          const SizedBox(height: 12),

          // Navigacija datuma
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: () => _changeDate(-1),
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  _formatDateRange(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: () => _changeDate(1),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Theme.of(context).primaryColor : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildVozacCard(String vozac, VozacStatsV2 stats) {
    final boja = VozacBoja.getColor(vozac);
    final emoji = _vozaciEmoji[vozac] ?? '🚗';
    final uspesnost = stats.pokupljeni + stats.otkazani > 0
        ? ((stats.pokupljeni / (stats.pokupljeni + stats.otkazani)) * 100).round()
        : 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Možda detaljan prikaz u budućnosti
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: boja, width: 4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header - Ime i pazar
                Row(
                  children: [
                    // Emoji i ime
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: boja.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vozac,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$uspesnost% uspešnost',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getUspesnostColor(uspesnost),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Pazar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          stats.pazar.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: boja,
                          ),
                        ),
                        Text(
                          'RSD',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Statistike
                Row(
                  children: [
                    Expanded(child: _buildVozacStat('✅', stats.pokupljeni, 'pokupljeni', Colors.green)),
                    Expanded(child: _buildVozacStat('❌', stats.otkazani, 'otkazani', Colors.red)),
                    Expanded(child: _buildVozacStat('⚠️', stats.duznici, 'dužnici', Colors.orange)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVozacStat(String emoji, int value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getUspesnostColor(int uspesnost) {
    if (uspesnost >= 90) return Colors.green;
    if (uspesnost >= 75) return Colors.lightGreen;
    if (uspesnost >= 60) return Colors.orange;
    return Colors.red;
  }
}

/// Model za statistike vozača V2
class VozacStatsV2 {
  int pokupljeni;
  int otkazani;
  int duznici;
  double pazar;

  VozacStatsV2({
    this.pokupljeni = 0,
    this.otkazani = 0,
    this.duznici = 0,
    this.pazar = 0,
  });
}
