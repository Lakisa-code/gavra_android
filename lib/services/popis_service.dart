import 'package:flutter/material.dart';

import '../models/putnik.dart';
import '../services/daily_checkin_service.dart';
import '../services/putnik_service.dart';
import '../services/statistika_service.dart';
import '../utils/vozac_boja.dart';

/// 🎯 MODEL ZA PODATKE POPISA
class PopisData {
  final String vozac;
  final DateTime datum;
  final double ukupanPazar;
  final double sitanNovac;
  final int dodatiPutnici;
  final int otkazaniPutnici;
  final int naplaceniPutnici;
  final int pokupljeniPutnici;
  final int dugoviPutnici;
  final int mesecneKarte;
  final double kilometraza;

  const PopisData({
    required this.vozac,
    required this.datum,
    required this.ukupanPazar,
    required this.sitanNovac,
    required this.dodatiPutnici,
    required this.otkazaniPutnici,
    required this.naplaceniPutnici,
    required this.pokupljeniPutnici,
    required this.dugoviPutnici,
    required this.mesecneKarte,
    required this.kilometraza,
  });

  Map<String, dynamic> toMap() => {
        'ukupanPazar': ukupanPazar,
        'sitanNovac': sitanNovac,
        'dodatiPutnici': dodatiPutnici,
        'otkazaniPutnici': otkazaniPutnici,
        'naplaceniPutnici': naplaceniPutnici,
        'pokupljeniPutnici': pokupljeniPutnici,
        'dugoviPutnici': dugoviPutnici,
        'mesecneKarte': mesecneKarte,
        'kilometraza': kilometraza,
      };
}

/// 📊 SERVIS ZA POPIS DANA
/// Centralizuje logiku za učitavanje i čuvanje popisa
class PopisService {
  static final _putnikService = PutnikService();

  /// Učitaj podatke za popis
  static Future<PopisData> loadPopisData({
    required String vozac,
    required String selectedGrad,
    required String selectedVreme,
  }) async {
    final today = DateTime.now();
    final dayStart = DateTime(today.year, today.month, today.day);
    final dayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

    // 1. REALTIME STREAM ZA KOMBINOVANE PUTNIKE
    late List<Putnik> putnici;
    try {
      final isoDate = DateTime.now().toIso8601String().split('T')[0];
      final stream = _putnikService.streamKombinovaniPutniciFiltered(
        isoDate: isoDate,
        grad: selectedGrad,
        vreme: selectedVreme,
      );
      putnici = await stream.first.timeout(const Duration(seconds: 10));
    } catch (e) {
      putnici = [];
    }

    // 2. REALTIME DETALJNE STATISTIKE
    final detaljneStats = await StatistikaService.instance.detaljneStatistikePoVozacima(putnici, dayStart, dayEnd);
    final vozacStats = detaljneStats[vozac] ?? {};

    // 3. REALTIME PAZAR STREAM
    late double ukupanPazar;
    try {
      ukupanPazar = await StatistikaService.streamPazarZaVozaca(
        vozac: vozac,
        from: dayStart,
        to: dayEnd,
      ).first.timeout(const Duration(seconds: 10));
    } catch (e) {
      ukupanPazar = 0.0;
    }

    // 4. SITAN NOVAC
    final sitanNovac = await DailyCheckInService.getTodayAmount(vozac) ?? 0.0;

    // 5. MAPIRANJE PODATAKA
    final dodatiPutnici = (vozacStats['dodati'] ?? 0) as int;
    final otkazaniPutnici = (vozacStats['otkazani'] ?? 0) as int;
    final naplaceniPutnici = (vozacStats['naplaceni'] ?? 0) as int;
    final pokupljeniPutnici = (vozacStats['pokupljeni'] ?? 0) as int;
    final dugoviPutnici = (vozacStats['dugovi'] ?? 0) as int;
    final mesecneKarte = (vozacStats['mesecneKarte'] ?? 0) as int;

    // 6. KILOMETRAŽA
    late double kilometraza;
    try {
      kilometraza = await StatistikaService.instance.getKilometrazu(vozac, dayStart, dayEnd);
    } catch (e) {
      kilometraza = 0.0;
    }

    return PopisData(
      vozac: vozac,
      datum: today,
      ukupanPazar: ukupanPazar,
      sitanNovac: sitanNovac,
      dodatiPutnici: dodatiPutnici,
      otkazaniPutnici: otkazaniPutnici,
      naplaceniPutnici: naplaceniPutnici,
      pokupljeniPutnici: pokupljeniPutnici,
      dugoviPutnici: dugoviPutnici,
      mesecneKarte: mesecneKarte,
      kilometraza: kilometraza,
    );
  }

  /// Sačuvaj popis u bazu
  static Future<void> savePopis(PopisData data) async {
    await DailyCheckInService.saveDailyReport(data.vozac, data.datum, data.toMap());
    await DailyCheckInService.saveCheckIn(data.vozac, data.sitanNovac);
  }

  /// Prikaži popis dialog i vrati true ako korisnik želi da sačuva
  static Future<bool> showPopisDialog(BuildContext context, PopisData data) async {
    final vozacColor = VozacBoja.get(data.vozac);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person, color: vozacColor, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'POPIS - ${data.datum.day}.${data.datum.month}.${data.datum.year}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.all(0),
              elevation: 4,
              color: vozacColor.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: vozacColor.withValues(alpha: 0.6), width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER SA VOZAČEM
                    Row(
                      children: [
                        Icon(Icons.person, color: vozacColor, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          data.vozac,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // DETALJNE STATISTIKE
                    _buildStatRow('Dodati putnici', data.dodatiPutnici, Icons.add_circle, Colors.blue),
                    _buildStatRow('Otkazani', data.otkazaniPutnici, Icons.cancel, Colors.red),
                    _buildStatRow('Naplaćeni', data.naplaceniPutnici, Icons.payment, Colors.green),
                    _buildStatRow('Pokupljeni', data.pokupljeniPutnici, Icons.check_circle, Colors.orange),
                    _buildStatRow('Dugovi', data.dugoviPutnici, Icons.warning, Colors.redAccent),
                    _buildStatRow('Mesečne karte', data.mesecneKarte, Icons.card_membership, Colors.purple),
                    _buildStatRow('Kilometraža', '${data.kilometraza.toStringAsFixed(1)} km', Icons.route, Colors.teal),

                    Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),

                    // UKUPAN PAZAR
                    _buildStatRow(
                      'Ukupno pazar',
                      '${data.ukupanPazar.toStringAsFixed(0)} RSD',
                      Icons.monetization_on,
                      Colors.amber,
                    ),

                    const SizedBox(height: 12),

                    // SITAN NOVAC
                    if (data.sitanNovac > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Sitan novac: ${data.sitanNovac.toStringAsFixed(0)} RSD',
                              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Text(
                        '📋 Ovaj popis će biti sačuvan i prikazan pri sledećem check-in-u.',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Otkaži')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.save),
            label: const Text('Sačuvaj popis'),
            style: ElevatedButton.styleFrom(
              backgroundColor: vozacColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Helper za kreiranje reda statistike
  static Widget _buildStatRow(String label, dynamic value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(
            value.toString(),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
