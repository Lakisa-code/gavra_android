import 'package:flutter/material.dart';

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
          child: TextFormField(
            controller: bcController,
            keyboardType: TextInputType.datetime,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            decoration: InputDecoration(
              hintText: '07:30',
              prefixIcon: Icon(Icons.access_time, color: Colors.blue, size: 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: vsController,
            keyboardType: TextInputType.datetime,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            decoration: InputDecoration(
              hintText: '16:30',
              prefixIcon: Icon(Icons.access_time, color: Colors.blue, size: 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }
}
