import 'package:flutter/material.dart';

import 'time_picker_cell.dart';

/// Small shared widget to render a BC / VS time row for a single day.
/// Koristi TimePickerCell za konzistentan izgled na svim mestima.
class TimeRow extends StatelessWidget {
  final String dayLabel;
  final TextEditingController bcController;
  final TextEditingController vsController;

  const TimeRow({
    super.key,
    required this.dayLabel,
    required this.bcController,
    required this.vsController,
  });

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
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: bcController,
            builder: (context, value, _) {
              final currentValue = value.text.trim().isEmpty ? null : value.text.trim();
              return TimePickerCell(
                value: currentValue,
                isBC: true,
                onChanged: (newValue) {
                  bcController.text = newValue ?? '';
                },
              );
            },
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: vsController,
            builder: (context, value, _) {
              final currentValue = value.text.trim().isEmpty ? null : value.text.trim();
              return TimePickerCell(
                value: currentValue,
                isBC: false,
                onChanged: (newValue) {
                  vsController.text = newValue ?? '';
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
