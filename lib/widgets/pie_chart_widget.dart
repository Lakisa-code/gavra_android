import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class PieChartWidget extends StatelessWidget {
  const PieChartWidget({
    Key? key,
    required this.data,
    required this.colors,
    this.title = '',
  }) : super(key: key);
  final Map<String, double> data;
  final List<Color> colors;
  final String title;

  @override
  Widget build(BuildContext context) {
    // Osiguraj da su sve vrednosti double i non-null
    // Osiguraj da su sve vrednosti double i non-null
    // Ako je neka vrednost null, tretiraj je kao 0.0
    // Prava null-safe verzija: koristi .toDouble() i null kao 0.0
    // Konačno robustno: ako je b null, koristi 0.0
    // Najsigurnije: mapiraj sve vrednosti na double, null kao 0.0
    // Najsigurnije: mapiraj sve vrednosti na double, null kao 0.0, a+b kao double
    // Konačno: sve vrednosti su double, fold radi na double
    // Konačno: sve vrednosti su double, fold radi na double, a+b je double
    final total =
        data.values.fold(0.0, (double a, double? b) => a + (b ?? 0.0));
    final entries = data.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        AspectRatio(
          aspectRatio: 1.3,
          child: PieChart(
            PieChartData(
              sections: [
                for (int i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    color: colors[i % colors.length],
                    value: entries[i].value,
                    title: total == 0
                        ? ''
                        : '${((entries[i].value / total) * 100).toStringAsFixed(1)}%',
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
              sectionsSpace: 2,
              centerSpaceRadius: 30,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            for (int i = 0; i < entries.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    color: colors[i % colors.length],
                  ),
                  const SizedBox(width: 4),
                  Text(entries[i].key),
                ],
              ),
          ],
        ),
      ],
    );
  }
}





