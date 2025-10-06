import 'package:flutter/material.dart';
import '../services/email_auth_service.dart';
import '../utils/logging.dart';
import 'email_login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String driverName;

  const EmailVerificationScreen({
    Key? key,
    required this.email,
    required this.driverName,
  }) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with TickerProviderStateMixin {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isResendLoading = false;

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
    _codeController.dispose();
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

                // Verification Form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildVerificationForm(),
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
            Icons.mark_email_read_rounded,
            size: 60,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          const Text(
            'Email Verifikacija',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Provjerite email: ${widget.email}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),

        // Instructions
        _buildInstructions(),

        const SizedBox(height: 32),

        // Code Field
        _buildCodeField(),

        const SizedBox(height: 32),

        // Verify Button
        _buildVerifyButton(),

        const SizedBox(height: 24),

        // Resend Code
        _buildResendCodeButton(),

        const SizedBox(height: 24),

        // Back to Registration
        _buildBackToRegistration(),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.info_outline,
            color: Colors.blue,
            size: 32,
          ),
          const SizedBox(height: 16),
          Text(
            'Poslali smo verifikacioni kod na vašu email adresu. Unesite 6-cifreni kod da biste potvrdili email.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeField() {
    return TextFormField(
      controller: _codeController,
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: 8,
      ),
      decoration: InputDecoration(
        labelText: 'Verifikacioni Kod',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        hintText: '000000',
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 24,
          letterSpacing: 8,
        ),
        prefixIcon: const Icon(Icons.security, color: Colors.blue),
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
        counterText: '',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Unesite verifikacioni kod';
        }
        if (value.length != 6) {
          return 'Kod mora imati 6 cifara';
        }
        return null;
      },
    );
  }

  Widget _buildVerifyButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleVerification,
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
              'Potvrdi Email',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildResendCodeButton() {
    return TextButton(
      onPressed: _isResendLoading ? null : _handleResendCode,
      child: _isResendLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          : Text(
              'Pošalji kod ponovo',
              style: TextStyle(
                color: Colors.blue.shade300,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
    );
  }

  Widget _buildBackToRegistration() {
    return TextButton.icon(
      onPressed: () {
        Navigator.of(context).pop();
      },
      icon: const Icon(Icons.arrow_back, color: Colors.blue),
      label: const Text(
        'Nazad na registraciju',
        style: TextStyle(
          color: Colors.blue,
          fontSize: 16,
        ),
      ),
    );
  }

  Future<void> _handleVerification() async {
    final code = _codeController.text.trim();

    if (code.isEmpty || code.length != 6) {
      _showErrorDialog('Nevažeći kod', 'Unesite 6-cifreni verifikacioni kod.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      dlog('📧 Potvrđujem email ${widget.email} sa kodom: $code');

      final success =
          await EmailAuthService.confirmEmailVerification(widget.email, code);

      if (success) {
        dlog('✅ Email uspješno potvrđen za vozača: ${widget.driverName}');

        _showSuccessDialog(
          'Email Potvrđen',
          'Vaš email je uspješno potvrđen. Sada se možete prijaviti.',
          onOk: () {
            // Idi na login screen
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const EmailLoginScreen(),
              ),
              (route) => false,
            );
          },
        );
      } else {
        _showErrorDialog(
            'Neuspješna verifikacija', 'Provjerite kod i pokušajte ponovo.');
      }
    } catch (e) {
      dlog('❌ Greška pri verifikaciji email-a: $e');
      _showErrorDialog(
          'Greška', 'Došlo je do greške pri verifikaciji. Pokušajte ponovo.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResendCode() async {
    setState(() => _isResendLoading = true);

    try {
      final success = await EmailAuthService.resendEmailCode(widget.email);

      if (success) {
        _showSuccessDialog(
            'Kod poslan', 'Novi verifikacioni kod je poslan na vaš email.');
      } else {
        _showErrorDialog('Greška', 'Nije moguće poslati novi kod.');
      }
    } catch (e) {
      dlog('❌ Greška pri ponovnom slanju koda: $e');
      _showErrorDialog('Greška', 'Došlo je do greške. Pokušajte ponovo.');
    } finally {
      setState(() => _isResendLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message,
            style: TextStyle(color: Colors.white.withOpacity(0.8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message, {VoidCallback? onOk}) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message,
            style: TextStyle(color: Colors.white.withOpacity(0.8))),
        actions: [
          TextButton(
            onPressed: onOk ?? () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
}
