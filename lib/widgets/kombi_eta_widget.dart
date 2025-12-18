import 'dart:async';

import 'package:flutter/material.dart';

import '../services/realtime_hub_service.dart';

/// Widget koji prikazuje ETA dolaska kombija
class KombiEtaWidget extends StatefulWidget {
  const KombiEtaWidget({
    Key? key,
    required this.putnikIme,
    required this.grad,
  }) : super(key: key);

  final String putnikIme;
  final String grad;

  @override
  State<KombiEtaWidget> createState() => _KombiEtaWidgetState();
}

class _KombiEtaWidgetState extends State<KombiEtaWidget> {
  StreamSubscription? _subscription;
  int? _etaMinutes;
  bool _isLoading = true;
  bool _isActive = false;
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
    super.dispose();
  }

  void _startListening() {
    _subscription = RealtimeHubService.instance.gpsStreamPoGradu(widget.grad).listen((list) {
      if (!mounted) return;

      // Nađi aktivnog vozača
      final activeDrivers = list.where((l) => l['aktivan'] == true).toList();

      if (activeDrivers.isEmpty) {
        setState(() {
          _isActive = false;
          _etaMinutes = null;
          _isLoading = false;
        });
        return;
      }

      // Uzmi prvog aktivnog vozača
      final driver = activeDrivers.first;
      final putniciEta = driver['putnici_eta'] as Map<String, dynamic>?;
      final vozacIme = driver['vozac_ime'] as String?;

      // Pronađi ETA za ovog putnika
      int? eta;
      if (putniciEta != null) {
        // Probaj tačno ime
        if (putniciEta.containsKey(widget.putnikIme)) {
          eta = putniciEta[widget.putnikIme] as int?;
        } else {
          // Probaj case-insensitive pretragu
          for (final entry in putniciEta.entries) {
            if (entry.key.toLowerCase() == widget.putnikIme.toLowerCase()) {
              eta = entry.value as int?;
              break;
            }
          }
        }
      }

      setState(() {
        _isActive = true;
        // Zapamti vreme kada se status promeni na pokupljen
        if (eta == -1 && _etaMinutes != -1) {
          _vremePokupljenja = DateTime.now();
        }
        _etaMinutes = eta;
        _vozacIme = vozacIme;
        _isLoading = false;
      });
    }, onError: (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isActive = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade400, Colors.grey.shade600],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
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

    // Odredi boje i poruku na osnovu stanja
    final bool hasEta = _isActive && _etaMinutes != null;
    final bool isPokupljen = _etaMinutes == -1;

    // Poruka i naslov
    final String title;
    final String message;

    if (isPokupljen) {
      title = '✅ POKUPLJEN';
      // Prikaži vreme pokupljenja
      if (_vremePokupljenja != null) {
        final h = _vremePokupljenja!.hour.toString().padLeft(2, '0');
        final m = _vremePokupljenja!.minute.toString().padLeft(2, '0');
        message = 'U $h:$m - Uživajte u vožnji!';
      } else {
        message = 'Uživajte u vožnji!';
      }
    } else if (hasEta) {
      title = '🚐 KOMBI STIŽE ZA';
      message = _formatEta(_etaMinutes!);
    } else {
      title = '🚐 PRAĆENJE UŽIVO';
      message = 'Vozač će uskoro krenuti';
    }

    // Boje sa providnošću kao IZMIRENO kocka
    // Zelena kad je pokupljen, plava kad ima ETA, siva kad čeka
    final Color baseColor = isPokupljen ? Colors.green : (hasEta ? Colors.blue : Colors.grey);

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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
              fontSize: isPokupljen ? 18 : (hasEta ? 28 : 18),
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_vozacIme != null && hasEta && !isPokupljen)
            Text(
              'Vozač: $_vozacIme',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  String _formatEta(int minutes) {
    if (minutes < 1) return '< 1 min';
    if (minutes == 1) return '~1 minut';
    if (minutes < 5) return '~$minutes minuta';
    return '~$minutes min';
  }
}
