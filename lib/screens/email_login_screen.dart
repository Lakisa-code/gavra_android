import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show globalThemeRefresher;
import '../services/daily_checkin_service.dart';
import '../services/email_auth_service.dart';
import '../services/permission_service.dart';
import '../utils/logging.dart';
import 'daily_checkin_screen.dart';
import 'email_registration_screen.dart';
import 'home_screen.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({Key? key}) : super(key: key);

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

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
            '🎺 🎵 SVETLANA EMAIL LOGIN: Puštam "Hiljson Mandela & Miach - Anđeo" kao dobrodošlicu - CELA PESMA! 🎵 🎺',
          );
          break;

        case 'bruda':
          // 🎵 BRUDINA SPECIJALNA PESMA
          assetPath = 'assets/bruda.mp3';
          dlog(
            '🎵 BRUDA EMAIL LOGIN: Puštam Brudinu specijalnu pesmu - CELA PESMA!',
          );
          break;

        case 'bilevski':
          // 🎵 BILEVSKIJEVA SPECIJALNA PESMA
          assetPath = 'assets/bilevski.mp3';
          dlog(
            '🎵 BILEVSKI EMAIL LOGIN: Puštam Bilevskijevu specijalnu pesmu - CELA PESMA!',
          );
          break;

        case 'bojan':
          // 🎵 BOJANOVA SPECIJALNA PESMA
          assetPath = 'assets/gavra.mp3';
          dlog(
            '🎵 BOJAN EMAIL LOGIN: Puštam Gavrinu specijalnu pesmu - CELA PESMA!',
          );
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
        '🎵 ✓ EMAIL LOGIN: Pesma pokrenuta u pozadini za $driverName - neće se prekinuti!',
      );

      // Postaviti listener da se audio player očisti kad pesma završi
      _globalAudioPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          dlog('🎵 ✓ EMAIL LOGIN: Pesma završena, čistim audio player...');
          _globalAudioPlayer?.dispose();
          _globalAudioPlayer = null;
        }
      });
    } catch (e) {
      dlog('❌ EMAIL LOGIN: Greška pri puštanju pesme: $e');
    }
  }

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
              Theme.of(context).colorScheme.tertiary,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Login Form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildLoginForm(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
            Theme.of(context).colorScheme.secondary.withOpacity(0.6),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.email_rounded,
            size: 60,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          const SizedBox(height: 16),
          Text(
            'Email Prijava',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Prijavite se sa email adresom',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),

          // Email Field
          _buildEmailField(),

          const SizedBox(height: 24),

          // Password Field
          _buildPasswordField(),

          const SizedBox(height: 32),

          // Login Button
          _buildLoginButton(),

          const SizedBox(height: 24),

          // Forgot Password
          _buildForgotPasswordButton(),

          const SizedBox(height: 32),

          // Register Link
          _buildRegisterLink(),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: 'Email Adresa',
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
        hintText: 'vas.email@primjer.com',
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
        prefixIcon: Icon(Icons.email, color: Theme.of(context).colorScheme.primary),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Unesite email adresu';
        }
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
          return 'Unesite valjan email format';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: 'Šifra',
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
        hintText: 'Unesite šifru',
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
        prefixIcon: Icon(Icons.lock, color: Theme.of(context).colorScheme.primary),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Unesite šifru';
        }
        if (value.length < 6) {
          return 'Šifra mora imati najmanje 6 karaktera';
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
      ),
      child: _isLoading
          ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
              ),
            )
          : const Text(
              'Prijavi se',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return TextButton(
      onPressed: _handleForgotPassword,
      child: Text(
        'Zaboravili ste šifru?',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Nemate nalog? ',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontSize: 16,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const EmailRegistrationScreen(),
              ),
            );
          },
          child: Text(
            'Registrujte se',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      dlog('🔐 Pokušavam prijavu sa email-om: $email');

      final driverName = await EmailAuthService.signInWithEmail(email, password);

      if (driverName != null) {
        dlog('✅ Uspješna prijava vozača: $driverName');

        // 💾 Sačuvaj vozača u SharedPreferences za auto-login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_driver', driverName);
        dlog('💾 Vozač $driverName sačuvan u SharedPreferences');

        // 🔐 ZAHTEVAJ DOZVOLE PRI PRVOM POKRETANJU
        // ignore: use_build_context_synchronously
        await PermissionService.requestAllPermissionsOnFirstLaunch(context);

        // 🎨 Osveži temu za vozača
        if (globalThemeRefresher != null) {
          globalThemeRefresher!();
          dlog('🎨 Tema osvežena za vozača $driverName');
        }

        // 🎵 PUSTI PESMU NAKON EMAIL LOGIN-A
        await _EmailLoginScreenState._playDriverWelcomeSong(driverName);

        // Provjeri daily check-in
        final needsCheckIn = !await DailyCheckInService.hasCheckedInToday(driverName);

        if (needsCheckIn) {
          // Idi na daily check-in
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute<void>(
                builder: (context) => DailyCheckInScreen(
                  vozac: driverName,
                  onCompleted: () {
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => const HomeScreen(),
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          }
        } else {
          // Idi direktno na home screen
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const HomeScreen(),
              ),
            );
          }
        }
      } else {
        _showErrorDialog(
          'Neuspješna prijava',
          'Provjerite email i šifru ili potvrdite email adresu.',
        );
      }
    } catch (e) {
      dlog('❌ Greška pri prijavi: $e');
      _showErrorDialog(
        'Greška',
        'Došlo je do greške pri prijavi. Pokušajte ponovo.',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !EmailAuthService.isValidEmailFormat(email)) {
      _showErrorDialog(
        'Nevažeći email',
        'Unesite validnu email adresu da biste resetovali šifru.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await EmailAuthService.resetPasswordViaEmail(email);

      if (success) {
        _showSuccessDialog(
          'Email poslan',
          'Provjerite email za link za reset šifre.',
        );
      } else {
        _showErrorDialog('Greška', 'Nije moguće poslati email za reset šifre.');
      }
    } catch (e) {
      dlog('❌ Greška pri reset šifre: $e');
      _showErrorDialog('Greška', 'Došlo je do greške. Pokušajte ponovo.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 2,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 2,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}



