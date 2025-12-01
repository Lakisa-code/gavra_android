import 'dart:async';

import 'package:flutter/material.dart';

import '../config/route_config.dart';
import '../models/putnik.dart';
import '../services/putnik_service.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/grad_adresa_validator.dart';
import '../utils/schedule_utils.dart';
import '../utils/vozac_boja.dart';
import '../widgets/bottom_nav_bar_letnji.dart';
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

  String _getDayAbbreviation(String fullDay) {
    const Map<String, String> dayMap = {
      'Ponedeljak': 'pon',
      'Utorak': 'uto',
      'Sreda': 'sre',
      'Četvrtak': 'cet',
      'Petak': 'pet',
    };
    return dayMap[fullDay] ?? 'pon';
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

        setState(() {
          _putnici = filtered;
          _isLoading = false;
        });
      }
    });
  }

  // 📊 Broj putnika za BottomNavBar
  int _getPutnikCount(String grad, String vreme) {
    final normalizedVreme = GradAdresaValidator.normalizeTime(vreme);
    return _allPutnici.where((p) {
      final vremeMatch = GradAdresaValidator.normalizeTime(p.polazak) == normalizedVreme;
      final gradMatch = p.grad.toLowerCase().contains(grad.toLowerCase().substring(0, 4));
      return vremeMatch && gradMatch;
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
              // Lista vozača
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
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != currentVozac && putnik.id != null) {
      try {
        await _putnikService.prebacijPutnikaVozacu(putnik.id!, selected);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${putnik.ime} prebačen na $selected'),
              backgroundColor: VozacBoja.get(selected),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dodeli Putnike'),
        centerTitle: true,
        elevation: 0,
        actions: [
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
          // 📊 INFO BAR - Dan dropdown i broj putnika
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                // 📅 Dan DROPDOWN
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDay,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                      dropdownColor: Theme.of(context).colorScheme.primary,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      items: _dani.map((dan) {
                        return DropdownMenuItem<String>(
                          value: dan,
                          child: Text(
                            dan.substring(0, 3).toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedDay = value);
                          _setupStream();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.people,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_putnici.length} putnika',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '$_selectedVreme - $_selectedGrad',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

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
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: vozacColor.withValues(alpha: 0.2),
                                child: Text(
                                  putnik.dodaoVozac?.isNotEmpty == true ? putnik.dodaoVozac![0] : '?',
                                  style: TextStyle(
                                    color: vozacColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                putnik.ime,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${putnik.adresa ?? putnik.grad} • ${putnik.dodaoVozac ?? "Nedodeljen"}',
                                style: TextStyle(color: vozacColor),
                              ),
                              trailing: const Icon(Icons.swap_horiz),
                              onTap: () => _showVozacPicker(putnik),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      // 🎯 BOTTOM NAV BAR - identično kao HomeScreen
      bottomNavigationBar: isZimski(DateTime.now())
          ? BottomNavBarZimski(
              sviPolasci: _sviPolasci,
              selectedGrad: _selectedGrad,
              selectedVreme: _selectedVreme,
              getPutnikCount: _getPutnikCount,
              onPolazakChanged: _onPolazakChanged,
            )
          : BottomNavBarLetnji(
              sviPolasci: _sviPolasci,
              selectedGrad: _selectedGrad,
              selectedVreme: _selectedVreme,
              getPutnikCount: _getPutnikCount,
              onPolazakChanged: _onPolazakChanged,
            ),
    );
  }
}
