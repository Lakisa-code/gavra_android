import 'package:flutter/material.dart';

import '../services/simple_usage_monitor.dart';
import '../theme.dart'; // 🎨 Import ThemeManager

/// Jednostavan i lep ekran za praćenje Supabase potrošnje
class MonitoringEkran extends StatefulWidget {
  const MonitoringEkran({super.key});

  @override
  State<MonitoringEkran> createState() => _MonitoringEkranState();
}

class _MonitoringEkranState extends State<MonitoringEkran> {
  Map<String, String> _statistika = {};
  // loading flag removed — UI doesn't use `_ucitava` here any more
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
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
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
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                          _ucitajStatistiku();
                        },
                        child: const Text(
                          'Pokušaj ponovo',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              _napraviGlavnuKarticu(),
              const SizedBox(height: 12),
              _napraviDetaljeKarticu(),
              const SizedBox(height: 12),
              _napraviSaveteKarticu(),
              const SizedBox(height: 12),
            ],
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: boja.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            const Text(
              'TRENUTNO STANJE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: FractionallySizedBox(
                widthFactor: procenat / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_statistika['procenat']} od mesečnog limita',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11,
              ),
            ),
            if (_statistika['last_update'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Ažurirano: ${_statistika['last_update']}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 9,
                  ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).glassBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'DETALJI POTROŠNJE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _napraviRedDetalja(
              '📅 API poziva danas',
              _statistika['dnevni_pozivi'] ?? '0',
              _statistika['api_status'] ?? '✅ UNLIMITED',
            ),
            _napraviRedDetalja(
              '👥 Aktivni korisnici',
              _statistika['procenjeni_users'] ?? '0',
              _statistika['registrovana_procena'] ?? '',
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
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _statistika['poruka'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Row(
              children: [
                Text(ikona.substring(0, 2), style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    ikona.substring(2).trim(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vrednost,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (opis.isNotEmpty)
                  Text(
                    opis,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.6),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).glassBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.amber, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'KORISNI SAVETI',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ikona, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              tekst,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
