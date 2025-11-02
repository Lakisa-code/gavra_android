import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/auth_manager.dart';
import '../services/local_notification_service.dart';
import '../services/permission_service.dart';
import '../services/realtime_notification_service.dart';
import '../services/simplified_daily_checkin.dart';
import '../theme.dart';
import '../utils/vozac_boja.dart';
import 'daily_checkin_screen.dart';
import 'email_login_screen.dart';
import 'home_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Lista vozača za email sistem - koristi VozacBoja utility
  final List<Map<String, dynamic>> _drivers = [
    {
      'name': 'Bilevski',
      'color': VozacBoja.get('Bilevski'),
      'icon': Icons.directions_car,
    },
    {
      'name': 'Bruda',
      'color': VozacBoja.get('Bruda'),
      'icon': Icons.local_taxi,
    },
    {
      'name': 'Bojan',
      'color': VozacBoja.get('Bojan'),
      'icon': Icons.airport_shuttle,
    },
    {
      'name': 'Svetlana',
      'color': VozacBoja.get('Svetlana'),
      'icon': Icons.favorite,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Dodano za lifecycle

    _setupAnimations();
    // Inicijalizacija lokalnih notifikacija
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocalNotificationService.initialize(context);
      // Ensure runtime notification permission on Android 13+
      _ensureNotificationPermissions();
      _checkAutoLogin(); // AUTO-LOGIN BEZ PESME - auto-login BEZ pesme
    });
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
      } catch (e) {}
    } catch (e) {}
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
      final driverName = VozacBoja.getVozacForEmail(email) ?? rememberedDevice['driverName']!;

      // Postavi driver session
      await AuthManager.setCurrentDriver(driverName);

      // 🔐 ZAHTEVAJ DOZVOLE I ZA REMEMBERED DEVICE (sa timeout)
      try {
        // ignore: use_build_context_synchronously
        await PermissionService.requestAllPermissionsOnFirstLaunch(context)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        // Ako permission zahtev pukne ili se zamrzne, nastavi dalje
      }

      if (!mounted) return;

      // Direktno na Daily Check-in ili Home Screen
      final hasCheckedIn = await SimplifiedDailyCheckInService.hasCheckedInToday(driverName)
          .timeout(const Duration(seconds: 5), onTimeout: () => false);

      if (!hasCheckedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (context) => DailyCheckInScreen(
              vozac: driverName,
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
      return;
    }

    // PROVERI FIREBASE AUTH STATE
    final firebaseUser = AuthManager.getCurrentUser();
    // 🔄 MAPIRANJE: email -> vozač ime umesto displayName
    final driverFromFirebase = firebaseUser?.email != null
        ? VozacBoja.getVozacForEmail(firebaseUser!.email) ?? firebaseUser.displayName
        : firebaseUser?.displayName;

    // 🔒 STRIKTNA PROVERA EMAIL VERIFIKACIJE
    if (AuthManager.isEmailAuthenticated() && !AuthManager.isEmailVerified()) {
      // Korisnik je ulogovan ali email nije verifikovan - odjavi ga
      await AuthManager.logout(context);
      return;
    }

    // Koristi novi AuthManager za session management
    final savedDriver = await AuthManager.getCurrentDriver();

    // Ako je neko ulogovan u Firebase ALI nema saved driver, sinhronizuj
    if (driverFromFirebase != null && (savedDriver == null || savedDriver != driverFromFirebase)) {
      await AuthManager.setCurrentDriver(driverFromFirebase);
    }

    // Koristi driver iz Firebase ako postoji, inače iz local storage
    final activeDriver = driverFromFirebase ?? savedDriver;

    if (activeDriver != null && activeDriver.isNotEmpty) {
      // Vozač je već logovan - PROVERI DAILY CHECK-IN
      
      // 🔐 ZAHTEVAJ DOZVOLE PRI PRVOM POKRETANJU (sa timeout za anti-freeze)
      try {
        // ignore: use_build_context_synchronously
        await PermissionService.requestAllPermissionsOnFirstLaunch(context)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        // Ako permission zahtev pukne ili se zamrzne, nastavi dalje
        // Korisnik može ručno odobriti dozvole kasnije
      }

      // 📅 PROVERI DA LI JE VOZAČ URADIO DAILY CHECK-IN
      final hasCheckedIn = await SimplifiedDailyCheckInService.hasCheckedInToday(activeDriver)
          .timeout(const Duration(seconds: 5), onTimeout: () => false);

      if (!mounted) return;

      if (!hasCheckedIn) {
        // POŠALJI NA DAILY CHECK-IN SCREEN
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (context) => DailyCheckInScreen(
              vozac: activeDriver,
              onCompleted: () {
                // Kada završi check-in, idi na HomeScreen
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
          MaterialPageRoute<void>(builder: (context) => const HomeScreen()),
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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
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
      if (_audioPlayer.playing) {
        await _audioPlayer.stop();
      }
    } catch (e) {
      // Swallow audio errors silently
    }
  }

  Future<void> _loginAsDriver(String driverName) async {
    // 🎵 PREKINI PESMU kada korisnik počne login
    await _stopAudio();

    // STRIKTNA VALIDACIJA VOZAČA
    if (!VozacBoja.isValidDriver(driverName)) {
      if (!mounted) return;
      _showErrorDialog(
        'NEVALJAN VOZAČ!',
        'Dozvoljen je samo login za: ${VozacBoja.validDrivers.join(", ")}',
      );
      return;
    }

    // 📱 PRVO PROVERI REMEMBERED DEVICE za ovog vozača
    final rememberedDevice = await AuthManager.getRememberedDevice();
    if (rememberedDevice != null) {
      final rememberedEmail = rememberedDevice['email']!;
      final rememberedName = rememberedDevice['driverName']!;

      // 🔄 FORSIRAJ REFRESH: Koristi VozacBoja mapiranje za ispravno ime
      final correctName = VozacBoja.getVozacForEmail(rememberedEmail) ?? rememberedName;

      if (correctName == driverName) {
        // Ovaj vozač je zapamćen na ovom uređaju - DIREKTNO AUTO-LOGIN
        await AuthManager.setCurrentDriver(correctName);

        if (!mounted) return;

        // Direktno na Daily Check-in ili Home Screen
        final hasCheckedIn = await SimplifiedDailyCheckInService.hasCheckedInToday(correctName);

        if (!hasCheckedIn) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (context) => DailyCheckInScreen(
                vozac: correctName,
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
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (context) => const HomeScreen(),
            ),
          );
        }
      }
    }

    // AKO NIJE REMEMBERED DEVICE - IDI NA EMAIL LOGIN PRVO
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const EmailLoginScreen(),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Theme.of(context).colorScheme.error.withOpacity(0.5),
              width: 2,
            ),
          ),
          title: Column(
            children: [
              Icon(Icons.error, color: Theme.of(context).colorScheme.error, size: 40),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'U redu',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: tripleBlueFashionGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16), // Reduced padding
            child: Column(
              children: [
                // Moderni welcome tekst
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.13),
                        width: 1.8,
                      ),
                    ),
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'DOBRODOŠLI',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3.5,
                              color: Colors.white,
                              shadows: [
                                // Glavni glow efekat - plavi
                                Shadow(
                                  color: const Color(0xFF12D8FA).withOpacity(0.8),
                                  blurRadius: 20,
                                ),
                                // Dodatni glow - svetliji plavi
                                Shadow(
                                  color: const Color(0xFF00E5FF).withOpacity(0.6),
                                  blurRadius: 15,
                                ),
                                // Treći glow - još svetliji
                                Shadow(
                                  color: Colors.cyan.withOpacity(0.4),
                                  blurRadius: 10,
                                ),
                                // Osnovna senka za dubinu
                                const Shadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Aplikacija za vozače',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12), // Further reduced from 16
                Expanded(
                  flex: 3, // Give more space to driver buttons
                  child: Center(
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...List.generate(_drivers.length, (index) {
                              final driver = _drivers[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0, // Increased slightly for better visibility
                                ),
                                child: _buildDriverButton(
                                  driver['name'] as String,
                                  driver['color'] as Color,
                                  driver['icon'] as IconData,
                                  index,
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Moderno dugme GAVRA 013 dole - compacted
                Container(
                  padding: const EdgeInsets.only(top: 8), // Reduced padding
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: GestureDetector(
                        onTap: () async {
                          try {
                            await _audioPlayer.setAsset('assets/kasno_je.mp3');
                            await _audioPlayer.setVolume(0.5); // 50% jačine
                            await _audioPlayer.play();
                          } catch (e) {
                            // Swallow audio errors silently in production
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20, // Reduced padding
                            vertical: 10, // Reduced padding
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.22),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.13),
                              width: 1.8,
                            ),
                          ),
                          child: Text(
                            'GAVRA 013',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: Colors.white,
                              shadows: [
                                // Glavni glow efekat - plavi
                                Shadow(
                                  color: const Color(0xFF12D8FA).withOpacity(0.8),
                                  blurRadius: 20,
                                ),
                                // Dodatni glow - svetliji plavi
                                Shadow(
                                  color: const Color(0xFF00E5FF).withOpacity(0.6),
                                  blurRadius: 15,
                                ),
                                // Treći glow - još svetliji
                                Shadow(
                                  color: Colors.cyan.withOpacity(0.4),
                                  blurRadius: 10,
                                ),
                                // Osnovna senka za dubinu
                                const Shadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8), // Reduced from 16
                // Footer
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        'Developed • Designed • Crafted with balls',
                        style: TextStyle(
                          fontSize: 13,
                          letterSpacing: 1.0,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: const Color(0xFF12D8FA).withOpacity(0.6),
                              blurRadius: 15,
                            ),
                            Shadow(
                              color: Colors.cyan.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'by Bojan Gavrilovic',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.0,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: const Color(0xFF00E5FF).withOpacity(0.5),
                              blurRadius: 12,
                            ),
                            Shadow(
                              color: Colors.cyan.withOpacity(0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '03.2025 - 11.2025',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: const Color(0xFF12D8FA).withOpacity(0.4),
                              blurRadius: 10,
                            ),
                            Shadow(
                              color: Colors.cyan.withOpacity(0.2),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8), // Reduced from 12
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverButton(
    String name,
    Color color,
    IconData icon,
    int index,
  ) {
    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        // Calculate delay-like effect based on index
        final delayFactor = (index * 0.1).clamp(0.0, 1.0);
        final adjustedValue = (_slideController.value - delayFactor).clamp(
          0.0,
          1.0,
        );
        final scale = 0.8 + (0.2 * adjustedValue);
        final opacity = adjustedValue;

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: GestureDetector(
              onTap: () => _loginAsDriver(name),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                constraints: const BoxConstraints(
                  minHeight: 55, // Minimum height
                  maxHeight: 65, // Maximum height with some flexibility
                ),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  vertical: 6, // Further reduced to prevent overflow
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.85),
                      Colors.white.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: color.withOpacity(0.7),
                    width: 2.0,
                  ),
                ),
                child: ClipRect(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(
                          3,
                        ), // Further reduced to prevent overflow
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.18),
                              color.withOpacity(0.25),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: 18,
                        ), // Further reduced to prevent overflow
                      ),
                      const SizedBox(
                        height: 1,
                      ), // Further reduced to prevent overflow
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13, // Further reduced to prevent overflow
                            fontWeight: FontWeight.bold,
                            color: color,
                            letterSpacing: 1.0, // Further reduced to prevent overflow
                            shadows: [
                              Shadow(
                                color: Colors.white.withOpacity(0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
