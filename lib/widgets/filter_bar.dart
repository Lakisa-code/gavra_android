import 'package:flutter/material.dart';

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
  final ValueChanged<String> onDayChanged;
  final ValueChanged<String> onGradChanged;
  final ValueChanged<String> onVremeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // Dan
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedDay,
              decoration: const InputDecoration(
                labelText: 'Dan',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              items: dani
                  .map(
                    (dan) => DropdownMenuItem(
                      value: dan,
                      child: Text(dan),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onDayChanged(value);
              },
            ),
          ),
          const SizedBox(width: 8),
          // Grad
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedGrad,
              decoration: const InputDecoration(
                labelText: 'Grad',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              items: gradovi
                  .map(
                    (grad) => DropdownMenuItem(
                      value: grad,
                      child: Text(grad),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onGradChanged(value);
              },
            ),
          ),
          const SizedBox(width: 8),
          // Vreme
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedVreme,
              decoration: const InputDecoration(
                labelText: 'Vreme',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              items: vremena
                  .map(
                    (vreme) => DropdownMenuItem(
                      value: vreme,
                      child: Text(vreme),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onVremeChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
