import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // DODANO za kDebugMode
import 'package:supabase_flutter/supabase_flutter.dart'; // DODANO za direktne pozive
import 'package:url_launcher/url_launcher.dart'; // 🗺️ DODANO za Google Maps
import '../models/putnik.dart';
import '../models/realtime_route_data.dart'; // 🛰️ DODANO za realtime tracking
import '../services/advanced_route_optimization_service.dart';
import '../services/daily_checkin_service.dart'; // 🌅 DODANO za sitan novac
import '../services/firebase_service.dart';
import '../services/mesecni_putnik_service.dart'; // 🎓 DODANO za đačke statistike
import '../services/realtime_notification_counter_service.dart'; // 🔔 DODANO za notification count
import '../services/realtime_gps_service.dart'; // 🛰️ DODANO za GPS tracking
import '../services/realtime_notification_service.dart';
import '../services/route_optimization_service.dart';
import '../services/statistika_service.dart'; // DODANO za jedinstvenu logiku pazara
import '../services/realtime_route_tracking_service.dart'; // 🚗 NOVO
import '../services/putnik_service.dart'; // 🆕 DODANO za nove metode
import '../utils/vozac_boja.dart'; // 🎯 DODANO za konzistentne boje vozača
import '../widgets/putnik_list.dart';
import '../widgets/real_time_navigation_widget.dart'; // 🧭 NOVO navigation widget

import '../widgets/bottom_nav_bar_letnji.dart'; // 🚀 DODANO za letnji nav bar
import 'dugovi_screen.dart';
import '../services/local_notification_service.dart';
import '../utils/grad_adresa_validator.dart'; // 🏘️ NOVO za validaciju gradova

class DanasScreen extends StatefulWidget {
  final String? highlightPutnikIme;
  final String? filterGrad;
  final String? filterVreme;

  const DanasScreen({
    Key? key,
    this.highlightPutnikIme,
    this.filterGrad,
    this.filterVreme,
  }) : super(key: key);

  @override
  State<DanasScreen> createState() => _DanasScreenState();
}

class _DanasScreenState extends State<DanasScreen> {
  final supabase = Supabase.instance.client; // DODANO za direktne pozive
  final _putnikService = PutnikService(); // 🆕 DODANO PutnikService instanca

  // 🎓 FUNKCIJA ZA RAČUNANJE ĐAČKIH STATISTIKA
  Future<Map<String, int>> _calculateDjackieBrojeviAsync() async {
    try {
      final danasnjiDan = _getTodayForDatabase();

      // Direktno dohvati mesečne putnike iz baze da imamo pristup tip informaciji
      final sviMesecniPutnici =
          await MesecniPutnikService.getAktivniMesecniPutnici();

      // Filtriraj samo učenike za današnji dan
      final djaci = sviMesecniPutnici.where((mp) {
        final dayMatch =
            mp.radniDani.toLowerCase().contains(danasnjiDan.toLowerCase());
        final jeUcenik = mp.tip == 'ucenik';
        final aktivanStatus = mp.status == 'radi'; // samo oni koji rade
        return dayMatch && jeUcenik && aktivanStatus;
      }).toList();

      // FINALNA LOGIKA: OSTALO/UKUPNO
      int ukupnoUjutro = 0; // ukupno učenika koji idu ujutro (Bela Crkva)
      int reseniUcenici =
          0; // učenici upisani za OBA pravca (automatski rešeni)
      int otkazaliUcenici = 0; // učenici koji su otkazali

      for (final djak in djaci) {
        final status = djak.status.toLowerCase().trim();

        // Da li je otkazao?
        final jeOtkazao = (status == 'otkazano' ||
            status == 'otkazan' ||
            status == 'bolovanje' ||
            status == 'godisnji' ||
            status == 'godišnji' ||
            status == 'obrisan');

        // Da li ide ujutro (Bela Crkva)?
        final ideBelaCrkva =
            djak.polazakBelaCrkva != null && djak.polazakBelaCrkva!.isNotEmpty;

        // Da li se vraća (Vršac)?
        final vraca =
            djak.polazakVrsac != null && djak.polazakVrsac!.isNotEmpty;

        if (ideBelaCrkva) {
          ukupnoUjutro++; // broji sve koji idu ujutro

          if (jeOtkazao) {
            otkazaliUcenici++; // otkazao nakon upisa
          } else if (vraca) {
            reseniUcenici++; // upisan za oba pravca = rešen
          }
        }
      }

      // RAČUNAJ OSTALO
      final ostalo = ukupnoUjutro - reseniUcenici - otkazaliUcenici;

      return {
        'ukupno_ujutro': ukupnoUjutro, // 30 - ukupno koji idu ujutro
        'reseni': reseniUcenici, // 15 - upisani za oba pravca
        'otkazali': otkazaliUcenici, // 5 - otkazani
        'ostalo': ostalo, // 10 - ostalo da se vrati
      };
    } catch (e) {
      debugPrint('❌ Greška pri računanju đačkih statistika: $e');
      return {
        'ukupno': 0,
        'povratak': 0,
        'slobodno': 0,
      };
    }
  }

  // ✨ DIGITALNI BROJAČ DATUM WIDGET - ISTI STIL KAO REZERVACIJE
  Widget _buildDigitalDateDisplay() {
    return StreamBuilder<DateTime>(
      stream:
          Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final dayNames = [
          'PONEDELJAK',
          'UTORAK',
          'SREDA',
          'ČETVRTAK',
          'PETAK',
          'SUBOTA',
          'NEDELJA'
        ];
        final dayName = dayNames[now.weekday - 1];
        final dayStr = now.day.toString().padLeft(2, '0');
        final monthStr = now.month.toString().padLeft(2, '0');
        final yearStr = now.year.toString();

        // VREME - sati, minuti, sekunde
        final hourStr = now.hour.toString().padLeft(2, '0');
        final minuteStr = now.minute.toString().padLeft(2, '0');
        final secondStr = now.second.toString().padLeft(2, '0');

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ROW SA TRI DELA: DATUM - DAN - VREME
            Container(
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // LEVO - DATUM
                  Text(
                    '$dayStr.$monthStr.${yearStr.substring(2)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.8,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  // SREDINA - DAN
                  Text(
                    dayName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.8,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  // DESNO - VREME
                  Text(
                    '$hourStr:$minuteStr:$secondStr',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.8,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // 🎓 FINALNO DUGME - OSTALO/UKUPNO FORMAT
  Widget _buildDjackiBrojacButton() {
    return FutureBuilder<Map<String, int>>(
      future: _calculateDjackieBrojeviAsync(),
      builder: (context, snapshot) {
        final statistike = snapshot.data ??
            {'ukupno_ujutro': 0, 'reseni': 0, 'otkazali': 0, 'ostalo': 0};
        final ostalo = statistike['ostalo'] ?? 0; // 10 - ostalo da se vrati
        final ukupnoUjutro =
            statistike['ukupno_ujutro'] ?? 0; // 30 - ukupno ujutro

        return SizedBox(
          height: 26, // povećao sa 24 na 26
          child: ElevatedButton(
            onPressed: () => _showDjackiDialog(statistike),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2), // povećao sa 4 na 8
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school, size: 12), // povećao sa 9 na 12
                const SizedBox(width: 2), // povećao sa 1 na 2
                // UKUPNO UJUTRO (belo) - PRVI
                Text(
                  '$ukupnoUjutro',
                  style: const TextStyle(
                    fontSize: 14, // povećao sa 13 na 14
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  '/',
                  style: TextStyle(
                    fontSize: 14, // povećao sa 13 na 14
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                // OSTALO (crveno) - DRUGI
                Text(
                  '$ostalo',
                  style: const TextStyle(
                    fontSize: 14, // povećao sa 13 na 14
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🚀 KOMPAKTNO DUGME ZA OPTIMIZACIJU
  Widget _buildOptimizeButton() {
    return StreamBuilder<List<Putnik>>(
      stream: _putnikService.streamKombinovaniPutnici(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container();

        final sviPutnici = snapshot.data!;
        final danasnjiDan = _getTodayForDatabase();
        final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

        final danasPutnici = sviPutnici.where((p) {
          final dayMatch =
              p.dan.toLowerCase().contains(danasnjiDan.toLowerCase());
          bool timeMatch = true;
          if (p.mesecnaKarta != true && p.vremeDodavanja != null) {
            timeMatch = p.vremeDodavanja!.isAfter(oneWeekAgo);
          }
          return dayMatch && timeMatch;
        }).toList();

        final filtriraniPutnici = danasPutnici.where((putnik) {
          final normalizedStatus = (putnik.status ?? '').toLowerCase().trim();
          final vremeMatch =
              GradAdresaValidator.normalizeTime(putnik.polazak) ==
                  GradAdresaValidator.normalizeTime(_selectedVreme);
          final gradMatch = _isGradMatch(
              putnik.grad, putnik.adresa, _selectedGrad,
              isMesecniPutnik: putnik.mesecnaKarta == true);
          final statusOk = (normalizedStatus != 'otkazano' &&
              normalizedStatus != 'otkazan' &&
              normalizedStatus != 'bolovanje' &&
              normalizedStatus != 'godisnji' &&
              normalizedStatus != 'godišnji' &&
              normalizedStatus != 'obrisan');
          return vremeMatch && gradMatch && statusOk;
        }).toList();

        final hasPassengers = filtriraniPutnici.isNotEmpty;

        return SizedBox(
          height: 26, // povećao sa 24 na 26
          child: ElevatedButton.icon(
            onPressed: _isLoading || !hasPassengers
                ? null
                : () {
                    if (_isRouteOptimized) {
                      _resetOptimization();
                    } else {
                      _optimizeCurrentRoute(filtriraniPutnici);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRouteOptimized
                  ? Colors.green.shade600
                  : (hasPassengers
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade400),
              foregroundColor: Colors.white,
              elevation: hasPassengers ? 2 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2), // povećao sa 4 na 8
            ),
            icon: Icon(
              _isRouteOptimized ? Icons.close : Icons.route,
              size: 12, // povećao sa 10 na 12
            ),
            label: Text(
              _isRouteOptimized ? 'Reset' : 'Ruta',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13, // povećao sa 12 na 13
              ),
            ),
          ),
        );
      },
    );
  }

  // ⚡ SPEEDOMETER DUGME U APPBAR-U
  Widget _buildSpeedometerButton() {
    return StreamBuilder<double>(
      stream: RealtimeGpsService.speedStream,
      builder: (context, speedSnapshot) {
        final speed = speedSnapshot.data ?? 0.0;
        final speedColor = speed >= 90
            ? Colors.red
            : speed >= 60
                ? Colors.orange
                : speed > 0
                    ? Colors.green
                    : Colors.white70;

        return SizedBox(
          height: 26,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: speedColor.withOpacity(0.4), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  speed.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 14, // povećao sa 13 na 14
                    fontWeight: FontWeight.bold,
                    color: speedColor,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🗺️ DUGME ZA GOOGLE MAPS NAVIGACIJU
  Widget _buildMapsButton() {
    final hasOptimizedRoute = _isRouteOptimized && _optimizedRoute.isNotEmpty;

    return SizedBox(
      height: 26, // povećao sa 24 na 26 za konzistentnost
      child: ElevatedButton.icon(
        onPressed: hasOptimizedRoute ? () => _openGoogleMapsNavigation() : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              hasOptimizedRoute ? Colors.blue.shade600 : Colors.grey.shade400,
          foregroundColor: Colors.white,
          elevation: hasOptimizedRoute ? 2 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        ),
        icon: const Icon(
          Icons.navigation,
          size: 12,
        ),
        label: const Text(
          'Mapa',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13, // povećao sa 12 na 13
          ),
        ),
      ),
    );
  }

  // 📊 DUGME ZA POPIS DANA
  Widget _buildPopisButton() {
    return SizedBox(
      height: 26, // povećao sa 24 na 26 za konzistentnost
      child: ElevatedButton.icon(
        onPressed: () => _showPopisDana(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange.shade600,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 2), // smanjio sa 10 na 8
        ),
        icon: const Icon(
          Icons.assessment,
          size: 12,
        ),
        label: const Text(
          'POPIS',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11, // povećao sa 10 na 11
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // 🎓 POPUP SA DETALJNIM ĐAČKIM STATISTIKAMA - OPTIMIZOVAN
  void _showDjackiDialog(Map<String, int> statistike) {
    final zakazane = statistike['povratak'] ?? 0;
    final ostale = statistike['slobodno'] ?? 0;
    final ukupno = statistike['ukupno'] ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.school, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Đaci - Danas ($zakazane/$ostale)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow(
                'Ukupno upisano', '$ukupno', Icons.group, Colors.blue),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Zakazane ($zakazane)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Učenici koji imaju i jutarnji i popodnevni polazak',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.orangeAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ostale ($ostale)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Učenici koji imaju samo jutarnji polazak',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
      String label, dynamic value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
                color: Colors.grey[700], fontSize: 14), // 🎨 Tamniji tekst
          ),
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 📊 POPIS DANA - REALTIME PODACI SA ISTIM NAZIVIMA KAO U STATISTIKA SCREEN
  Future<void> _showPopisDana() async {
    print('🔥 [POPIS] 1. Početak _showPopisDana funkcije');
    final vozac = _currentDriver ?? 'Nepoznat';
    print('🔥 [POPIS] 2. Vozač: $vozac');

    try {
      // 1. OSNOVNI PODACI
      final today = DateTime.now();
      final dayStart = DateTime(today.year, today.month, today.day);
      final dayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
      print('🔥 [POPIS] 3. Datum postavljen: ${dayStart.toString()}');

      // 2. REALTIME STREAM ZA KOMBINOVANE PUTNIKE
      print('🔥 [POPIS] 4. Učitavam putnike...');
      late List<Putnik> putnici;
      try {
        final stream = PutnikService().streamKombinovaniPutnici();
        putnici = await stream.first.timeout(Duration(seconds: 10));
        print('🔥 [POPIS] 5. Putnici učitani: ${putnici.length}');
      } catch (e) {
        print('🔥 [POPIS] 5.ERROR: Greška pri učitavanju putnika: $e');
        putnici = []; // Prazan list kao fallback
        print('🔥 [POPIS] 5.FALLBACK: Koristim prazan list putnika');
      }

      // 3. REALTIME DETALJNE STATISTIKE - IDENTIČNE SA STATISTIKA SCREEN
      print('🔥 [POPIS] 6. Računam detaljne statistike...');
      final detaljneStats =
          await StatistikaService.detaljneStatistikePoVozacima(
              putnici, dayStart, dayEnd);
      final vozacStats = detaljneStats[vozac] ?? {};
      print('🔥 [POPIS] 7. Statistike računate: $vozacStats');

      // 4. REALTIME PAZAR STREAM
      print('🔥 [POPIS] 8. Računam pazar stream...');
      late double ukupanPazar;
      try {
        ukupanPazar = await StatistikaService.streamPazarSvihVozaca(
                from: dayStart, to: dayEnd)
            .map((pazarMap) => pazarMap[vozac] ?? 0.0)
            .first
            .timeout(Duration(seconds: 10));
        print('🔥 [POPIS] 9. Ukupan pazar: $ukupanPazar');
      } catch (e) {
        print('🔥 [POPIS] 9.ERROR: Greška pri učitavanju pazara: $e');
        ukupanPazar = 0.0; // Fallback vrednost
        print('🔥 [POPIS] 9.FALLBACK: Koristim pazar = 0.0');
      }

      // 5. SITAN NOVAC
      print('🔥 [POPIS] 10. Učitavam sitan novac...');
      final sitanNovac = await DailyCheckInService.getTodayAmount(vozac);
      print('🔥 [POPIS] 11. Sitan novac: $sitanNovac');

      // 6. MAPIRANJE PODATAKA - IDENTIČNO SA STATISTIKA SCREEN
      print('🔥 [POPIS] 12. Mapiram podatke...');
      final dodatiPutnici = (vozacStats['dodati'] ?? 0) as int;
      final otkazaniPutnici = (vozacStats['otkazani'] ?? 0) as int;
      final naplaceniPutnici = (vozacStats['naplaceni'] ?? 0) as int;
      final pokupljeniPutnici = (vozacStats['pokupljeni'] ?? 0) as int;
      final dugoviPutnici = (vozacStats['dugovi'] ?? 0) as int;
      final mesecneKarte = (vozacStats['mesecneKarte'] ?? 0) as int;
      print(
          '🔥 [POPIS] 13. Podaci mapirani - dodati: $dodatiPutnici, pazar: $ukupanPazar');

      // 🚗 REALTIME GPS KILOMETRAŽA (umesto statične vrednosti)
      print('🔥 [POPIS] 14. Računam GPS kilometražu...');
      late double kilometraza;
      try {
        kilometraza =
            await StatistikaService.getKilometrazu(vozac, dayStart, dayEnd);
        print(
            '🚗 GPS kilometraža za $vozac danas: ${kilometraza.toStringAsFixed(1)} km');
      } catch (e) {
        print('⚠️ Greška pri GPS računanju kilometraže: $e');
        kilometraza = 0.0; // Fallback vrednost
      }
      print('🔥 [POPIS] 15. Kilometraža: ${kilometraza.toStringAsFixed(1)} km');

      // 7. PRIKAŽI POPIS DIALOG SA REALTIME PODACIMA
      print('🔥 [POPIS] 16. Pozivam _showPopisDialog...');
      final bool sacuvaj = await _showPopisDialog(
        vozac: vozac,
        datum: today,
        ukupanPazar: ukupanPazar,
        sitanNovac: sitanNovac ?? 0.0,
        dodatiPutnici: dodatiPutnici,
        otkazaniPutnici: otkazaniPutnici,
        naplaceniPutnici: naplaceniPutnici,
        pokupljeniPutnici: pokupljeniPutnici,
        dugoviPutnici: dugoviPutnici,
        mesecneKarte: mesecneKarte,
        kilometraza: kilometraza,
      );
      print('🔥 [POPIS] 17. Dialog zatovoren, sačuvaj: $sacuvaj');

      // 8. SAČUVAJ POPIS AKO JE POTVRĐEN
      if (sacuvaj) {
        print('🔥 [POPIS] 18. Čuvam popis...');
        await _sacuvajPopis(vozac, today, {
          'ukupanPazar': ukupanPazar,
          'sitanNovac': sitanNovac,
          'dodatiPutnici': dodatiPutnici,
          'otkazaniPutnici': otkazaniPutnici,
          'naplaceniPutnici': naplaceniPutnici,
          'pokupljeniPutnici': pokupljeniPutnici,
          'dugoviPutnici': dugoviPutnici,
          'mesecneKarte': mesecneKarte,
          'kilometraza': kilometraza,
        });
        print('🔥 [POPIS] 19. Popis je sačuvan!');
      }
      print('🔥 [POPIS] 20. _showPopisDana završen USPEŠNO!');
    } catch (e) {
      print('🔥 [POPIS] ❌ GREŠKA u _showPopisDana: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Greška pri učitavanju popisa: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isLoading = false;

  Future<void> _loadPutnici() async {
    setState(() => _isLoading = true);
    // Osloni se na stream, ali možeš ovde dodati logiku za ručno osvežavanje ako bude potrebno
    await Future.delayed(const Duration(milliseconds: 100)); // simulacija
    setState(() => _isLoading = false);
  }

  // _filteredDuznici već postoji, ne treba duplirati
  // VRATITI NA PUTNIK SERVICE - BEZ CACHE-A

  // Optimizacija rute - zadržavam zbog postojeće logike
  bool _isRouteOptimized = false;
  List<Putnik> _optimizedRoute = [];

  // Status varijable - pojednostavljeno
  String _navigationStatus = '';

  // Praćenje navigacije
  bool _isGpsTracking = false;
  DateTime? _lastGpsUpdate;

  // Lista varijable - zadržavam zbog UI
  int _currentPassengerIndex = 0;
  bool _isListReordered = false;

  // 🔄 RESET OPTIMIZACIJE RUTE
  void _resetOptimization() {
    setState(() {
      _isRouteOptimized = false;
      _isListReordered = false;
      _optimizedRoute.clear();
      _currentPassengerIndex = 0;
      _isGpsTracking = false;
      _lastGpsUpdate = null;
      _navigationStatus = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Optimizacija rute je isključena'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 📊 DIALOG ZA PRIKAZ POPISA DANA - IDENTIČAN FORMAT SA STATISTIKA SCREEN
  Future<bool> _showPopisDialog({
    required String vozac,
    required DateTime datum,
    required double ukupanPazar,
    required double sitanNovac,
    required int dodatiPutnici,
    required int otkazaniPutnici,
    required int naplaceniPutnici,
    required int pokupljeniPutnici,
    required int dugoviPutnici,
    required int mesecneKarte,
    required double kilometraza,
  }) async {
    final vozacColor = VozacBoja.get(vozac);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person, color: vozacColor, size: 24),
            const SizedBox(width: 8),
            Text(
              '📊 POPIS DANA - ${datum.day}.${datum.month}.${datum.year}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.all(0),
              elevation: 4,
              color: vozacColor.withOpacity(0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: vozacColor.withOpacity(0.6),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER SA VOZAČEM
                    Row(
                      children: [
                        Icon(Icons.person, color: vozacColor, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          vozac,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // DETALJNE STATISTIKE - IDENTIČNE SA STATISTIKA SCREEN
                    _buildStatRow('Dodati putnici', dodatiPutnici,
                        Icons.add_circle, Colors.blue),
                    _buildStatRow(
                        'Otkazani', otkazaniPutnici, Icons.cancel, Colors.red),
                    _buildStatRow('Naplaćeni', naplaceniPutnici, Icons.payment,
                        Colors.green),
                    _buildStatRow('Pokupljeni', pokupljeniPutnici,
                        Icons.check_circle, Colors.orange),
                    _buildStatRow('Dugovi', dugoviPutnici, Icons.warning,
                        Colors.redAccent),
                    _buildStatRow('Mesečne karte', mesecneKarte,
                        Icons.card_membership, Colors.purple),
                    _buildStatRow(
                        'Kilometraža',
                        '${kilometraza.toStringAsFixed(1)} km',
                        Icons.route,
                        Colors.teal),

                    const Divider(color: Colors.white24),

                    // UKUPAN PAZAR - GLAVNI PODATAK
                    _buildStatRow(
                        'Ukupno pazar',
                        '${ukupanPazar.toStringAsFixed(0)} RSD',
                        Icons.monetization_on,
                        Colors.amber),

                    const SizedBox(height: 12),

                    // DODATNE INFORMACIJE
                    if (sitanNovac > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet,
                                color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Sitan novac: ${sitanNovac.toStringAsFixed(0)} RSD',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Text(
                        '📋 Ovaj popis će biti sačuvan i prikazan pri sledećem check-in-u.',
                        style: TextStyle(
                            fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otkaži'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.save),
            label: const Text('Sačuvaj popis'),
            style: ElevatedButton.styleFrom(
              backgroundColor: vozacColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  //  SAČUVAJ POPIS U DAILY CHECK-IN SERVICE
  Future<void> _sacuvajPopis(
      String vozac, DateTime datum, Map<String, dynamic> podaci) async {
    try {
      // Sačuvaj kompletan popis
      await DailyCheckInService.saveDailyReport(vozac, datum, podaci);

      // Takođe sačuvaj i sitan novac (za kompatibilnost)
      await DailyCheckInService.saveCheckIn(
          vozac, podaci['sitanNovac'] as double);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Popis je uspešno sačuvan!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Greška pri čuvanju popisa: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  final bool _useAdvancedNavigation = true;

  String _selectedGrad = 'Bela Crkva';
  String _selectedVreme = '5:00';
  String? _currentDriver; // Dodato za dohvat vozača

  // Lista polazaka za chipove - LETNJI RASPORED
  final List<String> _sviPolasci = [
    '5:00 Bela Crkva',
    '6:00 Bela Crkva',
    '8:00 Bela Crkva',
    '10:00 Bela Crkva',
    '12:00 Bela Crkva',
    '13:00 Bela Crkva',
    '14:00 Bela Crkva',
    '15:30 Bela Crkva',
    '18:00 Bela Crkva',
    '6:00 Vršac',
    '7:00 Vršac',
    '9:00 Vršac',
    '11:00 Vršac',
    '13:00 Vršac',
    '14:00 Vršac',
    '15:30 Vršac',
    '16:15 Vršac',
    '19:00 Vršac'
  ];

  // Dobij današnji dan u formatu koji se koristi u bazi
  String _getTodayForDatabase() {
    final now = DateTime.now();
    final dayNames = [
      'pon',
      'uto',
      'sre',
      'cet',
      'pet',
      'sub',
      'ned'
    ]; // Koristi iste kratice kao Home screen
    final todayName = dayNames[now.weekday - 1];

    // ✅ UKLONJENA LOGIKA AUTOMATSKOG PREBACIVANJA NA PONEDELJAK
    // Sada vraća pravi trenutni dan u nedelji
    debugPrint('🗓️ [DANAS SCREEN] Današnji dan: $todayName');
    return todayName;
  }

  // ✅ SINHRONIZACIJA SA HOME SCREEN - postavi trenutno vreme i grad
  void _initializeCurrentTime() {
    final now = DateTime.now();
    final currentHour = now.hour;

    // Logika kao u home_screen - odaberi najbliže vreme
    String closestTime = '5:00';
    int minDiff = 24;

    final availableTimes = [
      '5:00',
      '6:00',
      '7:00',
      '8:00',
      '9:00',
      '10:00',
      '11:00',
      '12:00',
      '13:00',
      '14:00',
      '15:30',
      '16:15',
      '18:00',
      '19:00'
    ];

    for (String time in availableTimes) {
      final timeHour = int.tryParse(time.split(':')[0]) ?? 5;
      final diff = (timeHour - currentHour).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestTime = time;
      }
    }

    setState(() {
      _selectedVreme = closestTime;
      // Određi grad na osnovu vremena - kao u home_screen
      if ([
        '5:00',
        '6:00',
        '8:00',
        '10:00',
        '12:00',
        '13:00',
        '14:00',
        '15:30',
        '18:00'
      ].contains(closestTime)) {
        _selectedGrad = 'Bela Crkva';
      } else {
        _selectedGrad = 'Vršac';
      }
    });

    debugPrint(
        '🕐 [DANAS SCREEN] Inicijalizovano vreme: $_selectedVreme, grad: $_selectedGrad');
  }

  @override
  void initState() {
    super.initState();

    // ✅ SETUP FILTERS FROM NOTIFICATION DATA
    if (widget.filterGrad != null) {
      _selectedGrad = widget.filterGrad!;
      debugPrint('🔔 [NOTIFICATION] Setting filter grad: ${widget.filterGrad}');
    }
    if (widget.filterVreme != null) {
      _selectedVreme = widget.filterVreme!;
      debugPrint(
          '🔔 [NOTIFICATION] Setting filter vreme: ${widget.filterVreme}');
    }

    // Ako nema filter podataka iz notifikacije, koristi default logiku
    if (widget.filterGrad == null || widget.filterVreme == null) {
      _initializeCurrentTime(); // ✅ SINHRONIZACIJA - postavi trenutno vreme i grad kao home_screen
    }

    _initializeCurrentDriver();
    _loadPutnici();
    // Inicijalizuj heads-up i zvuk notifikacije
    LocalNotificationService.initialize(context);
    RealtimeNotificationService.listenForForegroundNotifications(context);
    FirebaseService.getCurrentDriver().then((driver) {
      if (driver != null && driver.isNotEmpty) {
        RealtimeNotificationService.initialize();
      }
    });
    // Dodato: NIŠTA - koristimo direktne supabase pozive bez cache
    // 🛰️ REALTIME ROUTE TRACKING LISTENER
    _initializeRealtimeTracking();

    //  REAL-TIME NOTIFICATION COUNTER
    RealtimeNotificationCounterService.initialize();

    // 🛰️ START GPS TRACKING
    RealtimeGpsService.startTracking().catchError((e) {
      debugPrint('🚨 GPS tracking failed: $e');
    });

    // 🔔 SHOW NOTIFICATION MESSAGE IF PASSENGER NAME PROVIDED
    if (widget.highlightPutnikIme != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNotificationMessage();
      });
    }
  }

  void _initializeRealtimeTracking() {
    // Slušaj realtime route data updates
    RealtimeRouteTrackingService.routeDataStream.listen((routeData) {
      if (mounted) {
        // Ažuriraj poslednji GPS update time
        setState(() {
          _lastGpsUpdate = routeData.timestamp;
        });
      }
    });

    // Slušaj traffic alerts
    RealtimeRouteTrackingService.trafficAlertsStream.listen((alerts) {
      if (mounted && alerts.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🚨 SAOBRAĆAJNI ALERT!',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...alerts.map((alert) => Text('• $alert')),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    });
  }

  // 🔔 SHOW NOTIFICATION MESSAGE WHEN OPENED FROM NOTIFICATION
  void _showNotificationMessage() {
    if (widget.highlightPutnikIme == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notification_important, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🔔 Otvoreno iz notifikacije',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Putnik: ${widget.highlightPutnikIme} | ${widget.filterGrad} ${widget.filterVreme}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  /// 🔍 GRAD POREĐENJE - razlikuj mesečne i obične putnike
  bool _isGradMatch(
      String? putnikGrad, String? putnikAdresa, String selectedGrad,
      {bool isMesecniPutnik = false}) {
    // Za mesečne putnike - direktno poređenje grada
    if (isMesecniPutnik) {
      return putnikGrad == selectedGrad;
    }
    // Za obične putnike - koristi adresnu validaciju
    return GradAdresaValidator.isGradMatch(
        putnikGrad, putnikAdresa, selectedGrad);
  }

  Future<void> _initializeCurrentDriver() async {
    _currentDriver = await FirebaseService.getCurrentDriver();
    // Inicijalizacija vozača završena
  }

  @override
  void dispose() {
    // 🛑 Zaustavi realtime tracking kad se ekran zatvori
    RealtimeRouteTrackingService.stopRouteTracking();

    super.dispose();
  }

  // Uklonjeno ručno učitavanje putnika, koristi se stream

  // Uklonjeno: _calculateDnevniPazar

  // Uklonjeno, filtriranje ide u StreamBuilder

  // Filtriranje dužnika ide u StreamBuilder

  // Optimizacija rute za trenutni polazak (napredna verzija)
  void _optimizeCurrentRoute(List<Putnik> putnici) async {
    setState(() {
      _isLoading = true; // ✅ POKRENI LOADING
    });

    // 🔍 DEBUG - ispišemo trenutne filter vrednosti
    debugPrint(
        '🎯 [OPTIMIZUJ] TRENUTNI FILTERI: grad="$_selectedGrad", vreme="$_selectedVreme"');
    debugPrint('🎯 [OPTIMIZUJ] Ukupno putnika za analizu: ${putnici.length}');

    // 🔍 DEBUG - ispišemo sva dostupna vremena polaska
    final dostupnaVremena = putnici.map((p) => p.polazak).toSet().toList();
    debugPrint('🎯 [OPTIMIZUJ] Dostupna vremena polaska: $dostupnaVremena');

    // 🎯 SAMO REORDER PUTNIKA - bez otvaranja mape
    final filtriraniPutnici = putnici.where((p) {
      final normalizedStatus = (p.status ?? '').toLowerCase().trim();

      final vremeMatch = GradAdresaValidator.normalizeTime(p.polazak) ==
          GradAdresaValidator.normalizeTime(_selectedVreme);

      // 🏘️ KORISTI NOVU OGRANIČENU LOGIKU - samo Bela Crkva i Vršac
      final gradMatch = _isGradMatch(p.grad, p.adresa, _selectedGrad);

      final danMatch = p.dan == _getTodayForDatabase();
      final statusOk = (normalizedStatus != 'otkazano' &&
          normalizedStatus != 'otkazan' &&
          normalizedStatus != 'bolovanje' &&
          normalizedStatus != 'godisnji' &&
          normalizedStatus != 'godišnji' &&
          normalizedStatus != 'obrisan');
      final hasAddress = p.adresa != null && p.adresa!.isNotEmpty;

      // 🔍 DEBUG LOG za optimizaciju
      debugPrint(
          '🎯 [OPTIMIZUJ] Putnik: ${p.ime}, grad: "${p.grad}" vs "$_selectedGrad", vreme: "${p.polazak}" vs "$_selectedVreme", status: "$normalizedStatus", adresa: "${p.adresa}", gradMatch: $gradMatch, vremeMatch: $vremeMatch, danMatch: $danMatch, statusOk: $statusOk, hasAddress: $hasAddress');

      return vremeMatch && gradMatch && danMatch && statusOk && hasAddress;
    }).toList();

    debugPrint(
        '🎯 [OPTIMIZUJ] Ukupno putnika za optimizaciju: ${filtriraniPutnici.length}');

    if (filtriraniPutnici.isEmpty) {
      setState(() {
        _isLoading = false; // ✅ RESETUJ LOADING
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Nema putnika sa adresama za reorder'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // 🎯 OPTIMIZUJ REDOSLED PUTNIKA (bez mape)
      final optimizedPutnici =
          await AdvancedRouteOptimizationService.optimizeRouteAdvanced(
        filtriraniPutnici,
        startAddress: _selectedGrad == 'Bela Crkva'
            ? 'Bela Crkva, Serbia'
            : 'Vršac, Serbia',
        departureTime: DateTime.now(),
        useTrafficData: false, // ISKLJUČENO - trošilo Google API 💸
        useMLOptimization: false, // ISKLJUČENO - ne treba za basic
      );

      setState(() {
        _optimizedRoute = optimizedPutnici;
        _isRouteOptimized = true;
        _isListReordered = true; // ✅ Lista je reorderovana
        _currentPassengerIndex = 0; // ✅ Počni od prvog putnika
        _isGpsTracking = true; // 🛰️ Pokreni GPS tracking
        _lastGpsUpdate = DateTime.now(); // 🛰️ Zapamti vreme
        _isLoading = false; // ✅ ZAUSTAVI LOADING
      });

      // Prikaži rezultat reorderovanja
      final routeString = optimizedPutnici
          .take(3) // Prikaži prva 3 putnika
          .map((p) => p.adresa?.split(',').first ?? p.ime)
          .join(' → ');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '🎯 LISTA PUTNIKA REORDEROVANA za $_selectedGrad $_selectedVreme!',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    '📍 Sledeći putnici: $routeString${optimizedPutnici.length > 3 ? "..." : ""}'),
                Text('🎯 Broj putnika: ${optimizedPutnici.length}'),
                const Text('🛰️ Sledite listu odozgo nadole!'),
              ],
            ),
            duration: const Duration(seconds: 6),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Greška pri optimizaciji rute: $e');

      try {
        // Fallback na osnovnu optimizaciju
        final fallbackOptimized =
            await RouteOptimizationService.optimizeRouteGeographically(
          filtriraniPutnici,
          startAddress: _selectedGrad == 'Bela Crkva'
              ? 'Bela Crkva, Serbia'
              : 'Vršac, Serbia',
        );

        setState(() {
          _optimizedRoute = fallbackOptimized;
          _isRouteOptimized = true;
          _isListReordered = true;
          _currentPassengerIndex = 0;
          _isGpsTracking = true;
          _lastGpsUpdate = DateTime.now();
          _isLoading = false; // ✅ RESETUJ LOADING
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '⚠️ Koristim osnovnu GPS optimizaciju (napredna nije dostupna)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (fallbackError) {
        debugPrint('❌ Greška i sa fallback optimizacijom: $fallbackError');

        // Kompletno neuspešna optimizacija - resetuj sve
        setState(() {
          _isLoading = false; // ✅ RESETUJ LOADING
          _isRouteOptimized = false;
          _isListReordered = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('❌ Nije moguće optimizovati rutu. Pokušajte ponovo.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.center, // dodano za centriranje
                children: [
                  // DATUM TEKST - kao rezervacije
                  Center(
                      child:
                          _buildDigitalDateDisplay()), // dodano Center widget
                  const SizedBox(height: 4),
                  // DUGMAD U APP BAR-U - 5 dugmića jednake širine
                  Row(
                    children: [
                      // 🎓 ĐAČKI BROJAČ
                      Expanded(flex: 1, child: _buildDjackiBrojacButton()),
                      const SizedBox(width: 2),
                      // 🚀 DUGME ZA OPTIMIZACIJU RUTE
                      Expanded(flex: 1, child: _buildOptimizeButton()),
                      const SizedBox(width: 2),
                      // � DUGME ZA POPIS DANA
                      Expanded(flex: 1, child: _buildPopisButton()),
                      const SizedBox(width: 2),
                      // �️ DUGME ZA GOOGLE MAPS
                      Expanded(flex: 1, child: _buildMapsButton()),
                      const SizedBox(width: 2),
                      // ⚡ SPEEDOMETER
                      Expanded(flex: 1, child: _buildSpeedometerButton()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Putnik>>(
              stream: _putnikService
                  .streamKombinovaniPutnici(), // 🔄 KOMBINOVANI STREAM (mesečni + dnevni)
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Greška: ${snapshot.error}'),
                  );
                }

                final sviPutnici = snapshot.data ?? [];
                final danasnjiDan = _getTodayForDatabase();

                debugPrint(
                    '🕐 [DANAS SCREEN] Filter: $danasnjiDan, $_selectedVreme, $_selectedGrad'); // ✅ DEBUG

                // 🔄 REAL-TIME FILTRIRANJE - kombinuj sa vremenskim filterom poslednje nedelje
                final oneWeekAgo =
                    DateTime.now().subtract(const Duration(days: 7));

                final danasPutnici = sviPutnici.where((p) {
                  // Dan u nedelji filter
                  final dayMatch =
                      p.dan.toLowerCase().contains(danasnjiDan.toLowerCase());

                  // Vremski filter - samo poslednja nedelja za dnevne putnike
                  bool timeMatch = true;
                  if (p.mesecnaKarta != true && p.vremeDodavanja != null) {
                    timeMatch = p.vremeDodavanja!.isAfter(oneWeekAgo);
                  }

                  return dayMatch && timeMatch;
                }).toList();

                final vreme = _selectedVreme;
                final grad = _selectedGrad;

                final filtriraniPutnici = danasPutnici.where((putnik) {
                  final normalizedStatus =
                      (putnik.status ?? '').toLowerCase().trim();

                  final vremeMatch =
                      GradAdresaValidator.normalizeTime(putnik.polazak) ==
                          GradAdresaValidator.normalizeTime(vreme);

                  // 🏘️ KORISTI NOVU OGRANIČENU LOGIKU - razlikuj mesečne i obične putnike
                  final gradMatch = _isGradMatch(
                      putnik.grad, putnik.adresa, grad,
                      isMesecniPutnik: putnik.mesecnaKarta == true);

                  final statusOk = (normalizedStatus != 'otkazano' &&
                      normalizedStatus != 'otkazan' &&
                      normalizedStatus != 'bolovanje' &&
                      normalizedStatus != 'godisnji' &&
                      normalizedStatus != 'godišnji' &&
                      normalizedStatus != 'obrisan');

                  return vremeMatch && gradMatch && statusOk;
                }).toList();

                // Koristiti optimizovanu rutu ako postoji, ali filtriraj je po trenutnom polazaku
                final finalPutnici = _isRouteOptimized
                    ? _optimizedRoute.where((putnik) {
                        final normalizedStatus =
                            (putnik.status ?? '').toLowerCase().trim();

                        final vremeMatch =
                            GradAdresaValidator.normalizeTime(putnik.polazak) ==
                                GradAdresaValidator.normalizeTime(vreme);

                        // 🏘️ KORISTI NOVU OGRANIČENU LOGIKU - razlikuj mesečne i obične putnike
                        final gradMatch = _isGradMatch(
                            putnik.grad, putnik.adresa, grad,
                            isMesecniPutnik: putnik.mesecnaKarta == true);

                        final statusOk = (normalizedStatus != 'otkazano' &&
                            normalizedStatus != 'otkazan' &&
                            normalizedStatus != 'bolovanje' &&
                            normalizedStatus != 'godisnji' &&
                            normalizedStatus != 'godišnji' &&
                            normalizedStatus != 'obrisan');

                        return vremeMatch && gradMatch && statusOk;
                      }).toList()
                    : filtriraniPutnici;
                // 💳 SVIH DUŽNIKA SORTIRANIH PO DATUMU (najnoviji na vrhu)
                final filteredDuznici = danasPutnici.where((putnik) {
                  final nijePlatio = (putnik.iznosPlacanja == null ||
                      putnik.iznosPlacanja == 0);
                  final nijeOtkazan =
                      putnik.status != 'otkazan' && putnik.status != 'Otkazano';
                  final jesteMesecni = putnik.mesecnaKarta == true;
                  final pokupljen = putnik.jePokupljen;

                  // 🔥 NOVA LOGIKA: Samo dužnici koje je ovaj vozač pokupljao
                  final jeOvajVozac = (putnik.pokupioVozac == _currentDriver);

                  return nijePlatio &&
                      nijeOtkazan &&
                      !jesteMesecni &&
                      pokupljen &&
                      jeOvajVozac;
                }).toList();

                // Sortiraj po vremenu pokupljenja (najnoviji na vrhu)
                filteredDuznici.sort((a, b) {
                  final aTime = a.vremePokupljenja;
                  final bTime = b.vremePokupljenja;

                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;

                  return bTime.compareTo(aTime);
                });
                // KORISTI NOVU STANDARDIZOVANU LOGIKU ZA PAZAR 💰
                final today = DateTime.now();
                final dayStart = DateTime(today.year, today.month, today.day);
                final dayEnd =
                    DateTime(today.year, today.month, today.day, 23, 59, 59);

                if (kDebugMode) {}

                return StreamBuilder<double>(
                  stream: StatistikaService.streamPazarZaVozaca(
                      _currentDriver ?? '',
                      from: dayStart,
                      to: dayEnd), // 🔄 REAL-TIME PAZAR STREAM
                  builder: (context, pazarSnapshot) {
                    if (!pazarSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    double ukupnoPazarVozac = pazarSnapshot.data!;

                    // Mesečne karte su već uključene u pazarZaVozaca funkciju
                    return Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 69, // smanjio sa 70 na 69
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.green[300]!),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('Pazar',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green)),
                                      const SizedBox(height: 4),
                                      Text(ukupnoPazarVozac.toStringAsFixed(0),
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green),
                                          textAlign: TextAlign.center),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 69, // smanjio sa 70 na 69
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.purple[300]!),
                                  ),
                                  child: StreamBuilder<int>(
                                    stream: StatistikaService
                                        .streamBrojMesecnihKarataZaVozaca(
                                            _currentDriver ?? '',
                                            from: dayStart,
                                            to: dayEnd),
                                    builder: (context, mesecneSnapshot) {
                                      final brojMesecnih =
                                          mesecneSnapshot.data ?? 0;
                                      return Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('Mesečne',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.purple)),
                                          const SizedBox(height: 4),
                                          Text(
                                            brojMesecnih.toString(),
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 69, // smanjio sa 70 na 69
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red[300]!),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DugoviScreen(
                                              currentDriver: _currentDriver),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Dugovi',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red)),
                                        const SizedBox(height: 4),
                                        Text(
                                          filteredDuznici.length.toString(),
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // 🌅 NOVA KOCKA ZA SITAN NOVAC
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 69, // smanjio sa 70 na 69
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.orange[300]!),
                                  ),
                                  child: StreamBuilder<double>(
                                    stream:
                                        DailyCheckInService.streamTodayAmount(
                                            _currentDriver ?? ''),
                                    builder: (context, sitanSnapshot) {
                                      final sitanNovac =
                                          sitanSnapshot.data ?? 0.0;
                                      return Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('Kusur',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange)),
                                          const SizedBox(height: 4),
                                          Text(
                                            sitanNovac > 0
                                                ? sitanNovac.toStringAsFixed(0)
                                                : '-',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: finalPutnici.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Nema putnika za izabrani polazak',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey),
                                  ),
                                )
                              : Column(
                                  children: [
                                    if (_isRouteOptimized)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: _isGpsTracking
                                              ? Colors.blue[50]
                                              : Colors.green[50],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: _isGpsTracking
                                                  ? Colors.blue[300]!
                                                  : Colors.green[300]!),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                                _isGpsTracking
                                                    ? Icons.gps_fixed
                                                    : Icons.route,
                                                color: _isGpsTracking
                                                    ? Colors.blue
                                                    : Colors.green,
                                                size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _isListReordered
                                                        ? '🎯 Lista Reorderovana (${_currentPassengerIndex + 1}/${_optimizedRoute.length})'
                                                        : (_isGpsTracking
                                                            ? '🛰️ GPS Tracking AKTIVAN'
                                                            : 'Ruta optimizovana'),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: _isListReordered
                                                          ? Colors.orange[700]
                                                          : (_isGpsTracking
                                                              ? Colors.blue
                                                              : Colors.green),
                                                    ),
                                                  ),
                                                  // 🎯 PRIKAZ TRENUTNOG PUTNIKA
                                                  if (_isListReordered &&
                                                      _currentPassengerIndex <
                                                          _optimizedRoute
                                                              .length)
                                                    Text(
                                                      '👤 SLEDEĆI: ${_optimizedRoute[_currentPassengerIndex].ime}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Colors.orange[600],
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  // 🧭 PRIKAZ NAVIGATION STATUS-A
                                                  if (_useAdvancedNavigation &&
                                                      _navigationStatus
                                                          .isNotEmpty)
                                                    Text(
                                                      '🧭 $_navigationStatus',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            Colors.indigo[600],
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  if (_isGpsTracking &&
                                                      _lastGpsUpdate != null)
                                                    StreamBuilder<
                                                        RealtimeRouteData>(
                                                      stream:
                                                          RealtimeRouteTrackingService
                                                              .routeDataStream,
                                                      builder: (context,
                                                          realtimeSnapshot) {
                                                        if (realtimeSnapshot
                                                            .hasData) {
                                                          final data =
                                                              realtimeSnapshot
                                                                  .data!;
                                                          final speed = data
                                                                  .currentSpeed
                                                                  ?.toStringAsFixed(
                                                                      1) ??
                                                              '0.0';
                                                          final completion = data
                                                              .routeCompletionPercentage
                                                              .toStringAsFixed(
                                                                  0);
                                                          return Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                'REALTIME: $speed km/h • $completion% završeno',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors
                                                                          .blue[
                                                                      700],
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                              if (data.nextDestination !=
                                                                  null)
                                                                Text(
                                                                  'Sledeći: ${data.nextDestination!.ime}',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize: 9,
                                                                    color: Colors
                                                                            .blue[
                                                                        600],
                                                                  ),
                                                                ),
                                                            ],
                                                          );
                                                        } else {
                                                          return Text(
                                                            'Poslednji update: ${_lastGpsUpdate!.hour}:${_lastGpsUpdate!.minute.toString().padLeft(2, '0')}',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors
                                                                  .blue[700],
                                                            ),
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  // 🔄 REAL-TIME ROUTE STRING
                                                  StreamBuilder<String>(
                                                    stream: Stream
                                                        .fromIterable([
                                                      finalPutnici
                                                    ]).map((putnici) =>
                                                        RouteOptimizationService
                                                            .generateRouteStringSync(
                                                                putnici)),
                                                    initialData:
                                                        RouteOptimizationService
                                                            .generateRouteStringSync(
                                                                finalPutnici),
                                                    builder:
                                                        (context, snapshot) {
                                                      if (snapshot.hasData) {
                                                        return Text(
                                                          snapshot.data!,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color:
                                                                _isGpsTracking
                                                                    ? Colors
                                                                        .blue
                                                                    : Colors
                                                                        .green,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        );
                                                      } else {
                                                        return const Text(
                                                          'Učitavanje...',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.green,
                                                          ),
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // 🧭 NOVO: Real-time navigation widget
                                    if (_useAdvancedNavigation &&
                                        _optimizedRoute.isNotEmpty)
                                      RealTimeNavigationWidget(
                                        optimizedRoute: _optimizedRoute,
                                        onStatusUpdate: (message) {
                                          setState(() {
                                            _navigationStatus = message;
                                          });
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(message),
                                                duration:
                                                    const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                        onRouteUpdate: (newRoute) {
                                          setState(() {
                                            _optimizedRoute = newRoute;
                                          });
                                        },
                                        showDetailedInstructions: true,
                                        enableVoiceInstructions: false,
                                      ),
                                    Expanded(
                                      child: PutnikList(
                                        putnici: finalPutnici,
                                        currentDriver: _currentDriver,
                                        bcVremena: const [
                                          '5:00',
                                          '6:00',
                                          '7:00',
                                          '8:00',
                                          '9:00',
                                          '11:00',
                                          '12:00',
                                          '13:00',
                                          '14:00',
                                          '15:30',
                                          '18:00'
                                        ],
                                        vsVremena: const [
                                          '6:00',
                                          '7:00',
                                          '8:00',
                                          '10:00',
                                          '11:00',
                                          '12:00',
                                          '13:00',
                                          '14:00',
                                          '15:30',
                                          '17:00',
                                          '19:00'
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
      bottomNavigationBar: StreamBuilder<List<Putnik>>(
        stream: _putnikService
            .streamKombinovaniPutnici(), // 🔄 KOMBINOVANI STREAM (mesečni + dnevni)
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              snapshot.hasError ||
              !snapshot.hasData) {
            return Container(
                height: 0); // Ne prikazuj nav bar ako nema podataka
          }

          final allPutnici = snapshot.data!;
          final danasnjiDan = _getTodayForDatabase();
          final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

          debugPrint(
              '🔍 [DANAS SCREEN] Ukupno putnika iz stream-a: ${allPutnici.length}');
          debugPrint('🔍 [DANAS SCREEN] Današnji dan: $danasnjiDan');

          // 🔄 REAL-TIME FILTRIRANJE za bottom nav
          final todayPutnici = allPutnici.where((p) {
            final dayMatch =
                p.dan.toLowerCase().contains(danasnjiDan.toLowerCase());
            bool timeMatch = true;
            if (p.mesecnaKarta != true && p.vremeDodavanja != null) {
              timeMatch = p.vremeDodavanja!.isAfter(oneWeekAgo);
            }

            debugPrint(
                '📍 [DANAS SCREEN] Putnik: ${p.ime}, dan: ${p.dan}, dayMatch: $dayMatch, timeMatch: $timeMatch');

            return dayMatch && timeMatch;
          }).toList();

          debugPrint(
              '🔍 [DANAS SCREEN] Filtrirani putnici za danas: ${todayPutnici.length}');

          // Funkcija za brojanje putnika po gradu, vremenu i danu (samo aktivni)
          int getPutnikCount(String grad, String vreme) {
            final matchingPutnici = todayPutnici.where((putnik) {
              final normalizedStatus =
                  (putnik.status ?? '').toLowerCase().trim();

              // 🏘️ KORISTI NOVU OGRANIČENU LOGIKU - razlikuj mesečne i obične putnike
              final gradMatch = _isGradMatch(putnik.grad, putnik.adresa, grad,
                  isMesecniPutnik: putnik.mesecnaKarta == true);

              final vremeMatch =
                  GradAdresaValidator.normalizeTime(putnik.polazak) ==
                      GradAdresaValidator.normalizeTime(vreme);
              final danMatch =
                  putnik.dan.toLowerCase().contains(danasnjiDan.toLowerCase());
              final statusOk = (normalizedStatus != 'otkazano' &&
                  normalizedStatus != 'otkazan' &&
                  normalizedStatus != 'bolovanje' &&
                  normalizedStatus != 'godisnji' &&
                  normalizedStatus != 'obrisan');

              debugPrint(
                  '🎯 [COUNT] Putnik: ${putnik.ime}, grad: "${putnik.grad}" vs "$grad", vreme: "${putnik.polazak}" vs "$vreme", status: "${putnik.status}", gradMatch: $gradMatch, vremeMatch: $vremeMatch, statusOk: $statusOk');

              return gradMatch && vremeMatch && danMatch && statusOk;
            }).toList();

            debugPrint(
                '📊 [COUNT] Za $grad $vreme: ${matchingPutnici.length} putnika');
            return matchingPutnici.length;
          }

          return BottomNavBarLetnji(
            sviPolasci: _sviPolasci,
            selectedGrad: _selectedGrad,
            selectedVreme: _selectedVreme,
            getPutnikCount: getPutnikCount,
            onPolazakChanged: (grad, vreme) async {
              // Prvo resetuj pokupljanje za novo vreme polaska
              await _putnikService.resetPokupljenjaNaPolazak(
                  vreme, grad, _currentDriver ?? 'Unknown');

              setState(() {
                _selectedGrad = grad;
                _selectedVreme = vreme;
                // Force rebuild da prikaže nove putnike
              });

              // 🔄 REFRESH putnika kada se promeni vreme polaska
              // setState() će automatski reload-ovati widget sa novom logikom
              debugPrint(
                  '🔄 VREME POLASKA PROMENJENO: $grad $vreme - widget će se ažurirati nakon resetovanja pokupljanja');
            },
          );
        },
      ),
    );
  }

  // 🗺️ POKRETANJE GOOGLE MAPS NAVIGACIJE SA OPTIMIZOVANOM RUTOM
  Future<void> _openGoogleMapsNavigation() async {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prvo optimizuj rutu pre pokretanja navigacije!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Kreiranje waypoints od optimizovane rute
      final waypoints = _optimizedRoute
          .where((p) => p.adresa?.isNotEmpty == true)
          .map((p) => p.adresa!)
          .join('|');

      if (waypoints.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nema validnih adresa za navigaciju!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Google Maps URL sa waypoints
      final googleMapsUrl =
          'https://www.google.com/maps/dir/?api=1&waypoints=$waypoints&travelmode=driving';

      // Pokušaj otvaranja URL-a
      final uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '🗺️ Navigacija pokrenuta sa ${_optimizedRoute.length} putnika'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {
      debugPrint('❌ Greška pri pokretanju Google Maps: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Greška pri pokretanju navigacije: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
