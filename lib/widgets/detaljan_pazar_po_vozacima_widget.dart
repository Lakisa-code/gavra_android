import 'package:flutter/material.dart';

import 'istorija_naplata_widget.dart';

class DetaljanPazarPoVozacimaWidget extends StatelessWidget {
  const DetaljanPazarPoVozacimaWidget({
    Key? key,
    required this.vozaciStatistike,
    required this.ukupno,
    required this.periodLabel,
    required this.vozacBoje,
  }) : super(key: key);
  final Map<String, Map<String, dynamic>> vozaciStatistike;
  final double ukupno;
  final String periodLabel;
  final Map<String, Color> vozacBoje;

  @override
  Widget build(BuildContext context) {
    final List<String> vozaciRedosled = [
      'Bruda',
      'Bilevski',
      'Bojan',
      'Svetlana',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            '$periodLabel - Detaljne naplate po vozačima',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...vozaciRedosled.map((vozac) {
          final stats = vozaciStatistike[vozac] ?? {};
          final pazar = (stats['ukupnoPazar'] as double?) ?? 0.0;
          final brojPutnika = (stats['naplaceni'] as int?) ?? 0;
          final brojMesecnih = (stats['mesecneKarte'] as int?) ?? 0;
          final avgPlacanjeObicno = brojPutnika > 0 ? pazar / brojPutnika : 0.0;

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  (vozacBoje[vozac] ?? Colors.blueGrey).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (vozacBoje[vozac] ?? Colors.blueGrey)
                    .withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header sa vozačem i ukupnim pazarom
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: vozacBoje[vozac] ?? Colors.blueGrey,
                      radius: 18,
                      child: Text(
                        vozac[0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vozac,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: vozacBoje[vozac] ?? Colors.blueGrey,
                            ),
                          ),
                          Text(
                            'Ukupno: ${pazar.toStringAsFixed(0)} RSD',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: (vozacBoje[vozac] ?? Colors.blueGrey)
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Detalji o naplatama
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        '👥 Putnici',
                        brojPutnika.toString(),
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        '🎫 Mesečni',
                        brojMesecnih.toString(),
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        '💰 Prosek',
                        avgPlacanjeObicno > 0
                            ? '${avgPlacanjeObicno.toStringAsFixed(0)} RSD'
                            : '0 RSD',
                        Colors.green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Istorija naplate
                IstorijaHaplataWidget(
                  detaljiNaplata:
                      stats['detaljiNaplata'] as List<Map<String, dynamic>>? ??
                          [],
                  vozac: vozac,
                ),
              ],
            ),
          );
        }).toList(),

        const SizedBox(height: 16),

        // Ukupan pazar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[100]!, Colors.green[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[300]!, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: Colors.green[700],
                size: 24,
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  Text(
                    'UKUPAN PAZAR',
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ukupno.toStringAsFixed(0)} RSD',
                    style: TextStyle(
                      color: Colors.green[900],
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
