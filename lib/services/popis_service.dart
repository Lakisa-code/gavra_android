import 'package:flutter/material.dart';

import '../services/daily_checkin_service.dart';
import '../services/statistika_service.dart';
import '../services/voznje_log_service.dart';
import '../utils/vozac_boja.dart';

/// 🎯 MODEL ZA PODATKE POPISA
class PopisData {
  final String vozac;
  final DateTime datum;
  final double ukupanPazar;
  final double sitanNovac;
  final int otkazaniPutnici;
  final int pokupljeniPutnici;
  final int naplaceniDnevni;
  final int naplaceniMesecni;
  final int dugoviPutnici;
  final double kilometraza;
  final bool automatskiGenerisan;

  const PopisData({
    required this.vozac,
    required this.datum,
    required this.ukupanPazar,
    required this.sitanNovac,
    required this.otkazaniPutnici,
    required this.pokupljeniPutnici,
    this.naplaceniDnevni = 0,
    this.naplaceniMesecni = 0,
    required this.dugoviPutnici,
    required this.kilometraza,
    this.automatskiGenerisan = false,
  });

  Map<String, dynamic> toMap() => {
        'vozac': vozac,
        'datum': datum.toIso8601String(),
        'ukupanPazar': ukupanPazar,
        'sitanNovac': sitanNovac,
        'otkazaniPutnici': otkazaniPutnici,
        'pokupljeniPutnici': pokupljeniPutnici,
        'naplaceniPutnici': naplaceniDnevni, // Kompatibilnost
        'mesecneKarte': naplaceniMesecni, // Kompatibilnost
        'dugoviPutnici': dugoviPutnici,
        'kilometraza': kilometraza,
        'automatskiGenerisan': automatskiGenerisan,
        'timestamp': DateTime.now().toIso8601String(),
      };
}

/// 📊 SERVIS ZA POPIS DANA
/// Centralizuje logiku za učitavanje i čuvanje popisa
class PopisService {
  /// Učitaj podatke za popis
  /// ✅ FIX: Koristi VoznjeLogService direktno za tačne statistike
  static Future<PopisData> loadPopisData({
    required String vozac,
    required String selectedGrad,
    required String selectedVreme,
    DateTime? date, // 📅 Dodato za radne datume vikendom
  }) async {
    final today = date ?? DateTime.now();
    final dayStart = DateTime(today.year, today.month, today.day);
    final dayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

    // 1. ✅ DIREKTNE STATISTIKE IZ VOZNJE_LOG - tačni podaci
    final stats = await VoznjeLogService.getStatistikePoVozacu(
      vozacIme: vozac,
      datum: today,
    );

    final pokupljeniPutnici = stats['voznje'] as int? ?? 0;
    final otkazaniPutnici = stats['otkazivanja'] as int? ?? 0;
    final naplaceniDnevni = stats['uplate'] as int? ?? 0;
    final naplaceniMesecni = stats['mesecne'] as int? ?? 0;
    final ukupanPazar = stats['pazar'] as double? ?? 0.0;

    // 2. SITAN NOVAC
    final sitanNovac = await DailyCheckInService.getTodayAmount(vozac) ?? 0.0;

    // 3. KILOMETRAŽA
    late double kilometraza;
    try {
      kilometraza = await StatistikaService.instance.getKilometrazu(vozac, dayStart, dayEnd);
    } catch (e) {
      kilometraza = 0.0;
    }

    // 4. DUŽNICI - dnevni putnici koji su pokupljeni ali nisu platili
    final dugoviPutnici = await VoznjeLogService.getBrojDuznikaPoVozacu(
      vozacIme: vozac,
      datum: today,
    );

    return PopisData(
      vozac: vozac,
      datum: today,
      ukupanPazar: ukupanPazar,
      sitanNovac: sitanNovac,
      otkazaniPutnici: otkazaniPutnici,
      pokupljeniPutnici: pokupljeniPutnici,
      naplaceniDnevni: naplaceniDnevni,
      naplaceniMesecni: naplaceniMesecni,
      dugoviPutnici: dugoviPutnici,
      kilometraza: kilometraza,
    );
  }

  /// Sačuvaj popis u bazu
  static Future<void> savePopis(PopisData data) async {
    await DailyCheckInService.saveDailyReport(data.vozac, data.datum, data.toMap());
    await DailyCheckInService.saveCheckIn(data.vozac, data.sitanNovac, date: data.datum);
  }

  /// Prikaži popis dialog i vrati true ako korisnik želi da sačuva
  static Future<bool> showPopisDialog(BuildContext context, PopisData data, {bool isAutomatic = false}) async {
    final vozacColor = VozacBoja.get(data.vozac);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: isAutomatic,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(isAutomatic ? Icons.auto_awesome : Icons.person, color: vozacColor, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isAutomatic
                    ? 'AUTOMATSKI POPIS - ${data.datum.day}.${data.datum.month}.${data.datum.year}'
                    : 'POPIS - ${data.datum.day}.${data.datum.month}.${data.datum.year}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800]),
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
                    _buildStatRow('Pokupljeni', data.pokupljeniPutnici, Icons.check_circle, Colors.teal),
                    _buildStatRow('Otkazani', data.otkazaniPutnici, Icons.cancel, Colors.red),
                    _buildStatRow('Dugovi', data.dugoviPutnici, Icons.warning, Colors.orange),

                    if (data.naplaceniDnevni > 0 || data.naplaceniMesecni > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (data.naplaceniDnevni > 0)
                            Expanded(child: _buildSmallStat('Dnevne: ${data.naplaceniDnevni}', Colors.blueGrey)),
                          if (data.naplaceniMesecni > 0)
                            Expanded(child: _buildSmallStat('Mesečne: ${data.naplaceniMesecni}', Colors.purple)),
                        ],
                      ),
                    ],

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
          if (!isAutomatic) TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Otkaži')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: Icon(isAutomatic ? Icons.check : Icons.save),
            label: Text(isAutomatic ? 'U redu' : 'Sačuvaj popis'),
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

  /// Helper za manju statistiku (uplate)
  static Widget _buildSmallStat(String text, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
