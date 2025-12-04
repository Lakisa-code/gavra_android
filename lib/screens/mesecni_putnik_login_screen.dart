import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';
import 'mesecni_putnik_profil_screen.dart';

/// 📱 MESEČNI PUTNIK LOGIN SCREEN
/// Putnik unosi telefon + PIN da se identifikuje
class MesecniPutnikLoginScreen extends StatefulWidget {
  const MesecniPutnikLoginScreen({Key? key}) : super(key: key);

  @override
  State<MesecniPutnikLoginScreen> createState() => _MesecniPutnikLoginScreenState();
}

class _MesecniPutnikLoginScreenState extends State<MesecniPutnikLoginScreen> {
  final _telefonController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSavedLogin();
  }

  /// Proveri da li je putnik već ulogovan
  Future<void> _checkSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('mesecni_putnik_telefon');
    final savedPin = prefs.getString('mesecni_putnik_pin');

    if (savedPhone != null && savedPhone.isNotEmpty && savedPin != null && savedPin.isNotEmpty) {
      // Automatski probaj login
      _telefonController.text = savedPhone;
      _pinController.text = savedPin;
      await _login();
    }
  }

  Future<void> _login() async {
    final telefon = _telefonController.text.trim();
    final pin = _pinController.text.trim();

    if (telefon.isEmpty) {
      setState(() => _errorMessage = 'Unesite broj telefona');
      return;
    }

    if (pin.isEmpty) {
      setState(() => _errorMessage = 'Unesite PIN');
      return;
    }

    if (pin.length != 4) {
      setState(() => _errorMessage = 'PIN mora imati 4 cifre');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Traži putnika po telefonu i PIN-u
      final response = await Supabase.instance.client
          .from('mesecni_putnici')
          .select()
          .eq('telefon', telefon)
          .eq('pin', pin)
          .maybeSingle();

      if (response != null) {
        // Sačuvaj za auto-login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('mesecni_putnik_telefon', telefon);
        await prefs.setString('mesecni_putnik_pin', pin);

        if (mounted) {
          // Idi na profil ekran
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MesecniPutnikProfilScreen(
                putnikData: Map<String, dynamic>.from(response),
              ),
            ),
          );
        }
      } else {
        // Proveri da li telefon postoji ali PIN nije tačan
        final phoneCheck =
            await Supabase.instance.client.from('mesecni_putnici').select('id').eq('telefon', telefon).maybeSingle();

        if (phoneCheck != null) {
          setState(() {
            _errorMessage = 'Pogrešan PIN. Pokušajte ponovo.';
          });
        } else {
          setState(() {
            _errorMessage = 'Niste pronađeni u sistemu.\nKontaktirajte admina za registraciju.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Greška pri povezivanju: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _telefonController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: tripleBlueFashionGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Ikona
                const Icon(
                  Icons.card_membership,
                  color: Colors.amber,
                  size: 60,
                ),
                const SizedBox(height: 16),

                // Naslov
                const Text(
                  'Mesečni putnici',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Unesite broj telefona i PIN',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),

                // Telefon input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: TextField(
                    controller: _telefonController,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    keyboardType: TextInputType.phone,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '06x xxx xxxx',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                      prefixIcon: const Icon(Icons.phone, color: Colors.amber),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // PIN input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: TextField(
                    controller: _pinController,
                    style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 4,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: '• • • •',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), letterSpacing: 8),
                      prefixIcon: const Icon(Icons.lock, color: Colors.amber),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                ),
                const SizedBox(height: 16),

                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Login dugme
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                          )
                        : const Text(
                            '🔓 Pristupi',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white54, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'PIN ste dobili od admina prilikom registracije. Ako nemate PIN, kontaktirajte nas.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
