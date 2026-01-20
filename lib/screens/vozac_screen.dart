import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // 🗺️ Za GPS poziciju

import '../config/route_config.dart';
import '../globals.dart';
import '../models/putnik.dart';
import '../services/auth_manager.dart';
import '../services/daily_checkin_service.dart';
import '../services/driver_location_service.dart'; // 🚐 Za ETA tracking
import '../services/firebase_service.dart'; // 🎯 Za vozača
import '../services/kapacitet_service.dart'; // 🎫 Za broj mesta
import '../services/local_notification_service.dart'; // 🔔 Za lokalne notifikacije
import '../services/popis_service.dart'; // 📋 Za popis dana
import '../services/putnik_push_service.dart'; // 📱 Za push notifikacije putnicima
import '../services/putnik_service.dart';
import '../services/realtime_gps_service.dart'; // 🛰️ Za GPS tracking
import '../services/realtime_notification_service.dart'; // 🔔 Za realtime notifikacije
import '../services/smart_navigation_service.dart';
import '../services/statistika_service.dart';
import '../services/theme_manager.dart';
import '../utils/grad_adresa_validator.dart'; // 🏘️ Za validaciju gradova
import '../utils/putnik_count_helper.dart'; // 🔢 Za brojanje putnika po gradu
import '../utils/schedule_utils.dart';
import '../utils/text_utils.dart'; // 🎯 Za TextUtils.isStatusActive
import '../utils/vozac_boja.dart'; // 🎯 Za validaciju vozača
import '../widgets/bottom_nav_bar_letnji.dart';
import '../widgets/bottom_nav_bar_praznici.dart';
import '../widgets/bottom_nav_bar_zimski.dart';
import '../widgets/clock_ticker.dart';
import '../widgets/putnik_list.dart';
import 'dugovi_screen.dart';
import 'welcome_screen.dart';

/// 🚗 VOZAČ SCREEN - Za Ivan-a
/// Prikazuje putnike koristeći isti PutnikService stream kao DanasScreen
class VozacScreen extends StatefulWidget {
  /// Opcioni parametar - ako je null, koristi trenutnog ulogovanog vozača
  /// Ako je prosleđen, prikazuje ekran kao da je taj vozač ulogovan (admin preview)
  final String? previewAsDriver;

  const VozacScreen({Key? key, this.previewAsDriver}) : super(key: key);

  @override
  State<VozacScreen> createState() => _VozacScreenState();
}

class _VozacScreenState extends State<VozacScreen> {
  final String _vozacIme = 'Ivan';
  final PutnikService _putnikService = PutnikService();

  StreamSubscription<Position>? _driverPositionSubscription;

  String _selectedGrad = 'Bela Crkva';
  String _selectedVreme = '5:00';

  // 🎯 OPTIMIZACIJA RUTE - kopirano iz DanasScreen
  bool _isRouteOptimized = false;
  List<Putnik> _optimizedRoute = [];
  bool _isLoading = false;
  Map<Putnik, Position>? _cachedCoordinates; // 🎯 Keširane koordinate

  /// 📅 HELPER: Vraća radni datum - vikendom vraća naredni ponedeljak
  String _getWorkingDateIso() {
    final today = DateTime.now();
    // Vikendom (subota=6, nedelja=7) koristi naredni ponedeljak
    if (today.weekday == DateTime.saturday) {
      return today.add(const Duration(days: 2)).toIso8601String().split('T')[0];
    } else if (today.weekday == DateTime.sunday) {
      return today.add(const Duration(days: 1)).toIso8601String().split('T')[0];
    }
    return today.toIso8601String().split('T')[0];
  }

  String? _currentDriver; // 🎯 Trenutni vozač

  // Status varijable
  String _navigationStatus = ''; // ignore: unused_field
  int _currentPassengerIndex = 0; // ignore: unused_field
  bool _isListReordered = false;
  bool _isGpsTracking = false; // 🛰️ GPS tracking status
  bool _isPopisLoading = false; // 📋 Loading state za POPIS dugme

  // 🕒 THROTTLING ZA REALTIME SYNC - sprečava prekomerne UI rebuilde
  // ✅ Povećano na 800ms da spreči race conditions, ali i dalje dovoljno brzo za UX
  DateTime? _lastSyncTime;
  static const Duration _syncThrottleDuration = Duration(milliseconds: 800);

  // 🔄 PENDING SYNC - čuva poslednje promene ako je throttling aktivan
  List<Putnik>? _pendingSyncPutnici;

  // 🔒 LOCK ZA KONKURENTNE REOPTIMIZACIJE
  bool _isReoptimizing = false;

  // 🕐 DINAMIČKA VREMENA - prate navBarTypeNotifier (praznici/zimski/letnji)
  List<String> get _bcVremena {
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

  List<String> get _vsVremena {
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
    _driverPositionSubscription = RealtimeGpsService.positionStream.listen((pos) {});
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
  }

  Future<void> _initializeCurrentDriver() async {
    // 🎯 ADMIN PREVIEW MODE: Ako je prosleđen previewAsDriver, koristi ga
    if (widget.previewAsDriver != null && widget.previewAsDriver!.isNotEmpty) {
      _currentDriver = widget.previewAsDriver;
      if (mounted) setState(() {});
      return;
    }

    _currentDriver = await FirebaseService.getCurrentDriver();
    // 🆘 FALLBACK: Ako FirebaseService ne vrati vozača, koristi _vozacIme (Ivan)
    if (_currentDriver == null || _currentDriver!.isEmpty) {
      _currentDriver = _vozacIme; // 'Ivan'
      // ✅ FIX: Koristi AuthManager da bi se ažurirao i push token
      await AuthManager.setCurrentDriver(_vozacIme);
    }
    if (mounted) setState(() {});
  }

  // 🔧 IDENTIČNA LOGIKA SA DANAS SCREEN - konvertuj ISO datum u kraći dan
  String _isoDateToDayAbbr(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      const dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      return dani[date.weekday - 1];
    } catch (e) {
      return 'pon'; // fallback
    }
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

  // 🎯 REOPTIMIZACIJA RUTE NAKON PROMENE STATUSA PUTNIKA
  Future<void> _reoptimizeAfterStatusChange() async {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty) return;

    // 🔄 BATCH DOHVATI SVEŽE PODATKE IZ BAZE - efikasnije od pojedinačnih poziva
    final putnikService = PutnikService();
    final ids = _optimizedRoute.where((p) => p.id != null).map((p) => p.id!).toList();
    final sveziPutnici = await putnikService.getPutniciByIds(ids);

    // 🔄 UJEDNAČENO SA DANAS_SCREEN: Razdvoji pokupljene/otkazane/tuđe od preostalih
    final pokupljeniIOtkazani = sveziPutnici.where((p) {
      final jeTudji = p.dodeljenVozac != null && p.dodeljenVozac!.isNotEmpty && p.dodeljenVozac != _currentDriver;
      return p.jePokupljen || p.jeOtkazan || p.jeOdsustvo || jeTudji;
    }).toList();

    final preostaliPutnici = sveziPutnici.where((p) {
      final jeTudji = p.dodeljenVozac != null && p.dodeljenVozac!.isNotEmpty && p.dodeljenVozac != _currentDriver;
      return !p.jePokupljen && !p.jeOtkazan && !p.jeOdsustvo && !jeTudji;
    }).toList();

    if (preostaliPutnici.isEmpty) {
      // Svi putnici su pokupljeni ili otkazani - ZADRŽI ih u listi

      // ✅ STOP TRACKING AKO SU SVI GOTOVI
      if (DriverLocationService.instance.isTracking) {
        await DriverLocationService.instance.updatePutniciEta({});
      }

      if (mounted) {
        setState(() {
          _optimizedRoute = pokupljeniIOtkazani; // ✅ ZADRŽI pokupljene u listi
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
            // ✅ KOMBINUJ: optimizovani preostali + pokupljeni/otkazani na kraju
            _optimizedRoute = [...result.optimizedPutnici!, ...pokupljeniIOtkazani];
            _currentPassengerIndex = 0;
          });

          // 🔄 REALTIME FIX: Ažuriraj ETA (uklanja pokupljene sa mape)
          if (DriverLocationService.instance.isTracking && result.putniciEta != null) {
            await DriverLocationService.instance.updatePutniciEta(result.putniciEta!);
          }

          if (!mounted) return;

          final sledeci = result.optimizedPutnici!.isNotEmpty ? result.optimizedPutnici!.first.ime : 'N/A';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔄 Ruta ažurirana! Sledeći: $sledeci (${preostaliPutnici.length} preostalo)'),
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

  // 🔄 SINHRONIZACIJA OPTIMIZOVANE RUTE SA REALTIME STREAM-om
  // Ažurira statuse putnika u optimizovanoj listi kada se promene u bazi
  // ✅ SA THROTTLING-om: Sprečava prekomerne UI rebuilde (max 2x/sec)
  // ✅ AUTO-REOPTIMIZACIJA: Kada se doda ili otkaže putnik, automatski reoptimizuje rutu
  void _syncOptimizedRouteWithStream(List<Putnik> streamPutnici) {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty) return;

    // 🕒 THROTTLING: Ignoriši ako je prošlo manje od 800ms od poslednje sinhronizacije
    // ✅ ALI: Sačuvaj pending podatke za sledeći sync
    final now = DateTime.now();
    if (_lastSyncTime != null && now.difference(_lastSyncTime!) < _syncThrottleDuration) {
      _pendingSyncPutnici = streamPutnici; // Sačuvaj za kasnije
      // Zakaži odloženi sync ako nije već zakazan
      Future.delayed(_syncThrottleDuration, () {
        if (_pendingSyncPutnici != null && mounted) {
          final pending = _pendingSyncPutnici!;
          _pendingSyncPutnici = null;
          _syncOptimizedRouteWithStream(pending);
        }
      });
      return;
    }
    _lastSyncTime = now;
    _pendingSyncPutnici = null; // Očisti pending jer procesiramo sada

    // Kreiraj Set ID-ova iz stream-a za brzu pretragu
    final streamIds = streamPutnici.map((p) => p.id).toSet();
    final optimizedIds = _optimizedRoute.map((p) => p.id).toSet();

    bool hasChanges = false;
    bool hasNewPassengers = false;
    bool hasCancelledOrDeleted = false;
    final newPassengerNames = <String>[];
    final cancelledNames = <String>[];
    final updatedRoute = <Putnik>[];

    // 1️⃣ Ažuriraj postojeće putnike i detektuj obrisane/otkazane
    for (final optimizedPutnik in _optimizedRoute) {
      // Proveri da li putnik još postoji u stream-u
      if (!streamIds.contains(optimizedPutnik.id)) {
        // 🗑️ Putnik obrisan iz baze
        hasChanges = true;
        hasCancelledOrDeleted = true;
        cancelledNames.add(optimizedPutnik.ime);
        continue;
      }

      // Pronađi putnika u stream-u po ID-u
      final streamPutnik = streamPutnici.firstWhere(
        (p) => p.id == optimizedPutnik.id,
      );

      // Proveri da li je putnik UPRAVO otkazan (bio aktivan, sada nije)
      final wasActive = !optimizedPutnik.jeOtkazan && !optimizedPutnik.jeOdsustvo;
      final isNowCancelled = streamPutnik.jeOtkazan || streamPutnik.jeOdsustvo;
      if (wasActive && isNowCancelled) {
        hasCancelledOrDeleted = true;
        cancelledNames.add(streamPutnik.ime);
      }

      // Proveri da li se status promenio
      if (streamPutnik.jePokupljen != optimizedPutnik.jePokupljen ||
          streamPutnik.jeOtkazan != optimizedPutnik.jeOtkazan ||
          streamPutnik.jeOdsustvo != optimizedPutnik.jeOdsustvo ||
          streamPutnik.status != optimizedPutnik.status) {
        hasChanges = true;
        updatedRoute.add(streamPutnik);
      } else {
        updatedRoute.add(optimizedPutnik);
      }
    }

    // 2️⃣ Detektuj nove putnike koji nisu u optimizovanoj ruti
    // 🔧 FIX: Filtriraj nove putnike SAMO za trenutni grad i vreme
    final newPassengers = <Putnik>[];
    final normFilterTime = GradAdresaValidator.normalizeTime(_selectedVreme);
    for (final streamPutnik in streamPutnici) {
      if (!optimizedIds.contains(streamPutnik.id)) {
        // ✅ Proveri da li putnik pripada trenutnom gradu i vremenu
        final normStreamTime = GradAdresaValidator.normalizeTime(streamPutnik.polazak);
        final vremeMatch = normStreamTime == normFilterTime;

        // Koristi istu logiku kao u filteru ispod
        final isRegistrovaniPutnik = streamPutnik.mesecnaKarta == true;
        bool gradMatch;
        if (isRegistrovaniPutnik) {
          gradMatch = streamPutnik.grad == _selectedGrad;
        } else {
          gradMatch = GradAdresaValidator.isGradMatch(streamPutnik.grad, streamPutnik.adresa, _selectedGrad);
        }

        // ✅ Samo aktivni putnici (ne otkazani/obrisani)
        final isActive = !streamPutnik.jeOtkazan && !streamPutnik.jeOdsustvo && !streamPutnik.obrisan;

        if (vremeMatch && gradMatch && isActive) {
          hasNewPassengers = true;
          newPassengers.add(streamPutnik);
          newPassengerNames.add(streamPutnik.ime);
        }
      }
    }

    // 🆕 AUTO-REOPTIMIZACIJA: Ako ima novih ILI otkazanih putnika
    if ((hasNewPassengers || hasCancelledOrDeleted) && mounted) {
      // Prikaži notifikaciju
      String message;
      Color bgColor;
      if (hasNewPassengers && hasCancelledOrDeleted) {
        message = '🔄 Promene: +${newPassengerNames.join(", ")} / -${cancelledNames.join(", ")} - Reoptimizujem...';
        bgColor = Colors.purple;
      } else if (hasNewPassengers) {
        message = '🆕 Novi putnik: ${newPassengerNames.join(", ")} - Reoptimizujem rutu...';
        bgColor = Colors.blue;
      } else {
        message = '❌ Otkazano: ${cancelledNames.join(", ")} - Reoptimizujem rutu...';
        bgColor = Colors.orange;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: bgColor,
          duration: const Duration(seconds: 2),
        ),
      );

      // Kombinuj postojeće + nove putnike i pokreni reoptimizaciju
      final allPassengers = [...updatedRoute, ...newPassengers];
      _autoReoptimizeRoute(allPassengers);
      return; // Ne ažuriraj state ovde, _autoReoptimizeRoute će to uraditi
    }

    // Samo ažuriraj ako ima promena (bez novih/otkazanih putnika)
    if (hasChanges && mounted) {
      setState(() {
        _optimizedRoute = updatedRoute;
      });
    }
  }

  // 🔄 AUTO-REOPTIMIZACIJA RUTE SA NOVIM PUTNICIMA
  // Poziva OSRM da dobije novu optimalnu rutu
  // ✅ SA LOCK MEHANIZMOM: Sprečava konkurentne reoptimizacije
  // ✅ ČUVA pokupljene/otkazane putnike na kraju liste
  Future<void> _autoReoptimizeRoute(List<Putnik> allPassengers) async {
    // 🔒 LOCK: Ako je već u toku reoptimizacija, preskoči
    if (_isReoptimizing) {
      return;
    }
    _isReoptimizing = true;

    try {
      // 🔄 Razdvoji pokupljene/otkazane/tuđe od aktivnih putnika
      final pokupljeniIOtkazani = allPassengers.where((p) {
        final jeTudji = p.dodeljenVozac != null && p.dodeljenVozac!.isNotEmpty && p.dodeljenVozac != _currentDriver;
        return p.jePokupljen || p.jeOtkazan || p.jeOdsustvo || jeTudji;
      }).toList();

      // Filtriraj samo AKTIVNE putnike sa validnim adresama za optimizaciju
      final filtriraniPutnici = allPassengers.where((p) {
        final hasValidAddress = (p.adresaId != null && p.adresaId!.isNotEmpty) ||
            (p.adresa != null && p.adresa!.isNotEmpty && p.adresa != p.grad);
        // 🔘 Isključi pokupljene, otkazane i tuđe putnike
        final jeTudji = p.dodeljenVozac != null && p.dodeljenVozac!.isNotEmpty && p.dodeljenVozac != _currentDriver;
        final isActive = !p.jePokupljen && !p.jeOtkazan && !p.jeOdsustvo && !jeTudji;
        return hasValidAddress && isActive;
      }).toList();

      // ✅ Ako nema aktivnih putnika, zadrži samo pokupljene/otkazane
      if (filtriraniPutnici.isEmpty) {
        if (pokupljeniIOtkazani.isNotEmpty && mounted) {
          setState(() {
            _optimizedRoute = pokupljeniIOtkazani;
          });
        }
        return;
      }

      final result = await SmartNavigationService.optimizeRouteOnly(
        putnici: filtriraniPutnici,
        startCity: _selectedGrad.isNotEmpty ? _selectedGrad : 'Vršac',
      );

      if (result.success && result.optimizedPutnici != null && result.optimizedPutnici!.isNotEmpty) {
        if (mounted) {
          setState(() {
            // ✅ KOMBINUJ: optimizovani aktivni + pokupljeni/otkazani na kraju
            _optimizedRoute = [...result.optimizedPutnici!, ...pokupljeniIOtkazani];
            _cachedCoordinates = result.cachedCoordinates;
          });

          // 🔄 REALTIME FIX: Ažuriraj ETA bez restarta trackinga
          if (DriverLocationService.instance.isTracking && result.putniciEta != null) {
            await DriverLocationService.instance.updatePutniciEta(result.putniciEta!);
          }

          // ✅ FIX: Ponovna provera mounted posle await operacije
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Ruta uspešno reoptimizovana sa novim putnikom!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Greška pri reoptimizaciji - zadrži postojeću rutu
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Greška pri reoptimizaciji: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // 🔓 UNLOCK: Uvek oslobodi lock
      _isReoptimizing = false;
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
                Text(
                    '🎯 Broj putnika: ${_optimizedRoute.where((p) => TextUtils.isStatusActive(p.status) && !p.jePokupljen).length}'),
              ],
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    // Filter putnika sa validnim adresama i aktivnim statusom
    final filtriraniPutnici = putnici.where((p) {
      // Isključi otkazane putnike
      if (p.jeOtkazan) return false;
      // Isključi već pokupljene putnike
      if (p.jePokupljen) return false;
      // Isključi odsutne putnike (bolovanje/godišnji)
      if (p.jeOdsustvo) return false;
      // 🔘 Isključi tuđe putnike (dodeljeni drugom vozaču)
      if (p.dodeljenVozac != null && p.dodeljenVozac!.isNotEmpty && p.dodeljenVozac != _currentDriver) {
        return false;
      }
      // Proveri validnu adresu
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

        // 🆕 Dodaj putnike BEZ ADRESE na početak liste kao podsetnik
        final skippedPutnici = result.skippedPutnici ?? [];
        final finalRoute = [...skippedPutnici, ...optimizedPutnici];

        if (mounted) {
          setState(() {
            _optimizedRoute = finalRoute; // Preskočeni + optimizovani
            _cachedCoordinates = result.cachedCoordinates; // 🎯 Sačuvaj koordinate
            _isRouteOptimized = true;
            _isListReordered = true;
            _currentPassengerIndex = 0;
            _isLoading = false;
          });
        }

        // 🚐 AUTOMATSKI POKRENI GPS TRACKING nakon optimizacije
        if (_currentDriver != null && result.putniciEta != null) {
          await _startGpsTracking();
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
                  Text(
                      '🎯 Broj putnika: ${optimizedPutnici.where((p) => TextUtils.isStatusActive(p.status) && !p.jePokupljen).length}'),
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
        // ❌ OSRM/SmartNavigationService nije uspeo - NE koristi fallback, prikaži grešku
        if (mounted) {
          setState(() {
            _isLoading = false;
            // NE postavljaj _isRouteOptimized = true jer ruta NIJE optimizovana!
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Optimizacija neuspešna: ${result.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
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

  // 🚀 KOMPAKTNO DUGME ZA GPS TRACKING
  // ✅ TOGGLE: Pokreće ili zaustavlja GPS tracking u pozadini
  Widget _buildOptimizeButton() {
    return StreamBuilder<List<Putnik>>(
      // ✅ Koristi isti stream kao ostatak screen-a
      stream: _putnikService.streamPutnici(),
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

        // 🎯 Filtriraj putnike po gradu i vremenu
        final sviPutnici = snapshot.data ?? [];

        // 🔄 REALTIME SYNC: Ažuriraj statuse u optimizovanoj ruti
        if (_isRouteOptimized && sviPutnici.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncOptimizedRouteWithStream(sviPutnici);
          });
        }

        final normFilterTime = GradAdresaValidator.normalizeTime(_selectedVreme);
        final filtriraniPutnici = sviPutnici.where((p) {
          // Vreme filter
          final pTime = GradAdresaValidator.normalizeTime(p.polazak);
          if (pTime != normFilterTime) return false;

          // Grad filter
          final isRegistrovaniPutnik = p.mesecnaKarta == true;
          bool gradMatch;
          if (isRegistrovaniPutnik) {
            gradMatch = p.grad == _selectedGrad;
          } else {
            gradMatch = GradAdresaValidator.isGradMatch(p.grad, p.adresa, _selectedGrad);
          }
          if (!gradMatch) return false;

          // Status filter - samo aktivni
          if (!TextUtils.isStatusActive(p.status)) return false;

          // 🎯 Boja filter - samo bele kartice (nepokupljeni)
          if (p.jePokupljen) return false;

          return true;
        }).toList();

        final hasPassengers = filtriraniPutnici.isNotEmpty;
        final bool isDriverValid = _currentDriver != null && VozacBoja.isValidDriver(_currentDriver);

        return SizedBox(
          height: 26,
          child: ElevatedButton(
            onPressed: _isLoading || !isDriverValid
                ? null
                : () {
                    if (_isGpsTracking) {
                      // ZAUSTAVI GPS tracking
                      _stopGpsTracking();
                    } else if (_isRouteOptimized) {
                      // POKRENI GPS tracking
                      _startGpsTracking();
                    } else {
                      // OPTIMIZUJ RUTU + POKRENI GPS tracking
                      _optimizeCurrentRoute(filtriraniPutnici, isAlreadyOptimized: false);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isGpsTracking
                  ? Colors.orange.shade700
                  : (_isRouteOptimized
                      ? Colors.green.shade600
                      : (hasPassengers ? Theme.of(context).primaryColor : Colors.grey.shade400)),
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: hasPassengers ? 2 : 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _isGpsTracking ? 'STOP' : 'START',
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

  // 🗺️ DUGME ZA NAVIGACIJU - OTVARA HERE WeGo SA REDOSLEDOM IZ OPTIMIZOVANE RUTE
  Widget _buildMapsButton() {
    final hasOptimizedRoute = _isRouteOptimized && _optimizedRoute.isNotEmpty;
    final bool isDriverValid = _currentDriver != null && VozacBoja.isValidDriver(_currentDriver);
    return SizedBox(
      height: 26,
      child: ElevatedButton(
        onPressed: hasOptimizedRoute && isDriverValid ? _openHereWeGoNavigation : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: hasOptimizedRoute ? Colors.blue.shade600 : Colors.grey.shade400,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: hasOptimizedRoute ? 2 : 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.navigation,
                size: 10,
                color: Colors.white,
              ),
              SizedBox(width: 2),
              Text(
                'NAV',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🚀 POKRENI GPS TRACKING (ruta je već optimizovana)
  Future<void> _startGpsTracking() async {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty || _currentDriver == null) return;

    try {
      final smer = _selectedGrad.toLowerCase().contains('bela') || _selectedGrad == 'BC' ? 'BC_VS' : 'VS_BC';

      // Konvertuj koordinate: Map<Putnik, Position> -> Map<String, Position>
      Map<String, Position>? coordsByName;
      if (_cachedCoordinates != null) {
        coordsByName = {};
        for (final entry in _cachedCoordinates!.entries) {
          coordsByName[entry.key.ime] = entry.value;
        }
      }

      // Izvuci redosled imena putnika
      final putniciRedosled = _optimizedRoute.map((p) => p.ime).toList();

      // Izračunaj ETA za putnike ako već nisu dostupni
      Map<String, int>? putniciEta;
      if (_cachedCoordinates != null && _cachedCoordinates!.isNotEmpty) {
        // Kreiraj simulirane ETA vrednosti na osnovu redosleda (svaki putnik +3 minuta)
        putniciEta = {};
        int cumulativeMinutes = 3;
        for (final putnik in _optimizedRoute) {
          putniciEta[putnik.ime] = cumulativeMinutes;
          cumulativeMinutes += 3;
        }
      }

      await DriverLocationService.instance.startTracking(
        vozacId: _currentDriver!,
        vozacIme: _currentDriver!,
        grad: _selectedGrad,
        vremePolaska: _selectedVreme,
        smer: smer,
        putniciEta: putniciEta,
        putniciCoordinates: coordsByName,
        putniciRedosled: putniciRedosled,
        onAllPassengersPickedUp: () {
          if (mounted) {
            setState(() {
              _isGpsTracking = false;
              _navigationStatus = '';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Svi putnici pokupljeni! Tracking automatski zaustavljen.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        },
      );

      if (mounted) {
        setState(() => _isGpsTracking = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚀 GPS tracking pokrenut! Putnici dobijaju realtime lokaciju.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // 📱 POŠALJI PUSH NOTIFIKACIJE PUTNICIMA
      if (putniciEta != null) {
        await _sendTransportStartedNotifications(
          putniciEta: putniciEta,
          vozacIme: _currentDriver!,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška pri pokretanju GPS trackinga: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🛑 ZAUSTAVI GPS TRACKING
  void _stopGpsTracking() {
    DriverLocationService.instance.stopTracking();

    if (mounted) {
      setState(() {
        _isGpsTracking = false;
        _navigationStatus = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛑 GPS tracking zaustavljen'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // 🗺️ OTVORI HERE WeGo NAVIGACIJU SA OPTIMIZOVANIM REDOSLEDOM
  Future<void> _openHereWeGoNavigation() async {
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
            content: Text('❌ Greška pri otvaranju navigacije: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  // 📊 POPIS DANA - KORISTI CENTRALIZOVANI POPIS SERVICE
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
      // 1. UČITAJ PODATKE PREKO POPIS SERVICE
      final popisData = await PopisService.loadPopisData(
        vozac: vozac,
        selectedGrad: _selectedGrad,
        selectedVreme: _selectedVreme,
      );

      // 2. PRIKAŽI DIALOG
      if (!mounted) return;
      final bool sacuvaj = await PopisService.showPopisDialog(context, popisData);

      // 3. SAČUVAJ AKO JE POTVRĐEN
      if (sacuvaj) {
        await PopisService.savePopis(popisData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Popis je uspešno sačuvan!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dayStart = DateTime(today.year, today.month, today.day);
    final dayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return Container(
      decoration: BoxDecoration(
        gradient: ThemeManager().currentGradient, // 🎨 Theme-aware gradijent
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
                  isoDate: _getWorkingDateIso(),
                  grad: _selectedGrad,
                  vreme: _selectedVreme,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }

                  // 🎯 FILTER: Prikaži SVE putnike na kojima je vozač bio aktivan danas
                  // (dodeljeni, pokupljeni, naplaćeni ili otkazani od strane ovog vozača)
                  final sviPutnici = snapshot.data ?? [];
                  final mojiPutnici = sviPutnici.where((p) {
                    // Dodeljeni putnike
                    if (p.dodeljenVozac == _currentDriver) return true;
                    // Pokupljeni od ovog vozača
                    if (p.pokupioVozac == _currentDriver) return true;
                    // Naplaćeni od ovog vozača
                    if (p.naplatioVozac == _currentDriver) return true;
                    // Otkazani od ovog vozača
                    if (p.otkazaoVozac == _currentDriver) return true;
                    return false;
                  }).toList();

                  final putnici = _isRouteOptimized && _optimizedRoute.isNotEmpty ? _optimizedRoute : mojiPutnici;

                  return Column(
                    children: [
                      // KOCKE - Pazar, Dugovi, Kusur
                      // ✅ ISPRAVKA: Računaj statistike direktno iz liste putnika (kao DanasScreen)
                      Builder(
                        builder: (context) {
                          // 💳 DUŽNICI - putnici sa PLAVOM KARTICOM (nisu mesečni tip) koji nisu platili
                          // ❗ KORISTIMO sviPutnici da bi videli SVE dužnike, ne samo moje
                          final filteredDuzniciRaw = sviPutnici.where((putnik) {
                            final nijeMesecni = !putnik.isMesecniTip;
                            if (!nijeMesecni) return false; // ✅ FIX: Plava kartica = nije mesečni tip

                            final nijePlatio =
                                putnik.vremePlacanja == null; // ✅ FIX: Nije platio ako nema vremePlacanja
                            final nijeOtkazan = putnik.status != 'otkazan' && putnik.status != 'Otkazano';
                            final pokupljen = putnik.jePokupljen;

                            return nijePlatio && nijeOtkazan && pokupljen;
                          }).toList();

                          // ✅ DEDUPLIKACIJA: Jedan putnik može imati više termina, ali je jedan dužnik
                          final seenIds = <dynamic>{};
                          final filteredDuznici = filteredDuzniciRaw.where((p) {
                            final key = p.id ?? '${p.ime}_${p.dan}';
                            if (seenIds.contains(key)) return false;
                            seenIds.add(key);
                            return true;
                          }).toList();

                          return Container(
                            margin: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // PAZAR
                                Expanded(
                                  child: StreamBuilder<double>(
                                    stream: StatistikaService.streamPazarZaVozaca(
                                      vozac: _currentDriver!,
                                      from: dayStart,
                                      to: dayEnd,
                                    ),
                                    builder: (context, snapshot) {
                                      final pazar = snapshot.data ?? 0.0;
                                      return InkWell(
                                        onTap: () {
                                          _showStatPopup(
                                            context,
                                            'Pazar',
                                            pazar.toStringAsFixed(0),
                                            Colors.green,
                                          );
                                        },
                                        child: _buildStatBox(
                                          'Pazar',
                                          pazar.toStringAsFixed(0),
                                          Colors.green,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // DUGOVI - ✅ ISPRAVKA: Koristi filteredDuznici direktno
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (context) => DugoviScreen(currentDriver: _currentDriver!),
                                        ),
                                      );
                                    },
                                    child: _buildStatBox(
                                      'Dugovi',
                                      filteredDuznici.length.toString(),
                                      Colors.red,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // KUSUR
                                Expanded(
                                  child: StreamBuilder<double>(
                                    stream: DailyCheckInService.streamTodayAmount(_currentDriver!),
                                    builder: (context, snapshot) {
                                      final kusur = snapshot.data ?? 0.0;
                                      return InkWell(
                                        onTap: () {
                                          _showStatPopup(
                                            context,
                                            'Kusur',
                                            kusur > 0 ? kusur.toStringAsFixed(0) : '0',
                                            Colors.orange,
                                          );
                                        },
                                        child: _buildStatBox(
                                          'Kusur',
                                          kusur > 0 ? kusur.toStringAsFixed(0) : '-',
                                          Colors.orange,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
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
                                    _currentDriver!, // ✅ FIX: Koristi dinamički _currentDriver umesto hardkodovanog _vozacIme
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
            isoDate: _getWorkingDateIso(),
          ),
          builder: (context, snapshot) {
            final allPutnici = snapshot.data ?? <Putnik>[];

            // 🎯 FILTER: Svi putnici na kojima je vozač bio aktivan
            final mojiPutnici = allPutnici.where((p) {
              if (p.dodeljenVozac == _currentDriver) return true;
              if (p.pokupioVozac == _currentDriver) return true;
              if (p.naplatioVozac == _currentDriver) return true;
              if (p.otkazaoVozac == _currentDriver) return true;
              return false;
            }).toList();

            // 🔧 REFAKTORISANO: Koristi PutnikCountHelper za centralizovano brojanje
            final targetDateIso = _getWorkingDateIso();
            final targetDayAbbr = _isoDateToDayAbbr(targetDateIso);
            final countHelper = PutnikCountHelper.fromPutnici(
              putnici: mojiPutnici,
              targetDateIso: targetDateIso,
              targetDayAbbr: targetDayAbbr,
            );

            int getPutnikCount(String grad, String vreme) {
              return countHelper.getCount(grad, vreme);
            }

            // 🎫 KAPACITET: Broj mesta za svaki polazak (real-time od admina)
            int getKapacitet(String grad, String vreme) {
              return KapacitetService.getKapacitetSync(grad, vreme);
            }

            // 🎯 FILTER VREMENA: Samo vremena koja imaju putnike za ovog vozača
            final filteredBcVremena = _bcVremena.where((vreme) => getPutnikCount('Bela Crkva', vreme) > 0).toList();
            final filteredVsVremena = _vsVremena.where((vreme) => getPutnikCount('Vršac', vreme) > 0).toList();

            // ✅ IZMENA: Uklonjen fallback. Ako nema putnika, liste su prazne.
            final bcVremenaToShow = filteredBcVremena;
            final vsVremenaToShow = filteredVsVremena;

            // ✅ SAKRIJ CEO BOTTOM BAR AKO NEMA VOŽNJI
            if (bcVremenaToShow.isEmpty && vsVremenaToShow.isEmpty) {
              return const SizedBox.shrink();
            }

            // Helper funkcija za kreiranje nav bar-a
            Widget buildNavBar(String navType) {
              switch (navType) {
                case 'praznici':
                  return BottomNavBarPraznici(
                    sviPolasci: _sviPolasci,
                    selectedGrad: _selectedGrad,
                    selectedVreme: _selectedVreme,
                    getPutnikCount: getPutnikCount,
                    getKapacitet: getKapacitet,
                    onPolazakChanged: _onPolazakChanged,
                  );
                case 'zimski':
                  return BottomNavBarZimski(
                    sviPolasci: _sviPolasci,
                    selectedGrad: _selectedGrad,
                    selectedVreme: _selectedVreme,
                    getPutnikCount: getPutnikCount,
                    getKapacitet: getKapacitet,
                    onPolazakChanged: _onPolazakChanged,
                    bcVremena: bcVremenaToShow,
                    vsVremena: vsVremenaToShow,
                  );
                case 'letnji':
                  return BottomNavBarLetnji(
                    sviPolasci: _sviPolasci,
                    selectedGrad: _selectedGrad,
                    selectedVreme: _selectedVreme,
                    getPutnikCount: getPutnikCount,
                    getKapacitet: getKapacitet,
                    onPolazakChanged: _onPolazakChanged,
                    bcVremena: bcVremenaToShow,
                    vsVremena: vsVremenaToShow,
                  );
                default: // 'auto'
                  return isZimski(DateTime.now())
                      ? BottomNavBarZimski(
                          sviPolasci: _sviPolasci,
                          selectedGrad: _selectedGrad,
                          selectedVreme: _selectedVreme,
                          getPutnikCount: getPutnikCount,
                          getKapacitet: getKapacitet,
                          onPolazakChanged: _onPolazakChanged,
                          bcVremena: bcVremenaToShow,
                          vsVremena: vsVremenaToShow,
                        )
                      : BottomNavBarLetnji(
                          sviPolasci: _sviPolasci,
                          selectedGrad: _selectedGrad,
                          selectedVreme: _selectedVreme,
                          getPutnikCount: getPutnikCount,
                          getKapacitet: getKapacitet,
                          onPolazakChanged: _onPolazakChanged,
                          bcVremena: bcVremenaToShow,
                          vsVremena: vsVremenaToShow,
                        );
              }
            }

            return ValueListenableBuilder<String>(
              valueListenable: navBarTypeNotifier,
              builder: (context, navType, _) => buildNavBar(navType),
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
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getBorderColor(color)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // 📊 POPUP ZA PRIKAZ STATISTIKE
  void _showStatPopup(BuildContext context, String label, String value, Color color) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _getBorderColor(color)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Zatvori',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
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

  // 📱 POŠALJI PUSH NOTIFIKACIJE PUTNICIMA KADA VOZAC KRENE
  Future<void> _sendTransportStartedNotifications({
    required Map<String, int> putniciEta,
    required String vozacIme,
  }) async {
    try {
      // Dohvati tokene za sve putnike
      final putnikImena = putniciEta.keys.toList();
      final tokens = await PutnikPushService.getTokensForPutnici(putnikImena);

      if (tokens.isEmpty) {
        return;
      }

      // Pošalji notifikaciju svakom putniku
      for (final entry in tokens.entries) {
        final putnikIme = entry.key;
        final tokenInfo = entry.value;
        final eta = putniciEta[putnikIme] ?? 0;

        await RealtimeNotificationService.sendPushNotification(
          title: '🚐 Kombi je krenuo!',
          body: 'Vozač $vozacIme kreće ka vama. Stiže za ~$eta min.\n📍 Možete pratiti uživo klikom ovde!',
          tokens: [
            {'token': tokenInfo['token']!, 'provider': tokenInfo['provider']!}
          ],
          data: {
            'type': 'transport_started',
            'eta_minutes': eta,
            'vozac': vozacIme,
            'putnik_ime': putnikIme,
          },
        );
      }
    } catch (e) {
      // Error sending notifications
    }
  }
}
