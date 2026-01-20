import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/route_config.dart';
import '../globals.dart';
import '../models/putnik.dart';
import '../services/kapacitet_service.dart';
import '../services/putnik_service.dart';
import '../services/theme_manager.dart';
import '../services/vreme_vozac_service.dart'; // 🆕 Per-vreme dodeljivanje
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/grad_adresa_validator.dart';
import '../utils/putnik_count_helper.dart';
import '../utils/schedule_utils.dart';
import '../utils/vozac_boja.dart';
import '../widgets/bottom_nav_bar_letnji.dart';
import '../widgets/bottom_nav_bar_praznici.dart';
import '../widgets/bottom_nav_bar_zimski.dart';

/// 🎯 DODELI PUTNIKE SCREEN
/// Omogućava adminima (Bojan, Svetlana) da dodele putnike vozačima
/// UI identičan HomeScreen-u: izbor dan/vreme/grad, lista putnika sa bojama vozača
class DodeliPutnikeScreen extends StatefulWidget {
  const DodeliPutnikeScreen({super.key});

  @override
  State<DodeliPutnikeScreen> createState() => _DodeliPutnikeScreenState();
}

class _DodeliPutnikeScreenState extends State<DodeliPutnikeScreen> {
  final PutnikService _putnikService = PutnikService();

  // Filteri - identično kao HomeScreen
  String _selectedDay = 'Ponedeljak';
  String _selectedGrad = 'Bela Crkva';
  String _selectedVreme = '5:00';

  // Stream subscription
  StreamSubscription<List<Putnik>>? _putnikSubscription;
  List<Putnik> _putnici = [];
  bool _isLoading = true;

  // Svi putnici za count u BottomNavBar
  List<Putnik> _allPutnici = [];

  // 🎯 MULTI-SELECT MODE
  bool _isSelectionMode = false;
  final Set<String> _selectedPutnici = {};

  // Dani
  final List<String> _dani = [
    'Ponedeljak',
    'Utorak',
    'Sreda',
    'Četvrtak',
    'Petak',
  ];

  // 🕐 DINAMIČKA VREMENA - prate navBarTypeNotifier (praznici/zimski/letnji)
  List<String> get bcVremena {
    final navType = navBarTypeNotifier.value;
    switch (navType) {
      case 'praznici':
        return RouteConfig.bcVremenaPraznici;
      case 'zimski':
        return RouteConfig.bcVremenaZimski;
      case 'letnji':
        return RouteConfig.bcVremenaLetnji;
      default: // 'auto'
        return isZimski(DateTime.now()) ? RouteConfig.bcVremenaZimski : RouteConfig.bcVremenaLetnji;
    }
  }

  List<String> get vsVremena {
    final navType = navBarTypeNotifier.value;
    switch (navType) {
      case 'praznici':
        return RouteConfig.vsVremenaPraznici;
      case 'zimski':
        return RouteConfig.vsVremenaZimski;
      case 'letnji':
        return RouteConfig.vsVremenaLetnji;
      default: // 'auto'
        return isZimski(DateTime.now()) ? RouteConfig.vsVremenaZimski : RouteConfig.vsVremenaLetnji;
    }
  }

  // 📋 Svi polasci za BottomNavBar
  List<String> get _sviPolasci {
    final bcList = bcVremena.map((v) => '$v Bela Crkva').toList();
    final vsList = vsVremena.map((v) => '$v Vršac').toList();
    return [...bcList, ...vsList];
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _getTodayName();
    _setupStream();
  }

  @override
  void dispose() {
    _putnikSubscription?.cancel();
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

  // ✅ KORISTI CENTRALNU FUNKCIJU IZ DateUtils

  void _setupStream() {
    _putnikSubscription?.cancel();

    final isoDate = app_date_utils.DateUtils.getIsoDateForDay(_selectedDay);
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

        // Sačuvaj sve putnike za dan (za BottomNavBar count)
        _allPutnici = putnici.where((p) {
          return p.dan.toLowerCase() == danAbbrev.toLowerCase();
        }).toList();

        // Filtriraj za prikaz po vremenu i gradu
        final filtered = _allPutnici.where((p) {
          final vremeMatch = GradAdresaValidator.normalizeTime(p.polazak) == normalizedVreme;
          final gradMatch = GradAdresaValidator.isGradMatch(p.grad, p.adresa, _selectedGrad);
          return vremeMatch && gradMatch;
        }).toList();

        // 🔢 Sortiraj konzistentno sa PutnikList:
        // 1. Aktivni (alfabetski)
        // 2. Crveni (otkazani)
        // 3. Žuti (odsustvo - bolovanje/godišnji) na dno
        filtered.sort((a, b) {
          // Prioritet: aktivni=0, otkazani=1, odsustvo=2
          int getPriority(Putnik p) {
            if (p.jeOdsustvo) return 2; // žuti na dno
            if (p.jeOtkazan) return 1; // crveni iznad žutih
            return 0; // aktivni na vrh
          }

          final priorityCompare = getPriority(a).compareTo(getPriority(b));
          if (priorityCompare != 0) return priorityCompare;
          // Unutar iste grupe - alfabetski
          return a.ime.toLowerCase().compareTo(b.ime.toLowerCase());
        });

        setState(() {
          _putnici = filtered;
          _isLoading = false;
        });
      }
    });
  }

  // 📊 Broj putnika za BottomNavBar - REFAKTORISANO: koristi PutnikCountHelper za konzistentnost
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

  /// 🆕 Vraća kraticu pravca: 'bc' za Bela Crkva, 'vs' za Vršac
  String get _currentPlaceKratica => _selectedGrad == 'Bela Crkva' ? 'bc' : 'vs';

  /// 🆕 Vraća kraticu dana: 'pon', 'uto', itd.
  String get _currentDayKratica {
    const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    final index = _dani.indexOf(_selectedDay);
    return index >= 0 && index < daniKratice.length ? daniKratice[index] : 'pon';
  }

  Future<void> _showVozacPicker(Putnik putnik) async {
    final vozaci = VozacBoja.validDrivers;
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
                // Lista vozača - scrollable
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...vozaci.map((vozac) {
                          final isSelected = vozac == currentVozac;
                          final color = VozacBoja.get(vozac);
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: color, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  vozac[0],
                                  style: TextStyle(
                                    color: color,
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
                                ? Icon(Icons.check_circle, color: color)
                                : const Icon(Icons.circle_outlined, color: Colors.grey),
                            onTap: () => Navigator.pop(context, vozac),
                          );
                        }),
                        // ➖ Opcija za uklanjanje vozača
                        const Divider(),
                        ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey, width: 2),
                            ),
                            child: const Center(
                              child: Icon(Icons.person_off, color: Colors.grey, size: 20),
                            ),
                          ),
                          title: const Text(
                            'Bez vozača',
                            style: TextStyle(color: Colors.grey),
                          ),
                          trailing: currentVozac == 'Nedodeljen'
                              ? const Icon(Icons.check_circle, color: Colors.grey)
                              : const Icon(Icons.circle_outlined, color: Colors.grey),
                          onTap: () => Navigator.pop(context, '_NONE_'),
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

    if (selected != null && selected != currentVozac && putnik.id != null) {
      try {
        // ➖ Ako je izabrano "Bez vozača", postavi null
        final noviVozac = selected == '_NONE_' ? null : selected;
        final pravac = _currentPlaceKratica; // 'bc' ili 'vs'
        final dan = _currentDayKratica; // 'pon', 'uto', itd.

        // 🆕 Sačuvaj per-pravac per-vreme (bc_5:00_vozac ili vs_14:00_vozac u polasci_po_danu)
        await _putnikService.dodelPutnikaVozacuZaPravac(
          putnik.id!,
          noviVozac,
          pravac,
          vreme: _selectedVreme, // 🆕 Prosleđivanje vremena
          selectedDan: dan,
        );

        if (mounted) {
          final pravacLabel = _selectedGrad == 'Bela Crkva' ? 'BC' : 'VS';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(noviVozac == null
                  ? '✅ ${putnik.ime} uklonjen sa vozača ($pravacLabel)'
                  : '✅ ${putnik.ime} → $noviVozac ($pravacLabel)'),
              backgroundColor: noviVozac == null ? Colors.grey : VozacBoja.get(noviVozac),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
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
  }

  /// 🆕 DODELI CELO VREME VOZAČU
  /// Prikazuje picker za izbor vozača koji će voziti CEO termin (npr. BC 18:00)
  Future<void> _showVremeVozacPicker() async {
    final vozaci = VozacBoja.validDrivers;
    final vremeVozacService = VremeVozacService();
    final danKratica = _currentDayKratica;

    // Dohvati trenutnog vozača za ovo vreme (ako postoji)
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
                    color: Colors.blue.withValues(alpha: 0.1),
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
                                color: currentVozac != 'Nije dodeljeno' ? VozacBoja.get(currentVozac) : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Lista vozača
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...vozaci.map((vozac) {
                          final isSelected = vozac == currentVozac;
                          final color = VozacBoja.get(vozac);
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: color, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  vozac[0],
                                  style: TextStyle(
                                    color: color,
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
                                ? Icon(Icons.check_circle, color: color)
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
                              color: Colors.grey.withValues(alpha: 0.2),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ $vremeLabel - dodeljivanje uklonjeno'),
                backgroundColor: Colors.grey,
                duration: const Duration(seconds: 2),
              ),
            );
            // Osveži listu putnika
            _setupStream();
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
                content: Text('✅ $vremeLabel → $selected (ceo termin)'),
                backgroundColor: VozacBoja.get(selected),
                duration: const Duration(seconds: 2),
              ),
            );
            // Osveži listu putnika
            _setupStream();
          }
        }
      } catch (e) {
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
  }

  /// 🆕 WIDGET: AppBar title sa indikatorom dodeljenog vozača
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
      final color = VozacBoja.get(terminVozac);
      // Samo badge sa vozačem, bez "Dodeli Putnike" teksta da ne bude overflow
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.3),
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
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              terminVozac,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
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
      value: SystemUiOverlayStyle.light, // 🎨 Bele ikonice u status baru
      child: Container(
        decoration: BoxDecoration(
          gradient: ThemeManager().currentGradient, // 🎨 Theme-aware gradijent
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
              // 🆕 Dodeli celo vreme vozaču
              IconButton(
                icon: const Icon(Icons.groups),
                tooltip: 'Dodeli termin vozaču',
                onPressed: _showVremeVozacPicker,
              ),
              // 🎯 Toggle selection mode
              IconButton(
                icon: Icon(_isSelectionMode ? Icons.check_circle : Icons.checklist),
                tooltip: _isSelectionMode ? 'Završi selekciju' : 'Selektuj putnike',
                onPressed: () {
                  setState(() {
                    _isSelectionMode = !_isSelectionMode;
                    if (!_isSelectionMode) _selectedPutnici.clear();
                  });
                },
              ),
              // Izbor dana
              PopupMenuButton<String>(
                icon: const Icon(Icons.calendar_today),
                tooltip: 'Izaberi dan',
                onSelected: (day) {
                  setState(() => _selectedDay = day);
                  _setupStream();
                },
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
              // 📋 LISTA PUTNIKA
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
                              final vozacColor = VozacBoja.getColorOrDefault(putnik.dodeljenVozac, Colors.grey);
                              final isSelected = putnik.id != null && _selectedPutnici.contains(putnik.id);

                              // 🎨 Boja kartice prema statusu putnika
                              Color? cardColor;
                              Color? borderColor;
                              String? statusText;
                              if (putnik.jeOtkazan) {
                                cardColor = Colors.red.withValues(alpha: 0.15);
                                borderColor = Colors.red;
                                statusText = '❌ OTKAZAN';
                              } else if (putnik.jeOdsustvo) {
                                cardColor = Colors.amber.withValues(alpha: 0.15);
                                borderColor = Colors.amber;
                                statusText = '🏖️ ${putnik.status?.toUpperCase() ?? "ODSUSTVO"}';
                              } else if (isSelected) {
                                cardColor = vozacColor.withValues(alpha: 0.1);
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
                                            if (putnik.id != null) {
                                              setState(() {
                                                if (value == true) {
                                                  _selectedPutnici.add(putnik.id!);
                                                } else {
                                                  _selectedPutnici.remove(putnik.id);
                                                }
                                              });
                                            }
                                          },
                                        )
                                      : CircleAvatar(
                                          backgroundColor:
                                              borderColor?.withValues(alpha: 0.3) ?? vozacColor.withValues(alpha: 0.2),
                                          child: Text(
                                            putnik.dodeljenVozac?.isNotEmpty == true ? putnik.dodeljenVozac![0] : '?',
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${putnik.adresa ?? putnik.grad} • ${putnik.dodeljenVozac ?? "Nedodeljen"}',
                                        style: TextStyle(color: borderColor ?? vozacColor),
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
                                          backgroundColor: vozacColor.withValues(alpha: 0.2),
                                          child: Text(
                                            putnik.dodeljenVozac?.isNotEmpty == true ? putnik.dodeljenVozac![0] : '?',
                                            style: TextStyle(color: vozacColor, fontSize: 12),
                                          ),
                                        )
                                      : const Icon(Icons.swap_horiz),
                                  onTap: () {
                                    if (_isSelectionMode && putnik.id != null) {
                                      setState(() {
                                        if (_selectedPutnici.contains(putnik.id)) {
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
                                    if (!_isSelectionMode && putnik.id != null) {
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
          // 🎯 BOTTOM NAV BAR - identično kao HomeScreen (sa kapacitetom i praznicima)
          bottomNavigationBar: _buildBottomNavBar(),
          // 🎯 PERSISTENT BOTTOM SHEET za bulk akcije (kad je selection mode aktivan)
          persistentFooterButtons: _isSelectionMode && _selectedPutnici.isNotEmpty
              ? [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Vozači dugmići
                          ...VozacBoja.validDrivers.map((vozac) {
                            final color = VozacBoja.get(vozac);
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color.withValues(alpha: 0.2),
                                  foregroundColor: color,
                                ),
                                icon: Text(vozac[0], style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                                label: Text(vozac),
                                onPressed: () => _bulkPrebaci(vozac),
                              ),
                            );
                          }),
                          const SizedBox(width: 8),
                          // Obriši dugme
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withValues(alpha: 0.2),
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

  // 🎯 BULK PREBACIVANJE NA VOZAČA
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
              backgroundColor: VozacBoja.get(noviVozac),
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
        // 🆕 Koristi per-pravac per-vreme dodeljivanje
        await _putnikService.dodelPutnikaVozacuZaPravac(
          id,
          noviVozac,
          pravac,
          vreme: _selectedVreme, // 🆕 Prosleđivanje vremena
          selectedDan: dan,
        );
        uspesno++;
      } catch (e) {
        greska++;
      }
    }

    if (mounted) {
      setState(() {
        _isSelectionMode = false;
        _selectedPutnici.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Prebačeno $uspesno putnika na $noviVozac${greska > 0 ? " (greške: $greska)" : ""}'),
          backgroundColor: VozacBoja.get(noviVozac),
        ),
      );
    }
  }

  // 🗑️ BULK BRISANJE PUTNIKA
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

    for (final id in _selectedPutnici.toList()) {
      try {
        await _putnikService.otkaziPutnika(id, 'Admin',
            selectedVreme: _selectedVreme, selectedGrad: _selectedGrad, selectedDan: _selectedDay);
        uspesno++;
      } catch (e) {
        greska++;
      }
    }

    if (mounted) {
      setState(() {
        _isSelectionMode = false;
        _selectedPutnici.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ Obrisano $uspesno putnika${greska > 0 ? " (greške: $greska)" : ""}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 🎯 Helper metoda za kreiranje bottom nav bar-a (identično kao HomeScreen)
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
        );
      case 'letnji':
        return BottomNavBarLetnji(
          sviPolasci: _sviPolasci,
          selectedGrad: _selectedGrad,
          selectedVreme: _selectedVreme,
          getPutnikCount: _getPutnikCount,
          getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
          onPolazakChanged: _onPolazakChanged,
          selectedDan: _selectedDay,
        );
      default: // 'auto'
        return isZimski(now)
            ? BottomNavBarZimski(
                sviPolasci: _sviPolasci,
                selectedGrad: _selectedGrad,
                selectedVreme: _selectedVreme,
                getPutnikCount: _getPutnikCount,
                getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
                onPolazakChanged: _onPolazakChanged,
                selectedDan: _selectedDay,
              )
            : BottomNavBarLetnji(
                sviPolasci: _sviPolasci,
                selectedGrad: _selectedGrad,
                selectedVreme: _selectedVreme,
                getPutnikCount: _getPutnikCount,
                getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
                onPolazakChanged: _onPolazakChanged,
                selectedDan: _selectedDay,
              );
    }
  }
}
