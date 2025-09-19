import 'package:flutter/material.dart';
import '../utils/slot_utils.dart';

class BottomNavBarZimski extends StatefulWidget {
  final List<String> sviPolasci;
  final String selectedGrad;
  final String selectedVreme;
  final Function(String grad, String vreme) onPolazakChanged;
  final Function(String grad, String vreme) getPutnikCount;
  final bool Function(String grad, String vreme)? isSlotLoading;
  const BottomNavBarZimski({
    super.key,
    required this.sviPolasci,
    required this.selectedGrad,
    required this.selectedVreme,
    required this.onPolazakChanged,
    required this.getPutnikCount,
    this.isSlotLoading,
  });

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

    const List<String> bcVremena = [
      '5:00',
      '6:00',
      '7:00',
      '8:00',
      '9:00',
      '11:00',
      '12:00',
      '13:00',
      '14:00',
      '15:30',
      '18:00'
    ];
    const List<String> vsVremena = [
      '6:00',
      '7:00',
      '8:00',
      '10:00',
      '11:00',
      '12:00',
      '13:00',
      '14:00',
      '15:30',
      '17:00',
      '19:00'
    ];

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    const List<String> bcVremena = SlotUtils.bcVremena;
    const List<String> vsVremena = SlotUtils.vsVremena;
    return Material(
      color: isDarkMode ? Theme.of(context).cardColor : Colors.white,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
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
              fixedBoxWidth: 56,
              scrollController: _bcScrollController,
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
              fixedBoxWidth: 56,
              scrollController: _vsScrollController,
            ),
          ],
        ),
      ),
    );
  }
}

class _PolazakRow extends StatelessWidget {
  final String label;
  final List<String> vremena;
  final String selectedGrad;
  final String selectedVreme;
  final String grad;
  final Function(String grad, String vreme) onPolazakChanged;
  final Function(String grad, String vreme) getPutnikCount;
  final bool Function(String grad, String vreme)? isSlotLoading;
  final double fixedBoxWidth;
  final ScrollController? scrollController;

  const _PolazakRow({
    required this.label,
    required this.vremena,
    required this.selectedGrad,
    required this.selectedVreme,
    required this.grad,
    required this.onPolazakChanged,
    required this.getPutnikCount,
    this.isSlotLoading,
    this.fixedBoxWidth = 56,
    this.scrollController,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                )),
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
                      width: fixedBoxWidth,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 0),
                      decoration: BoxDecoration(
                        color: selected
                            ? (isDarkMode
                                ? Colors.blueAccent.withOpacity(0.3)
                                : Colors.blueAccent.withOpacity(0.15))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? Colors.blue
                              : (isDarkMode
                                  ? Colors.grey[600]!
                                  : Colors.grey[300]!),
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
                                  ? Colors.blue
                                  : (isDarkMode ? Colors.white : Colors.black),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Builder(builder: (ctx) {
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
                                    ? Colors.blue
                                    : (isDarkMode
                                        ? Colors.grey[300]
                                        : Colors.grey[700]),
                              ),
                            );
                          }),
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
