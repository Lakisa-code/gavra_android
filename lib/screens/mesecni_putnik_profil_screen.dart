import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

/// 📊 MESEČNI PUTNIK PROFIL SCREEN
/// Prikazuje podatke o mesečnom putniku: raspored, vožnje, dugovanja
class MesecniPutnikProfilScreen extends StatefulWidget {
  final Map<String, dynamic> putnikData;

  const MesecniPutnikProfilScreen({
    Key? key,
    required this.putnikData,
  }) : super(key: key);

  @override
  State<MesecniPutnikProfilScreen> createState() => _MesecniPutnikProfilScreenState();
}

class _MesecniPutnikProfilScreenState extends State<MesecniPutnikProfilScreen> {
  Map<String, dynamic> _putnikData = {};
  bool _isLoading = false;
  int _brojVoznji = 0;
  final int _brojOtkazivanja = 0;
  double _dugovanje = 0.0;
  List<Map<String, dynamic>> _istorijaPl = [];

  @override
  void initState() {
    super.initState();
    _putnikData = widget.putnikData;
    _loadStatistike();
  }

  Future<void> _loadStatistike() async {
    setState(() => _isLoading = true);

    try {
      final putnikId = _putnikData['id'];
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      // Broj vožnji ovog meseca
      final voznje = await Supabase.instance.client
          .from('putovanja_istorija')
          .select('id')
          .eq('mesecni_putnik_id', putnikId)
          .gte('datum', startOfMonth.toIso8601String())
          .count();

      // Dugovanje
      final dug = _putnikData['dug'] ?? 0;

      // 💰 Istorija plaćanja - poslednjih 6 meseci
      final istorija = await _loadIstorijuPlacanja(putnikId);

      setState(() {
        _brojVoznji = voznje.count;
        _dugovanje = (dug is int) ? dug.toDouble() : (dug as double);
        _istorijaPl = istorija;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Greška pri učitavanju statistika: $e');
      setState(() => _isLoading = false);
    }
  }

  /// 💰 Učitaj istoriju plaćanja - od 1. januara tekuće godine
  Future<List<Map<String, dynamic>>> _loadIstorijuPlacanja(String putnikId) async {
    try {
      final now = DateTime.now();
      // Od 1. januara tekuće godine
      final pocetakGodine = DateTime(now.year, 1, 1);

      final placanja = await Supabase.instance.client
          .from('putovanja_istorija')
          .select('cena, datum_putovanja, created_at')
          .eq('mesecni_putnik_id', putnikId)
          .eq('status', 'placeno')
          .eq('tip_putnika', 'mesecni')
          .gte('datum_putovanja', pocetakGodine.toIso8601String().split('T')[0])
          .order('datum_putovanja', ascending: false);

      // Grupiši po mesecima
      final Map<String, double> poMesecima = {};
      final Map<String, DateTime> poslednjeDatum = {};

      for (final p in placanja) {
        final datumStr = p['datum_putovanja'] as String?;
        if (datumStr == null) continue;

        final datum = DateTime.tryParse(datumStr);
        if (datum == null) continue;

        final mesecKey = '${datum.year}-${datum.month.toString().padLeft(2, '0')}';
        final iznos = (p['cena'] as num?)?.toDouble() ?? 0.0;

        poMesecima[mesecKey] = (poMesecima[mesecKey] ?? 0.0) + iznos;

        // Zapamti poslednji datum uplate za taj mesec
        if (!poslednjeDatum.containsKey(mesecKey) || datum.isAfter(poslednjeDatum[mesecKey]!)) {
          poslednjeDatum[mesecKey] = datum;
        }
      }

      // Konvertuj u listu sortiranu po datumu (najnoviji prvi)
      final result = poMesecima.entries.map((e) {
        final parts = e.key.split('-');
        final godina = int.parse(parts[0]);
        final mesec = int.parse(parts[1]);
        return {
          'mesec': mesec,
          'godina': godina,
          'iznos': e.value,
          'datum': poslednjeDatum[e.key],
        };
      }).toList();

      result.sort((a, b) {
        final dateA = DateTime(a['godina'] as int, a['mesec'] as int);
        final dateB = DateTime(b['godina'] as int, b['mesec'] as int);
        return dateB.compareTo(dateA);
      });

      return result;
    } catch (e) {
      debugPrint('Greška pri učitavanju istorije plaćanja: $e');
      return [];
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Odjava?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Da li želiš da se odjaviš?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ne'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Da, odjavi me'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('mesecni_putnik_telefon');

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ime = _putnikData['ime'] ?? '';
    final prezime = _putnikData['prezime'] ?? '';
    final adresa = _putnikData['adresa'] ?? '-';
    final telefon = _putnikData['telefon'] ?? '-';
    final grad = _putnikData['grad'] ?? 'BC';
    final tip = _putnikData['tip'] ?? 'radnik';
    final daniVoznje = _putnikData['dani_voznje'] ?? 'pon-pet';
    final aktivan = _putnikData['aktivan'] ?? true;

    return Container(
      decoration: const BoxDecoration(
        gradient: tripleBlueFashionGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            '👤 Moj profil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: _logout,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : RefreshIndicator(
                onRefresh: _loadStatistike,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Ime i status
                      Card(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: aktivan ? Colors.green.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.amber,
                                child: Text(
                                  '${ime.isNotEmpty ? ime[0] : ''}${prezime.isNotEmpty ? prezime[0] : ''}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Ime
                              Text(
                                '$ime $prezime',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Tip i grad
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: tip == 'ucenik' ? Colors.blue : Colors.orange,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      tip == 'ucenik' ? '🎓 Učenik' : '💼 Radnik',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.purple,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      grad == 'BC' ? '📍 Bela Crkva' : '📍 Vršac',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Status
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color:
                                      aktivan ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  aktivan ? '✅ Aktivan' : '❌ Neaktivan',
                                  style: TextStyle(
                                    color: aktivan ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Statistike
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              '🚌',
                              'Vožnje',
                              _brojVoznji.toString(),
                              Colors.blue,
                              'ovaj mesec',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              '❌',
                              'Otkazano',
                              _brojOtkazivanja.toString(),
                              Colors.orange,
                              'ovaj mesec',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              '💰',
                              'Dugovanje',
                              _dugovanje.toStringAsFixed(0),
                              _dugovanje > 0 ? Colors.red : Colors.green,
                              'RSD',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 📅 Raspored polazaka
                      _buildRasporedCard(),
                      const SizedBox(height: 16),

                      // 💰 Istorija plaćanja
                      _buildIstorijaPlacanjaCard(),
                      const SizedBox(height: 16),

                      // Detalji
                      Card(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '📋 Moji podaci',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildDetailRow(Icons.calendar_today, 'Dani vožnje', daniVoznje),
                              _buildDetailRow(Icons.home, 'Adresa', adresa),
                              _buildDetailRow(Icons.phone, 'Telefon', telefon),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Za izmenu podataka ili otkazivanje vožnje kontaktirajte admina.',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(String emoji, String label, String value, Color color, String subtitle) {
    return Card(
      color: Colors.white.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// 📅 Widget za prikaz rasporeda polazaka po danima
  Widget _buildRasporedCard() {
    // Parsiranje polasci_po_danu iz putnikData
    final polasciRaw = _putnikData['polasci_po_danu'];
    Map<String, Map<String, String?>> polasci = {};

    if (polasciRaw != null && polasciRaw is Map) {
      polasciRaw.forEach((key, value) {
        if (value is Map) {
          polasci[key.toString()] = {
            'bc': value['bc']?.toString(),
            'vs': value['vs']?.toString(),
          };
        }
      });
    }

    final dani = ['pon', 'uto', 'sre', 'cet', 'pet'];
    final daniLabels = {
      'pon': 'PON',
      'uto': 'UTO',
      'sre': 'SRE',
      'cet': 'ČET',
      'pet': 'PET',
    };

    return Card(
      color: Colors.white.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '📅 Moj raspored',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Lista dana
            ...dani.map((dan) {
              final danPolasci = polasci[dan];
              final bcVreme = danPolasci?['bc'];
              final vsVreme = danPolasci?['vs'];
              final hasPolasci = (bcVreme != null && bcVreme.isNotEmpty) || (vsVreme != null && vsVreme.isNotEmpty);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: hasPolasci ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasPolasci ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    // Dan
                    SizedBox(
                      width: 40,
                      child: Text(
                        daniLabels[dan] ?? dan.toUpperCase(),
                        style: TextStyle(
                          color: hasPolasci ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Polasci
                    Expanded(
                      child: hasPolasci
                          ? Row(
                              children: [
                                if (bcVreme != null && bcVreme.isNotEmpty) ...[
                                  Icon(Icons.arrow_forward, size: 14, color: Colors.blue.shade300),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$bcVreme BC',
                                    style: TextStyle(color: Colors.blue.shade200, fontSize: 13),
                                  ),
                                ],
                                if (bcVreme != null && bcVreme.isNotEmpty && vsVreme != null && vsVreme.isNotEmpty)
                                  const SizedBox(width: 12),
                                if (vsVreme != null && vsVreme.isNotEmpty) ...[
                                  Icon(Icons.arrow_back, size: 14, color: Colors.purple.shade300),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$vsVreme VS',
                                    style: TextStyle(color: Colors.purple.shade200, fontSize: 13),
                                  ),
                                ],
                              ],
                            )
                          : Text(
                              'Nema vožnje',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 💰 Widget za prikaz istorije plaćanja
  Widget _buildIstorijaPlacanjaCard() {
    final meseci = {
      1: 'Januar',
      2: 'Februar',
      3: 'Mart',
      4: 'April',
      5: 'Maj',
      6: 'Jun',
      7: 'Jul',
      8: 'Avgust',
      9: 'Septembar',
      10: 'Oktobar',
      11: 'Novembar',
      12: 'Decembar',
    };

    return Card(
      color: Colors.white.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '💰 Istorija plaćanja',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_istorijaPl.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade400, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Nema podataka o plaćanjima',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ..._istorijaPl.map((placanje) {
                final mesec = placanje['mesec'] as int;
                final godina = placanje['godina'] as int;
                final iznos = placanje['iznos'] as double;
                final datum = placanje['datum'] as DateTime?;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      // Mesec i godina
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${meseci[mesec]} $godina',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (datum != null)
                              Text(
                                'Plaćeno: ${DateFormat('dd.MM.yyyy').format(datum)}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Iznos
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${iznos.toStringAsFixed(0)} RSD',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
