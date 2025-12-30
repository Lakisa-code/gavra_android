import 'package:flutter/material.dart';

import '../../config/route_config.dart';
import '../../globals.dart';
import '../../services/theme_manager.dart';
import '../../utils/schedule_utils.dart';

/// UNIVERZALNI TIME PICKER CELL WIDGET
/// Koristi se za prikaz i izbor vremena polaska (BC ili VS)
///
/// Koristi se na:
/// - Dodaj putnika (RegistrovaniPutnikDialog)
/// - Uredi putnika (RegistrovaniPutnikDialog)
/// - Moj profil učenici (RegistrovaniPutnikProfilScreen)
/// - Moj profil radnici (RegistrovaniPutnikProfilScreen)
class TimePickerCell extends StatelessWidget {
  final String? value;
  final bool isBC;
  final ValueChanged<String?> onChanged;
  final double? width;
  final double? height;

  const TimePickerCell({
    Key? key,
    required this.value,
    required this.isBC,
    required this.onChanged,
    this.width = 70,
    this.height = 40,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasTime = value != null && value!.isNotEmpty;

    return GestureDetector(
      onTap: () => _showTimePickerDialog(context),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: hasTime
              ? Text(
                  value!,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                )
              : Icon(
                  Icons.access_time,
                  color: Colors.grey.shade400,
                  size: 18,
                ),
        ),
      ),
    );
  }

  void _showTimePickerDialog(BuildContext context) {
    // Koristi navBarTypeNotifier za određivanje vremena (prati aktivan bottom nav bar)
    final navType = navBarTypeNotifier.value;
    List<String> vremena;

    switch (navType) {
      case 'praznici':
        vremena = isBC ? RouteConfig.bcVremenaPraznici : RouteConfig.vsVremenaPraznici;
        break;
      case 'zimski':
        vremena = isBC ? RouteConfig.bcVremenaZimski : RouteConfig.vsVremenaZimski;
        break;
      case 'letnji':
        vremena = isBC ? RouteConfig.bcVremenaLetnji : RouteConfig.vsVremenaLetnji;
        break;
      default: // 'auto'
        final jeZimski = isZimski(DateTime.now());
        vremena = isBC
            ? (jeZimski ? RouteConfig.bcVremenaZimski : RouteConfig.bcVremenaLetnji)
            : (jeZimski ? RouteConfig.vsVremenaZimski : RouteConfig.vsVremenaLetnji);
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            gradient: ThemeManager().currentGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  isBC ? 'BC polazak' : 'VS polazak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Content
              SizedBox(
                height: 350,
                child: ListView(
                  children: [
                    // Option to clear
                    ListTile(
                      title: const Text(
                        'Bez polaska',
                        style: TextStyle(color: Colors.white70),
                      ),
                      leading: Icon(
                        value == null || value!.isEmpty ? Icons.check_circle : Icons.circle_outlined,
                        color: value == null || value!.isEmpty ? Colors.green : Colors.white54,
                      ),
                      onTap: () {
                        onChanged(null);
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                    const Divider(color: Colors.white24),
                    // Time options
                    ...vremena.map((vreme) {
                      final isSelected = value == vreme;
                      return ListTile(
                        title: Text(
                          vreme,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        leading: Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected ? Colors.green : Colors.white54,
                        ),
                        onTap: () {
                          onChanged(vreme);
                          Navigator.of(dialogContext).pop();
                        },
                      );
                    }),
                  ],
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Otkaži', style: TextStyle(color: Colors.white70)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
