import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../globals.dart';
import '../services/realtime/realtime_manager.dart';

/// Widget koji prikazuje ETA dolaska kombija sa 4 faze:
/// 1. 30 min pre polaska: "Vozač će uskoro krenuti"
/// 2. Vozač startovao rutu: Realtime ETA praćenje
/// 3. Pokupljen: "Pokupljeni ste u HH:MM" (stoji 60 min) - ČITA IZ BAZE!
/// 4. Nakon 60 min: "Vaša sledeća zakazana vožnja: dan, vreme"
class KombiEtaWidget extends StatefulWidget {
  const KombiEtaWidget({
    super.key,
    required this.putnikIme,
    required this.grad,
    this.vremePolaska,
    this.sledecaVoznja,
    this.putnikId, // 🆕 ID putnika za čitanje iz baze
  });

  final String putnikIme;
  final String grad;
  final String? vremePolaska;
  final String? sledecaVoznja;
  final String? putnikId; // 🆕 UUID putnika

  @override
  State<KombiEtaWidget> createState() => _KombiEtaWidgetState();
}

/// Faze prikaza widgeta
enum _WidgetFaza {
  potrebneDozvole, // Faza 0: Putnik treba da odobri GPS i notifikacije
  cekanje, // Faza 1: 30 min pre polaska - "Vozač će uskoro krenuti"
  pracenje, // Faza 2: Vozač startovao rutu - realtime ETA
  pokupljen, // Faza 3: Pokupljen - prikazuje vreme pokupljenja 60 min
  sledecaVoznja, // Faza 4: Nakon 60 min - prikazuje sledeću vožnju
}

class _KombiEtaWidgetState extends State<KombiEtaWidget> {
  StreamSubscription? _subscription;
  StreamSubscription? _putnikSubscription; // 🆕 Za praćenje promena u registrovani_putnici
  int? _etaMinutes;
  bool _isLoading = true;
  bool _isActive = false; // Vozač je aktivan (šalje lokaciju)
  bool _vozacStartovaoRutu = false; // 🆕 Vozač pritisnuo "Ruta" dugme
  String? _vozacIme;
  DateTime? _vremePokupljenja; // 🆕 ČITA SE IZ BAZE - tačno vreme kada je vozač pritisnuo
  bool _jePokupljenIzBaze = false; // 🆕 Flag iz baze
  bool _imaDozvole = false; // 🆕 Da li putnik ima GPS i notifikacije dozvole

  @override
  void initState() {
    super.initState();
    _checkPermissions(); // 🆕 Proveri dozvole prvo
    _startListening();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _putnikSubscription?.cancel();
    RealtimeManager.instance.unsubscribe('vozac_lokacije');
    if (widget.putnikId != null) {
      RealtimeManager.instance.unsubscribe('registrovani_putnici');
    }
    super.dispose();
  }

  Future<void> _loadGpsData() async {
    try {
      final normalizedGrad = _normalizeGrad(widget.grad);

      var query = supabase.from('vozac_lokacije').select().eq('aktivan', true);

      if (widget.vremePolaska != null) {
        query = query.eq('vreme_polaska', widget.vremePolaska!);
      }

      final data = await query;

      if (!mounted) return;

      final list = data as List<dynamic>;

      final filteredList = list.where((driver) {
        final driverGrad = driver['grad'] as String? ?? '';
        final driverVreme = driver['vreme_polaska'] as String?;
        final updatedAtStr = driver['updated_at'] as String?;

        // 1. Provera grada
        if (_normalizeGrad(driverGrad) != normalizedGrad) return false;

        // 🛑 STALE CHECK: Ako zapis nije ažuriran u poslednjih 30 minuta, ignoriši ga!
        // Ovo rešava problem "zombija" vozača koji nisu odjavljeni (putnici_eta ostaje zapamćen)
        if (updatedAtStr != null) {
          final updatedAt = DateTime.tryParse(updatedAtStr);
          if (updatedAt != null) {
            final diff = DateTime.now().difference(updatedAt).inMinutes.abs();
            if (diff > 30) return false; // Stariji od 30 min -> SIGURNO zombi
          }
        }

        // 2. Ako tražimo specifično vreme (npr. putnik bira 05:00), ignoriši ako vozač nije ažuran
        if (widget.vremePolaska != null) return true;

        // 3. SANITY CHECK za automatsku detekciju (kada putnik nema target vreme)
        if (driverVreme == null) return false;

        final now = DateTime.now();
        final parts = driverVreme.split(':');
        if (parts.length != 2) return false;

        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;

        int diffInMinutes = (h * 60 + m) - (now.hour * 60 + now.minute);

        if (diffInMinutes > 720) diffInMinutes -= 1440;
        if (diffInMinutes < -720) diffInMinutes += 1440;

        if (diffInMinutes < -180 || diffInMinutes > 240) return false;

        return true;
      }).toList();

      if (filteredList.isEmpty) {
        setState(() {
          _isActive = false;
          _vozacStartovaoRutu = false;
          _etaMinutes = null;
          _vozacIme = null;
          _isLoading = false;
        });
        return;
      }

      final driver = filteredList.first;
      final rawEta = driver['putnici_eta'];
      Map<String, dynamic>? putniciEta;
      if (rawEta is String) {
        try {
          putniciEta = json.decode(rawEta) as Map<String, dynamic>?;
        } catch (_) {}
      } else if (rawEta is Map) {
        putniciEta = Map<String, dynamic>.from(rawEta);
      }
      final vozacIme = driver['vozac_ime'] as String?;

      // 🆕 Proveri da li vozač ima putnike u ETA mapi (znači da je startovao rutu)
      final hasEtaData = putniciEta != null && putniciEta.isNotEmpty;

      int? eta;
      if (putniciEta != null) {
        // Exact match
        if (putniciEta.containsKey(widget.putnikIme)) {
          eta = putniciEta[widget.putnikIme] as int?;
        } else {
          // Case-insensitive match
          for (final entry in putniciEta.entries) {
            if (entry.key.toLowerCase() == widget.putnikIme.toLowerCase()) {
              eta = entry.value as int?;
              break;
            }
          }
          // Partial match
          if (eta == null) {
            final putnikLower = widget.putnikIme.toLowerCase();
            for (final entry in putniciEta.entries) {
              final keyLower = entry.key.toLowerCase();
              if (keyLower.contains(putnikLower) || putnikLower.contains(keyLower)) {
                eta = entry.value as int?;
                break;
              }
            }
          }
        }
      }

      // // DEBUG: Štampaj šta je pronađeno
      // debugPrint('🚐 KombiEtaWidget: putnikIme=${widget.putnikIme}, eta=$eta, putniciEta=$putniciEta');

      setState(() {
        _isActive = true;
        _vozacStartovaoRutu = hasEtaData;
        // Postavi vreme pokupljenja ako je ETA -1 (pokupljen) i još nije setovano
        if (eta == -1 && _vremePokupljenja == null) {
          _vremePokupljenja = DateTime.now();
        }
        if (eta != null && eta != -1) {
          _vremePokupljenja = null;
        }
        _etaMinutes = eta;
        _vozacIme = vozacIme;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isActive = false;
          _vozacStartovaoRutu = false;
        });
      }
    }
  }

  String _normalizeGrad(String grad) {
    final lower = grad.toLowerCase();
    if (lower.contains('bela') || lower == 'bc') {
      return 'BC';
    } else if (lower.contains('vršac') || lower.contains('vrsac') || lower == 'vs') {
      return 'VS';
    }
    return grad.toUpperCase();
  }

  /// 🔓 Zatraži dozvole za GPS
  Future<void> _requestPermissions() async {
    try {
      final permission = await Geolocator.requestPermission();
      final hasGps = permission == LocationPermission.always || permission == LocationPermission.whileInUse;

      setState(() {
        _imaDozvole = hasGps;
      });

      // Ako su dozvole odobrene, osvježi GPS podatke
      if (hasGps) {
        await _loadGpsData();
      }
    } catch (e) {
      // Greška pri traženju dozvola
    }
  }

  /// 🔐 Proveri da li putnik ima potrebne dozvole (GPS i notifikacije)
  Future<void> _checkPermissions() async {
    try {
      // Proveri GPS dozvolu
      final locationPermission = await Geolocator.checkPermission();
      final hasGps =
          locationPermission == LocationPermission.always || locationPermission == LocationPermission.whileInUse;

      // Za notifikacije, pretpostavljamo da su potrebne ali ne blokira UI
      // (user može da ih omogući kasnije kroz sistemske podešavanja)
      setState(() {
        _imaDozvole = hasGps;
      });
    } catch (e) {
      setState(() {
        _imaDozvole = false;
      });
    }
  }

  void _startListening() {
    _loadGpsData();
    _loadPokupljenjeIzBaze(); // 🆕 Učitaj status pokupljenja iz baze
    _subscription = RealtimeManager.instance.subscribe('vozac_lokacije').listen(
      (payload) {
        _loadGpsData();
      },
      onError: (error) {
        debugPrint('🔴 [KombiEtaWidget] vozac_lokacije stream error: $error');
      },
    );
    // 🆕 Prati promene u registrovani_putnici tabeli (kada vozač pokupi putnika)
    if (widget.putnikId != null) {
      _putnikSubscription = RealtimeManager.instance.subscribe('registrovani_putnici').listen(
        (payload) {
          _loadPokupljenjeIzBaze();
        },
        onError: (error) {
          debugPrint('🔴 [KombiEtaWidget] registrovani_putnici stream error: $error');
        },
      );
    }
  }

  /// 🆕 Učitaj vreme pokupljenja DIREKTNO iz baze (voznje_log)
  Future<void> _loadPokupljenjeIzBaze() async {
    if (widget.putnikId == null) return;

    try {
      final now = DateTime.now();
      final todayDate = now.toIso8601String().split('T')[0];

      final response = await supabase
          .from('voznje_log')
          .select('created_at')
          .eq('putnik_id', widget.putnikId!)
          .eq('datum', todayDate)
          .eq('tip', 'voznja')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted || response == null) return;

      final createdAt = response['created_at'] as String?;
      if (createdAt != null && createdAt.isNotEmpty) {
        final parsedTime = DateTime.tryParse(createdAt);
        if (parsedTime != null) {
          setState(() {
            _vremePokupljenja = parsedTime.toLocal();
            _jePokupljenIzBaze = true;
          });
        }
      } else {
        // Ako nije pokupljen u bazi, resetuj flag (bitno za realtime update)
        if (_jePokupljenIzBaze) {
          setState(() {
            _jePokupljenIzBaze = false;
            _vremePokupljenja = null;
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ Greška pri učitavanju pokupljenja: $e');
    }
  }

  /// 🆕 Odredi trenutnu fazu widgeta
  _WidgetFaza _getCurrentFaza() {
    // 🆕 PRIORITET 1: Ako je pokupljen IZ BAZE (vozač pritisnuo long press) - to je ISTINA!
    if (_jePokupljenIzBaze && _vremePokupljenja != null) {
      final minutesSincePokupljenje = DateTime.now().difference(_vremePokupljenja!).inMinutes;
      if (minutesSincePokupljenje <= 60) {
        return _WidgetFaza.pokupljen; // Faza 3: Prikazuj "Pokupljeni ste" 60 min
      } else {
        return _WidgetFaza.sledecaVoznja; // Faza 4: Prikazuj sledeću vožnju
      }
    }

    // Faza 2: Vozač startovao rutu i ima ETA (praćenje uživo)
    if (_isActive && _vozacStartovaoRutu && _etaMinutes != null && _etaMinutes! >= 0) {
      return _WidgetFaza.pracenje;
    }

    // Faza 1: Čekanje - SAMO ako vozač je aktivan
    if (_isActive) {
      return _WidgetFaza.cekanje;
    }

    // 🆕 PRIORITET 0: Ako nema aktivnog vozača, prikaži info o dozvolama (bez obzira da li ih ima)
    // Ovime widget postaje "obaveštajni" a ne "sivi i ružni"
    return _WidgetFaza.potrebneDozvole;
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return _buildContainer(
        Colors.grey,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    final faza = _getCurrentFaza();

    // Ako smo u fazi 4 i nema sledeće vožnje, sakrij widget
    if (faza == _WidgetFaza.sledecaVoznja && widget.sledecaVoznja == null) {
      return const SizedBox.shrink();
    }

    // 🔧 Widget se UVEK prikazuje - ili kao info o dozvolama ili kao ETA tracking
    // Više se ne sakriva kada nema aktivnog vozača

    // Odredi sadržaj na osnovu faze
    final String title;
    final String message;
    final Color baseColor;
    final IconData? icon;

    switch (faza) {
      case _WidgetFaza.potrebneDozvole:
        // Faza 0: Info widget (nema aktivnog vozača)
        title = '📍 GPS PRAĆENJE UŽIVO';
        if (_imaDozvole) {
          message = 'Ovde će biti prikazano vreme dolaska prevoza kada vozač krene';
        } else {
          message = 'Odobravanjem GPS i notifikacija ovde će vam biti prikazano vreme dolaska prevoza do vas';
        }
        baseColor = _imaDozvole ? Colors.white : Colors.orange.shade600;
        icon = _imaDozvole ? Icons.my_location : Icons.gps_not_fixed;

      case _WidgetFaza.cekanje:
        // Faza 1: 30 min pre polaska
        title = '🚐 PRAĆENJE UŽIVO';
        message = 'Vozač će uskoro krenuti';
        baseColor = Colors.white;
        icon = Icons.schedule;

      case _WidgetFaza.pracenje:
        // Faza 2: Realtime ETA
        title = '🚐 KOMBI STIŽE ZA';
        message = _formatEta(_etaMinutes!);
        baseColor = Colors.white;
        icon = Icons.directions_bus;

      case _WidgetFaza.pokupljen:
        // Faza 3: Pokupljen
        title = '✅ POKUPLJENI STE';
        if (_vremePokupljenja != null) {
          final h = _vremePokupljenja!.hour.toString().padLeft(2, '0');
          final m = _vremePokupljenja!.minute.toString().padLeft(2, '0');
          message = 'U $h:$m - Uživajte u vožnji!';
        } else {
          message = 'Uživajte u vožnji!';
        }
        baseColor = Colors.green.shade600;
        icon = Icons.check_circle;

      case _WidgetFaza.sledecaVoznja:
        // Faza 4: Sledeća vožnja
        title = '📅 SLEDEĆA VOŽNJA';
        message = widget.sledecaVoznja ?? 'Nema zakazanih vožnji';
        baseColor = Colors.purple.shade500;
        icon = Icons.event;
    }

    return _buildContainer(
      baseColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.8), size: 24),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              color: Colors.white,
              fontSize: faza == _WidgetFaza.pracenje ? 28 : (faza == _WidgetFaza.potrebneDozvole ? 14 : 18),
              fontWeight: faza == _WidgetFaza.potrebneDozvole ? FontWeight.w500 : FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          // 🆕 Dugme za omogućavanje dozvola (samo ako nema dozvole)
          if (faza == _WidgetFaza.potrebneDozvole && !_imaDozvole)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await _requestPermissions();
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gps_fixed, size: 20, color: baseColor),
                          const SizedBox(width: 8),
                          Text(
                            'Omogući praćenje',
                            style: TextStyle(
                              color: baseColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_vozacIme != null && faza == _WidgetFaza.pracenje)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Vozač: $_vozacIme',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContainer(Color baseColor, {required Widget child}) {
    // 🌟 Glassmorphism stil - ultra providno bez senke
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withOpacity(0.15),
            baseColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  String _formatEta(int minutes) {
    if (minutes < 1) return '< 1 min';
    if (minutes == 1) return '~1 minut';
    if (minutes < 5) return '~$minutes minuta';
    return '~$minutes min';
  }
}
