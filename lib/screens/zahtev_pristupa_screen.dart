import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

/// 📝 ZAHTEV PRISTUPA SCREEN
/// Ovde novi vozači šalju zahtev za pristup aplikaciji
class ZahtevPristupaScreen extends StatefulWidget {
  const ZahtevPristupaScreen({Key? key}) : super(key: key);

  @override
  State<ZahtevPristupaScreen> createState() => _ZahtevPristupaScreenState();
}

class _ZahtevPristupaScreenState extends State<ZahtevPristupaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imeController = TextEditingController();
  final _prezimeController = TextEditingController();
  final _adresaController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonController = TextEditingController();
  final _porukaController = TextEditingController();

  bool _isLoading = false;
  bool _zahtevPoslat = false;

  @override
  void dispose() {
    _imeController.dispose();
    _prezimeController.dispose();
    _adresaController.dispose();
    _emailController.dispose();
    _telefonController.dispose();
    _porukaController.dispose();
    super.dispose();
  }

  Future<void> _posaljiZahtev() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.from('zahtevi_pristupa').insert({
        'ime': _imeController.text.trim(),
        'prezime': _prezimeController.text.trim(),
        'adresa': _adresaController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'telefon': _telefonController.text.trim(),
        'poruka': _porukaController.text.trim(),
        'status': 'pending',
      });

      setState(() {
        _isLoading = false;
        _zahtevPoslat = true;
      });
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            '📝 Zatraži pristup',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: _zahtevPoslat ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              '✅ Zahtev poslat!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Admin će pregledati tvoj zahtev.\nDobićeš pristup kad te odobri.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Nazad'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Icon(
              Icons.person_add,
              color: Colors.amber,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'Pridruži se Gavra 013',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Popuni formu i sačekaj odobrenje admina',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Ime
            TextFormField(
              controller: _imeController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Ime', Icons.person),
              validator: (v) {
                if (v?.isEmpty == true) return 'Unesite ime';
                if (v!.length < 2) return 'Ime mora imati bar 2 karaktera';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Prezime
            TextFormField(
              controller: _prezimeController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Prezime', Icons.person_outline),
              validator: (v) {
                if (v?.isEmpty == true) return 'Unesite prezime';
                if (v!.length < 2) return 'Prezime mora imati bar 2 karaktera';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Adresa
            TextFormField(
              controller: _adresaController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Adresa', Icons.home),
              validator: (v) {
                if (v?.isEmpty == true) return 'Unesite adresu';
                return null;
              },
            ),
            const SizedBox(height: 16),

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

            // Poruka (opciono)
            TextFormField(
              controller: _porukaController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: _inputDecoration('Poruka za admina (opciono)', Icons.message),
            ),
            const SizedBox(height: 32),

            // Submit dugme
            ElevatedButton(
              onPressed: _isLoading ? null : _posaljiZahtev,
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
                      '📨 Pošalji zahtev',
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
                      'Admin će dobiti obaveštenje o tvom zahtevu i odobriti pristup.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
