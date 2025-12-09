import 'package:flutter/material.dart';

import '../config/route_config.dart';
import '../services/slobodna_mesta_service.dart';
import '../services/theme_manager.dart';
import '../theme.dart';
import '../utils/schedule_utils.dart';

/// 🎫 Widget za prikaz slobodnih mesta - BOTTOM NAV BAR STIL
/// Identičan dizajn kao BottomNavBarZimski, samo prikazuje slobodna mesta
class SlobodnaMestaWidget extends StatefulWidget {
  final String? putnikId;
  final String? putnikGrad;
  final String? putnikVreme;
  final Function(String novoVreme)? onPromenaVremena;

  const SlobodnaMestaWidget({
    Key? key,
    this.putnikId,
    this.putnikGrad,
    this.putnikVreme,
    this.onPromenaVremena,
  }) : super(key: key);

  @override
  State<SlobodnaMestaWidget> createState() => _SlobodnaMestaWidgetState();
}

class _SlobodnaMestaWidgetState extends State<SlobodnaMestaWidget> {
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
  void didUpdateWidget(SlobodnaMestaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.putnikVreme != widget.putnikVreme || oldWidget.putnikGrad != widget.putnikGrad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelected();
      });
    }
  }

  void _scrollToSelected() {
    const double itemWidth = 60.0;

    final jeZimski = isZimski(DateTime.now());
    final bcVremena = jeZimski ? RouteConfig.bcVremenaZimski : RouteConfig.bcVremenaLetnji;
    final vsVremena = jeZimski ? RouteConfig.vsVremenaZimski : RouteConfig.vsVremenaLetnji;

    final normalizedGrad = widget.putnikGrad?.toLowerCase() ?? '';

    if (normalizedGrad.contains('bela') || normalizedGrad == 'bc') {
      final index = bcVremena.indexOf(widget.putnikVreme ?? '');
      if (index != -1 && _bcScrollController.hasClients) {
        final targetOffset = (index * itemWidth) - (MediaQuery.of(context).size.width / 4);
        _bcScrollController.animateTo(
          targetOffset.clamp(0.0, _bcScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else if (normalizedGrad.contains('vrsac') || normalizedGrad.contains('vršac') || normalizedGrad == 'vs') {
      final index = vsVremena.indexOf(widget.putnikVreme ?? '');
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

  Future<void> _onTapSlot(SlobodnaMesta sm) async {
    // Ako je puno ili neaktivno
    if (sm.jePuno || !sm.aktivan) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sm.jePuno ? 'Ovaj termin je pun!' : 'Ovaj termin nije aktivan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Ako je isto vreme kao trenutno
    final normalizedGrad = widget.putnikGrad?.toLowerCase() ?? '';
    final isBC = normalizedGrad.contains('bela') || normalizedGrad == 'bc';
    final isVS = normalizedGrad.contains('vrsac') || normalizedGrad.contains('vršac') || normalizedGrad == 'vs';

    if (sm.vreme == widget.putnikVreme && ((sm.grad == 'BC' && isBC) || (sm.grad == 'VS' && isVS))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Već ste na ovom terminu'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    // Potvrda promene
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F), // Tamno plava, čvrsta boja
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Promena vremena',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Da li želite da promenite vreme polaska na ${sm.vreme} (${sm.grad == 'BC' ? 'Bela Crkva' : 'Vršac'})?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ne', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Da, promeni'),
          ),
        ],
      ),
    );

    if (confirm == true && widget.onPromenaVremena != null) {
      widget.onPromenaVremena!('${sm.grad}|${sm.vreme}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentThemeId = ThemeManager().currentThemeId;

    return StreamBuilder<Map<String, List<SlobodnaMesta>>>(
      stream: SlobodnaMestaService.streamSlobodnaMesta(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(
                color: Theme.of(context).glassBorder,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final data = snapshot.data ?? {'BC': [], 'VS': []};

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          // Flow dizajn - bez okvira
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header - SLOBODNA MESTA
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_seat, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'SLOBODNA MESTA UŽIVO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // BC Row
                  _SlobodnaRow(
                    label: 'BC',
                    grad: 'BC',
                    slobodnaList: data['BC'] ?? [],
                    putnikGrad: widget.putnikGrad,
                    putnikVreme: widget.putnikVreme,
                    onTapSlot: _onTapSlot,
                    scrollController: _bcScrollController,
                    currentThemeId: currentThemeId,
                  ),
                  // VS Row
                  _SlobodnaRow(
                    label: 'VS',
                    grad: 'VS',
                    slobodnaList: data['VS'] ?? [],
                    putnikGrad: widget.putnikGrad,
                    putnikVreme: widget.putnikVreme,
                    onTapSlot: _onTapSlot,
                    scrollController: _vsScrollController,
                    currentThemeId: currentThemeId,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Red sa vremenima - identičan kao _PolazakRow u BottomNavBarZimski
class _SlobodnaRow extends StatelessWidget {
  const _SlobodnaRow({
    required this.label,
    required this.grad,
    required this.slobodnaList,
    required this.putnikGrad,
    required this.putnikVreme,
    required this.onTapSlot,
    required this.currentThemeId,
    this.scrollController,
    Key? key,
  }) : super(key: key);

  final String label;
  final String grad;
  final List<SlobodnaMesta> slobodnaList;
  final String? putnikGrad;
  final String? putnikVreme;
  final Function(SlobodnaMesta) onTapSlot;
  final ScrollController? scrollController;
  final String currentThemeId;

  bool _isSelected(SlobodnaMesta sm) {
    final normalizedGrad = putnikGrad?.toLowerCase() ?? '';
    final isBC = normalizedGrad.contains('bela') || normalizedGrad == 'bc';
    final isVS = normalizedGrad.contains('vrsac') || normalizedGrad.contains('vršac') || normalizedGrad == 'vs';

    return sm.vreme == putnikVreme && ((sm.grad == 'BC' && isBC) || (sm.grad == 'VS' && isVS));
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
                children: slobodnaList
                    .where((sm) => !sm.jePuno) // 🎫 Sakrij pune termine
                    .map((sm) {
                  final bool selected = _isSelected(sm);

                  return GestureDetector(
                    onTap: () => onTapSlot(sm),
                    child: Container(
                      width: 60.0,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
                            sm.vreme,
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
                          Text(
                            sm.jePuno ? 'X' : '${sm.slobodna}',
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
