import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

/// 🔐 PROMENA ŠIFRE SCREEN
/// Vozač može da promeni svoju šifru nakon uspešnog logina
class PromenaSifreScreen extends StatefulWidget {
  final String vozacIme;

  const PromenaSifreScreen({super.key, required this.vozacIme});

  @override
  State<PromenaSifreScreen> createState() => _PromenaSifreScreenState();
}

class _PromenaSifreScreenState extends State<PromenaSifreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _staraSifraController = TextEditingController();
  final _novaSifraController = TextEditingController();
  final _potvrdaSifraController = TextEditingController();

  bool _isLoading = false;
  bool _staraSifraVisible = false;
  bool _novaSifraVisible = false;
  bool _potvrdaVisible = false;

  String? _trenutnaSifra;

  @override
  void initState() {
    super.initState();
    _loadTrenutnaSifra();
  }

  @override
  void dispose() {
    _staraSifraController.dispose();
    _novaSifraController.dispose();
    _potvrdaSifraController.dispose();
    super.dispose();
  }

  Future<void> _loadTrenutnaSifra() async {
    final prefs = await SharedPreferences.getInstance();
    final vozaciJson = prefs.getString('auth_vozaci');
    if (vozaciJson != null) {
      final List<dynamic> decoded = jsonDecode(vozaciJson);
      final vozaci = decoded.map((v) => Map<String, dynamic>.from(v)).toList();
      final vozac = vozaci.firstWhere(
        (v) => v['ime'].toString().toLowerCase() == widget.vozacIme.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      if (vozac.isNotEmpty) {
        setState(() {
          _trenutnaSifra = vozac['sifra']?.toString() ?? '';
        });
      }
    }
  }

  Future<void> _promeniSifru() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final vozaciJson = prefs.getString('auth_vozaci');

      if (vozaciJson == null) {
        _showError('Greška: Nema podataka o vozačima.');
        return;
      }

      final List<dynamic> decoded = jsonDecode(vozaciJson);
      final vozaci = decoded.map((v) => Map<String, dynamic>.from(v)).toList();

      // Pronađi vozača
      final index = vozaci.indexWhere(
        (v) => v['ime'].toString().toLowerCase() == widget.vozacIme.toLowerCase(),
      );

      if (index == -1) {
        _showError('Vozač nije pronađen.');
        return;
      }

      // Proveri staru šifru
      final staraSifra = _staraSifraController.text;
      if (_trenutnaSifra != null && _trenutnaSifra!.isNotEmpty && _trenutnaSifra != staraSifra) {
        _showError('Pogrešna trenutna šifra.');
        return;
      }

      // Proveri da li se nove šifre poklapaju
      if (_novaSifraController.text != _potvrdaSifraController.text) {
        _showError('Nove šifre se ne poklapaju.');
        return;
      }

      // Ažuriraj šifru
      vozaci[index]['sifra'] = _novaSifraController.text;

      // Sačuvaj nazad u SharedPreferences
      await prefs.setString('auth_vozaci', jsonEncode(vozaci));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Šifra uspešno promenjena!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      _showError('Greška: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    final bool imaSifru = _trenutnaSifra != null && _trenutnaSifra!.isNotEmpty;

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
            '🔑 Promena šifre',
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
                  Icons.lock_reset,
                  color: Colors.amber,
                  size: 60,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.vozacIme,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  imaSifru ? 'Promeni svoju šifru' : 'Postavi novu šifru',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Stara šifra (ako postoji)
                if (imaSifru) ...[
                  TextFormField(
                    controller: _staraSifraController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: !_staraSifraVisible,
                    decoration: InputDecoration(
                      labelText: 'Trenutna šifra',
                      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.amber),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _staraSifraVisible ? Icons.visibility_off : Icons.visibility,
                          color: Colors.amber,
                        ),
                        onPressed: () => setState(() => _staraSifraVisible = !_staraSifraVisible),
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
                    validator: (v) {
                      if (imaSifru && (v?.isEmpty == true)) {
                        return 'Unesite trenutnu šifru';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Nova šifra
                TextFormField(
                  controller: _novaSifraController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: !_novaSifraVisible,
                  decoration: InputDecoration(
                    labelText: 'Nova šifra',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    prefixIcon: const Icon(Icons.lock, color: Colors.amber),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _novaSifraVisible ? Icons.visibility_off : Icons.visibility,
                        color: Colors.amber,
                      ),
                      onPressed: () => setState(() => _novaSifraVisible = !_novaSifraVisible),
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
                  validator: (v) {
                    if (v?.isEmpty == true) {
                      return 'Unesite novu šifru';
                    }
                    if (v!.length < 4) {
                      return 'Šifra mora imati minimum 4 karaktera';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Potvrda šifre
                TextFormField(
                  controller: _potvrdaSifraController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: !_potvrdaVisible,
                  decoration: InputDecoration(
                    labelText: 'Potvrdi novu šifru',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    prefixIcon: const Icon(Icons.lock_clock, color: Colors.amber),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _potvrdaVisible ? Icons.visibility_off : Icons.visibility,
                        color: Colors.amber,
                      ),
                      onPressed: () => setState(() => _potvrdaVisible = !_potvrdaVisible),
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
                  validator: (v) {
                    if (v?.isEmpty == true) {
                      return 'Potvrdite novu šifru';
                    }
                    if (v != _novaSifraController.text) {
                      return 'Šifre se ne poklapaju';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Dugme za promenu
                ElevatedButton(
                  onPressed: _isLoading ? null : _promeniSifru,
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
                      : Text(
                          imaSifru ? '🔄 Promeni šifru' : '✅ Postavi šifru',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 24),

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
                          'Nova šifra će važiti od sledeće prijave.',
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
