import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dnevni_putnik_screen.dart';

/// 🕐 Ekran koji dnevni putnik vidi dok čeka odobrenje admina
class PutnikCekanjeScreen extends StatefulWidget {
  final String zahtevId;
  final String ime;
  final String prezime;

  const PutnikCekanjeScreen({
    super.key,
    required this.zahtevId,
    required this.ime,
    required this.prezime,
  });

  @override
  State<PutnikCekanjeScreen> createState() => _PutnikCekanjeScreenState();
}

class _PutnikCekanjeScreenState extends State<PutnikCekanjeScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _status = 'pending';
  StreamSubscription? _statusSubscription;
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _checkStatus();
    _setupRealtimeListener();

    // Fallback: proveri status svakih 10 sekundi
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkStatus();
    });
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _setupRealtimeListener() {
    _statusSubscription =
        _supabase.from('zahtevi_pristupa').stream(primaryKey: ['id']).eq('id', widget.zahtevId).listen((data) {
              if (data.isNotEmpty) {
                final newStatus = data.first['status'] as String?;
                if (newStatus != null && newStatus != _status) {
                  setState(() => _status = newStatus);
                  _handleStatusChange(newStatus);
                }
              }
            });
  }

  Future<void> _checkStatus() async {
    try {
      final response = await _supabase.from('zahtevi_pristupa').select('status').eq('id', widget.zahtevId).single();

      final newStatus = response['status'] as String?;
      if (newStatus != null && newStatus != _status && mounted) {
        setState(() => _status = newStatus);
        _handleStatusChange(newStatus);
      }
    } catch (e) {
      debugPrint('Greška pri proveri statusa: $e');
    }
  }

  void _handleStatusChange(String status) {
    if (status == 'approved') {
      _onApproved();
    } else if (status == 'rejected') {
      _onRejected();
    }
  }

  Future<void> _onApproved() async {
    // Sačuvaj podatke u SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dnevni_putnik_id', widget.zahtevId);
    await prefs.setString('dnevni_putnik_ime', '${widget.ime} ${widget.prezime}');
    await prefs.setBool('dnevni_putnik_approved', true);

    if (!mounted) return;

    // Prikaži poruku i idi na glavni ekran
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Tvoj zahtev je odobren! Dobrodošao/la!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DnevniPutnikScreen(
            putnikId: widget.zahtevId,
            ime: widget.ime,
            prezime: widget.prezime,
          ),
        ),
      );
    }
  }

  void _onRejected() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Zahtev odbijen'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nažalost, tvoj zahtev za pristup je odbijen.'),
            SizedBox(height: 12),
            Text(
              'Možeš pokušati ponovo ili kontaktirati Gavra prevoz za više informacija.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Vrati na welcome
            },
            child: const Text('U redu'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusSubscription?.cancel();
    _checkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animirana ikona
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.hourglass_empty,
                            size: 60,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Pozdrav
                  Text(
                    'Zdravo, ${widget.ime}! 👋',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Status poruka
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.pending_actions,
                          size: 48,
                          color: Colors.orange.shade600,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Tvoj zahtev je poslat!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Čekamo da admin pregleda i odobri tvoj zahtev za pristup.\n\nOvo obično traje nekoliko minuta.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Loading indikator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue.shade400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Čekam odobrenje...',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Info kartica
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Možeš zatvoriti aplikaciju - dobićeš pristup čim admin odobri zahtev.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Dugme za nazad
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Nazad na početnu'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
