import 'package:flutter/material.dart';

import '../models/putnik.dart';
import '../services/admin_security_service.dart'; // 🔐 ADMIN SECURITY
import '../services/firebase_service.dart';
import '../services/local_notification_service.dart';
import '../services/optimized_kusur_service.dart'; // 🔥 ZAMENЈENO: kusur stream umesto MasterRealtimeStream
import '../services/putnik_service.dart'; // ⏪ VRAĆEN na stari servis zbog grešaka u novom
import '../services/realtime_notification_service.dart';
import '../services/realtime_service.dart';
import '../services/statistika_service.dart'; // DODANO za jedinstvenu logiku pazara
import '../services/theme_manager.dart';
import '../services/timer_manager.dart'; // 🕐 TIMER MANAGEMENT
import '../services/vozac_mapping_service.dart'; // 🔧 VOZAC MAPIRANJE
import '../theme.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/vozac_boja.dart';
import '../widgets/dug_button.dart';
import 'admin_map_screen.dart'; // OpenStreetMap verzija
import 'auth_screen.dart'; // DODANO za auth admin
import 'dodeli_putnike_screen.dart'; // DODANO za raspodelu putnika vozačima
import 'dugovi_screen.dart';
import 'geocoding_admin_screen.dart'; // DODANO za geocoding admin
import 'kapacitet_screen.dart'; // DODANO za kapacitet polazaka
import 'registrovani_putnici_screen.dart'; // DODANO za mesečne putnike
import 'monitoring_ekran.dart'; // 📊 MONITORING
import 'putovanja_istorija_screen.dart'; // DODANO za istoriju putovanja
import 'statistika_detail_screen.dart'; // DODANO za statistike
import 'vozac_screen.dart'; // DODANO za vozac screen

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String? _currentDriver;
  final PutnikService _putnikService = PutnikService(); // ⏪ VRAĆEN na stari servis zbog grešaka u novom

  // 🔄 REALTIME MONITORING STATE
  late ValueNotifier<bool> _isRealtimeHealthy;
  late ValueNotifier<bool> _kusurStreamHealthy;
  late ValueNotifier<bool> _putnikDataHealthy;
  // 🕐 TIMER MANAGEMENT - sada koristi TimerManager singleton umesto direktnog Timer-a

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

    // � FORSIRANA INICIJALIZACIJA VOZAC MAPIRANJA
    VozacMappingService.refreshMapping();

    // �🔄 INITIALIZE REALTIME MONITORING
    _isRealtimeHealthy = ValueNotifier(true);
    _kusurStreamHealthy = ValueNotifier(true);
    _putnikDataHealthy = ValueNotifier(true);

    _loadCurrentDriver();
    _setupRealtimeMonitoring();

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

    // Osiguraj da je RealtimeService pokrenut
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize realtime service
      try {
        // Forsiraj refresh RealtimeService
        await RealtimeService.instance.refreshNow();
        // RealtimeService refresh completed

        // Pokreni refresh da osiguramo podatke
        _putnikService.getAllPutniciFromBothTables().then((data) {
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
    // 🧹 CLEANUP REALTIME MONITORING sa TimerManager
    TimerManager.cancelTimer('admin_screen_health_check');

    // 🧹 SAFE DISPOSAL ValueNotifier-a
    try {
      if (mounted) {
        _isRealtimeHealthy.dispose();
        _kusurStreamHealthy.dispose();
        _putnikDataHealthy.dispose();
      }
    } catch (e) {
      // Error handling - logging removed for production
    }

    // AdminScreen disposed realtime monitoring resources safely
    super.dispose();
  }

  void _loadCurrentDriver() async {
    try {
      final driver = await FirebaseService.getCurrentDriver().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          return null;
        },
      );
      if (mounted) {
        setState(() {
          _currentDriver = driver;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentDriver = null;
        });
      }
    }
  }

  // 🔄 REALTIME MONITORING SETUP
  void _setupRealtimeMonitoring() {
    // Setting up realtime monitoring

    // 🕐 KORISTI TIMER MANAGER za health check - SPREČAVA MEMORY LEAK
    TimerManager.cancelTimer('admin_screen_health_check');
    TimerManager.createTimer(
      'admin_screen_health_check',
      const Duration(seconds: 30),
      _checkStreamHealth,
      isPeriodic: true,
    );

    // AdminScreen: Realtime monitoring active
  }

  // 🩺 STREAM HEALTH CHECK
  void _checkStreamHealth() {
    try {
      // Check if realtime services are responding
      final healthCheck = true; // RealtimeService.isConnected() - simplified for now
      _isRealtimeHealthy.value = healthCheck;

      // Check specific stream health (will be updated by StreamBuilders)
      // Kusur streams health is managed by individual StreamBuilders
      // Putnik data health check
      _putnikDataHealthy.value = true; // Assume healthy unless FutureBuilder reports error

      // Health check completed

      // 🚨 COMPREHENSIVE HEALTH REPORT
      final overallHealth = _isRealtimeHealthy.value && _kusurStreamHealthy.value && _putnikDataHealthy.value;

      if (!overallHealth) {
        // AdminScreen health issues detected
        // Implementation removed for production
      }
    } catch (e) {
      // Error handling - logging removed for production
      _isRealtimeHealthy.value = false;
      _kusurStreamHealthy.value = false;
      _putnikDataHealthy.value = false;
    }
  }

  // Mapiranje punih imena dana u skraćenice za filtriranje
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
          preferredSize: const Size.fromHeight(115),
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
              // No boxShadow — keep AppBar fully transparent and only glass border
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
                          // PRVI RED - Admin Panel sa Heartbeat
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
                          // DRUGI RED - Admin ikone
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth = constraints.maxWidth;
                              const spacing = 1.0; // Minimal spacing
                              const padding = 8.0; // Safety padding
                              final availableWidth = screenWidth - padding;
                              final buttonWidth = (availableWidth - (spacing * 4)) / 5; // 5 buttons with 4 spaces

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // MESEČNI PUTNICI - levo
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).glassContainer,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Theme.of(context).glassBorder,
                                            width: 1.5,
                                          ),
                                          // no boxShadow — keep transparent glass + border only
                                        ),
                                        child: const Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Putnici',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: Colors.white,
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
                                        ),
                                      ),
                                    ),
                                  ),

                                  // STATISTIKE - desno-sredina
                                  SizedBox(
                                    width: buttonWidth,
                                    child: InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (context) => const StatistikaDetailScreen(),
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 28,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).glassContainer,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Theme.of(context).glassBorder,
                                            width: 1.5,
                                          ),
                                          // no boxShadow — keep transparent glass + border only
                                        ),
                                        child: const Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Statistike',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: Colors.white,
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
                                        ),
                                      ),
                                    ),
                                  ),

                                  // GEOCODING ADMIN - novo
                                  SizedBox(
                                    width: buttonWidth,
                                    child: InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (context) => const GeocodingAdminScreen(),
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 28,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).glassContainer,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Theme.of(context).glassBorder,
                                            width: 1.5,
                                          ),
                                          // no boxShadow — keep transparent glass + border only
                                        ),
                                        child: const Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'API',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: Colors.white,
                                                    letterSpacing: 0.3,
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
                                        ),
                                      ),
                                    ),
                                  ),

                                  // ISTORIJA DUGME - četvrto
                                  SizedBox(
                                    width: buttonWidth,
                                    child: InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (context) => const PutovanjaIstorijaScreen(),
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 28,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).glassContainer,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Theme.of(context).glassBorder,
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Istorija',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: Colors.white,
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
                                        ),
                                      ),
                                    ),
                                  ),

                                  // DROPDOWN - desno
                                  SizedBox(
                                    width: buttonWidth,
                                    child: Container(
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).glassContainer,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Theme.of(context).glassBorder,
                                          width: 1.5,
                                        ),
                                        // no boxShadow — keep transparent glass + border only
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedDan,
                                          isExpanded: true,
                                          hint: const Center(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Icon(
                                                Icons.calendar_today,
                                                color: Colors.white,
                                                size: 12,
                                              ),
                                            ),
                                          ),
                                          selectedItemBuilder: (BuildContext context) {
                                            return [
                                              'Ponedeljak',
                                              'Utorak',
                                              'Sreda',
                                              'Četvrtak',
                                              'Petak',
                                              'Subota',
                                              'Nedelja',
                                            ].map<Widget>((String value) {
                                              return Center(
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Flexible(
                                                      child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        child: Text(
                                                          value,
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                      ),
                                                    ),
                                                    // arrow removed — selected item displays only text
                                                  ],
                                                ),
                                              );
                                            }).toList();
                                          },
                                          icon: const SizedBox.shrink(),
                                          dropdownColor: Theme.of(context).colorScheme.primary,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          items: [
                                            'Ponedeljak',
                                            'Utorak',
                                            'Sreda',
                                            'Četvrtak',
                                            'Petak',
                                            'Subota',
                                            'Nedelja',
                                          ].map((dan) {
                                            return DropdownMenuItem<String>(
                                              value: dan,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                child: Center(
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      dan,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            if (value != null) {
                                              if (mounted) {
                                                setState(() {
                                                  _selectedDan = value;
                                                });
                                              }
                                            }
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
                          // TREĆI RED - Auth i Vozač dugmad (dinamička širina kao gornji red)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth = constraints.maxWidth;
                              const spacing = 1.0;
                              const padding = 8.0;
                              final availableWidth = screenWidth - padding;
                              // Broj dugmadi zavisi od korisnika
                              final buttonCount = (_currentDriver == 'Bojan' || _currentDriver == 'Svetlana') ? 5 : 2;
                              final buttonWidth = (availableWidth - (spacing * (buttonCount - 1))) / buttonCount;

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // AUTH dugme
                                  SizedBox(
                                    width: buttonWidth,
                                    child: InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (context) => const AuthScreen(),
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 28,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).glassContainer,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Theme.of(context).glassBorder,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: const Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'Auth',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Colors.white,
                                                shadows: [
                                                  Shadow(
                                                    offset: Offset(1, 1),
                                                    blurRadius: 3,
                                                    color: Colors.black54,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // VOZAČ dugme
                                  SizedBox(
                                    width: buttonWidth,
                                    child: InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (context) => const VozacScreen(),
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 28,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).glassContainer,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Theme.of(context).glassBorder,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: const Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'Vozač',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Colors.white,
                                                shadows: [
                                                  Shadow(
                                                    offset: Offset(1, 1),
                                                    blurRadius: 3,
                                                    color: Colors.black54,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 🎯 DUGME DODELI - samo za Bojan i Svetlana
                                  if (_currentDriver == 'Bojan' || _currentDriver == 'Svetlana')
                                    SizedBox(
                                      width: buttonWidth,
                                      child: InkWell(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (context) => const DodeliPutnikeScreen(),
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          height: 28,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).glassContainer,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Theme.of(context).glassBorder,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: const Center(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                'Dodeli',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: Colors.white,
                                                  shadows: [
                                                    Shadow(
                                                      offset: Offset(1, 1),
                                                      blurRadius: 3,
                                                      color: Colors.black54,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                  // 🎫 DUGME KAPACITET - podešavanje kapaciteta polazaka
                                  if (_currentDriver == 'Bojan' || _currentDriver == 'Svetlana')
                                    SizedBox(
                                      width: buttonWidth,
                                      child: InkWell(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (context) => const KapacitetScreen(),
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          height: 28,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).glassContainer,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Theme.of(context).glassBorder,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: const Center(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                'Kapacit',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: Colors.white,
                                                  shadows: [
                                                    Shadow(
                                                      offset: Offset(1, 1),
                                                      blurRadius: 3,
                                                      color: Colors.black54,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
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
        body: FutureBuilder<List<Putnik>>(
          future: _putnikService.getAllPutniciFromBothTables().timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              // Timeout handling - logging removed for production
              return <Putnik>[];
            },
          ),
          builder: (context, snapshot) {
            // 🩺 UPDATE PUTNIK DATA HEALTH STATUS
            if (snapshot.hasError) {
              _putnikDataHealthy.value = false;
            } else if (snapshot.hasData) {
              _putnikDataHealthy.value = true;
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              // Loading state - logging removed for production
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
              // 🗓️ FILTER PO DANU - Samo po danu nedelje
              // Filtriraj po odabranom danu
              final shortDayName = _getShortDayName(_selectedDan);
              return putnik.dan == shortDayName;
            }).toList();
            // ✅ DUŽNICI - SAMO DNEVNI PUTNICI koji nisu platili
            final filteredDuznici = filteredPutnici.where((putnik) {
              final jesteRegistrovani = putnik.mesecnaKarta == true;
              if (jesteRegistrovani) return false; // ✅ ISKLJUČI mesečne putnike

              final nijePlatio = (putnik.iznosPlacanja == null || putnik.iznosPlacanja == 0);
              final nijeOtkazan = putnik.status != 'otkazan' && putnik.status != 'Otkazano';
              final pokupljen = putnik.jePokupljen;

              // ✅ NOVA LOGIKA: SVI (admin i vozači) vide SVE dužnike
              // Omogućava vozačima da naplate dugove drugih vozača
              // Uklonjeno AdminSecurityService.canViewDriverData filtriranje

              return nijePlatio && nijeOtkazan && pokupljen;
            }).toList();

            // Izračunaj pazar po vozačima - KORISTI DIREKTNO filteredPutnici UMESTO DATUMA 💰
            // ✅ ISPRAVKA: Umesto kalkulacije datuma, koristi već filtrirane putnike po danu
            // Ovo omogućava prikaz pazara za odabrani dan (Pon, Uto, itd.) direktno

            // 📅 KALKULIRAJ DATUM NA OSNOVU DROPDOWN SELEKCIJE
            final DateTime streamFrom, streamTo;

            // Odabran je specifičan dan, pronađi taj dan u trenutnoj nedelji
            final now = DateTime.now();
            final currentWeekday = now.weekday; // 1=Pon, 2=Uto, 3=Sre, 4=Čet, 5=Pet

            int targetWeekday;
            switch (_selectedDan) {
              case 'Ponedeljak':
                targetWeekday = 1;
                break;
              case 'Utorak':
                targetWeekday = 2;
                break;
              case 'Sreda':
                targetWeekday = 3;
                break;
              case 'Četvrtak':
                targetWeekday = 4;
                break;
              case 'Petak':
                targetWeekday = 5;
                break;
              default:
                targetWeekday = currentWeekday;
            }

            // 🎯 USKLADI SA DANAS SCREEN: Ako je odabrani dan isti kao danas, koristi današnji datum
            final DateTime targetDate;
            if (targetWeekday == currentWeekday) {
              // Isti dan kao danas - koristi današnji datum (kao danas screen)
              targetDate = now;
            } else {
              // Standardna logika za ostale dane
              final daysFromToday = targetWeekday - currentWeekday;
              targetDate = now.add(Duration(days: daysFromToday));
            }

            // ✅ KORISTI UTILS ZA KREIRANJE DATE RANGE
            final dateRange = app_date_utils.DateUtils.getDateRange(targetDate);
            streamFrom = dateRange['from']!;
            streamTo = dateRange['to']!;

            // 🎯 KORISTI StatistikaService.streamPazarZaSveVozace() - BEZ RxDart
            return StreamBuilder<Map<String, double>>(
              stream: StatistikaService.streamPazarZaSveVozace(from: streamFrom, to: streamTo),
              builder: (context, pazarSnapshot) {
                if (!pazarSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final pazarMap = pazarSnapshot.data!;

                // 🎯 IDENTIČNA LOGIKA SA DANAS SCREEN: uzmi direktno vrednost iz mape
                final ukupno = pazarMap['_ukupno'] ?? 0.0;

                // Ukloni '_ukupno' ključ za čist prikaz
                final Map<String, double> pazar = Map.from(pazarMap)..remove('_ukupno');

                // 👥 FILTER PO VOZAČU - Prikaži samo naplate trenutnog vozača ili sve za admin
                // 🔐 KORISTI ADMIN SECURITY SERVICE za filtriranje privilegija
                final bool isAdmin = AdminSecurityService.isAdmin(_currentDriver);
                final Map<String, double> filteredPazar = AdminSecurityService.filterPazarByPrivileges(
                  _currentDriver,
                  pazar,
                );

                final Map<String, Color> vozacBoje = VozacBoja.boje;
                final List<String> vozaciRedosled = [
                  'Bruda',
                  'Bilevski',
                  'Bojan',
                  'Svetlana',
                  'Ivan',
                ];

                // Filter vozače redosled na osnovu trenutnog vozača
                // 🔐 KORISTI ADMIN SECURITY SERVICE za filtriranje vozača
                final List<String> prikazaniVozaci = AdminSecurityService.getVisibleDrivers(
                  _currentDriver,
                  vozaciRedosled,
                );
                return SingleChildScrollView(
                  // ensure we respect device safe area / system nav bar at the
                  // bottom — some devices (Samsung) have a system bar which can
                  // cause a tiny overflow (2px on some screens). Add extra
                  // bottom padding based on MediaQuery so the content can scroll
                  // clear of system UI on all devices.
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 12),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom + 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Text(
                                AdminSecurityService.generateTitle(
                                  _currentDriver,
                                  'Dnevni pazar - $_selectedDan',
                                ),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white, // Bela boja
                                  shadows: [
                                    Shadow(
                                      offset: Offset(1, 1),
                                      blurRadius: 3,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.today,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              if (!isAdmin) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.person,
                                  color: Colors.green[600],
                                  size: 18,
                                ),
                              ],
                            ],
                          ),
                        ),
                        //  Info box za individualnog vozača
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
                        // 👥 VOZAČI PAZAR (BEZ DEPOZITA)
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
                                      20,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: (vozacBoje[vozac] ?? Colors.blueGrey).withAlpha(
                                        70,
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
                                  currentDriver: _currentDriver,
                                ),
                              ),
                            );
                          },
                          wide: true,
                        ),
                        const SizedBox(height: 4),
                        // 💸 KUSUR KOCKE (REAL-TIME)
                        Row(
                          children: [
                            // Kusur za Bruda - REAL-TIME (OPTIMIZED)
                            Expanded(
                              child: StreamBuilder<double>(
                                // 🔥 ZAMENЈENO: OptimizedKusurService umesto MasterRealtimeStream
                                stream: OptimizedKusurService.instance.streamKusurForVozac('Bruda'),
                                builder: (context, snapshot) {
                                  // Heartbeat indicator pokazuje status konekcije
                                  if (snapshot.hasError) {
                                    _kusurStreamHealthy.value = false;
                                    // Prikaži prazno stanje umesto error widget-a
                                    return Container(
                                      height: 60,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Theme.of(context).glassBorder,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.purple.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.savings,
                                            color: Colors.purple,
                                            size: 16,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'KUSUR',
                                            style: TextStyle(
                                              color: Colors.purple,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                          Expanded(
                                            child: Center(
                                              child: Text(
                                                '0 RSD',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  // Update health status on successful data
                                  if (snapshot.hasData) {
                                    _kusurStreamHealthy.value = true;
                                  }

                                  final kusurBruda = snapshot.data ?? 0.0;

                                  return Container(
                                    height: 60,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2), // Glassmorphism
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context).glassBorder, // Transparentni border
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.purple.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.savings,
                                          color: Colors.purple[700],
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'KUSUR',
                                          style: TextStyle(
                                            color: Colors.purple[800],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.purple[100],
                                              border: Border.all(
                                                color: Colors.purple[300]!,
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '${kusurBruda.toStringAsFixed(0)} RSD',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.purple[800],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Kusur za Bilevski - REAL-TIME (OPTIMIZED)
                            Expanded(
                              child: StreamBuilder<double>(
                                // 🔥 ZAMENЈENO: OptimizedKusurService umesto MasterRealtimeStream
                                stream: OptimizedKusurService.instance.streamKusurForVozac('Bilevski'),
                                builder: (context, snapshot) {
                                  // Heartbeat indicator pokazuje status konekcije
                                  if (snapshot.hasError) {
                                    _kusurStreamHealthy.value = false;
                                    // Prikaži prazno stanje umesto error widget-a
                                    return Container(
                                      height: 60,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Theme.of(context).glassBorder,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.orange.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.savings,
                                            color: Colors.orange,
                                            size: 16,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'KUSUR',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                          Expanded(
                                            child: Center(
                                              child: Text(
                                                '0 RSD',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  // Update health status on successful data
                                  if (snapshot.hasData) {
                                    _kusurStreamHealthy.value = true;
                                  }

                                  final kusurBilevski = snapshot.data ?? 0.0;

                                  return Container(
                                    height: 60,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2), // Glassmorphism
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context).glassBorder, // Transparentni border
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orange.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.savings,
                                          color: Colors.orange[700],
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'KUSUR',
                                          style: TextStyle(
                                            color: Colors.orange[800],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange[100],
                                              border: Border.all(
                                                color: Colors.orange[300]!,
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '${kusurBilevski.toStringAsFixed(0)} RSD',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.orange[800],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // UKUPAN PAZAR
                        Container(
                          width: double.infinity,
                          // increased slightly to provide safe headroom across
                          // devices (prevent tiny 1–3px overflows caused by
                          // font metrics / shadows on some phones)
                          height: 76,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2), // Glassmorphism
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).glassBorder, // Transparentni border
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.3),
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
                                  // 💰 UKUPAN PAZAR (BEZ DEPOZITA)
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
                        // � SMS TEST DUGME - samo za Bojan
                        if (_currentDriver?.toLowerCase() == 'bojan') ...[
                          // SMS test i debug funkcionalnost uklonjena - servis radi u pozadini
                        ],
                        // 🎯 SVI ADMIN DUGMIĆI U JEDNOM REDU
                        Container(
                          margin: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              // 🗺️ GPS ADMIN MAPA
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (context) => const AdminMapScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    height: 54,
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2), // Glassmorphism
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context).glassBorder,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          color: Colors.white,
                                          size: 16,
                                          shadows: [
                                            Shadow(
                                              offset: Offset(1, 1),
                                              blurRadius: 3,
                                              color: Colors.black54,
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'GPS',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
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
                                ),
                              ),
                              // 📊 SUPABASE MONITORING
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (context) => const MonitoringEkran(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    height: 54,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2), // Glassmorphism
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context).glassBorder,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.analytics,
                                          color: Colors.white,
                                          size: 16,
                                          shadows: [
                                            Shadow(
                                              offset: Offset(1, 1),
                                              blurRadius: 3,
                                              color: Colors.black54,
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'Monitor',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
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
                                ),
                              ),
                            ],
                          ),
                        ),
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

  // (Funkcija za dijalog sa dužnicima je uklonjena - sada se koristi DugoviScreen)
}
