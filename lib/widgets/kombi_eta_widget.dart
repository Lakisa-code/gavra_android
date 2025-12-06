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
    // Ne prikazuj ništa ako nije aktivan vozač
    if (!_isActive && !_isLoading) {
      return const SizedBox.shrink();
    }

    // Loading state
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    // Ako nema ETA za ovog putnika (nije u ruti)
    if (_etaMinutes == null) {
      return const SizedBox.shrink();
    }

    // Prikaži ETA widget
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade600,
            Colors.blue.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ikona kombija
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_bus,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🚐 KOMBI STIŽE ZA',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatEta(_etaMinutes!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_vozacIme != null)
                  Text(
                    'Vozač: $_vozacIme',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          // Animirana ikona
          _buildPulsingIcon(),
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

  Widget _buildPulsingIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.2),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.schedule,
              color: Colors.greenAccent,
              size: 24,
            ),
          ),
        );
      },
      onEnd: () {
        // Restart animacije - ne radi dobro ovako, ali OK za sada
      },
    );
  }
}
