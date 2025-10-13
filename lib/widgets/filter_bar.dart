import 'package:flutter/material.dart';

import '../theme.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({
    Key? key,
    required this.dani,
    required this.selectedDay,
    required this.gradovi,
    required this.selectedGrad,
    required this.vremena,
    required this.selectedVreme,
    required this.onDayChanged,
    required this.onGradChanged,
    required this.onVremeChanged,
  }) : super(key: key);

  final List<String> dani;
  final String selectedDay;
  final List<String> gradovi;
  final String selectedGrad;
  final List<String> vremena;
  final String selectedVreme;
  final void Function(String) onDayChanged;
  final void Function(String) onGradChanged;
  final void Function(String) onVremeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // Dan
          Expanded(
            child: Container(
              decoration: Theme.of(context).brightness == Brightness.dark
                  ? DarkSapphirePlatinumStyles.dropdownDecoration
                  : FlutterBankStyles.dropdownDecoration,
              child: DropdownButtonFormField<String>(
                value: selectedDay,
                dropdownColor:
                    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F2937) : const Color(0xFFF5F8FF),
                decoration: InputDecoration(
                  labelText: 'Dan',
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: dani
                    .map(
                      (dan) => DropdownMenuItem(
                        value: dan,
                        child: Text(
                          dan,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onDayChanged(value);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Grad
          Expanded(
            child: Container(
              decoration: Theme.of(context).brightness == Brightness.dark
                  ? DarkSapphirePlatinumStyles.dropdownDecoration
                  : FlutterBankStyles.dropdownDecoration,
              child: DropdownButtonFormField<String>(
                value: selectedGrad,
                dropdownColor:
                    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F2937) : const Color(0xFFF5F8FF),
                decoration: InputDecoration(
                  labelText: 'Grad',
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: gradovi
                    .map(
                      (grad) => DropdownMenuItem(
                        value: grad,
                        child: Text(
                          grad,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onGradChanged(value);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Vreme
          Expanded(
            child: Container(
              decoration: Theme.of(context).brightness == Brightness.dark
                  ? DarkSapphirePlatinumStyles.dropdownDecoration
                  : FlutterBankStyles.dropdownDecoration,
              child: DropdownButtonFormField<String>(
                value: selectedVreme,
                dropdownColor:
                    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F2937) : const Color(0xFFF5F8FF),
                decoration: InputDecoration(
                  labelText: 'Vreme',
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: vremena
                    .map(
                      (vreme) => DropdownMenuItem(
                        value: vreme,
                        child: Text(
                          vreme,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onVremeChanged(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
