import 'package:flutter/material.dart';
import 'package:gavra_android/services/clean_statistika_service.dart';

import '../theme.dart';

/// Widget za prikaz čistih statistika bez duplikata
class CleanStatistikaWidget extends StatefulWidget {
  const CleanStatistikaWidget({Key? key}) : super(key: key);

  @override
  State<CleanStatistikaWidget> createState() => _CleanStatistikaWidgetState();
}

class _CleanStatistikaWidgetState extends State<CleanStatistikaWidget> {
  Map<String, dynamic>? _statistike;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ucitajStatistike();
  }

  Future<void> _ucitajStatistike() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final stats = await CleanStatistikaService.dohvatiUkupneStatistike();

      setState(() {
        _statistike = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Greška: $_error'),
            ElevatedButton(
              onPressed: _ucitajStatistike,
              child: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      );
    }

    if (_statistike == null) {
      return const Center(child: Text('Nema podataka'));
    }

    return RefreshIndicator(
      onRefresh: _ucitajStatistike,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header sa clean indikatorom
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Čisti podaci - bez duplikata',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_statistike!['no_duplicates'] == true) const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Ukupne statistike
            _buildStatistikaCard(
              'Ukupno',
              '${_statistike!['ukupno_sve']} RSD',
              Icons.account_balance_wallet,
              Colors.blue,
            ),

            const SizedBox(height: 8),

            // Mesečni putnici
            _buildStatistikaCard(
              'Mesečni putnici',
              '${_statistike!['ukupno_mesecni']} RSD ' + '(${_statistike!['broj_mesecnih']} zapisa)',
              Icons.people,
              Colors.orange,
            ),

            const SizedBox(height: 8),

            // Standalone putovanja
            _buildStatistikaCard(
              'Dnevna putovanja',
              '${_statistike!['ukupno_standalone']} RSD ' + '(${_statistike!['broj_standalone']} zapisa)',
              Icons.directions_car,
              Colors.purple,
            ),

            const SizedBox(height: 16),

            // Debug info button
            ElevatedButton.icon(
              onPressed: _pokaziDebugInfo,
              icon: const Icon(Icons.info),
              label: const Text('Debug informacije'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistikaCard(
    String naslov,
    String vrednost,
    IconData ikona,
    Color boja,
  ) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: boja.withOpacity(0.1),
          child: Icon(ikona, color: boja),
        ),
        title: Text(naslov),
        subtitle: Text(vrednost),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  void _pokaziDebugInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111111) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFBB86FC).withOpacity(0.4)
                : const Color(0xFF008B8B).withOpacity(0.5),
            width: 2,
          ),
        ),
        title: Text(
          'Debug informacije',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Container(
          decoration: Theme.of(context).brightness == Brightness.dark
              ? DarkSapphirePlatinumStyles.popupDecoration
              : FlutterBankStyles.popupDecoration,
          child: SingleChildScrollView(
            child: Text(
              _statistike.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
        actions: [
          Container(
            decoration: Theme.of(context).brightness == Brightness.dark
                ? DarkSapphirePlatinumStyles.gradientButton
                : FlutterBankStyles.gradientButton,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Zatvori',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
