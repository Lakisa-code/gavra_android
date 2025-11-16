import 'package:flutter/material.dart';

import '../services/simple_usage_monitor.dart';
import '../theme.dart'; // 🎨 Import ThemeManager

/// Jednostavan i lep ekran za praćenje Supabase potrošnje
class MonitoringEkran extends StatefulWidget {
  const MonitoringEkran({Key? key}) : super(key: key);

  @override
  _MonitoringEkranState createState() => _MonitoringEkranState();
}

class _MonitoringEkranState extends State<MonitoringEkran> {
  Map<String, String> _statistika = {};
  bool _ucitava = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Koristi PostFrameCallback da izbegne debugBuildingDirtyElements greške
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ucitajStatistiku();
    });
  }

  Future<void> _ucitajStatistiku() async {
    try {
      final stats = await SimpleUsageMonitor.dobijStatistiku();
      if (mounted) {
        setState(() {
          _statistika = stats;
          _ucitava = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ucitava = false;
          _errorMessage = 'Greška pri učitavanju: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).backgroundGradient, // 🎨 Use theme gradient
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Transparent background
        appBar: AppBar(
          title: const Text(
            'Supabase Monitoring',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              shadows: [
                Shadow(
                  blurRadius: 8,
                  color: Colors.black87,
                ),
              ],
            ),
          ),
          backgroundColor: Colors.transparent, // Transparent appBar
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).glassContainer,
              border: Border.all(
                color: Theme.of(context).glassBorder,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _ucitava
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : RefreshIndicator(
                onRefresh: _ucitajStatistiku,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      if (_errorMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.orange),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _ucitava = true;
                                    _errorMessage = null;
                                  });
                                  _ucitajStatistiku();
                                },
                                child: const Text(
                                  'Pokušaj ponovo',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      _napraviGlavnuKarticu(),
                      const SizedBox(height: 20),
                      _napraviDetaljeKarticu(),
                      const SizedBox(height: 20),
                      _napraviSaveteKarticu(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _napraviGlavnuKarticu() {
    final status = _statistika['status'] ?? '🟢 ODLIČNO';
    final procenat = int.tryParse(_statistika['procenat']?.replaceAll('%', '') ?? '0') ?? 0;

    MaterialColor boja = Colors.green;
    if (status.contains('🟡')) boja = Colors.orange;
    if (status.contains('🟠')) boja = Colors.deepOrange;
    if (status.contains('🔴')) boja = Colors.red;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [boja.shade400, boja.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: boja.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Text(
              'TRENUTNO STANJE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              status,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FractionallySizedBox(
                widthFactor: procenat / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${_statistika['procenat']} od mesečnog limita',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            if (_statistika['last_update'] != null)
              Text(
                'Poslednje ažuriranje: ${_statistika['last_update']}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _napraviDetaljeKarticu() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).glassContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).glassBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'DETALJI POTROŠNJE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _napraviRedDetalja(
              '📅 API poziva danas',
              _statistika['dnevni_pozivi'] ?? '0',
              _statistika['api_status'] ?? '✅ UNLIMITED',
            ),
            _napraviRedDetalja(
              '👥 Aktivni korisnici',
              _statistika['procenjeni_users'] ?? '0',
              _statistika['mesecna_procena'] ?? '',
            ),
            _napraviRedDetalja(
              '💾 Database limit',
              _statistika['database_limit'] ?? '500 MB',
              'Free tier',
            ),
            _napraviRedDetalja(
              '� Storage limit',
              _statistika['storage_limit'] ?? '1 GB',
              'Free tier',
            ),
            _napraviRedDetalja(
              '🌐 Egress limit',
              _statistika['egress_limit'] ?? '5 GB',
              'Free tier',
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statistika['poruka'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _napraviRedDetalja(String ikona, String vrednost, String opis) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(ikona, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vrednost,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (opis.isNotEmpty)
                  Text(
                    opis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _napraviSaveteKarticu() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).glassContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).glassBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.amber, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'KORISNI SAVETI',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _napraviSavet(
              '🎉',
              'ODLIČO! API pozivi su sada UNLIMITED u Free tier!',
            ),
            _napraviSavet(
              '👥',
              'Glavni limit: 50,000 aktivnih korisnika mesečno',
            ),
            _napraviSavet('💾', 'Database: 500MB | Storage: 1GB | Egress: 5GB'),
            _napraviSavet(
              '📱',
              'Development faza - optimalno vreme za testiranje',
            ),
            _napraviSavet(
              '🔧',
              'Koristite PametniSupabase.from() za automatsko praćenje',
            ),
            _napraviSavet(
              '💰',
              'Supabase Pro (25 USD/mesec) tek kad prođete limite',
            ),
            _napraviSavet(
              '🏪',
              'Prioritet: Store developer fee (25 USD jednom)',
            ),
            _napraviSavet(
              '📊',
              'Povucite nadole za refresh - cache važi 30 sekundi',
            ),
          ],
        ),
      ),
    );
  }

  Widget _napraviSavet(String ikona, String tekst) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ikona, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tekst,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
