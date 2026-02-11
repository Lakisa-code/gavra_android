import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/daily_checkin_service.dart';
import '../theme.dart';
import '../utils/smart_colors.dart';
import '../utils/vozac_boja.dart';

class DailyCheckInScreen extends StatefulWidget {
  const DailyCheckInScreen({
    super.key,
    required this.vozac,
    required this.onCompleted,
  });
  final String vozac;
  final VoidCallback onCompleted;

  @override
  State<DailyCheckInScreen> createState() => _DailyCheckInScreenState();
}

class _DailyCheckInScreenState extends State<DailyCheckInScreen> with TickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submitCheckIn() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      // 🚀 DIREKTAN POZIV - bez sitnog novca
      await DailyCheckInService.saveCheckIn(widget.vozac);

      if (mounted) {
        setState(() => _isLoading = false);

        // Haptic feedback
        HapticFeedback.lightImpact();

        // Success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Dobro jutro ${widget.vozac}! Uspešno zabeleženo.'),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.smartSuccess,
            duration: const Duration(milliseconds: 800),
          ),
        );

        // Pozovi callback posle kratkog delay-a
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            widget.onCompleted();
          }
        });
      }
    } catch (e) {
      debugPrint('❌ DailyCheckIn Supabase error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Greška pri čuvanju: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.smartError,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 KORISTI BOJU VOZAČA KAO GLAVNU TEMU
    final vozacColor = VozacBoja.getSync(widget.vozac);

    // 🎨 Kreiranje paleta boja na osnovu vozačeve boje
    final lightVozacColor = Color.lerp(vozacColor, Colors.white, 0.7)!; // Vrlo svetla verzija
    final softVozacColor = Color.lerp(vozacColor, Colors.white, 0.4)!; // Mekša verzija
    final deepVozacColor = Color.lerp(vozacColor, Colors.black, 0.2)!; // Tamnija verzija

    // 🎨 Text boje bazirane na vozačevoj boji
    final primaryTextColor = deepVozacColor; // Tamni tekst na svetloj pozadini
    final secondaryTextColor = Color.lerp(vozacColor, Colors.black, 0.5)!;

    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Dnevna Prijava - ${widget.vozac}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 3,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 80,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).glassContainer,
              border: Border.all(
                color: Theme.of(context).glassBorder,
                width: 1.5,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
              // no boxShadow: appbar remains fully transparent and border-only
            ),
          ),
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Jutarnja ikona - mekša i toplija
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              softVozacColor.withOpacity(0.8),
                              softVozacColor.withOpacity(0.4),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: softVozacColor.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                            // Dodatni warm glow
                            BoxShadow(
                              color: const Color(0xFFFFE0B2).withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.light_mode_outlined, // Mekša jutarnja ikona
                          size: 60,
                          color: Colors.white.withOpacity(0.95),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Jutarnji pozdrav
                      Text(
                        'Dobro jutro',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          color: primaryTextColor,
                          shadows: [
                            Shadow(
                              color: Colors.white.withOpacity(0.8),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        widget.vozac,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: vozacColor.withOpacity(0.9),
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.white.withOpacity(0.8),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Mekše instrukcije
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: lightVozacColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: vozacColor.withOpacity(0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: vozacColor.withOpacity(0.15),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: vozacColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Pritisnite "Potvrdi" da započnete dan',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  HapticFeedback.mediumImpact(); // Dodaj haptic feedback
                                  _submitCheckIn();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: vozacColor,
                            foregroundColor: Colors.white,
                            elevation: 6,
                            shadowColor: vozacColor.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Potvrdi',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

