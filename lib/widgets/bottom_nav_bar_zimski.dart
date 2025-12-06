import 'package:flutter/material.dart';

import '../config/route_config.dart';
import '../services/theme_manager.dart';
import '../theme.dart';
import '../utils/schedule_utils.dart';

class BottomNavBarZimski extends StatefulWidget {
  const BottomNavBarZimski({
    super.key,
    required this.sviPolasci,
    required this.selectedGrad,
    required this.selectedVreme,
    required this.onPolazakChanged,
    required this.getPutnikCount,
    this.isSlotLoading,
    this.bcVremena, // ✅ Opcionalno - ako nije prosleđeno, koristi RouteConfig
    this.vsVremena, // ✅ Opcionalno - ako nije prosleđeno, koristi RouteConfig
  });
  final List<String> sviPolasci;
  final String selectedGrad;
  final String selectedVreme;
  final void Function(String grad, String vreme) onPolazakChanged;
  final int Function(String grad, String vreme) getPutnikCount;
  final bool Function(String grad, String vreme)? isSlotLoading;
  final List<String>? bcVremena; // ✅ Custom BC vremena
  final List<String>? vsVremena; // ✅ Custom VS vremena

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
    if (oldWidget.selectedVreme != widget.selectedVreme ||
        oldWidget.selectedGrad != widget.selectedGrad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelected();
      });
    }
  }

  void _scrollToSelected() {
    const double itemWidth = 60.0; // width + margin

    // 🎯 Automatska provera sezone
    final jeZimski = isZimski(DateTime.now());
    final bcVremena = widget.bcVremena ??
        (jeZimski ? RouteConfig.bcVremenaZimski : RouteConfig.bcVremenaLetnji);
    final vsVremena = widget.vsVremena ??
        (jeZimski ? RouteConfig.vsVremenaZimski : RouteConfig.vsVremenaLetnji);

    if (widget.selectedGrad == 'Bela Crkva') {
      final index = bcVremena.indexOf(widget.selectedVreme);
      if (index != -1 && _bcScrollController.hasClients) {
        final targetOffset =
            (index * itemWidth) - (MediaQuery.of(context).size.width / 4);
        _bcScrollController.animateTo(
          targetOffset.clamp(0.0, _bcScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else if (widget.selectedGrad == 'Vršac') {
      final index = vsVremena.indexOf(widget.selectedVreme);
      if (index != -1 && _vsScrollController.hasClients) {
        final targetOffset =
            (index * itemWidth) - (MediaQuery.of(context).size.width / 4);
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
    // 🎯 Automatska provera sezone
    final jeZimski = isZimski(DateTime.now());
    final bcVremena = widget.bcVremena ??
        (jeZimski ? RouteConfig.bcVremenaZimski : RouteConfig.bcVremenaLetnji);
    final vsVremena = widget.vsVremena ??
        (jeZimski ? RouteConfig.vsVremenaZimski : RouteConfig.vsVremenaLetnji);
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
                  isSlotLoading: widget.isSlotLoading,
                  scrollController: _bcScrollController,
                  currentThemeId: currentThemeId,
                ),
                _PolazakRow(
                  label: 'VS',
                  vremena: vsVremena,
                  selectedGrad: widget.selectedGrad,
                  selectedVreme: widget.selectedVreme,
                  grad: 'Vršac',
                  onPolazakChanged: widget.onPolazakChanged,
                  getPutnikCount: widget.getPutnikCount,
                  isSlotLoading: widget.isSlotLoading,
                  scrollController: _vsScrollController,
                  currentThemeId: currentThemeId,
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
    this.isSlotLoading,
    this.scrollController,
    Key? key,
  }) : super(key: key);
  final String label;
  final List<String> vremena;
  final String selectedGrad;
  final String selectedVreme;
  final String grad;
  final void Function(String grad, String vreme) onPolazakChanged;
  final int Function(String grad, String vreme) getPutnikCount;
  final bool Function(String grad, String vreme)? isSlotLoading;
  final ScrollController? scrollController;
  final String currentThemeId;

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
                  final bool selected =
                      selectedGrad == grad && selectedVreme == vreme;
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
                                ? const Color(0xFF4A4A4A)
                                    .withValues(alpha: 0.15) // Crna tema
                                : currentThemeId == 'passionate_rose'
                                    ? const Color(0xFFDC143C).withValues(
                                        alpha: 0.15) // Pink tema - Crimson
                                    : Colors.blueAccent
                                        .withValues(alpha: 0.15)) // Plava tema
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? (currentThemeId == 'dark_steel_grey'
                                  ? const Color(0xFF4A4A4A) // Crna tema
                                  : currentThemeId == 'passionate_rose'
                                      ? const Color(
                                          0xFFDC143C) // Pink tema - Crimson
                                      : Colors.blue) // Plava tema
                              : Colors.grey[300]!,
                          width: selected ? 2 : 1,
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
                                          ? const Color(
                                              0xFFDC143C,
                                            ) // Pink tema - Crimson
                                          : Colors.blue) // Plava tema
                                  : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Builder(
                            builder: (ctx) {
                              final loading =
                                  isSlotLoading?.call(grad, vreme) ?? false;
                              if (loading) {
                                return const SizedBox(
                                  height: 12,
                                  width: 12,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                );
                              }
                              return Text(
                                getPutnikCount(grad, vreme).toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: selected
                                      ? (currentThemeId == 'dark_steel_grey'
                                          ? const Color(0xFF4A4A4A) // Crna tema
                                          : currentThemeId == 'passionate_rose'
                                              ? const Color(
                                                  0xFFDC143C,
                                                ) // Pink tema - Crimson
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
