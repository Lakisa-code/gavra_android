import 'package:flutter/material.dart';

import '../controllers/form_controller.dart';

/// 🕐 Sekcija za vremena polaska
class TimesSection extends StatelessWidget {
  final AddPutnikFormController controller;

  const TimesSection({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.13),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header sa preset dugmetom
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.schedule,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '🕐 Vremena polaska',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        shadows: const [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.schedule_outlined,
                      size: 18,
                      color: Colors.white70,
                    ),
                    tooltip: 'Standardna vremena',
                    onSelected: (value) => controller.popuniStandardnaVremena(value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'jutarnja_smena',
                        child: Text(
                          'Jutarnja smena (06:00-14:00)',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'popodnevna_smena',
                        child: Text(
                          'Popodnevna smena (14:00-22:00)',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'skola',
                        child: Text(
                          'Škola (07:30-14:00)',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'ocisti',
                        child: Text(
                          'Očisti sva vremena',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red[300],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Unesite vremena polaska za svaki radni dan:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Vremena za svaki dan
              ...['pon', 'uto', 'sre', 'cet', 'pet'].map((dan) {
                return _buildTimeInputRow(dan);
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  /// Kreira red za unos vremena za određeni dan
  Widget _buildTimeInputRow(String danKod) {
    final nazivDana = _getDayName(danKod);
    final isWorkingDay = controller.isWorkingDay(danKod);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWorkingDay ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWorkingDay ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWorkingDay ? Icons.check_circle : Icons.circle_outlined,
                size: 16,
                color: isWorkingDay ? Colors.green : Colors.white30,
              ),
              const SizedBox(width: 8),
              Text(
                nazivDana,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isWorkingDay ? Colors.white : Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              if (!isWorkingDay) ...[
                const SizedBox(width: 8),
                const Text(
                  '(neradni dan)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white30,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          if (isWorkingDay) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                // BC vreme
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BC',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: controller.getController('vreme_bc_$danKod'),
                        keyboardType: TextInputType.datetime,
                        decoration: InputDecoration(
                          hintText: '05:00',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          errorText: controller.getFieldError('vreme_bc_$danKod'),
                        ),
                        style: const TextStyle(fontSize: 14, height: 1.1, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                // VS vreme
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: controller.getController('vreme_vs_$danKod'),
                        keyboardType: TextInputType.datetime,
                        decoration: InputDecoration(
                          hintText: '05:30',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          errorText: controller.getFieldError('vreme_vs_$danKod'),
                        ),
                        style: const TextStyle(fontSize: 14, height: 1.1, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Helper za nazive dana
  String _getDayName(String danKod) {
    switch (danKod) {
      case 'pon':
        return 'Ponedeljak';
      case 'uto':
        return 'Utorak';
      case 'sre':
        return 'Sreda';
      case 'cet':
        return 'Četvrtak';
      case 'pet':
        return 'Petak';
      default:
        return danKod;
    }
  }
}
