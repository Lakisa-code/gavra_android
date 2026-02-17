import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/route_config.dart';
import '../globals.dart';
import '../models/putnik.dart';
import '../services/kapacitet_service.dart';
import '../services/putnik_service.dart';
import '../services/realtime/realtime_manager.dart'; // ?? Realtime manager
import '../services/theme_manager.dart';
import '../services/vreme_vozac_service.dart'; // ?? Per-vreme dodeljivanje
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/grad_adresa_validator.dart';
import '../utils/putnik_count_helper.dart';
import '../utils/vozac_boja.dart';
import '../widgets/bottom_nav_bar_letnji.dart';
import '../widgets/bottom_nav_bar_praznici.dart';
import '../widgets/bottom_nav_bar_zimski.dart';

/// ?? DODELI PUTNIKE SCREEN
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
  String _selectedVreme = '5:00';

  // Stream subscription
  StreamSubscription<List<Putnik>>? _putnikSubscription;
  String? _currentStreamKey; // ?? Cuvaj kljuc trenutnog streama
  List<Putnik> _putnici = [];
  bool _isLoading = true;

  // Svi putnici za count u BottomNavBar
  List<Putnik> _allPutnici = [];

  // ?? MULTI-SELECT MODE
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

  // ?? Svi polasci za BottomNavBar
  List<String> get _sviPolasci {
    final bcList = bcVremena.map((v) => '$v Bela Crkva').toList();
    final vsList = vsVremena.map((v) => '$v Vr�ac').toList();
    return [...bcList, ...vsList];
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _getTodayName();
    _setupRealtimeListener();
    _setupStream();
  }

  void _setupRealtimeListener() {
    // Slu�aj promjene u registrovani_putnici tabeli
    RealtimeManager.instance.subscribe('registrovani_putnici').listen((_) {
      if (mounted) {
        _setupStream();
      }
    });
  }

  @override
  void dispose() {
    _putnikSubscription?.cancel();
    super.dispose();
  }

  String _getTodayName() {
    final today = DateTime.now();
    // Vikendom (subota=6, nedelja=7) prika�i ponedeljak
    if (today.weekday == DateTime.saturday ||
        today.weekday == DateTime.sunday) {
      return 'Ponedeljak';
    }
    return app_date_utils.DateUtils.getTodayFullName();
  }

  // ? KORISTI CENTRALNU FUNKCIJU IZ DateUtils

  void _setupStream() {
    // ?? Zatvori stari stream ako postoji
    _putnikSubscription?.cancel();

    final isoDate = app_date_utils.DateUtils.getIsoDateForDay(_selectedDay);

    // ?? Ako menjamo datum, zatvori stari stream eksplicitno
    if (_currentStreamKey != null) {
      // Ekstraktuj isoDate iz starog kljuca
      final oldIsoDate = _currentStreamKey!.split('|')[0];
      if (oldIsoDate.isNotEmpty && oldIsoDate != isoDate) {
        PutnikService.closeStream(isoDate: oldIsoDate);
      }
    }

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
        final danAbbrev =
            app_date_utils.DateUtils.getDayAbbreviation(_selectedDay);

        // Sacuvaj sve putnike za dan (za BottomNavBar count)
        _allPutnici = putnici.where((p) {
          return p.dan.toLowerCase() == danAbbrev.toLowerCase();
        }).toList();

        // Filtriraj za prikaz po vremenu i gradu
        final filtered = _allPutnici.where((p) {
          final vremeMatch =
              GradAdresaValidator.normalizeTime(p.polazak) == normalizedVreme;
          final gradMatch =
              GradAdresaValidator.isGradMatch(p.grad, p.adresa, _selectedGrad);
          return vremeMatch && gradMatch;
        }).toList();

        // ?? Sortiraj po redosledu: Nedodeljeni ? Bojan ? Ostali vozaci
        filtered.sort((a, b) {
          // Prvo po statusu (da aktivni budu gore, otkazani i odsustvo dole)
          int getStatusPriority(Putnik p) {
            if (p.jeOdsustvo) return 3; // �uti na dno
            if (p.jeOtkazan) return 2; // crveni iznad �utih
            return 0; // aktivni na vrh
          }

          final statusCompare =
              getStatusPriority(a).compareTo(getStatusPriority(b));
          if (statusCompare != 0) return statusCompare;

          // Zatim po vozacu: Nedodeljeni=0, Bojan=1, ostali=2
          int getVozacPriority(Putnik p) {
            final vozac = p.dodeljenVozac ?? 'Nedodeljen';
            if (vozac == 'Nedodeljen' || vozac.isEmpty) return 0;
            if (vozac == 'Bojan') return 1;
            return 2;
          }

          final vozacCompare =
              getVozacPriority(a).compareTo(getVozacPriority(b));
          if (vozacCompare != 0) return vozacCompare;

          // Unutar iste grupe vozaca - alfabetski po imenu putnika
          return a.ime.toLowerCase().compareTo(b.ime.toLowerCase());
        });

        setState(() {
          _putnici = filtered;
          _isLoading = false;
        });
      }
    });
  }

  // ?? Broj putnika za BottomNavBar - REFAKTORISANO: koristi PutnikCountHelper za konzistentnost
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

  /// ?? Vraca kraticu pravca: 'bc' za Bela Crkva, 'vs' za Vr�ac
  String get _currentPlaceKratica =>
      _selectedGrad == 'Bela Crkva' ? 'bc' : 'vs';

  /// ?? Vraca kraticu dana: 'pon', 'uto', itd.
  String get _currentDayKratica {
    const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    final index = _dani.indexOf(_selectedDay);
    return index >= 0 && index < daniKratice.length
        ? daniKratice[index]
        : 'pon';
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                              '$pravacLabel $_selectedVreme � Vozac: $currentVozac',
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
                        // 1?? NEDODELJENI - prvi
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
                              child: Icon(Icons.person_off,
                                  color: Colors.grey, size: 20),
                            ),
                          ),
                          title: const Text(
                            'Nedodeljeni',
                            style: TextStyle(color: Colors.grey),
                          ),
                          trailing: currentVozac == 'Nedodeljen'
                              ? const Icon(Icons.check_circle,
                                  color: Colors.grey)
                              : const Icon(Icons.circle_outlined,
                                  color: Colors.grey),
                          onTap: () => Navigator.pop(context, '_NONE_'),
                        ),
                        const Divider(),
                        // 2?? BOJAN - drugi (admin)
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
                                  border:
                                      Border.all(color: Colors.white, width: 2),
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
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected ? color : null,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle,
                                      color: Colors.white)
                                  : const Icon(Icons.circle_outlined,
                                      color: Colors.grey),
                              onTap: () => Navigator.pop(context, vozac),
                            );
                          }),
                          const Divider(),
                        ],
                        // 3?? OSTALI VOZACI
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
                                border:
                                    Border.all(color: Colors.white, width: 2),
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
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected ? color : null,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle, color: Colors.white)
                                : const Icon(Icons.circle_outlined,
                                    color: Colors.grey),
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
        // ? Ako je izabrano "Bez vozaca", postavi null
        final noviVozac = selected == '_NONE_' ? null : selected;
        final pravac = _currentPlaceKratica; // 'bc' ili 'vs'
        final dan = _currentDayKratica; // 'pon', 'uto', itd.

        // ?? Sacuvaj per-pravac per-vreme (bc_5:00_vozac ili vs_14:00_vozac u polasci_po_danu)
        await _putnikService.dodelPutnikaVozacuZaPravac(
          putnik.id!,
          noviVozac,
          pravac,
          vreme: _selectedVreme, // ?? Prosledivanje vremena
          selectedDan: dan,
        );

        // Cekaj 300ms da se baza a�urira prije nego �to osve�i UI
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          final pravacLabel = _selectedGrad == 'Bela Crkva' ? 'BC' : 'VS';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(noviVozac == null
                  ? '? ${putnik.ime} uklonjen sa vozaca ($pravacLabel)'
                  : '? ${putnik.ime} ? $noviVozac ($pravacLabel)'),
              backgroundColor: noviVozac == null
                  ? Colors.grey
                  : VozacBoja.getSync(noviVozac),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('? Gre�ka: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// ?? DODELI CELO VREME VOZACU
  /// Prikazuje picker za izbor vozaca koji ce voziti CEO termin (npr. BC 18:00)
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
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
                              'Svi putnici na ovom terminu idu sa izabranim vozacem',
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
                                color: currentVozac != 'Nije dodeljeno'
                                    ? VozacBoja.getSync(currentVozac)
                                    : Colors.grey,
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
                                border:
                                    Border.all(color: Colors.white, width: 2),
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
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected ? color : null,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle, color: Colors.white)
                                : const Icon(Icons.circle_outlined,
                                    color: Colors.grey),
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
                              child: Icon(Icons.block,
                                  color: Colors.grey, size: 20),
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
                              ? const Icon(Icons.check_circle,
                                  color: Colors.grey)
                              : const Icon(Icons.circle_outlined,
                                  color: Colors.grey),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('? $vremeLabel - dodeljivanje uklonjeno'),
                backgroundColor: Colors.grey,
                duration: const Duration(seconds: 2),
              ),
            );
            // Cekaj 300ms da se baza a�urira prije nego �to refresh-uje� stream
            await Future.delayed(const Duration(milliseconds: 300));
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('? $vremeLabel ? $selected (ceo termin)'),
                backgroundColor: VozacBoja.getSync(selected),
                duration: const Duration(seconds: 2),
              ),
            );
            // Cekaj 300ms da se baza a�urira prije nego �to refresh-uje� stream
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) {
              _setupStream();
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('? Gre�ka: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// ?? WIDGET: AppBar title sa indikatorom dodeljenog vozaca
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
          color: color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              terminVozac,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // ?? Bele ikonice u status baru
      child: Container(
        decoration: BoxDecoration(
          gradient: ThemeManager().currentGradient, // ?? Theme-aware gradijent
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
              // ?? Dodeli celo vreme vozacu
              IconButton(
                icon: const Icon(Icons.groups),
                tooltip: 'Dodeli termin vozacu',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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
              // ?? LISTA PUTNIKA
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
                              final vozacColor =
                                  VozacBoja.getColorOrDefaultSync(
                                      putnik.dodeljenVozac, Colors.grey);
                              final isSelected = putnik.id != null &&
                                  _selectedPutnici.contains(putnik.id);

                              // ?? Boja kartice prema statusu putnika
                              Color? cardColor;
                              Color? borderColor;
                              String? statusText;
                              if (putnik.jeOtkazan) {
                                cardColor = Colors.red.withOpacity(0.15);
                                borderColor = Colors.red;
                                statusText = '? OTKAZAN';
                              } else if (putnik.jeOdsustvo) {
                                cardColor = Colors.amber.withOpacity(0.15);
                                borderColor = Colors.amber;
                                statusText =
                                    '??? ${putnik.status?.toUpperCase() ?? "ODSUSTVO"}';
                              } else if (isSelected) {
                                cardColor = vozacColor.withOpacity(0.1);
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                color: cardColor,
                                shape: borderColor != null
                                    ? RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                            color: borderColor, width: 2),
                                      )
                                    : null,
                                child: ListTile(
                                  leading: _isSelectionMode
                                      ? Checkbox(
                                          value: isSelected,
                                          activeColor: vozacColor,
                                          onChanged: (value) {
                                            if (putnik.id != null) {
                                              setState(() {
                                                if (value == true) {
                                                  _selectedPutnici
                                                      .add(putnik.id!);
                                                } else {
                                                  _selectedPutnici
                                                      .remove(putnik.id);
                                                }
                                              });
                                            }
                                          },
                                        )
                                      : CircleAvatar(
                                          backgroundColor:
                                              borderColor?.withOpacity(0.3) ??
                                                  vozacColor.withOpacity(0.2),
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: borderColor ?? vozacColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                  title: Text(
                                    putnik.ime,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: borderColor,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${putnik.adresa ?? putnik.grad} � ${putnik.dodeljenVozac ?? "Nedodeljen"}',
                                        style: TextStyle(
                                            color: borderColor ?? vozacColor),
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
                                          backgroundColor:
                                              vozacColor.withOpacity(0.2),
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                                color: vozacColor,
                                                fontSize: 12),
                                          ),
                                        )
                                      : const Icon(Icons.swap_horiz),
                                  onTap: () {
                                    if (_isSelectionMode && putnik.id != null) {
                                      setState(() {
                                        if (_selectedPutnici
                                            .contains(putnik.id)) {
                                          _selectedPutnici.remove(putnik.id);
                                        } else {
                                          _selectedPutnici.add(putnik.id!);
                                        }
                                      });
                                    } else {
                                      _showVozacPicker(putnik);
                                    }
                                  },
                                  onLongPress: () {
                                    if (!_isSelectionMode &&
                                        putnik.id != null) {
                                      setState(() {
                                        _isSelectionMode = true;
                                        _selectedPutnici.add(putnik.id!);
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
          // ?? BOTTOM NAV BAR - identicno kao HomeScreen (sa kapacitetom i praznicima)
          bottomNavigationBar: _buildBottomNavBar(),
          // ?? PERSISTENT BOTTOM SHEET za bulk akcije (kad je selection mode aktivan)
          persistentFooterButtons:
              _isSelectionMode && _selectedPutnici.isNotEmpty
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
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: color.withOpacity(0.2),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: Text(vozac[0],
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    label: Text(vozac),
                                    onPressed: () => _bulkPrebaci(vozac),
                                  ),
                                );
                              }),
                              const SizedBox(width: 8),
                              // Obri�i dugme
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.withOpacity(0.2),
                                  foregroundColor: Colors.red,
                                ),
                                icon: const Icon(Icons.delete),
                                label: const Text('Obri�i'),
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

  // ?? BULK PREBACIVANJE NA VOZACA
  Future<void> _bulkPrebaci(String noviVozac) async {
    if (_selectedPutnici.isEmpty) return;

    final count = _selectedPutnici.length;
    final pravacLabel = _selectedGrad == 'Bela Crkva' ? 'BC' : 'VS';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Prebaci na $noviVozac?'),
        content: Text(
            'Da li �eli� da prebaci� $count putnika na vozaca $noviVozac za $pravacLabel pravac?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otka�i'),
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

    for (final id in _selectedPutnici.toList()) {
      try {
        // ?? Koristi per-pravac per-vreme dodeljivanje
        await _putnikService.dodelPutnikaVozacuZaPravac(
          id,
          noviVozac,
          pravac,
          vreme: _selectedVreme, // ?? Prosledivanje vremena
          selectedDan: dan,
        );
        uspesno++;
        // Cekaj izmedu operacija da se baza a�urira
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        greska++;
      }
    }

    // Cekaj da se sve operacije kompletan prije osve�avanja streama
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _isSelectionMode = false;
        _selectedPutnici.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '? Prebaceno $uspesno putnika na $noviVozac${greska > 0 ? " (gre�ke: $greska)" : ""}'),
          backgroundColor: VozacBoja.getSync(noviVozac),
        ),
      );
      // Osvezi listu nakon bulk prebacivanja
      _setupStream();
    }
  }

  // ??? BULK BRISANJE PUTNIKA
  Future<void> _bulkObrisi() async {
    if (_selectedPutnici.isEmpty) return;

    final count = _selectedPutnici.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Obri�i putnike?'),
        content: Text(
            'Da li sigurno �eli� da obri�e� $count putnika? Ova akcija se ne mo�e poni�titi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otka�i'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Obri�i', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    int uspesno = 0;
    int greska = 0;

    for (final id in _selectedPutnici.toList()) {
      try {
        await _putnikService.otkaziPutnika(id, 'Admin',
            selectedVreme: _selectedVreme,
            selectedGrad: _selectedGrad,
            selectedDan: _selectedDay);
        uspesno++;
        // Cekaj izmedu operacija da se baza a�urira
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        greska++;
      }
    }

    // Cekaj da se sve operacije kompletan prije osve�avanja streama
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _isSelectionMode = false;
        _selectedPutnici.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '??? Obrisano $uspesno putnika${greska > 0 ? " (gre�ke: $greska)" : ""}'),
          backgroundColor: Colors.red,
        ),
      );
      // Osvezi listu nakon bulk brisanja
      _setupStream();
    }
  }

  /// ?? Helper metoda za kreiranje bottom nav bar-a (identicno kao HomeScreen)
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
          getKapacitet: (grad, vreme) =>
              KapacitetService.getKapacitetSync(grad, vreme),
          onPolazakChanged: _onPolazakChanged,
          selectedDan: _selectedDay,
        );
      case 'zimski':
        return BottomNavBarZimski(
          sviPolasci: _sviPolasci,
          selectedGrad: _selectedGrad,
          selectedVreme: _selectedVreme,
          getPutnikCount: _getPutnikCount,
          getKapacitet: (grad, vreme) =>
              KapacitetService.getKapacitetSync(grad, vreme),
          onPolazakChanged: _onPolazakChanged,
          selectedDan: _selectedDay,
        );
      default: // 'letnji' ili nepoznato
        return BottomNavBarLetnji(
          sviPolasci: _sviPolasci,
          selectedGrad: _selectedGrad,
          selectedVreme: _selectedVreme,
          getPutnikCount: _getPutnikCount,
          getKapacitet: (grad, vreme) =>
              KapacitetService.getKapacitetSync(grad, vreme),
          onPolazakChanged: _onPolazakChanged,
          selectedDan: _selectedDay,
        );
    }
  }
}
