import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

/// 🔐 AUTH SCREEN - Admin panel za upravljanje vozačima
/// Ovde dodaješ/brišeš vozače, emailove, šifre, telefone, boje
class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  List<Map<String, dynamic>> _vozaci = [];
  bool _isLoading = true;

  // Forma za novog vozača
  final _formKey = GlobalKey<FormState>();
  final _imeController = TextEditingController();
  final _emailController = TextEditingController();
  final _sifraController = TextEditingController();
  final _telefonController = TextEditingController();
  Color _selectedColor = Colors.blue;

  // Predefinisane boje za izbor
  final List<Color> _availableColors = [
    const Color(0xFF7C4DFF), // ljubičasta
    const Color(0xFFFF9800), // narandžasta
    const Color(0xFF00E5FF), // cyan
    const Color(0xFFFF1493), // pink
    const Color(0xFFFFD700), // žuta (Gold)
    const Color(0xFF4CAF50), // zelena
    const Color(0xFFE91E63), // crvena-pink
    const Color(0xFF2196F3), // plava
    const Color(0xFFFFEB3B), // svetla žuta
    const Color(0xFF9C27B0), // tamno ljubičasta
  ];

  @override
  void initState() {
    super.initState();
    _loadVozaci();
  }

  @override
  void dispose() {
    _imeController.dispose();
    _emailController.dispose();
    _sifraController.dispose();
    _telefonController.dispose();
    super.dispose();
  }

  /// Učitaj vozače iz SharedPreferences
  Future<void> _loadVozaci() async {
    final prefs = await SharedPreferences.getInstance();
    final vozaciJson = prefs.getString('auth_vozaci');

    if (vozaciJson != null) {
      final List<dynamic> decoded = jsonDecode(vozaciJson);
      if (!mounted) return;
      setState(() {
        _vozaci = decoded.map((v) => Map<String, dynamic>.from(v)).toList();
        _isLoading = false;
      });
    } else {
      // Inicijalni podaci - postojeći vozači
      _vozaci = [
        {
          'ime': 'Bojan',
          'email': 'gavriconi19@gmail.com',
          'sifra': '191919',
          'telefon': '0641162560',
          'boja': 0xFF00E5FF,
        },
        {
          'ime': 'Bruda',
          'email': 'igor.jovanovic.1984@icloud.com',
          'sifra': '111111',
          'telefon': '0641202844',
          'boja': 0xFF7C4DFF,
        },
        {
          'ime': 'Bilevski',
          'email': 'bilyboy1983@gmail.com',
          'sifra': '222222',
          'telefon': '0638466418',
          'boja': 0xFFFF9800,
        },
        {
          'ime': 'Svetlana',
          'email': 'risticsvetlana2911@yahoo.com',
          'sifra': '444444',
          'telefon': '0658464160',
          'boja': 0xFFFF1493,
        },
        {
          'ime': 'Ivan',
          'email': 'bradvarevicivan99@gmail.com',
          'sifra': '333333',
          'telefon': '0677662993',
          'boja': 0xFFFFD700, // žuta (Gold)
        },
      ];
      await _saveVozaci();
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Sačuvaj vozače u SharedPreferences
  Future<void> _saveVozaci() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_vozaci', jsonEncode(_vozaci));
  }

  /// Dodaj novog vozača
  Future<void> _addVozac() async {
    if (!_formKey.currentState!.validate()) return;

    final noviVozac = {
      'ime': _imeController.text.trim(),
      'email': _emailController.text.trim().toLowerCase(),
      'sifra': _sifraController.text,
      'telefon': _telefonController.text.trim(),
      'boja': _selectedColor.toARGB32(),
    };

    setState(() {
      _vozaci.add(noviVozac);
    });
    await _saveVozaci();

    // Reset forme
    _imeController.clear();
    _emailController.clear();
    _sifraController.clear();
    _telefonController.clear();
    _selectedColor = Colors.blue;

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vozač ${noviVozac['ime']} dodat!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Obriši vozača
  Future<void> _deleteVozac(int index) async {
    final vozac = _vozaci[index];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Obriši vozača?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Da li si siguran da želiš da obrišeš ${vozac['ime']}?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ne'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Da', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _vozaci.removeAt(index);
      });
      await _saveVozaci();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${vozac['ime']} obrisan!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Edituj vozača
  Future<void> _editVozac(int index) async {
    final vozac = _vozaci[index];

    _imeController.text = vozac['ime'] ?? '';
    _emailController.text = vozac['email'] ?? '';
    _sifraController.text = vozac['sifra'] ?? '';
    _telefonController.text = vozac['telefon'] ?? '';
    _selectedColor = Color(vozac['boja'] ?? 0xFF2196F3);

    await showDialog(
      context: context,
      builder: (ctx) => _buildVozacDialog(
        title: 'Izmeni vozača',
        onSave: () async {
          setState(() {
            _vozaci[index] = {
              'ime': _imeController.text.trim(),
              'email': _emailController.text.trim().toLowerCase(),
              'sifra': _sifraController.text,
              'telefon': _telefonController.text.trim(),
              'boja': _selectedColor.toARGB32(),
            };
          });
          await _saveVozaci();

          _imeController.clear();
          _emailController.clear();
          _sifraController.clear();
          _telefonController.clear();

          if (!mounted) return;
          // ignore: use_build_context_synchronously
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vozač ažuriran!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  /// Dialog za dodavanje/editovanje vozača
  Widget _buildVozacDialog({required String title, required VoidCallback onSave}) {
    return StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ime
                TextFormField(
                  controller: _imeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Ime vozača', Icons.person),
                  validator: (v) => v?.isEmpty == true ? 'Unesite ime' : null,
                ),
                const SizedBox(height: 12),

                // Email
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('Email', Icons.email),
                  validator: (v) {
                    if (v?.isEmpty == true) return 'Unesite email';
                    if (!v!.contains('@')) return 'Neispravan email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Šifra
                TextFormField(
                  controller: _sifraController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  decoration: _inputDecoration('Šifra', Icons.lock),
                ),
                const SizedBox(height: 12),

                // Telefon
                TextFormField(
                  controller: _telefonController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Telefon', Icons.phone),
                ),
                const SizedBox(height: 16),

                // Boja
                const Text('Izaberi boju:', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableColors.map((color) {
                    final isSelected = _selectedColor.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow:
                              isSelected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)] : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _imeController.clear();
              _emailController.clear();
              _sifraController.clear();
              _telefonController.clear();
              Navigator.pop(context);
            },
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Sačuvaj'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      prefixIcon: Icon(icon, color: Colors.blue),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue),
      ),
    );
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
          automaticallyImplyLeading: false,
          title: const Text(
            '🔐 Auth Admin',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
              onPressed: () {
                _imeController.clear();
                _emailController.clear();
                _sifraController.clear();
                _telefonController.clear();
                _selectedColor = Colors.blue;

                showDialog(
                  context: context,
                  builder: (ctx) => _buildVozacDialog(
                    title: 'Dodaj vozača',
                    onSave: _addVozac,
                  ),
                );
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // 👥 SEKCIJA VOZAČA
                  Row(
                    children: [
                      const Text(
                        '👥 VOZAČI',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_vozaci.length}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_vozaci.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Nema vozača.\nKlikni + da dodaš.',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ..._vozaci.asMap().entries.map((entry) {
                      final index = entry.key;
                      final vozac = entry.value;
                      final boja = Color(vozac['boja'] ?? 0xFF2196F3);

                      return Card(
                        color: Colors.white.withValues(alpha: 0.1),
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: boja.withValues(alpha: 0.6), width: 1.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                backgroundColor: boja,
                                radius: 22,
                                child: Text(
                                  (vozac['ime'] ?? '?')[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Ime vozača + ikone u istom redu
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            vozac['ime'] ?? '',
                                            style: TextStyle(
                                              color: boja,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        // Actions - olovka i kanta
                                        IconButton(
                                          icon: Icon(Icons.edit, color: boja, size: 20),
                                          onPressed: () => _editVozac(index),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                          onPressed: () => _deleteVozac(index),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.email, size: 14, color: Colors.white54),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            vozac['email'] ?? '-',
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(Icons.phone, size: 14, color: Colors.white54),
                                        const SizedBox(width: 6),
                                        Text(
                                          vozac['telefon'] ?? '-',
                                          style: const TextStyle(color: Colors.white, fontSize: 13),
                                        ),
                                        if (vozac['sifra']?.isNotEmpty == true)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 6),
                                            child: Text('🔒', style: TextStyle(fontSize: 12)),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }
}

/// 🔐 AUTH SERVICE - Statički servis za auth operacije
/// Koristi se umesto Supabase Auth
class LocalAuthService {
  static const String _storageKey = 'auth_vozaci';

  /// Učitaj sve vozače
  static Future<List<Map<String, dynamic>>> getVozaci() async {
    final prefs = await SharedPreferences.getInstance();
    final vozaciJson = prefs.getString(_storageKey);

    if (vozaciJson != null) {
      final List<dynamic> decoded = jsonDecode(vozaciJson);
      return decoded.map((v) => Map<String, dynamic>.from(v)).toList();
    }
    return [];
  }

  /// Pronađi vozača po emailu
  static Future<Map<String, dynamic>?> getVozacByEmail(String email) async {
    final vozaci = await getVozaci();
    try {
      return vozaci.firstWhere(
        (v) => (v['email'] as String?)?.toLowerCase() == email.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Proveri login (email + šifra)
  static Future<Map<String, dynamic>?> login(String email, String sifra) async {
    final vozac = await getVozacByEmail(email);
    if (vozac == null) return null;

    // Ako vozač nema šifru, dozvoli login samo sa emailom
    if (vozac['sifra']?.isEmpty != false) {
      return vozac;
    }

    // Proveri šifru
    if (vozac['sifra'] == sifra) {
      return vozac;
    }

    return null;
  }

  /// Dobij boju vozača
  static Future<Color?> getVozacColor(String ime) async {
    final vozaci = await getVozaci();
    try {
      final vozac = vozaci.firstWhere(
        (v) => (v['ime'] as String?)?.toLowerCase() == ime.toLowerCase(),
      );
      return Color(vozac['boja'] ?? 0xFF2196F3);
    } catch (_) {
      return null;
    }
  }

  /// Dobij telefon vozača
  static Future<String?> getVozacTelefon(String ime) async {
    final vozaci = await getVozaci();
    try {
      final vozac = vozaci.firstWhere(
        (v) => (v['ime'] as String?)?.toLowerCase() == ime.toLowerCase(),
      );
      return vozac['telefon'];
    } catch (_) {
      return null;
    }
  }

  /// Dobij email vozača
  static Future<String?> getVozacEmail(String ime) async {
    final vozaci = await getVozaci();
    try {
      final vozac = vozaci.firstWhere(
        (v) => (v['ime'] as String?)?.toLowerCase() == ime.toLowerCase(),
      );
      return vozac['email'];
    } catch (_) {
      return null;
    }
  }

  /// Proveri da li je email dozvoljen
  static Future<bool> isEmailAllowed(String email) async {
    final vozac = await getVozacByEmail(email);
    return vozac != null;
  }

  /// Dobij ime vozača po emailu
  static Future<String?> getVozacNameByEmail(String email) async {
    final vozac = await getVozacByEmail(email);
    return vozac?['ime'];
  }
}
