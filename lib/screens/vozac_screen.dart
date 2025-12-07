import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // 🗺️ Za GPS poziciju

import '../models/putnik.dart';
import '../services/auth_manager.dart';
import '../services/firebase_service.dart'; // 🎯 Za vozača
import '../services/local_notification_service.dart'; // 🔔 Za lokalne notifikacije
import '../services/pickup_tracking_service.dart'; // 🛰️ Za GPS pickup tracking
import '../services/putnik_service.dart';
import '../services/realtime_gps_service.dart'; // 🛰️ Za GPS tracking
import '../services/realtime_notification_counter_service.dart'; // 🔔 Za notification count
import '../services/realtime_notification_service.dart'; // 🔔 Za realtime notifikacije
import '../services/route_optimization_service.dart';
import '../services/simplified_daily_checkin.dart';
import '../services/smart_navigation_service.dart';
import '../services/statistika_service.dart';
import '../theme.dart';
import '../utils/schedule_utils.dart';
import '../utils/vozac_boja.dart'; // 🎯 Za validaciju vozača
import '../widgets/bottom_nav_bar_letnji.dart';
import '../widgets/bottom_nav_bar_zimski.dart';
import '../widgets/clock_ticker.dart';
import '../widgets/putnik_list.dart';
import 'dugovi_screen.dart';
import 'welcome_screen.dart';

/// 🚗 VOZAČ SCREEN - Za Ivan-a
/// Prikazuje putnike koristeći isti PutnikService stream kao DanasScreen
class VozacScreen extends StatefulWidget {
  const VozacScreen({Key? key}) : super(key: key);

  @override
  State<VozacScreen> createState() => _VozacScreenState();
}

class _VozacScreenState extends State<VozacScreen> {
  final String _vozacIme = 'Ivan';
  final PutnikService _putnikService = PutnikService();
  final RouteOptimizationService _routeOptimizationService = RouteOptimizationService();

  Position? _lastDriverPosition;
  StreamSubscription<Position>? _driverPositionSubscription;

  String _selectedGrad = 'Bela Crkva';
  String _selectedVreme = '5:00';

  // 🎯 OPTIMIZACIJA RUTE - kopirano iz DanasScreen
  bool _isRouteOptimized = false;
  List<Putnik> _optimizedRoute = [];
  bool _isLoading = false;
  Map<Putnik, Position>? _cachedCoordinates; // 🎯 Keširane koordinate
  String? _currentDriver; // 🎯 Trenutni vozač

  // Status varijable
  String _navigationStatus = ''; // ignore: unused_field
  int _currentPassengerIndex = 0; // ignore: unused_field
  bool _isListReordered = false;
  bool _isGpsTracking = false; // 🛰️ GPS tracking status
  bool _isPopisLoading = false; // 📋 Loading state za POPIS dugme

  // Hardkodovana vremena za vozač screen
  static const List<String> _bcVremena = [
    '5:00',
    '7:00',
    '15:30',
    '18:00',
  ];

  static const List<String> _vsVremena = [
    '6:00',
    '8:00',
    '17:00',
    '19:00',
  ];

  List<String> get _sviPolasci {
    final bcList = _bcVremena.map((v) => '$v Bela Crkva').toList();
    final vsList = _vsVremena.map((v) => '$v Vršac').toList();
    return [...bcList, ...vsList];
  }

  @override
  void initState() {
    super.initState();
    _initializeCurrentDriver();
    _initializeNotifications();
    _initializeGpsTracking();
  }

  // 🛰️ GPS TRACKING INICIJALIZACIJA
  void _initializeGpsTracking() {
    // Start GPS tracking
    RealtimeGpsService.startTracking().catchError((Object e) {});

    // Subscribe to driver position updates
    _driverPositionSubscription = RealtimeGpsService.positionStream.listen((pos) {
      _lastDriverPosition = pos;
    });
  }

  @override
  void dispose() {
    _driverPositionSubscription?.cancel();
    super.dispose();
  }

  // 🔔 INICIJALIZACIJA NOTIFIKACIJA - IDENTIČNO KAO DANAS SCREEN
  void _initializeNotifications() {
    // Inicijalizuj heads-up i zvuk notifikacije
    LocalNotificationService.initialize(context);
    RealtimeNotificationService.listenForForegroundNotifications(context);

    // Inicijalizuj realtime notifikacije za vozača
    FirebaseService.getCurrentDriver().then((driver) {
      if (driver != null && driver.isNotEmpty) {
        RealtimeNotificationService.initialize();
      }
    });

    // Real-time notification counter
    RealtimeNotificationCounterService.initialize();
  }

  Future<void> _initializeCurrentDriver() async {
    _currentDriver = await FirebaseService.getCurrentDriver();
    // 🆘 FALLBACK: Ako FirebaseService ne vrati vozača, koristi _vozacIme (Ivan)
    if (_currentDriver == null || _currentDriver!.isEmpty) {
      _currentDriver = _vozacIme; // 'Ivan'
      // Sačuvaj u SharedPreferences za sledeći put
      await FirebaseService.setCurrentDriver(_vozacIme);
    }
    if (mounted) setState(() {});
  }

  // Callback za BottomNavBar
  void _onPolazakChanged(String grad, String vreme) {
    if (mounted) {
      setState(() {
        _selectedGrad = grad;
        _selectedVreme = vreme;
      });
    }
  }

  Future<void> _logout() async {
    await AuthManager.logout(context);
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  // 🔄 RESET OPTIMIZACIJE RUTE
  void _resetOptimization() {
    if (mounted) {
      setState(() {
        _isRouteOptimized = false;
        _isListReordered = false;
        _optimizedRoute.clear();
        _currentPassengerIndex = 0;
        _navigationStatus = '';
        _cachedCoordinates = null;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Optimizacija rute je isključena'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 🎯 REOPTIMIZACIJA RUTE NAKON PROMENE STATUSA PUTNIKA
  Future<void> _reoptimizeAfterStatusChange() async {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty) return;

    // Filtriraj samo nepokupljene i neotkazane putnike
    final preostaliPutnici = _optimizedRoute.where((p) {
      final status = p.status?.toLowerCase() ?? '';
      final isPokupljen = p.vremePokupljenja != null;
      final isOtkazan = status == 'otkazano' || status == 'otkazan';
      return !isPokupljen && !isOtkazan;
    }).toList();

    if (preostaliPutnici.isEmpty) {
      // Svi putnici su pokupljeni ili otkazani
      if (mounted) {
        setState(() {
          _optimizedRoute.clear();
          _isRouteOptimized = false;
          _isListReordered = false;
          _currentPassengerIndex = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Svi putnici su pokupljeni!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    // Reoptimizuj rutu od trenutne GPS pozicije
    try {
      final result = await SmartNavigationService.optimizeRouteOnly(
        putnici: preostaliPutnici,
        startCity: _selectedGrad.isNotEmpty ? _selectedGrad : 'Vršac',
      );

      if (result.success && result.optimizedPutnici != null) {
        if (mounted) {
          setState(() {
            _optimizedRoute = result.optimizedPutnici!;
            _currentPassengerIndex = 0;
          });

          final sledeci = _optimizedRoute.isNotEmpty ? _optimizedRoute.first.ime : 'N/A';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔄 Ruta ažurirana! Sledeći: $sledeci (${_optimizedRoute.length} preostalo)'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      // Greška pri reoptimizaciji
    }
  }

  // 🎯 OPTIMIZACIJA RUTE - IDENTIČNO KAO DANAS SCREEN
  void _optimizeCurrentRoute(List<Putnik> putnici, {bool isAlreadyOptimized = false}) async {
    // Proveri da li je ulogovan i valjan vozač
    if (_currentDriver == null || !VozacBoja.isValidDriver(_currentDriver)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Morate biti ulogovani i ovlašćeni da biste koristili optimizaciju rute.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    // 🎯 Ako je lista već optimizovana od strane servisa, koristi je direktno
    if (isAlreadyOptimized) {
      if (putnici.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Nema putnika sa adresama za reorder'), backgroundColor: Colors.orange),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _optimizedRoute = List<Putnik>.from(putnici);
          _isRouteOptimized = true;
          _isListReordered = true;
          _currentPassengerIndex = 0;
          _isLoading = false;
        });
      }

      final routeString = _optimizedRoute.take(3).map((p) => p.adresa?.split(',').first ?? p.ime).join(' → ');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎯 Lista putnika optimizovana (server) za $_selectedGrad $_selectedVreme!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('📍 Sledeći putnici: $routeString${_optimizedRoute.length > 3 ? "..." : ""}'),
                Text('🎯 Broj putnika: ${_optimizedRoute.length}'),
              ],
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    // Filter putnika sa validnim adresama
    final filtriraniPutnici = putnici.where((p) {
      final hasValidAddress = (p.adresaId != null && p.adresaId!.isNotEmpty) ||
          (p.adresa != null && p.adresa!.isNotEmpty && p.adresa != p.grad);
      return hasValidAddress;
    }).toList();

    if (filtriraniPutnici.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Nema putnika sa adresama za optimizaciju'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    try {
      final result = await SmartNavigationService.optimizeRouteOnly(
        putnici: filtriraniPutnici,
        startCity: _selectedGrad.isNotEmpty ? _selectedGrad : 'Vršac',
      );

      if (result.success && result.optimizedPutnici != null && result.optimizedPutnici!.isNotEmpty) {
        final optimizedPutnici = result.optimizedPutnici!;

        if (mounted) {
          setState(() {
            _optimizedRoute = optimizedPutnici;
            _cachedCoordinates = result.cachedCoordinates; // 🎯 Sačuvaj koordinate
            _isRouteOptimized = true;
            _isListReordered = true;
            _currentPassengerIndex = 0;
            _isLoading = false;
          });
        }

        final routeString = optimizedPutnici.take(3).map((p) => p.adresa?.split(',').first ?? p.ime).join(' → ');

        // 🆕 Proveri da li ima preskočenih putnika
        final skipped = result.skippedPutnici;
        final hasSkipped = skipped != null && skipped.isNotEmpty;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎯 RUTA OPTIMIZOVANA za $_selectedGrad $_selectedVreme!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('📍 Sledeći putnici: $routeString${optimizedPutnici.length > 3 ? "..." : ""}'),
                  Text('🎯 Broj putnika: ${optimizedPutnici.length}'),
                  if (result.totalDistance != null)
                    Text('📏 Ukupno: ${(result.totalDistance! / 1000).toStringAsFixed(1)} km'),
                ],
              ),
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.green,
            ),
          );

          // 🆕 Prikaži POSEBAN DIALOG za preskočene putnike
          if (hasSkipped) {
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.orange.shade100,
                  title: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
                      const SizedBox(width: 8),
                      Text(
                        '${skipped.length} PUTNIKA BEZ LOKACIJE',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ovi putnici nisu uključeni u optimizovanu rutu:',
                        style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      ...skipped.take(5).map((p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.location_off, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    p.ime,
                                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      if (skipped.length > 5)
                        Text(
                          '... i još ${skipped.length - 5}',
                          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54),
                        ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lightbulb, color: Colors.blue, size: 24),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pokupite ih ručno!\nAplikacija će zapamtiti lokaciju za sledeći put.',
                                style: TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('RAZUMEM', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }
          }
        }
      } else {
        // Fallback na osnovno sortiranje
        final optimizedPutnici = List<Putnik>.from(filtriraniPutnici)
          ..sort((a, b) => (a.adresa ?? '').compareTo(b.adresa ?? ''));

        if (mounted) {
          setState(() {
            _optimizedRoute = optimizedPutnici;
            _isRouteOptimized = true;
            _isListReordered = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${result.message}\nKoristim osnovno sortiranje.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRouteOptimized = false;
          _isListReordered = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška pri optimizaciji: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🚀 KOMPAKTNO DUGME ZA OPTIMIZACIJU - IDENTIČNO KAO DANAS SCREEN
  // ✅ ISPRAVKA: Koristi FutureBuilder + RouteOptimizationService
  Widget _buildOptimizeButton() {
    return FutureBuilder<List<Putnik>>(
      // ✅ Key koji se menja kada se filteri promene
      key: ValueKey('route_$_selectedGrad$_selectedVreme${_lastDriverPosition?.latitude}'),
      future: _routeOptimizationService.fetchPassengersForRoute(
        grad: _selectedGrad,
        vreme: _selectedVreme,
        driverPosition: _lastDriverPosition,
      ),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 26,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
              child: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return SizedBox(
            height: 26,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
              child: const Text('!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          );
        }

        final filtriraniPutnici = snapshot.data ?? [];
        final hasPassengers = filtriraniPutnici.isNotEmpty;
        final bool isDriverValid = _currentDriver != null && VozacBoja.isValidDriver(_currentDriver);

        return SizedBox(
          height: 26,
          child: ElevatedButton(
            onPressed: _isLoading || !hasPassengers || !isDriverValid
                ? null
                : () {
                    if (_isRouteOptimized) {
                      _resetOptimization();
                    } else {
                      _optimizeCurrentRoute(filtriraniPutnici, isAlreadyOptimized: false);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRouteOptimized
                  ? Colors.green.shade600
                  : (hasPassengers ? Theme.of(context).primaryColor : Colors.grey.shade400),
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: hasPassengers ? 2 : 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _isRouteOptimized ? 'Reset' : 'Ruta',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        );
      },
    );
  }

  // ⚡ SPEEDOMETER DUGME U APPBAR-U - IDENTIČNO KAO DANAS SCREEN
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
                    : Theme.of(context).colorScheme.onSurface;

        return SizedBox(
          height: 26,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: speedColor.withValues(alpha: 0.4)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                speed.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: speedColor,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 🗺️ DUGME ZA NAVIGACIJU - IDENTIČNO KAO DANAS SCREEN
  Widget _buildMapsButton() {
    final hasOptimizedRoute = _isRouteOptimized && _optimizedRoute.isNotEmpty;
    final bool isDriverValid = _currentDriver != null && VozacBoja.isValidDriver(_currentDriver);
    return SizedBox(
      height: 26,
      child: ElevatedButton(
        onPressed: hasOptimizedRoute && isDriverValid
            ? () => (_isGpsTracking ? _stopSmartNavigation() : _showNavigationOptionsDialog())
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isGpsTracking
              ? Colors.orange.shade700
              : (hasOptimizedRoute ? Theme.of(context).colorScheme.primary : Colors.grey.shade400),
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: hasOptimizedRoute ? 2 : 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isGpsTracking ? Icons.stop : Icons.navigation,
                size: 10,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              const SizedBox(width: 2),
              Text(
                _isGpsTracking ? 'STOP' : 'NAV',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🗺️ DIJALOG SA OPCIJAMA NAVIGACIJE
  void _showNavigationOptionsDialog() {
    final putnikCount = _optimizedRoute.length;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.navigation, color: Colors.blue),
            SizedBox(width: 8),
            Text('Navigacija', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Opcija 1: Samo sledeći putnik
            ListTile(
              leading: const Icon(Icons.person, color: Colors.green),
              title: const Text('Sledeći putnik'),
              subtitle: Text(
                _optimizedRoute.isNotEmpty
                    ? '${_optimizedRoute.first.ime} - ${_optimizedRoute.first.adresa}'
                    : 'Nema putnika',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _startSmartNavigation();
              },
            ),
            const Divider(),
            // Opcija 2: Svi putnici (multi-waypoint)
            ListTile(
              leading: const Icon(Icons.group, color: Colors.blue),
              title: Text('Svi putnici ($putnikCount)'),
              subtitle: Text(
                putnikCount > 10 ? 'Prvih 10 kao waypoints, ostali posle' : 'Svi kao waypoints u Google Maps',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _startAllWaypointsNavigation();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Otkaži'),
          ),
        ],
      ),
    );
  }

  // 🗺️ NAVIGACIJA SA SVIM PUTNICIMA (multi-waypoint)
  Future<void> _startAllWaypointsNavigation() async {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty) return;

    try {
      final result = await SmartNavigationService.startMultiProviderNavigation(
        context: context,
        putnici: _optimizedRoute,
        startCity: _selectedGrad.isNotEmpty ? _selectedGrad : 'Vršac',
        cachedCoordinates: _cachedCoordinates,
      );

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🗺️ ${result.message}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
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

  // 🗺️ START SMART NAVIGATION
  Future<void> _startSmartNavigation() async {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty) return;

    try {
      final result = await SmartNavigationService.startMultiProviderNavigation(
        context: context,
        putnici: _optimizedRoute,
        startCity: _selectedGrad.isNotEmpty ? _selectedGrad : 'Vršac',
        cachedCoordinates: _cachedCoordinates,
      );

      if (result.success) {
        // 🛰️ POKRENI PICKUP TRACKING SA GPS PRAĆENJEM
        await _startPickupTracking();

        if (mounted) {
          setState(() {
            _optimizedRoute = result.optimizedPutnici ?? _optimizedRoute;
            _cachedCoordinates = result.cachedCoordinates;
            _isRouteOptimized = true;
            _isGpsTracking = true;
            _navigationStatus = result.message;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('🗺️ ${result.message}'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isGpsTracking = false;
            _navigationStatus = result.message;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ ${result.message}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGpsTracking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Greška pri pokretanju navigacije: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 🛰️ START PICKUP TRACKING (GPS + NOTIFIKACIJE)
  Future<void> _startPickupTracking() async {
    final coords = _cachedCoordinates;
    if (coords == null || coords.isEmpty) {
      return;
    }

    final pickupService = PickupTrackingService();
    await pickupService.initialize();

    final started = await pickupService.startTracking(
      putnici: _optimizedRoute,
      coordinates: coords,
      onPickedUp: (putnik, status) async {
        // 🔄 REALTIME: Ažuriraj status putnika u bazi
        if (putnik.id != null && _currentDriver != null) {
          try {
            await _putnikService.oznaciPokupljen(putnik.id!, _currentDriver!);
          } catch (_) {
            // Greška pri označavanju
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${putnik.ime} pokupljen'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      onSkipped: (putnik) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⏭️ ${putnik.ime} preskočen'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      onApproaching: (putnik, distance) {},
      onCompleted: () {
        if (mounted) {
          setState(() {
            _isGpsTracking = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Svi putnici pokupljeni!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      },
    );

    if (started) {
    } else {}
  }

  // 🛑 STOP SMART NAVIGATION
  void _stopSmartNavigation() {
    // 🛰️ ZAUSTAVI PICKUP TRACKING
    PickupTrackingService().stopTracking();

    if (mounted) {
      setState(() {
        _isGpsTracking = false;
        _navigationStatus = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🛑 Navigacija zaustavljena'), backgroundColor: Colors.orange),
      );
    }
  }

  // 📋 POPIS DUGME - IDENTIČNO KAO DANAS SCREEN
  Widget _buildPopisButton() {
    final bool isDriverValid = _currentDriver != null && VozacBoja.isValidDriver(_currentDriver);
    return SizedBox(
      height: 26,
      child: ElevatedButton(
        onPressed: (!isDriverValid || _isPopisLoading) ? null : () => _showPopisDana(),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isPopisLoading ? Colors.grey.shade400 : Theme.of(context).colorScheme.secondary,
          foregroundColor: Theme.of(context).colorScheme.onSecondary,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        ),
        child: _isPopisLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('POPIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.3)),
              ),
      ),
    );
  }

  // 📊 POPIS DANA - REALTIME PODACI
  Future<void> _showPopisDana() async {
    if (_currentDriver == null || _currentDriver!.isEmpty || !VozacBoja.isValidDriver(_currentDriver)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Morate biti ulogovani i ovlašćeni da biste koristili Popis.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    final vozac = _currentDriver!;

    // Pokreni loading indikator
    if (mounted) setState(() => _isPopisLoading = true);

    try {
      // 1. OSNOVNI PODACI
      final today = DateTime.now();
      final dayStart = DateTime(today.year, today.month, today.day);
      final dayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

      // 2. REALTIME STREAM ZA KOMBINOVANE PUTNIKE
      late List<Putnik> putnici;
      try {
        final isoDate = DateTime.now().toIso8601String().split('T')[0];
        final stream = _putnikService.streamKombinovaniPutniciFiltered(
          isoDate: isoDate,
          grad: _selectedGrad,
          vreme: _selectedVreme,
        );
        putnici = await stream.first.timeout(const Duration(seconds: 10));
      } catch (e) {
        putnici = [];
      }

      // 3. REALTIME DETALJNE STATISTIKE
      final detaljneStats = await StatistikaService.instance.detaljneStatistikePoVozacima(putnici, dayStart, dayEnd);
      final vozacStats = detaljneStats[vozac] ?? {};

      // 4. REALTIME PAZAR STREAM
      late double ukupanPazar;
      try {
        ukupanPazar = await StatistikaService.streamPazarZaVozaca(
          vozac,
          from: dayStart,
          to: dayEnd,
        ).first.timeout(const Duration(seconds: 10));
      } catch (e) {
        ukupanPazar = 0.0;
      }

      // 5. SITAN NOVAC
      final sitanNovac = await SimplifiedDailyCheckInService.getTodayAmount(vozac);

      // 6. MAPIRANJE PODATAKA
      final dodatiPutnici = (vozacStats['dodati'] ?? 0) as int;
      final otkazaniPutnici = (vozacStats['otkazani'] ?? 0) as int;
      final naplaceniPutnici = (vozacStats['naplaceni'] ?? 0) as int;
      final pokupljeniPutnici = (vozacStats['pokupljeni'] ?? 0) as int;
      final dugoviPutnici = (vozacStats['dugovi'] ?? 0) as int;
      final mesecneKarte = (vozacStats['mesecneKarte'] ?? 0) as int;

      // 7. KILOMETRAŽA
      late double kilometraza;
      try {
        kilometraza = await StatistikaService.instance.getKilometrazu(vozac, dayStart, dayEnd);
      } catch (e) {
        kilometraza = 0.0;
      }

      // 8. PRIKAŽI POPIS DIALOG
      final bool sacuvaj = await _showPopisDialog(
        vozac: vozac,
        datum: today,
        ukupanPazar: ukupanPazar,
        sitanNovac: sitanNovac,
        dodatiPutnici: dodatiPutnici,
        otkazaniPutnici: otkazaniPutnici,
        naplaceniPutnici: naplaceniPutnici,
        pokupljeniPutnici: pokupljeniPutnici,
        dugoviPutnici: dugoviPutnici,
        mesecneKarte: mesecneKarte,
        kilometraza: kilometraza,
      );

      // 9. SAČUVAJ POPIS AKO JE POTVRĐEN
      if (sacuvaj) {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Greška pri učitavanju popisa: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPopisLoading = false);
    }
  }

  // 📊 DIALOG ZA PRIKAZ POPISA DANA
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
            Icon(Icons.person, color: vozacColor, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'POPIS - ${datum.day}.${datum.month}.${datum.year}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                overflow: TextOverflow.ellipsis,
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
              color: vozacColor.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: vozacColor.withValues(alpha: 0.6), width: 2),
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
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // DETALJNE STATISTIKE
                    _buildPopisStatRow('Dodati putnici', dodatiPutnici, Icons.add_circle, Colors.blue),
                    _buildPopisStatRow('Otkazani', otkazaniPutnici, Icons.cancel, Colors.red),
                    _buildPopisStatRow('Naplaćeni', naplaceniPutnici, Icons.payment, Colors.green),
                    _buildPopisStatRow('Pokupljeni', pokupljeniPutnici, Icons.check_circle, Colors.orange),
                    _buildPopisStatRow('Dugovi', dugoviPutnici, Icons.warning, Colors.redAccent),
                    _buildPopisStatRow('Mesečne karte', mesecneKarte, Icons.card_membership, Colors.purple),
                    _buildPopisStatRow('Kilometraža', '${kilometraza.toStringAsFixed(1)} km', Icons.route, Colors.teal),

                    Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),

                    // UKUPAN PAZAR
                    _buildPopisStatRow(
                      'Ukupno pazar',
                      '${ukupanPazar.toStringAsFixed(0)} RSD',
                      Icons.monetization_on,
                      Colors.amber,
                    ),

                    const SizedBox(height: 12),

                    // DODATNE INFORMACIJE
                    if (sitanNovac > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Sitan novac: ${sitanNovac.toStringAsFixed(0)} RSD',
                              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
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
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Otkaži')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.save),
            label: const Text('Sačuvaj popis'),
            style: ElevatedButton.styleFrom(
              backgroundColor: vozacColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // 📊 HELPER ZA STATISTIKU RED U POPIS DIALOGU
  Widget _buildPopisStatRow(String label, dynamic value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(
            value.toString(),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // 💾 SAČUVAJ POPIS U DAILY CHECK-IN SERVICE
  Future<void> _sacuvajPopis(String vozac, DateTime datum, Map<String, dynamic> podaci) async {
    try {
      await SimplifiedDailyCheckInService.saveDailyReport(vozac, datum, podaci);
      await SimplifiedDailyCheckInService.saveCheckIn(vozac, podaci['sitanNovac'] as double);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Popis je uspešno sačuvan!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Greška pri čuvanju popisa: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dayStart = DateTime(today.year, today.month, today.day);
    final dayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return Container(
      decoration: const BoxDecoration(
        gradient: tripleBlueFashionGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          toolbarHeight: 80,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // PRVI RED - Datum i vreme
                  _buildDigitalDateDisplay(),
                  const SizedBox(height: 8),
                  // DRUGI RED - Dugmad ravnomerno raspoređena
                  Row(
                    children: [
                      // 🎯 RUTA DUGME
                      Expanded(child: _buildOptimizeButton()),
                      const SizedBox(width: 4),
                      // 🗺️ NAV DUGME
                      Expanded(child: _buildMapsButton()),
                      const SizedBox(width: 4),
                      // 📋 POPIS DUGME
                      Expanded(child: _buildPopisButton()),
                      const SizedBox(width: 4),
                      // ⚡ BRZINOMER
                      Expanded(child: _buildSpeedometerButton()),
                      const SizedBox(width: 4),
                      // Logout
                      _buildAppBarButton(
                        icon: Icons.logout,
                        color: Colors.red.shade400,
                        onTap: _logout,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        body: _currentDriver == null
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : StreamBuilder<List<Putnik>>(
                stream: _putnikService.streamKombinovaniPutniciFiltered(
                  isoDate: DateTime.now().toIso8601String().split('T')[0],
                  grad: _selectedGrad,
                  vreme: _selectedVreme,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }

                  final putnici =
                      _isRouteOptimized && _optimizedRoute.isNotEmpty ? _optimizedRoute : (snapshot.data ?? []);

                  return Column(
                    children: [
                      // KOCKE - Pazar, Mesečne, Dugovi, Kusur
                      Container(
                        margin: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // PAZAR
                            Expanded(
                              child: StreamBuilder<double>(
                                stream: StatistikaService.streamPazarZaVozaca(
                                  _currentDriver ?? '',
                                  from: dayStart,
                                  to: dayEnd,
                                ),
                                builder: (context, snapshot) {
                                  final pazar = snapshot.data ?? 0.0;
                                  return _buildStatBox(
                                    'Pazar',
                                    pazar.toStringAsFixed(0),
                                    Colors.green,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            // MESEČNE
                            Expanded(
                              child: StreamBuilder<int>(
                                stream: StatistikaService.streamBrojMesecnihKarataZaVozaca(
                                  _currentDriver ?? '',
                                  from: dayStart,
                                  to: dayEnd,
                                ),
                                builder: (context, snapshot) {
                                  final mesecne = snapshot.data ?? 0;
                                  return _buildStatBox(
                                    'Mesečne',
                                    mesecne.toString(),
                                    Colors.purple,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            // DUGOVI
                            Expanded(
                              child: StreamBuilder<int>(
                                stream: StatistikaService.streamBrojDuznikaZaVozaca(
                                  _currentDriver ?? '',
                                  from: dayStart,
                                  to: dayEnd,
                                ),
                                builder: (context, snapshot) {
                                  final brojDuznika = snapshot.data ?? 0;
                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (context) => DugoviScreen(currentDriver: _currentDriver),
                                        ),
                                      );
                                    },
                                    child: _buildStatBox(
                                      'Dugovi',
                                      brojDuznika.toString(),
                                      Colors.red,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            // KUSUR
                            Expanded(
                              child: StreamBuilder<double>(
                                stream: SimplifiedDailyCheckInService.streamTodayAmount(_currentDriver ?? ''),
                                builder: (context, snapshot) {
                                  final kusur = snapshot.data ?? 0.0;
                                  return _buildStatBox(
                                    'Kusur',
                                    kusur > 0 ? kusur.toStringAsFixed(0) : '-',
                                    Colors.orange,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Lista putnika - koristi PutnikList sa stream-om kao DanasScreen
                      Expanded(
                        child: putnici.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inbox,
                                      size: 64,
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Nema putnika za izabrani polazak',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : PutnikList(
                                putnici: putnici,
                                useProvidedOrder: _isListReordered,
                                currentDriver:
                                    _currentDriver, // ✅ FIX: Koristi dinamički _currentDriver umesto hardkodovanog _vozacIme
                                selectedGrad: _selectedGrad,
                                selectedVreme: _selectedVreme,
                                onPutnikStatusChanged: _reoptimizeAfterStatusChange,
                                bcVremena: _bcVremena,
                                vsVremena: _vsVremena,
                              ),
                      ),
                    ],
                  );
                },
              ),
        // 🎯 BOTTOM NAV BAR
        bottomNavigationBar: StreamBuilder<List<Putnik>>(
          stream: _putnikService.streamKombinovaniPutniciFiltered(
            isoDate: DateTime.now().toIso8601String().split('T')[0],
          ),
          builder: (context, snapshot) {
            final allPutnici = snapshot.data ?? <Putnik>[];

            // Računaj broj putnika po gradu/vremenu za BottomNavBar
            int getPutnikCount(String grad, String vreme) {
              return allPutnici.where((p) {
                final gradMatch = p.grad.toLowerCase().contains(grad.toLowerCase().substring(0, 4));
                final vremeMatch = p.polazak == vreme;
                return gradMatch && vremeMatch;
              }).length;
            }

            return isZimski(DateTime.now())
                ? BottomNavBarZimski(
                    sviPolasci: _sviPolasci,
                    selectedGrad: _selectedGrad,
                    selectedVreme: _selectedVreme,
                    getPutnikCount: getPutnikCount,
                    onPolazakChanged: _onPolazakChanged,
                    bcVremena: _bcVremena, // ✅ Custom vremena za VozacScreen
                    vsVremena: _vsVremena, // ✅ Custom vremena za VozacScreen
                  )
                : BottomNavBarLetnji(
                    sviPolasci: _sviPolasci,
                    selectedGrad: _selectedGrad,
                    selectedVreme: _selectedVreme,
                    getPutnikCount: getPutnikCount,
                    onPolazakChanged: _onPolazakChanged,
                    bcVremena: _bcVremena, // ✅ Custom vremena za VozacScreen
                    vsVremena: _vsVremena, // ✅ Custom vremena za VozacScreen
                  );
          },
        ),
      ),
    );
  }

  // 📅 Digitalni datum display
  Widget _buildDigitalDateDisplay() {
    final now = DateTime.now();
    final dayNames = ['PONEDELJAK', 'UTORAK', 'SREDA', 'ČETVRTAK', 'PETAK', 'SUBOTA', 'NEDELJA'];
    final dayName = dayNames[now.weekday - 1];
    final dayStr = now.day.toString().padLeft(2, '0');
    final monthStr = now.month.toString().padLeft(2, '0');
    final yearStr = now.year.toString().substring(2);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // LEVO - DATUM
        Text(
          '$dayStr.$monthStr.$yearStr',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onPrimary,
            shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)],
          ),
        ),
        // SREDINA - DAN
        Text(
          dayName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onPrimary,
            shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)],
          ),
        ),
        // DESNO - VREME
        ClockTicker(
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onPrimary,
            shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)],
          ),
          showSeconds: true,
        ),
      ],
    );
  }

  // 🔘 AppBar dugme
  Widget _buildAppBarButton({
    String? label,
    IconData? icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 14)
              : Text(
                  label ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  // 📊 Statistika kocka
  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      height: 69,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getBorderColor(color)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper za border boju kao u danas_screen
  Color _getBorderColor(Color color) {
    if (color == Colors.green) return Colors.green[300]!;
    if (color == Colors.purple) return Colors.purple[300]!;
    if (color == Colors.red) return Colors.red[300]!;
    if (color == Colors.orange) return Colors.orange[300]!;
    return color.withValues(alpha: 0.6);
  }
}
