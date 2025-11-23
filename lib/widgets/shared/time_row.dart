import 'package:flutter/material.dart';

import '../../utils/mesecni_helpers.dart';

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
              prefixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: bcController,
                builder: (_, value, __) {
                  final text = value.text.trim();
                  return InkWell(
                    onTap: () async {
                      final initial = _parseTime(bcController.text) ?? const TimeOfDay(hour: 7, minute: 30);
                      final picked = await showTimePicker(context: context, initialTime: initial);
                      if (picked != null) {
                        final formatted = '${picked.hour}:${picked.minute.toString().padLeft(2, '0')}';
                        bcController.text = MesecniHelpers.normalizeTime(formatted) ?? formatted;
                      }
                    },
                    child: text.isNotEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            margin: const EdgeInsets.only(left: 6, right: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(text,
                                style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                          )
                        : const Icon(Icons.access_time, color: Colors.blue, size: 16),
                  );
                },
              ),
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
              prefixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: vsController,
                builder: (_, value, __) {
                  final text = value.text.trim();
                  return InkWell(
                    onTap: () async {
                      final initial = _parseTime(vsController.text) ?? const TimeOfDay(hour: 16, minute: 30);
                      final picked = await showTimePicker(context: context, initialTime: initial);
                      if (picked != null) {
                        final formatted = '${picked.hour}:${picked.minute.toString().padLeft(2, '0')}';
                        vsController.text = MesecniHelpers.normalizeTime(formatted) ?? formatted;
                      }
                    },
                    child: text.isNotEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            margin: const EdgeInsets.only(left: 6, right: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(text,
                                style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                          )
                        : const Icon(Icons.access_time, color: Colors.blue, size: 16),
                  );
                },
              ),
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

  TimeOfDay? _parseTime(String? raw) {
    final s = MesecniHelpers.normalizeTime(raw);
    if (s == null || s.isEmpty) return null;
    final parts = s.split(':');
    if (parts.isEmpty) return null;
    final h = int.tryParse(parts[0]);
    final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
    if (h == null || m == null) return null;
    final hour = h.clamp(0, 23);
    final minute = m.clamp(0, 59);
    return TimeOfDay(hour: hour, minute: minute);
  }
}
