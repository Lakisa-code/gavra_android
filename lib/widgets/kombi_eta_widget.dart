import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🚐 Jednostavan widget koji prikazuje ETA dolaska kombija
/// Čita iz Supabase vozac_lokacije.putnici_eta
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
    // Slušaj promene u vozac_lokacije tabeli za ovaj grad
    _subscription = Supabase.instance.client
        .from('vozac_lokacije')
        .stream(primaryKey: ['id'])
        .eq('grad', widget.grad)
        .listen((list) {
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
    // Odredi boje i poruku na osnovu stanja
    final bool hasEta = _isActive && _etaMinutes != null;

    // Boje: plava ako ima ETA, siva ako čeka
    final Color primaryColor = hasEta ? Colors.blue.shade600 : Colors.grey.shade500;
    final Color secondaryColor = hasEta ? Colors.blue.shade800 : Colors.grey.shade700;

    // Poruka i naslov - samo "Čekanje..." ako nema ETA
    final String title = hasEta ? '🚐 KOMBI STIŽE ZA' : '🚐 KOMBI STATUS';
    final String message = hasEta ? _formatEta(_etaMinutes!) : 'Čekanje...';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
              fontSize: hasEta ? 28 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_vozacIme != null && hasEta)
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
