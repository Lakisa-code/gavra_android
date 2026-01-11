import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/route_config.dart';
import '../helpers/putnik_statistike_helper.dart'; // 📊 Zajednički dijalog za statistike
import '../services/cena_obracun_service.dart';
import '../services/leaderboard_service.dart'; // 🏆💀 Leaderboard servis
import '../services/putnik_push_service.dart'; // 📱 Push notifikacije za putnike
import '../services/putnik_service.dart'; // 🏖️ Za bolovanje/godišnji
import '../services/seat_request_service.dart'; // 🎫 Smart Seat Request Service
import '../services/slobodna_mesta_service.dart'; // 🎫 Promena vremena
import '../services/theme_manager.dart';
import '../services/weather_service.dart'; // 🌤️ Vremenska prognoza
import '../theme.dart';
import '../utils/schedule_utils.dart';
import '../widgets/kombi_eta_widget.dart'; // 🆕 Jednostavan ETA widget
import '../widgets/shared/time_picker_cell.dart';

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
    _registerPushToken(); // 📱 Registruj push token (retry ako nije uspelo pri login-u)
    WeatherService.refreshAll(); // 🌤️ Učitaj vremensku prognozu
  }

  /// 📱 Registruje push token za notifikacije (retry mehanizam)
  Future<void> _registerPushToken() async {
    final putnikId = _putnikData['id'];
    if (putnikId != null) {
      await PutnikPushService.registerPutnikToken(putnikId);
    }
  }

  /// 🔄 Osvežava podatke putnika iz baze
  Future<void> _refreshPutnikData() async {
    try {
      final putnikId = _putnikData['id'];
      if (putnikId == null) return;

      final response = await Supabase.instance.client.from('registrovani_putnici').select().eq('id', putnikId).single();

      if (mounted) {
        setState(() {
          _putnikData = Map<String, dynamic>.from(response);
        });
      }
    } catch (e) {
      // Error refreshing data
    }
  }

  Future<void> _loadStatistike() async {
    setState(() => _isLoading = true);

    try {
      final putnikId = _putnikData['id'];
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final pocetakGodine = DateTime(now.year, 1, 1);

      // Koristi voznje_log za statistiku vožnji
      // Broj vožnji ovog meseca - JEDINSTVENI DATUMI
      final voznjeResponse = await Supabase.instance.client
          .from('voznje_log')
          .select('datum')
          .eq('putnik_id', putnikId)
          .gte('datum', startOfMonth.toIso8601String().split('T')[0])
          .eq('tip', 'voznja');

      // Broji jedinstvene datume
      final jedinstveniDatumiVoznji = <String>{};
      for (final v in voznjeResponse) {
        final datum = v['datum'] as String?;
        if (datum != null) jedinstveniDatumiVoznji.add(datum);
      }
      final brojVoznji = jedinstveniDatumiVoznji.length;

      // Broj otkazivanja ovog meseca - JEDINSTVENI DATUMI
      final otkazivanjaResponse = await Supabase.instance.client
          .from('voznje_log')
          .select('datum')
          .eq('putnik_id', putnikId)
          .gte('datum', startOfMonth.toIso8601String().split('T')[0])
          .eq('tip', 'otkazivanje');

      // Broji jedinstvene datume otkazivanja
      final jedinstveniDatumiOtkazivanja = <String>{};
      for (final o in otkazivanjaResponse) {
        final datum = o['datum'] as String?;
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
        // Error loading addresses
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

      // 💰 Istorija plaćanja - poslednjih 6 meseci
      final istorija = await _loadIstorijuPlacanja(putnikId);

      // 📊 Vožnje po mesecima (cela godina) - koristi voznje_log
      final sveVoznje = await Supabase.instance.client
          .from('voznje_log')
          .select('datum, tip, created_at')
          .eq('putnik_id', putnikId)
          .gte('datum', pocetakGodine.toIso8601String().split('T')[0])
          .order('datum', ascending: false);

      // Grupiši podatke po JEDINSTVENIM datumima
      final Map<String, Set<String>> voznjeDetaljnoMap = {};
      final Map<String, Set<String>> otkazivanjaDetaljnoMap = {};

      for (final v in sveVoznje) {
        final datumStr = v['datum'] as String?;
        if (datumStr == null) continue;

        final datum = DateTime.tryParse(datumStr);
        if (datum == null) continue;

        final mesecKey = '${datum.year}-${datum.month.toString().padLeft(2, '0')}';
        final tip = v['tip'] as String?;

        if (tip == 'otkazivanje') {
          // Otkazivanja
          otkazivanjaDetaljnoMap[mesecKey] = {...(otkazivanjaDetaljnoMap[mesecKey] ?? {}), datumStr};
        } else if (tip == 'voznja') {
          // Vožnje
          voznjeDetaljnoMap[mesecKey] = {...(voznjeDetaljnoMap[mesecKey] ?? {}), datumStr};
        }
      }

      // Izračunaj ukupno zaduženje
      final tipPutnika = _putnikData['tip'] ?? 'radnik';
      final cenaPoVoznji = CenaObracunService.getDefaultCenaByTip(tipPutnika);
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
  /// 🔄 POJEDNOSTAVLJENO: Koristi voznje_log
  Future<List<Map<String, dynamic>>> _loadIstorijuPlacanja(String putnikId) async {
    try {
      final now = DateTime.now();
      final pocetakGodine = DateTime(now.year, 1, 1);

      // Koristi voznje_log za uplate
      final placanja = await Supabase.instance.client
          .from('voznje_log')
          .select('iznos, datum, created_at')
          .eq('putnik_id', putnikId)
          .eq('tip', 'uplata')
          .gte('datum', pocetakGodine.toIso8601String().split('T')[0])
          .order('datum', ascending: false);

      // Grupiši po mesecima
      final Map<String, double> poMesecima = {};
      final Map<String, DateTime> poslednjeDatum = {};

      for (final p in placanja) {
        final datumStr = p['datum'] as String?;
        if (datumStr == null) continue;

        final datum = DateTime.tryParse(datumStr);
        if (datum == null) continue;

        final mesecKey = '${datum.year}-${datum.month.toString().padLeft(2, '0')}';
        final iznos = (p['iznos'] as num?)?.toDouble() ?? 0.0;

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

  /// 🏖️ Dugme za postavljanje bolovanja/godišnjeg - SAMO za radnike
  Widget _buildOdsustvoButton() {
    final status = _putnikData['status']?.toString().toLowerCase() ?? 'radi';
    final jeNaOdsustvu = status == 'bolovanje' || status == 'godisnji';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: ListTile(
          leading: Icon(
            jeNaOdsustvu ? Icons.work : Icons.beach_access,
            color: jeNaOdsustvu ? Colors.green : Colors.orange,
          ),
          title: Text(
            jeNaOdsustvu ? 'Vratite se na posao' : 'Godišnji / Bolovanje',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            jeNaOdsustvu
                ? 'Trenutno ste na ${status == "godisnji" ? "godišnjem odmoru" : "bolovanju"}'
                : 'Postavite se na odsustvo',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
          onTap: () => _pokaziOdsustvoDialog(jeNaOdsustvu),
        ),
      ),
    );
  }

  /// 🏖️ Dialog za odabir tipa odsustva ili vraćanje na posao
  Future<void> _pokaziOdsustvoDialog(bool jeNaOdsustvu) async {
    if (jeNaOdsustvu) {
      // Vraćanje na posao
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Row(
            children: [
              Icon(Icons.work, color: Colors.green),
              SizedBox(width: 8),
              Expanded(child: Text('Povratak na posao')),
            ],
          ),
          content: const Text('Da li želite da se vratite na posao?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ne'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Da, vraćam se'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _postaviStatus('radi');
      }
    } else {
      // Odabir tipa odsustva
      final odabraniStatus = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Row(
            children: [
              Icon(Icons.beach_access, color: Colors.orange),
              SizedBox(width: 8),
              Text('Odsustvo'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Izaberite tip odsustva:'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'godisnji'),
                  icon: const Icon(Icons.beach_access),
                  label: const Text('🏖️ Godišnji odmor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'bolovanje'),
                  icon: const Icon(Icons.sick),
                  label: const Text('🤒 Bolovanje'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Odustani'),
            ),
          ],
        ),
      );

      if (odabraniStatus != null) {
        await _postaviStatus(odabraniStatus);
      }
    }
  }

  /// 🔄 Postavi status putnika u bazu
  Future<void> _postaviStatus(String noviStatus) async {
    try {
      final putnikId = _putnikData['id']?.toString();
      if (putnikId == null) return;

      await PutnikService().oznaciBolovanjeGodisnji(
        putnikId,
        noviStatus,
        'self', // Radnik sam sebi menja status
      );

      // Ažuriraj lokalni state
      setState(() {
        _putnikData['status'] = noviStatus;
      });

      if (mounted) {
        final poruka = noviStatus == 'radi'
            ? '✅ Vraćeni ste na posao'
            : noviStatus == 'godisnji'
                ? '🏖️ Postavljeni ste na godišnji odmor'
                : '🤒 Postavljeni ste na bolovanje';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(poruka),
            backgroundColor: noviStatus == 'radi' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🌤️ KOMPAKTAN PRIKAZ TEMPERATURE ZA GRAD (isti kao na danas_screen)
  Widget _buildWeatherCompact(String grad) {
    final stream = grad == 'BC' ? WeatherService.bcWeatherStream : WeatherService.vsWeatherStream;

    return StreamBuilder<WeatherData?>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final temp = data?.temperature;
        final icon = data?.icon ?? '🌡️';
        final tempStr = temp != null ? '${temp.round()}°' : '--';
        final tempColor = temp != null
            ? (temp < 0
                ? Colors.lightBlue
                : temp < 15
                    ? Colors.cyan
                    : temp < 25
                        ? Colors.green
                        : Colors.orange)
            : Colors.grey;

        // Widget za ikonu - slika ili emoji (usklađene veličine)
        Widget iconWidget;
        if (WeatherData.isAssetIcon(icon)) {
          iconWidget = Image.asset(
            WeatherData.getAssetPath(icon),
            width: 32,
            height: 32,
          );
        } else {
          iconWidget = Text(icon, style: const TextStyle(fontSize: 14));
        }

        return GestureDetector(
          onTap: () => _showWeatherDialog(grad, data),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              const SizedBox(width: 2),
              Text(
                '$grad $tempStr',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tempColor,
                  shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black54)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🏆💀 MINI LEADERBOARD - Fame ili Shame
  Widget _buildMiniLeaderboard({required bool isShame}) {
    return FutureBuilder<LeaderboardData?>(
      future: LeaderboardService.getLeaderboard(tipPutnika: _putnikData['tip'] as String? ?? 'radnik'),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        final entries = isShame ? data.wallOfShame : data.wallOfFame;
        final title = isShame ? '💀 Shame' : '🏆 Fame';
        final titleColor = isShame ? Colors.redAccent : Colors.greenAccent;

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isShame
                  ? [Colors.red.shade900.withValues(alpha: 0.15), Colors.orange.shade900.withValues(alpha: 0.1)]
                  : [Colors.green.shade900.withValues(alpha: 0.15), Colors.teal.shade900.withValues(alpha: 0.1)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (isShame ? Colors.red : Colors.green).withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              if (entries.isEmpty)
                Text(
                  'Nema podataka',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ...entries.take(3).toList().asMap().entries.map((e) {
                  final rank = e.key + 1;
                  final entry = e.value;
                  String displayName = entry.ime;
                  if (displayName.length > 10) {
                    final parts = displayName.split(' ');
                    if (parts.length >= 2) {
                      displayName = '${parts[0]} ${parts[1][0]}.';
                    } else {
                      displayName = '${displayName.substring(0, 8)}..';
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      children: [
                        Text(
                          '$rank.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(entry.icon, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  // 🌤️ DIJALOG ZA DETALJNU VREMENSKU PROGNOZU
  void _showWeatherDialog(String grad, WeatherData? data) {
    final gradPun = grad == 'BC' ? 'Bela Crkva' : 'Vršac';

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          decoration: BoxDecoration(
            gradient: Theme.of(context).backgroundGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).glassBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).glassContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '🌤️ Vreme - $gradPun',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: data != null
                    ? Column(
                        children: [
                          // Upozorenje za kišu/sneg
                          if (data.willSnow)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('❄️', style: TextStyle(fontSize: 20)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'SNEG ${data.precipitationStartTime ?? 'SADA'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (data.willRain)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.indigo.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🌧️', style: TextStyle(fontSize: 20)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'KIŠA ${data.precipitationStartTime ?? 'SADA'}${data.precipitationProbability != null ? ' (${data.precipitationProbability}%)' : ''}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Velika ikona i temperatura
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (WeatherData.isAssetIcon(data.icon))
                                Image.asset(
                                  WeatherData.getAssetPath(data.icon),
                                  width: 80,
                                  height: 80,
                                )
                              else
                                Text(data.icon, style: const TextStyle(fontSize: 60)),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${data.temperature.round()}°C',
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold,
                                      color: data.temperature < 0
                                          ? Colors.lightBlue
                                          : data.temperature < 15
                                              ? Colors.cyan
                                              : data.temperature < 25
                                                  ? Colors.white
                                                  : Colors.orange,
                                      shadows: const [
                                        Shadow(offset: Offset(2, 2), blurRadius: 4, color: Colors.black54),
                                      ],
                                    ),
                                  ),
                                  if (data.tempMin != null && data.tempMax != null)
                                    Text(
                                      '${data.tempMin!.round()}° / ${data.tempMax!.round()}°',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.white70,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Opis baziran na weather code
                          Text(
                            _getWeatherDescription(data.dailyWeatherCode ?? data.weatherCode),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : const Center(
                        child: Text(
                          'Podaci nisu dostupni',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getWeatherDescription(int code) {
    if (code == 0) return 'Vedro nebo';
    if (code == 1) return 'Pretežno vedro';
    if (code == 2) return 'Delimično oblačno';
    if (code == 3) return 'Oblačno';
    if (code >= 45 && code <= 48) return 'Magla';
    if (code >= 51 && code <= 55) return 'Sitna kiša';
    if (code >= 56 && code <= 57) return 'Ledena kiša';
    if (code >= 61 && code <= 65) return 'Kiša';
    if (code >= 66 && code <= 67) return 'Ledena kiša';
    if (code >= 71 && code <= 77) return 'Sneg';
    if (code >= 80 && code <= 82) return 'Pljuskovi';
    if (code >= 85 && code <= 86) return 'Snežni pljuskovi';
    if (code >= 95 && code <= 99) return 'Grmljavina';
    return '';
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
                      // 🌤️ VREMENSKA PROGNOZA - BC levo, VS desno
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Center(child: _buildWeatherCompact('BC'))),
                            const SizedBox(width: 16),
                            Expanded(child: Center(child: _buildWeatherCompact('VS'))),
                          ],
                        ),
                      ),
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
                        putnikIme: fullName,
                        grad: grad,
                      ),

                      // ─────────── Divider ───────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Divider(color: Colors.white.withValues(alpha: 0.2), thickness: 1),
                      ),

                      // 🏆💀 FAME | SHAME - samo za učenike
                      if (tip == 'ucenik')
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🏆 FAME - levo
                              Expanded(child: _buildMiniLeaderboard(isShame: false)),
                              const SizedBox(width: 16),
                              // 💀 SHAME - desno
                              Expanded(child: _buildMiniLeaderboard(isShame: true)),
                            ],
                          ),
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

                      // 🏖️ Bolovanje/Godišnji dugme - SAMO za radnike
                      if (_putnikData['tip']?.toString().toLowerCase() == 'radnik') ...[
                        _buildOdsustvoButton(),
                        const SizedBox(height: 16),
                      ],

                      // 💰 TRENUTNO ZADUŽENJE
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _ukupnoZaduzenje > 0
                                ? [Colors.red.withValues(alpha: 0.2), Colors.red.withValues(alpha: 0.05)]
                                : [Colors.green.withValues(alpha: 0.2), Colors.green.withValues(alpha: 0.05)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _ukupnoZaduzenje > 0
                                ? Colors.red.withValues(alpha: 0.3)
                                : Colors.green.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'TRENUTNO STANJE',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _ukupnoZaduzenje > 0 ? '${_ukupnoZaduzenje.toStringAsFixed(0)} RSD' : 'IZMIRENO ✓',
                              style: TextStyle(
                                color: _ukupnoZaduzenje > 0 ? Colors.red.shade200 : Colors.green.shade200,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 📊 Detaljne statistike - dugme za dijalog
                      _buildDetaljneStatistikeDugme(),
                      const SizedBox(height: 16),

                      // 📅 Raspored polazaka (sa integrisanim seat request za fleksibilne)
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
                  // VS vreme - sa TimePickerCell ili SeatRequest za fleksibilne
                  Expanded(
                    child: Center(
                      child: _buildVsCell(dan, vsVreme, bcVreme),
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
      // 🚫 OGRANIČENJA ZA RADNIKE - Max 1 promena dnevno
      // ═══════════════════════════════════════════════════════════════
      if (tipPutnika == 'radnik' && putnikId != null && jeZaDanas) {
        final checkResult = await SeatRequestService.canMakeChange(putnikId);

        if (!checkResult.allowed) {
          // Blokiran - nema više promena
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(checkResult.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        } else if (checkResult.remaining == 0) {
          // Poslednja promena - traži potvrdu
          if (!mounted) return;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
                  const SizedBox(width: 12),
                  const Text('Poslednja promena!'),
                ],
              ),
              content: Text(
                checkResult.message,
                style: const TextStyle(fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Odustani'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Da, promeni', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );

          if (confirmed != true) return;
        }
      }

      // ═══════════════════════════════════════════════════════════════
      // 🎓 OGRANIČENJA ZA UČENIKE
      // ═══════════════════════════════════════════════════════════════
      if (tipPutnika == 'ucenik') {
        // 0. 🔒 Proveri da li ima PENDING zahtev za VS (čeka algoritam)
        if (tipGrad == 'vs' && putnikId != null) {
          final lockCheck = await SeatRequestService.isLockedForChanges(
            putnikId: putnikId,
            dan: dan,
          );
          if (lockCheck.locked) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(lockCheck.reason ?? '🔒 Zaključano dok se ne dodeli mesto'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            return;
          }
        }

        // 1. Proveri da li je pre 16h - za oba grada
        // BC: mora da stigne na vreme
        // VS: algoritam ih raspoređuje, ne može zadnji minut
        if (sada.hour >= 16) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⏰ Zakazivanje je dozvoljeno samo do 16:00h'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // 2. 🎓 UČENICI: Max 2 promene dnevno (ukupno BC + VS)
        // Posle 1. promene: upozorenje "Imate još 1 pravo"
        // Posle 2. promene: blokiran do sutra
        if (putnikId != null) {
          final ukupnoPromena = await SlobodnaMestaService.ukupnoPromenaDanas(putnikId);

          if (ukupnoPromena >= 2) {
            // Blokiran - potrošio obe promene
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚫 Već ste iskoristili 2 promene danas. Pokušajte sutra.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 4),
                ),
              );
            }
            return;
          } else if (ukupnoPromena == 1) {
            // Poslednja promena - traži potvrdu
            if (!mounted) return;
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
                    const SizedBox(width: 12),
                    const Text('Poslednja promena!'),
                  ],
                ),
                content: const Text(
                  'Već ste jednom menjali danas.\n\n'
                  'Imate još samo 1 pravo na promenu.\n\n'
                  'Da li ste sigurni?',
                  style: TextStyle(fontSize: 15),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Odustani'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Da, promeni', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );

            if (confirmed != true) return;
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
        // 🆕 Automatski ažuriraj radni_dani na osnovu polasci_po_danu
        final Set<String> radniDaniSet = {};
        polasci.forEach((danKey, vrednosti) {
          final bcVreme = vrednosti['bc'];
          final vsVreme = vrednosti['vs'];
          // Ako ima bilo koje vreme za taj dan, dodaj ga u radne dane
          if ((bcVreme != null && bcVreme.isNotEmpty) || (vsVreme != null && vsVreme.isNotEmpty)) {
            radniDaniSet.add(danKey);
          }
        });
        final noviRadniDani = radniDaniSet.join(',');

        // 🔍 DEBUG
        debugPrint('🔍 DEBUG _saveVreme:');
        debugPrint('   putnikId: $putnikId');
        debugPrint('   dan: $dan, tipGrad: $tipGrad, novoVreme: $novoVreme');
        debugPrint('   polasci: $polasci');
        debugPrint('   noviRadniDani: $noviRadniDani');

        await Supabase.instance.client.from('registrovani_putnici').update({
          'polasci_po_danu': polasci,
          'radni_dani': noviRadniDani,
        }).eq('id', putnikId);

        debugPrint('   ✅ Supabase update uspešan!');

        // 🎓 Zapiši promenu za učenike (za ograničenje)
        if (tipPutnika == 'ucenik') {
          await SlobodnaMestaService.zapisiPromenuVremena(putnikId.toString(), dan);
        }

        // 🚫 Zapiši promenu za radnike (max 1 dnevno)
        if (tipPutnika == 'radnik' && jeZaDanas) {
          await SeatRequestService.recordChange(putnikId);
        }

        // Ažuriraj lokalni state
        setState(() {
          _putnikData['polasci_po_danu'] = polasci;
          _putnikData['radni_dani'] = noviRadniDani;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Vreme sačuvano (radni_dani: $noviRadniDani)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ DEBUG _saveVreme GREŠKA: $e');
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

  /// 📊 Dugme za otvaranje detaljnih statistika
  Widget _buildDetaljneStatistikeDugme() {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).glassBorder, width: 1.5),
      ),
      child: InkWell(
        onTap: () {
          PutnikStatistikeHelper.prikaziDetaljneStatistike(
            context: context,
            putnikId: _putnikData['id'] ?? '',
            putnikIme: _putnikData['putnik_ime'] ?? 'Nepoznato',
            tip: _putnikData['tip'] ?? 'radnik',
            tipSkole: _putnikData['tip_skole'],
            brojTelefona: _putnikData['broj_telefona'],
            radniDani: _putnikData['radni_dani'] ?? 'pon,uto,sre,cet,pet',
            createdAt:
                _putnikData['created_at'] != null ? DateTime.tryParse(_putnikData['created_at'].toString()) : null,
            updatedAt:
                _putnikData['updated_at'] != null ? DateTime.tryParse(_putnikData['updated_at'].toString()) : null,
            aktivan: _putnikData['aktivan'] ?? true,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics_outlined,
                color: Colors.blue.shade300,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Detaljne statistike',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withValues(alpha: 0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 📊 Widget za prikaz stanja računa (STARI - nekoristi se više)
  // ignore: unused_element
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
    final cenaPoVoznji = CenaObracunService.getDefaultCenaByTip(tip);

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

            const SizedBox(height: 12),

            // 📊 DUGME ZA DETALJNE STATISTIKE
            Center(
              child: TextButton.icon(
                onPressed: () {
                  PutnikStatistikeHelper.prikaziDetaljneStatistike(
                    context: context,
                    putnikId: _putnikData['id'] ?? '',
                    putnikIme: _putnikData['putnik_ime'] ?? 'Nepoznato',
                    tip: _putnikData['tip'] ?? 'radnik',
                    tipSkole: _putnikData['tip_skole'],
                    brojTelefona: _putnikData['broj_telefona'],
                    radniDani: _putnikData['radni_dani'] ?? 'pon,uto,sre,cet,pet',
                    createdAt: _putnikData['created_at'] != null
                        ? DateTime.tryParse(_putnikData['created_at'].toString())
                        : null,
                    updatedAt: _putnikData['updated_at'] != null
                        ? DateTime.tryParse(_putnikData['updated_at'].toString())
                        : null,
                    aktivan: _putnikData['aktivan'] ?? true,
                  );
                },
                icon: const Icon(Icons.analytics_outlined, size: 18),
                label: const Text('Detaljne statistike'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.9),
                  backgroundColor: Colors.blue.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.blue.withValues(alpha: 0.4)),
                  ),
                ),
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

  // ============================================================
  // 🎫 VS ĆELIJA SA SEAT REQUEST LOGIKOM
  // ============================================================

  /// Gradi VS ćeliju - ako je fleksibilan putnik, koristi seat request logiku
  Widget _buildVsCell(String dan, String? vsVreme, String? bcVreme) {
    final putnikId = _putnikData['id'] as String?;

    // Ako ima fiksno VS vreme ILI nema BC vreme (ne ide taj dan) → normalan picker
    if (vsVreme != null && vsVreme.isNotEmpty) {
      return TimePickerCell(
        value: vsVreme,
        isBC: false,
        onChanged: (newValue) => _updatePolazak(dan, 'vs', newValue),
      );
    }

    // Ako nema BC vreme, znači ne ide taj dan - prikaži prazan picker
    if (bcVreme == null || bcVreme.isEmpty) {
      return TimePickerCell(
        value: null,
        isBC: false,
        onChanged: (newValue) => _updatePolazak(dan, 'vs', newValue),
      );
    }

    // FLEKSIBILAN PUTNIK - ima BC ali nema VS
    // Proveri da li već ima zahtev za taj dan
    return FutureBuilder<SeatRequest?>(
      future: putnikId != null
          ? SeatRequestService.getExistingRequest(
              putnikId: putnikId,
              grad: 'VS',
              datum: _getDatumZaDan(dan),
            )
          : Future.value(null),
      builder: (context, snapshot) {
        final request = snapshot.data;

        if (request != null) {
          // Ima zahtev - prikaži status
          return _buildRequestStatusCell(request);
        }

        // Nema zahtev - prikaži picker koji šalje zahtev
        return GestureDetector(
          onTap: () => _showSeatRequestPicker(dan),
          child: Container(
            width: 70,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300, width: 2),
            ),
            child: Center(
              child: Icon(
                Icons.add_circle_outline,
                color: Colors.orange.shade400,
                size: 20,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Prikazuje status zahteva u ćeliji
  Widget _buildRequestStatusCell(SeatRequest request) {
    Color bgColor;
    Color borderColor;
    Widget child;

    switch (request.status) {
      case SeatRequestStatus.approved:
        bgColor = Colors.green.shade50;
        borderColor = Colors.green;
        child = Text(
          request.dodeljenoVreme ?? request.zeljenoVreme,
          style: TextStyle(
            color: Colors.green.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        );
        break;
      case SeatRequestStatus.pending:
        bgColor = Colors.orange.shade50;
        borderColor = Colors.orange;
        child = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange.shade700, size: 12),
            const SizedBox(width: 2),
            Text(
              request.zeljenoVreme,
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        );
        break;
      case SeatRequestStatus.waitlist:
        bgColor = Colors.yellow.shade50;
        borderColor = Colors.yellow.shade700;
        child = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue, color: Colors.yellow.shade800, size: 12),
            const SizedBox(width: 2),
            Text(
              request.zeljenoVreme,
              style: TextStyle(
                color: Colors.yellow.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        );
        break;
      default:
        bgColor = Colors.grey.shade100;
        borderColor = Colors.grey;
        child = Icon(Icons.access_time, color: Colors.grey.shade400, size: 18);
    }

    return Container(
      width: 70,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Center(child: child),
    );
  }

  /// Prikazuje picker za seat request (izgleda isto kao TimePickerCell dialog)
  Future<void> _showSeatRequestPicker(String dan) async {
    final putnikId = _putnikData['id'] as String?;
    final putnikIme =
        _putnikData['putnik_ime'] as String? ?? '${_putnikData['ime'] ?? ''} ${_putnikData['prezime'] ?? ''}'.trim();

    if (putnikId == null) return;

    final datum = _getDatumZaDan(dan);
    final jeZimski = isZimski(datum);
    final vremena = jeZimski ? RouteConfig.vsVremenaZimski : RouteConfig.vsVremenaLetnji;

    final selectedVreme = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            gradient: ThemeManager().currentGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'VS polazak',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white70, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Izaberite željeno vreme povratka',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Time options
              SizedBox(
                height: 350,
                child: ListView(
                  children: vremena.map((vreme) {
                    return ListTile(
                      title: Text(
                        vreme,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      leading: const Icon(Icons.circle_outlined, color: Colors.white54),
                      onTap: () => Navigator.of(dialogContext).pop(vreme),
                    );
                  }).toList(),
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Otkaži', style: TextStyle(color: Colors.white70)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedVreme == null) return;

    // Pošalji zahtev
    final request = await SeatRequestService.createRequest(
      putnikId: putnikId,
      putnikIme: putnikIme.isNotEmpty ? putnikIme : null,
      grad: 'VS',
      datum: datum,
      zeljenoVreme: selectedVreme,
    );

    if (request != null && mounted) {
      // Prikaži lepu poruku sa info o čekanju
      _showRequestConfirmationDialog(selectedVreme, datum);
      setState(() {}); // Refresh da prikaže status
    }
  }

  /// Prikazuje confirmation dialog sa info o čekanju
  void _showRequestConfirmationDialog(String vreme, DateTime datum) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: ThemeManager().currentGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ikonica
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),

              // Naslov
              const Text(
                'Zahtev primljen! 📬',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Info o vremenu
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🕐 Željeno vreme: $vreme',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Poruka o čekanju
              const Text(
                'Obrađujemo tvoj zahtev...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_active, color: Colors.amber.withValues(alpha: 0.8), size: 18),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Dobićeš potvrdu za najviše 10 min',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Dugme
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Važi! 👍'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vraća datum za dati dan u tekućoj/sledećoj nedelji (uvek unapred)
  DateTime _getDatumZaDan(String dan) {
    final now = DateTime.now();
    const daniLista = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    final currentDayIndex = now.weekday - 1; // 0 = pon
    final targetDayIndex = daniLista.indexOf(dan.toLowerCase());

    if (targetDayIndex == -1) return now;

    int diff = targetDayIndex - currentDayIndex;

    // Ako je dan prošao ove nedelje, uzmi sledeću nedelju
    if (diff < 0) {
      diff += 7;
    }
    // Ako je danas taj dan, ostavi danas (može da zakaže za danas)

    return DateTime(now.year, now.month, now.day).add(Duration(days: diff));
  }
}
