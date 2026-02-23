import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../globals.dart';
import '../services/realtime/realtime_manager.dart';
import '../utils/grad_adresa_validator.dart';

/// Widget koji prikazuje ETA dolaska kombija.
/// - Uvek vidljiv sa informativnom porukom
/// - Kada vozač startuje rutu: prikazuje ETA uživo
/// - Kada vozač pokupi putnika: prikazuje vreme pokupljenja pa se gasi
class KombiEtaWidget extends StatefulWidget {
  const KombiEtaWidget({
    super.key,
    required this.putnikIme,
    required this.grad,
    this.sledecaVoznja,
    this.putnikId,
    this.vreme,
  });

  final String putnikIme;
  final String grad;
  final String? sledecaVoznja;
  final String? putnikId;
  final String? vreme; // Termin polaska putnika npr. '7:00'

  @override
  State<KombiEtaWidget> createState() => _KombiEtaWidgetState();
}

class _KombiEtaWidgetState extends State<KombiEtaWidget> {
  StreamSubscription? _subscription;
  StreamSubscription? _putnikSubscription;
  Timer? _pollingTimer;
  int? _etaMinutes;
  bool _isLoading = true;
  bool _isActive = false;
  String? _vozacIme;
  DateTime? _vremePokupljenja;
  bool _jePokupljenIzBaze = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _subscription?.cancel();
    _putnikSubscription?.cancel();
    RealtimeManager.instance.unsubscribe('vozac_lokacije');
    if (widget.putnikId != null) {
      RealtimeManager.instance.unsubscribe('seat_requests');
    }
    super.dispose();
  }

  Future<void> _loadGpsData() async {
    try {
      final normalizedGrad = GradAdresaValidator.normalizeGrad(widget.grad);
      final data = await supabase.from('vozac_lokacije').select().eq('aktivan', true);
      if (!mounted) return;

      final list = data as List<dynamic>;
      final normVreme = widget.vreme != null ? GradAdresaValidator.normalizeTime(widget.vreme!) : null;

      final filteredList = list.where((driver) {
        final driverGrad = driver['grad'] as String? ?? '';
        if (GradAdresaValidator.normalizeGrad(driverGrad) != normalizedGrad) return false;
        if (normVreme != null) {
          final driverVreme = driver['vreme_polaska'] as String? ?? '';
          if (GradAdresaValidator.normalizeTime(driverVreme) != normVreme) return false;
        }
        return true;
      }).toList();

      if (filteredList.isEmpty) {
        setState(() {
          _isActive = false;
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

      int? eta;
      if (putniciEta != null) {
        if (putniciEta.containsKey(widget.putnikIme)) {
          eta = putniciEta[widget.putnikIme] as int?;
        } else {
          for (final entry in putniciEta.entries) {
            if (entry.key.toLowerCase() == widget.putnikIme.toLowerCase()) {
              eta = entry.value as int?;
              break;
            }
          }
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

      setState(() {
        _isActive = true;
        if (eta == -1 && _vremePokupljenja == null) {
          _vremePokupljenja = DateTime.now();
          _jePokupljenIzBaze = true;
        }
        if (eta != null && eta >= 0) {
          _vremePokupljenja = null;
          _jePokupljenIzBaze = false;
        }
        _etaMinutes = eta;
        _vozacIme = driver['vozac_ime'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isActive = false;
        });
      }
    }
  }

  void _startListening() {
    _loadGpsData();
    _loadPokupljenjeIzBaze();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadGpsData());
    _subscription = RealtimeManager.instance.subscribe('vozac_lokacije').listen(
          (payload) => _loadGpsData(),
          onError: (_) {},
        );
    if (widget.putnikId != null) {
      _putnikSubscription = RealtimeManager.instance.subscribe('seat_requests').listen(
            (payload) => _loadPokupljenjeIzBaze(),
            onError: (_) {},
          );
    }
  }

  Future<void> _loadPokupljenjeIzBaze() async {
    if (widget.putnikId == null) return;
    try {
      const dani = ['ned', 'pon', 'uto', 'sre', 'cet', 'pet', 'sub'];
      final danasKratica = dani[DateTime.now().weekday % 7];

      final response = await supabase
          .from('seat_requests')
          .select('status, updated_at')
          .eq('putnik_id', widget.putnikId!)
          .eq('status', 'pokupljen')
          .eq('dan', danasKratica)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        final updatedAt = response['updated_at'] as String?;
        final parsedTime = updatedAt != null ? DateTime.tryParse(updatedAt) : null;
        setState(() {
          _jePokupljenIzBaze = true;
          _vremePokupljenja = parsedTime?.toLocal() ?? DateTime.now();
        });
      } else if (_jePokupljenIzBaze) {
        setState(() {
          _jePokupljenIzBaze = false;
          _vremePokupljenja = null;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [KombiEta] Greška pri čitanju seat_requests: $e');
    }
  }

  // Faza 1 — uvek vidljiv default info widget
  Widget _buildFaza1() {
    return _buildContainer(
      Colors.white,
      icon: Icons.directions_bus,
      title: '🚐 PRAĆENJE KOMBIJA',
      message: 'Ovde će biti prikazano vreme dolaska kombija kada vozač krene',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dok se učitava — prikaži Fazu 1 sa spinnerom (ne prazan container)
    if (_isLoading) {
      return _buildContainer(
        Colors.white,
        icon: Icons.directions_bus,
        title: '🚐 PRAĆENJE KOMBIJA',
        message: '',
        isLoading: true,
      );
    }

    // Pokupljen — prikaži zelenu potvrdu max 60 min, pa nazad na Fazu 1
    if (_jePokupljenIzBaze && _vremePokupljenja != null) {
      final minutesSince = DateTime.now().difference(_vremePokupljenja!).inMinutes;
      if (minutesSince <= 60) {
        final h = _vremePokupljenja!.hour.toString().padLeft(2, '0');
        final m = _vremePokupljenja!.minute.toString().padLeft(2, '0');
        return _buildContainer(
          Colors.green.shade600,
          icon: Icons.check_circle,
          title: '✅ POKUPLJENI STE',
          message: 'u $h:$m • Želimo ugodnu vožnju! 🚐',
        );
      }
      // Prošlo > 60 min od pokupljenja — nazad na Fazu 1
      return _buildFaza1();
    }

    // Faza 2 — Vozač aktivan i ima ETA za ovog putnika
    if (_isActive && _etaMinutes != null && _etaMinutes! >= 0) {
      return _buildContainer(
        Colors.blue.shade700,
        icon: Icons.directions_bus,
        title: '🚐 KOMBI STIŽE ZA',
        message: _formatEta(_etaMinutes!),
        subtitle: _vozacIme != null ? 'Vozač: $_vozacIme' : null,
        bigMessage: true,
      );
    }

    // Faza 2 — Vozač aktivan ali ETA još nije izračunat
    if (_isActive) {
      return _buildContainer(
        Colors.white,
        icon: Icons.schedule,
        title: '🚐 PRAĆENJE KOMBIJA',
        message: 'Vozač kreće uskoro',
      );
    }

    // Faza 1 — nema aktivnog vozača
    return _buildFaza1();
  }

  Widget _buildContainer(
    Color baseColor, {
    required IconData icon,
    required String title,
    required String message,
    String? subtitle,
    bool bigMessage = false,
    bool isLoading = false,
  }) {
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
      child: isLoading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            )
          : Column(
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
                    fontSize: bigMessage ? 28 : 16,
                    fontWeight: bigMessage ? FontWeight.bold : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
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
