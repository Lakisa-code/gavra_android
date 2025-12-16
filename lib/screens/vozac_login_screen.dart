import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_manager.dart';
import '../services/daily_checkin_service.dart';
import '../theme.dart';
import 'daily_checkin_screen.dart';
import 'home_screen.dart';
import 'vozac_screen.dart';

/// 🔐 VOZAČ LOGIN SCREEN
/// Lokalni login - proverava email/telefon/šifru iz SharedPreferences
class VozacLoginScreen extends StatefulWidget {
  final String vozacIme;

  const VozacLoginScreen({Key? key, required this.vozacIme}) : super(key: key);

  @override
  State<VozacLoginScreen> createState() => _VozacLoginScreenState();
}

class _VozacLoginScreenState extends State<VozacLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _telefonController = TextEditingController();
  final _sifraController = TextEditingController();

  bool _isLoading = false;
  bool _sifraVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _telefonController.dispose();
    _sifraController.dispose();
    super.dispose();
  }

  /// Učitaj vozače iz SharedPreferences
  Future<List<Map<String, dynamic>>> _loadVozaci() async {
    final prefs = await SharedPreferences.getInstance();
    final vozaciJson = prefs.getString('auth_vozaci');
    if (vozaciJson != null) {
      final List<dynamic> decoded = jsonDecode(vozaciJson);
      return decoded.map((v) => Map<String, dynamic>.from(v)).toList();
    }

    // Inicijalni podaci ako SharedPreferences je prazan
    final List<Map<String, dynamic>> initialVozaci = <Map<String, dynamic>>[
      <String, dynamic>{
        'ime': 'Bojan',
        'email': 'gavriconi19@gmail.com',
        'sifra': '191919',
        'telefon': '0641162560',
        'boja': 0xFF00E5FF,
      },
      <String, dynamic>{
        'ime': 'Bruda',
        'email': 'igor.jovanovic.1984@icloud.com',
        'sifra': '111111',
        'telefon': '0641202844',
        'boja': 0xFF7C4DFF,
      },
      <String, dynamic>{
        'ime': 'Bilevski',
        'email': 'bilyboy1983@gmail.com',
        'sifra': '222222',
        'telefon': '0638466418',
        'boja': 0xFFFF9800,
      },
      <String, dynamic>{
        'ime': 'Svetlana',
        'email': 'risticsvetlana2911@yahoo.com',
        'sifra': '444444',
        'telefon': '0658464160',
        'boja': 0xFFFF1493,
      },
      <String, dynamic>{
        'ime': 'Ivan',
        'email': 'kadpitamkurac@gmail.com',
        'sifra': '333333',
        'telefon': '0605073073',
        'boja': 0xFF8B4513, // braon
      },
    ];

    // Sačuvaj inicijalne podatke za buduće korišćenje
    await prefs.setString('auth_vozaci', jsonEncode(initialVozaci));
    return initialVozaci;
  }

  /// Proveri login
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final vozaci = await _loadVozaci();

      // Pronađi vozača po imenu
      final vozac = vozaci.firstWhere(
        (v) => v['ime'].toString().toLowerCase() == widget.vozacIme.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );

      if (vozac.isEmpty) {
        _showError('Vozač "${widget.vozacIme}" nije pronađen u sistemu.');
        return;
      }

      final email = _emailController.text.trim().toLowerCase();
      final telefon = _telefonController.text.trim();
      final sifra = _sifraController.text;

      // Proveri email
      if (vozac['email'].toString().toLowerCase() != email) {
        _showError('Pogrešan email.');
        return;
      }

      // Proveri telefon
      if (vozac['telefon'].toString() != telefon) {
        _showError('Pogrešan broj telefona.');
        return;
      }

      // Proveri šifru (ako postoji)
      final vozacSifra = vozac['sifra']?.toString() ?? '';
      if (vozacSifra.isNotEmpty && vozacSifra != sifra) {
        _showError('Pogrešna šifra.');
        return;
      }

      // ✅ SVE OK - LOGIN USPEŠAN
      await AuthManager.setCurrentDriver(widget.vozacIme);

      // Zapamti uređaj
      await AuthManager.rememberDevice(email, widget.vozacIme);

      if (!mounted) return;

      // Proveri daily check-in
      final hasCheckedIn = await DailyCheckInService.hasCheckedInToday(widget.vozacIme);

      if (!mounted) return;

      if (!hasCheckedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DailyCheckInScreen(
              vozac: widget.vozacIme,
              onCompleted: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => _getScreenForDriver(widget.vozacIme),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => _getScreenForDriver(widget.vozacIme),
          ),
        );
      }
    } catch (e) {
      _showError('Greška: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _getScreenForDriver(String driverName) {
    if (driverName == 'Ivan') {
      return const VozacScreen();
    }
    return const HomeScreen();
  }

  void _showError(String message) {
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          title: const Text(
            '🔐 Prijava',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const Icon(
                  Icons.login,
                  color: Colors.amber,
                  size: 60,
                ),
                const SizedBox(height: 16),
                Text(
                  'Dobrodošao, ${widget.vozacIme}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Potvrdi svoje podatke za prijavu',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Email
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('Email adresa', Icons.email),
                  validator: (v) {
                    if (v?.isEmpty == true) {
                      return 'Unesite email';
                    }
                    if (!v!.contains('@') || !v.contains('.')) {
                      return 'Neispravan email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Telefon
                TextFormField(
                  controller: _telefonController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Broj telefona', Icons.phone),
                  validator: (v) {
                    if (v?.isEmpty == true) return 'Unesite telefon';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Šifra
                TextFormField(
                  controller: _sifraController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: !_sifraVisible,
                  decoration: InputDecoration(
                    labelText: 'Šifra',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    prefixIcon: const Icon(Icons.lock, color: Colors.amber),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _sifraVisible ? Icons.visibility_off : Icons.visibility,
                        color: Colors.amber,
                      ),
                      onPressed: () => setState(() => _sifraVisible = !_sifraVisible),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.amber),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Login dugme
                ElevatedButton(
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
                          '🚀 Prijavi se',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 16),

                // Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white54, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Unesi iste podatke koje je admin postavio za tebe.',
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      prefixIcon: Icon(icon, color: Colors.amber),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.amber),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}
