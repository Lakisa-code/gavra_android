import 'package:flutter/material.dart';

import '../services/slobodna_mesta_service.dart';
import '../theme.dart';

/// 🎫 Widget za prikaz slobodnih mesta i promenu vremena
/// Prikazuje se na Moj profil ekranu ispod Kombi status
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

class _SlobodnaMestaWidgetState extends State<SlobodnaMestaWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Podesi početni tab na grad putnika
    final initialIndex = widget.putnikGrad?.toUpperCase() == 'VS' ? 1 : 0;
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        width: 65,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isCurrentTime ? Colors.blue.withValues(alpha: 0.4) : statusColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentTime ? Colors.blue : statusColor,
            width: isCurrentTime ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sm.vreme,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isCurrentTime ? 14 : 12,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sm.jePuno ? 'PUNO' : '${sm.slobodna}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            if (isCurrentTime) ...[
              const SizedBox(height: 4),
              const Icon(Icons.check_circle, color: Colors.blue, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGradTab(List<SlobodnaMesta> slobodna) {
    if (slobodna.isEmpty) {
      return const Center(
        child: Text(
          'Nema podataka',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: slobodna.map((sm) => _buildTimeSlot(sm)).toList(),
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
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_seat, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'SLOBODNA MESTA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    // Legenda
                    _buildLegendItem(Colors.green, '>3'),
                    const SizedBox(width: 4),
                    _buildLegendItem(Colors.orange, '1-3'),
                    const SizedBox(width: 4),
                    _buildLegendItem(Colors.red, '0'),
                  ],
                ),
              ),
              // Tabs
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black26,
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.green,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: const [
                    Tab(text: 'Bela Crkva'),
                    Tab(text: 'Vršac'),
                  ],
                ),
              ),
              // Content
              SizedBox(
                height: 100,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGradTab(data['BC'] ?? []),
                    _buildGradTab(data['VS'] ?? []),
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
