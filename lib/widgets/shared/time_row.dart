import 'package:flutter/material.dart';

import '../../config/route_config.dart';
import '../../utils/schedule_utils.dart';

/// Small shared widget to render a BC / VS time row for a single day.
class TimeRow extends StatelessWidget {
  final String dayLabel;
  final TextEditingController bcController;
  final TextEditingController vsController;

  const TimeRow({
    Key? key,
    required this.dayLabel,
    required this.bcController,
    required this.vsController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            dayLabel,
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
        Expanded(
          flex: 2,
          child: _buildTimePickerField(
            context: context,
            controller: bcController,
            isBC: true,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: _buildTimePickerField(
            context: context,
            controller: vsController,
            isBC: false,
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerField({
    required BuildContext context,
    required TextEditingController controller,
    required bool isBC,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final currentValue =
            value.text.trim().isEmpty ? null : value.text.trim();

        return GestureDetector(
          onTap: () => _showTimePickerDialog(
            context: context,
            controller: controller,
            isBC: isBC,
            currentValue: currentValue,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    currentValue ?? '--:--',
                    style: TextStyle(
                      color:
                          currentValue != null ? Colors.black87 : Colors.grey,
                      fontSize: 13,
                      fontWeight: currentValue != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTimePickerDialog({
    required BuildContext context,
    required TextEditingController controller,
    required bool isBC,
    String? currentValue,
  }) {
    // Automatska provera sezone
    final jeZimski = isZimski(DateTime.now());
    final vremena = isBC
        ? (jeZimski ? RouteConfig.bcVremenaZimski : RouteConfig.bcVremenaLetnji)
        : (jeZimski
            ? RouteConfig.vsVremenaZimski
            : RouteConfig.vsVremenaLetnji);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                  currentValue == null
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: currentValue == null ? Colors.green : Colors.grey,
                ),
                onTap: () {
                  controller.text = '';
                  Navigator.of(dialogContext).pop();
                },
              ),
              const Divider(color: Colors.white24),
              // Time options
              ...vremena.map((vreme) {
                final isSelected = currentValue == vreme;
                return ListTile(
                  title: Text(
                    vreme,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? Colors.green : Colors.white54,
                  ),
                  onTap: () {
                    controller.text = vreme;
                    Navigator.of(dialogContext).pop();
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child:
                const Text('Otkaži', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
