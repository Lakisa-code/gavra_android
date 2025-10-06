import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import '../services/local_notification_service.dart';
import '../services/realtime_notification_service.dart';
import '../services/password_service.dart';
import '../services/daily_checkin_service.dart';
import '../services/permission_service.dart';
import '../utils/vozac_boja.dart';
import 'home_screen.dart';
import 'change_password_screen.dart';
import 'daily_checkin_screen.dart';
import 'email_login_screen.dart';
import '../main.dart' show globalThemeRefresher;

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // STATIC GLOBAL AUDIO PLAYER - za pesme u pozadini
  static AudioPlayer? _globalAudioPlayer;

  // PUSTI SPECIJALNE PESME ZA VOZAČE - CELA PESMA U POZADINI
  static Future<void> _playDriverWelcomeSong(String driverName) async {
    try {
      // Stvori globalni audio player ako ne postoji
      _globalAudioPlayer ??= AudioPlayer();

      // Zaustavi trenutnu pesmu
      await _globalAudioPlayer!.stop();

      String assetPath;
      double volume = 0.8; // Uvek 0.8 za sve pesme

      switch (driverName.toLowerCase()) {
        case 'svetlana':
          // 🎺 SVETLANINA SPECIJALNA PESMA - "Hiljson Mandela & Miach - Anđeo"
          assetPath = 'assets/svetlana.mp3';
          dlog(
              '🎺 🎵 SVETLANA LOGIN: Puštam "Hiljson Mandela & Miach - Anđeo" kao dobrodošlicu - CELA PESMA! 🎵 🎺');
          break;

        case 'bruda':
          // 🎵 BRUDINA SPECIJALNA PESMA
          assetPath = 'assets/bruda.mp3';
          dlog('🎵 BRUDA LOGIN: Puštam Brudinu specijalnu pesmu - CELA PESMA!');
          break;

        case 'bilevski':
          // 🎵 BILEVSKIJEVA SPECIJALNA PESMA
          assetPath = 'assets/bilevski.mp3';
          dlog(
              '🎵 BILEVSKI LOGIN: Puštam Bilevskijevu specijalnu pesmu - CELA PESMA!');
          break;

        case 'bojan':
          // 🎵 BOJANOVA SPECIJALNA PESMA
          assetPath = 'assets/gavra.mp3';
          dlog('🎵 BOJAN LOGIN: Puštam Gavrinu specijalnu pesmu - CELA PESMA!');
          break;

        default:
          // 🎵 Default pesma za ostale vozače
          assetPath = 'assets/gavra.mp3';
          dlog('🎵 Puštam default welcome song za $driverName - CELA PESMA!');
          break;
      }

      // Postavi i pokreni pesmu - CELA PESMA
      await _globalAudioPlayer!.setAsset(assetPath);
      await _globalAudioPlayer!.setVolume(volume);
      await _globalAudioPlayer!.setLoopMode(LoopMode.off); // Bez ponavljanja
      await _globalAudioPlayer!.play();

      dlog(
          '🎵 ✓ Pesma pokrenuta u pozadini za $driverName - neće se prekinuti!');

      // Postaviti listener da se audio player očisti kad pesma završi
      _globalAudioPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          dlog('🎵 ✓ Pesma završena, čistim audio player...');
          _globalAudioPlayer?.dispose();
          _globalAudioPlayer = null;
        }
      });
    } catch (e) {
      dlog('❌ Greška pri puštanju pesme: $e');
    }
  }

  final List<Map<String, dynamic>> _drivers = [
    {
      'name': 'Bilevski',
      'password': '2222',
      'color': const Color(0xFFFF9800), // narandžasta
      'icon': Icons.directions_car,
    },
    {
      'name': 'Bruda',
      'password': '1111',
      'color': const Color(0xFF7C4DFF), // ljubičasta
      'icon': Icons.local_taxi,
    },
    {
      'name': 'Bojan',
      'password': '1919',
      'color': const Color(0xFF00E5FF), // svetla cyan plava
      'icon': Icons.airport_shuttle,
    },
    {
      'name': 'Svetlana',
      'password': '0000',
      'color': const Color(0xFFFF1493), // deep pink
      'icon': Icons.favorite,
    },
  ];

  @override
  void initState() {
    super.initState();

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
          final result = await Permission.notification.request();
          dlog(
              '🔔 Android notification permission result: ${result.isGranted}');
        } else {
          dlog('🔔 Android notification permission already granted');
        }
      }

      // Also request Firebase/iOS style permissions via RealtimeNotificationService
      try {
        final granted =
            await RealtimeNotificationService.requestNotificationPermissions();
        dlog('🔔 RealtimeNotificationService permission result: $granted');
      } catch (e) {
        dlog(
            '⚠️💥 Error requesting RealtimeNotificationService permissions: $e');
      }
    } catch (e) {
      dlog('⚠️💥 Error during notification permission flow: $e');
    }
  }

  // 🔄 AUTO-LOGIN BEZ PESME - Proveri da li je vozač već logovan
  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDriver = prefs.getString('current_driver');

    if (savedDriver != null && savedDriver.isNotEmpty) {
      // Vozač je već logovan - PROVERI DAILY CHECK-IN
      dlog(
          '🔄 AUTO-LOGIN: $savedDriver je već logovan - proveravam daily check-in');

      // 🎨 OSVEŽI TEMU ZA VOZAČA
      if (globalThemeRefresher != null) {
        globalThemeRefresher!();
      }

      // 🔐 ZAHTEVAJ DOZVOLE PRI PRVOM POKRETANJU (auto-login)
      // ignore: use_build_context_synchronously
      await PermissionService.requestAllPermissionsOnFirstLaunch(context);

      // 📅 PROVERI DA LI JE VOZAČ URADIO DAILY CHECK-IN
      final today = DateTime.now();

      // 🏖️ PRESKOČI VIKENDE - ne radi se subotom i nedeljom
      if (today.weekday == 6 || today.weekday == 7) {
        dlog(
            '🏖️ Preskoćem daily check-in za vikend (${today.weekday == 6 ? "Subota" : "Nedelja"}) - idem direktno na HomeScreen');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (context) => const HomeScreen()),
        );
        return;
      }

      final hasCheckedIn =
          await DailyCheckInService.hasCheckedInToday(savedDriver);

      if (!mounted) return;

      if (!hasCheckedIn) {
        // POŠALJI NA DAILY CHECK-IN SCREEN
        dlog('📅 DAILY CHECK-IN: $savedDriver mora da uradi check-in');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (context) => DailyCheckInScreen(
              vozac: savedDriver,
              onCompleted: () {
                // Kada završi check-in, idi na HomeScreen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(
                      builder: (context) => const HomeScreen()),
                );
              },
            ),
          ),
        );
      } else {
        // DIREKTNO NA HOME SCREEN
        dlog('✓ DAILY CHECK-IN: $savedDriver već uradio check-in danas');
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

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });
  }

  @override
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _audioPlayer.dispose(); // Dodano za cleanup audio player-a
    super.dispose();
  }

  Future<void> _loginAsDriver(String driverName) async {
    // STRIKTNA VALIDACIJA VOZAČA
    if (!VozacBoja.isValidDriver(driverName)) {
      if (!mounted) return;
      _showErrorDialog('NEVALJAN VOZAČ!',
          'Dozvoljen je samo login za: ${VozacBoja.validDrivers.join(", ")}');
      return;
    }

    // Dohvati šifru iz PasswordService-a
    final correctPassword = await PasswordService.getPassword(driverName);

    // Pronađi vozača za boju
    final driver = _drivers.firstWhere((d) => d['name'] == driverName);

    // Prikaži dialog za unos šifre
    final enteredPassword = await _showPasswordDialog(
      driverName,
      driver['color'] as Color,
    );

    if (enteredPassword == null) {
      // Korisnik je otkazao
      return;
    }

    if (enteredPassword == correctPassword) {
      // Šifra je tačna, nastavi sa login-om
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_driver', driverName);

      // 🔐 ZAHTEVAJ DOZVOLE PRI PRVOM POKRETANJU
      // ignore: use_build_context_synchronously
      await PermissionService.requestAllPermissionsOnFirstLaunch(context);

      // 🎨 OSVEŽI TEMU ZA NOVOG VOZAČA
      if (globalThemeRefresher != null) {
        globalThemeRefresher!();
      }

      // 🎵 PUSTI PESMU SAMO PRI MANUELNOM LOGIN-U SA ŠIFROM (ne pri auto-login-u)
      await _WelcomeScreenState._playDriverWelcomeSong(driverName);

      // 📅 PROVERI DAILY CHECK-IN I NAKON MANUELNOG LOGIN-A
      final today = DateTime.now();

      // 🏖️ PRESKOČI VIKENDE - ne radi se subotom i nedeljom
      if (today.weekday == 6 || today.weekday == 7) {
        dlog(
            '🏖️ Preskoćem daily check-in za vikend (${today.weekday == 6 ? "Subota" : "Nedelja"}) - idem direktno na HomeScreen');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (context) => const HomeScreen()),
        );
        return;
      }

      final hasCheckedIn =
          await DailyCheckInService.hasCheckedInToday(driverName);

      if (!mounted) return;

      if (!hasCheckedIn) {
        // POŠALJI NA DAILY CHECK-IN SCREEN
        dlog('📅 MANUAL LOGIN: $driverName mora da uradi check-in');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (context) => DailyCheckInScreen(
              vozac: driverName,
              onCompleted: () {
                // Kada završi check-in, idi na HomeScreen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(
                      builder: (context) => const HomeScreen()),
                );
              },
            ),
          ),
        );
      } else {
        // DIREKTNO NA HOME SCREEN
        dlog('✓ MANUAL LOGIN: $driverName već uradio check-in danas');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      // Pogreška šifra
      if (!mounted) return;
      _showErrorDialog('Pogreška šifra!', 'Molimo pokušajte ponovo.');
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.red.withOpacity(0.5),
              width: 2,
            ),
          ),
          title: Column(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
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
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
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

  Future<String?> _showPasswordDialog(
      String driverName, Color driverColor) async {
    final TextEditingController passwordController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: driverColor.withOpacity(0.5),
              width: 2,
            ),
          ),
          title: Column(
            children: [
              Icon(Icons.lock, color: driverColor, size: 40),
              const SizedBox(height: 12),
              Text(
                'Šifra za $driverName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Unesite šifru',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: driverColor.withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: driverColor, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                    ),
                    onSubmitted: (value) {
                      Navigator.of(context).pop(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text('Otkaži', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(null); // Zatvori password dialog
                // Otvori change password screen
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        ChangePasswordScreen(driverName: driverName),
                  ),
                );
              },
              child: Text('Promeni šifru',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(null); // Zatvori password dialog
                // Otvori email login screen
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const EmailLoginScreen(),
                  ),
                );
              },
              child: const Text('Email Prijava',
                  style: TextStyle(color: Colors.green)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: driverColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(passwordController.text);
              },
              child: const Text(
                'Uloguj se',
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
          gradient: LinearGradient(
            colors: [Color(0xFF232526), Color(0xFF414345)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16), // Reduced padding
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.start, // Changed from spaceBetween
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
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
                        ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              colors: [Color(0xFF00E5FF), Color(0xFFB388FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds);
                          },
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'DOBRODOŠLI',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3.5,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Colors.black26, blurRadius: 12),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ...List.generate(_drivers.length, (index) {
                              final driver = _drivers[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical:
                                      4.0, // Increased slightly for better visibility
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
                            await _audioPlayer.setAsset('assets/gavra.mp3');
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
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF2979FF,
                                ).withOpacity(0.22),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.directions_bus,
                                color: Colors.white.withOpacity(0.92),
                                size: 24, // Reduced size
                              ),
                              const SizedBox(width: 8), // Reduced spacing
                              Text(
                                'GAVRA 013',
                                style: TextStyle(
                                  fontSize: 24, // Reduced size
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(
                                      color: const Color(
                                        0xFF00E5FF,
                                      ).withOpacity(0.7),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
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
                  child: Text(
                    '05. 07. 2025  •  Made by Bojan Gavrilovic',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 12, // Reduced from 14
                      letterSpacing: 1.0, // Reduced from 1.2
                    ),
                    textAlign: TextAlign.center,
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(
                            3), // Further reduced to prevent overflow
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
                        child: Icon(icon,
                            color: color,
                            size: 18), // Further reduced to prevent overflow
                      ),
                      const SizedBox(
                          height: 1), // Further reduced to prevent overflow
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 13, // Further reduced to prevent overflow
                            fontWeight: FontWeight.bold,
                            color: color,
                            letterSpacing:
                                1.0, // Further reduced to prevent overflow
                            shadows: [
                              Shadow(
                                color: Colors.white.withOpacity(0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          textAlign: TextAlign.center,
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
