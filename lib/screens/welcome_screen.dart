import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/vozac.dart';
import '../services/auth_manager.dart';
import '../services/biometric_service.dart';
import '../services/daily_checkin_service.dart';
import '../services/local_notification_service.dart';
import '../services/permission_service.dart';
import '../services/realtime_notification_service.dart';
import '../services/theme_manager.dart';
import '../services/vozac_service.dart';
import '../utils/vozac_boja.dart';
import 'daily_checkin_screen.dart';
import 'home_screen.dart';
import 'o_nama_screen.dart';
import 'registrovani_putnik_login_screen.dart';
import 'vozac_login_screen.dart';
import 'vozac_screen.dart';

Widget _getHomeScreen() {
  return const HomeScreen();
}

Widget _getScreenForDriver(String driverName) {
  // Vozači koji koriste VozacScreen umesto HomeScreen
  if (driverName == 'Ivan' || driverName == 'Voja') {
    return const VozacScreen();
  }
  return const HomeScreen();
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAudioPlaying = false;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;

  // Lista vozača učitana iz baze
  List<Vozac> _drivers = [];
  bool _isLoadingDrivers = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Dodano za lifecycle

    _setupAnimations();
    _loadDrivers();

    // Inicijalizacija bez blokiranja - dajemo aplikaciji vremena da "udahne"
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _initServicesRecursively();
    });
  }

  /// Učitaj vozače iz baze
  Future<void> _loadDrivers() async {
    try {
      final vozacService = VozacService();
      final vozaci = await vozacService.getAllVozaci();
      if (!mounted) return;
      setState(() {
        _drivers = vozaci;
        _isLoadingDrivers = false;
      });
    } catch (e) {
      // Fallback na hardkodovane vozače
      if (!mounted) return;
      setState(() {
        _drivers = [
          Vozac(
            ime: 'Bruda',
            email: 'igor.jovanovic.1984@icloud.com',
            sifra: '111111',
            brojTelefona: '+381641202844',
            boja: '7C4DFF',
          ),
          Vozac(
            ime: 'Bilevski',
            email: 'bilyboy1983@gmail.com',
            sifra: '222222',
            brojTelefona: '+381638466418',
            boja: 'FF9800',
          ),
          Vozac(
            ime: 'Ivan',
            email: 'bradvarevicivan99@gmail.com',
            sifra: '333333',
            brojTelefona: '+381677662993',
            boja: 'FFD700',
          ),
          Vozac(
            ime: 'Bojan',
            email: 'gavriconi19@gmail.com',
            sifra: '191919',
            brojTelefona: '+381641162560',
            boja: '00E5FF',
          ),
        ];
        _isLoadingDrivers = false;
      });
    }
  }

  /// 🛠️ Inicijalizacija servisa jedan po jedan, bez agresivnih await-ova
  Future<void> _initServicesRecursively() async {
    try {
      // 1. Notifikacije
      unawaited(LocalNotificationService.initialize(context));

      // 2. Dozvole (ovo otvara dialog, pa mora biti lagano)
      if (mounted) {
        await PermissionService.requestAllPermissionsOnFirstLaunch(context);
      }

      // 3. Auto-login
      if (mounted) {
        _ensureNotificationPermissions();
        _checkAutoLogin();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [WelcomeScreen] Init failed: $e');
    }
  }

  Future<void> _ensureNotificationPermissions() async {
    try {
      // On Android request POST_NOTIFICATIONS runtime permission (API 33+)
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        } else {}
      }

      // Also request Firebase/iOS style permissions via RealtimeNotificationService
      try {
        await RealtimeNotificationService.requestNotificationPermissions();
      } catch (e) {
        // Silently ignore permission errors
      }
    } catch (e) {
      // Silently ignore
    }
  }

  // 🔄 AUTO-LOGIN BEZ PESME - Proveri da li je vozač već logovan
  Future<void> _checkAutoLogin() async {
    // 🎵 PREKINI PESMU ako se auto-login aktivira
    await _stopAudio();

    // 📱 PRVO PROVERI REMEMBERED DEVICE
    final rememberedDevice = await AuthManager.getRememberedDevice();
    if (rememberedDevice != null) {
      // Auto-login sa zapamćenim uređajem
      final email = rememberedDevice['email']!;
      // 🔄 FORSIRAJ ISPRAVNO MAPIRANJE: email -> vozač ime
      final driverName = VozacBoja.getVozacForEmail(email);
      // Ne dozvoli auto-login ako vozač nije prepoznat
      if (driverName == null || !VozacBoja.isValidDriver(driverName)) {
        // Ostani na welcome/login i ne auto-login
        return;
      }

      // Postavi driver session
      await AuthManager.setCurrentDriver(driverName);

      if (!mounted) return;

      // Direktno na Daily Check-in ili Home Screen
      final hasCheckedIn = await DailyCheckInService.hasCheckedInToday(driverName);

      if (!hasCheckedIn) {
        if (!mounted) return;
        // Navigate to DailyCheckInScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (context) => DailyCheckInScreen(
              vozac: driverName,
              onCompleted: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => _getScreenForDriver(driverName),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (context) => _getScreenForDriver(driverName),
          ),
        );
      }
      return;
    }

    // Koristi AuthManager za session management
    final activeDriver = await AuthManager.getCurrentDriver();

    if (activeDriver != null && activeDriver.isNotEmpty) {
      // Vozač je već logovan - PROVERI DAILY CHECK-IN
      // (dozvole su već zatražene u _requestPermissionsAndCheckLogin)

      // 📅 PROVERI DA LI JE VOZAČ URADIO DAILY CHECK-IN
      final hasCheckedIn = await DailyCheckInService.hasCheckedInToday(activeDriver);

      if (!mounted) return;

      if (!hasCheckedIn) {
        // Navigate to DailyCheckInScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (context) => DailyCheckInScreen(
              vozac: activeDriver,
              onCompleted: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const HomeScreen(),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        // DIREKTNO NA HOME SCREEN
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (context) => _getHomeScreen()),
        );
      }
    }
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Uklanjamo observer
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _audioPlayer.dispose(); // Dodano za cleanup audio player-a
    super.dispose();
  }

  // Dodano za praćenje lifecycle-a aplikacije
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        // Aplikacija ide u pozadinu - zaustavi muziku
        _stopAudio();
        break;
      case AppLifecycleState.resumed:
        // Aplikacija se vraća u foreground - ne radi ništa
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // Zaustavi muziku i u ovim stanjima
        _stopAudio();
        break;
      case AppLifecycleState.hidden:
        // Zaustavi muziku kada je skrivena
        _stopAudio();
        break;
    }
  }

  // Helper metoda za zaustavljanje pesme
  Future<void> _stopAudio() async {
    try {
      if (_isAudioPlaying) {
        await _audioPlayer.stop();
        _isAudioPlaying = false;
      }
    } catch (e) {
      // Swallow audio errors silently
    }
  }

  Future<void> _loginAsDriver(String driverName) async {
    // 🎵 PREKINI PESMU kada korisnik počne login
    await _stopAudio();

    // Uklonjena striktna validacija vozača - dozvoljava sve vozače

    // 📱 PRVO PROVERI REMEMBERED DEVICE za ovog vozača
    final rememberedDevice = await AuthManager.getRememberedDevice();
    if (rememberedDevice != null) {
      final rememberedEmail = rememberedDevice['email']!;
      final rememberedName = rememberedDevice['driverName']!;

      // 🔄 FORSIRAJ REFRESH: Koristi VozacBoja mapiranje za ispravno ime
      final correctName = VozacBoja.getVozacForEmail(rememberedEmail) ?? rememberedName;

      if (correctName == driverName) {
        // 👆 BIOMETRIJA: Ako je UKLJUČENA i dostupna, zahtevaj potvrdu pre auto-logina
        final biometricAvailable = await BiometricService.isBiometricAvailable();
        final biometricEnabled = await BiometricService.isBiometricEnabled();

        if (biometricAvailable && biometricEnabled) {
          final authenticated = await BiometricService.authenticate(
            reason: 'Potvrdi identitet za prijavu kao $correctName',
          );

          if (!authenticated) {
            // Korisnik je otkazao ili nije uspeo - idi na manual login
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => VozacLoginScreen(vozacIme: driverName),
              ),
            );
            return;
          }
        }

        // Ovaj vozač je zapamćen na ovom uređaju - DIREKTNO AUTO-LOGIN
        await AuthManager.setCurrentDriver(correctName);

        if (!mounted) return;

        // Direktno na Daily Check-in ili Home Screen
        final hasCheckedIn = await DailyCheckInService.hasCheckedInToday(correctName);

        if (!hasCheckedIn) {
          if (!mounted) return;
          // Navigate to DailyCheckInScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (context) => DailyCheckInScreen(
                vozac: correctName,
                onCompleted: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => _getScreenForDriver(correctName),
                    ),
                  );
                },
              ),
            ),
          );
        } else {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (context) => _getScreenForDriver(correctName),
            ),
          );
        }
      }
    }

    // AKO NIJE REMEMBERED DEVICE - IDI NA VOZAČ LOGIN
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => VozacLoginScreen(vozacIme: driverName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: ThemeManager().currentGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(height: screenHeight * 0.04),

                  // 🎨 LOGO sa shimmer efektom
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: GestureDetector(
                      onTap: () async {
                        try {
                          if (_isAudioPlaying) {
                            await _audioPlayer.stop();
                            _isAudioPlaying = false;
                          } else {
                            await _audioPlayer.setVolume(0.5);
                            await _audioPlayer.play(AssetSource('kasno_je.mp3'));
                            _isAudioPlaying = true;
                          }
                        } catch (_) {}
                      },
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                begin: Alignment(-1.5 + 3 * _pulseController.value, 0),
                                end: Alignment(-0.5 + 3 * _pulseController.value, 0),
                                colors: [
                                  Colors.white.withValues(alpha: 0.6),
                                  Colors.white,
                                  Colors.white.withValues(alpha: 0.6),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.srcATop,
                            child: child,
                          );
                        },
                        child: Image.asset(
                          'assets/logo_transparent.png',
                          height: 180,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🎯 DOBRODOŠLI tekst - klikabilno za promenu teme
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: GestureDetector(
                      onTap: () async {
                        await ThemeManager().nextTheme();
                        if (mounted) setState(() {});
                      },
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.amber.shade200,
                            Colors.white,
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          'DOBRODOŠLI',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Vaš pouzdani prevoz',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 2,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.05),

                  // 🚀 GLAVNO DUGME - PRIJAVA PUTNIKA
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegistrovaniPutnikLoginScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber,
                              Colors.amber.shade700,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.login,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Prijavi se',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 📱 SEKUNDARNA DUGMAD - O nama i Vozači
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Row(
                      children: [
                        // O NAMA
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ONamaScreen()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'O nama',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // VOZAČI
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showDriverSelectionDialog(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.local_taxi,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Vozači',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.08),

                  // 📝 FOOTER
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.3),
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Designed • Developed • Crafted with balls',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'by Bojan Gavrilovic',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'v6.0.15 • 2025-2026',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.5),
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🚗 Dijalog za izbor vozača
  void _showDriverSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Izaberi vozača',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                if (_isLoadingDrivers)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  ..._drivers.map((driver) {
                    // Odredi ikonu na osnovu imena vozača
                    IconData getIconForDriver(String name) {
                      switch (name.toLowerCase()) {
                        case 'bruda':
                          return Icons.local_taxi;
                        case 'bilevski':
                          return Icons.directions_car;
                        case 'ivan':
                          return Icons.directions_car;
                        case 'bojan':
                          return Icons.airport_shuttle;
                        default:
                          return Icons.person;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context); // Zatvori dijalog
                          _loginAsDriver(driver.ime);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                (driver.color ?? Colors.blue).withValues(alpha: 0.8),
                                Colors.white.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (driver.color ?? Colors.blue).withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                getIconForDriver(driver.ime),
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                driver.ime,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Otkaži',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
