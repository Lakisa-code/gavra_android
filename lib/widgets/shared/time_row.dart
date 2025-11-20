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
          flex: 2,
          child: Text(
            dayLabel,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: bcController,
            keyboardType: TextInputType.datetime,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'BC vreme',
              hintText: '07:30',
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: vsController,
            keyboardType: TextInputType.datetime,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'VS vreme',
              hintText: '16:30',
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
