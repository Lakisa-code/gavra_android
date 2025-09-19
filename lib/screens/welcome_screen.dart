import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math';
import '../services/local_notification_service.dart';
import '../services/password_service.dart';
import '../services/daily_checkin_service.dart';
import '../utils/vozac_boja.dart'; // DODATO za validaciju vozača
import 'home_screen.dart';
import 'change_password_screen.dart';
import 'daily_checkin_screen.dart';
import '../main.dart' show globalThemeRefresher; // DODATO za tema refresh

// Uses centralized debug logger `dlog` from `lib/utils/logging.dart`.

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

  // 🎵 STATIC GLOBAL AUDIO PLAYER - za pesme u pozadini
  static AudioPlayer? _globalAudioPlayer;

  // 🎵 PUSTI SPECIJALNE PESME ZA VOZAČE - CELA PESMA U POZADINI
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
          // 💖 SVETLANINA SPECIJALNA PESMA - "Hiljson Mandela & Miach - Anđeo"
          assetPath = 'assets/svetlana.mp3';
          dlog(
              '💖 🎵 SVETLANA LOGIN: Puštam "Hiljson Mandela & Miach - Anđeo" kao dobrodošlicu - CELA PESMA! 🎵 💖');
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
          '🎵 ✅ Pesma pokrenuta u pozadini za $driverName - neće se prekinuti!');

      // Postaviti listener da se audio player očisti kad pesma završi
      _globalAudioPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          dlog('🎵 ✅ Pesma završena, čistim audio player...');
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
  ];

  @override
  void initState() {
    super.initState();

    _setupAnimations();
    // Inicijalizacija lokalnih notifikacija
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocalNotificationService.initialize(context);
      _checkAutoLogin(); // VRAĆEN _checkAutoLogin() - auto-login BEZ pesme
    });
  }

  // 🔄 AUTO-LOGIN BEZ PESME - Proveri da li je vozač već logovan
  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDriver = prefs.getString('current_driver');

    if (savedDriver != null && savedDriver.isNotEmpty) {
      // Vozač je već logovan - PROVERI DAILY CHECK-IN
      dlog(
          '🔄 AUTO-LOGIN: $savedDriver je već logovan - proveravam daily check-in');

      // 🎨 OSVEZI TEMU ZA VOZAČA
      if (globalThemeRefresher != null) {
        globalThemeRefresher!();
      }

      // 🌅 PROVERI DA LI JE VOZAČ URADIO DAILY CHECK-IN
      final today = DateTime.now();

      // 🚫 PRESKAČI VIKENDE - ne radi se subotom i nedeljom
      if (today.weekday == 6 || today.weekday == 7) {
        dlog(
            '🚫 Preskačem daily check-in za vikend (${today.weekday == 6 ? "Subota" : "Nedelja"}) - idem direktno na HomeScreen');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        return;
      }

      final hasCheckedIn =
          await DailyCheckInService.hasCheckedInToday(savedDriver);

      if (!mounted) return;

      if (!hasCheckedIn) {
        // POŠALJI NA DAILY CHECK-IN SCREEN
        dlog('🌅 DAILY CHECK-IN: $savedDriver mora da uradi check-in');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DailyCheckInScreen(
              vozac: savedDriver,
              onCompleted: () {
                // Kada završi check-in, idi na HomeScreen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
            ),
          ),
        );
      } else {
        // DIREKTNO NA HOME SCREEN
        dlog('✅ DAILY CHECK-IN: $savedDriver već uradio check-in danas');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
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
      driver['color'],
    );

    if (enteredPassword == null) {
      // Korisnik je otkazao
      return;
    }

    if (enteredPassword == correctPassword) {
      // Šifra je tačna, nastavi sa login-om
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_driver', driverName);

      // 🎨 OSVEZI TEMU ZA NOVOG VOZAČA
      if (globalThemeRefresher != null) {
        globalThemeRefresher!();
      }

      // 🎵 PUSTI PESMU SAMO PRI MANUELNOM LOGIN-U SA ŠIFROM (ne pri auto-login-u)
      await _WelcomeScreenState._playDriverWelcomeSong(driverName);

      // 🌅 PROVERI DAILY CHECK-IN I NAKON MANUELNOG LOGIN-A
      final today = DateTime.now();

      // 🚫 PRESKAČI VIKENDE - ne radi se subotom i nedeljom
      if (today.weekday == 6 || today.weekday == 7) {
        dlog(
            '🚫 Preskačem daily check-in za vikend (${today.weekday == 6 ? "Subota" : "Nedelja"}) - idem direktno na HomeScreen');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        return;
      }

      final hasCheckedIn =
          await DailyCheckInService.hasCheckedInToday(driverName);

      if (!mounted) return;

      if (!hasCheckedIn) {
        // POŠALJI NA DAILY CHECK-IN SCREEN
        dlog('🌅 MANUAL LOGIN: $driverName mora da uradi check-in');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DailyCheckInScreen(
              vozac: driverName,
              onCompleted: () {
                // Kada završi check-in, idi na HomeScreen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
            ),
          ),
        );
      } else {
        // DIREKTNO NA HOME SCREEN
        dlog('✅ MANUAL LOGIN: $driverName već uradio check-in danas');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      // Pogrešna šifra
      if (!mounted) return;
      _showErrorDialog('Pogrešna šifra!', 'Molimo pokušajte ponovo.');
    }
  }

  Future<String?> _showPasswordDialog(
    String driverName,
    Color driverColor,
  ) async {
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
          content: Column(
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
                  MaterialPageRoute(
                    builder: (context) =>
                        ChangePasswordScreen(driverName: driverName),
                  ),
                );
              },
              child: const Text('Promeni šifru',
                  style: TextStyle(color: Colors.orange)),
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

  void _showErrorDialog(String title, String message) {
    showDialog(
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

  @override
  Widget build(BuildContext context) {
    // ...existing code...
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
            padding: const EdgeInsets.all(24),
            child: Column(
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
                const SizedBox(height: 24),
                Expanded(
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
                                  vertical: 8.0,
                                ),
                                child: _buildDriverButton(
                                  driver['name'],
                                  driver['color'],
                                  driver['icon'],
                                  index,
                                ),
                              );
                            }),
                            // Svetlana S dugme
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 20.0),
                              child: _buildSvetlanaButton(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Moderno dugme GAVRA 013 dole
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      try {
                        await _audioPlayer.setAsset('assets/gavra.mp3');
                        await _audioPlayer.play();
                      } catch (e) {
                        if (kDebugMode) {}
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
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
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'GAVRA 013',
                            style: TextStyle(
                              fontSize: 28,
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
                const SizedBox(height: 28),
                // Footer
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    '05. 07. 2025  •  Made by Bojan Gavrilovic',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
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
                width: double.infinity,
                // height: 80, // uklonjeno zbog overflowa
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 0,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
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
                      child: name == 'Svetlana'
                          ? Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Center(
                                child: Text(
                                  'S',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'serif',
                                  ),
                                ),
                              ),
                            )
                          : Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                          letterSpacing: 1.5,
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
        );
      },
    );
  }

  Widget _buildSvetlanaButton() {
    return GestureDetector(
      onTap: () => _showSvetlanaLoginDialog(),
      child: SizedBox(
        width: 100,
        height: 100,
        child: CustomPaint(
          painter: SvetlanaDiamondPainter(),
          child: Center(
            child: SizedBox(
              width: 65,
              height: 65,
              child: CustomPaint(
                painter: SvetlanaSPainter(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSvetlanaLoginDialog() async {
    // Dohvati šifru iz PasswordService-a za Svetlanu
    final correctPassword = await PasswordService.getPassword('Svetlana');

    // Prikaži dialog za unos šifre
    final enteredPassword = await _showPasswordDialog(
      'Svetlana',
      const Color(0xFFF8BBD9), // Pastel pink boja
    );

    if (enteredPassword == null) {
      // Korisnik je otkazao
      return;
    }

    if (enteredPassword == correctPassword) {
      // Šifra je tačna, nastavi sa login-om
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_driver', 'Svetlana');

      // 🎨 OSVEZI TEMU ZA SVETLANU
      if (globalThemeRefresher != null) {
        globalThemeRefresher!();
      }

      // 🎵 PUSTI SVETLANINU PESMU SAMO PRI MANUELNOM LOGIN-U SA ŠIFROM (ne pri auto-login-u)
      await _WelcomeScreenState._playDriverWelcomeSong('Svetlana');

      // 🌅 PROVERI DAILY CHECK-IN I ZA SVETLANU
      final today = DateTime.now();

      // 🚫 PRESKAČI VIKENDE - ne radi se subotom i nedeljom
      if (today.weekday == 6 || today.weekday == 7) {
        dlog(
            '🚫 Preskačem daily check-in za vikend (${today.weekday == 6 ? "Subota" : "Nedelja"}) - idem direktno na HomeScreen');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        return;
      }

      final hasCheckedIn =
          await DailyCheckInService.hasCheckedInToday('Svetlana');

      if (!mounted) return;

      if (!hasCheckedIn) {
        // POŠALJI NA DAILY CHECK-IN SCREEN
        dlog('🌅 SVETLANA LOGIN: mora da uradi check-in');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DailyCheckInScreen(
              vozac: 'Svetlana',
              onCompleted: () {
                // Kada završi check-in, idi na HomeScreen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
            ),
          ),
        );
      } else {
        // DIREKTNO NA HOME SCREEN
        dlog('✅ SVETLANA LOGIN: već uradila check-in danas');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      // Pogrešna šifra
      if (!mounted) return;
      _showErrorDialog('Pogrešna šifra!', 'Molimo pokušajte ponovo.');
    }
  }
}

// 💖 SVETLANA DIAMOND PAINTER - Pink seksi dijamant sa belim zvezdicama
class SvetlanaDiamondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final width = size.width;
    final height = size.height;

    // Dijamantski put
    final path = Path()
      ..moveTo(center.dx, height * 0.1) // Vrh
      ..lineTo(width * 0.85, center.dy) // Desno
      ..lineTo(center.dx, height * 0.9) // Dno
      ..lineTo(width * 0.15, center.dy) // Levo
      ..close();

    // Živa pink gradient za bolju vidljivost
    const gradient = LinearGradient(
      colors: [
        Color(0xFFFF1493), // Deep Pink (živa)
        Color(0xFFFF69B4), // Hot Pink
        Color(0xFFFF1493), // Deep Pink (živa)
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    // Outer shadow
    final shadowPaint = Paint()
      ..color = const Color(0xFFDC143C).withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.save();
    canvas.translate(3, 6);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Glavni dijamant
    canvas.drawPath(path, paint);

    // Unutrašnji okvir (kao na slici)
    final innerPath = Path()
      ..moveTo(center.dx, height * 0.17)
      ..lineTo(width * 0.78, center.dy)
      ..lineTo(center.dx, height * 0.83)
      ..lineTo(width * 0.22, center.dy)
      ..close();

    final innerPaint = Paint()
      ..color = const Color(0xFFDC143C) // Crimson border za kontrast
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawPath(innerPath, innerPaint);

    // Spoljašnji border
    final borderPaint = Paint()
      ..color = const Color(0xFFDC143C) // Crimson border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawPath(path, borderPaint);

    // Bele zvezdice kao na slici ✨
    _drawStars(canvas, size);
  }

  void _drawStars(Canvas canvas, Size size) {
    final starPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    // Pozicije zvezdi kao na slici
    final starPositions = [
      Offset(size.width * 0.3, size.height * 0.25), // Gore levo
      Offset(size.width * 0.7, size.height * 0.25), // Gore desno
      Offset(size.width * 0.25, size.height * 0.45), // Levo
      Offset(size.width * 0.75, size.height * 0.45), // Desno
      Offset(size.width * 0.35, size.height * 0.65), // Dole levo
      Offset(size.width * 0.65, size.height * 0.65), // Dole desno
      Offset(size.width * 0.5, size.height * 0.75), // Dole centar
    ];

    for (final pos in starPositions) {
      _drawStar(canvas, pos, 4, starPaint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    const angleStep = (3.14159 * 2) / 4; // 4-pointed star

    for (int i = 0; i < 8; i++) {
      final angle = i * angleStep / 2;
      final r = i.isEven ? radius : radius * 0.4;
      final x = center.dx + r * cos(angle - 3.14159 / 2);
      final y = center.dy + r * sin(angle - 3.14159 / 2);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 💖 SVETLANA S PAINTER - Pastel pink stilizovano S
class SvetlanaSPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // S path - stilizovan kao na slici (jednostavniji)
    final sPath = Path();

    // Gornji deo S-a (kao na slici)
    sPath.moveTo(width * 0.7, height * 0.25);
    sPath.quadraticBezierTo(
        width * 0.5, height * 0.15, width * 0.3, height * 0.25);
    sPath.quadraticBezierTo(
        width * 0.2, height * 0.3, width * 0.25, height * 0.4);
    sPath.lineTo(width * 0.45, height * 0.45);
    sPath.quadraticBezierTo(
        width * 0.55, height * 0.5, width * 0.5, height * 0.55);
    sPath.lineTo(width * 0.3, height * 0.6);
    sPath.quadraticBezierTo(
        width * 0.25, height * 0.65, width * 0.3, height * 0.75);
    sPath.quadraticBezierTo(
        width * 0.5, height * 0.85, width * 0.7, height * 0.75);
    sPath.quadraticBezierTo(
        width * 0.8, height * 0.7, width * 0.75, height * 0.6);
    sPath.lineTo(width * 0.55, height * 0.55);
    sPath.quadraticBezierTo(
        width * 0.45, height * 0.5, width * 0.5, height * 0.45);
    sPath.lineTo(width * 0.7, height * 0.4);
    sPath.quadraticBezierTo(
        width * 0.75, height * 0.35, width * 0.7, height * 0.25);

    // Pastel pink gradient za S (kao dijamant)
    const sGradient = LinearGradient(
      colors: [
        Color(0xFFD8587A), // Darker pink
        Color(0xFFF8BBD9), // Pastel pink
        Color(0xFFFFB6C1), // Light pink
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    final sPaint = Paint()
      ..shader = sGradient.createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    // Shadow za S
    final sShadowPaint = Paint()
      ..color = const Color(0xFFD8587A).withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.save();
    canvas.translate(1, 2);
    canvas.drawPath(sPath, sShadowPaint);
    canvas.restore();

    // Nacrtaj S
    canvas.drawPath(sPath, sPaint);

    // S border (darker pink)
    final sBorderPaint = Paint()
      ..color = const Color(0xFFD8587A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(sPath, sBorderPaint);

    // Highlight na S (beli)
    final sHighlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final highlightPath = Path()
      ..moveTo(width * 0.35, height * 0.3)
      ..quadraticBezierTo(
          width * 0.4, height * 0.25, width * 0.55, height * 0.35);

    canvas.drawPath(highlightPath, sHighlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
