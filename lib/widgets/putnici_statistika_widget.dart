import 'package:flutter/material.dart';
import '../models/putnik.dart';

import 'bar_chart_widget.dart';
import 'pie_chart_widget.dart';

import 'putnik_list.dart';

class PutniciStatistikaWidget extends StatelessWidget {
  final int ukupnoPutnika;
  final Map<DateTime, int> putniciPoDanu;
  final List<Putnik> duznici;
  final String? periodOpis;
  final String? currentDriver;
  // Svi callbackovi uklonjeni, widget je sada samo prikaz

  const PutniciStatistikaWidget({
    Key? key,
    required this.ukupnoPutnika,
    required this.putniciPoDanu,
    required this.duznici,
    this.periodOpis,
    required this.currentDriver,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (periodOpis != null)
              Text(periodOpis!,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              color: Colors.blue[50],
              child: ListTile(
                leading: Icon(Icons.people, color: Colors.blue[700]),
                title: const Text('Ukupno putnika'),
                trailing: Text('$ukupnoPutnika',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            // Bar chart: broj putnika po danu
            BarChartWidget(
              data: putniciPoDanu,
              color: Colors.blue,
              title: 'Broj putnika po danu',
            ),
            const SizedBox(height: 24),
            // Pie chart: udeo dužnika, mesečnih karata, ostalih
            Builder(
              builder: (context) {
                final ukupno = ukupnoPutnika.toDouble();
                final brojDuznika = duznici.length.toDouble();
                // final brojMesecnih = putniciPoDanu.isEmpty
                //     ? 0.0
                //     : putniciPoDanu.entries
                //         .map((e) => e.value)
                //         .fold(0.0, (a, b) => a + (b ?? 0.0));
                // Za demo: broj mesečnih karata izračunaj iz dužnika (ili prosledi kao parametar)
                // Ovde pretpostavljamo da je duznik onaj ko nije platio, a mesečna karta je onaj sa mesecnaKarta == true
                // Ako imaš listu svih putnika za period, možeš preciznije
                final pieData = <String, double>{
                  'Dužnici': brojDuznika,
                  'Ostali': ukupno - brojDuznika,
                };
                return PieChartWidget(
                  data: pieData,
                  colors: const [Colors.red, Colors.green],
                  title: 'Udeo dužnika',
                );
              },
            ),
            const SizedBox(height: 24),
            const Text('Lista dužnika:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            duznici.isEmpty
                ? Text('Nema dužnika za izabrani period.',
                    style: TextStyle(color: Colors.green[700]))
                : PutnikList(
                    putnici: duznici,
                    currentDriver: currentDriver,
                  ),
          ],
        ),
      ),
    );
  }

  // String _formatDate(DateTime date) {
  //   return '${date.day}.${date.month}.${date.year}.';
  // }
}
