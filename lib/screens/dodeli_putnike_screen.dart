import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/route_config.dart';
import '../globals.dart';
import '../models/putnik.dart';
import '../services/kapacitet_service.dart';
import '../services/putnik_service.dart';
import '../services/putnik_vozac_dodela_service.dart'; // • Per-putnik individualno dodeljivanje
import '../services/theme_manager.dart';
import '../services/vreme_vozac_service.dart'; // • Per-vreme dodeljivanje
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/app_snack_bar.dart';
import '../utils/grad_adresa_validator.dart';
import '../utils/putnik_count_helper.dart';
import '../utils/vozac_boja.dart';
import '../widgets/bottom_nav_bar_letnji.dart';
import '../widgets/bottom_nav_bar_praznici.dart';
import '../widgets/bottom_nav_bar_zimski.dart';

/// • DODELI PUTNIKE SCREEN
/// Omogucava adminima (Bojan) da dodele putnike vozacima
/// UI identican HomeScreen-u: izbor dan/vreme/grad, lista putnika sa bojama vozaca
class DodeliPutnikeScreen extends StatefulWidget {
  const DodeliPutnikeScreen({super.key});

  @override
  State<DodeliPutnikeScreen> createState() => _DodeliPutnikeScreenState();
}

class _DodeliPutnikeScreenState extends State<DodeliPutnikeScreen> {
  final PutnikService _putnikService = PutnikService();

  // Filteri - identicno kao HomeScreen
  String _selectedDay = 'Ponedeljak';
  String _selectedGrad = 'Bela Crkva';
  String _selectedVreme = '05:00';

  // Stream subscriptions
  StreamSubscription<List<Putnik>>? _putnikSubscription;
  StreamSubscription<void>? _vremeVozacSubscription;
  String? _currentStreamKey; // • Čuvaj ključ trenutnog streama
  List<Putnik> _putnici = [];
  bool _isLoading = true;

  // Svi putnici za count u BottomNavBar
  List<Putnik> _allPutnici = [];

  // • MULTI-SELECT MODE
  bool _isSelectionMode = false;
  final Set<String> _selectedPutnici = {};

  // Dani
  final List<String> _dani = [
    'Ponedeljak',
    'Utorak',
    'Sreda',
    'Cetvrtak',
    'Petak',
  ];

  // 🕐 DINAMICKA VREMENA - prate navBarTypeNotifier (praznici/zimski/letnji)
  List<String> get bcVremena {
    final navType = navBarTypeNotifier.value;
    if (navType == 'praznici') {
      return RouteConfig.bcVremenaPraznici;
    } else if (navType == 'zimski') {
      return RouteConfig.bcVremenaZimski;
    } else {
      return RouteConfig.bcVremenaLetnji;
    }
  }

  List<String> get vsVremena {
    final navType = navBarTypeNotifier.value;
    if (navType == 'praznici') {
      return RouteConfig.vsVremenaPraznici;
    } else if (navType == 'zimski') {
      return RouteConfig.vsVremenaZimski;
    } else {
      return RouteConfig.vsVremenaLetnji;
    }
  }

  // • Svi polasci za BottomNavBar
  List<String> get _sviPolasci {
    final bcList = bcVremena.map((v) => '$v Bela Crkva').toList();
    final vsList = vsVremena.map((v) => '$v Vršac').toList();
    return [...bcList, ...vsList];
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _getTodayName();
    _setupRealtimeListener();
    _loadVremeVozacCache(); // 🆕 Učitaj vreme-vozac mapiranja
    _setupStream();
  }

  Future<void> _loadVremeVozacCache() async {
    await VremeVozacService().loadAllVremeVozac();
    if (mounted) {
      setState(() {}); // Osvezi UI nakon ucitavanja cache-a
    }
  }

  void _setupRealtimeListener() {
    // NE kreiramo realtime listener-e ovde!
    // PutnikService već ima realtime listener-e i automatski osvežava stream
    // Samo slušamo stream iz PutnikService-a

    // VremeVozacService listener - samo za AppBar naslov
    _vremeVozacSubscription?.cancel();
    _vremeVozacSubscription = VremeVozacService().onChanges.listen((_) {
      if (mounted) {
        setState(() {}); // Osvezi AppBar naslov kada se promeni vreme_vozac
      }
    });
  }

  @override
  void dispose() {
    _putnikSubscription?.cancel();
    _vremeVozacSubscription?.cancel();
    // PutnikService će automatski zatvoriti svoj stream kada nema više listener-a
    super.dispose();
  }

  String _getTodayName() {
    final today = DateTime.now();
    // Vikendom (subota=6, nedelja=7) prikaži ponedeljak
    if (today.weekday == DateTime.saturday || today.weekday == DateTime.sunday) {
      return 'Ponedeljak';
    }
    return app_date_utils.DateUtils.getTodayFullName();
  }

  void _setupStream() {
    // • Zatvori stari stream ako postoji
    _putnikSubscription?.cancel();

    final isoDate = app_date_utils.DateUtils.getIsoDateForDay(_selectedDay);

    _currentStreamKey = isoDate;
    final normalizedVreme = GradAdresaValidator.normalizeTime(_selectedVreme);

    setState(() => _isLoading = true);

    // Stream bez filtera za vreme/grad - da imamo sve putnike za count
    _putnikSubscription = _putnikService
        .streamKombinovaniPutniciFiltered(
      isoDate: isoDate,
    )
        .listen((putnici) {
      if (mounted) {
        final danAbbrev = app_date_utils.DateUtils.getDayAbbreviation(_selectedDay);

        // Sacuvaj sve putnike za dan (za BottomNavBar count)
        _allPutnici = putnici.where((p) {
          final dayMatch = p.datum != null ? p.datum == isoDate : p.dan.toLowerCase().contains(danAbbrev.toLowerCase());
          return dayMatch;
        }).toList();

        // • Filtriraj za prikaz po vremenu i gradu
        final filtered = _allPutnici.where((p) {
          final pVreme = GradAdresaValidator.normalizeTime(p.polazak);
          final vremeMatch = pVreme == normalizedVreme;
          final gradMatch = GradAdresaValidator.isGradMatch(p.grad, p.adresa, _selectedGrad);
          return vremeMatch && gradMatch;
        }).toList();

        // • Ukloni duplikate po putnik ID (ako isti putnik ima više unosa)
        final seenIds = <String>{};
        final deduplicated = <Putnik>[];
        for (final p in filtered) {
          // Koristi requestId ako postoji, inače fallback na p.id
          final uniqueId = p.requestId ?? p.id;
          if (uniqueId != null && !seenIds.contains(uniqueId)) {
            seenIds.add(uniqueId);
            deduplicated.add(p);
          } else if (uniqueId == null) {
            // Ako nema ni requestId ni ID, dodaj svakako (ne bi trebalo da se desi)
            deduplicated.add(p);
          }
        }

        // • Sortiraj po redosledu: Nedodeljeni > Bojan > Ostali vozači
        deduplicated.sort((a, b) {
          // Prvo po statusu (da aktivni budu gore, otkazani i odsustvo dole)
          int getStatusPriority(Putnik p) {
            if (p.jeOdsustvo) return 3; // žuti na dno
            if (p.jeOtkazan) return 2; // crveni iznad žutih
            return 0; // aktivni na vrh
          }

          final statusCompare = getStatusPriority(a).compareTo(getStatusPriority(b));
          if (statusCompare != 0) return statusCompare;

          // Zatim po vozacu: Nedodeljeni=0, Bojan=1, ostali=2
          int getVozacPriority(Putnik p) {
            final vozac = p.dodeljenVozac ?? 'Nedodeljen';
            if (vozac == 'Nedodeljen' || vozac.isEmpty) return 0;
            if (vozac == 'Bojan') return 1;
            return 2;
          }

          final vozacCompare = getVozacPriority(a).compareTo(getVozacPriority(b));
          if (vozacCompare != 0) return vozacCompare;

          // Unutar iste grupe vozaca - alfabetski po imenu putnika
          return a.ime.toLowerCase().compareTo(b.ime.toLowerCase());
        });

        setState(() {
          _putnici = deduplicated;
          _isLoading = false;
        });
      }
    });
  }

  // • Broj putnika za BottomNavBar - REFAKTORISANO: koristi PutnikCountHelper za konzistentnost
  int _getPutnikCount(String grad, String vreme) {
    final isoDate = app_date_utils.DateUtils.getIsoDateForDay(_selectedDay);
    final danAbbrev = app_date_utils.DateUtils.getDayAbbreviation(_selectedDay);

    final countHelper = PutnikCountHelper.fromPutnici(
      putnici: _allPutnici,
      targetDateIso: isoDate,
      targetDayAbbr: danAbbrev,
    );

    return countHelper.getCount(grad, vreme);
  }

  // Callback za BottomNavBar
  void _onPolazakChanged(String grad, String vreme) {
    if (mounted) {
      setState(() {
        _selectedGrad = grad;
        _selectedVreme = vreme;
      });
      _setupStream();
    }
  }

  /// • Vraća kraticu pravca: 'bc' za Bela Crkva, 'vs' za Vršac
  String get _currentPlaceKratica => _selectedGrad == 'Bela Crkva' ? 'bc' : 'vs';

  /// • Vraća kraticu dana: 'pon', 'uto', itd.
  String get _currentDayKratica {
    const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet'];
    final index = _dani.indexOf(_selectedDay);
    return index >= 0 && index < daniKratice.length ? daniKratice[index] : 'pon';
  }

  Future<void> _showVozacPicker(Putnik putnik) async {
    final vozaci = VozacBoja.validDriversSync;
    final currentVozac = putnik.dodeljenVozac ?? 'Nedodeljen';
    final pravacLabel = _selectedGrad == 'Bela Crkva' ? 'BC' : 'VS';

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              putnik.ime,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$pravacLabel $_selectedVreme • Vozač: $currentVozac',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Lista vozaca - scrollable
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. NEDODELJENI - prvi
                        ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey, width: 2),
                            ),
                            child: const Center(
                              child: Icon(Icons.person_off, color: Colors.grey, size: 20),
                            ),
                          ),
                          title: const Text(
                            'Nedodeljeni',
                            style: TextStyle(color: Colors.grey),
                          ),
                          trailing: currentVozac == 'Nedodeljen'
                              ? const Icon(Icons.check_circle, color: Colors.grey)
                              : const Icon(Icons.circle_outlined, color: Colors.grey),
                          onTap: () => Navigator.pop(context, '_NONE_'),
                        ),
                        const Divider(),
                        // 2. BOJAN - drugi (admin)
                        if (vozaci.contains('Bojan')) ...[
                          Builder(builder: (context) {
                            final vozac = 'Bojan';
                            final isSelected = vozac == currentVozac;
                            final color = VozacBoja.getSync(vozac);
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    vozac[0],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                vozac,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? color : null,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle, color: Colors.white)
                                  : const Icon(Icons.circle_outlined, color: Colors.grey),
                              onTap: () => Navigator.pop(context, vozac),
                            );
                          }),
                          const Divider(),
                        ],
                        // 3. OSTALI VOZAČI
                        ...vozaci.where((v) => v != 'Bojan').map((vozac) {
                          final isSelected = vozac == currentVozac;
                          final color = VozacBoja.getSync(vozac);
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  vozac[0],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              vozac,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? color : null,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle, color: Colors.white)
                                : const Icon(Icons.circle_outlined, color: Colors.grey),
                            onTap: () => Navigator.pop(context, vozac),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && selected != currentVozac && putnik.id != null) {
      try {
        // • Ako je izabrano "Bez vozača", ukloni individualnu dodelu
        final noviVozac = selected == '_NONE_' ? null : selected;
        final pravac = _currentPlaceKratica; // 'bc' ili 'vs'
        final targetDatum = app_date_utils.DateUtils.getIsoDateForDay(_selectedDay);

        // • Sačuvaj per-putnik individualnu dodelu (putnik_vozac_dodela tabela)
        final dodelaService = PutnikVozacDodelaService();
        if (noviVozac == null) {
          await dodelaService.ukloniDodelu(
            putnikId: putnik.id!,
            datum: targetDatum,
            grad: pravac,
          );
        } else {
          await dodelaService.dodelVozaca(
            putnikId: putnik.id!,
            vozacIme: noviVozac,
            datum: targetDatum,
            grad: pravac,
            vreme: _selectedVreme,
          );
        }

        if (mounted) {
          final pravacLabel = _selectedGrad == 'Bela Crkva' ? 'BC' : 'VS';
          if (noviVozac == null) {
            AppSnackBar.info(context, '✓ ${putnik.ime} uklonjen sa vozača ($pravacLabel)');
          } else {
            AppSnackBar.success(context, '✓ ${putnik.ime} → $noviVozac ($pravacLabel)');
          }

          // Osvezi UI odmah
          _setupStream();
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.error(context, '• Greška: $e');
        }
      }
    }
  }

  /// • DODELI CELO VREME VOZAČU
  /// Prikazuje picker za izbor vozača koji će voziti CEO termin (npr. BC 18:00)
  Future<void> _showVremeVozacPicker() async {
    final vozaci = VozacBoja.validDriversSync;
    final vremeVozacService = VremeVozacService();
    final danKratica = _currentDayKratica;

    // Dohvati trenutnog vozaca za ovo vreme (ako postoji)
    final currentVozac = vremeVozacService.getVozacZaVremeSync(
          _selectedGrad,
          _selectedVreme,
          danKratica,
        ) ??
        'Nije dodeljeno';

    final pravacLabel = _selectedGrad == 'Bela Crkva' ? 'BC' : 'VS';
    final vremeLabel = '$pravacLabel $_selectedVreme';

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 28, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dodeli $vremeLabel',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Svi putnici na ovom terminu idu sa izabranim vozačem',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Trenutno: $currentVozac',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: currentVozac != 'Nije dodeljeno' ? VozacBoja.getSync(currentVozac) : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Lista vozaca
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...vozaci.map((vozac) {
                          final isSelected = vozac == currentVozac;
                          final color = VozacBoja.getSync(vozac);
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  vozac[0],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              vozac,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? color : null,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle, color: Colors.white)
                                : const Icon(Icons.circle_outlined, color: Colors.grey),
                            onTap: () => Navigator.pop(context, vozac),
                          );
                        }),
                        // Opcija za uklanjanje
                        const Divider(),
                        ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey, width: 2),
                            ),
                            child: const Center(
                              child: Icon(Icons.block, color: Colors.grey, size: 20),
                            ),
                          ),
                          title: const Text(
                            'Ukloni dodeljivanje',
                            style: TextStyle(color: Colors.grey),
                          ),
                          subtitle: const Text(
                            'Putnici koriste individualna dodeljivanja',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: currentVozac == 'Nije dodeljeno'
                              ? const Icon(Icons.check_circle, color: Colors.grey)
                              : const Icon(Icons.circle_outlined, color: Colors.grey),
                          onTap: () => Navigator.pop(context, '_REMOVE_'),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      try {
        if (selected == '_REMOVE_') {
          await vremeVozacService.removeVozacZaVreme(
            _selectedGrad,
            _selectedVreme,
            danKratica,
          );
          if (mounted) {
            AppSnackBar.info(context, '✓ $vremeLabel - dodeljivanje uklonjeno');
            // Prvo osvezi UI
            setState(() {});
            // Čekaj 500ms da se baza ažurira pre nego što osvežiš stream
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              _setupStream();
            }
          }
        } else {
          await vremeVozacService.setVozacZaVreme(
            _selectedGrad,
            _selectedVreme,
            danKratica,
            selected,
          );
          if (mounted) {
            AppSnackBar.success(context, '✓ $vremeLabel → $selected (ceo termin)');
            // Prvo osvezi UI
            setState(() {});
            // Čekaj 500ms da se baza ažurira pre nego što osvežiš stream
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              _setupStream();
            }
          }
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.error(context, '• Greška: $e');
        }
      }
    }
  }

  /// • WIDGET: AppBar title sa indikatorom dodeljenog vozača
  Widget _buildAppBarTitle() {
    if (_isSelectionMode) {
      return Text('${_selectedPutnici.length} selektovano');
    }

    final vremeVozacService = VremeVozacService();
    final terminVozac = vremeVozacService.getVozacZaVremeSync(
      _selectedGrad,
      _selectedVreme,
      _currentDayKratica,
    );

    if (terminVozac != null) {
      final color = VozacBoja.getSync(terminVozac);
      // Samo badge sa vozacem, bez "Dodeli Putnike" teksta da ne bude overflow
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white, // Bela pozadina kako bi boja vozača došla do izražaja
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color, // Tačkica u boji vozača
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              terminVozac,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color, // Ime vozača u njegovoj boji
              ),
            ),
          ],
        ),
      );
    }

    return const Text('Dodeli Putnike');
  }

  @override
  Widget build(BuildContext context) {
    // • Dobijamo boju trenutno dodeljenog vozača za ovaj termin (za fallback)
    final terminVozac = VremeVozacService().getVozacZaVremeSync(
      _selectedGrad,
      _selectedVreme,
      _currentDayKratica,
    );
    final currentTerminalColor = terminVozac != null ? VozacBoja.getSync(terminVozac) : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // • Bele ikonice u status baru
      child: Container(
        decoration: BoxDecoration(
          gradient: ThemeManager().currentGradient, // • Theme-aware gradijent
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: _buildAppBarTitle(),
            centerTitle: true,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: _isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedPutnici.clear();
                      });
                    },
                  )
                : null,
            actions: [
              // • Dodeli celo vreme vozaču
              IconButton(
                icon: const Icon(Icons.groups),
                tooltip: 'Dodeli termin vozaču',
                onPressed: _showVremeVozacPicker,
              ),
              // Izbor dana
              PopupMenuButton<String>(
                tooltip: 'Izaberi dan',
                onSelected: (day) {
                  setState(() => _selectedDay = day);
                  _setupStream();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    _selectedDay,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                itemBuilder: (context) => _dani.map((dan) {
                  final isSelected = dan == _selectedDay;
                  return PopupMenuItem<String>(
                    value: dan,
                    child: Row(
                      children: [
                        if (isSelected)
                          const Icon(Icons.check, size: 18, color: Colors.green)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(
                          dan,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          body: Column(
            children: [
              // • LISTA PUTNIKA
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _putnici.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_off,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Nema putnika za $_selectedVreme',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _putnici.length,
                            itemBuilder: (context, index) {
                              final putnik = _putnici[index];
                              // Ako putnik nije dodeljen, koristi boju termina (npr. narandžasta za BC 5:00)
                              // umesto bledo sive, ili belu ako termin nema vozača.
                              final vozacColor = VozacBoja.getColorOrDefaultSync(
                                putnik.dodeljenVozac,
                                currentTerminalColor,
                              );
                              final isSelected = (putnik.requestId ?? putnik.id) != null &&
                                  _selectedPutnici.contains(putnik.requestId ?? putnik.id);

                              // • Boja kartice prema statusu putnika
                              Color? cardColor;
                              Color? borderColor;
                              String? statusText;
                              if (putnik.jeOtkazan) {
                                cardColor = Colors.red.withOpacity(0.15);
                                borderColor = Colors.red;
                                statusText = '• OTKAZAN';
                              } else if (putnik.jeOdsustvo) {
                                cardColor = Colors.amber.withOpacity(0.15);
                                borderColor = Colors.amber;
                                statusText = '🗓️ ${putnik.status?.toUpperCase() ?? "ODSUSTVO"}';
                              } else if (isSelected) {
                                cardColor = vozacColor.withOpacity(0.1);
                              } else if (putnik.dodeljenVozac != null &&
                                  putnik.dodeljenVozac != 'Nedodeljen' &&
                                  putnik.dodeljenVozac!.isNotEmpty) {
                                cardColor = vozacColor.withOpacity(0.1);
                                borderColor = vozacColor.withOpacity(0.5);
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                color: cardColor,
                                shape: borderColor != null
                                    ? RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: borderColor, width: 2),
                                      )
                                    : null,
                                child: ListTile(
                                  leading: _isSelectionMode
                                      ? Checkbox(
                                          value: isSelected,
                                          activeColor: vozacColor,
                                          onChanged: (value) {
                                            final pId = putnik.requestId ?? putnik.id;
                                            if (pId != null) {
                                              setState(() {
                                                if (value == true) {
                                                  _selectedPutnici.add(pId);
                                                } else {
                                                  _selectedPutnici.remove(pId);
                                                }
                                              });
                                            }
                                          },
                                        )
                                      : CircleAvatar(
                                          backgroundColor: borderColor?.withOpacity(0.3) ?? vozacColor.withOpacity(0.2),
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: (borderColor ?? vozacColor).computeLuminance() > 0.6
                                                  ? Colors.black
                                                  : (borderColor ?? vozacColor),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                  title: Text(
                                    putnik.ime,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black, // Uvek crna za bolju čitljivost
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${putnik.adresa ?? putnik.grad} • ${putnik.dodeljenVozac ?? "Nedodeljen"}',
                                        style: const TextStyle(color: Colors.black87),
                                      ),
                                      if (statusText != null)
                                        Text(
                                          statusText,
                                          style: TextStyle(
                                            color: borderColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: _isSelectionMode
                                      ? CircleAvatar(
                                          radius: 16,
                                          backgroundColor: vozacColor.withOpacity(0.2),
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(color: vozacColor, fontSize: 12),
                                          ),
                                        )
                                      : const Icon(Icons.swap_horiz),
                                  onTap: () {
                                    final pId = putnik.requestId ?? putnik.id;
                                    if (_isSelectionMode && pId != null) {
                                      setState(() {
                                        if (_selectedPutnici.contains(pId)) {
                                          _selectedPutnici.remove(pId);
                                        } else {
                                          _selectedPutnici.add(pId);
                                        }
                                      });
                                    } else {
                                      _showVozacPicker(putnik);
                                    }
                                  },
                                  onLongPress: () {
                                    final pId = putnik.requestId ?? putnik.id;
                                    if (!_isSelectionMode && pId != null) {
                                      setState(() {
                                        _isSelectionMode = true;
                                        _selectedPutnici.add(pId);
                                      });
                                    }
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          // • BOTTOM NAV BAR - identično kao HomeScreen (sa kapacitetom i praznicima)
          bottomNavigationBar: _buildBottomNavBar(),
          // • PERSISTENT BOTTOM SHEET za bulk akcije (kad je selection mode aktivan)
          persistentFooterButtons: _isSelectionMode && _selectedPutnici.isNotEmpty
              ? [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Vozaci dugmici
                          ...VozacBoja.validDriversSync.map((vozac) {
                            final color = VozacBoja.getSync(vozac);
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color.withOpacity(0.2),
                                  foregroundColor: Colors.white,
                                ),
                                icon:
                                    Text(vozac[0], style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                label: Text(vozac),
                                onPressed: () => _bulkPrebaci(vozac),
                              ),
                            );
                          }),
                          const SizedBox(width: 8),
                          // Obriši dugme
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.2),
                              foregroundColor: Colors.red,
                            ),
                            icon: const Icon(Icons.delete),
                            label: const Text('Obriši'),
                            onPressed: _bulkObrisi,
                          ),
                        ],
                      ),
                    ),
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  // • BULK PREBACIVANJE NA VOZAČA
  Future<void> _bulkPrebaci(String noviVozac) async {
    if (_selectedPutnici.isEmpty) return;

    final count = _selectedPutnici.length;
    final pravacLabel = _selectedGrad == 'Bela Crkva' ? 'BC' : 'VS';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Prebaci na $noviVozac?'),
        content: Text('Da li želiš da prebaciš $count putnika na vozača $noviVozac za $pravacLabel pravac?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VozacBoja.getSync(noviVozac),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Prebaci', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    int uspesno = 0;
    int greska = 0;

    final pravac = _currentPlaceKratica;
    final dan = _currentDayKratica;

    for (final identifier in _selectedPutnici.toList()) {
      try {
        // Pronađi putnika u keširanoj listi da izvučemo IDs
        final p = _allPutnici.firstWhere(
          (p) => (p.requestId ?? p.id) == identifier,
          orElse: () => _putnici.firstWhere((p) => (p.requestId ?? p.id) == identifier),
        );

        // Proveri da putnik ima ID pre nego što nastaviš
        if (p.id == null) {
          greska++;
          continue;
        }

        // • Koristi per-putnik individualnu dodelu (putnik_vozac_dodela tabela)
        final targetDatum = app_date_utils.DateUtils.getIsoDateForDay(_selectedDay);
        await PutnikVozacDodelaService().dodelVozaca(
          putnikId: p.id!,
          vozacIme: noviVozac,
          datum: targetDatum,
          grad: pravac,
          vreme: _selectedVreme,
        );
        uspesno++;
        // Čekaj između operacija da se baza ažurira
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        greska++;
      }
    }

    // Čekaj da se sve operacije završe pre nego što osvežiš stream
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _isSelectionMode = false;
        _selectedPutnici.clear();
      });
      AppSnackBar.info(context, '• Prebačeno $uspesno putnika na $noviVozac${greska > 0 ? " (greške: $greska)" : ""}');
      // Osveži listu nakon bulk prebacivanja
      _setupStream();
    }
  }

  // • BULK BRISANJE PUTNIKA
  Future<void> _bulkObrisi() async {
    if (_selectedPutnici.isEmpty) return;

    final count = _selectedPutnici.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Obriši putnike?'),
        content: Text('Da li sigurno želiš da obrišeš $count putnika? Ova akcija se ne može poništiti.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Obriši', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    int uspesno = 0;
    int greska = 0;

    final targetDate = app_date_utils.DateUtils.getIsoDateForDay(_selectedDay);
    for (final identifier in _selectedPutnici.toList()) {
      try {
        final p = _allPutnici.firstWhere(
          (p) => (p.requestId ?? p.id) == identifier,
          orElse: () => _putnici.firstWhere((p) => (p.requestId ?? p.id) == identifier),
        );

        // Proveri da putnik ima ID pre nego što nastaviš
        if (p.id == null) {
          greska++;
          continue;
        }

        await _putnikService.otkaziPutnika(
          p.id!,
          'Admin',
          datum: targetDate,
          selectedVreme: _selectedVreme,
          selectedGrad: _selectedGrad,
          requestId: p.requestId,
        );
        uspesno++;
        // Čekaj između operacija da se baza ažurira
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        greska++;
      }
    }

    // Čekaj da se sve operacije završe pre nego što osvežiš stream
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _isSelectionMode = false;
        _selectedPutnici.clear();
      });
      AppSnackBar.error(context, '• Obrisano $uspesno putnika${greska > 0 ? " (greške: $greska)" : ""}');
      // Osveži listu nakon bulk brisanja
      _setupStream();
    }
  }

  /// • Helper metoda za kreiranje bottom nav bar-a (identično kao HomeScreen)
  Widget _buildBottomNavBar() {
    final navType = navBarTypeNotifier.value;
    final now = DateTime.now();

    switch (navType) {
      case 'praznici':
        return BottomNavBarPraznici(
          sviPolasci: _sviPolasci,
          selectedGrad: _selectedGrad,
          selectedVreme: _selectedVreme,
          getPutnikCount: _getPutnikCount,
          getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
          onPolazakChanged: _onPolazakChanged,
          selectedDan: _selectedDay,
          showVozacBoja: true,
        );
      case 'zimski':
        return BottomNavBarZimski(
          sviPolasci: _sviPolasci,
          selectedGrad: _selectedGrad,
          selectedVreme: _selectedVreme,
          getPutnikCount: _getPutnikCount,
          getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
          onPolazakChanged: _onPolazakChanged,
          selectedDan: _selectedDay,
          showVozacBoja: true,
        );
      default: // 'letnji' ili nepoznato
        return BottomNavBarLetnji(
          sviPolasci: _sviPolasci,
          selectedGrad: _selectedGrad,
          selectedVreme: _selectedVreme,
          getPutnikCount: _getPutnikCount,
          getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
          onPolazakChanged: _onPolazakChanged,
          selectedDan: _selectedDay,
          showVozacBoja: true,
        );
    }
  }
}
