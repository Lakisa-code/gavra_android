import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../services/vozac_mapping_service.dart';
import '../theme.dart';
import '../utils/vozac_boja.dart';

/// Screen za detaljne statistike po vozačima
/// Pristup: samo iz admin_screen.dart
class VozaciStatistikaScreen extends StatefulWidget {
  const VozaciStatistikaScreen({Key? key}) : super(key: key);

  @override
  State<VozaciStatistikaScreen> createState() => _VozaciStatistikaScreenState();
}

class _VozaciStatistikaScreenState extends State<VozaciStatistikaScreen> {
  SupabaseClient get _supabase => supabase;

  // Filter opcije
  String _selectedFilter = 'dan'; // dan, nedelja, mesec, godina
  DateTime _selectedDate = DateTime.now();

  // Podaci po vozačima
  Map<String, VozacStats> _statsPoVozacima = {};
  bool _isLoading = true;

  // Fiksni redosled vozača
  final List<String> _vozaciRedosled = ['Bruda', 'Bilevski', 'Bojan', 'Svetlana', 'Ivan'];

  @override
  void initState() {
    super.initState();
    _loadData();
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

  /// Učitaj sve podatke iz voznje_log
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final (from, to) = _getDateRange();
      final fromStr = from.toIso8601String().split('T')[0];
      final toStr = to.toIso8601String().split('T')[0];

      // Dohvati SVE zapise u periodu (voznje, otkazivanja, uplate) sa tipom putnika
      final response = await _supabase
          .from('voznje_log')
          .select('id, datum, tip, iznos, vozac_id, putnik_id, created_at, registrovani_putnici!inner(tip)')
          .gte('datum', fromStr)
          .lte('datum', toStr);

      // Inicijalizuj statistike za sve vozače
      final Map<String, VozacStats> stats = {};
      for (final vozac in _vozaciRedosled) {
        stats[vozac] = VozacStats();
      }

      // Pratimo voznje i uplate po putnik_id za dužnike (samo dnevni putnici)
      // Key: putnik_id, Value: vozac_ime koji je pokupio
      final Map<String, String> dnevniVoznjePoVozacu = {};
      final Set<String> naplaceniPutnici = {};

      // Prvo prolaz - sakupi sve voznje i uplate
      for (final record in response as List) {
        final vozacId = record['vozac_id'] as String?;
        final putnikId = record['putnik_id'] as String?;
        final tip = record['tip'] as String?;
        final iznos = double.tryParse(record['iznos']?.toString() ?? '0') ?? 0;
        final putnikTip = record['registrovani_putnici']?['tip'] as String?;

        if (vozacId == null) continue;

        // Konvertuj UUID u ime vozača
        String vozacIme = VozacMappingService.getVozacImeWithFallbackSync(vozacId) ?? 'Nepoznat';

        // Osiguraj da postoji u mapi
        stats.putIfAbsent(vozacIme, () => VozacStats());

        switch (tip) {
          case 'voznja':
            stats[vozacIme]!.pokupljeni++;
            // Zapamti ko je pokupio ovog putnika - SAMO ako je dnevni
            if (putnikId != null && putnikTip == 'dnevni') {
              dnevniVoznjePoVozacu[putnikId] = vozacIme;
            }
            break;
          case 'otkazivanje':
            stats[vozacIme]!.otkazani++;
            break;
          case 'uplata':
          case 'uplata_mesecna':
          case 'uplata_dnevna':
            stats[vozacIme]!.pazar += iznos;
            // Označi putnika kao naplaćenog
            if (putnikId != null) {
              naplaceniPutnici.add(putnikId);
            }
            break;
        }
      }

      // Drugi prolaz - izračunaj dužnike (dnevne voznje bez uplate)
      for (final entry in dnevniVoznjePoVozacu.entries) {
        final putnikId = entry.key;
        final vozacIme = entry.value;
        if (!naplaceniPutnici.contains(putnikId)) {
          // Ovaj dnevni putnik je pokupljen ali nije platio
          stats[vozacIme]?.duznici++;
        }
      }

      if (!mounted) return;
      setState(() {
        _statsPoVozacima = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška: $e'), backgroundColor: Colors.red),
      );
    }
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

  /// Promeni datum (prethodni/sledeći)
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
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'STATISTIKA VOZAČA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Filter dugmad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFilterButton('Dan', 'dan'),
                    _buildFilterButton('Nedelja', 'nedelja'),
                    _buildFilterButton('Mesec', 'mesec'),
                    _buildFilterButton('Godina', 'godina'),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Navigacija datuma
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                      onPressed: () => _changeDate(-1),
                    ),
                    Text(
                      _formatDateRange(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                      onPressed: () => _changeDate(1),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Lista vozača
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _buildVozaciList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = value);
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.blue.shade700 : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildVozaciList() {
    // Izračunaj ukupne statistike
    int ukupnoPokupljeni = 0;
    int ukupnoOtkazani = 0;
    double ukupnoPazar = 0;
    int ukupnoDuznici = 0;

    for (final stats in _statsPoVozacima.values) {
      ukupnoPokupljeni += stats.pokupljeni;
      ukupnoOtkazani += stats.otkazani;
      ukupnoPazar += stats.pazar;
      ukupnoDuznici += stats.duznici;
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        // Kartice vozača
        ..._vozaciRedosled.map((vozac) {
          final stats = _statsPoVozacima[vozac] ?? VozacStats();
          return _buildVozacCard(vozac, stats);
        }),

        const SizedBox(height: 16),

        // Ukupno kartica
        _buildUkupnoCard(ukupnoPokupljeni, ukupnoOtkazani, ukupnoPazar, ukupnoDuznici),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildVozacCard(String vozac, VozacStats stats) {
    final boja = VozacBoja.getColor(vozac);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            boja.withValues(alpha: 0.8),
            boja.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Ime vozača sa avatarom
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 20,
                  child: Text(
                    vozac[0].toUpperCase(),
                    style: TextStyle(
                      color: boja,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  vozac,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Pazar - istaknuto
                Text(
                  '${stats.pazar.toStringAsFixed(0)} RSD',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Statistike u redu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.check_circle,
                  label: 'Pokupljeni',
                  value: '${stats.pokupljeni}',
                  color: Colors.greenAccent,
                ),
                _buildStatItem(
                  icon: Icons.cancel,
                  label: 'Otkazani',
                  value: '${stats.otkazani}',
                  color: Colors.redAccent,
                ),
                _buildStatItem(
                  icon: Icons.warning,
                  label: 'Dužnici',
                  value: '${stats.duznici}',
                  color: Colors.orangeAccent,
                ),
                _buildStatItem(
                  icon: Icons.attach_money,
                  label: 'Pazar',
                  value: stats.pazar.toStringAsFixed(0),
                  color: Colors.yellowAccent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildUkupnoCard(int pokupljeni, int otkazani, double pazar, int duznici) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade600,
            Colors.green.shade400,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.summarize, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text(
                  'UKUPNO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildUkupnoStatItem(
                  icon: Icons.check_circle,
                  label: 'Pokupljeni',
                  value: '$pokupljeni',
                ),
                _buildUkupnoStatItem(
                  icon: Icons.cancel,
                  label: 'Otkazani',
                  value: '$otkazani',
                ),
                _buildUkupnoStatItem(
                  icon: Icons.warning,
                  label: 'Dužnici',
                  value: '$duznici',
                ),
                _buildUkupnoStatItem(
                  icon: Icons.attach_money,
                  label: 'Pazar',
                  value: pazar.toStringAsFixed(0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUkupnoStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

/// Model za statistike vozača
class VozacStats {
  int pokupljeni;
  int otkazani;
  int duznici;
  double pazar;

  VozacStats({
    this.pokupljeni = 0,
    this.otkazani = 0,
    this.duznici = 0,
    this.pazar = 0,
  });
}
