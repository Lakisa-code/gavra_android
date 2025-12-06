/// ⚔️ BINARYBITCH: Widget za nedeljno zakazivanje vožnji
/// Konzistentan sa "Dodaj putnika" i "Uredi putnika" dialogom
/// Koristi isti stil: toggle za dane + BC/VS time picker grid

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/route_config.dart';

class NedeljaZakazivanjeWidget extends StatefulWidget {
  final String putnikId;
  final String putnikIme;
  final VoidCallback? onSaved;

  const NedeljaZakazivanjeWidget({
    super.key,
    required this.putnikId,
    required this.putnikIme,
    this.onSaved,
  });

  @override
  State<NedeljaZakazivanjeWidget> createState() => _NedeljaZakazivanjeWidgetState();
}

class _NedeljaZakazivanjeWidgetState extends State<NedeljaZakazivanjeWidget> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isSaving = false;

  // Toggle za radne dane
  final Map<String, bool> _radniDani = {
    'pon': true,
    'uto': true,
    'sre': true,
    'cet': true,
    'pet': true,
  };

  // Vremena po danima
  final Map<String, String?> _vremeBc = {};
  final Map<String, String?> _vremeVs = {};

  final _daniLabels = {
    'pon': 'Ponedeljak',
    'uto': 'Utorak',
    'sre': 'Sreda',
    'cet': 'Četvrtak',
    'pet': 'Petak',
  };

  @override
  void initState() {
    super.initState();
    _loadPostojeciPolasci();
  }

  Future<void> _loadPostojeciPolasci() async {
    setState(() => _isLoading = true);

    try {
      // Dohvati putnika iz baze da učitamo postojeće polasci_po_danu
      final response =
          await _supabase.from('mesecni_putnici').select('polasci_po_danu').eq('id', widget.putnikId).maybeSingle();

      if (response != null && response['polasci_po_danu'] != null) {
        final polasciRaw = response['polasci_po_danu'];
        if (polasciRaw is Map) {
          final dani = ['pon', 'uto', 'sre', 'cet', 'pet'];
          for (final dan in dani) {
            final danPolasci = polasciRaw[dan];
            if (danPolasci is Map) {
              final bc = danPolasci['bc']?.toString();
              final vs = danPolasci['vs']?.toString();

              // Ako ima bar jedno vreme, dan je radni
              if ((bc != null && bc.isNotEmpty) || (vs != null && vs.isNotEmpty)) {
                _radniDani[dan] = true;
                _vremeBc[dan] = bc;
                _vremeVs[dan] = vs;
              } else {
                _radniDani[dan] = false;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Greška pri učitavanju polazaka: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _sacuvajRaspored() async {
    setState(() => _isSaving = true);

    try {
      final dani = ['pon', 'uto', 'sre', 'cet', 'pet'];

      // Kreiraj polasci_po_danu mapu
      final Map<String, Map<String, String?>> polasciPoDanu = {};

      for (final dan in dani) {
        final jeRadniDan = _radniDani[dan] ?? false;
        polasciPoDanu[dan] = {
          'bc': jeRadniDan ? _vremeBc[dan] : null,
          'vs': jeRadniDan ? _vremeVs[dan] : null,
        };
      }

      // Sačuvaj u mesecni_putnici tabelu
      await _supabase.from('mesecni_putnici').update({'polasci_po_danu': polasciPoDanu}).eq('id', widget.putnikId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Vremena polazaka sačuvana!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSaved?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 650, maxWidth: 400),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade800,
            Colors.indigo.shade900,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(),

          // Content
          Flexible(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Nedelja info
                        _buildNedeljaInfo(),
                        const SizedBox(height: 16),

                        // Vremena polaska grid - GLAVNI DEO kao u "Dodaj putnika"
                        _buildVremenaPolaskaSection(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
          ),

          // Footer buttons
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Text('📅', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Zakaži vožnje',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.putnikIme,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildNedeljaInfo() {
    final pocetakStr = '${_pocetakNedelje.day}.${_pocetakNedelje.month}.';
    final krajNedelje = _pocetakNedelje.add(const Duration(days: 4));
    final krajStr = '${krajNedelje.day}.${krajNedelje.month}.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () {
              setState(() {
                _pocetakNedelje = _pocetakNedelje.subtract(const Duration(days: 7));
                _vremeBc.clear();
                _vremeVs.clear();
                _radniDani.updateAll((key, value) => true);
              });
              _loadPostojeceZakazivanje();
            },
          ),
          Expanded(
            child: Text(
              'Nedelja: $pocetakStr - $krajStr',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () {
              setState(() {
                _pocetakNedelje = _pocetakNedelje.add(const Duration(days: 7));
                _vremeBc.clear();
                _vremeVs.clear();
                _radniDani.updateAll((key, value) => true);
              });
              _loadPostojeceZakazivanje();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVremenaPolaskaSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.13),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.schedule, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                '🕐 Vremena polaska',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Header row - BC / VS labels
          Row(
            children: [
              const SizedBox(width: 115),
              Expanded(
                child: Center(
                  child: Text(
                    'BC',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Time rows for each day - ISTI STIL kao "Dodaj putnika"
          ...['pon', 'uto', 'sre', 'cet', 'pet'].map((dan) {
            return _buildTimeInputRow(dan);
          }),
        ],
      ),
    );
  }

  Widget _buildTimeInputRow(String dan) {
    final isActive = _radniDani[dan] ?? true;
    final label = _daniLabels[dan] ?? dan;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          // First row: toggle + day name
          Row(
            children: [
              // Toggle icon
              GestureDetector(
                onTap: () {
                  setState(() {
                    _radniDani[dan] = !isActive;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isActive ? Icons.check : Icons.close,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Day name
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (!isActive)
                Text(
                  '(neradni dan)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),

          // Second row: BC and VS time pickers (only if active)
          if (isActive) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 30), // offset for toggle
                // BC Time picker
                Expanded(
                  child: _buildTimePickerField(
                    dan: dan,
                    isBC: true,
                  ),
                ),
                const SizedBox(width: 8),
                // VS Time picker
                Expanded(
                  child: _buildTimePickerField(
                    dan: dan,
                    isBC: false,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimePickerField({
    required String dan,
    required bool isBC,
  }) {
    final currentValue = isBC ? _vremeBc[dan] : _vremeVs[dan];
    final vremena = isBC ? RouteConfig.bcVremenaZimski : RouteConfig.vsVremenaZimski;

    return GestureDetector(
      onTap: () => _showTimePickerDialog(
        dan: dan,
        isBC: isBC,
        vremena: vremena,
        currentValue: currentValue,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              currentValue ?? '--:--',
              style: TextStyle(
                color: currentValue != null ? Colors.black87 : Colors.grey,
                fontSize: 14,
                fontWeight: currentValue != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            Icon(
              Icons.access_time,
              size: 18,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _showTimePickerDialog({
    required String dan,
    required bool isBC,
    required List<String> vremena,
    String? currentValue,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.indigo.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.access_time,
              color: isBC ? Colors.orange : Colors.blue,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isBC ? 'BC polazak' : 'VS polazak',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: SizedBox(
          width: 280,
          height: 350,
          child: ListView(
            children: [
              // Option to clear
              ListTile(
                title: const Text(
                  'Bez polaska',
                  style: TextStyle(color: Colors.grey),
                ),
                leading: Icon(
                  currentValue == null ? Icons.check_circle : Icons.circle_outlined,
                  color: currentValue == null ? Colors.green : Colors.grey,
                ),
                onTap: () {
                  setState(() {
                    if (isBC) {
                      _vremeBc.remove(dan);
                    } else {
                      _vremeVs.remove(dan);
                    }
                  });
                  Navigator.of(context).pop();
                },
              ),
              Divider(color: Colors.white.withValues(alpha: 0.2)),
              // Time options
              ...vremena.map((vreme) => ListTile(
                    title: Text(
                      vreme,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    leading: Icon(
                      currentValue == vreme ? Icons.check_circle : Icons.circle_outlined,
                      color: currentValue == vreme ? Colors.green : Colors.white54,
                    ),
                    onTap: () {
                      setState(() {
                        if (isBC) {
                          _vremeBc[dan] = vreme;
                        } else {
                          _vremeVs[dan] = vreme;
                        }
                      });
                      Navigator.of(context).pop();
                    },
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Otkaži', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white30),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text('Otkaži'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _sacuvajRaspored,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(_isSaving ? 'Čuvam...' : 'Sačuvaj'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper funkcija za otvaranje dialoga
Future<void> showZakazivanjeDialog(
  BuildContext context, {
  required String putnikId,
  required String putnikIme,
  VoidCallback? onSaved,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: NedeljaZakazivanjeWidget(
        putnikId: putnikId,
        putnikIme: putnikIme,
        onSaved: onSaved,
      ),
    ),
  );
}
