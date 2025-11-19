import 'package:flutter/material.dart';

import '../models/mesecni_putnik.dart';
import '../services/mesecni_putnik_service.dart';
import '../theme.dart';
import '../utils/mesecni_helpers.dart';

/// 🔧 WIDGET ZA EDITOVANJE MESEČNIH PUTNIKA
///
/// Izdvojen iz mesecni_putnici_screen.dart za bolju organizaciju koda.
/// Sadrži kompletnu logiku za editovanje mesečnog putnika sa:
/// - Osnovnim informacijama (ime, tip, škola)
/// - Kontakt podacima (telefoni)
/// - Adresama polaska
/// - Radnim danima i vremenima
/// - Responsivnim dizajnom (dialog/bottom sheet)
/// - Glassmorphism stilizovanjem
class EditMesecniPutnikDialog extends StatefulWidget {
  final MesecniPutnik putnik;
  final VoidCallback? onUpdated;

  const EditMesecniPutnikDialog({
    Key? key,
    required this.putnik,
    this.onUpdated,
  }) : super(key: key);

  @override
  State<EditMesecniPutnikDialog> createState() => _EditMesecniPutnikDialogState();
}

class _EditMesecniPutnikDialogState extends State<EditMesecniPutnikDialog> {
  // Services
  final MesecniPutnikService _mesecniPutnikService = MesecniPutnikService();

  // Form data
  late String _novoIme;
  late String _noviTip;
  late String _novaTipSkole;
  late String _noviBrojTelefona;
  String _novaAdresaBelaCrkva = '';
  String _novaAdresaVrsac = '';

  // Controllers
  late TextEditingController _imeController;
  late TextEditingController _tipSkoleController;
  late TextEditingController _brojTelefonaController;
  late TextEditingController _brojTelefonaOcaController;
  late TextEditingController _brojTelefonaMajkeController;
  late TextEditingController _adresaBelaCrkvaController;
  late TextEditingController _adresaVrsacController;

  // Time controllers for each day
  final Map<String, TextEditingController> _vremenaBcControllers = {};
  final Map<String, TextEditingController> _vremenaVsControllers = {};

  // Working days
  final Map<String, bool> _radniDani = {
    'pon': false,
    'uto': false,
    'sre': false,
    'cet': false,
    'pet': false,
  };

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadPutnikData();
  }

  void _initializeControllers() {
    _imeController = TextEditingController();
    _tipSkoleController = TextEditingController();
    _brojTelefonaController = TextEditingController();
    _brojTelefonaOcaController = TextEditingController();
    _brojTelefonaMajkeController = TextEditingController();
    _adresaBelaCrkvaController = TextEditingController();
    _adresaVrsacController = TextEditingController();

    // Initialize time controllers for each day
    for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
      _vremenaBcControllers[dan] = TextEditingController();
      _vremenaVsControllers[dan] = TextEditingController();
    }
  }

  void _loadPutnikData() {
    // Load basic info
    _novoIme = widget.putnik.putnikIme;
    _noviTip = widget.putnik.tip;
    _novaTipSkole = widget.putnik.tipSkole ?? '';
    _noviBrojTelefona = widget.putnik.brojTelefona ?? '';

    // Set controller values
    _imeController.text = _novoIme;
    _tipSkoleController.text = _novaTipSkole;
    _brojTelefonaController.text = _noviBrojTelefona;
    _adresaBelaCrkvaController.text = _novaAdresaBelaCrkva;
    _adresaVrsacController.text = _novaAdresaVrsac;

    // Load times for each day
    for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
      _vremenaBcControllers[dan]!.text = widget.putnik.getPolazakBelaCrkvaZaDan(dan) ?? '';
      _vremenaVsControllers[dan]!.text = widget.putnik.getPolazakVrsacZaDan(dan) ?? '';
    }

    // Load working days
    _setRadniDaniFromString(widget.putnik.radniDani);

    // Load addresses asynchronously
    _loadAdreseForEditovanje();
  }

  void _setRadniDaniFromString(String? radniDaniStr) {
    if (radniDaniStr == null || radniDaniStr.isEmpty) return;

    final dani = radniDaniStr.split(',');
    for (final dan in dani) {
      final cleanDan = dan.trim().toLowerCase();
      if (_radniDani.containsKey(cleanDan)) {
        _radniDani[cleanDan] = true;
      }
    }
  }

  String _getRadniDaniString() {
    final aktivniDani = _radniDani.entries.where((entry) => entry.value).map((entry) => entry.key).toList();
    return aktivniDani.join(',');
  }

  Future<void> _loadAdreseForEditovanje() async {
    // Address loading will be handled by the original screen logic
    // For now, we'll use empty strings as defaults
    if (mounted) {
      setState(() {
        _novaAdresaBelaCrkva = '';
        _novaAdresaVrsac = '';
        _adresaBelaCrkvaController.text = _novaAdresaBelaCrkva;
        _adresaVrsacController.text = _novaAdresaVrsac;
      });
    }
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

  TextEditingController _getControllerBelaCrkva(String dan) {
    switch (dan) {
      case 'pon':
        return _vremenaBcControllers['pon']!;
      case 'uto':
        return _vremenaBcControllers['uto']!;
      case 'sre':
        return _vremenaBcControllers['sre']!;
      case 'cet':
        return _vremenaBcControllers['cet']!;
      case 'pet':
        return _vremenaBcControllers['pet']!;
      default:
        return TextEditingController();
    }
  }

  TextEditingController _getControllerVrsac(String dan) {
    switch (dan) {
      case 'pon':
        return _vremenaVsControllers['pon']!;
      case 'uto':
        return _vremenaVsControllers['uto']!;
      case 'sre':
        return _vremenaVsControllers['sre']!;
      case 'cet':
        return _vremenaVsControllers['cet']!;
      case 'pet':
        return _vremenaVsControllers['pet']!;
      default:
        return TextEditingController();
    }
  }

  Widget _buildRadniDanCheckbox(String dan, String label) {
    return CheckboxListTile(
      title: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      value: _radniDani[dan],
      onChanged: (bool? value) {
        setState(() {
          _radniDani[dan] = value ?? false;
        });
      },
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      contentPadding: EdgeInsets.zero,
      checkColor: Colors.white,
      activeColor: Colors.green,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
    );
  }

  Widget _buildVremenaPolaskaSekcija() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vremena polaska po danima:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        ...['pon', 'uto', 'sre', 'cet', 'pet'].map((dan) {
          final label = {
            'pon': 'Ponedeljak',
            'uto': 'Utorak',
            'sre': 'Sreda',
            'cet': 'Četvrtak',
            'pet': 'Petak',
          }[dan]!;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _getControllerBelaCrkva(dan),
                    decoration: InputDecoration(
                      hintText: 'BC vreme',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      filled: true,
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _getControllerVrsac(dan),
                    decoration: InputDecoration(
                      hintText: 'VS vreme',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      filled: true,
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _sacuvajEditPutnika() async {
    // Validacija formulara
    final validationError = _validateForm();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Koristi vrednosti iz controller-a
    final ime = _imeController.text.trim();
    final tipSkole = _tipSkoleController.text.trim();
    final brojTelefona = _brojTelefonaController.text.trim();

    try {
      // Pripremi mapu polazaka po danima (JSON)
      final Map<String, List<String>> polasciPoDanu = {};
      for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
        final bcRaw = _getControllerBelaCrkva(dan).text.trim();
        final vsRaw = _getControllerVrsac(dan).text.trim();
        final bc = bcRaw.isNotEmpty ? (MesecniHelpers.normalizeTime(bcRaw) ?? '') : '';
        final vs = vsRaw.isNotEmpty ? (MesecniHelpers.normalizeTime(vsRaw) ?? '') : '';
        final List<String> polasci = [];
        if (bc.isNotEmpty) polasci.add('$bc BC');
        if (vs.isNotEmpty) polasci.add('$vs VS');
        if (polasci.isNotEmpty) polasciPoDanu[dan] = polasci;
      }

      final editovanPutnik = widget.putnik.copyWith(
        putnikIme: ime,
        tip: _noviTip,
        tipSkole: tipSkole.isEmpty ? null : tipSkole,
        brojTelefona: brojTelefona.isEmpty ? null : brojTelefona,
        polasciPoDanu: polasciPoDanu,
        radniDani: _getRadniDaniString(),
      );

      final updated = await _mesecniPutnikService.azurirajMesecnogPutnika(editovanPutnik);

      if (updated == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Greška pri ažuriranju u bazi. Pokušajte ponovo.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Kreiraj dnevne putovanja za danas
      try {
        await _mesecniPutnikService.kreirajDnevnaPutovanjaIzMesecnih(
          editovanPutnik,
          DateTime.now().add(const Duration(days: 1)),
        );
      } catch (_) {}

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesečni putnik je uspešno ažuriran'),
            backgroundColor: Colors.green,
          ),
        );
        // Call callback to refresh parent screen
        widget.onUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri čuvanju: $e'),
            backgroundColor: Colors.red,
          ),
        );
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

    for (final controller in _vremenaBcControllers.values) {
      controller.dispose();
    }
    for (final controller in _vremenaVsControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isSmallScreen = mq.size.height < 700 || mq.size.width < 600;

    Widget dialogContent = Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
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
            // Header
            Container(
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
                  Icon(Icons.edit, color: Colors.white70, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Uredi mesečnog putnika',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOsnovneInformacije(),
                    _buildKontaktInformacije(),
                    _buildAdresePolaska(),
                    _buildRadniDaniIVremena(),
                  ],
                ),
              ),
            ),
            // Footer Actions
            Container(
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
                        onPressed: () => Navigator.pop(context),
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
                  Expanded(
                    flex: 2,
                    child: Container(
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
                      child: ElevatedButton.icon(
                        onPressed: _sacuvajEditPutnika,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        icon: Icon(Icons.save, size: 18, color: Colors.white),
                        label: Text(
                          'Sačuvaj',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isSmallScreen) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(child: dialogContent),
          ),
        ),
      );
    } else {
      return dialogContent;
    }
  }

  Widget _buildOsnovneInformacije() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).glassContainer,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Theme.of(context).glassBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📋 Osnovne informacije',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
              shadows: [
                Shadow(
                  offset: const Offset(1, 1),
                  blurRadius: 3,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (value) => _novoIme = value,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: '👤 Ime putnika *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white70,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: Icon(
                Icons.person,
                color: Colors.white70,
              ),
              fillColor: Colors.white.withValues(alpha: 0.1),
              filled: true,
              labelStyle: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            controller: _imeController,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _noviTip,
            decoration: InputDecoration(
              labelText: 'Tip putnika',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _noviTip == 'ucenik' ? Icons.school : Icons.business,
                  key: ValueKey('${_noviTip}_dropdown'),
                  color: Colors.white70,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white70,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              fillColor: Colors.white.withValues(alpha: 0.1),
              filled: true,
            ),
            items: const [
              DropdownMenuItem(
                value: 'radnik',
                child: Row(
                  children: [
                    Icon(
                      Icons.business,
                      color: Colors.white70,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Radnik',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'ucenik',
                child: Row(
                  children: [
                    Icon(
                      Icons.school,
                      color: Colors.white70,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Učenik',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onChanged: (value) {
              if (mounted) setState(() => _noviTip = value!);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => _novaTipSkole = value,
            decoration: InputDecoration(
              labelText: _noviTip == 'ucenik' ? '🎓 Škola' : '🏢 Ustanova/Firma',
              hintText: _noviTip == 'ucenik' ? 'npr. Gimnazija "Bora Stanković"' : 'npr. Hemofarm, Opština Vršac...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white70,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _noviTip == 'ucenik' ? Icons.school : Icons.business,
                  key: ValueKey(_noviTip),
                  color: Colors.white70,
                ),
              ),
              fillColor: Colors.white.withValues(alpha: 0.1),
              filled: true,
              labelStyle: TextStyle(color: Colors.white70, fontSize: 14),
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
            ),
            controller: _tipSkoleController,
          ),
        ],
      ),
    );
  }

  Widget _buildKontaktInformacije() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).glassContainer,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Theme.of(context).glassBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📞 Kontakt informacije',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
              shadows: [
                Shadow(
                  offset: const Offset(1, 1),
                  blurRadius: 3,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: _noviTip == 'ucenik' ? '📱 Broj telefona učenika' : '📞 Broj telefona',
              hintText: '064/123-456',
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: Icon(Icons.phone, color: Colors.white70),
              fillColor: Colors.white.withValues(alpha: 0.1),
              filled: true,
            ),
            keyboardType: TextInputType.phone,
            controller: _brojTelefonaController,
          ),
          // Parent contacts section for students
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _noviTip == 'ucenik'
                ? Container(
                    key: const ValueKey('parent_contacts_edit'),
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).glassContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).glassBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
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
                                    ),
                                  ),
                                  Text(
                                    'Za hitne situacije',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Broj telefona oca',
                            hintText: '064/123-456',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.man, color: Colors.blue),
                            fillColor: Colors.white,
                            filled: true,
                          ),
                          keyboardType: TextInputType.phone,
                          controller: _brojTelefonaOcaController,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Broj telefona majke',
                            hintText: '065/789-012',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.woman, color: Colors.pink),
                            fillColor: Colors.white,
                            filled: true,
                          ),
                          keyboardType: TextInputType.phone,
                          controller: _brojTelefonaMajkeController,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdresePolaska() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).glassContainer,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Theme.of(context).glassBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📍 Adrese polaska',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
              shadows: [
                Shadow(
                  offset: const Offset(1, 1),
                  blurRadius: 3,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (value) => _novaAdresaBelaCrkva = value,
            decoration: InputDecoration(
              labelText: '🏠 Adresa polaska - Bela Crkva',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: Icon(Icons.home, color: Colors.white70),
              fillColor: Colors.white.withValues(alpha: 0.1),
              filled: true,
              labelStyle: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            style: TextStyle(color: Colors.white),
            controller: _adresaBelaCrkvaController,
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => _novaAdresaVrsac = value,
            decoration: InputDecoration(
              labelText: '🏢 Adresa polaska - Vršac',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: Icon(Icons.business, color: Colors.white70),
              fillColor: Colors.white.withValues(alpha: 0.1),
              filled: true,
              labelStyle: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            style: TextStyle(color: Colors.white),
            controller: _adresaVrsacController,
          ),
        ],
      ),
    );
  }

  Widget _buildRadniDaniIVremena() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).glassContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).glassBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📅 Radni dani i vremena',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Odaberi radne dane kada putnik koristi prevoz:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildRadniDanCheckbox('pon', 'Ponedeljak')),
                  Expanded(child: _buildRadniDanCheckbox('uto', 'Utorak')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildRadniDanCheckbox('sre', 'Sreda')),
                  Expanded(child: _buildRadniDanCheckbox('cet', 'Četvrtak')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildRadniDanCheckbox('pet', 'Petak')),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildVremenaPolaskaSekcija(),
        ],
      ),
    );
  }
}
