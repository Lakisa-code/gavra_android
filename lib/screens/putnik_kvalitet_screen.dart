import 'package:flutter/material.dart';

import '../services/putnik_kvalitet_service.dart';

/// 📊 PUTNIK KVALITET SCREEN
/// Analiza kvaliteta putnika za admina/vlasnika
/// Prikazuje putnike sortirane po kvalitetu (najgori prvi)
class PutnikKvalitetScreen extends StatefulWidget {
  const PutnikKvalitetScreen({super.key});

  @override
  State<PutnikKvalitetScreen> createState() => _PutnikKvalitetScreenState();
}

class _PutnikKvalitetScreenState extends State<PutnikKvalitetScreen> {
  List<PutnikKvalitetEntry> _entries = [];
  bool _isLoading = true;
  String _selectedTip = 'ucenik'; // 'ucenik', 'radnik', 'svi'
  int _minVoznji = 0; // Minimalan broj vožnji za prikaz (0 = svi)

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final entries = await PutnikKvalitetService.getKvalitetAnaliza(
      tipPutnika: _selectedTip,
      minVoznji: _minVoznji,
    );

    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Analiza Kvaliteta'),
        centerTitle: true,
        actions: [
          // Filter po minimalnom broju vožnji
          PopupMenuButton<int>(
            icon: Icon(
              Icons.filter_alt,
              color: _minVoznji > 0 ? Colors.green : null,
            ),
            tooltip: 'Min. vožnji',
            onSelected: (min) {
              setState(() => _minVoznji = min);
              _loadData();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 0,
                child: Row(
                  children: [
                    Icon(_minVoznji == 0 ? Icons.check : null, size: 18),
                    const SizedBox(width: 8),
                    const Text('Svi'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 5,
                child: Row(
                  children: [
                    Icon(_minVoznji == 5 ? Icons.check : null, size: 18),
                    const SizedBox(width: 8),
                    const Text('Min 5 vožnji'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 10,
                child: Row(
                  children: [
                    Icon(_minVoznji == 10 ? Icons.check : null, size: 18),
                    const SizedBox(width: 8),
                    const Text('Min 10 vožnji'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 20,
                child: Row(
                  children: [
                    Icon(_minVoznji == 20 ? Icons.check : null, size: 18),
                    const SizedBox(width: 8),
                    const Text('Min 20 vožnji'),
                  ],
                ),
              ),
            ],
          ),
          // Filter po tipu
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter po tipu',
            onSelected: (tip) {
              setState(() => _selectedTip = tip);
              _loadData();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'ucenik',
                child: Row(
                  children: [
                    Icon(_selectedTip == 'ucenik' ? Icons.check : null, size: 18),
                    const SizedBox(width: 8),
                    const Text('Učenici'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'radnik',
                child: Row(
                  children: [
                    Icon(_selectedTip == 'radnik' ? Icons.check : null, size: 18),
                    const SizedBox(width: 8),
                    const Text('Radnici'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'svi',
                child: Row(
                  children: [
                    Icon(_selectedTip == 'svi' ? Icons.check : null, size: 18),
                    const SizedBox(width: 8),
                    const Text('Svi'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('Nema podataka'))
              : Column(
                  children: [
                    // Legenda
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.black12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: const [
                          Text('🟢 >70', style: TextStyle(fontSize: 12)),
                          Text('🟡 40-70', style: TextStyle(fontSize: 12)),
                          Text('🟠 20-40', style: TextStyle(fontSize: 12)),
                          Text('🔴 <20', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),

                    // Statistika
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatCard(
                            '🔴 Kritični',
                            _entries.where((e) => e.kvalitetSkor < 20).length.toString(),
                            Colors.red,
                          ),
                          _buildStatCard(
                            '🟠 Loši',
                            _entries.where((e) => e.kvalitetSkor >= 20 && e.kvalitetSkor < 40).length.toString(),
                            Colors.orange,
                          ),
                          _buildStatCard(
                            '🟡 Srednji',
                            _entries.where((e) => e.kvalitetSkor >= 40 && e.kvalitetSkor < 70).length.toString(),
                            Colors.yellow.shade700,
                          ),
                          _buildStatCard(
                            '🟢 Dobri',
                            _entries.where((e) => e.kvalitetSkor >= 70).length.toString(),
                            Colors.green,
                          ),
                        ],
                      ),
                    ),

                    const Divider(),

                    // Lista putnika
                    Expanded(
                      child: ListView.builder(
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          return _buildPutnikCard(entry, index + 1);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildPutnikCard(PutnikKvalitetEntry entry, int rank) {
    final isKritican = entry.kvalitetSkor < 20;
    final isLos = entry.kvalitetSkor >= 20 && entry.kvalitetSkor < 40;

    Color borderColor;
    if (isKritican) {
      borderColor = Colors.red;
    } else if (isLos) {
      borderColor = Colors.orange;
    } else if (entry.kvalitetSkor < 70) {
      borderColor = Colors.yellow.shade700;
    } else {
      borderColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: borderColor.withValues(alpha: 0.2),
          child: Text(
            entry.status,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Row(
          children: [
            Text(
              '#$rank ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            Expanded(
              child: Text(
                entry.ime,
                style: TextStyle(
                  fontWeight: isKritican || isLos ? FontWeight.bold : FontWeight.normal,
                  color: isKritican ? Colors.red : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              'Kvalitet: ${entry.kvalitetSkor}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: borderColor,
              ),
            ),
            const SizedBox(width: 8),
            Text('| ${entry.prosecnoMesecnoFormatted}/mes'),
            const SizedBox(width: 8),
            Text('| ${entry.voznji30Dana} u 30d'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('📅 Registrovan', entry.registrovanFormatted),
                _buildDetailRow('📆 Meseci', '${entry.mesecRegistrovan}'),
                _buildDetailRow('🚐 Ukupno vožnji', '${entry.ukupnoVoznji}'),
                _buildDetailRow('❌ Ukupno otkazivanja', '${entry.ukupnoOtkazivanja}'),
                _buildDetailRow('📊 Prosečno mesečno', entry.prosecnoMesecnoFormatted),
                _buildDetailRow('📈 Vožnji u 30d', '${entry.voznji30Dana}'),
                _buildDetailRow('✅ Uspešnost', '${entry.uspesnost}%'),
                // Prikaži "Zakazuje unapred" SAMO za učenike
                if (entry.tip == 'ucenik')
                  _buildDetailRow(
                    '⏰ Zakazuje unapred',
                    '${entry.odgovornostStatus} ${entry.prosecnoSatiUnapredFormatted}',
                    color: entry.prosecnoSatiUnapred >= 24 ? Colors.green : Colors.red,
                  ),
                const Divider(),
                _buildDetailRow('🎯 KVALITET SKOR', '${entry.kvalitetSkor}%', bold: true, color: borderColor),
                if (entry.kandidatZaZamenu)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '⚠️ KANDIDAT ZA ZAMENU\nZauzima mesto ali se retko vozi',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
