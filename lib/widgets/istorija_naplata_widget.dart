import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/vozac_boja.dart';

class IstorijaHaplataWidget extends StatelessWidget {
  const IstorijaHaplataWidget({
    Key? key,
    required this.detaljiNaplata,
    required this.vozac,
  }) : super(key: key);
  final List<Map<String, dynamic>> detaljiNaplata;
  final String vozac;

  String _formatVreme(int milliseconds) {
    final datum = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return DateFormat('dd.MM HH:mm').format(datum);
  }

  @override
  Widget build(BuildContext context) {
    if (detaljiNaplata.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sortiraj po vremenu (najnovije prvo)
    final sortiraneNaplate = List<Map<String, dynamic>>.from(detaljiNaplata);
    sortiraneNaplate.sort((a, b) => (b['vreme'] as int).compareTo(a['vreme'] as int));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Poslednje naplate (${sortiraneNaplate.length})',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: VozacBoja.get(vozac),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 150),
          child: SingleChildScrollView(
            child: Column(
              children: sortiraneNaplate.take(5).map((naplata) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: VozacBoja.get(vozac).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: VozacBoja.get(vozac).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Tip naplate ikona
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: naplata['tip'] == 'Mesečna' ? Colors.orange : Colors.blue,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Icon(
                          naplata['tip'] == 'Mesečna' ? Icons.card_membership : Icons.confirmation_num,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Ime putnika
                      Expanded(
                        flex: 2,
                        child: Text(
                          (naplata['ime'] as String?) ?? 'Nepoznato',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Iznos
                      Expanded(
                        child: Text(
                          '${(naplata['iznos'] as double).toStringAsFixed(0)} RSD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: VozacBoja.get(vozac),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      // Vreme
                      Text(
                        _formatVreme((naplata['vreme'] as int?) ?? 0),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
