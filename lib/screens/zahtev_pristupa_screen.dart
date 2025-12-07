import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';
import 'dnevni_putnik_screen.dart';
import 'putnik_cekanje_screen.dart';

/// 📝 ZAHTEV PRISTUPA SCREEN
/// Ovde DNEVNI putnici šalju zahtev za registraciju
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
  final _telefonController = TextEditingController();
  final _porukaController = TextEditingController();

  // Dropdown za grad
  String? _selectedGrad;

  bool _isLoading = false;
  final bool _zahtevPoslat = false;

  // Za proveru postojećeg zahteva
  bool _hasExistingRequest = false;
  Map<String, dynamic>? _existingRequest;

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
  }

  /// Proverava da li postoji sačuvan zahtev u SharedPreferences
  Future<void> _checkExistingRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('pending_request_phone');

    if (savedPhone != null && savedPhone.isNotEmpty) {
      // Proveri status u bazi
      await _checkRequestStatus(savedPhone);
    }
  }

  /// Proverava status zahteva u bazi po broju telefona
  Future<void> _checkRequestStatus(String phone) async {
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('zahtevi_pristupa')
          .select()
          .eq('telefon', phone)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _existingRequest = response;
          _hasExistingRequest = true;
        });
      }
    } catch (e) {
      debugPrint('Greška pri proveri zahteva: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Briše sačuvani zahtev i omogućava novi
  Future<void> _clearSavedRequest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_request_phone');
    setState(() {
      _hasExistingRequest = false;
      _existingRequest = null;
    });
  }

  /// Nastavlja na DnevniPutnikScreen kada je zahtev odobren
  Future<void> _nastaviNaDnevniEkran(String ime, String prezime) async {
    try {
      final zahtevId = _existingRequest?['id'];
      if (zahtevId == null) {
        _showError('Greška: nema ID zahteva');
        return;
      }

      // Dohvati putnik_id iz dnevni_putnici_registrovani
      final response = await Supabase.instance.client
          .from('dnevni_putnici_registrovani')
          .select('id')
          .eq('zahtev_id', zahtevId)
          .single();

      final putnikId = response['id'] as String;

      // Sačuvaj u SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dnevni_putnik_id', putnikId);
      await prefs.setString('dnevni_putnik_ime', '$ime $prezime');
      await prefs.setBool('dnevni_putnik_approved', true);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DnevniPutnikScreen(
              putnikId: putnikId,
              ime: ime,
              prezime: prezime,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Greška pri navigaciji: $e');
      _showError('Greška pri učitavanju podataka');
    }
  }

  @override
  void dispose() {
    _imeController.dispose();
    _prezimeController.dispose();
    _adresaController.dispose();
    _telefonController.dispose();
    _porukaController.dispose();
    super.dispose();
  }

  Future<void> _posaljiZahtev() async {
    if (!_formKey.currentState!.validate()) return;

    // Validacija dropdown-a
    if (_selectedGrad == null) {
      _showError('Izaberite grad');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phone = _telefonController.text.trim();
      final ime = _imeController.text.trim();
      final prezime = _prezimeController.text.trim();

      // Insert i dobij ID nazad
      final response = await Supabase.instance.client
          .from('zahtevi_pristupa')
          .insert({
            'ime': ime,
            'prezime': prezime,
            'adresa': _adresaController.text.trim(),
            'telefon': phone,
            'poruka': _porukaController.text.trim(),
            'grad': _selectedGrad,
            'tip_putnika': 'dnevni', // Automatski dnevni putnik
            'podtip': null,
            'status': 'pending',
          })
          .select('id')
          .single();

      final zahtevId = response['id'].toString();

      // Sačuvaj telefon za kasniju proveru statusa
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_request_phone', phone);
      await prefs.setString('pending_request_id', zahtevId);

      setState(() => _isLoading = false);

      // Navigiraj na ekran za čekanje
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PutnikCekanjeScreen(
              zahtevId: zahtevId,
              ime: ime,
              prezime: prezime,
            ),
          ),
        );
      }
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
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
          title: const Text(
            '📝 Registracija putnika',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading && !_zahtevPoslat && !_hasExistingRequest
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : _zahtevPoslat
                ? _buildSuccess()
                : _hasExistingRequest
                    ? _buildExistingRequestStatus()
                    : _buildForm(),
      ),
    );
  }

  /// Prikazuje status postojećeg zahteva
  Widget _buildExistingRequestStatus() {
    final status = _existingRequest?['status'] ?? 'pending';
    final ime = _existingRequest?['ime'] ?? '';
    final prezime = _existingRequest?['prezime'] ?? '';

    IconData statusIcon;
    Color statusColor;
    String statusText;
    String statusDescription;

    switch (status) {
      case 'approved':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        statusText = '✅ Odobren!';
        statusDescription = 'Tvoj zahtev je odobren.\nSada možeš koristiti aplikaciju.';
        break;
      case 'rejected':
        statusIcon = Icons.cancel;
        statusColor = Colors.red;
        statusText = '❌ Odbijen';
        statusDescription = 'Nažalost, tvoj zahtev je odbijen.\nMožeš poslati novi zahtev.';
        break;
      default: // pending
        statusIcon = Icons.hourglass_empty;
        statusColor = Colors.amber;
        statusText = '⏳ Čeka odobrenje';
        statusDescription = 'Tvoj zahtev čeka pregled od strane admina.\nMolimo te za strpljenje.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(statusIcon, color: statusColor, size: 80),
            const SizedBox(height: 24),
            Text(
              statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$ime $prezime',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              statusDescription,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Dugme za osvežavanje statusa
            if (status == 'pending') ...[
              ElevatedButton.icon(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final phone = prefs.getString('pending_request_phone');
                  if (phone != null) {
                    await _checkRequestStatus(phone);
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Osveži status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Dugme za nastavak ako je odobren
            if (status == 'approved') ...[
              ElevatedButton.icon(
                onPressed: () => _nastaviNaDnevniEkran(ime, prezime),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Nastavi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Dugme za novi zahtev (ako je odbijen) ili nazad
            if (status == 'rejected') ...[
              ElevatedButton.icon(
                onPressed: _clearSavedRequest,
                icon: const Icon(Icons.add),
                label: const Text('Pošalji novi zahtev'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Nazad dugme
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              label: const Text('Nazad', style: TextStyle(color: Colors.white70)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white38),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
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
              Icons.directions_bus,
              color: Colors.amber,
              size: 40,
            ),
            const SizedBox(height: 16),
            const Text(
              'Zakaži vožnju',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Registruj se za dnevne vožnje',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Info box - registracija samo jednom
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.black87, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Registracija se vrši samo jednom! Nakon odobrenja, tvoji podaci se pamte i možeš rezervisati vožnje bez ponovnog unosa.',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Grad (BC / VS)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedGrad,
                decoration: InputDecoration(
                  labelText: 'Grad',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  prefixIcon: const Icon(Icons.location_city, color: Colors.amber),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                dropdownColor: const Color(0xFF1a1a2e),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'BC', child: Text('Bela Crkva')),
                  DropdownMenuItem(value: 'VS', child: Text('Vršac')),
                ],
                onChanged: (v) => setState(() => _selectedGrad = v),
              ),
            ),
            const SizedBox(height: 16),

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
