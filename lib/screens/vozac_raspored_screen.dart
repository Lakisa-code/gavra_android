import 'package:flutter/material.dart';

import '../config/route_config.dart';
import '../constants/day_constants.dart';
import '../services/theme_manager.dart';
import '../services/vozac_raspored_service.dart';
import '../services/vozac_service.dart';
import '../utils/app_snack_bar.dart';
import '../utils/vozac_cache.dart';

/// 🗓️ Ekran za upravljanje rasporedom vozača
/// Admin dodaje/briše koji vozač vozi koji termin
class VozacRasporedScreen extends StatefulWidget {
  const VozacRasporedScreen({super.key});

  @override
  State<VozacRasporedScreen> createState() => _VozacRasporedScreenState();
}

class _VozacRasporedScreenState extends State<VozacRasporedScreen> {
  final _service = VozacRasporedService();

  List<VozacRasporedEntry> _raspored = [];
  List<String> _vozaci = [];
  bool _isLoading = true;

  // Selektovani dan za prikaz (kratica)
  String _selectedDan = DayConstants.dayAbbreviations.first;

  // Za dodavanje novog termina
  String _selGrad = 'BC';
  String _selVreme = '';
  String? _selVozac;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);
    final data = await _service.loadAll();
    final vozaciList = await VozacService().getAllVozaci();
    if (mounted) {
      final vozaci = vozaciList.map((v) => v.ime).toList();
      final vremeOpts = _vremeOptionsForGrad(_selGrad);
      setState(() {
        _raspored = data.where((r) => r.putnikId == null).toList();
        _vozaci = vozaci;
        _selVozac ??= vozaci.isNotEmpty ? vozaci.first : null;
        if (_selVreme.isEmpty || !vremeOpts.contains(_selVreme)) {
          _selVreme = vremeOpts.isNotEmpty ? vremeOpts.first : '';
        }
        _isLoading = false;
      });
    }
  }

  List<String> _vremeOptionsForGrad(String grad) {
    final navType = ThemeManager().currentNavBarType;
    if (grad == 'BC') {
      if (navType == 'praznici') return RouteConfig.bcVremenaPraznici;
      if (navType == 'zimski') return RouteConfig.bcVremenaZimski;
      return RouteConfig.bcVremenaLetnji;
    } else {
      if (navType == 'praznici') return RouteConfig.vsVremenaPraznici;
      if (navType == 'zimski') return RouteConfig.vsVremenaZimski;
      return RouteConfig.vsVremenaLetnji;
    }
  }

  List<VozacRasporedEntry> get _terminiZaDan =>
      _raspored.where((r) => r.dan == _selectedDan).toList();

  String get _selectedDanLabel =>
      DayConstants.dayNamesInternal[DayConstants.dayAbbreviations.indexOf(_selectedDan)];

  Future<void> _dodaj() async {
    if (_selVozac == null || _selVreme.isEmpty) return;

    final exists = _raspored.any((r) =>
        r.dan == _selectedDan &&
        r.grad == _selGrad &&
        r.vreme == _selVreme &&
        r.vozac == _selVozac);
    if (exists) {
      if (mounted) AppSnackBar.error(context, '⚠️ Već postoji: $_selVozac — $_selGrad $_selVreme');
      return;
    }

    await _service.upsert(VozacRasporedEntry(
      dan: _selectedDan,
      grad: _selGrad,
      vreme: _selVreme,
      vozac: _selVozac!,
    ));
    if (mounted) {
      AppSnackBar.success(context, '✅ $_selVozac → $_selGrad $_selVreme ($_selectedDan)');
    }
    _load();
  }

  Future<void> _obrisi(VozacRasporedEntry r) async {
    await _service.deleteTermin(
      dan: r.dan,
      grad: r.grad,
      vreme: r.vreme,
      vozac: r.vozac,
    );
    if (mounted) AppSnackBar.success(context, '🗑️ Obrisano');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = ThemeManager().currentGradient;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          '🗓️ Raspored vozača',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  children: [
                    const SizedBox(height: 4),
                    _buildDanSelector(),
                    const SizedBox(height: 4),
                    Expanded(
                      child: _terminiZaDan.isEmpty
                          ? _buildPraznaLista()
                          : _buildTerminiLista(),
                    ),
                    _buildAddBar(),
                  ],
                ),
        ),
      ),
    );
  }

  // ── DAN SELECTOR ────────────────────────────────────────────────────────────
  Widget _buildDanSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List.generate(DayConstants.dayAbbreviations.length, (i) {
          final abbr = DayConstants.dayAbbreviations[i];
          final label = DayConstants.dayNamesInternal[i].substring(0, 3);
          final selected = _selectedDan == abbr;
          final count = _raspored.where((r) => r.dan == abbr).length;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDan = abbr),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.18)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.white.withOpacity(0.15),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white60,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── PRAZNA LISTA ─────────────────────────────────────────────────────────────
  Widget _buildPraznaLista() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 56, color: Colors.white.withOpacity(0.25)),
          const SizedBox(height: 14),
          Text(
            'Nema rasporeda za $_selectedDanLabel',
            style:
                TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Svi vozači vide sve putnike.',
            style:
                TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── LISTA TERMINA ─────────────────────────────────────────────────────────────
  Widget _buildTerminiLista() {
    final Map<String, List<VozacRasporedEntry>> grouped = {};
    for (final r in _terminiZaDan) {
      grouped.putIfAbsent('${r.grad}|${r.vreme}', () => []).add(r);
    }
    final keys = grouped.keys.toList()
      ..sort((a, b) {
        // sortiraj: BC pre VS, onda po vremenu
        final aGrad = a.split('|')[0];
        final bGrad = b.split('|')[0];
        if (aGrad != bGrad) return aGrad.compareTo(bGrad);
        return a.split('|')[1].compareTo(b.split('|')[1]);
      });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final entries = grouped[keys[i]]!;
        return _buildTerminCard(entries);
      },
    );
  }

  Widget _buildTerminCard(List<VozacRasporedEntry> entries) {
    final isBC = entries.first.grad == 'BC';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.13), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: isBC
                        ? Colors.blue.withOpacity(0.3)
                        : Colors.green.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    entries.first.grad,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  entries.first.vreme,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17),
                ),
                const Spacer(),
                Text(
                  '${entries.length} vozač${entries.length > 1 ? 'a' : ''}',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          ...entries.map(_buildVozacRow),
        ],
      ),
    );
  }

  Widget _buildVozacRow(VozacRasporedEntry r) {
    final boja = VozacCache.getColor(r.vozac);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: boja.withOpacity(0.85),
            child: Text(
              r.vozac.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              r.vozac,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15),
            ),
          ),
          GestureDetector(
            onTap: () => _obrisi(r),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.remove_circle_outline,
                  color: Colors.red.withOpacity(0.8), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── ADD BAR ─────────────────────────────────────────────────────────────────
  Widget _buildAddBar() {
    final vremeOpts = _vremeOptionsForGrad(_selGrad);
    final validVreme =
        vremeOpts.contains(_selVreme) ? _selVreme : (vremeOpts.isNotEmpty ? vremeOpts.first : null);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.13), width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dodaj za $_selectedDanLabel:',
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // GRAD chip
              _buildChipSelector(
                options: ['BC', 'VS'],
                selected: _selGrad,
                onSelect: (v) {
                  final opts = _vremeOptionsForGrad(v);
                  setState(() {
                    _selGrad = v;
                    _selVreme = opts.isNotEmpty ? opts.first : '';
                  });
                },
              ),
              const SizedBox(width: 8),
              // VREME dropdown
              Expanded(
                flex: 3,
                child: _buildDropdown(
                  value: validVreme,
                  items: vremeOpts,
                  hint: 'Vreme',
                  onChanged: (v) => setState(() => _selVreme = v!),
                ),
              ),
              const SizedBox(width: 8),
              // VOZAC dropdown
              Expanded(
                flex: 4,
                child: _buildDropdown(
                  value: _selVozac,
                  items: _vozaci,
                  hint: 'Vozač',
                  onChanged: (v) => setState(() => _selVozac = v),
                ),
              ),
              const SizedBox(width: 8),
              // DODAJ
              GestureDetector(
                onTap: _dodaj,
                child: Container(
                  height: 40,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue, width: 1.5),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChipSelector({
    required List<String> options,
    required String selected,
    required void Function(String) onSelect,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((opt) {
        final isSel = opt == selected;
        return GestureDetector(
          onTap: () => onSelect(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSel
                  ? Colors.blue.withOpacity(0.45)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSel ? Colors.blue : Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                color: isSel ? Colors.white : Colors.white54,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required void Function(String?) onChanged,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF1A2340),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: Colors.white54, size: 18),
          hint: Text(hint,
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: items
              .map((v) => DropdownMenuItem(
                    value: v,
                    child:
                        Text(v, style: const TextStyle(color: Colors.white)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
