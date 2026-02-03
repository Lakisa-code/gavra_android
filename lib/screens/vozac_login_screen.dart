import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_manager.dart';
import '../services/biometric_service.dart';
import '../services/daily_checkin_service.dart';
import '../services/theme_manager.dart';
import 'daily_checkin_screen.dart';
import 'home_screen.dart';
import 'vozac_screen.dart';

/// 🔐 VOZAČ LOGIN SCREEN
/// Lokalni login - proverava email/telefon/šifru iz SharedPreferences
class VozacLoginScreen extends StatefulWidget {
  final String vozacIme;

  const VozacLoginScreen({super.key, required this.vozacIme});

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

  // 👆 Biometrija
  bool _biometricAvailable = false;
  bool _hasSavedCredentials = false;
  String _biometricIcon = '👆';

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  /// 👆 Proveri biometriju i sačuvane kredencijale
  Future<void> _checkBiometric() async {
    final available = await BiometricService.isBiometricAvailable();
    final hasCreds = await _hasBiometricCredentials();
    final icon = await BiometricService.getBiometricIcon();

    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _hasSavedCredentials = hasCreds;
        _biometricIcon = icon;
      });

      // Auto-login sa biometrijom ako ima sačuvane kredencijale
      if (available && hasCreds) {
        _loginWithBiometric();
      }
    }
  }

  /// Proveri da li ima sačuvane kredencijale za ovog vozača
  Future<bool> _hasBiometricCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'biometric_vozac_${widget.vozacIme}';
    final savedVozac = prefs.getString(key);
    return savedVozac != null;
  }

  /// 👆 Login sa biometrijom
  Future<void> _loginWithBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('biometric_vozac_${widget.vozacIme}');

    if (savedData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Nema sačuvanih kredencijala. Prijavi se prvo ručno.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final authenticated = await BiometricService.authenticate(
      reason: 'Potvrdi identitet za prijavu kao ${widget.vozacIme}',
    );

    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Biometrijska autentifikacija nije uspela'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Dekoduj sačuvane podatke
    final data = jsonDecode(savedData);
    _emailController.text = data['email'] ?? '';
    _telefonController.text = data['telefon'] ?? '';
    _sifraController.text = data['sifra'] ?? '';

    // Login
    await _login(saveBiometric: false);
  }

  /// 👆 Sačuvaj kredencijale za biometriju
  Future<void> _saveBiometricCredentials() async {
    if (!_biometricAvailable) return;

    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'email': _emailController.text.trim(),
      'telefon': _telefonController.text.trim(),
      'sifra': _sifraController.text,
    });
    await prefs.setString('biometric_vozac_${widget.vozacIme}', data);
  }

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
        'email': 'bradvarevicivan99@gmail.com',
        'sifra': '333333',
        'telefon': '0677662993',
        'boja': 0xFFFFD700, // žuta (Gold)
      },
    ];

    // Sačuvaj inicijalne podatke za buduće korišćenje
    await prefs.setString('auth_vozaci', jsonEncode(initialVozaci));
    return initialVozaci;
  }

  /// Proveri login
  Future<void> _login({bool saveBiometric = true}) async {
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

      // Proveri telefon (sa normalizacijom)
      final normalizedInput = _normalizePhone(telefon);
      final normalizedStored = _normalizePhone(vozac['telefon'].toString());
      if (normalizedInput != normalizedStored) {
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

      // 👆 Sačuvaj za biometriju
      if (saveBiometric && _biometricAvailable) {
        await _saveBiometricCredentials();
      }

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
    // Vozači koji koriste VozacScreen umesto HomeScreen
    if (driverName == 'Ivan' || driverName == 'Voja') {
      return const VozacScreen();
    }
    return const HomeScreen();
  }

  /// 📱 Normalizuje broj telefona za poređenje
  /// Uklanja razmake, crtice, zagrade i prefikse (+381, 00381)
  String _normalizePhone(String telefon) {
    var cleaned = telefon.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+381')) {
      cleaned = '0${cleaned.substring(4)}';
    } else if (cleaned.startsWith('00381')) {
      cleaned = '0${cleaned.substring(5)}';
    }
    return cleaned;
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
    final themeManager = ThemeManager();
    final currentTheme = themeManager.currentTheme;
    final isDark = currentTheme.colorScheme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: themeManager.currentGradient,
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
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Icon(
                  Icons.login,
                  color: isDark ? currentTheme.colorScheme.primary : Colors.amber,
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
                  decoration: _inputDecoration('Email adresa', Icons.email, isDark, currentTheme),
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
                  decoration: _inputDecoration('Broj telefona', Icons.phone, isDark, currentTheme),
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
                    prefixIcon: Icon(Icons.lock, color: isDark ? currentTheme.colorScheme.primary : Colors.amber),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _sifraVisible ? Icons.visibility_off : Icons.visibility,
                        color: isDark ? currentTheme.colorScheme.primary : Colors.amber,
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
                      borderSide: BorderSide(
                          color: (isDark ? currentTheme.colorScheme.primary : Colors.amber).withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? currentTheme.colorScheme.primary : Colors.amber),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Login dugme
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? currentTheme.colorScheme.primary : Colors.amber,
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: isDark ? Colors.white : Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '🚀 Prijavi se',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),

                // 👆 Biometrija dugme
                if (_biometricAvailable && _hasSavedCredentials) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithBiometric,
                    icon: Text(_biometricIcon, style: const TextStyle(fontSize: 24)),
                    label: const Text(
                      'Prijava otiskom prsta',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: isDark ? currentTheme.colorScheme.primary : Colors.amber),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
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

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark, dynamic currentTheme) {
    final accentColor = isDark ? currentTheme.colorScheme.primary as Color : Colors.amber;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      prefixIcon: Icon(icon, color: accentColor),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accentColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}
