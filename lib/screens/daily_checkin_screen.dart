import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/daily_checkin_service.dart';
import '../theme.dart';
import '../utils/smart_colors.dart';
import '../utils/vozac_boja.dart';

class DailyCheckInScreen extends StatefulWidget {
  const DailyCheckInScreen({
    Key? key,
    required this.vozac,
    required this.onCompleted,
  }) : super(key: key);
  final String vozac;
  final VoidCallback onCompleted;

  @override
  State<DailyCheckInScreen> createState() => _DailyCheckInScreenState();
}

class _DailyCheckInScreenState extends State<DailyCheckInScreen> with TickerProviderStateMixin {
  final TextEditingController _kusurController = TextEditingController();
  final FocusNode _kusurFocusNode = FocusNode();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    // Auto-focus na input field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kusurFocusNode.requestFocus();
      // 📊 POMERENO: Popis se prikazuje tek nakon unosa kusura u _submitKusur()
    });
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
    _kusurController.dispose();
    _kusurFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitCheckIn() async {
    if (_kusurController.text.trim().isEmpty) {
      _showError('Unesite iznos sitnog novca!');
      return;
    }

    final double? iznos = double.tryParse(_kusurController.text.trim());

    if (iznos == null || iznos < 0) {
      _showError('Unesite valjan iznos za kusur!');
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      // 🚀 DIREKTAN POZIV - Opet bez kilometraže
      await DailyCheckInService.saveCheckIn(widget.vozac, iznos);

      if (mounted) {
        // Reset loading state first
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
    final vozacColor = VozacBoja.get(widget.vozac);

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
                              softVozacColor.withValues(alpha: 0.8),
                              softVozacColor.withValues(alpha: 0.4),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: softVozacColor.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                            // Dodatni warm glow
                            BoxShadow(
                              color: const Color(0xFFFFE0B2).withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.light_mode_outlined, // Mekša jutarnja ikona
                          size: 60,
                          color: Colors.white.withValues(alpha: 0.95),
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
                              color: Colors.white.withValues(alpha: 0.8),
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
                          color: vozacColor.withValues(alpha: 0.9),
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.white.withValues(alpha: 0.8),
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
                          color: lightVozacColor.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: vozacColor.withValues(alpha: 0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: vozacColor.withValues(alpha: 0.15),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: vozacColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Unesite iznos sitnog novca za kusur',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Input field - Kusur
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: vozacColor.withValues(alpha: 0.2),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _kusurController,
                          focusNode: _kusurFocusNode,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'Sitan novac (kusur)',
                            labelStyle: TextStyle(color: vozacColor, fontSize: 14),
                            hintText: '0',
                            hintStyle: TextStyle(
                              color: primaryTextColor.withValues(alpha: 0.4),
                              fontSize: 24,
                            ),
                            suffixText: 'RSD',
                            suffixStyle: TextStyle(
                              color: vozacColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            filled: true,
                            fillColor: lightVozacColor.withValues(alpha: 0.6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: vozacColor,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                          ),
                          onSubmitted: (_) => _submitCheckIn(),
                        ),
                      ),

                      const SizedBox(height: 32),

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
                            shadowColor: vozacColor.withValues(alpha: 0.3),
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
