import 'package:flutter/material.dart';

class PazarPoVozacimaWidget extends StatelessWidget {
  const PazarPoVozacimaWidget({
    Key? key,
    required this.vozaciPazar,
    required this.ukupno,
    required this.periodLabel,
    required this.vozacBoje,
  }) : super(key: key);
  final Map<String, double> vozaciPazar;
  final double ukupno;
  final String periodLabel;
  final Map<String, Color> vozacBoje;

  @override
  Widget build(BuildContext context) {
    // Prikaz redosleda vozača kao u AdminScreen-u
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
            '$periodLabel pazar po vozačima',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...vozaciRedosled.map(
          (vozac) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: (vozacBoje[vozac] ?? Colors.blueGrey)
                  .withOpacity(0.25), // 🎨 POJAČAO sa 0.08 na 0.25
              borderRadius:
                  BorderRadius.circular(12), // 🎨 Povećao border radius
              border: Border.all(
                color: (vozacBoje[vozac] ?? Colors.blueGrey)
                    .withOpacity(0.6), // 🎨 POJAČAO sa 0.3 na 0.6
                width: 2, // 🎨 Povećao debljinu bordera
              ),
              boxShadow: [
                BoxShadow(
                  color: (vozacBoje[vozac] ?? Colors.blueGrey).withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: vozacBoje[vozac] ?? Colors.blueGrey,
                  radius: 16,
                  child: Text(
                    vozac[0],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vozac,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: vozacBoje[vozac] ?? Colors.blueGrey,
                        ),
                      ),
                      Text(
                        'Vozač',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.monetization_on,
                      color: vozacBoje[vozac] ?? Colors.blueGrey,
                      size: 16,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${(vozaciPazar[vozac] ?? 0.0).toStringAsFixed(0)} RSD',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: vozacBoje[vozac] ?? Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Ukupan pazar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[300]!, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: Colors.green[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text(
                    'UKUPAN PAZAR',
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${ukupno.toStringAsFixed(0)} RSD',
                    style: TextStyle(
                      color: Colors.green[900],
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
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
}





