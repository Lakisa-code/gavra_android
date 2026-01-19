import 'package:flutter/material.dart';

import '../services/putnik_kvalitet_service_v2.dart';

/// 📊 PUTNIK KVALITET SCREEN V2
/// Jednostavan prikaz kvaliteta putnika sa 5 boja
class PutnikKvalitetScreenV2 extends StatefulWidget {
  const PutnikKvalitetScreenV2({super.key});

  @override
  State<PutnikKvalitetScreenV2> createState() => _PutnikKvalitetScreenV2State();
}

class _PutnikKvalitetScreenV2State extends State<PutnikKvalitetScreenV2> {
  List<PutnikKvalitetV2> _putnici = [];
  bool _isLoading = true;
  String _selectedTip = 'ucenik';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final rezultati = await PutnikKvalitetServiceV2.getKvalitetAnaliza(
      tipPutnika: _selectedTip,
    );

    setState(() {
      _putnici = rezultati;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Kvalitet Putnika'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (tip) {
              setState(() => _selectedTip = tip);
              _loadData();
            },
            itemBuilder: (context) => [
              _buildMenuItem('ucenik', 'Učenici'),
              _buildMenuItem('radnik', 'Radnici'),
              _buildMenuItem('dnevni', 'Dnevni'),
              _buildMenuItem('svi', 'Svi'),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _putnici.isEmpty
              ? const Center(child: Text('Nema podataka'))
              : Column(
                  children: [
                    // Legenda
                    _buildLegenda(),

                    // Statistika
                    _buildStatistika(),

                    const Divider(height: 1),

                    // Lista putnika
                    Expanded(
                      child: ListView.builder(
                        itemCount: _putnici.length,
                        itemBuilder: (context, index) {
                          return _buildPutnikCard(_putnici[index], index + 1);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(_selectedTip == value ? Icons.check : null, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildLegenda() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text('🟢 Odličan', style: TextStyle(fontSize: 11)),
          Text('🟡 Dobar', style: TextStyle(fontSize: 11)),
          Text('🟠 Srednji', style: TextStyle(fontSize: 11)),
          Text('🔴 Loš', style: TextStyle(fontSize: 11)),
          Text('⚫ Kritičan', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStatistika() {
    final odlicni = _putnici.where((p) => p.ukupniSkor <= 1.8).length;
    final dobri = _putnici.where((p) => p.ukupniSkor > 1.8 && p.ukupniSkor <= 2.6).length;
    final srednji = _putnici.where((p) => p.ukupniSkor > 2.6 && p.ukupniSkor <= 3.4).length;
    final losi = _putnici.where((p) => p.ukupniSkor > 3.4 && p.ukupniSkor <= 4.2).length;
    final kriticni = _putnici.where((p) => p.ukupniSkor > 4.2).length;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBox('$odlicni', Colors.green),
          _buildStatBox('$dobri', Colors.yellow.shade700),
          _buildStatBox('$srednji', Colors.orange),
          _buildStatBox('$losi', Colors.red),
          _buildStatBox('$kriticni', Colors.grey.shade900),
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, Color color) {
    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPutnikCard(PutnikKvalitetV2 putnik, int rank) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: putnik.boja, width: 2),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: putnik.boja.withValues(alpha: 0.2),
          child: Text(
            putnik.bojaEmoji,
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
                putnik.ime,
                style: TextStyle(
                  fontWeight: putnik.ukupniSkor > 3.4 ? FontWeight.bold : FontWeight.normal,
                  color: putnik.ukupniSkor > 4.2 ? Colors.red : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${putnik.nivoOpis} | Vožnji: ${putnik.brojVoznji}',
          style: TextStyle(color: putnik.boja),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetalj('🚐 Broj vožnji', '${putnik.brojVoznji}'),
                _buildDetalj('❌ Otkazivanja', '${putnik.brojOtkazivanja}'),
                _buildDetalj('🔄 Promene vremena', '${putnik.brojPromenaVremena}'),
                _buildDetalj('💰 Prosečno plaća', '${putnik.prosecniDanPlacanja}. u mesecu'),
                _buildDetalj('⏰ Prosečno zakazuje', '${putnik.prosecniSatZakazivanja}:00h'),
                const Divider(),
                const Text('SKOROVI (1=najbolje, 5=najgore):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                _buildSkorRow('Vožnji', putnik.skorVoznji),
                _buildSkorRow('Otkazivanja', putnik.skorOtkazivanja),
                _buildSkorRow('Promene', putnik.skorPromena),
                _buildSkorRow('Plaćanje', putnik.skorPlacanja),
                _buildSkorRow('Zakazivanje', putnik.skorZakazivanja),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'UKUPNO: ${putnik.ukupniSkor.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: putnik.boja,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(putnik.bojaEmoji, style: const TextStyle(fontSize: 24)),
                  ],
                ),
                if (putnik.ukupniSkor > 4.2)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
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
                            '⚠️ KANDIDAT ZA ZAMENU',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
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

  Widget _buildDetalj(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSkorRow(String label, int skor) {
    Color color;
    if (skor == 1) {
      color = Colors.green;
    } else if (skor == 2) {
      color = Colors.yellow.shade700;
    } else if (skor == 3) {
      color = Colors.orange;
    } else if (skor == 4) {
      color = Colors.red;
    } else {
      color = Colors.grey.shade900;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          ...List.generate(5, (i) {
            final isFilled = i < skor;
            return Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: isFilled ? color : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
          const Spacer(),
          Text('$skor/5', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
