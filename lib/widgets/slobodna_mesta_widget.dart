import 'package:flutter/material.dart';

import '../services/slobodna_mesta_service.dart';
import '../theme.dart';

/// 🎫 Widget za prikaz slobodnih mesta i promenu vremena
/// Prikazuje oba grada uporedo (Bela Crkva | Vršac)
class SlobodnaMestaWidget extends StatefulWidget {
  final String? putnikId;
  final String? putnikGrad;
  final String? putnikVreme;
  final Function(String novoVreme)? onPromenaVremena;

  const SlobodnaMestaWidget({
    Key? key,
    this.putnikId,
    this.putnikGrad,
    this.putnikVreme,
    this.onPromenaVremena,
  }) : super(key: key);

  @override
  State<SlobodnaMestaWidget> createState() => _SlobodnaMestaWidgetState();
}

class _SlobodnaMestaWidgetState extends State<SlobodnaMestaWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Color _getStatusColor(SlobodnaMesta sm) {
    if (!sm.aktivan) return Colors.grey;
    if (sm.slobodna > 3) return Colors.green;
    if (sm.slobodna > 0) return Colors.orange;
    return Colors.red;
  }

  Future<void> _onTapVreme(SlobodnaMesta sm) async {
    // Ako je puno ili neaktivno, ne može se izabrati
    if (sm.jePuno || !sm.aktivan) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sm.jePuno ? 'Ovaj termin je pun!' : 'Ovaj termin nije aktivan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Ako je isto vreme kao trenutno
    if (sm.vreme == widget.putnikVreme && sm.grad.toUpperCase() == widget.putnikGrad?.toUpperCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Već ste na ovom terminu'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    // Potvrda promene
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).glassContainer,
        title: const Text(
          'Promena vremena',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Da li želite da promenite vreme polaska na ${sm.vreme} (${sm.grad})?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ne', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Da, promeni'),
          ),
        ],
      ),
    );

    if (confirm == true && widget.onPromenaVremena != null) {
      widget.onPromenaVremena!('${sm.grad}|${sm.vreme}');
    }
  }

  Widget _buildTimeSlot(SlobodnaMesta sm) {
    final isCurrentTime = sm.vreme == widget.putnikVreme && sm.grad.toUpperCase() == widget.putnikGrad?.toUpperCase();
    final statusColor = _getStatusColor(sm);

    return GestureDetector(
      onTap: () => _onTapVreme(sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isCurrentTime ? Colors.blue.withValues(alpha: 0.4) : statusColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrentTime ? Colors.blue : statusColor.withValues(alpha: 0.6),
            width: isCurrentTime ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              sm.vreme,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                sm.jePuno ? 'X' : '${sm.slobodna}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            if (isCurrentTime) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_circle, color: Colors.blue, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGradColumn(String gradNaziv, String gradKod, List<SlobodnaMesta> slobodna) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Naslov grada
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  gradKod == 'BC' ? Icons.home : Icons.location_city,
                  color: gradKod == 'BC' ? Colors.green : Colors.blue,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  gradNaziv,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Grid vremena
          if (slobodna.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Nema podataka',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            )
          else
            Wrap(
              alignment: WrapAlignment.center,
              children: slobodna.map((sm) => _buildTimeSlot(sm)).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, List<SlobodnaMesta>>>(
      stream: SlobodnaMestaService.streamSlobodnaMesta(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).glassContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).glassBorder,
                width: 1.5,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final data = snapshot.data ?? {'BC': [], 'VS': []};

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).glassContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).glassBorder,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueGrey.shade800.withValues(alpha: 0.8),
                      Colors.blueGrey.shade900.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_seat, color: Colors.lightBlueAccent, size: 18),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'SLOBODNA MESTA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    // Legenda
                    _buildLegendItem(Colors.green, '>3'),
                    const SizedBox(width: 3),
                    _buildLegendItem(Colors.orange, '1-3'),
                    const SizedBox(width: 3),
                    _buildLegendItem(Colors.red, '0'),
                  ],
                ),
              ),
              // Uporedni prikaz oba grada
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bela Crkva kolona
                    _buildGradColumn('Bela Crkva', 'BC', data['BC'] ?? []),
                    // Vertikalni separator
                    Container(
                      width: 1,
                      height: 80,
                      color: Colors.white24,
                    ),
                    // Vršac kolona
                    _buildGradColumn('Vršac', 'VS', data['VS'] ?? []),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
