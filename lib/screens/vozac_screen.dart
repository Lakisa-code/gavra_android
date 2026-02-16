import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // 🛰️ Za GPS poziciju

import '../config/route_config.dart';
import '../globals.dart';
import '../models/putnik.dart';
import '../services/auth_manager.dart';
import '../services/daily_checkin_service.dart';
import '../services/driver_location_service.dart'; // 📍 Za ETA tracking
import '../services/firebase_service.dart'; // 👤 Za vozača
import '../services/kapacitet_service.dart'; // 🎫 Za broj mesta
import '../services/local_notification_service.dart'; // 🔔 Za lokalne notifikacije
import '../services/popis_service.dart'; // 📝 Za popis dana
import '../services/putnik_service.dart';
import '../services/realtime_gps_service.dart'; // 🛰️ Za GPS tracking
import '../services/realtime_notification_service.dart'; // 🔔 Za realtime notifikacije
import '../services/smart_navigation_service.dart';
import '../services/statistika_service.dart';
import '../services/theme_manager.dart';
import '../services/vreme_vozac_service.dart'; // 🕒 Za dodeljena vremena vozača
import '../utils/grad_adresa_validator.dart'; // 🏘️ Za validaciju gradova
import '../utils/putnik_count_helper.dart'; // 🔢 Za brojanje putnika po gradu
import '../utils/putnik_helpers.dart'; // 🛠️ Centralizovani helperi
import '../utils/schedule_utils.dart';
import '../utils/text_utils.dart'; // 📝 Za TextUtils.isStatusActive
import '../utils/vozac_boja.dart'; // 🎨 Za validaciju vozača
import '../widgets/bottom_nav_bar_letnji.dart';
import '../widgets/bottom_nav_bar_praznici.dart';
import '../widgets/bottom_nav_bar_zimski.dart';
import '../widgets/clock_ticker.dart';
import '../widgets/putnik_list.dart';
import '../widgets/shimmer_widgets.dart';
import 'dugovi_screen.dart';
import 'welcome_screen.dart';

/// 🚛 VOZAČ SCREEN
/// Prikazuje putnike koristeći isti PutnikService stream kao DanasScreen
class VozacScreen extends StatefulWidget {
  /// Opcioni parametar - ako je null, koristi trenutnog ulogovanog vozaca
  /// Ako je prosleden, prikazuje ekran kao da je taj vozac ulogovan (admin preview)
  final String? previewAsDriver;

  const VozacScreen({super.key, this.previewAsDriver});

  @override
  State<VozacScreen> createState() => _VozacScreenState();
}

class _VozacScreenState extends State<VozacScreen> {
  final PutnikService _putnikService = PutnikService();

  StreamSubscription<Position>? _driverPositionSubscription;

  String _selectedGrad = 'Bela Crkva';
  String _selectedVreme = '5:00';

  // 📍 OPTIMIZACIJA RUTE - kopirano iz DanasScreen
  bool _isRouteOptimized = false;
  List<Putnik> _optimizedRoute = [];
  final bool _isLoading = false;
  bool _isOptimizing = false; // ⏳ Loading state specifično za optimizaciju rute

  /// 📅 HELPER: Vraća radni datum - vikendom vraća naredni ponedeljak
  String _getWorkingDateIso() => PutnikHelpers.getWorkingDateIso();

  /// 📅 HELPER: Vraća radni DateTime - vikendom vraća naredni ponedeljak
  DateTime _getWorkingDateTime() => PutnikHelpers.getWorkingDateTime();

  /// 🕒 HELPER: Dobij dodeljena vremena za trenutnog vozača
  List<Map<String, String>> _getDodeljenaVremena({List<Putnik>? sviPutnici}) {
    if (_currentDriver == null) return [];

    final vozaciZaDan = VremeVozacService().getVozaciZaDanSync(_isoDateToDayAbbr(_getWorkingDateIso()));
    final dodeljena = <Map<String, String>>[];

    // 1. Dodaj vremena iz globalnog rasporeda (VremeVozac table)
    vozaciZaDan.forEach((key, vozac) {
      if (vozac == _currentDriver) {
        final parts = key.split('|');
        if (parts.length == 2) {
          dodeljena.add({
            'grad': parts[0],
            'vreme': parts[1],
          });
        }
      }
    });

    // 2. Dodaj vremena iz individualnih dodela (ako imamo putnike)
    if (sviPutnici != null) {
      for (var p in sviPutnici) {
        if (p.dodeljenVozac == _currentDriver) {
          final pGrad = p.grad;
          final pPolazak = p.polazak;

          // Proveri da li vec imamo ovo vreme u listi
          bool postoji = dodeljena.any((v) => v['grad'] == pGrad && v['vreme'] == pPolazak);
          if (!postoji) {
            dodeljena.add({
              'grad': pGrad,
              'vreme': pPolazak,
            });
          }
        }
      }
    }

    // Sortiraj po vremenu
    dodeljena.sort((a, b) {
      final aTime = a['vreme']!;
      final bTime = b['vreme']!;
      return aTime.compareTo(bTime);
    });

    return dodeljena;
  }

  String? _currentDriver; // 👤 Trenutni vozač

  // Status varijable
  String _navigationStatus = ''; // ignore: unused_field
  int _currentPassengerIndex = 0; // ignore: unused_field
  bool _isListReordered = false;
  bool _isGpsTracking = false; // 🛰️ GPS tracking status
  bool _isPopisLoading = false; // ⏳ Loading state za POPIS dugme
  bool _isPopisSaved = false; // ✅ Da li je popis već sačuvan danas

  // 🕒 THROTTLING ZA REALTIME SYNC - sprečava prekomerne UI rebuilde
  // ⚡ Povećano na 800ms da spreči race conditions, ali i dalje dovoljno brzo za UX
  DateTime? _lastSyncTime;
  static const Duration _syncThrottleDuration = Duration(milliseconds: 800);

  // 📝 PENDING SYNC - čuva poslednje promene ako je throttling aktivan
  List<Putnik>? _pendingSyncPutnici;

  // 🔐 LOCK ZA KONKURENTNE REOPTIMIZACIJE
  bool _isReoptimizing = false;

  // 🕐 DINAMIČKA VREMENA - prate navBarTypeNotifier (praznici/zimski/letnji)
  List<String> get _bcVremena {
    final navType = navBarTypeNotifier.value;
    String sezona;

    switch (navType) {
      case 'praznici':
        sezona = 'praznici';
        break;
      case 'zimski':
        sezona = 'zimski';
        break;
      case 'letnji':
        sezona = 'letnji';
        break;
      default: // 'auto'
        sezona = isZimski(DateTime.now()) ? 'zimski' : 'letnji';
    }

    // Use RouteConfig for schedule times
    return (sezona == 'praznici'
        ? RouteConfig.bcVremenaPraznici
        : sezona == 'zimski'
            ? RouteConfig.bcVremenaZimski
            : RouteConfig.bcVremenaLetnji);
  }

  List<String> get _vsVremena {
    final navType = navBarTypeNotifier.value;
    String sezona;

    switch (navType) {
      case 'praznici':
        sezona = 'praznici';
        break;
      case 'zimski':
        sezona = 'zimski';
        break;
      case 'letnji':
        sezona = 'letnji';
        break;
      default: // 'auto'
        sezona = isZimski(DateTime.now()) ? 'zimski' : 'letnji';
    }

    // Use RouteConfig for schedule times
    return (sezona == 'praznici'
        ? RouteConfig.vsVremenaPraznici
        : sezona == 'zimski'
            ? RouteConfig.vsVremenaZimski
            : RouteConfig.vsVremenaLetnji);
  }

  List<String> get _sviPolasci {
    final bcList = _bcVremena.map((v) => '$v Bela Crkva').toList();
    final vsList = _vsVremena.map((v) => '$v Vršac').toList();
    return [...bcList, ...vsList];
  }

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  Future<void> _initAsync() async {
    // 1. Prvo učitaj dodeljena vremena (vreme_vozac tabela)
    await _loadVremeVozacData();

    // 2. Inicijalizuj vozača (ovo će takođe pozvati _selectClosestDeparture)
    await _initializeCurrentDriver();

    // 3. Ostalo
    _initializeNotifications();
    _initializeGpsTracking();
    _checkIfPopisSaved();
  }

  // 🕒 UCITAJ VREME VOZAC PODATKE
  Future<void> _loadVremeVozacData() async {
    await VremeVozacService().loadAllVremeVozac();
  }

  // 🛰️ GPS TRACKING INICIJALIZACIJA
  void _initializeGpsTracking() {
    // Start GPS tracking
    RealtimeGpsService.startTracking().catchError((Object e) {});

    // Subscribe to driver position updates - a�uriraj lokaciju u realnom vremenu
    _driverPositionSubscription = RealtimeGpsService.positionStream.listen((pos) {
      // ?? Po�alji poziciju vozaca u DriverLocationService za pracenje u�ivu
      DriverLocationService.instance.forceLocationUpdate(knownPosition: pos);
    });
  }

  // ?? PROVERA DA LI JE POPIS SACUVAN
  Future<void> _checkIfPopisSaved() async {
    if (_currentDriver == null) return;
    final workingDate = _getWorkingDateTime();
    final isSaved = await DailyCheckInService.isPopisSavedToday(_currentDriver!, date: workingDate);
    if (mounted) {
      setState(() => _isPopisSaved = isSaved);
    }
  }

  @override
  void dispose() {
    _driverPositionSubscription?.cancel();
    super.dispose();
  }

  // ?? INICIJALIZACIJA NOTIFIKACIJA - IDENTICNO KAO DANAS SCREEN
  void _initializeNotifications() {
    // Inicijalizuj heads-up i zvuk notifikacije
    LocalNotificationService.initialize(context);
    // 🔕 UKLONJENO: listener se sada registruje globalno u main.dart
    // RealtimeNotificationService.listenForForegroundNotifications(context);

    // Inicijalizuj realtime notifikacije za vozaca
    FirebaseService.getCurrentDriver().then((driver) {
      if (driver != null && driver.isNotEmpty) {
        RealtimeNotificationService.initialize();
      }
    });
  }

  Future<void> _initializeCurrentDriver() async {
    // ?? ADMIN PREVIEW MODE: Ako je prosleden previewAsDriver, koristi ga
    if (widget.previewAsDriver != null && widget.previewAsDriver!.isNotEmpty) {
      _currentDriver = widget.previewAsDriver;
      if (mounted) {
        setState(() {});
        _selectClosestDeparture();
      }
      return;
    }

    _currentDriver = await FirebaseService.getCurrentDriver();

    if (mounted) {
      setState(() {});
      // 🕒 Nakon što je vozač inicijalizovan, izaberi najbliži polazak
      _selectClosestDeparture();
    }
  }

  // ?? IDENTICNA LOGIKA SA DANAS SCREEN - konvertuj ISO datum u kraci dan
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

  /// 🕒 Bira polazak koji je najbliži trenutnom vremenu iz dodeljenih polazaka
  void _selectClosestDeparture() {
    if (!mounted || _currentDriver == null) return;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    String? closestVreme;
    String? closestGrad;
    int minDifference = 9999;

    // Uzmi samo dodeljena vremena za ovog vozača
    final dodeljenaVremena = _getDodeljenaVremena();
    if (dodeljenaVremena.isEmpty) return;

    for (final v in dodeljenaVremena) {
      final gradStr = v['grad'];
      final timeStr = v['vreme'];
      if (gradStr == null || timeStr == null) continue;

      final timeParts = timeStr.split(':');
      if (timeParts.length != 2) continue;

      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = int.tryParse(timeParts[1]) ?? 0;
      final polazakMinutes = hour * 60 + minute;

      // Razlika u minutima
      final diff = (polazakMinutes - currentMinutes).abs();

      if (diff < minDifference) {
        minDifference = diff;
        closestVreme = timeStr;
        closestGrad = gradStr;
      }
    }

    if (closestVreme != null && closestGrad != null) {
      setState(() {
        _selectedVreme = closestVreme!;
        _selectedGrad = closestGrad!;
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

  // ?? REOPTIMIZACIJA RUTE NAKON PROMENE STATUSA PUTNIKA
  Future<void> _reoptimizeAfterStatusChange() async {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty) return;

    // ?? BATCH DOHVATI SVE�E PODATKE IZ BAZE - efikasnije od pojedinacnih poziva
    final putnikService = PutnikService();
    final ids = _optimizedRoute.where((p) => p.id != null).map((p) => p.id!).toList();
    final sveziPutnici = await putnikService.getPutniciByIds(ids);

    // ?? UJEDNACENO SA DANAS_SCREEN: Razdvoji pokupljene/otkazane/tude od preostalih
    final pokupljeniIOtkazani = sveziPutnici.where((p) {
      final jeTudji = p.dodeljenVozac != null && p.dodeljenVozac!.isNotEmpty && p.dodeljenVozac != _currentDriver;
      return p.jePokupljen || p.jeOtkazan || p.jeOdsustvo || jeTudji;
    }).toList();

    final preostaliPutnici = sveziPutnici.where((p) {
      final jeTudji = p.dodeljenVozac != null && p.dodeljenVozac!.isNotEmpty && p.dodeljenVozac != _currentDriver;
      return !p.jePokupljen && !p.jeOtkazan && !p.jeOdsustvo && !jeTudji;
    }).toList();

    if (preostaliPutnici.isEmpty) {
      // Svi putnici su pokupljeni ili otkazani - ZADR�I ih u listi

      // ? STOP TRACKING AKO SU SVI GOTOVI
      if (DriverLocationService.instance.isTracking) {
        await DriverLocationService.instance.updatePutniciEta({});
      }

      if (mounted) {
        setState(() {
          _optimizedRoute = pokupljeniIOtkazani; // ? ZADR�I pokupljene u listi
          _currentPassengerIndex = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('? Svi putnici su pokupljeni!'),
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
            // ? KOMBINUJ: optimizovani preostali + pokupljeni/otkazani na kraju
            _optimizedRoute = [...result.optimizedPutnici!, ...pokupljeniIOtkazani];
            _currentPassengerIndex = 0;
          });

          // 🛠️ REALTIME FIX: Ažuriraj ETA (uklanja pokupljene sa mape)
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
    } catch (e) {
      debugPrint('❌ Error auto-reoptimizing route: $e');
    }
  }

  // 🔄 SINHRONIZACIJA OPTIMIZOVANE RUTE SA REALTIME STREAM-om
  // Ažurira statuse putnika u optimizovanoj listi kada se promene u bazi
  // ⏱️ SA THROTTLING-om: Sprečava prekomerne UI rebuilde (max 2x/sec)
  // 🚀 AUTO-REOPTIMIZACIJA: Kada se doda ili otkaže putnik, automatski reoptimizuje rutu
  void _syncOptimizedRouteWithStream(List<Putnik> streamPutnici) {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty) return;

    // ⏳ THROTTLING: Ignoriši ako je prošlo manje od 800ms od poslednje sinhronizacije
    // 💡 ALI: Sačuvaj pending podatke za sledeći sync
    final now = DateTime.now();
    if (_lastSyncTime != null && now.difference(_lastSyncTime!) < _syncThrottleDuration) {
      _pendingSyncPutnici = streamPutnici; // Sacuvaj za kasnije
      // Zaka�i odlo�eni sync ako nije vec zakazan
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
    _pendingSyncPutnici = null; // Ocisti pending jer procesiramo sada

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
      // Proveri da li putnik jo� postoji u stream-u
      if (!streamIds.contains(optimizedPutnik.id)) {
        // ??? Putnik obrisan iz baze
        hasChanges = true;
        hasCancelledOrDeleted = true;
        cancelledNames.add(optimizedPutnik.ime);
        continue;
      }

      // Pronadi putnika u stream-u po ID-u
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

    // 2?? Detektuj nove putnike koji nisu u optimizovanoj ruti
    // ?? FIX: Filtriraj nove putnike SAMO za trenutni grad i vreme
    final newPassengers = <Putnik>[];
    final normFilterTime = GradAdresaValidator.normalizeTime(_selectedVreme);
    for (final streamPutnik in streamPutnici) {
      if (!optimizedIds.contains(streamPutnik.id)) {
        // ? Proveri da li putnik pripada trenutnom gradu i vremenu
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

        // ? Samo aktivni putnici (ne otkazani/obrisani)
        final isActive = !streamPutnik.jeOtkazan && !streamPutnik.jeOdsustvo && !streamPutnik.obrisan;

        if (vremeMatch && gradMatch && isActive) {
          hasNewPassengers = true;
          newPassengers.add(streamPutnik);
          newPassengerNames.add(streamPutnik.ime);
        }
      }
    }

    // ?? AUTO-REOPTIMIZACIJA: Ako ima novih ILI otkazanih putnika
    if ((hasNewPassengers || hasCancelledOrDeleted) && mounted) {
      // Prika�i notifikaciju
      String message;
      Color bgColor;
      if (hasNewPassengers && hasCancelledOrDeleted) {
        message = '🔄 Promene: +${newPassengerNames.join(", ")} / -${cancelledNames.join(", ")} - Reoptimizujem...';
        bgColor = Colors.purple;
      } else if (hasNewPassengers) {
        message = '🔄 Novi putnik: ${newPassengerNames.join(", ")} - Reoptimizujem rutu...';
        bgColor = Colors.blue;
      } else {
        message = '? Otkazano: ${cancelledNames.join(", ")} - Reoptimizujem rutu...';
        bgColor = Colors.orange;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: bgColor,
          duration: const Duration(seconds: 2),
        ),
      );

      // Kombinuj postojece + nove putnike i pokreni reoptimizaciju
      final allPassengers = [...updatedRoute, ...newPassengers];
      _autoReoptimizeRoute(allPassengers);
      return; // Ne a�uriraj state ovde, _autoReoptimizeRoute ce to uraditi
    }

    // Samo a�uraj ako ima promena (bez novih/otkazanih putnika)
    if (hasChanges && mounted) {
      setState(() {
        _optimizedRoute = updatedRoute;
      });
    }
  }

  // ?? AUTO-REOPTIMIZACIJA RUTE SA NOVIM PUTNICIMA
  // Poziva OSRM da dobije novu optimalnu rutu
  // ? SA LOCK MEHANIZMOM: Sprecava konkurentne reoptimizacije
  // ? CUVA pokupljene/otkazane putnike na kraju liste
  Future<void> _autoReoptimizeRoute(List<Putnik> allPassengers) async {
    // ?? LOCK: Ako je vec u toku reoptimizacija, preskoci
    if (_isReoptimizing) {
      return;
    }
    _isReoptimizing = true;

    try {
      // ?? Razdvoji pokupljene/otkazane/tude od aktivnih putnika
      final pokupljeniIOtkazani = allPassengers.where((p) {
        final jeTudji = p.dodeljenVozac != null && p.dodeljenVozac!.isNotEmpty && p.dodeljenVozac != _currentDriver;
        return p.jePokupljen || p.jeOtkazan || p.jeOdsustvo || jeTudji;
      }).toList();

      // Filtriraj samo AKTIVNE putnike sa validnim adresama za optimizaciju
      final filtriraniPutnici = allPassengers.where((p) {
        final hasValidAddress = (p.adresaId != null && p.adresaId!.isNotEmpty) ||
            (p.adresa != null && p.adresa!.isNotEmpty && p.adresa != p.grad);
        // ?? Iskljuci pokupljene, otkazane i tude putnike
        final jeTudji = p.dodeljenVozac != null && p.dodeljenVozac!.isNotEmpty && p.dodeljenVozac != _currentDriver;
        final isActive = !p.jePokupljen && !p.jeOtkazan && !p.jeOdsustvo && !jeTudji;
        return hasValidAddress && isActive;
      }).toList();

      // ? Ako nema aktivnih putnika, zadr�i samo pokupljene/otkazane
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
            // ? KOMBINUJ: optimizovani aktivni + pokupljeni/otkazani na kraju
            _optimizedRoute = [...result.optimizedPutnici!, ...pokupljeniIOtkazani];
          });

          // ?? REALTIME FIX: Ažuriraj ETA bez restarta trackinga
          if (DriverLocationService.instance.isTracking && result.putniciEta != null) {
            await DriverLocationService.instance.updatePutniciEta(result.putniciEta!);
          }

          // ? FIX: Ponovna provera mounted posle await operacije
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('? Ruta uspe�no reoptimizovana sa novim putnikom!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Gre�ka pri reoptimizaciji - zadr�i postojecu rutu
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška pri reoptimizaciji: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // ?? UNLOCK: Uvek oslobodi lock
      _isReoptimizing = false;
    }
  }

  // ?? OPTIMIZACIJA RUTE - IDENTICNO KAO DANAS SCREEN
  void _optimizeCurrentRoute(List<Putnik> putnici, {bool isAlreadyOptimized = false}) async {
    // Proveri da li je ulogovan i valjan vozac
    if (_currentDriver == null || !VozacBoja.isValidDriverSync(_currentDriver)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Morate biti ulogovani i ovla�ceni da biste koristili optimizaciju rute.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isOptimizing = true; // ? USE _isOptimizing INSTEAD OF _isLoading
      });
    }

    // ?? Ako je lista vec optimizovana od strane servisa, koristi je direktno
    if (isAlreadyOptimized) {
      if (putnici.isEmpty) {
        if (mounted) {
          setState(() => _isOptimizing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('? Nema putnika sa adresama za reorder'), backgroundColor: Colors.orange),
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
          _isOptimizing = false;
        });
      }

      final routeString = _optimizedRoute.take(3).map((p) => p.adresa?.split(',').first ?? p.ime).join(' ? ');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '?? Lista putnika optimizovana (server) za $_selectedGrad $_selectedVreme!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('?? Sledeci putnici: $routeString${_optimizedRoute.length > 3 ? "..." : ""}'),
                Text(
                    '?? Broj putnika: ${_optimizedRoute.where((p) => TextUtils.isStatusActive(p.status) && !p.jePokupljen).length}'),
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
      // Iskljuci otkazane putnike
      if (p.jeOtkazan) return false;
      // Iskljuci vec pokupljene putnike
      if (p.jePokupljen) return false;
      // Iskljuci odsutne putnike (bolovanje/godi�nji)
      if (p.jeOdsustvo) return false;
      // ?? Iskljuci tude putnike (dodeljeni drugom vozacu)
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
          _isOptimizing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('? Nema putnika sa adresama za optimizaciju'), backgroundColor: Colors.orange),
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

        // ?? Dodaj putnike BEZ ADRESE na pocetak liste kao podsetnik
        final skippedPutnici = result.skippedPutnici ?? [];
        final finalRoute = [...skippedPutnici, ...optimizedPutnici];

        if (mounted) {
          setState(() {
            _optimizedRoute = finalRoute; // Preskoceni + optimizovani
            _isRouteOptimized = true;
            _isListReordered = true;
            _currentPassengerIndex = 0;
            _isOptimizing = false;
          });
        }

        // ?? AUTOMATSKI POKRENI GPS TRACKING nakon optimizacije
        if (_currentDriver != null && result.putniciEta != null) {
          await _startGpsTracking();
        }

        final routeString = optimizedPutnici.take(3).map((p) => p.adresa?.split(',').first ?? p.ime).join(' ? ');

        // ?? Proveri da li ima preskocenih putnika
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
                    '?? RUTA OPTIMIZOVANA za $_selectedGrad $_selectedVreme!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('?? Sledeci putnici: $routeString${optimizedPutnici.length > 3 ? "..." : ""}'),
                  Text(
                      '?? Broj putnika: ${optimizedPutnici.where((p) => TextUtils.isStatusActive(p.status) && !p.jePokupljen).length}'),
                  if (result.totalDistance != null)
                    Text('?? Ukupno: ${(result.totalDistance! / 1000).toStringAsFixed(1)} km'),
                ],
              ),
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.green,
            ),
          );

          // ? OPTIMIZACIJA 3: Zameni blokirajuci AlertDialog sa Snackbar-om
          // Korisnik vidi notifikaciju ali NIJE BLOKIRAN da nastavi sa akcijama
          if (hasSkipped) {
            // ?? Prika�i preskocene putnike kao SNACKBAR umesto DIALOG-a
            if (mounted) {
              final skippedNames = skipped.take(5).map((p) => p.ime).join(', ');
              final moreText = skipped.length > 5 ? ' +${skipped.length - 5} jo�' : '';

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${skipped.length} putnika BEZ adrese',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$skippedNames$moreText',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  backgroundColor: Colors.orange.shade700,
                  duration: const Duration(seconds: 6),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      } else {
        // ? OSRM/SmartNavigationService nije uspeo - NE koristi fallback, prika�i gre�ku
        if (mounted) {
          setState(() {
            _isOptimizing = false;
            // NE postavljaj _isRouteOptimized = true jer ruta NIJE optimizovana!
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('? Optimizacija neuspe�na: ${result.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOptimizing = false;
          _isRouteOptimized = false;
          _isListReordered = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('? Gre�ka pri optimizaciji: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ?? KOMPAKTNO DUGME ZA GPS TRACKING
  // ? TOGGLE: Pokrece ili zaustavlja GPS tracking u pozadini
  Widget _buildOptimizeButton() {
    return StreamBuilder<List<Putnik>>(
      // ? Koristi isti stream kao ostatak screen-a
      stream: _putnikService.streamPutnici(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getBorderColor(Colors.grey)),
            ),
            child: const Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getBorderColor(Colors.red)),
            ),
            child: const Center(
              child: Text(
                '!',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
          );
        }

        // ?? Filtriraj putnike po gradu i vremenu
        final sviPutnici = snapshot.data ?? [];

        // ?? REALTIME SYNC: A�uriraj statuse u optimizovanoj ruti
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

          // ?? Boja filter - samo bele kartice (nepokupljeni)
          if (p.jePokupljen) return false;

          return true;
        }).toList();

        final bool isDriverValid = _currentDriver != null && VozacBoja.isValidDriverSync(_currentDriver);
        final bool canPress = !_isOptimizing && !_isLoading && isDriverValid;

        final baseColor = _isGpsTracking ? Colors.orange : (_isRouteOptimized ? Colors.green : Colors.white);

        return InkWell(
          onTap: canPress
              ? () {
                  if (_isGpsTracking) {
                    _stopGpsTracking();
                  } else if (_isRouteOptimized) {
                    _startGpsTracking();
                  } else {
                    _optimizeCurrentRoute(filtriraniPutnici, isAlreadyOptimized: false);
                  }
                }
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Opacity(
            opacity: 1.0,
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: baseColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getBorderColor(baseColor)),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _isOptimizing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _isGpsTracking ? 'STOP' : 'START',
                          style: TextStyle(
                            color: baseColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ? SPEEDOMETER DUGME U APPBAR-U - IDENTICNO KAO DANAS SCREEN
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
                    : Colors.white; // ? Koristi cisto belu, pa cemo je 'uti�ati' sa alpha na pozadini

        return Opacity(
          opacity: 1.0,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: speedColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getBorderColor(speedColor)),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
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
                  if (speed > 0) ...[
                    const SizedBox(width: 2),
                    const Text(
                      'km/h',
                      style: TextStyle(color: Colors.white54, fontSize: 8),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ??? DUGME ZA NAVIGACIJU - OTVARA HERE WeGo SA REDOSLEDOM IZ OPTIMIZOVANE RUTE
  Widget _buildMapsButton() {
    final hasOptimizedRoute = _isRouteOptimized && _optimizedRoute.isNotEmpty;
    final bool isDriverValid = _currentDriver != null && VozacBoja.isValidDriverSync(_currentDriver);
    final bool canPress = hasOptimizedRoute && isDriverValid;
    final baseColor = hasOptimizedRoute ? Colors.blue : Colors.white;

    return InkWell(
      onTap: canPress ? _openHereWeGoNavigation : null,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: 1.0,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: baseColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _getBorderColor(baseColor)),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'MAPA',
                style: TextStyle(
                  color: baseColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ?? POKRENI GPS TRACKING (ruta je vec optimizovana)
  Future<void> _startGpsTracking() async {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty || _currentDriver == null) return;

    try {
      final smer = _selectedGrad.toLowerCase().contains('bela') || _selectedGrad == 'BC' ? 'BC_VS' : 'VS_BC';

      // Konvertuj koordinate: Map<Putnik, Position> -> Map<String, Position>
      Map<String, Position>? coordsByName;

      // Izvuci redosled imena putnika
      final putniciRedosled = _optimizedRoute.map((p) => p.ime).toList();

      // Izracunaj ETA za putnike ako vec nisu dostupni
      Map<String, int>? putniciEta;

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
                content: Text('? Svi putnici pokupljeni! Tracking automatski zaustavljen.'),
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
            content: Text('?? GPS tracking pokrenut! Putnici dobijaju realtime lokaciju.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // ?? PO�ALJI PUSH NOTIFIKACIJE PUTNICIMA - bez ETA
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('? Gre�ka pri pokretanju GPS trackinga: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ?? ZAUSTAVI GPS TRACKING
  void _stopGpsTracking() {
    DriverLocationService.instance.stopTracking();

    if (mounted) {
      setState(() {
        _isGpsTracking = false;
        _navigationStatus = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('?? GPS tracking zaustavljen'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ??? OTVORI HERE WeGo NAVIGACIJU SA OPTIMIZOVANIM REDOSLEDOM
  Future<void> _openHereWeGoNavigation() async {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty) return;

    try {
      final result = await SmartNavigationService.startMultiProviderNavigation(
        context: context,
        putnici: _optimizedRoute,
        startCity: _selectedGrad.isNotEmpty ? _selectedGrad : 'Vršac',
      );

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('??? ${result.message}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('? ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('? Gre�ka pri otvaranju navigacije: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ?? POPIS DUGME - IDENTICNO KAO DANAS SCREEN
  Widget _buildPopisButton() {
    final bool isDriverValid = _currentDriver != null && VozacBoja.isValidDriverSync(_currentDriver);
    final bool canPress = isDriverValid && !_isPopisLoading;
    final baseColor = _isPopisSaved ? Colors.green : Colors.white;

    return InkWell(
      onTap: canPress ? () => _showPopisDana() : null,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: 1.0,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: baseColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _getBorderColor(baseColor)),
          ),
          child: Center(
            child: _isPopisLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'POPIS',
                      style: TextStyle(
                        color: baseColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ?? POPIS DANA - KORISTI CENTRALIZOVANI POPIS SERVICE
  Future<void> _showPopisDana() async {
    if (_currentDriver == null || _currentDriver!.isEmpty || !VozacBoja.isValidDriverSync(_currentDriver)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Morate biti ulogovani i ovla�ceni da biste koristili Popis.'),
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
      // 1. UCITAJ PODATKE PREKO POPIS SERVICE
      final popisData = await PopisService.loadPopisData(
        vozac: vozac,
        selectedGrad: _selectedGrad,
        selectedVreme: _selectedVreme,
        date: _getWorkingDateTime(), // ?? Koristi radni datum (ponedeljak ako je vikend)
      );

      // 2. PRIKA�I DIALOG
      if (!mounted) return;
      final bool sacuvaj = await PopisService.showPopisDialog(context, popisData);

      // 3. SACUVAJ AKO JE POTVR�EN
      if (sacuvaj) {
        await PopisService.savePopis(popisData);
        if (mounted) {
          setState(() => _isPopisSaved = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('? Popis je uspe�no sacuvan!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('? Gre�ka pri ucitavanju popisa: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPopisLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ?? KORISTI RADNI DATUM (Vikendom prebacuje na ponedeljak)
    final workingDateIso = _getWorkingDateIso();
    final parts = workingDateIso.split('-');
    final today =
        parts.length == 3 ? DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])) : DateTime.now();

    final dayStart = DateTime(today.year, today.month, today.day);
    final dayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return Container(
      decoration: BoxDecoration(
        gradient: ThemeManager().currentGradient, // ?? Theme-aware gradijent
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
                  // DRUGI RED - Dugmad ravnomerno rasporedena
                  Row(
                    children: [
                      // ?? RUTA DUGME
                      Expanded(child: _buildOptimizeButton()),
                      const SizedBox(width: 4),
                      // ??? NAV DUGME
                      Expanded(child: _buildMapsButton()),
                      const SizedBox(width: 4),
                      // ?? POPIS DUGME
                      Expanded(child: _buildPopisButton()),
                      const SizedBox(width: 4),
                      // ? BRZINOMER
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
                  // ? BEZ FILTERA - filtriraj client-side
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      children: [
                        ShimmerWidgets.vozacHeaderShimmer(context),
                        const SizedBox(height: 8),
                        ShimmerWidgets.statistikaShimmer(context),
                        Expanded(child: ShimmerWidgets.putnikListShimmer(itemCount: 5)),
                      ],
                    );
                  }

                  // ?? FILTER: Prika�i ISKLJUCIVO putnike koje je admin dodelio ovom vozacu
                  final sviPutnici = snapshot.data ?? [];
                  final mojiPutnici = sviPutnici.where((p) {
                    return p.dodeljenVozac == _currentDriver;
                  }).toList();

                  // ? CLIENT-SIDE FILTER za grad i vreme - kao u DanasScreen
                  final filteredByGradVreme = mojiPutnici.where((p) {
                    // Filter po gradu
                    final gradMatch =
                        _selectedGrad.isEmpty || GradAdresaValidator.isGradMatch(p.grad, p.adresa, _selectedGrad);

                    // Filter po vremenu
                    final vremeMatch = _selectedVreme.isEmpty ||
                        GradAdresaValidator.normalizeTime(p.polazak) ==
                            GradAdresaValidator.normalizeTime(_selectedVreme);

                    // 🛡️ Predlog 3: Sakrij putnike na čekanju (pending)
                    final isPending = p.status?.toLowerCase() == 'pending';

                    return gradMatch && vremeMatch && !isPending;
                  }).toList();

                  // ?? FIX: Uvek koristi `filteredByGradVreme` kao izvor istine (iz streama)
                  // Ako je ruta optimizovana, sortiraj po redosledu iz `_optimizedRoute`
                  List<Putnik> putnici = filteredByGradVreme;

                  if (_isRouteOptimized && _optimizedRoute.isNotEmpty) {
                    // Sortiraj filteredByGradVreme prema redosledu u _optimizedRoute
                    final optimizedOrder = <dynamic, int>{};

                    for (int i = 0; i < _optimizedRoute.length; i++) {
                      optimizedOrder[_optimizedRoute[i].id] = i;
                    }

                    putnici.sort((a, b) {
                      final aIndex = optimizedOrder[a.id] ?? 999;
                      final bIndex = optimizedOrder[b.id] ?? 999;
                      return aIndex.compareTo(bIndex);
                    });
                  }

                  return Column(
                    children: [
                      // KOCKE - Pazar, Dugovi
                      _buildStatsRow(sviPutnici, mojiPutnici),
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
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Nema putnika za izabrani polazak',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
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
                                    _currentDriver!, // ? FIX: Koristi dinamicki _currentDriver umesto hardkodovanog _vozacIme
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
        // ?? BOTTOM NAV BAR
        bottomNavigationBar: StreamBuilder<List<Putnik>>(
          stream: _putnikService.streamKombinovaniPutniciFiltered(
            isoDate: _getWorkingDateIso(),
          ),
          builder: (context, snapshot) {
            final allPutnici = snapshot.data ?? <Putnik>[];

            // ?? FILTER: Svi putnici koje je admin dodelio ovom vozacu za izabrani dan
            final mojiPutnici = allPutnici.where((p) {
              return p.dodeljenVozac == _currentDriver;
            }).toList();

            // ?? REFAKTORISANO: Koristi PutnikCountHelper za centralizovano brojanje
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

            // ?? KAPACITET: Broj mesta za svaki polazak (real-time od admina)
            int getKapacitet(String grad, String vreme) {
              return KapacitetService.getKapacitetSync(grad, vreme);
            }

            // ?? FILTER VREMENA: Samo dodeljena vremena za ovog vozača
            final dodeljenaVremena = _getDodeljenaVremena(sviPutnici: allPutnici);
            final assignedBcTimes =
                dodeljenaVremena.where((v) => v['grad'] == 'Bela Crkva').map((v) => v['vreme']!).toList();
            final assignedVsTimes =
                dodeljenaVremena.where((v) => v['grad'] == 'Vršac').map((v) => v['vreme']!).toList();

            // Prikaži samo dodeljena vremena
            final bcVremenaToShow = assignedBcTimes.toList()..sort();
            final vsVremenaToShow = assignedVsTimes.toList()..sort();

            // 🚫 SAKRIJ CEO BOTTOM BAR AKO NEMA VOŽNJI
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

  // 🕒 Digitalni datum display
  Widget _buildDigitalDateDisplay() {
    final workingDateIso = _getWorkingDateIso();
    final parts = workingDateIso.split('-');
    final now =
        parts.length == 3 ? DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])) : DateTime.now();

    final dayNames = ['PONEDELJAK', 'UTORAK', 'SREDA', 'ČETVRTAK', 'PETAK', 'SUBOTA', 'NEDELJA'];
    final dayName = dayNames[now.weekday - 1];
    final dayStr = now.day.toString().padLeft(2, '0');
    final monthStr = now.month.toString().padLeft(2, '0');
    final yearStr = now.year.toString().substring(2);

    // ?? Izracunaj boju za dan (ako smo u admin preview modu)
    final isPreview = widget.previewAsDriver != null && widget.previewAsDriver!.isNotEmpty;
    final driverColor =
        isPreview ? VozacBoja.getSync(widget.previewAsDriver!) : Theme.of(context).colorScheme.onPrimary;

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
            color: driverColor, // ?? Koristi boju vozaca ako je preview
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

  // ?? AppBar dugme
  Widget _buildAppBarButton({
    String? label,
    IconData? icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _getBorderColor(color)),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: color, size: 14)
              : Text(
                  label ?? '',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  // ?? Statistika kocka
  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getBorderColor(color)),
      ),
      child: Center(
        child: Text(
          label.isEmpty ? value : label,
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

  // ?? Stats row
  Widget _buildStatsRow(List<Putnik> sviPutnici, List<Putnik> mojiPutnici) {
    final dayStart = DateTime.parse('${_getWorkingDateIso()}T00:00:00');
    final dayEnd = DateTime.parse('${_getWorkingDateIso()}T23:59:59');

    final filteredDuzniciRaw = sviPutnici.where((putnik) {
      final nijeMesecni = !putnik.isMesecniTip;
      if (!nijeMesecni) return false;
      final nijePlatio = putnik.vremePlacanja == null;
      final nijeOtkazan = putnik.status != 'otkazan' && putnik.status != 'Otkazano';
      final pokupljen = putnik.jePokupljen;
      return nijePlatio && nijeOtkazan && pokupljen;
    }).toList();

    final seenIds = <dynamic>{};
    final filteredDuznici = filteredDuzniciRaw.where((p) {
      final key = p.id ?? '${p.ime}_${p.dan}';
      if (seenIds.contains(key)) return false;
      seenIds.add(key);
      return true;
    }).toList();

    // 🔄 NOVI JEDNOSTAVAN BROJAČ POVRATAKA
    // Grupišemo sve polaske po putniku (ID) da vidimo ko ima BC, a ko ima i VS
    final Map<dynamic, Set<String>> putnikSmerovi = {};

    for (var p in sviPutnici) {
      if (p.jeOtkazan || p.jeOdsustvo || p.obrisan) continue;
      if (p.tipPutnika == 'posiljka') continue;

      final id = p.id;
      if (id == null) continue;

      putnikSmerovi.putIfAbsent(id, () => <String>{});

      final gradLower = p.grad.toLowerCase();
      if (gradLower.contains('bela crkva') || gradLower == 'bc') {
        putnikSmerovi[id]!.add('bc');
      } else if (gradLower.contains('vršac') || gradLower.contains('vrsac') || gradLower == 'vs') {
        putnikSmerovi[id]!.add('vs');
      }
    }

    int ukupnoPutnika = 0;
    int saObaSmera = 0;

    final List<String> samoJedanSmerImena = [];

    putnikSmerovi.forEach((id, smerovi) {
      ukupnoPutnika++;
      if (smerovi.contains('bc') && smerovi.contains('vs')) {
        saObaSmera++;
      } else {
        final p = sviPutnici.firstWhere((element) => element.id == id);
        final grad = smerovi.contains('bc') ? 'BC' : 'VS';
        samoJedanSmerImena.add('${p.ime} ($grad)');
      }
    });

    return Container(
      margin: const EdgeInsets.all(12),
      child: Row(
        children: [
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
                filteredDuznici.isEmpty ? Colors.blue : Colors.red,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 🔄 KOCKA ZA POVRATAK
          Expanded(
            child: InkWell(
              onTap: () {
                _showPovratakStatPopup(
                  context,
                  'Povratak',
                  '$saObaSmera/$ukupnoPutnika',
                  samoJedanSmerImena,
                  Colors.orange,
                );
              },
              child: _buildStatBox(
                'Povratak',
                '$saObaSmera/$ukupnoPutnika',
                Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 📊 POPUP ZA PRIKAZ POVRATKA SA SPISKOM
  void _showPovratakStatPopup(
    BuildContext context,
    String label,
    String value,
    List<String> putniciJedanSmer,
    Color color,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.4),
                Colors.black.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Divider(color: Colors.white24, height: 24),
              const Text(
                'Samo jedan polazak:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: putniciJedanSmer.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Svi putnici imaju oba smera! 🎉',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: putniciJedanSmer.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline, size: 16, color: Colors.white54),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    putniciJedanSmer[index],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.withOpacity(0.3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Zatvori'),
              ),
            ],
          ),
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
            color: color.withOpacity(0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _getBorderColor(color)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
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
    return color.withOpacity(0.6);
  }
}
