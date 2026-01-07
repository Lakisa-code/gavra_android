import 'package:flutter/material.dart';

import '../services/predikcija_service.dart';

/// 🔮 PREDIKCIJA SCREEN
/// Prikazuje predviđeni raspored za sledeću nedelju
class PredikcijaScreen extends StatefulWidget {
  const PredikcijaScreen({super.key});

  @override
  State<PredikcijaScreen> createState() => _PredikcijaScreenState();
}

class _PredikcijaScreenState extends State<PredikcijaScreen> {
  Map<String, Map<String, List<PutnikPredikcija>>> _predikcija = {};
  Map<String, PredikcijaStats> _stats = {};
  bool _isLoading = true;
  String _selectedDan = 'pon';

  final List<String> _dani = ['pon', 'uto', 'sre', 'cet', 'pet'];
  final Map<String, String> _daniPunoIme = {
    'pon': 'Ponedeljak',
    'uto': 'Utorak',
    'sre': 'Sreda',
    'cet': 'Četvrtak',
    'pet': 'Petak',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final predikcija = await PredikcijaService.getPredikcijaZaNedelju();
    final stats = await PredikcijaService.getStatistikaZaNedelju();

    setState(() {
      _predikcija = predikcija;
      _stats = stats;
      _isLoading = false;
    });
  }

  /// Izračunaj datum za dan u sledećoj nedelji
  String _getDatumZaDan(String dan) {
    final now = DateTime.now();
    final daniMapa = {'pon': 1, 'uto': 2, 'sre': 3, 'cet': 4, 'pet': 5};
    final targetWeekday = daniMapa[dan] ?? 1;

    // Nađi sledeći ponedeljak
    int daysUntilNextMonday = (8 - now.weekday) % 7;
    if (daysUntilNextMonday == 0) daysUntilNextMonday = 7; // Ako je danas ponedeljak, uzmi sledeći

    final nextMonday = now.add(Duration(days: daysUntilNextMonday));
    final targetDate = nextMonday.add(Duration(days: targetWeekday - 1));

    return '${targetDate.day}.${targetDate.month}.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔮 Predikcija'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Osveži',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header sa naslovom
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Sledeća nedelja',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tabs za dane
                Container(
                  height: 50,
                  color: Colors.grey.shade100,
                  child: Row(
                    children: _dani.map((dan) {
                      final isSelected = dan == _selectedDan;
                      final stats = _stats[dan];

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedDan = dan),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: isSelected ? Colors.blue.shade700 : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  dan.toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.black87,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${stats?.ukupnoPutnika ?? 0}',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white70 : Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Info za izabrani dan
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_daniPunoIme[_selectedDan]} ${_getDatumZaDan(_selectedDan)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          _buildLegendItem('✓', 'Siguran', Colors.green),
                          const SizedBox(width: 12),
                          _buildLegendItem('?', 'Neizvestan', Colors.orange),
                        ],
                      ),
                    ],
                  ),
                ),

                // Lista termina
                Expanded(
                  child: _buildDanContent(),
                ),
              ],
            ),
    );
  }

  Widget _buildLegendItem(String symbol, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(symbol, style: TextStyle(color: color, fontSize: 12)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildDanContent() {
    final danData = _predikcija[_selectedDan] ?? {};

    if (danData.isEmpty) {
      return const Center(
        child: Text(
          'Nema zakazanih putnika za ovaj dan',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Sortiraj vremena
    final vremena = danData.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: vremena.length,
      itemBuilder: (context, index) {
        final vreme = vremena[index];
        final putnici = danData[vreme]!;

        return _buildTerminCard(vreme, putnici);
      },
    );
  }

  Widget _buildTerminCard(String vreme, List<PutnikPredikcija> putnici) {
    final kapacitet = 8;
    final popunjenost = putnici.length;
    final isPun = popunjenost >= kapacitet;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPun ? Colors.red : Colors.grey.shade300,
          width: isPun ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header termina
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isPun ? Colors.red.shade50 : Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 20,
                      color: isPun ? Colors.red : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      vreme,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isPun ? Colors.red : Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPun ? Colors.red : Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🚐 $popunjenost/$kapacitet',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista putnika
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: putnici.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final putnik = putnici[index];
              return _buildPutnikTile(putnik);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPutnikTile(PutnikPredikcija putnik) {
    Color statusColor;
    if (putnik.verovatnoca >= 80) {
      statusColor = Colors.green;
    } else if (putnik.verovatnoca >= 50) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.red;
    }

    return ListTile(
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          putnik.statusEmoji,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      title: Text(
        putnik.ime,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${putnik.tip == 'ucenik' ? '🎓' : '👷'} ${putnik.grad}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${putnik.verovatnoca}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: statusColor,
              fontSize: 16,
            ),
          ),
          Text(
            '${putnik.brojVoznjiU8Nedelja}/8 ned.',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
