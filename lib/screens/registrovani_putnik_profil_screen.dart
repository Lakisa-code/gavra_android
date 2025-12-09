import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/route_config.dart';
import '../services/slobodna_mesta_service.dart'; // 🎫 Promena vremena
import '../services/theme_manager.dart';
import '../theme.dart';
import '../utils/schedule_utils.dart';
import '../widgets/kombi_eta_widget.dart'; // 🆕 Jednostavan ETA widget
import '../widgets/shared/time_picker_cell.dart';
import '../widgets/slobodna_mesta_widget.dart'; // 🎫 Slobodna mesta widget

/// 📊 MESEČNI PUTNIK PROFIL SCREEN
/// Prikazuje podatke o mesečnom putniku: raspored, vožnje, dugovanja
class RegistrovaniPutnikProfilScreen extends StatefulWidget {
  final Map<String, dynamic> putnikData;

  const RegistrovaniPutnikProfilScreen({
    Key? key,
    required this.putnikData,
  }) : super(key: key);

  @override
  State<RegistrovaniPutnikProfilScreen> createState() => _RegistrovaniPutnikProfilScreenState();
}

class _RegistrovaniPutnikProfilScreenState extends State<RegistrovaniPutnikProfilScreen> {
  Map<String, dynamic> _putnikData = {};
  bool _isLoading = false;
  int _brojVoznji = 0;
  int _brojOtkazivanja = 0;
  // ignore: unused_field
  double _dugovanje = 0.0;
  List<Map<String, dynamic>> _istorijaPl = [];

  // 📊 Statistike - detaljno po datumima (Set za jedinstvene datume)
  Map<String, Set<String>> _voznjeDetaljno = {}; // mesec -> set jedinstvenih datuma vožnji
  Map<String, Set<String>> _otkazivanjaDetaljno = {}; // mesec -> set jedinstvenih datuma otkazivanja
  double _ukupnoZaduzenje = 0.0; // ukupno zaduženje za celu godinu
  String? _adresaBC; // BC adresa
  String? _adresaVS; // VS adresa

  // 🚐 GPS Tracking - više se ne koristi direktno, ETA se čita iz KombiEtaWidget
  // ignore: unused_field
  double? _putnikLat;
  // ignore: unused_field
  double? _putnikLng;
  // ignore: unused_field
  String? _sledeciPolazak;
  // ignore: unused_field
  String _smerTure = 'BC_VS';

  @override
  void initState() {
    super.initState();
    _putnikData = Map<String, dynamic>.from(widget.putnikData);
    _refreshPutnikData(); // 🔄 Učitaj sveže podatke iz baze
    _loadStatistike();
  }

  /// 🔄 Osvežava podatke putnika iz baze
  Future<void> _refreshPutnikData() async {
    try {
      final putnikId = _putnikData['id'];
      if (putnikId == null) return;

      final response = await Supabase.instance.client
          .from('registrovani_putnici')
          .select()
          .eq('id', putnikId)
          .single();

      if (mounted && response != null) {
        setState(() {
          _putnikData = Map<String, dynamic>.from(response);
        });
      }
    } catch (e) {
      debugPrint('❌ Greška pri osvežavanju podataka: $e');
    }
  }

  Future<void> _loadStatistike() async {
    setState(() => _isLoading = true);

    try {
      final putnikId = _putnikData['id'];
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final pocetakGodine = DateTime(now.year, 1, 1);

      // Broj vožnji ovog meseca - JEDINSTVENI DATUMI (1 dan = 1 vožnja)
      // VOŽNJA = samo kada je status 'pokupljen'
      // Kolona 'pokupljen' boolean NE POSTOJI u tabeli putovanja_istorija
      final voznjeResponse = await Supabase.instance.client
          .from('putovanja_istorija')
          .select('datum_putovanja')
          .eq('registrovani_putnik_id', putnikId)
          .gte('datum_putovanja', startOfMonth.toIso8601String().split('T')[0])
          .eq('status', 'pokupljen');

      // Broji jedinstvene datume
      final jedinstveniDatumiVoznji = <String>{};
      for (final v in voznjeResponse) {
        final datum = v['datum_putovanja'] as String?;
        if (datum != null) jedinstveniDatumiVoznji.add(datum);
      }
      final brojVoznji = jedinstveniDatumiVoznji.length;

      // Broj otkazivanja ovog meseca - JEDINSTVENI DATUMI
      // NAPOMENA: U bazi je status 'otkazan' (ne 'otkazano')
      final otkazivanjaResponse = await Supabase.instance.client
          .from('putovanja_istorija')
          .select('datum_putovanja')
          .eq('registrovani_putnik_id', putnikId)
          .gte('datum_putovanja', startOfMonth.toIso8601String().split('T')[0])
          .eq('status', 'otkazan');

      // Broji jedinstvene datume otkazivanja
      final jedinstveniDatumiOtkazivanja = <String>{};
      for (final o in otkazivanjaResponse) {
        final datum = o['datum_putovanja'] as String?;
        if (datum != null) jedinstveniDatumiOtkazivanja.add(datum);
      }
      final brojOtkazivanja = jedinstveniDatumiOtkazivanja.length;

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

      // Dobavi vremena polazaka iz RouteConfig (automatski letnji/zimski)
      final vremenaPolazaka = RouteConfig.getVremenaPolazaka(
        grad: grad,
        letnji: !isZimski(now), // Automatska provera sezone
      );

      // Za testiranje - uzmi prvi sledeći polazak ili prvi u listi
      sledeciPolazak = _getNextPolazak(vremenaPolazaka, now.hour, now.minute) ??
          (debugAlwaysShowTracking && vremenaPolazaka.isNotEmpty ? vremenaPolazaka.first : null);
      if (debugAlwaysShowTracking && sledeciPolazak != null) {
        debugPrint('🧪 DEBUG MODE: Forsiram prikaz tracking widgeta sa polaskom $sledeciPolazak');
      }

      debugPrint('🚐 Sledeći polazak za $grad: $sledeciPolazak, koordinate: $putnikLat, $putnikLng');

      // 💰 Istorija plaćanja - poslednjih 6 meseci
      final istorija = await _loadIstorijuPlacanja(putnikId);

      // 📊 Vožnje po mesecima (cela godina)
      final sveVoznje = await Supabase.instance.client
          .from('putovanja_istorija')
          .select('datum_putovanja, status, created_at')
          .eq('registrovani_putnik_id', putnikId)
          .gte('datum_putovanja', pocetakGodine.toIso8601String().split('T')[0])
          .order('datum_putovanja', ascending: false);

      // Grupiši podatke po JEDINSTVENIM datumima (Set eliminiše duplikate)
      // VOŽNJA = samo status 'pokupljen' (jedinstveni datum)
      // OTKAZIVANJE = samo status 'otkazan' (u bazi je 'otkazan', ne 'otkazano')
      final Map<String, Set<String>> voznjeDetaljnoMap = {};
      final Map<String, Set<String>> otkazivanjaDetaljnoMap = {};

      for (final v in sveVoznje) {
        final datumStr = v['datum_putovanja'] as String?;
        if (datumStr == null) continue;

        final datum = DateTime.tryParse(datumStr);
        if (datum == null) continue;

        final mesecKey = '${datum.year}-${datum.month.toString().padLeft(2, '0')}';
        final status = v['status'] as String?;

        if (status == 'otkazan') {
          // Otkazivanja - status je 'otkazan' u bazi
          otkazivanjaDetaljnoMap[mesecKey] = {...(otkazivanjaDetaljnoMap[mesecKey] ?? {}), datumStr};
        } else if (status == 'pokupljen') {
          // Vožnje - SAMO status 'pokupljen' se broji kao vožnja
          voznjeDetaljnoMap[mesecKey] = {...(voznjeDetaljnoMap[mesecKey] ?? {}), datumStr};
        }
        // Ignoriši: placeno, resetovan, nije_se_pojavio, radi
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
        _brojVoznji = brojVoznji;
        _brojOtkazivanja = brojOtkazivanja;
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
          .eq('registrovani_putnik_id', putnikId)
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
      await prefs.remove('registrovani_putnik_telefon');

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
      decoration: BoxDecoration(
        gradient: ThemeManager().currentGradient,
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
              icon: const Icon(Icons.palette, color: Colors.white),
              tooltip: 'Tema',
              onPressed: () async {
                await ThemeManager().nextTheme();
                if (mounted) setState(() {});
              },
            ),
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
                      // Ime i status - Flow dizajn bez Card okvira
                      Padding(
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
                                        : tip == 'dnevni'
                                            ? Colors.green.withValues(alpha: 0.3)
                                            : Colors.orange.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    tip == 'ucenik'
                                        ? '🎓 Učenik'
                                        : tip == 'dnevni'
                                            ? '📅 Dnevni'
                                            : '💼 Radnik',
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
                      const SizedBox(height: 16),

                      // ─────────── Divider ───────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Divider(color: Colors.white.withValues(alpha: 0.2), thickness: 1),
                      ),

                      // 🚐 ETA Widget - prikazuje "Kombi stiže za X min" ako je vozač aktivan
                      KombiEtaWidget(
                        putnikIme: ime,
                        grad: grad,
                      ),

                      // ─────────── Divider ───────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Divider(color: Colors.white.withValues(alpha: 0.2), thickness: 1),
                      ),

                      // 🎫 Slobodna mesta Widget - prikazuje slobodna mesta po terminima
                      SlobodnaMestaWidget(
                        putnikId: _putnikData['id']?.toString(),
                        putnikGrad: grad,
                        putnikVreme: _putnikData['polazak']?.toString(),
                        onPromenaVremena: (novoVreme) async {
                          // Format: 'GRAD|VREME' npr. 'BC|7:00'
                          final parts = novoVreme.split('|');
                          if (parts.length != 2) return;

                          final noviGrad = parts[0];
                          final novoVremeValue = parts[1];

                          // Odredi dan
                          final danas = DateTime.now();
                          const dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
                          final dan = dani[danas.weekday - 1];

                          // Sačuvaj messenger pre async poziva
                          final messenger = ScaffoldMessenger.of(context);

                          final result = await SlobodnaMestaService.promeniVremePutnika(
                            putnikId: _putnikData['id']?.toString() ?? '',
                            novoVreme: novoVremeValue,
                            grad: noviGrad,
                            dan: dan,
                          );

                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(result['message'] as String),
                                backgroundColor: result['success'] == true ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                      ),

                      // ─────────── Divider ───────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Divider(color: Colors.white.withValues(alpha: 0.2), thickness: 1),
                      ),
                      const SizedBox(height: 8),

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
    // Flow dizajn - bez Card okvira
    return Padding(
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
    );
  }

  /// 📅 Widget za prikaz rasporeda polazaka po danima - GRID STIL kao "Vremena polaska"
  Widget _buildRasporedCard() {
    // Parsiranje polasci_po_danu iz putnikData
    final polasciRaw = _putnikData['polasci_po_danu'];
    debugPrint('🕐 polasci_po_danu raw: $polasciRaw');
    debugPrint('🕐 polasci_po_danu type: ${polasciRaw.runtimeType}');
    Map<String, Map<String, String?>> polasci = {};

    // Helper funkcija za sigurno parsiranje vremena
    String? parseVreme(dynamic value) {
      if (value == null) return null;
      final str = value.toString().trim();
      if (str.isEmpty || str == 'null') return null;
      return str;
    }

    if (polasciRaw != null && polasciRaw is Map) {
      polasciRaw.forEach((key, value) {
        if (value is Map) {
          polasci[key.toString()] = {
            'bc': parseVreme(value['bc']),
            'vs': parseVreme(value['vs']),
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
          const Center(
            child: Text(
              '🕐 Vremena polaska',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                  // BC vreme - sa TimePickerCell
                  Expanded(
                    child: Center(
                      child: TimePickerCell(
                        value: bcVreme,
                        isBC: true,
                        onChanged: (newValue) => _updatePolazak(dan, 'bc', newValue),
                      ),
                    ),
                  ),
                  // VS vreme - sa TimePickerCell
                  Expanded(
                    child: Center(
                      child: TimePickerCell(
                        value: vsVreme,
                        isBC: false,
                        onChanged: (newValue) => _updatePolazak(dan, 'vs', newValue),
                      ),
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

  /// 🕐 Ažurira polazak za određeni dan i čuva u bazu
  Future<void> _updatePolazak(String dan, String tipGrad, String? novoVreme) async {
    try {
      final tipPutnika = (_putnikData['tip'] as String?)?.toLowerCase() ?? 'radnik';
      final putnikId = _putnikData['id']?.toString();
      final sada = DateTime.now();
      const daniLista = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      final danasDan = daniLista[sada.weekday - 1];
      final jeZaDanas = dan.toLowerCase() == danasDan.toLowerCase();

      // ═══════════════════════════════════════════════════════════════
      // 🎓 OGRANIČENJA ZA UČENIKE
      // ═══════════════════════════════════════════════════════════════
      if (tipPutnika == 'ucenik') {
        // 1. Proveri da li je pre 16h
        if (sada.hour >= 16) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⏰ Promene su dozvoljene samo do 16:00h'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // 2. Proveri broj promena za ciljni dan
        if (putnikId != null) {
          final brojPromena = await SlobodnaMestaService.brojPromenaZaDan(putnikId, dan);

          if (jeZaDanas) {
            // Za DANAŠNJI dan: max 1 promena
            if (brojPromena >= 1) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Za današnji dan možete promeniti vreme samo jednom.'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
              return;
            }
          } else {
            // Za BUDUĆE dane: max 3 promene
            if (brojPromena >= 3) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('⚠️ Za $dan ste već napravili 3 promene danas.'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
              return;
            }
          }
        }
      }

      // Ažuriraj lokalno
      final polasciRaw = _putnikData['polasci_po_danu'] ?? {};
      Map<String, Map<String, String?>> polasci = {};

      if (polasciRaw is Map) {
        polasciRaw.forEach((key, value) {
          if (value is Map) {
            polasci[key.toString()] = {
              'bc': value['bc']?.toString(),
              'vs': value['vs']?.toString(),
            };
            // Očisti "null" stringove
            if (polasci[key.toString()]!['bc'] == 'null') {
              polasci[key.toString()]!['bc'] = null;
            }
            if (polasci[key.toString()]!['vs'] == 'null') {
              polasci[key.toString()]!['vs'] = null;
            }
          } else {
            polasci[key.toString()] = {'bc': null, 'vs': null};
          }
        });
      }

      // Osiguraj da dan postoji
      polasci[dan] ??= {'bc': null, 'vs': null};
      polasci[dan]![tipGrad] = novoVreme;

      // Sačuvaj u bazu
      if (putnikId != null) {
        await Supabase.instance.client
            .from('registrovani_putnici')
            .update({'polasci_po_danu': polasci}).eq('id', putnikId);

        // 🎓 Zapiši promenu za učenike (za ograničenje)
        if (tipPutnika == 'ucenik') {
          await SlobodnaMestaService.zapisiPromenuVremena(putnikId.toString(), dan);
        }

        // Ažuriraj lokalni state
        setState(() {
          _putnikData['polasci_po_danu'] = polasci;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Vreme sačuvano'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Greška pri čuvanju polaska: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
            // TRENUTNO STANJE - veliko i vidljivo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _ukupnoZaduzenje > 0
                      ? [Colors.red.withValues(alpha: 0.3), Colors.red.withValues(alpha: 0.1)]
                      : [Colors.green.withValues(alpha: 0.5), Colors.green.withValues(alpha: 0.25)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _ukupnoZaduzenje > 0 ? Colors.red.withValues(alpha: 0.5) : Colors.green.withValues(alpha: 0.6),
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
                  const SizedBox(height: 4),
                  Text(
                    _ukupnoZaduzenje > 0 ? '${_ukupnoZaduzenje.toStringAsFixed(0)} RSD' : 'IZMIRENO',
                    style: TextStyle(
                      color: _ukupnoZaduzenje > 0 ? Colors.red.shade100 : Colors.green.shade100,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
            const Center(
              child: Text(
                '📋 Izvod po mesecima',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
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

                // Konvertuj Set<String> u List<DateTime> za prikaz
                final voznjeSet = _voznjeDetaljno[key] ?? <String>{};
                final otkazivanjaSet = _otkazivanjaDetaljno[key] ?? <String>{};
                final voznjeList = voznjeSet.map((s) => DateTime.parse(s)).toList()..sort();
                final otkazivanjaList = otkazivanjaSet.map((s) => DateTime.parse(s)).toList()..sort();
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
                              dugujeZaMesec > 0 ? '${dugujeZaMesec.toStringAsFixed(0)} RSD' : 'IZMIRENO',
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
