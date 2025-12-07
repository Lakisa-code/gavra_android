import 'package:flutter/material.dart';

import '../models/mesecni_putnik.dart';
import '../services/adresa_supabase_service.dart';
import '../services/mesecni_putnik_service.dart';
import '../theme.dart';
import '../utils/mesecni_helpers.dart';
import '../widgets/shared/time_row.dart';
import 'adresa_widgets.dart';

/// 🆕🔧 UNIFIKOVANI WIDGET ZA DODAVANJE I EDITOVANJE MESEČNIH PUTNIKA
///
/// Kombinuje funkcionalnost iz add_mesecni_putnik_dialog.dart i edit_mesecni_putnik_dialog.dart
/// u jedan optimizovan widget koji radi i za dodavanje i za editovanje.
///
/// Parametri:
/// - existingPutnik: null za dodavanje, postojeći objekat za editovanje
/// - onSaved: callback koji se poziva posle uspešnog čuvanja
class MesecniPutnikDialog extends StatefulWidget {
  final MesecniPutnik? existingPutnik; // null = dodavanje, !null = editovanje
  final VoidCallback? onSaved;

  const MesecniPutnikDialog({
    super.key,
    this.existingPutnik,
    this.onSaved,
  });

  /// Da li je dialog u edit modu
  bool get isEditing => existingPutnik != null;

  @override
  State<MesecniPutnikDialog> createState() => _MesecniPutnikDialogState();
}

class _MesecniPutnikDialogState extends State<MesecniPutnikDialog> {
  final MesecniPutnikService _mesecniPutnikService = MesecniPutnikService();

  // Form controllers
  final TextEditingController _imeController = TextEditingController();
  final TextEditingController _tipSkoleController = TextEditingController();
  final TextEditingController _brojTelefonaController = TextEditingController();
  final TextEditingController _brojTelefonaOcaController = TextEditingController();
  final TextEditingController _brojTelefonaMajkeController = TextEditingController();
  final TextEditingController _adresaBelaCrkvaController = TextEditingController();
  final TextEditingController _adresaVrsacController = TextEditingController();
  // Selected address UUIDs (keeps track when user chooses a suggestion)
  String? _adresaBelaCrkvaId;
  String? _adresaVrsacId;

  // Time controllers — map based for days (pon, uto, sre, cet, pet)
  final Map<String, TextEditingController> _polazakBcControllers = {};
  final Map<String, TextEditingController> _polazakVsControllers = {};

  // Form data
  String _tip = 'radnik';
  Map<String, bool> _radniDani = {
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
    _initializeControllers();
    _loadDataFromExistingPutnik();
  }

  void _initializeControllers() {
    // Initialize per-day time controllers
    for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
      _polazakBcControllers[dan] = TextEditingController();
      _polazakVsControllers[dan] = TextEditingController();
    }
  }

  void _loadDataFromExistingPutnik() {
    if (widget.isEditing) {
      final putnik = widget.existingPutnik!;

      // Load basic info
      _imeController.text = putnik.putnikIme;
      _tip = putnik.tip;
      _tipSkoleController.text = putnik.tipSkole ?? '';
      _brojTelefonaController.text = putnik.brojTelefona ?? '';
      _brojTelefonaOcaController.text = putnik.brojTelefonaOca ?? '';
      _brojTelefonaMajkeController.text = putnik.brojTelefonaMajke ?? '';

      // Load times for each day
      for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
        _polazakBcControllers[dan]!.text = putnik.getPolazakBelaCrkvaZaDan(dan) ?? '';
        _polazakVsControllers[dan]!.text = putnik.getPolazakVrsacZaDan(dan) ?? '';
      }

      // Load working days
      _setRadniDaniFromString(putnik.radniDani);

      // Load addresses asynchronously
      _loadAdreseForEditovanje();
    }
  }

  void _setRadniDaniFromString(String? radniDaniStr) {
    if (radniDaniStr == null || radniDaniStr.isEmpty) return;

    // Reset all days to false first
    _radniDani = {
      'pon': false,
      'uto': false,
      'sre': false,
      'cet': false,
      'pet': false,
    };

    final dani = radniDaniStr.split(',');
    for (final dan in dani) {
      final cleanDan = dan.trim().toLowerCase();
      if (_radniDani.containsKey(cleanDan)) {
        _radniDani[cleanDan] = true;
      }
    }
  }

  Future<void> _loadAdreseForEditovanje() async {
    // Load existing address names for the edit dialog using the UUIDs
    final putnik = widget.existingPutnik;
    if (putnik == null) return;

    // Try batch fetch for both ids (faster & respects cache)
    try {
      final idsToFetch = <String>[];
      if (putnik.adresaBelaCrkvaId != null && putnik.adresaBelaCrkvaId!.isNotEmpty) {
        idsToFetch.add(putnik.adresaBelaCrkvaId!);
      }
      if (putnik.adresaVrsacId != null && putnik.adresaVrsacId!.isNotEmpty) {
        idsToFetch.add(putnik.adresaVrsacId!);
      }

      if (idsToFetch.isNotEmpty) {
        final fetched = await AdresaSupabaseService.getAdreseByUuids(idsToFetch);

        final bcNaziv = putnik.adresaBelaCrkvaId != null
            ? fetched[putnik.adresaBelaCrkvaId!]?.naziv ??
                await AdresaSupabaseService.getNazivAdreseByUuid(putnik.adresaBelaCrkvaId)
            : null;

        final vsNaziv = putnik.adresaVrsacId != null
            ? fetched[putnik.adresaVrsacId!]?.naziv ??
                await AdresaSupabaseService.getNazivAdreseByUuid(putnik.adresaVrsacId)
            : null;

        if (mounted) {
          setState(() {
            _adresaBelaCrkvaController.text = bcNaziv ?? '';
            _adresaVrsacController.text = vsNaziv ?? '';
            // keep UUIDs so autocomplete selection is preserved
            _adresaBelaCrkvaId = putnik.adresaBelaCrkvaId;
            _adresaVrsacId = putnik.adresaVrsacId;
          });
        }
      } else {
        // No UUIDs present → leave controllers empty
        if (mounted) {
          setState(() {
            _adresaBelaCrkvaController.text = '';
            _adresaVrsacController.text = '';
            _adresaBelaCrkvaId = null;
            _adresaVrsacId = null;
          });
        }
      }
    } catch (e) {
      // In case of any error, keep empty strings but don't crash the dialog
      if (mounted) {
        setState(() {
          _adresaBelaCrkvaController.text = '';
          _adresaVrsacController.text = '';
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: _buildContent(),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = widget.isEditing ? '🔧 Uredi putnika' : '✨ Dodaj putnika';

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
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
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
            onTap: () => Navigator.pop(context),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfoSection(),
          const SizedBox(height: 20),
          _buildContactSection(),
          const SizedBox(height: 20),
          _buildAddressSection(),
          const SizedBox(height: 20),
          _buildTimesSection(),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildGlassSection(
      title: 'Osnovne informacije',
      child: Column(
        children: [
          _buildTextField(
            controller: _imeController,
            label: 'Ime i prezime',
            icon: Icons.person,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ime je obavezno polje';
              }
              if (value.trim().length < 2) {
                return 'Ime mora imati najmanje 2 karaktera';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          _buildDropdown(
            value: _tip,
            label: 'Tip putnika',
            icon: Icons.category,
            items: const ['radnik', 'ucenik'],
            onChanged: (value) => setState(() => _tip = value ?? 'radnik'),
          ),
          if (_tip == 'ucenik') ...[
            const SizedBox(height: 24),
            _buildTextField(
              controller: _tipSkoleController,
              label: 'Škola',
              icon: Icons.school,
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
            label: _tip == 'ucenik' ? 'Broj telefona učenika' : 'Broj telefona',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
          ),
          if (_tip == 'ucenik') ...[
            const SizedBox(height: 16),
            // Glassmorphism container za roditeljske kontakte
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.family_restroom,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kontakt podaci roditelja',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 14,
                                shadows: [
                                  Shadow(
                                    offset: const Offset(1, 1),
                                    blurRadius: 3,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _brojTelefonaOcaController,
                    label: 'Broj telefona oca',
                    icon: Icons.man,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _brojTelefonaMajkeController,
                    label: 'Broj telefona majke',
                    icon: Icons.woman,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return _buildGlassSection(
      title: '🏠 Adrese',
      child: Column(
        children: [
          AdresaAutocompleteWidget(
            grad: 'Bela Crkva',
            controller: _adresaBelaCrkvaController,
            initialValue: _adresaBelaCrkvaController.text.isNotEmpty ? _adresaBelaCrkvaController.text : null,
            label: 'Adresa Bela Crkva',
            prefixIcon: const Icon(Icons.location_on),
            onChanged: (id, naziv) {
              setState(() {
                _adresaBelaCrkvaId = id;
                // if user selected a suggestion the controller already has naziv
                // if user typed free text, id will be null until saved/created
              });
            },
          ),
          const SizedBox(height: 12),
          AdresaAutocompleteWidget(
            grad: 'Vršac',
            controller: _adresaVrsacController,
            initialValue: _adresaVrsacController.text.isNotEmpty ? _adresaVrsacController.text : null,
            label: 'Adresa Vršac',
            prefixIcon: const Icon(Icons.location_city),
            onChanged: (id, naziv) {
              setState(() {
                _adresaVrsacId = id;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimesSection() {
    return _buildGlassSection(
      title: '🕐 Vremena polaska',
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()), // Placeholder for day label
              Expanded(
                flex: 2,
                child: Text(
                  'BC',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: Text(
                  'VS',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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
            ],
          ),
          const SizedBox(height: 8),
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

  Widget _buildActions() {
    final buttonText = widget.isEditing ? 'Sačuvaj' : 'Dodaj';
    final buttonIcon = widget.isEditing ? Icons.save : Icons.add_circle;

    return Container(
      width: double.infinity,
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
          // Cancel button
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
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: const Text(
                  'Otkaži',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
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
            ),
          ),
          const SizedBox(width: 15),
          // Save/Add button
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
                onPressed: _isLoading ? null : _savePutnik,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isLoading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: const BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black54,
                                  offset: Offset(1, 1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: Text(
                              widget.isEditing ? 'Čuva...' : 'Dodaje...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            buttonIcon,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            buttonText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              shadows: [
                                Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 3,
                                  color: Colors.black54,
                                ),
                              ],
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
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 3,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black87),
      validator: validator,
      decoration: InputDecoration(
        hintText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        prefixIcon: icon != null ? Icon(icon, color: Colors.blue, size: 20) : null,
        fillColor: Colors.white.withValues(alpha: 0.9),
        filled: true,
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
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        hintText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        prefixIcon: Icon(icon, color: Colors.blue, size: 20),
        fillColor: Colors.white.withValues(alpha: 0.9),
        filled: true,
      ),
      dropdownColor: Theme.of(context).colorScheme.surface,
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: const TextStyle(color: Colors.black87),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  String _getRadniDaniString() {
    List<String> aktivniDani = [];
    _radniDani.forEach((dan, aktivan) {
      if (aktivan) aktivniDani.add(dan);
    });
    return aktivniDani.join(',');
  }

  Map<String, List<String>> _getPolasciPoDanu() {
    final polasci = <String, List<String>>{};

    for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
      final bcRaw = _polazakBcControllers[dan]?.text.trim() ?? '';
      final vsRaw = _polazakVsControllers[dan]?.text.trim() ?? '';

      final List<String> danPolasci = [];

      if (bcRaw.isNotEmpty) {
        final norm = MesecniHelpers.normalizeTime(bcRaw) ?? bcRaw;
        danPolasci.add('$norm BC');
      }

      if (vsRaw.isNotEmpty) {
        final norm = MesecniHelpers.normalizeTime(vsRaw) ?? vsRaw;
        danPolasci.add('$norm VS');
      }

      if (danPolasci.isNotEmpty) {
        polasci[dan] = danPolasci;
      }
    }

    return polasci;
  }

  /// Vraća polasci_po_danu u formatu koji baza očekuje: {dan: {bc: time, vs: time}}
  Map<String, Map<String, String?>> _getPolasciPoDanuMap() {
    final Map<String, Map<String, String?>> normalizedPolasci = {};

    for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
      final bcRaw = _polazakBcControllers[dan]?.text.trim() ?? '';
      final vsRaw = _polazakVsControllers[dan]?.text.trim() ?? '';

      final bc = bcRaw.isNotEmpty ? MesecniHelpers.normalizeTime(bcRaw) : null;
      final vs = vsRaw.isNotEmpty ? MesecniHelpers.normalizeTime(vsRaw) : null;

      normalizedPolasci[dan] = {'bc': bc, 'vs': vs};
    }

    return normalizedPolasci;
  }

  String? _validateForm() {
    final ime = _imeController.text.trim();
    if (ime.isEmpty) {
      return 'Ime putnika je obavezno';
    }
    if (ime.length < 2) {
      return 'Ime putnika mora imati najmanje 2 karaktera';
    }
    return null;
  }

  Future<void> _savePutnik() async {
    print('🔵 _savePutnik() started');
    final validationError = _validateForm();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $validationError'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('🔵 isEditing: ${widget.isEditing}');
      if (widget.isEditing) {
        await _updateExistingPutnik();
      } else {
        await _createNewPutnik();
      }
    } catch (e, stack) {
      print('❌ _savePutnik error: $e');
      print('❌ _savePutnik stack: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška: $e'),
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

  Future<void> _createNewPutnik() async {
    print('🟢 _createNewPutnik() started');
    // Resolve addresses:
    // Prefer UUIDs selected via autocomplete (_adresa*Id). If no UUID but text exists, create or find address.
    String? adresaBelaCrkvaId = _adresaBelaCrkvaId;
    String? adresaVrsacId = _adresaVrsacId;

    print('🟢 _adresaBelaCrkvaId: $_adresaBelaCrkvaId');
    print('🟢 _adresaBelaCrkvaController.text: "${_adresaBelaCrkvaController.text}"');

    if (adresaBelaCrkvaId == null && _adresaBelaCrkvaController.text.isNotEmpty) {
      print('🟢 Creating/getting address for Bela Crkva...');
      final adresaBC = await AdresaSupabaseService.createOrGetAdresa(
        naziv: _adresaBelaCrkvaController.text.trim(),
        grad: 'Bela Crkva',
      );
      print('🟢 adresaBC: $adresaBC, id: ${adresaBC?.id}');
      adresaBelaCrkvaId = adresaBC?.id;
    }

    if (adresaVrsacId == null && _adresaVrsacController.text.isNotEmpty) {
      final adresaVS = await AdresaSupabaseService.createOrGetAdresa(
        naziv: _adresaVrsacController.text.trim(),
        grad: 'Vršac',
      );
      adresaVrsacId = adresaVS?.id;
    }

    // Create new passenger
    final noviPutnik = MesecniPutnik(
      id: '', // Will be generated by database
      putnikIme: _imeController.text.trim(),
      tip: _tip,
      tipSkole: _tipSkoleController.text.isEmpty ? null : _tipSkoleController.text.trim(),
      brojTelefona: _brojTelefonaController.text.isEmpty ? null : _brojTelefonaController.text.trim(),
      brojTelefonaOca: _brojTelefonaOcaController.text.isEmpty ? null : _brojTelefonaOcaController.text.trim(),
      brojTelefonaMajke: _brojTelefonaMajkeController.text.isEmpty ? null : _brojTelefonaMajkeController.text.trim(),
      polasciPoDanu: _getPolasciPoDanu(),
      adresaBelaCrkvaId: adresaBelaCrkvaId,
      adresaVrsacId: adresaVrsacId,
      radniDani: _getRadniDaniString(),
      datumPocetkaMeseca: DateTime(DateTime.now().year, DateTime.now().month),
      datumKrajaMeseca: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: 'radi', // Dozvoljeni: radi, bolovanje, godisnji, odsustvo, otkazan
    );

    print('🟢 noviPutnik.status: ${noviPutnik.status}');
    print('🟢 noviPutnik.toMap(): ${noviPutnik.toMap()}');
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
      widget.onSaved?.call();
    }
  }

  Future<void> _updateExistingPutnik() async {
    // Resolve address UUIDs:
    // - Ako je _adresaBelaCrkvaId postavljen (korisnik je izabrao iz autocomplete) -> koristi taj ID
    // - Ako je null ali ima teksta u polju -> korisnik je ručno uneo/promenio adresu, kreiraj novu
    // - Ako je polje prazno -> postavi null
    String? adresaBelaCrkvaId;
    String? adresaVrsacId;

    // Adresa Bela Crkva
    if (_adresaBelaCrkvaController.text.isEmpty) {
      adresaBelaCrkvaId = null;
    } else if (_adresaBelaCrkvaId != null) {
      // Korisnik je izabrao adresu iz autocomplete-a
      adresaBelaCrkvaId = _adresaBelaCrkvaId;
    } else {
      // Korisnik je ručno uneo tekst, kreiraj ili pronađi adresu
      final adresaBC = await AdresaSupabaseService.createOrGetAdresa(
        naziv: _adresaBelaCrkvaController.text.trim(),
        grad: 'Bela Crkva',
      );
      adresaBelaCrkvaId = adresaBC?.id;
    }

    // Adresa Vršac
    if (_adresaVrsacController.text.isEmpty) {
      adresaVrsacId = null;
    } else if (_adresaVrsacId != null) {
      // Korisnik je izabrao adresu iz autocomplete-a
      adresaVrsacId = _adresaVrsacId;
    } else {
      // Korisnik je ručno uneo tekst, kreiraj ili pronađi adresu
      final adresaVS = await AdresaSupabaseService.createOrGetAdresa(
        naziv: _adresaVrsacController.text.trim(),
        grad: 'Vršac',
      );
      adresaVrsacId = adresaVS?.id;
    }

    // 🔧 DIREKTNO KREIRAJ MAPU ZA UPDATE - zaobilazi copyWith problem sa null vrednostima
    final updateMap = <String, dynamic>{
      'putnik_ime': _imeController.text.trim(),
      'tip': _tip,
      'tip_skole': _tipSkoleController.text.isEmpty ? null : _tipSkoleController.text.trim(),
      'broj_telefona': _brojTelefonaController.text.isEmpty ? null : _brojTelefonaController.text.trim(),
      'broj_telefona_oca': _brojTelefonaOcaController.text.isEmpty ? null : _brojTelefonaOcaController.text.trim(),
      'broj_telefona_majke':
          _brojTelefonaMajkeController.text.isEmpty ? null : _brojTelefonaMajkeController.text.trim(),
      'polasci_po_danu': _getPolasciPoDanuMap(),
      'radni_dani': _getRadniDaniString(),
      // ✅ KLJUČNO: Eksplicitno postavi adrese (uključujući null za brisanje)
      'adresa_bela_crkva_id': adresaBelaCrkvaId,
      'adresa_vrsac_id': adresaVrsacId,
    };

    try {
      final updated = await _mesecniPutnikService.updateMesecniPutnik(
        widget.existingPutnik!.id,
        updateMap,
      );

      // Create daily travels for updated passenger
      try {
        await _mesecniPutnikService.kreirajDnevnaPutovanjaIzMesecnih(
          updated,
          DateTime.now().add(const Duration(days: 1)),
        );
      } catch (_) {
        // Ignore errors in daily travel creation
      }

      // ✅ Očisti cache (refresh se dešava kroz ValueKey u parent screen-u)
      MesecniPutnikService.clearCache();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Mesečni putnik je uspešno ažuriran'),
            backgroundColor: Colors.green,
          ),
        );

        // Call callback to refresh parent screen
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri ažuriranju u bazi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
