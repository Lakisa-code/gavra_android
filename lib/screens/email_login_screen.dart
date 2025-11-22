import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/auth_manager.dart';
import '../services/firebase_auth_service.dart';
import '../services/permission_service.dart';
import '../services/simplified_daily_checkin.dart';
import '../theme.dart'; // 🎨 Import za prelepe gradijente
import '../utils/vozac_boja.dart'; // 🎨 Import za boje vozača
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
  bool _rememberDevice = true;

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
          break;

        case 'bruda':
          // 🎵 BRUDINA SPECIJALNA PESMA
          assetPath = 'assets/bruda.mp3';
          break;

        case 'bilevski':
          // 🎵 BILEVSKIJEVA SPECIJALNA PESMA
          assetPath = 'assets/bilevski.mp3';
          break;

        case 'bojan':
          // 🎵 BOJANOVA SPECIJALNA PESMA
          assetPath = 'assets/gavra.mp3';
          break;

        default:
          // 🎵 Default pesma za ostale vozače
          assetPath = 'assets/gavra.mp3';
          break;
      }

      // Postavi i pokreni pesmu - CELA PESMA
      await _globalAudioPlayer!.setAsset(assetPath);
      await _globalAudioPlayer!.setVolume(volume);
      await _globalAudioPlayer!.setLoopMode(LoopMode.off); // Bez ponavljanja
      await _globalAudioPlayer!.play();
// Postaviti listener da se audio player očisti kad pesma završi
      _globalAudioPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _globalAudioPlayer?.dispose();
          _globalAudioPlayer = null;
        }
      });
    } catch (e) {}
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
    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
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
            ),
          ),
          title: const Text(
            'Prijava',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
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
          centerTitle: true,
        ),
        body: SafeArea(
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
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
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
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
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

          // Remember device checkbox
          CheckboxListTile(
            value: _rememberDevice,
            onChanged: (v) {
              if (mounted) setState(() => _rememberDevice = v ?? false);
            },
            title: const Text('Zapamti uređaj'),
            controlAffinity: ListTileControlAffinity.leading,
          ),

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
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        ),
        hintText: 'vas.email@primjer.com',
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        prefixIcon: Icon(Icons.email, color: Theme.of(context).colorScheme.primary),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
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
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        ),
        hintText: 'Unesite šifru',
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        prefixIcon: Icon(Icons.lock, color: Theme.of(context).colorScheme.primary),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () {
            if (mounted)
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
          },
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
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
        shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
      ),
      child: _isLoading
          ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.onPrimary,
                ),
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
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
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
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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

    if (mounted) setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Koristi AuthManager umesto direktno EmailAuthService
      final result = await AuthManager.signInWithEmail(email, password, remember: _rememberDevice);

      if (result.isSuccess) {
        // Dobij ime vozača iz trenutne auth session
        final user = AuthManager.getCurrentUser();
        final email = user?.email;
        final driverName = VozacBoja.getVozacForEmail(email);
        if (driverName == null || !VozacBoja.isValidDriver(driverName)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Niste ovlašćeni da se prijavite. Kontaktirajte admina.'),
                backgroundColor: Colors.orange,
              ),
            );
            setState(() => _isLoading = false);
          }
          return;
        }

        // 💾 SAČUVAJ PRAVO IME VOZAČA (ne email!)
        await AuthManager.setCurrentDriver(driverName);

        // 🔐 ZAHTEVAJ DOZVOLE PRI PRVOM POKRETANJU
        // ignore: use_build_context_synchronously
        await PermissionService.requestAllPermissionsOnFirstLaunch(context);

        // 🎨 Theme refresh removed in simple version

        // 🎵 PUSTI PESMU NAKON EMAIL LOGIN-A
        await _EmailLoginScreenState._playDriverWelcomeSong(driverName);

        // Provjeri daily check-in
        final needsCheckIn = !await SimplifiedDailyCheckInService.hasCheckedInToday(driverName);

        if (needsCheckIn) {
          // Navigate to DailyCheckInScreen
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
          result.message,
        );
      }
    } catch (e) {
      _showErrorDialog(
        'Greška',
        'Došlo je do greške pri prijavi. Pokušajte ponovo.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !FirebaseAuthService.isValidEmailFormat(email)) {
      _showErrorDialog(
        'Nevažeći email',
        'Unesite validnu email adresu da biste resetovali šifru.',
      );
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final success = await FirebaseAuthService.resetPasswordViaEmail(email);

      if (success) {
        _showSuccessDialog(
          'Email poslan',
          'Provjerite email za link za reset šifre.',
        );
      } else {
        _showErrorDialog('Greška', 'Nije moguće poslati email za reset šifre.');
      }
    } catch (e) {
      _showErrorDialog('Greška', 'Došlo je do greške. Pokušajte ponovo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
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
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
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
