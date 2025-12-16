import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/auth_manager.dart';
import '../services/daily_checkin_service.dart';
import '../services/local_notification_service.dart';
import '../services/permission_service.dart';
import '../services/realtime_notification_service.dart';
import '../theme.dart';
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
  if (driverName == 'Ivan') {
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
  late Animation<double> _fadeAnimation;

  // Lista vozača za email sistem - koristi VozacBoja utility
  final List<Map<String, dynamic>> _drivers = [
    {
      'name': 'Bruda',
      'color': VozacBoja.get('Bruda'),
      'icon': Icons.local_taxi,
    },
    {
      'name': 'Bilevski',
      'color': VozacBoja.get('Bilevski'),
      'icon': Icons.directions_car,
    },
    {
      'name': 'Ivan',
      'color': const Color(0xFF8B4513), // braon
      'icon': Icons.directions_car,
    },
    {
      'name': 'Svetlana',
      'color': VozacBoja.get('Svetlana'),
      'icon': Icons.favorite,
    },
    {
      'name': 'Bojan',
      'color': VozacBoja.get('Bojan'),
      'icon': Icons.airport_shuttle,
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

    // PROVERI FIREBASE AUTH STATE
    final firebaseUser = AuthManager.getCurrentUser();
    // 🔄 MAPIRANJE: email -> vozač ime umesto displayName
    // Map only via email to a whitelisted driver; don't fall back to displayName
    final driverFromFirebase = firebaseUser?.email != null ? VozacBoja.getVozacForEmail(firebaseUser!.email) : null;

    // 🔒 STRIKTNA PROVERA EMAIL VERIFIKACIJE
    if (AuthManager.isEmailAuthenticated() && !AuthManager.isEmailVerified()) {
      // Korisnik je ulogovan ali email nije verifikovan - odjavi ga
      if (mounted) {
        await AuthManager.logout(context);
      }
      return;
    }

    // Koristi novi AuthManager za session management
    final savedDriver = await AuthManager.getCurrentDriver();

    // Ako je neko ulogovan u Firebase, koristi to
    if (driverFromFirebase != null && (savedDriver == null || savedDriver != driverFromFirebase)) {
      await AuthManager.setCurrentDriver(driverFromFirebase);
    }

    // Koristi driver iz Firebase ako postoji, inače iz local storage
    final activeDriver = driverFromFirebase ?? savedDriver;

    if (activeDriver != null && activeDriver.isNotEmpty) {
      // Vozač je već logovan - PROVERI DAILY CHECK-IN
      // 🔐 ZAHTEVAJ DOZVOLE PRI PRVOM POKRETANJU (auto-login)
      if (mounted) {
        await PermissionService.requestAllPermissionsOnFirstLaunch(context);
      }

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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: tripleBlueFashionGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16), // Reduced padding
            child: Column(
              children: [
                // 🎫 Mesečni putnici - NA SREDINI sa jednakim razmakom za O nama i Vozači
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 20),
                        // Moderni welcome tekst
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.22),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.13),
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
                                          color: const Color(0xFF12D8FA).withValues(alpha: 0.8),
                                          blurRadius: 20,
                                        ),
                                        // Dodatni glow - svetliji plavi
                                        Shadow(
                                          color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                                          blurRadius: 15,
                                        ),
                                        // Treći glow - još svetliji
                                        Shadow(
                                          color: Colors.cyan.withValues(alpha: 0.4),
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
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // 📖 "O nama" dugme
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ONamaScreen()),
                              );
                            },
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.55,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'O nama',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.5,
                                  shadows: [
                                    Shadow(
                                      color: const Color(0xFF12D8FA).withValues(alpha: 0.8),
                                      blurRadius: 15,
                                    ),
                                    Shadow(
                                      color: Colors.cyan.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // 🎫 Mesečni putnici
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
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 28,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.amber.withValues(alpha: 0.85),
                                    Colors.white.withValues(alpha: 0.08),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.7),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withValues(alpha: 0.35),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.card_membership,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Uloguj se',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // 🚗 "Vozači" dugme
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: GestureDetector(
                            onTap: () => _showDriverSelectionDialog(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'Vozači',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.5,
                                  shadows: [
                                    Shadow(
                                      color: const Color(0xFF12D8FA).withValues(alpha: 0.8),
                                      blurRadius: 15,
                                    ),
                                    Shadow(
                                      color: Colors.cyan.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
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
                            await _audioPlayer.setVolume(0.5);
                            await _audioPlayer.play(AssetSource('kasno_je.mp3'));
                            _isAudioPlaying = true;
                          } catch (_) {}
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20, // Reduced padding
                            vertical: 10, // Reduced padding
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.13),
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
                                  color: const Color(0xFF12D8FA).withValues(alpha: 0.8),
                                  blurRadius: 20,
                                ),
                                // Dodatni glow - svetliji plavi
                                Shadow(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                                  blurRadius: 15,
                                ),
                                // Treći glow - još svetliji
                                Shadow(
                                  color: Colors.cyan.withValues(alpha: 0.4),
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
                        'Designed • Developed • Crafted with balls',
                        style: TextStyle(
                          fontSize: 13,
                          letterSpacing: 1.0,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: const Color(0xFF12D8FA).withValues(alpha: 0.6),
                              blurRadius: 15,
                            ),
                            Shadow(
                              color: Colors.cyan.withValues(alpha: 0.3),
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
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                              blurRadius: 12,
                            ),
                            Shadow(
                              color: Colors.cyan.withValues(alpha: 0.3),
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
                              color: const Color(0xFF12D8FA).withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                            Shadow(
                              color: Colors.cyan.withValues(alpha: 0.2),
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
                ..._drivers.map((driver) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context); // Zatvori dijalog
                        _loginAsDriver(driver['name'] as String);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              (driver['color'] as Color).withValues(alpha: 0.8),
                              Colors.white.withValues(alpha: 0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (driver['color'] as Color).withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              driver['icon'] as IconData,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              driver['name'] as String,
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
