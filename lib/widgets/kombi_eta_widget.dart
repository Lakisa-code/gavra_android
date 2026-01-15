import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/realtime/realtime_manager.dart';

/// Widget koji prikazuje ETA dolaska kombija sa 4 faze:
/// 1. 30 min pre polaska: "Vozač će uskoro krenuti"
/// 2. Vozač startovao rutu: Realtime ETA praćenje
/// 3. Pokupljen: "Pokupljeni ste u HH:MM" (stoji 60 min)
/// 4. Nakon 60 min: "Vaša sledeća zakazana vožnja: dan, vreme"
class KombiEtaWidget extends StatefulWidget {
  const KombiEtaWidget({
    Key? key,
    required this.putnikIme,
    required this.grad,
    this.vremePolaska,
    this.sledecaVoznja, // 🆕 Format: "Ponedeljak, 7:00" ili null
  }) : super(key: key);

  final String putnikIme;
  final String grad;
  final String? vremePolaska;
  final String? sledecaVoznja; // 🆕 Sledeća zakazana vožnja

  @override
  State<KombiEtaWidget> createState() => _KombiEtaWidgetState();
}

/// Faze prikaza widgeta
enum _WidgetFaza {
  cekanje, // Faza 1: 30 min pre polaska - "Vozač će uskoro krenuti"
  pracenje, // Faza 2: Vozač startovao rutu - realtime ETA
  pokupljen, // Faza 3: Pokupljen - prikazuje vreme pokupljenja 60 min
  sledecaVoznja, // Faza 4: Nakon 60 min - prikazuje sledeću vožnju
}

class _KombiEtaWidgetState extends State<KombiEtaWidget> {
  StreamSubscription? _subscription;
  int? _etaMinutes;
  bool _isLoading = true;
  bool _isActive = false; // Vozač je aktivan (šalje lokaciju)
  bool _vozacStartovaoRutu = false; // 🆕 Vozač pritisnuo "Ruta" dugme
  String? _vozacIme;
  DateTime? _vremePokupljenja;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    RealtimeManager.instance.unsubscribe('vozac_lokacije');
    super.dispose();
  }

  Future<void> _loadGpsData() async {
    try {
      final supabase = Supabase.instance.client;
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
      final putniciEta = driver['putnici_eta'] as Map<String, dynamic>?;
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

      // DEBUG: Štampaj šta je pronađeno
      debugPrint('🚐 KombiEtaWidget: putnikIme=${widget.putnikIme}, eta=$eta, putniciEta=$putniciEta');

      setState(() {
        _isActive = true;
        _vozacStartovaoRutu = hasEtaData;
        // Postavi vreme pokupljenja ako je ETA -1 (pokupljen) i još nije setovano
        if (eta == -1 && _vremePokupljenja == null) {
          _vremePokupljenja = DateTime.now();
        }
        // Resetuj vreme pokupljenja ako ETA više nije -1 (nova vožnja)
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

  void _startListening() {
    _loadGpsData();
    _subscription = RealtimeManager.instance.subscribe('vozac_lokacije').listen((payload) {
      _loadGpsData();
    });
  }

  /// 🆕 Odredi trenutnu fazu widgeta
  _WidgetFaza _getCurrentFaza() {
    final bool isPokupljen = _etaMinutes == -1;

    // Faza 3 & 4: Pokupljen (ETA == -1) - ALI samo ako je vozač aktivan!
    // Ako vozač nije aktivan, ignoriši stari -1 iz baze
    if (isPokupljen && _isActive) {
      // Ako nemamo vreme pokupljenja, postavi ga sada
      _vremePokupljenja ??= DateTime.now();
      final minutesSincePokupljenje = DateTime.now().difference(_vremePokupljenja!).inMinutes;
      if (minutesSincePokupljenje <= 60) {
        return _WidgetFaza.pokupljen; // Faza 3: Prikazuj "Pokupljeni ste" 60 min
      } else {
        return _WidgetFaza.sledecaVoznja; // Faza 4: Prikazuj sledeću vožnju
      }
    }

    // Faza 2: Vozač startovao rutu i ima ETA
    if (_isActive && _vozacStartovaoRutu && _etaMinutes != null && _etaMinutes! >= 0) {
      return _WidgetFaza.pracenje;
    }

    // Faza 1: Čekanje (vozač aktivan ali nije startovao rutu, ili nema ETA za ovog putnika)
    if (_isActive || widget.vremePolaska != null) {
      return _WidgetFaza.cekanje;
    }

    // Default: Čekanje
    return _WidgetFaza.cekanje;
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

    // Ako nema aktivnog vozača i nismo u fazi pokupljen/sledeca, sakrij widget
    if (!_isActive && faza == _WidgetFaza.cekanje && widget.vremePolaska == null) {
      return const SizedBox.shrink();
    }

    // Odredi sadržaj na osnovu faze
    final String title;
    final String message;
    final Color baseColor;
    final IconData? icon;

    switch (faza) {
      case _WidgetFaza.cekanje:
        // Faza 1: 30 min pre polaska
        title = '🚐 PRAĆENJE UŽIVO';
        message = 'Vozač će uskoro krenuti';
        baseColor = Colors.grey;
        icon = Icons.schedule;

      case _WidgetFaza.pracenje:
        // Faza 2: Realtime ETA
        title = '🚐 KOMBI STIŽE ZA';
        message = _formatEta(_etaMinutes!);
        baseColor = Colors.blue;
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
        baseColor = Colors.green;
        icon = Icons.check_circle;

      case _WidgetFaza.sledecaVoznja:
        // Faza 4: Sledeća vožnja
        title = '📅 SLEDEĆA VOŽNJA';
        message = widget.sledecaVoznja ?? 'Nema zakazanih vožnji';
        baseColor = Colors.purple;
        icon = Icons.event;
    }

    return _buildContainer(
      baseColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 24),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
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
              fontSize: faza == _WidgetFaza.pracenje ? 28 : 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (_vozacIme != null && faza == _WidgetFaza.pracenje)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Vozač: $_vozacIme',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContainer(Color baseColor, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withValues(alpha: 0.5),
            baseColor.withValues(alpha: 0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: baseColor.withValues(alpha: 0.6),
          width: 2,
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
