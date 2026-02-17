import 'package:flutter/material.dart';

import 'time_picker_cell.dart';

/// Small shared widget to render a BC / VS time row for a single day.
/// Koristi TimePickerCell za konzistentan izgled na svim mestima.
class TimeRow extends StatelessWidget {
  final String dayLabel;
  final TextEditingController bcController;
  final TextEditingController vsController;
  final String? bcStatus;
  final String? vsStatus;
  final bool isAdmin;
  final String? dayName; // 🆕 pon, uto, sre...

  const TimeRow({
    super.key,
    required this.dayLabel,
    required this.bcController,
    required this.vsController,
    this.bcStatus,
    this.vsStatus,
    this.isAdmin = false,
    this.dayName,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            dayLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 2,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: bcController,
            builder: (context, value, _) {
              final currentValue =
                  value.text.trim().isEmpty ? null : value.text.trim();
              return TimePickerCell(
                value: currentValue,
                isBC: true,
                status: bcStatus,
                isCancelled: bcStatus == 'otkazano',
                isAdmin: isAdmin,
                dayName: dayName,
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
              final currentValue =
                  value.text.trim().isEmpty ? null : value.text.trim();
              return TimePickerCell(
                value: currentValue,
                isBC: false,
                status: vsStatus,
                isCancelled: vsStatus == 'otkazano',
                isAdmin: isAdmin,
                dayName: dayName,
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
