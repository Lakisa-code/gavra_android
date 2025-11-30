import 'package:flutter/material.dart';

import '../controllers/form_controller.dart';

/// 📋 Sekcija za osnovne informacije putnika
class BasicInfoSection extends StatelessWidget {
  final AddPutnikFormController controller;

  const BasicInfoSection({
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
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getTypeColor(controller.formData.tip, context).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '📋 Osnovne informacije',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
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
                ],
              ),
              const SizedBox(height: 16),

              // Ime putnika
              TextField(
                controller: controller.getController('ime'),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: '👤 Ime putnika *',
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  errorBorder: const OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.red,
                      width: 2,
                    ),
                  ),
                  prefixIcon: const Icon(
                    Icons.person,
                    color: Colors.white,
                  ),
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  filled: true,
                  labelStyle: const TextStyle(color: Colors.white70),
                  errorText: controller.getFieldError('ime'),
                ),
                style: const TextStyle(color: Colors.white),
              ),

              const SizedBox(height: 12),

              // Tip putnika dropdown
              DropdownButtonFormField<String>(
                initialValue: controller.formData.tip,
                decoration: InputDecoration(
                  labelText: 'Tip putnika',
                  border: const OutlineInputBorder(),
                  prefixIcon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      controller.formData.tip == 'ucenik' ? Icons.school : Icons.business,
                      key: ValueKey('${controller.formData.tip}_dropdown'),
                      color: Colors.white,
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  filled: true,
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(
                    value: 'radnik',
                    child: Row(
                      children: [
                        Icon(
                          Icons.business,
                          color: Colors.teal,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Radnik',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'ucenik',
                    child: Row(
                      children: [
                        Icon(
                          Icons.school,
                          color: Colors.white70,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Učenik',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.updateTip(value);
                  }
                },
              ),

              const SizedBox(height: 12),

              // Škola/Ustanova
              TextField(
                controller: controller.getController('tipSkole'),
                decoration: InputDecoration(
                  labelText: controller.formData.tip == 'ucenik' ? '🎓 Škola' : '🏢 Ustanova/Firma',
                  hintText: controller.formData.tip == 'ucenik'
                      ? 'npr. Gimnazija "Bora Stanković"'
                      : 'npr. Hemofarm, Opština Vršac...',
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  prefixIcon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      controller.formData.tip == 'ucenik' ? Icons.school : Icons.business,
                      key: ValueKey(controller.formData.tip),
                      color: Colors.white,
                    ),
                  ),
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  filled: true,
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintStyle: const TextStyle(color: Colors.white54),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Vraća boju za tip putnika
  Color _getTypeColor(String tip, BuildContext context) {
    switch (tip) {
      case 'ucenik':
        return Colors.blue;
      case 'radnik':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}
