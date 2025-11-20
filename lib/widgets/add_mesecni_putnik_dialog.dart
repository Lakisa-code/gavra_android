import 'package:flutter/material.dart';

import '../models/mesecni_putnik.dart';
import '../services/adresa_supabase_service.dart';
import '../services/mesecni_putnik_service.dart';
import '../theme.dart';
import '../utils/mesecni_helpers.dart';
import '../widgets/shared/time_row.dart';

/// 🆕 WIDGET ZA DODAVANJE MESEČNIH PUTNIKA
///
/// Izdvojen iz mesecni_putnici_screen.dart za bolju organizaciju koda.
/// Sadrži kompletnu logiku za dodavanje novog mesečnog putnika sa:
/// - Osnovnim informacijama (ime, tip, škola)
/// - Kontakt podacima (telefoni)
/// - Adresama polaska
/// - Radnim danima i vremenima
/// - Responsivnim dizajnom (dialog/bottom sheet)
/// - Glassmorphism stilizovanjem
class AddMesecniPutnikDialog extends StatefulWidget {
  final VoidCallback? onAdded;

  const AddMesecniPutnikDialog({
    super.key,
    this.onAdded,
  });

  @override
  State<AddMesecniPutnikDialog> createState() => _AddMesecniPutnikDialogState();
}

class _AddMesecniPutnikDialogState extends State<AddMesecniPutnikDialog> {
  final MesecniPutnikService _mesecniPutnikService = MesecniPutnikService();

  // Form controllers
  final TextEditingController _imeController = TextEditingController();
  final TextEditingController _tipSkoleController = TextEditingController();
  final TextEditingController _brojTelefonaController = TextEditingController();
  final TextEditingController _brojTelefonaOcaController = TextEditingController();
  final TextEditingController _brojTelefonaMajkeController = TextEditingController();
  final TextEditingController _adresaBelaCrkvaController = TextEditingController();
  final TextEditingController _adresaVrsacController = TextEditingController();

  // Time controllers — map based for days (pon, uto, sre, cet, pet)
  final Map<String, TextEditingController> _polazakBcControllers = {};
  final Map<String, TextEditingController> _polazakVsControllers = {};

  // Form data
  String _novoIme = '';
  String _noviTip = 'radnik';
  String _novaTipSkole = '';
  String _noviBrojTelefona = '';
  String _noviBrojTelefonaOca = '';
  String _noviBrojTelefonaMajke = '';
  String _novaAdresaBelaCrkva = '';
  String _novaAdresaVrsac = '';

  Map<String, bool> _noviRadniDani = {
    'pon': true,
    'uto': true,
    'sre': true,
    'cet': true,
    'pet': true,
  };

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resetForm();
    // Initialize per-day time controllers
    for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
      _polazakBcControllers[dan] = TextEditingController();
      _polazakVsControllers[dan] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _imeController.dispose();
    _tipSkoleController.dispose();
    _brojTelefonaController.dispose();
    _brojTelefonaOcaController.dispose();
    _brojTelefonaMajkeController.dispose();
    _adresaBelaCrkvaController.dispose();
    _adresaVrsacController.dispose();
    for (final c in _polazakBcControllers.values) {
      c.dispose();
    }
    for (final c in _polazakVsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _resetForm() {
    if (mounted) {
      setState(() {
        _novoIme = '';
        _noviTip = 'radnik';
        _novaTipSkole = '';
        _noviBrojTelefona = '';
        _noviBrojTelefonaOca = '';
        _noviBrojTelefonaMajke = '';
        _novaAdresaBelaCrkva = '';
        _novaAdresaVrsac = '';

        // Clear controllers
        _imeController.clear();
        _tipSkoleController.clear();
        _brojTelefonaController.clear();
        _brojTelefonaOcaController.clear();
        _brojTelefonaMajkeController.clear();
        _adresaBelaCrkvaController.clear();
        _adresaVrsacController.clear();

        // Clear time controllers (map-based)
        for (final c in _polazakBcControllers.values) {
          c.clear();
        }
        for (final c in _polazakVsControllers.values) {
          c.clear();
        }

        // Reset working days
        _noviRadniDani = {
          'pon': true,
          'uto': true,
          'sre': true,
          'cet': true,
          'pet': true,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SizedBox(
        height: screenSize.height * 0.9,
        width: screenSize.width * 0.9,
        child: Container(
          decoration: BoxDecoration(
            gradient: Theme.of(context).backgroundGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).glassBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _buildContent(),
              ),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).glassContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).glassBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '✨ Dodaj putnika',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 3,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              _resetForm();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildBasicInfoSection(),
          const SizedBox(height: 16),
          _buildContactSection(),
          const SizedBox(height: 16),
          _buildAddressSection(),
          const SizedBox(height: 16),
          _buildWorkingDaysSection(),
          const SizedBox(height: 16),
          _buildTimesSection(),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildGlassSection(
      title: '👤 Osnovne informacije',
      child: Column(
        children: [
          _buildTextField(
            controller: _imeController,
            label: 'Ime i prezime',
            icon: Icons.person,
            onChanged: (value) => setState(() => _novoIme = value),
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            value: _noviTip,
            label: 'Tip putnika',
            icon: Icons.category,
            // Standardized types: 'radnik' and 'ucenik'
            items: const ['radnik', 'ucenik'],
            onChanged: (value) => setState(() => _noviTip = value ?? 'radnik'),
          ),
          if (_noviTip == 'ucenik') ...[
            const SizedBox(height: 12),
            _buildTextField(
              controller: _tipSkoleController,
              label: _noviTip == 'ucenik' ? 'Škola' : 'Fakultet',
              icon: Icons.school,
              onChanged: (value) => setState(() => _novaTipSkole = value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return _buildGlassSection(
      title: '📱 Kontakt informacije',
      child: Column(
        children: [
          _buildTextField(
            controller: _brojTelefonaController,
            label: 'Broj telefona',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            onChanged: (value) => setState(() => _noviBrojTelefona = value),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _brojTelefonaOcaController,
            label: 'Broj telefona oca',
            icon: Icons.phone_android,
            keyboardType: TextInputType.phone,
            onChanged: (value) => setState(() => _noviBrojTelefonaOca = value),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _brojTelefonaMajkeController,
            label: 'Broj telefona majke',
            icon: Icons.phone_iphone,
            keyboardType: TextInputType.phone,
            onChanged: (value) => setState(() => _noviBrojTelefonaMajke = value),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return _buildGlassSection(
      title: '🏠 Adrese',
      child: Column(
        children: [
          _buildTextField(
            controller: _adresaBelaCrkvaController,
            label: 'Adresa Bela Crkva',
            icon: Icons.location_on,
            onChanged: (value) => setState(() => _novaAdresaBelaCrkva = value),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _adresaVrsacController,
            label: 'Adresa Vršac',
            icon: Icons.location_city,
            onChanged: (value) => setState(() => _novaAdresaVrsac = value),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingDaysSection() {
    return _buildGlassSection(
      title: '📅 Radni dani',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _noviRadniDani.entries.map((entry) {
          return GestureDetector(
            onTap: () {
              setState(() {
                _noviRadniDani[entry.key] = !entry.value;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: entry.value ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: entry.value ? Colors.green.withValues(alpha: 0.6) : Colors.grey.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                entry.key.toUpperCase(),
                style: TextStyle(
                  color: entry.value ? Colors.white : Colors.grey[400],
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimesSection() {
    return _buildGlassSection(
      title: '🕐 Vremena polaska',
      child: Column(
        children: [
          TimeRow(
            dayLabel: 'Ponedeljak',
            bcController: _polazakBcControllers['pon']!,
            vsController: _polazakVsControllers['pon']!,
          ),
          const SizedBox(height: 8),
          TimeRow(
            dayLabel: 'Utorak',
            bcController: _polazakBcControllers['uto']!,
            vsController: _polazakVsControllers['uto']!,
          ),
          const SizedBox(height: 8),
          TimeRow(
            dayLabel: 'Sreda',
            bcController: _polazakBcControllers['sre']!,
            vsController: _polazakVsControllers['sre']!,
          ),
          const SizedBox(height: 8),
          TimeRow(
            dayLabel: 'Četvrtak',
            bcController: _polazakBcControllers['cet']!,
            vsController: _polazakVsControllers['cet']!,
          ),
          const SizedBox(height: 8),
          TimeRow(
            dayLabel: 'Petak',
            bcController: _polazakBcControllers['pet']!,
            vsController: _polazakVsControllers['pet']!,
          ),
        ],
      ),
    );
  }

  // TimeRow has been migrated to shared widget `TimeRow` in lib/widgets/shared/time_row.dart

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).glassContainer,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).glassBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.4),
                ),
              ),
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        _resetForm();
                        Navigator.pop(context);
                      },
                child: const Text(
                  'Otkaži',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            flex: 2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveNewPassenger,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Dodaj',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSection({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).glassContainer,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Theme.of(context).glassBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? hint,
    TextInputType? keyboardType,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: Colors.white70, size: 20) : null,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
      ),
      dropdownColor: Colors.grey[800],
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: const TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  String _getRadniDaniString() {
    List<String> aktivniDani = [];
    _noviRadniDani.forEach((dan, aktivan) {
      if (aktivan) aktivniDani.add(dan);
    });
    return aktivniDani.join(',');
  }

  Map<String, List<String>> _getPolasciPoDanu() {
    final polasci = <String, List<String>>{};
    // Add BC / VS polasci for each day — normalize time and attach suffix
    void addBc(String key) {
      final val = _polazakBcControllers[key]?.text.trim() ?? '';
      if (val.isNotEmpty) {
        final norm = MesecniHelpers.normalizeTime(val) ?? val;
        polasci[key] = [...(polasci[key] ?? []), '$norm BC'];
      }
    }

    void addVs(String key) {
      final val = _polazakVsControllers[key]?.text.trim() ?? '';
      if (val.isNotEmpty) {
        final norm = MesecniHelpers.normalizeTime(val) ?? val;
        polasci[key] = [...(polasci[key] ?? []), '$norm VS'];
      }
    }

    for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
      addBc(dan);
      addVs(dan);
    }

    return polasci;
  }

  Future<void> _saveNewPassenger() async {
    if (_novoIme.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Ime je obavezno polje'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create addresses if provided
      String? adresaBelaCrkvaId;
      String? adresaVrsacId;

      if (_novaAdresaBelaCrkva.isNotEmpty) {
        final adresaBC = await AdresaSupabaseService.createOrGetAdresa(
          naziv: _novaAdresaBelaCrkva,
          grad: 'Bela Crkva',
        );
        adresaBelaCrkvaId = adresaBC?.id;
      }

      if (_novaAdresaVrsac.isNotEmpty) {
        final adresaVS = await AdresaSupabaseService.createOrGetAdresa(
          naziv: _novaAdresaVrsac,
          grad: 'Vršac',
        );
        adresaVrsacId = adresaVS?.id;
      }

      // Create new passenger
      final noviPutnik = MesecniPutnik(
        id: '', // Will be generated by database
        putnikIme: _novoIme.trim(),
        tip: _noviTip,
        tipSkole: _novaTipSkole.isEmpty ? null : _novaTipSkole,
        brojTelefona: _noviBrojTelefona.isEmpty ? null : _noviBrojTelefona,
        brojTelefonaOca: _noviBrojTelefonaOca.isEmpty ? null : _noviBrojTelefonaOca,
        brojTelefonaMajke: _noviBrojTelefonaMajke.isEmpty ? null : _noviBrojTelefonaMajke,
        polasciPoDanu: _getPolasciPoDanu(),
        adresaBelaCrkvaId: adresaBelaCrkvaId,
        adresaVrsacId: adresaVrsacId,
        radniDani: _getRadniDaniString(),
        datumPocetkaMeseca: DateTime(DateTime.now().year, DateTime.now().month),
        datumKrajaMeseca: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final dodatiPutnik = await _mesecniPutnikService.dodajMesecnogPutnika(noviPutnik);

      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Uspešno dodat putnik: ${dodatiPutnik.putnikIme}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Call callback
        widget.onAdded?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška pri dodavanju: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
