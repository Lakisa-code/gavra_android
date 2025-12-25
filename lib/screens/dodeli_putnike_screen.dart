import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/route_config.dart';
import '../globals.dart';
import '../models/putnik.dart';
import '../services/kapacitet_service.dart';
import '../services/putnik_service.dart';
import '../services/theme_manager.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/grad_adresa_validator.dart';
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

  // 🕐 Koristi RouteConfig za vremena
  List<String> get bcVremena => isZimski(DateTime.now()) ? RouteConfig.bcVremenaZimski : RouteConfig.bcVremenaLetnji;

  List<String> get vsVremena => isZimski(DateTime.now()) ? RouteConfig.vsVremenaZimski : RouteConfig.vsVremenaLetnji;

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
    return app_date_utils.DateUtils.getTodayFullName();
  }

  // ✅ KORISTI CENTRALNU FUNKCIJU IZ DateUtils
  String _getDayAbbreviation(String fullDay) {
    return app_date_utils.DateUtils.getDayAbbreviation(fullDay);
  }

  // Konvertuj ime dana u ISO datum (identično kao HomeScreen)
  String _getIsoDateForDay(String fullDay) {
    final now = DateTime.now();

    final dayNamesMap = {
      'Ponedeljak': 0,
      'ponedeljak': 0,
      'Utorak': 1,
      'utorak': 1,
      'Sreda': 2,
      'sreda': 2,
      'Četvrtak': 3,
      'četvrtak': 3,
      'Petak': 4,
      'petak': 4,
      'Subota': 5,
      'subota': 5,
      'Nedelja': 6,
      'nedelja': 6,
    };

    int? targetDayIndex = dayNamesMap[fullDay];
    if (targetDayIndex == null) return now.toIso8601String().split('T')[0];

    final currentDayIndex = now.weekday - 1;

    if (targetDayIndex == currentDayIndex) {
      return now.toIso8601String().split('T')[0];
    }

    int daysToAdd = targetDayIndex - currentDayIndex;
    if (daysToAdd < 0) {
      daysToAdd += 7;
    }

    final targetDate = now.add(Duration(days: daysToAdd));
    return targetDate.toIso8601String().split('T')[0];
  }

  void _setupStream() {
    _putnikSubscription?.cancel();

    final isoDate = _getIsoDateForDay(_selectedDay);
    final normalizedVreme = GradAdresaValidator.normalizeTime(_selectedVreme);

    setState(() => _isLoading = true);

    // Stream bez filtera za vreme/grad - da imamo sve putnike za count
    _putnikSubscription = _putnikService
        .streamKombinovaniPutniciFiltered(
      isoDate: isoDate,
    )
        .listen((putnici) {
      if (mounted) {
        final danAbbrev = _getDayAbbreviation(_selectedDay);

        // Sačuvaj sve putnike za dan (za BottomNavBar count)
        _allPutnici = putnici.where((p) {
          return p.dan.toLowerCase() == danAbbrev.toLowerCase();
        }).toList();

        // Filtriraj za prikaz po vremenu i gradu
        final filtered = _allPutnici.where((p) {
          final vremeMatch = GradAdresaValidator.normalizeTime(p.polazak) == normalizedVreme;
          final gradMatch = p.grad.toLowerCase().contains(_selectedGrad.toLowerCase().substring(0, 4));
          return vremeMatch && gradMatch;
        }).toList();

        // 🔢 Sortiraj: aktivni prvi, odsustvo/otkazani na dno
        filtered.sort((a, b) {
          final aInactive = a.jeOdsustvo || a.jeOtkazan;
          final bInactive = b.jeOdsustvo || b.jeOtkazan;
          if (aInactive && !bInactive) return 1; // a ide dole
          if (!aInactive && bInactive) return -1; // b ide dole
          return 0; // isti status, zadrži redosled
        });

        setState(() {
          _putnici = filtered;
          _isLoading = false;
        });
      }
    });
  }

  // 📊 Broj putnika za BottomNavBar (ne računa odsustvo/otkazane)
  int _getPutnikCount(String grad, String vreme) {
    final normalizedVreme = GradAdresaValidator.normalizeTime(vreme);
    return _allPutnici.where((p) {
      final vremeMatch = GradAdresaValidator.normalizeTime(p.polazak) == normalizedVreme;
      final gradMatch = p.grad.toLowerCase().contains(grad.toLowerCase().substring(0, 4));
      final isActive = !p.jeOdsustvo && !p.jeOtkazan;
      return vremeMatch && gradMatch && isActive;
    }).length;
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

  Future<void> _showVozacPicker(Putnik putnik) async {
    final vozaci = VozacBoja.validDrivers;
    final currentVozac = putnik.dodaoVozac ?? 'Nepoznat';

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
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
                            'Trenutni vozač: $currentVozac',
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
                        trailing: currentVozac == 'Nepoznat' || currentVozac == 'Nedodeljen'
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
        );
      },
    );

    if (selected != null && selected != currentVozac && putnik.id != null) {
      try {
        // ➖ Ako je izabrano "Bez vozača", postavi null
        final noviVozac = selected == '_NONE_' ? null : selected;
        await _putnikService.prebacijPutnikaVozacu(putnik.id!, noviVozac);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  noviVozac == null ? '✅ ${putnik.ime} uklonjen sa vozača' : '✅ ${putnik.ime} prebačen na $noviVozac'),
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
            title: Text(_isSelectionMode ? '${_selectedPutnici.length} selektovano' : 'Dodeli Putnike'),
            centerTitle: true,
            elevation: 0,
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
                              final vozacColor = VozacBoja.getColorOrDefault(putnik.dodaoVozac, Colors.grey);
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
                                            putnik.dodaoVozac?.isNotEmpty == true ? putnik.dodaoVozac![0] : '?',
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
                                        '${putnik.adresa ?? putnik.grad} • ${putnik.dodaoVozac ?? "Nedodeljen"}',
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
                                            putnik.dodaoVozac?.isNotEmpty == true ? putnik.dodaoVozac![0] : '?',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Prebaci na $noviVozac?'),
        content: Text('Da li želiš da prebaciš $count putnika na vozača $noviVozac?'),
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

    for (final id in _selectedPutnici.toList()) {
      try {
        await _putnikService.prebacijPutnikaVozacu(id, noviVozac);
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
        );
      case 'zimski':
        return BottomNavBarZimski(
          sviPolasci: _sviPolasci,
          selectedGrad: _selectedGrad,
          selectedVreme: _selectedVreme,
          getPutnikCount: _getPutnikCount,
          getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
          onPolazakChanged: _onPolazakChanged,
        );
      case 'letnji':
        return BottomNavBarLetnji(
          sviPolasci: _sviPolasci,
          selectedGrad: _selectedGrad,
          selectedVreme: _selectedVreme,
          getPutnikCount: _getPutnikCount,
          getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
          onPolazakChanged: _onPolazakChanged,
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
              )
            : BottomNavBarLetnji(
                sviPolasci: _sviPolasci,
                selectedGrad: _selectedGrad,
                selectedVreme: _selectedVreme,
                getPutnikCount: _getPutnikCount,
                getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
                onPolazakChanged: _onPolazakChanged,
              );
    }
  }
}
