import 'package:flutter/material.dart';

import '../config/route_config.dart';
import '../services/theme_manager.dart';
import '../theme.dart';

/// Bottom navigation bar za praznike/specijalne dane
/// BC: 5:00, 6:00, 12:00, 13:00, 15:00
/// VS: 6:00, 7:00, 13:00, 14:00, 15:30
class BottomNavBarPraznici extends StatefulWidget {
  const BottomNavBarPraznici({
    super.key,
    required this.sviPolasci,
    required this.selectedGrad,
    required this.selectedVreme,
    required this.onPolazakChanged,
    required this.getPutnikCount,
    this.getKapacitet,
    this.isSlotLoading,
  });
  final List<String> sviPolasci;
  final String selectedGrad;
  final String selectedVreme;
  final void Function(String grad, String vreme) onPolazakChanged;
  final int Function(String grad, String vreme) getPutnikCount;
  final int Function(String grad, String vreme)? getKapacitet;
  final bool Function(String grad, String vreme)? isSlotLoading;

  @override
  State<BottomNavBarPraznici> createState() => _BottomNavBarPrazniciState();
}

class _BottomNavBarPrazniciState extends State<BottomNavBarPraznici> {
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
  void didUpdateWidget(BottomNavBarPraznici oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedVreme != widget.selectedVreme || oldWidget.selectedGrad != widget.selectedGrad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelected();
      });
    }
  }

  void _scrollToSelected() {
    const double itemWidth = 60.0;

    final bcVremena = RouteConfig.bcVremenaPraznici;
    final vsVremena = RouteConfig.vsVremenaPraznici;

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
    final bcVremena = RouteConfig.bcVremenaPraznici;
    final vsVremena = RouteConfig.vsVremenaPraznici;
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
    Key? key,
  }) : super(key: key);
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
                                ? const Color(0xFF4A4A4A).withValues(alpha: 0.15)
                                : currentThemeId == 'passionate_rose'
                                    ? const Color(0xFFDC143C).withValues(alpha: 0.15)
                                    : currentThemeId == 'dark_pink'
                                        ? const Color(0xFFE91E8C).withValues(alpha: 0.15)
                                        : Colors.blueAccent.withValues(alpha: 0.15))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? (currentThemeId == 'dark_steel_grey'
                                  ? const Color(0xFF4A4A4A)
                                  : currentThemeId == 'passionate_rose'
                                      ? const Color(0xFFDC143C)
                                      : currentThemeId == 'dark_pink'
                                          ? const Color(0xFFE91E8C)
                                          : Colors.blue)
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
                                      ? const Color(0xFF4A4A4A)
                                      : currentThemeId == 'passionate_rose'
                                          ? const Color(0xFFDC143C)
                                          : currentThemeId == 'dark_pink'
                                              ? const Color(0xFFE91E8C)
                                              : Colors.blue)
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
                                          ? const Color(0xFF4A4A4A)
                                          : currentThemeId == 'passionate_rose'
                                              ? const Color(0xFFDC143C)
                                              : currentThemeId == 'dark_pink'
                                                  ? const Color(0xFFE91E8C)
                                                  : Colors.blue)
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
