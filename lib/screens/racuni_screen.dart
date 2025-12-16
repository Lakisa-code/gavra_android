import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/registrovani_putnik.dart';
import '../services/racun_service.dart';
import '../services/registrovani_putnik_service.dart';

/// Ekran za prikaz i štampanje računa na kraju meseca
class RacuniScreen extends StatefulWidget {
  const RacuniScreen({super.key});

  @override
  State<RacuniScreen> createState() => _RacuniScreenState();
}

class _RacuniScreenState extends State<RacuniScreen> {
  final RegistrovaniPutnikService _service = RegistrovaniPutnikService();
  List<RegistrovaniPutnik> _putniciSaRacunom = [];
  Map<String, bool> _selected = {};
  Map<String, int> _brojDana = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPutnike();
  }

  Future<void> _loadPutnike() async {
    setState(() => _loading = true);

    final sviPutnici = await _service.getAllRegistrovaniPutnici();
    final saRacunom = sviPutnici.where((p) => p.trebaRacun && !p.obrisan && p.aktivan).toList();

    // Inicijalizuj selekciju i broj dana
    final selected = <String, bool>{};
    final brojDana = <String, int>{};

    for (final p in saRacunom) {
      selected[p.id] = true; // Svi selektovani po default-u
      brojDana[p.id] = _izracunajRadneDane(p); // Automatski izračunaj
    }

    setState(() {
      _putniciSaRacunom = saRacunom;
      _selected = selected;
      _brojDana = brojDana;
      _loading = false;
    });
  }

  /// Izračunaj broj radnih dana na osnovu radnih dana putnika
  int _izracunajRadneDane(RegistrovaniPutnik putnik) {
    final radniDani = putnik.radniDani.split(',').length;
    // Približno 4 nedelje u mesecu
    return radniDani * 4;
  }

  /// Dobij cenu po danu za putnika
  double _getCenaPoDanu(RegistrovaniPutnik putnik) {
    if (putnik.cenaPoDanu != null && putnik.cenaPoDanu! > 0) {
      return putnik.cenaPoDanu!;
    }
    // Default cene
    switch (putnik.tip.toLowerCase()) {
      case 'radnik':
        return 700;
      case 'ucenik':
        return 600;
      default:
        return 500;
    }
  }

  /// Izračunaj ukupan iznos za putnika
  double _getUkupanIznos(RegistrovaniPutnik putnik) {
    return _getCenaPoDanu(putnik) * (_brojDana[putnik.id] ?? 0);
  }

  /// Štampaj sve selektovane račune
  Future<void> _stampajSve() async {
    final selektovani = _putniciSaRacunom.where((p) => _selected[p.id] == true).toList();

    if (selektovani.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nema selektovanih putnika'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Pripremi podatke za štampanje
    final List<Map<String, dynamic>> racuniPodaci = [];

    for (final putnik in selektovani) {
      racuniPodaci.add({
        'putnik': putnik,
        'brojDana': _brojDana[putnik.id] ?? 0,
        'cenaPoDanu': _getCenaPoDanu(putnik),
        'ukupno': _getUkupanIznos(putnik),
      });
    }

    // Štampaj sve račune
    await RacunService.stampajRacuneZaFirme(
      racuniPodaci: racuniPodaci,
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mesec = DateFormat('MMMM yyyy', 'sr_Latn').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('Računi - $mesec'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPutnike,
            tooltip: 'Osveži',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _putniciSaRacunom.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Nema putnika kojima treba račun',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Uključi "Treba račun" kod putnika',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Zaglavlje sa ukupnim iznosom
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_selected.values.where((v) => v).length} računa',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              Text(
                                'Ukupno: ${NumberFormat('#,###').format(_izracunajUkupno())} RSD',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.print),
                            label: const Text('Štampaj sve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _stampajSve,
                          ),
                        ],
                      ),
                    ),
                    // Lista putnika
                    Expanded(
                      child: ListView.builder(
                        itemCount: _putniciSaRacunom.length,
                        itemBuilder: (context, index) {
                          final putnik = _putniciSaRacunom[index];
                          return _buildPutnikCard(putnik);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  double _izracunajUkupno() {
    double ukupno = 0;
    for (final putnik in _putniciSaRacunom) {
      if (_selected[putnik.id] == true) {
        ukupno += _getUkupanIznos(putnik);
      }
    }
    return ukupno;
  }

  Widget _buildPutnikCard(RegistrovaniPutnik putnik) {
    final isSelected = _selected[putnik.id] ?? false;
    final cenaPoDanu = _getCenaPoDanu(putnik);
    final brojDana = _brojDana[putnik.id] ?? 0;
    final ukupno = _getUkupanIznos(putnik);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? null : Colors.grey[200],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Red 1: Checkbox + Ime + Tip
            Row(
              children: [
                Checkbox(
                  value: isSelected,
                  activeColor: Colors.green,
                  onChanged: (value) {
                    setState(() => _selected[putnik.id] = value ?? false);
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        putnik.putnikIme,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${putnik.tip} • ${putnik.firmaNaziv ?? "Bez firme"}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(),
            // Red 2: Kalkulacija
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Broj dana (editabilno)
                Row(
                  children: [
                    const Text('Dana: '),
                    SizedBox(
                      width: 50,
                      child: TextFormField(
                        initialValue: brojDana.toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _brojDana[putnik.id] = int.tryParse(value) ?? 0;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // Cena po danu
                Text('× ${cenaPoDanu.toStringAsFixed(0)} RSD'),
                // Ukupno
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${NumberFormat('#,###').format(ukupno)} RSD',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
