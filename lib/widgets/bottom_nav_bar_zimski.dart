import 'package:flutter/material.dart';

import '../config/route_config.dart';
import '../services/theme_manager.dart';
import '../services/vreme_vozac_service.dart'; // 🆕 Za border boju dodeljenog vozača
import '../theme.dart';
import '../utils/schedule_utils.dart';
import '../utils/vozac_boja.dart'; // 🆕 Za border boju dodeljenog vozača

class BottomNavBarZimski extends StatefulWidget {
  const BottomNavBarZimski({
    super.key,
    required this.sviPolasci,
    required this.selectedGrad,
    required this.selectedVreme,
    required this.onPolazakChanged,
    required this.getPutnikCount,
    this.getKapacitet,
    this.isSlotLoading,
    this.bcVremena,
    this.vsVremena,
    this.selectedDan, // 🆕 Dan za proveru dodeljenog vozača (npr. 'pon', 'uto')
  });
  final List<String> sviPolasci;
  final String selectedGrad;
  final String selectedVreme;
  final void Function(String grad, String vreme) onPolazakChanged;
  final int Function(String grad, String vreme) getPutnikCount;
  final int Function(String grad, String vreme)? getKapacitet;
  final bool Function(String grad, String vreme)? isSlotLoading;
  final List<String>? bcVremena;
  final List<String>? vsVremena;
  final String? selectedDan; // 🆕

  @override
  State<BottomNavBarZimski> createState() => _BottomNavBarZimskiState();
}

class _BottomNavBarZimskiState extends State<BottomNavBarZimski> {
  final ScrollController _bcScrollController = ScrollController();
  final ScrollController _vsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  @override
  void didUpdateWidget(BottomNavBarZimski oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedVreme != widget.selectedVreme || oldWidget.selectedGrad != widget.selectedGrad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelected();
      });
    }
  }

  void _scrollToSelected() {
    const double itemWidth = 60.0; // width + margin

    // Automatska provera sezone
    final jeZimski = isZimski(DateTime.now());
    final bcVremena = widget.bcVremena ?? (jeZimski ? RouteConfig.bcVremenaZimski : RouteConfig.bcVremenaLetnji);
    final vsVremena = widget.vsVremena ?? (jeZimski ? RouteConfig.vsVremenaZimski : RouteConfig.vsVremenaLetnji);

    if (widget.selectedGrad == 'Bela Crkva') {
      final index = bcVremena.indexOf(widget.selectedVreme);
      if (index != -1 && _bcScrollController.hasClients) {
        final targetOffset = (index * itemWidth) - (MediaQuery.of(context).size.width / 4);
        _bcScrollController.animateTo(
          targetOffset.clamp(0.0, _bcScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else if (widget.selectedGrad == 'Vršac') {
      final index = vsVremena.indexOf(widget.selectedVreme);
      if (index != -1 && _vsScrollController.hasClients) {
        final targetOffset = (index * itemWidth) - (MediaQuery.of(context).size.width / 4);
        _vsScrollController.animateTo(
          targetOffset.clamp(0.0, _vsScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _bcScrollController.dispose();
    _vsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Automatska provera sezone
    final jeZimski = isZimski(DateTime.now());
    final bcVremena = widget.bcVremena ?? (jeZimski ? RouteConfig.bcVremenaZimski : RouteConfig.bcVremenaLetnji);
    final vsVremena = widget.vsVremena ?? (jeZimski ? RouteConfig.vsVremenaZimski : RouteConfig.vsVremenaLetnji);
    final currentThemeId = ThemeManager().currentThemeId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(
          color: Theme.of(context).glassBorder,
          width: 1.5,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, -8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // top-right total removed (per user request)
                _PolazakRow(
                  label: 'BC',
                  vremena: bcVremena,
                  selectedGrad: widget.selectedGrad,
                  selectedVreme: widget.selectedVreme,
                  grad: 'Bela Crkva',
                  onPolazakChanged: widget.onPolazakChanged,
                  getPutnikCount: widget.getPutnikCount,
                  getKapacitet: widget.getKapacitet,
                  isSlotLoading: widget.isSlotLoading,
                  scrollController: _bcScrollController,
                  currentThemeId: currentThemeId,
                  selectedDan: widget.selectedDan, // 🆕
                ),
                _PolazakRow(
                  label: 'VS',
                  vremena: vsVremena,
                  selectedGrad: widget.selectedGrad,
                  selectedVreme: widget.selectedVreme,
                  grad: 'Vršac',
                  onPolazakChanged: widget.onPolazakChanged,
                  getPutnikCount: widget.getPutnikCount,
                  getKapacitet: widget.getKapacitet,
                  isSlotLoading: widget.isSlotLoading,
                  scrollController: _vsScrollController,
                  currentThemeId: currentThemeId,
                  selectedDan: widget.selectedDan, // 🆕
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PolazakRow extends StatelessWidget {
  const _PolazakRow({
    required this.label,
    required this.vremena,
    required this.selectedGrad,
    required this.selectedVreme,
    required this.grad,
    required this.onPolazakChanged,
    required this.getPutnikCount,
    required this.currentThemeId,
    this.getKapacitet,
    this.isSlotLoading,
    this.scrollController,
    this.selectedDan, // 🆕
  });
  final String label;
  final List<String> vremena;
  final String selectedGrad;
  final String selectedVreme;
  final String grad;
  final void Function(String grad, String vreme) onPolazakChanged;
  final int Function(String grad, String vreme) getPutnikCount;
  final int Function(String grad, String vreme)? getKapacitet;
  final bool Function(String grad, String vreme)? isSlotLoading;
  final ScrollController? scrollController;
  final String currentThemeId;
  final String? selectedDan; // 🆕

  /// 🆕 Konvertuj puno ime dana u kraticu za bazu
  String _getDanKratica(String dan) {
    const Map<String, String> dayMap = {
      'Ponedeljak': 'pon',
      'Utorak': 'uto',
      'Sreda': 'sre',
      'Četvrtak': 'cet',
      'Petak': 'pet',
      'Subota': 'sub',
      'Nedelja': 'ned',
    };
    return dayMap[dan] ?? dan.toLowerCase().substring(0, 3);
  }

  /// 🆕 Dobij boju bordera za vreme - ako je dodeljen vozač, vrati njegovu boju
  Color? _getVozacBorderColor(String vreme) {
    if (selectedDan == null) return null;
    final danKratica = _getDanKratica(selectedDan!);
    final vozacIme = VremeVozacService().getVozacZaVremeSync(grad, vreme, danKratica);
    if (vozacIme == null) return null;
    return VozacBoja.get(vozacIme);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: scrollController,
              child: Row(
                children: vremena.map((vreme) {
                  final bool selected = selectedGrad == grad && selectedVreme == vreme;
                  // 🆕 Proveri da li je dodeljen vozač za ovo vreme
                  final vozacBorderColor = _getVozacBorderColor(vreme);
                  final hasVozac = vozacBorderColor != null;

                  return GestureDetector(
                    onTap: () => onPolazakChanged(grad, vreme),
                    child: Container(
                      width: 60.0,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? (currentThemeId == 'dark_steel_grey'
                                ? const Color(0xFF4A4A4A).withValues(alpha: 0.15) // Crna tema
                                : currentThemeId == 'passionate_rose'
                                    ? const Color(0xFFDC143C).withValues(alpha: 0.15) // Crvena tema
                                    : currentThemeId == 'dark_pink'
                                        ? const Color(0xFFE91E8C).withValues(alpha: 0.15) // Dark Pink tema
                                        : Colors.blueAccent.withValues(alpha: 0.15)) // Plava tema
                            : hasVozac
                                ? vozacBorderColor.withValues(alpha: 0.1) // 🆕 Lagana pozadina ako ima vozača
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          // 🆕 Ako ima dodeljen vozač, koristi njegovu boju za border
                          color: hasVozac
                              ? vozacBorderColor
                              : selected
                                  ? (currentThemeId == 'dark_steel_grey'
                                      ? const Color(0xFF4A4A4A) // Crna tema
                                      : currentThemeId == 'passionate_rose'
                                          ? const Color(0xFFDC143C) // Crvena tema
                                          : currentThemeId == 'dark_pink'
                                              ? const Color(0xFFE91E8C) // Dark Pink tema
                                              : Colors.blue) // Plava tema
                                  : Colors.grey[300]!,
                          width: hasVozac ? 2.5 : (selected ? 2 : 1), // 🆕 Deblji border ako ima vozača
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            vreme,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? (currentThemeId == 'dark_steel_grey'
                                      ? const Color(0xFF4A4A4A) // Crna tema
                                      : currentThemeId == 'passionate_rose'
                                          ? const Color(0xFFDC143C) // Crvena tema
                                          : currentThemeId == 'dark_pink'
                                              ? const Color(0xFFE91E8C) // Dark Pink tema
                                              : Colors.blue) // Plava tema
                                  : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Builder(
                            builder: (ctx) {
                              final loading = isSlotLoading?.call(grad, vreme) ?? false;
                              if (loading) {
                                return const SizedBox(
                                  height: 12,
                                  width: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                );
                              }
                              final count = getPutnikCount(grad, vreme);
                              final kapacitet = getKapacitet?.call(grad, vreme);
                              final displayText = kapacitet != null ? '$count ($kapacitet)' : '$count';
                              return Text(
                                displayText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: selected
                                      ? (currentThemeId == 'dark_steel_grey'
                                          ? const Color(0xFF4A4A4A) // Crna tema
                                          : currentThemeId == 'passionate_rose'
                                              ? const Color(0xFFDC143C) // Crvena tema
                                              : currentThemeId == 'dark_pink'
                                                  ? const Color(0xFFE91E8C) // Dark Pink tema
                                                  : Colors.blue) // Plava tema
                                      : Colors.white70,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
