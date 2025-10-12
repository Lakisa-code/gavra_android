import 'package:flutter/material.dart';

import '../services/driver_registration_service.dart';
import '../services/email_auth_service.dart';
import '../utils/logging.dart';
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

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Postavi preselected driver ako je proslećen
    if (widget.preselectedDriverName != null) {
      _selectedDriver = widget.preselectedDriverName;
      dlog('🚗 Preselected driver: ${widget.preselectedDriverName}');
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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1A2E),
              const Color(0xFF16213E),
              Colors.black.withOpacity(0.9),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withOpacity(0.8),
            Colors.indigo.withOpacity(0.6),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
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
          const Text(
            'Email Registracija',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Registrujte se sa email adresom',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
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

          // Driver Selection
          _buildDriverSelection(),

          const SizedBox(height: 24),

          // Email Field
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

          // Back to Login
          _buildBackToLogin(),
        ],
      ),
    );
  }

  Widget _buildDriverSelection() {
    final drivers = VozacBoja.validDrivers;

    return DropdownButtonFormField<String>(
      value: _selectedDriver,
      decoration: InputDecoration(
        labelText: 'Izaberite vozača',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        prefixIcon: const Icon(Icons.person, color: Colors.blue),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blue.withOpacity(0.3)),
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
      dropdownColor: const Color(0xFF1A1A2E),
      style: const TextStyle(color: Colors.white),
      items: drivers.map((driver) {
        return DropdownMenuItem<String>(
          value: driver,
          child: Text(driver),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedDriver = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Izaberite vozača';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Email Adresa',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        hintText: 'vas.email@primjer.com',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: const Icon(Icons.email, color: Colors.blue),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blue.withOpacity(0.3)),
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
        if (!EmailAuthService.isValidEmailFormat(value)) {
          return 'Unesite validnu email adresu';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Šifra',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        hintText: 'Najmanje 6 karaktera',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: const Icon(Icons.lock, color: Colors.blue),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
            color: Colors.blue,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blue.withOpacity(0.3)),
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
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        hintText: 'Ponovite šifru',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.blue),
        suffixIcon: IconButton(
          icon: Icon(
            _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
            color: Colors.blue,
          ),
          onPressed: () {
            setState(() {
              _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
            });
          },
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blue.withOpacity(0.3)),
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
        shadowColor: Colors.blue.withOpacity(0.5),
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
          : const Text(
              'Registrujte se',
              style: TextStyle(
                fontSize: 18,
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
      label: const Text(
        'Nazad na prijavu',
        style: TextStyle(
          color: Colors.blue,
          fontSize: 16,
        ),
      ),
    );
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Pokaži loading poruku
    _showLoadingDialog(
      'Registracija u toku...',
      'Molimo sačekajte dok se vaš nalog kreira.',
    );

    try {
      final driverName = _selectedDriver!;
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      dlog('📧 Registrujem vozača $driverName sa email-om: $email');

      final success = await EmailAuthService.registerDriverWithEmail(
        driverName,
        email,
        password,
      );

      // Sakrij loading dialog
      if (mounted) Navigator.of(context).pop();

      if (success) {
        dlog('✅ Registracija uspješna u Supabase');

        // REGISTRUJ VOZAČA LOKALNO
        final localRegistrationSuccess = await DriverRegistrationService.markDriverAsRegistered(
          driverName,
          email,
        );

        if (localRegistrationSuccess) {
          dlog('✅ Vozač $driverName lokalno registrovan');

          // Pokaži uspešnu poruku
          await _showSuccessDialog();

          // Vrati true da signal uspješnu registraciju
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else {
          dlog('❌ Greška pri lokalnoj registraciji vozača');
          _showErrorDialog(
            'Greška!',
            'Vozač je registrovan u sistemu, ali lokalna registracija nije uspešna.',
          );
        }
      } else {
        dlog('❌ Registracija nije uspješna');
        _showErrorDialog(
          'Registracija neuspješna',
          'Provjerite podatke i pokušajte ponovo. Email možda već postoji.',
        );
      }
    } catch (e) {
      // Sakrij loading dialog ako je otvoren
      if (mounted) Navigator.of(context).pop();

      dlog('❌ Greška pri registraciji: $e');
      _showErrorDialog(
        'Greška',
        'Došlo je do greške pri registraciji. Pokušajte ponovo.',
      );
    } finally {
      setState(() => _isLoading = false);
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
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
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
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Registracija uspešna!',
                style: TextStyle(color: Colors.white, fontSize: 16),
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
              'Poslali smo vam email sa linkom za potvrdu naloga. Molimo proverite vašu email poštu i kliknite na link da aktivirate nalog.',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
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
}
