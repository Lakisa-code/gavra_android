import 'package:flutter/material.dart';

import '../services/auth_manager.dart';
import '../theme.dart';
import '../utils/responsive.dart';
import '../utils/vozac_boja.dart';

class EmailRegistrationScreen extends StatefulWidget {
  const EmailRegistrationScreen({
    Key? key,
    this.preselectedDriverName,
  }) : super(key: key);
  final String? preselectedDriverName;

  @override
  State<EmailRegistrationScreen> createState() => _EmailRegistrationScreenState();
}

class _EmailRegistrationScreenState extends State<EmailRegistrationScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedDriver;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberDevice = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Postavi preselected driver ako je proslećen
    if (widget.preselectedDriverName != null) {
      _selectedDriver = widget.preselectedDriverName;
    }

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
    _confirmPasswordController.dispose();
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
          title: Text(
            'Registracija',
            style: TextStyle(
              color: Colors.white,
              fontSize: Responsive.fontSize(context, 20),
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

                // Registration Form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildRegistrationForm(),
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
        gradient: tripleBlueFashionGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.person_add_rounded,
            size: 60,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            'Email Registracija',
            style: TextStyle(
              color: Colors.white,
              fontSize: Responsive.fontSize(context, 28),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Registrujte se sa email adresom',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: Responsive.fontSize(context, 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),

          // Email Field (automatski prepoznaje vozača)
          _buildEmailField(),

          const SizedBox(height: 24),

          // Password Field
          _buildPasswordField(),

          const SizedBox(height: 24),

          // Confirm Password Field
          _buildConfirmPasswordField(),

          const SizedBox(height: 32),

          // Register Button
          _buildRegisterButton(),

          const SizedBox(height: 24),

          CheckboxListTile(
            value: _rememberDevice,
            onChanged: (v) {
              if (mounted) setState(() => _rememberDevice = v ?? false);
            },
            title: const Text('Zapamti uređaj'),
            controlAffinity: ListTileControlAffinity.leading,
          ),

          // Back to Login
          _buildBackToLogin(),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            // 🎯 AUTOMATSKI PREPOZNAJ VOZAČA NA OSNOVU EMAIL-A
            final vozac = VozacBoja.getVozacForEmail(value.trim());
            if (mounted) {
              setState(() {
                _selectedDriver = vozac;
              });
            }
          },
          decoration: InputDecoration(
            labelText: 'Email Adresa',
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            hintText: 'Unesite vašu email adresu',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            prefixIcon: const Icon(Icons.email, color: Colors.blue),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Unesite email adresu';
            }
            if (!AuthManager.isValidEmailFormat(value)) {
              return 'Unesite validnu email adresu';
            }

            // 🔒 AUTOMATSKA VALIDACIJA: Email mora biti iz liste dozvoljenih
            if (!VozacBoja.isDozvoljenEmail(value.trim())) {
              return 'Email adresa nije registrovana za nijednog vozača.\nDozvoljeni emailovi:\n${VozacBoja.sviDozvoljenEmails.join('\n')}';
            }

            return null;
          },
        ),

        // 🎯 PRIKAZ PREPOZNATOG VOZAČA
        if (_selectedDriver != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VozacBoja.get(_selectedDriver).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: VozacBoja.get(_selectedDriver).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: VozacBoja.get(_selectedDriver),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Prepoznat vozač: $_selectedDriver',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.fontSize(context, 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Šifra',
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        hintText: 'Najmanje 6 karaktera',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        prefixIcon: const Icon(Icons.lock, color: Colors.blue),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
            color: Colors.blue,
          ),
          onPressed: () {
            if (mounted)
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
          },
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
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

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: !_isConfirmPasswordVisible,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Potvrdite Šifru',
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        hintText: 'Ponovite šifru',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.blue),
        suffixIcon: IconButton(
          icon: Icon(
            _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
            color: Colors.blue,
          ),
          onPressed: () {
            if (mounted)
              setState(() {
                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
              });
          },
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Potvrdite šifru';
        }
        if (value != _passwordController.text) {
          return 'Šifre se ne poklapaju';
        }
        return null;
      },
    );
  }

  Widget _buildRegisterButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleRegistration,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        shadowColor: Colors.blue.withValues(alpha: 0.5),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              'Registrujte se',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 18),
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildBackToLogin() {
    return TextButton.icon(
      onPressed: () {
        Navigator.of(context).pop();
      },
      icon: const Icon(Icons.arrow_back, color: Colors.blue),
      label: Text(
        'Nazad na prijavu',
        style: TextStyle(
          color: Colors.blue,
          fontSize: Responsive.fontSize(context, 16),
        ),
      ),
    );
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) setState(() => _isLoading = true);

    // Pokaži loading poruku
    _showLoadingDialog(
      'Registracija u toku...',
      'Molimo sačekajte dok se vaš nalog kreira.',
    );

    try {
      // 🎯 AUTOMATSKA DETEKCIJA VOZAČA IZ EMAIL ADRESE
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Proveri da li je vozač automatski detektovan
      if (_selectedDriver == null) {
        throw Exception('Vozač nije automatski prepoznat iz email adrese');
      }

      final driverName = _selectedDriver!;

      // Koristi AuthManager umesto direktno EmailAuthService
      final result = await AuthManager.registerWithEmail(
        driverName,
        email,
        password,
        remember: _rememberDevice,
      );

      // Sakrij loading dialog
      if (mounted) Navigator.of(context).pop();

      if (result.isSuccess) {
        // 📧 PROVERI DA LI JE EMAIL VERIFICATION POTREBAN
        final needsVerification = !AuthManager.isEmailVerified();

        if (needsVerification) {
          // Sakrij loading dialog
          if (mounted) Navigator.of(context).pop();

          // Pokaži poruku o email verification
          await _showEmailVerificationDialog(email);

          // Vrati false da signalizira da verifikacija čeka
          if (mounted) {
            Navigator.of(context).pop(false);
          }
          return;
        }

        // REGISTRACIJA USPEŠNA - POKAŽI PORUKU
        // Pokaži uspešnu poruku
        await _showSuccessDialog();

        // Vrati true da signal uspješnu registraciju
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        _showErrorDialog(
          'Registracija neuspješna',
          result.message,
        );
      }
    } catch (e) {
      // Sakrij loading dialog ako je otvoren
      if (mounted) Navigator.of(context).pop();
      _showErrorDialog(
        'Greška',
        'Došlo je do greške pri registraciji. Pokušajte ponovo.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(
          message,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog(String title, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        insetPadding: const EdgeInsets.all(16),
        contentPadding: const EdgeInsets.all(20),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: Responsive.fontSize(context, 14),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSuccessDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        insetPadding: const EdgeInsets.all(16),
        contentPadding: const EdgeInsets.all(20),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Registracija uspešna!',
                style: TextStyle(color: Colors.white, fontSize: Responsive.fontSize(context, 16)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: SingleChildScrollView(
            child: Text(
              'Vaš nalog je uspešno kreiran i možete se prijaviti.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: Responsive.fontSize(context, 14)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('U redu', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Future<void> _showEmailVerificationDialog(String email) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.email, color: Colors.blue),
            SizedBox(width: 8),
            Text('Potvrda email adrese', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Poslali smo vam konfirmacioni email na:',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Molimo kliknite na link u email-u da potvrdite vašu adresu. Nakon toga se možete prijaviti u aplikaciju.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Razumem', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
}
