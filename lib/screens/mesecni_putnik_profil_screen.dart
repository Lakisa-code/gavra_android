import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/route_config.dart';
import '../theme.dart';
import '../widgets/driver_tracking_widget.dart';
import '../widgets/nedelja_zakazivanje_widget.dart';

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
  int _brojOtkazivanja = 0;
  // ignore: unused_field
  double _dugovanje = 0.0;
  List<Map<String, dynamic>> _istorijaPl = [];

  // 📊 Statistike - detaljno po datumima
  Map<String, List<DateTime>> _voznjeDetaljno = {}; // mesec -> lista datuma vožnji
  Map<String, List<DateTime>> _otkazivanjaDetaljno = {}; // mesec -> lista datuma otkazivanja
  double _ukupnoZaduzenje = 0.0; // ukupno zaduženje za celu godinu
  String? _adresaBC; // BC adresa
  String? _adresaVS; // VS adresa

  // 🚐 GPS Tracking za praćenje kombija
  double? _putnikLat;
  double? _putnikLng;
  String? _sledeciPolazak; // vreme sledećeg polaska za koji se prikazuje tracking
  String _smerTure = 'BC_VS'; // BC_VS ili VS_BC - za filtriranje GPS trackinga

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
      final pocetakGodine = DateTime(now.year, 1, 1);

      // Broj vožnji ovog meseca (samo završene, ne otkazane)
      final voznje = await Supabase.instance.client
          .from('putovanja_istorija')
          .select('id')
          .eq('mesecni_putnik_id', putnikId)
          .gte('datum_putovanja', startOfMonth.toIso8601String().split('T')[0])
          .neq('status', 'otkazano')
          .count();

      // Broj otkazivanja ovog meseca
      final otkazivanja = await Supabase.instance.client
          .from('putovanja_istorija')
          .select('id')
          .eq('mesecni_putnik_id', putnikId)
          .gte('datum_putovanja', startOfMonth.toIso8601String().split('T')[0])
          .eq('status', 'otkazano')
          .count();

      // Dugovanje
      final dug = _putnikData['dug'] ?? 0;

      // 🏠 Učitaj obe adrese iz tabele adrese (sa koordinatama za GPS tracking)
      String? adresaBcNaziv;
      String? adresaVsNaziv;
      double? putnikLat;
      double? putnikLng;
      final adresaBcId = _putnikData['adresa_bela_crkva_id'] as String?;
      final adresaVsId = _putnikData['adresa_vrsac_id'] as String?;
      final grad = _putnikData['grad'] as String? ?? 'BC';

      debugPrint('🏠 adresaBcId: $adresaBcId, adresaVsId: $adresaVsId');
      debugPrint('🏠 _putnikData keys: ${_putnikData.keys.toList()}');

      try {
        if (adresaBcId != null && adresaBcId.isNotEmpty) {
          final bcResponse = await Supabase.instance.client
              .from('adrese')
              .select('naziv, koordinate')
              .eq('id', adresaBcId)
              .maybeSingle();
          if (bcResponse != null) {
            adresaBcNaziv = bcResponse['naziv'] as String?;
            // Koordinate za BC adresu
            if (grad == 'BC' && bcResponse['koordinate'] != null) {
              final koordinate = bcResponse['koordinate'];
              if (koordinate is Map) {
                putnikLat = (koordinate['lat'] as num?)?.toDouble();
                putnikLng = (koordinate['lng'] as num?)?.toDouble();
              }
            }
          }
        }
        if (adresaVsId != null && adresaVsId.isNotEmpty) {
          final vsResponse = await Supabase.instance.client
              .from('adrese')
              .select('naziv, koordinate')
              .eq('id', adresaVsId)
              .maybeSingle();
          if (vsResponse != null) {
            adresaVsNaziv = vsResponse['naziv'] as String?;
            // Koordinate za VS adresu
            if (grad == 'VS' && vsResponse['koordinate'] != null) {
              final koordinate = vsResponse['koordinate'];
              if (koordinate is Map) {
                putnikLat = (koordinate['lat'] as num?)?.toDouble();
                putnikLng = (koordinate['lng'] as num?)?.toDouble();
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Greška pri učitavanju adresa: $e');
      }

      // 🚐 Određivanje sledećeg polaska za GPS tracking
      String? sledeciPolazak;

      // 🧪 DEBUG MODE: Uvek prikazuj tracking widget za testiranje
      const bool debugAlwaysShowTracking = true; // POSTAVI NA false ZA PRODUKCIJU!

      // Dobavi vremena polazaka iz RouteConfig (zimski red)
      final vremenaPolazaka = RouteConfig.getVremenaPolazaka(
        grad: grad,
        letnji: false, // TODO: dodati proveru za letnji/zimski red
      );

      if (debugAlwaysShowTracking) {
        // Za testiranje - uzmi prvi sledeći polazak ili prvi u listi
        sledeciPolazak = _getNextPolazak(vremenaPolazaka, now.hour, now.minute) ?? vremenaPolazaka.first;
        debugPrint('🧪 DEBUG MODE: Forsiram prikaz tracking widgeta sa polaskom $sledeciPolazak');
      } else {
        sledeciPolazak = _getNextPolazak(vremenaPolazaka, now.hour, now.minute);
      }

      debugPrint('🚐 Sledeći polazak za $grad: $sledeciPolazak, koordinate: $putnikLat, $putnikLng');

      // 💰 Istorija plaćanja - poslednjih 6 meseci
      final istorija = await _loadIstorijuPlacanja(putnikId);

      // 📊 Vožnje po mesecima (cela godina)
      final sveVoznje = await Supabase.instance.client
          .from('putovanja_istorija')
          .select('datum_putovanja, status, created_at')
          .eq('mesecni_putnik_id', putnikId)
          .gte('datum_putovanja', pocetakGodine.toIso8601String().split('T')[0])
          .order('datum_putovanja', ascending: false);

      // Grupiši podatke DETALJNO po datumima
      final Map<String, List<DateTime>> voznjeDetaljnoMap = {};
      final Map<String, List<DateTime>> otkazivanjaDetaljnoMap = {};

      for (final v in sveVoznje) {
        final datumStr = v['datum_putovanja'] as String?;
        if (datumStr == null) continue;

        final datum = DateTime.tryParse(datumStr);
        if (datum == null) continue;

        final mesecKey = '${datum.year}-${datum.month.toString().padLeft(2, '0')}';
        final status = v['status'] as String?;

        if (status == 'otkazano') {
          otkazivanjaDetaljnoMap[mesecKey] = [...(otkazivanjaDetaljnoMap[mesecKey] ?? []), datum];
        } else {
          voznjeDetaljnoMap[mesecKey] = [...(voznjeDetaljnoMap[mesecKey] ?? []), datum];
        }
      }

      // Izračunaj ukupno zaduženje
      final tip = _putnikData['tip'] ?? 'radnik';
      final cenaPoVoznji = tip == 'ucenik' ? 600.0 : 700.0;
      double ukupnoVoznji = 0;
      for (final lista in voznjeDetaljnoMap.values) {
        ukupnoVoznji += lista.length;
      }
      final ukupnoZaplacanje = ukupnoVoznji * cenaPoVoznji;

      // Ukupno plaćeno
      double ukupnoPlaceno = 0;
      for (final p in istorija) {
        ukupnoPlaceno += (p['iznos'] as double? ?? 0);
      }

      final zaduzenje = ukupnoZaplacanje - ukupnoPlaceno;

      setState(() {
        _brojVoznji = voznje.count;
        _brojOtkazivanja = otkazivanja.count;
        _dugovanje = (dug is int) ? dug.toDouble() : (dug as double);
        _istorijaPl = istorija;
        _voznjeDetaljno = voznjeDetaljnoMap;
        _otkazivanjaDetaljno = otkazivanjaDetaljnoMap;
        _ukupnoZaduzenje = zaduzenje;
        _adresaBC = adresaBcNaziv;
        _adresaVS = adresaVsNaziv;
        _putnikLat = putnikLat;
        _putnikLng = putnikLng;
        _sledeciPolazak = sledeciPolazak;
        // Odredi smer ture - ako je grad BC, putnik ide BC->VS, ako je VS ide VS->BC
        _smerTure = (grad == 'BC' || grad == 'Bela Crkva') ? 'BC_VS' : 'VS_BC';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Greška pri učitavanju statistika: $e');
      setState(() => _isLoading = false);
    }
  }

  /// 🕐 Nađi sledeći polazak na osnovu trenutnog vremena
  String? _getNextPolazak(List<String> vremena, int currentHour, int currentMinute) {
    final currentMinutes = currentHour * 60 + currentMinute;

    for (final vreme in vremena) {
      final parts = vreme.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final polazakMinutes = hour * 60 + minute;

      // Ako je polazak za više od 30 minuta od sada, to je sledeći
      if (polazakMinutes > currentMinutes - 30) {
        return vreme;
      }
    }

    return null; // Nema više polazaka danas
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
    // Ime može biti u 'putnik_ime' ili odvojeno 'ime'/'prezime'
    final putnikIme = _putnikData['putnik_ime'] as String? ?? '';
    final ime = _putnikData['ime'] as String? ?? '';
    final prezime = _putnikData['prezime'] as String? ?? '';
    final fullName = putnikIme.isNotEmpty ? putnikIme : '$ime $prezime'.trim();

    // Razdvoji ime i prezime za avatar
    final nameParts = fullName.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.last : '';

    final telefon = _putnikData['broj_telefona'] as String? ?? '-';
    // ignore: unused_local_variable
    final grad = _putnikData['grad'] as String? ?? 'BC';
    final tip = _putnikData['tip'] as String? ?? 'radnik';
    // ignore: unused_local_variable
    final aktivan = _putnikData['aktivan'] as bool? ?? true;

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
                      // 🚐 GPS Tracking - prikaži ako postoje koordinate i sledeći polazak
                      if (_putnikLat != null && _putnikLng != null && _sledeciPolazak != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: DriverTrackingWidget(
                            grad: grad,
                            vremePolaska: _sledeciPolazak!,
                            smer: _smerTure, // BC_VS ili VS_BC - samo za tu turu
                            putnikLat: _putnikLat!,
                            putnikLng: _putnikLng!,
                            putnikAdresa:
                                grad == 'BC' ? (_adresaBC ?? 'Nepoznata adresa') : (_adresaVS ?? 'Nepoznata adresa'),
                          ),
                        ),

                      // Ime i status
                      Card(
                        color: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Avatar - glassmorphism stil
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: tip == 'ucenik'
                                        ? [Colors.blue.shade400, Colors.indigo.shade600]
                                        : [Colors.orange.shade400, Colors.deepOrange.shade600],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (tip == 'ucenik' ? Colors.blue : Colors.orange).withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '${firstName.isNotEmpty ? firstName[0].toUpperCase() : ''}${lastName.isNotEmpty ? lastName[0].toUpperCase() : ''}',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(1, 1),
                                          blurRadius: 3,
                                          color: Colors.black38,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Ime
                              Text(
                                fullName,
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
                                      color: tip == 'ucenik'
                                          ? Colors.blue.withValues(alpha: 0.3)
                                          : Colors.orange.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
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
                                  if (telefon.isNotEmpty && telefon != '-') ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.phone, color: Colors.white70, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            telefon,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Adrese - BC levo, VS desno
                              if (_adresaBC != null || _adresaVS != null)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_adresaBC != null && _adresaBC!.isNotEmpty) ...[
                                      Icon(Icons.home, color: Colors.white70, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        _adresaBC!,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                    if (_adresaBC != null && _adresaVS != null) const SizedBox(width: 16),
                                    if (_adresaVS != null && _adresaVS!.isNotEmpty) ...[
                                      Icon(Icons.work, color: Colors.white70, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        _adresaVS!,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ],
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
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 📊 Stanje računa i izvod
                      _buildStatistikePoMesecimaCard(),
                      const SizedBox(height: 16),

                      // 📅 Raspored polazaka
                      _buildRasporedCard(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(String emoji, String label, String value, Color color, String subtitle) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
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

  /// 📅 Widget za prikaz rasporeda polazaka po danima - GRID STIL kao "Vremena polaska"
  Widget _buildRasporedCard() {
    // Parsiranje polasci_po_danu iz putnikData
    final polasciRaw = _putnikData['polasci_po_danu'];
    debugPrint('🕐 polasci_po_danu raw: $polasciRaw');
    debugPrint('🕐 polasci_po_danu type: ${polasciRaw.runtimeType}');
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
    debugPrint('🕐 polasci parsed: $polasci');

    final dani = ['pon', 'uto', 'sre', 'cet', 'pet'];
    final daniLabels = {
      'pon': 'Ponedeljak',
      'uto': 'Utorak',
      'sre': 'Sreda',
      'cet': 'Četvrtak',
      'pet': 'Petak',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Expanded(
                child: Text(
                  '🕐 Vremena polaska',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Dugme za zakazivanje
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: TextButton.icon(
                  onPressed: () {
                    showZakazivanjeDialog(
                      context,
                      putnikId: _putnikData['id'] ?? '',
                      putnikIme: _putnikData['putnik_ime'] ?? 'Putnik',
                      onSaved: () => _loadStatistike(),
                    );
                  },
                  icon: const Icon(Icons.edit_calendar, size: 16, color: Colors.white),
                  label: const Text('Zakaži', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Header row - BC / VS
          Row(
            children: [
              const SizedBox(width: 100), // Prostor za naziv dana
              Expanded(
                child: Center(
                  child: Text(
                    'BC',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Grid za svaki dan
          ...dani.map((dan) {
            final danPolasci = polasci[dan];
            final bcVreme = danPolasci?['bc'];
            final vsVreme = danPolasci?['vs'];

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Naziv dana
                  SizedBox(
                    width: 100,
                    child: Text(
                      daniLabels[dan] ?? dan,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // BC vreme
                  Expanded(
                    child: Center(
                      child: _buildTimeBox(bcVreme),
                    ),
                  ),
                  // VS vreme
                  Expanded(
                    child: Center(
                      child: _buildTimeBox(vsVreme),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Helper za prikaz vremena u box-u
  Widget _buildTimeBox(String? vreme) {
    final hasTime = vreme != null && vreme.isNotEmpty;
    return Container(
      width: 70,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Center(
        child: hasTime
            ? Text(
                vreme,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              )
            : Icon(
                Icons.access_time,
                color: Colors.grey.shade400,
                size: 18,
              ),
      ),
    );
  }

  /// 📊 Widget za prikaz stanja računa
  Widget _buildStatistikePoMesecimaCard() {
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

    final daniUNedelji = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];

    // Cena po tipu
    final tip = _putnikData['tip'] ?? 'radnik';
    final cenaPoVoznji = tip == 'ucenik' ? 600.0 : 700.0;

    // Sortiraj mesece od najnovijeg
    final sortedKeys = <String>{
      ..._voznjeDetaljno.keys,
      ..._otkazivanjaDetaljno.keys,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).glassBorder, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header sa ukupnim stanjem
            Row(
              children: [
                const Text(
                  '💰 Stanje računa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // TRENUTNO STANJE - veliko i vidljivo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _ukupnoZaduzenje > 0
                      ? [Colors.red.withValues(alpha: 0.3), Colors.red.withValues(alpha: 0.1)]
                      : [Colors.green.withValues(alpha: 0.3), Colors.green.withValues(alpha: 0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _ukupnoZaduzenje > 0 ? Colors.red.withValues(alpha: 0.5) : Colors.green.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'VAŠE TRENUTNO STANJE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _ukupnoZaduzenje > 0 ? '${_ukupnoZaduzenje.toStringAsFixed(0)} RSD' : 'IZMIRENO ✓',
                    style: TextStyle(
                      color: _ukupnoZaduzenje > 0 ? Colors.red.shade100 : Colors.green.shade100,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_ukupnoZaduzenje > 0)
                    Text(
                      'dugovanje',
                      style: TextStyle(
                        color: Colors.red.shade200,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Linija razdvajanja
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.1),
            ),

            const SizedBox(height: 16),

            // IZVOD PO MESECIMA
            const Text(
              '📋 Izvod po mesecima',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            if (sortedKeys.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Nema podataka o vožnjama',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ...sortedKeys.map((key) {
                final parts = key.split('-');
                final godina = int.parse(parts[0]);
                final mesecNum = int.parse(parts[1]);
                final mesecNaziv = meseci[mesecNum] ?? key;

                final voznjeList = _voznjeDetaljno[key] ?? [];
                final otkazivanjaList = _otkazivanjaDetaljno[key] ?? [];
                final brojVoznji = voznjeList.length;
                final brojOtkazivanja = otkazivanjaList.length;

                final ukupnoZaMesec = brojVoznji * cenaPoVoznji;

                // Plaćeno za ovaj mesec
                final placenoZaMesec = _istorijaPl
                    .where((p) => p['mesec'] == mesecNum && p['godina'] == godina)
                    .fold<double>(0, (sum, p) => sum + (p['iznos'] as double? ?? 0));

                final dugujeZaMesec = ukupnoZaMesec - placenoZaMesec;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    iconColor: Colors.white70,
                    collapsedIconColor: Colors.white70,
                    title: Row(
                      children: [
                        Text(
                          '$mesecNaziv $godina',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: dugujeZaMesec > 0
                                ? Colors.red.withValues(alpha: 0.3)
                                : Colors.green.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dugujeZaMesec > 0 ? '${dugujeZaMesec.toStringAsFixed(0)} RSD' : '✓',
                            style: TextStyle(
                              color: dugujeZaMesec > 0 ? Colors.red.shade100 : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '$brojVoznji vožnji × ${cenaPoVoznji.toStringAsFixed(0)} = ${ukupnoZaMesec.toStringAsFixed(0)} RSD',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    children: [
                      // VOŽNJE PO DANIMA
                      if (voznjeList.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('🚌', style: TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Vožnje ($brojVoznji)',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: voznjeList.map((datum) {
                                  final dan = daniUNedelji[datum.weekday - 1];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$dan ${datum.day}.${datum.month}.',
                                      style: TextStyle(
                                        color: Colors.green.shade100,
                                        fontSize: 11,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // OTKAZIVANJA PO DANIMA
                      if (otkazivanjaList.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('❌', style: TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Otkazivanja ($brojOtkazivanja)',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: otkazivanjaList.map((datum) {
                                  final dan = daniUNedelji[datum.weekday - 1];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$dan ${datum.day}.${datum.month}.',
                                      style: TextStyle(
                                        color: Colors.orange.shade100,
                                        fontSize: 11,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ZBIR ZA MESEC
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            _buildZbirRow('Ukupno vožnji:', '$brojVoznji × ${cenaPoVoznji.toStringAsFixed(0)}',
                                '${ukupnoZaMesec.toStringAsFixed(0)} RSD'),
                            const SizedBox(height: 6),
                            _buildZbirRow('Plaćeno:', '', '${placenoZaMesec.toStringAsFixed(0)} RSD',
                                color: Colors.green),
                            const Divider(color: Colors.white24, height: 16),
                            _buildZbirRow(
                              dugujeZaMesec > 0 ? 'Za uplatu:' : 'Stanje:',
                              '',
                              dugujeZaMesec > 0 ? '${dugujeZaMesec.toStringAsFixed(0)} RSD' : 'IZMIRENO ✓',
                              color: dugujeZaMesec > 0 ? Colors.red : Colors.green,
                              bold: true,
                            ),
                          ],
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

  Widget _buildZbirRow(String label, String formula, String value, {Color? color, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (formula.isNotEmpty)
          Text(
            formula,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
