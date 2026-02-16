import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/day_constants.dart';
import '../globals.dart';
import '../models/putnik.dart';
import '../services/admin_security_service.dart'; // 🛡️ ADMIN SECURITY
import '../services/app_settings_service.dart'; // ⚙️ NAV BAR SETTINGS
import '../services/firebase_service.dart';
import '../services/local_notification_service.dart';
import '../services/pin_zahtev_service.dart'; // 🔑 PIN ZAHTEVI
import '../services/putnik_service.dart'; // ⏪ VRAĆEN na stari servis zbog grešaka u novom
import '../services/realtime_notification_service.dart';
import '../services/statistika_service.dart'; // 📊 STATISTIKA
import '../services/theme_manager.dart';
import '../services/vozac_mapping_service.dart'; // 🗺️ VOZAC MAPIRANJE
import '../services/vozac_service.dart'; // 🛠️ VOZAC SERVIS
import '../theme.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/vozac_boja.dart';
import '../widgets/dug_button.dart';
import 'adrese_screen.dart'; // 🏘️ Upravljanje adresama
import 'auth_screen.dart'; // DODANO za auth admin
import 'dodeli_putnike_screen.dart'; // DODANO za raspodelu putnika vozacima
import 'dugovi_screen.dart';
import 'finansije_screen.dart'; // 💰 Finansijski izveštaj
import 'kapacitet_screen.dart'; // DODANO za kapacitet polazaka
import 'odrzavanje_screen.dart'; // 🚛 Kolska knjiga - vozila
import 'pin_zahtevi_screen.dart'; // 🔑 PIN ZAHTEVI
import 'registrovani_putnici_screen.dart';
import 'vozac_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String? _currentDriver;
  final PutnikService _putnikService = PutnikService(); // ⏪ VRAĆEN na stari servis zbog grešaka u novom

  // 🔑 PIN ZAHTEVI - broj zahteva koji čekaju
  int _brojPinZahteva = 0;
  // 🕒 TIMER MANAGEMENT - sada koristi TimerManager singleton umesto direktnog Timer-a

  //
  // Statistika pazara

  // Filter za dan - odmah postaviti na trenutni dan
  late String _selectedDan;

  @override
  void initState() {
    super.initState();
    final todayName = app_date_utils.DateUtils.getTodayFullName();
    // Admin screen supports all days now, including weekends
    _selectedDan = todayName;

    // 🗺️ FORSIRANA INICIJALIZACIJA VOZAC MAPIRANJA
    VozacMappingService.refreshMapping();

    _loadCurrentDriver();
    _loadBrojPinZahteva(); // 🔑 Učitaj broj PIN zahteva

    // Inicijalizuj heads-up i zvuk notifikacije
    try {
      LocalNotificationService.initialize(context);
      RealtimeNotificationService.listenForForegroundNotifications(context);
    } catch (e) {
      // Error handling - logging removed for production
    }

    FirebaseService.getCurrentDriver().then((driver) {
      if (driver != null && driver.isNotEmpty) {
        RealtimeNotificationService.initialize();
      }
    }).catchError((Object e) {
      // Error handling - logging removed for production
    });

    // Supabase realtime se koristi direktno
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize realtime service
      try {
        // Pokreni refresh da osiguramo podatke
        _putnikService.getAllPutnici().then((data) {
          // Successfully retrieved passenger data
        }).catchError((Object e) {
          // Error handling - logging removed for production
        });
      } catch (e) {
        // Error handling - logging removed for production
      }
    });
  }

  @override
  void dispose() {
    // AdminScreen disposed
    super.dispose();
  }

  /// 👤 VOZAČ PICKER DIALOG - Admin može da vidi ekran bilo kog vozača
  void _showVozacPickerDialog(BuildContext context) async {
    // Asinkrono učitaj vozače iz baze umesto fallback vrednosti
    try {
      final vozacService = VozacService();
      final vozaci = await vozacService.getAllVozaci();

      if (!mounted) return;

      if (vozaci.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Nema učitanih vozača')),
        );
        return;
      }

      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Izaberi vozaca'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: vozaci.length,
                itemBuilder: (context, index) {
                  final vozac = vozaci[index];
                  final boja = vozac.color ?? Color(0xFFBDBDBD); // Gray fallback
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: boja,
                      child: Text(
                        vozac.ime[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(vozac.ime),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => VozacScreen(previewAsDriver: vozac.ime),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Otkaži'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading drivers: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Greška pri učitavanju vozača')),
      );
    }
  }

  void _loadCurrentDriver() {
    FirebaseService.getCurrentDriver().then((driver) {
      if (mounted) {
        setState(() {
          _currentDriver = driver;
        });
      }
    }).catchError((Object e) {
      if (mounted) {
        setState(() {
          _currentDriver = null;
        });
      }
    });
  }

  // 🔑 Učitaj broj PIN zahteva koji čekaju
  Future<void> _loadBrojPinZahteva() async {
    try {
      final broj = await PinZahtevService.brojZahtevaKojiCekaju();
      if (mounted) {
        setState(() => _brojPinZahteva = broj);
      }
    } catch (e) {
      // Ignorišemo grešku, badge jednostavno neće prikazati broj
    }
  }

  // 📊 STATISTIKE MENI - otvara BottomSheet sa opcijama
  void _showStatistikeMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '📊 Statistike',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Text('💰', style: TextStyle(fontSize: 24)),
                  title: const Text('Finansije'),
                  subtitle: const Text('Prihodi, troškovi, neto zarada'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => const FinansijeScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Text('🚛', style: TextStyle(fontSize: 24)),
                  title: const Text('Kolska knjiga'),
                  subtitle: const Text('Servisi, registracija, gume...'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => const OdrzavanjeScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Mapiranje punih imena dana u skraćice za filtriranje
  String _getShortDayName(String fullDayName) {
    final dayMapping = {
      'ponedeljak': 'Pon',
      'utorak': 'Uto',
      'sreda': 'Sre',
      'četvrtak': 'Čet',
      'petak': 'Pet',
    };
    final key = fullDayName.trim().toLowerCase();
    return dayMapping[key] ?? (fullDayName.isNotEmpty ? fullDayName.trim() : 'Pon');
  }

  // Color _getVozacColor(String vozac) { ... } // unused

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: ThemeManager().currentGradient, // Theme-aware gradijent
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Transparentna pozadina
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(147),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).glassContainer, // Transparentni glassmorphism
              border: Border.all(
                color: Theme.of(context).glassBorder,
                width: 1.5,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
              // No boxShadow � keep AppBar fully transparent and only glass border
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    // ADMIN PANEL CONTAINER - levo
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 20,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'A D M I N   P A N E L',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    letterSpacing: 1.8,
                                    shadows: const [
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
                          const SizedBox(height: 4),
                          // DRUGI RED - Putnici, Adrese, NavBar, Dropdown (4 dugmeta)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth = constraints.maxWidth;
                              const spacing = 1.0;
                              const padding = 8.0;
                              final availableWidth = screenWidth - padding;
                              final buttonWidth = (availableWidth - (spacing * 3)) / 4; // 4 dugmeta

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // PUTNICI
                                  SizedBox(
                                    width: buttonWidth,
                                    child: InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (context) => const RegistrovaniPutniciScreen(),
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 28,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).glassContainer,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Theme.of(context).glassBorder, width: 1.5),
                                        ),
                                        child: const Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'Putnici',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Colors.white,
                                                shadows: [
                                                  Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // ADRESE
                                  SizedBox(
                                    width: buttonWidth,
                                    child: InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (context) => const AdreseScreen(),
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 28,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).glassContainer,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Theme.of(context).glassBorder, width: 1.5),
                                        ),
                                        child: const Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'Adrese',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Colors.white,
                                                shadows: [
                                                  Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // NAV BAR DROPDOWN
                                  SizedBox(
                                    width: buttonWidth,
                                    child: ValueListenableBuilder<String>(
                                      valueListenable: navBarTypeNotifier,
                                      builder: (context, navType, _) {
                                        return Container(
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).glassContainer,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Theme.of(context).glassBorder, width: 1.5),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: navType,
                                              isExpanded: true,
                                              icon: const SizedBox.shrink(),
                                              dropdownColor: Theme.of(context).colorScheme.primary,
                                              style: const TextStyle(color: Colors.white, fontSize: 11),
                                              selectedItemBuilder: (context) {
                                                return ['zimski', 'letnji', 'praznici'].map((t) {
                                                  String label;
                                                  bool useEmoji = false;
                                                  switch (t) {
                                                    case 'zimski':
                                                      label = '❄️';
                                                      useEmoji = true;
                                                      break;
                                                    case 'letnji':
                                                      label = '☀️';
                                                      useEmoji = true;
                                                      break;
                                                    case 'praznici':
                                                      label = '🎄';
                                                      useEmoji = true;
                                                      break;
                                                    default:
                                                      label = t;
                                                  }
                                                  return Center(
                                                    child: Text(label,
                                                        style: TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: useEmoji ? 14 : 11,
                                                            color: Colors.white)),
                                                  );
                                                }).toList();
                                              },
                                              items: const [
                                                DropdownMenuItem(value: 'zimski', child: Center(child: Text('Zimski'))),
                                                DropdownMenuItem(value: 'letnji', child: Center(child: Text('Letnji'))),
                                                DropdownMenuItem(
                                                    value: 'praznici', child: Center(child: Text('Praznici'))),
                                              ],
                                              onChanged: (value) {
                                                if (value != null) AppSettingsService.setNavBarType(value);
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                                  // DROPDOWN DANA
                                  SizedBox(
                                    width: buttonWidth,
                                    child: Container(
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).glassContainer,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Theme.of(context).glassBorder, width: 1.5),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedDan,
                                          isExpanded: true,
                                          icon: const SizedBox.shrink(),
                                          dropdownColor: Theme.of(context).colorScheme.primary,
                                          style: const TextStyle(color: Colors.white),
                                          selectedItemBuilder: (context) {
                                            return DayConstants.dayNamesInternal.map((d) {
                                              return Center(
                                                  child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Text(d,
                                                          style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w600))));
                                            }).toList();
                                          },
                                          items: DayConstants.dayNamesInternal.map((dan) {
                                            return DropdownMenuItem(
                                                value: dan,
                                                child: Center(
                                                    child: Text(dan,
                                                        style: const TextStyle(
                                                            fontSize: 14, fontWeight: FontWeight.w600))));
                                          }).toList(),
                                          onChanged: (value) {
                                            if (value != null && mounted) setState(() => _selectedDan = value);
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          // TRECI RED - Auth, PIN, Statistike, Dodeli (4 dugmeta)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth = constraints.maxWidth;
                              const spacing = 1.0;
                              const padding = 8.0;
                              final availableWidth = screenWidth - padding;
                              final buttonWidth = (availableWidth - (spacing * 3)) / 4; // 4 dugmeta

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // AUTH
                                  SizedBox(
                                    width: buttonWidth,
                                    child: InkWell(
                                      onTap: () => Navigator.push(
                                          context, MaterialPageRoute<void>(builder: (context) => const AuthScreen())),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 28,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).glassContainer,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Theme.of(context).glassBorder, width: 1.5),
                                        ),
                                        child: const Center(
                                            child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text('Auth',
                                                    style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                        color: Colors.white,
                                                        shadows: [
                                                          Shadow(
                                                              offset: Offset(1, 1),
                                                              blurRadius: 3,
                                                              color: Colors.black54)
                                                        ])))),
                                      ),
                                    ),
                                  ),

                                  // PIN
                                  SizedBox(
                                    width: buttonWidth,
                                    child: InkWell(
                                      onTap: () async {
                                        await Navigator.push(context,
                                            MaterialPageRoute<void>(builder: (context) => const PinZahteviScreen()));
                                        _loadBrojPinZahteva();
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            height: 28,
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).glassContainer,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: _brojPinZahteva > 0
                                                      ? Colors.orange
                                                      : Theme.of(context).glassBorder,
                                                  width: 1.5),
                                            ),
                                            child: const Center(
                                                child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text('PIN',
                                                        style: TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 14,
                                                            color: Colors.white,
                                                            shadows: [
                                                              Shadow(
                                                                  offset: Offset(1, 1),
                                                                  blurRadius: 3,
                                                                  color: Colors.black54)
                                                            ])))),
                                          ),
                                          if (_brojPinZahteva > 0)
                                            Positioned(
                                              right: -4,
                                              top: -4,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration:
                                                    const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                                child: Text('$_brojPinZahteva',
                                                    style: const TextStyle(
                                                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                    textAlign: TextAlign.center),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // STATISTIKE (otvara meni sa opcijama)
                                  SizedBox(
                                    width: buttonWidth,
                                    child: InkWell(
                                      onTap: () => _showStatistikeMenu(context),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 28,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).glassContainer,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Theme.of(context).glassBorder, width: 1.5),
                                        ),
                                        child: const Center(
                                            child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text('📊', style: TextStyle(fontSize: 14)))),
                                      ),
                                    ),
                                  ),

                                  // DODELI
                                  SizedBox(
                                    width: buttonWidth,
                                    child: InkWell(
                                      onTap: () => Navigator.push(context,
                                          MaterialPageRoute<void>(builder: (context) => const DodeliPutnikeScreen())),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 28,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).glassContainer,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Theme.of(context).glassBorder, width: 1.5),
                                        ),
                                        child: const Center(
                                            child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text('Dodeli',
                                                    style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                        color: Colors.white,
                                                        shadows: [
                                                          Shadow(
                                                              offset: Offset(1, 1),
                                                              blurRadius: 3,
                                                              color: Colors.black54)
                                                        ])))),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          // TRECI RED - Vozac, Monitor, Mesta (3 dugmeta)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth = constraints.maxWidth;
                              const spacing = 4.0; // Increased spacing safety
                              const padding = 12.0; // Increased padding safety
                              final availableWidth = screenWidth - padding;
                              final buttonWidth = (availableWidth - (spacing * 2)) / 3;

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  // VOZAC - Dropdown za admin preview
                                  SizedBox(
                                    width: buttonWidth,
                                    child: InkWell(
                                      onTap: () => _showVozacPickerDialog(context),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 28,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).glassContainer,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Theme.of(context).glassBorder, width: 1.5),
                                        ),
                                        child: Center(
                                            child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: const Text('Vozač',
                                                    style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                        color: Colors.white,
                                                        shadows: [
                                                          Shadow(
                                                              offset: Offset(1, 1),
                                                              blurRadius: 3,
                                                              color: Colors.black54)
                                                        ])))),
                                      ),
                                    ),
                                  ),

                                  // MESTA
                                  SizedBox(
                                    width: buttonWidth,
                                    child: InkWell(
                                      onTap: () => Navigator.push(context,
                                          MaterialPageRoute<void>(builder: (context) => const KapacitetScreen())),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 28,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).glassContainer,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Theme.of(context).glassBorder, width: 1.5),
                                        ),
                                        child: const Center(
                                            child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text('Mesta',
                                                    style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                        color: Colors.white,
                                                        shadows: [
                                                          Shadow(
                                                              offset: Offset(1, 1),
                                                              blurRadius: 3,
                                                              color: Colors.black54)
                                                        ])))),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // NETWORK STATUS - desno
                    const SizedBox(width: 8),
                    const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: StreamBuilder<List<Putnik>>(
          stream: _putnikService.streamPutnici(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Loading state - add refresh option to prevent infinite loading
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Učitavanje admin panela...'),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              // Error handling - logging removed for production
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    Text('Greška: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (mounted) setState(() {}); // Pokušaj ponovo
                      },
                      child: const Text('Pokušaj ponovo'),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final allPutnici = snapshot.data!;
            final filteredPutnici = allPutnici.where((putnik) {
              // 🕒 FILTER PO DANU - Samo po danu nedelje
              // Filtriraj po odabranom danu
              final shortDayName = _getShortDayName(_selectedDan);
              return putnik.dan == shortDayName;
            }).toList();
            // 💰 DUŽNICI - putnici sa PLAVOM KARTICOM (nisu mesecni tip) koji nisu platili
            final filteredDuznici = filteredPutnici.where((putnik) {
              final nijeMesecni = !putnik.isMesecniTip;
              if (!nijeMesecni) return false; // ✅ FIX: Plava kartica = nije mesecni tip

              final nijePlatio = putnik.vremePlacanja == null; // ✅ FIX: Nije platio ako nema vremePlacanja
              final nijeOtkazan = putnik.status != 'otkazan' && putnik.status != 'Otkazano';
              final pokupljen = putnik.jePokupljen;

              // ✅ NOVA LOGIKA: SVI (admin i vozači) vide SVE dužnike
              // Omogućava vozačima da naplate dugove drugih vozača
              // Uklonjeno AdminSecurityService.canViewDriverData filtriranje

              return nijePlatio && nijeOtkazan && pokupljen;
            }).toList();

            // Izračunaj pazar po vozačima - KORISTI DIREKTNO filteredPutnici UMESTO DATUMA 🕒
            // ✅ ISPRAVKA: Umesto kalkulacije datuma, koristi već filtrirane putnike po danu
            // Ovo omogućava prikaz pazara za odabrani dan (Pon, Uto, itd.) direktno

            // 🕒 KALKULIRAJ DATUM NA OSNOVU DROPDOWN SELEKCIJE

            // Odabran je specifičan dan, pronađi taj dan u trenutnoj nedelji
            final now = DateTime.now();
            final currentWeekday = now.weekday; // 1=Pon, 2=Uto, 3=Sre, 4=Čet, 5=Pet

            // ✅ KORISTI CENTRALNU FUNKCIJU IZ DateUtils
            final targetWeekday = app_date_utils.DateUtils.getDayWeekdayNumber(_selectedDan);

            // 🕒 USKLADI SA DANAS SCREEN: Ako je odabrani dan isti kao danas, koristi današnji datum
            final DateTime targetDate;
            if (targetWeekday == currentWeekday) {
              // Isti dan kao danas - koristi današnji datum (kao danas screen)
              targetDate = now;
            } else {
              // Standardna logika za ostale dane
              final daysFromToday = targetWeekday - currentWeekday;
              targetDate = now.add(Duration(days: daysFromToday));
            }

            final streamFrom = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
            final streamTo = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

            // 🛰️ KORISTI StatistikaService.streamPazarZaSveVozace() - BEZ RxDart
            return StreamBuilder<Map<String, double>>(
              stream: StatistikaService.streamPazarZaSveVozace(from: streamFrom, to: streamTo),
              builder: (context, pazarSnapshot) {
                if (!pazarSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final pazarMap = pazarSnapshot.data!;

                // ✅ IDENTIČNA LOGIKA SA DANAS SCREEN: uzmi direktno vrednost iz mape
                final ukupno = pazarMap['_ukupno'] ?? 0.0;

                // Ukloni '_ukupno' ključ za čist prikaz
                final Map<String, double> pazar = Map.from(pazarMap)..remove('_ukupno');

                // 👤 FILTER PO VOZAČU - Prikaži samo naplate trenutnog vozača ili sve za admin
                // 🛡️ KORISTI ADMIN SECURITY SERVICE za filtriranje privilegija
                if (_currentDriver == null) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('⏳ Učitavanje...'),
                    ),
                  );
                }

                final bool isAdmin = AdminSecurityService.isAdmin(_currentDriver!);
                final Map<String, double> filteredPazar = AdminSecurityService.filterPazarByPrivileges(
                  _currentDriver!,
                  pazar,
                );

                final Map<String, Color> vozacBoje = VozacBoja.bojeSync;
                final List<String> vozaciRedosled = [
                  'Bruda',
                  'Bilevski',
                  'Bojan',
                  'Voja',
                ];

                // Filter vozace redosled na osnovu trenutnog vozaca
                // ?? KORISTI ADMIN SECURITY SERVICE za filtriranje vozaca
                final List<String> prikazaniVozaci = AdminSecurityService.getVisibleDrivers(
                  _currentDriver!,
                  vozaciRedosled,
                );
                return SingleChildScrollView(
                  // ensure we respect device safe area / system nav bar at the
                  // bottom � some devices (Samsung) have a system bar which can
                  // cause a tiny overflow (2px on some screens). Add extra
                  // bottom padding based on MediaQuery so the content can scroll
                  // clear of system UI on all devices.
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 12),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom + 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        //  Info box za individualnog vozaca
                        if (!isAdmin)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: Colors.green[600],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Prikazuju se samo VAŠE naplate, vozač: $_currentDriver',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        // 💰 VOZAČI PAZAR (BEZ DEPOZITA)
                        Column(
                          children: prikazaniVozaci
                              .map(
                                (vozac) => Container(
                                  width: double.infinity,
                                  height: 60,
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (vozacBoje[vozac] ?? Colors.blueGrey).withAlpha(
                                      60,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: (vozacBoje[vozac] ?? Colors.blueGrey).withAlpha(
                                        120,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: vozacBoje[vozac] ?? Colors.blueGrey,
                                        radius: 16,
                                        child: Text(
                                          vozac[0],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          vozac,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: vozacBoje[vozac] ?? Colors.blueGrey,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.monetization_on,
                                            color: vozacBoje[vozac] ?? Colors.blueGrey,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${(filteredPazar[vozac] ?? 0.0).toStringAsFixed(0)} RSD',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: vozacBoje[vozac] ?? Colors.blueGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        DugButton(
                          brojDuznika: filteredDuznici.length,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (context) => DugoviScreen(
                                  // duznici: filteredDuznici,
                                  currentDriver: _currentDriver!,
                                ),
                              ),
                            );
                          },
                          wide: true,
                        ),
                        const SizedBox(height: 4),
                        // UKUPAN PAZAR
                        Container(
                          width: double.infinity,
                          // increased slightly to provide safe headroom across
                          // devices (prevent tiny 1�3px overflows caused by
                          // font metrics / shadows on some phones)
                          height: 76,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2), // Glassmorphism
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).glassBorder, // Transparentni border
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet,
                                color: Colors.green[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isAdmin ? 'UKUPAN PAZAR' : 'MOJ UKUPAN PAZAR',
                                    style: TextStyle(
                                      color: Colors.green[800],
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  // ?? UKUPAN PAZAR (BEZ DEPOZITA)
                                  Text(
                                    '${(isAdmin ? ukupno : filteredPazar.values.fold(0.0, (sum, val) => sum + val)).toStringAsFixed(0)} RSD',
                                    style: TextStyle(
                                      color: Colors.green[900],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // 📲 SMS TEST DUGME - samo za Bojan
                        if (_currentDriver?.toLowerCase() == 'bojan') ...[
                          // SMS test i debug funkcionalnost uklonjena - servis radi u pozadini
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ), // Zatvaranje Scaffold
    ); // Zatvaranje Container
  }

  // String _getTodayName() { ... } // unused

  // (Funkcija za dijalog sa du�nicima je uklonjena - sada se koristi DugoviScreen)
}
