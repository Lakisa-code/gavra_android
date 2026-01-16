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
  final String? status; // 🆕 pending, confirmed, waiting, null
  final String? dayName; // 🆕 Dan u nedelji (pon, uto, sre...) za zaključavanje prošlih dana
  final bool isCancelled; // 🆕 Da li je otkazan (crveno)
  final String? tipPutnika; // 🆕 Tip putnika: radnik, ucenik, dnevni

  const TimePickerCell({
    Key? key,
    required this.value,
    required this.isBC,
    required this.onChanged,
    this.width = 70,
    this.height = 40,
    this.status,
    this.dayName,
    this.isCancelled = false,
    this.tipPutnika,
  }) : super(key: key);

  /// Vraća DateTime za određeni dan u tekućoj nedelji
  DateTime? _getDateForDay() {
    if (dayName == null) return null;

    final now = DateTime.now();
    final todayWeekday = now.weekday;

    const daniMap = {
      'pon': 1,
      'uto': 2,
      'sre': 3,
      'cet': 4,
      'pet': 5,
      'sub': 6,
      'ned': 7,
    };

    final targetWeekday = daniMap[dayName!.toLowerCase()];
    if (targetWeekday == null) return null;

    // Razlika u danima od danas
    final diff = targetWeekday - todayWeekday;
    return DateTime(now.year, now.month, now.day).add(Duration(days: diff));
  }

  /// Da li je dan zaključan (prošao ili danas posle 18:00)
  /// 🆕 Za dnevne putnike: zaključano ako admin nije omogućio zakazivanje
  bool get isLocked {
    // 🆕 DNEVNI PUTNICI: proverava da li je admin omogućio zakazivanje
    if (tipPutnika == 'dnevni' && !isDnevniZakazivanjeAktivno) {
      return true;
    }

    if (dayName == null) return false;

    final dayDate = _getDateForDay();
    if (dayDate == null) return false;

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);

    // Zaključaj ako je dan pre danas
    // TEMP TEST: Disable locking for past days
    if (dayDate.isBefore(todayOnly)) {
      return false; // TEMPORARY CHANGE: return false instead of true
    }

    // 🆕 Zaključaj današnji dan posle 19:00 (nema smisla zakazivati uveče za isti dan)
    if (dayDate.isAtSameMomentAs(todayOnly) && now.hour >= 19) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hasTime = value != null && value!.isNotEmpty;
    final isPending = status == 'pending';
    final isWaiting = status == 'waiting';
    final locked = isLocked;

    debugPrint(
        '🎨 [TimePickerCell] value=$value, status=$status, isPending=$isPending, dayName=$dayName, locked=$locked, isCancelled=$isCancelled');

    // Boje za različite statuse
    Color borderColor = Colors.grey.shade300;
    Color bgColor = Colors.white;
    Color textColor = Colors.black87;

    // 🔴 OTKAZANO - crvena (prioritet nad svim ostalim) - bez obzira na locked
    if (isCancelled) {
      borderColor = Colors.red;
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade800;
    }
    // ⬜ PROŠLI DAN (nije otkazan) - sivo
    else if (locked) {
      borderColor = Colors.grey.shade400;
      bgColor = Colors.grey.shade200;
      textColor = Colors.grey.shade600;
    }
    // 🟠 PENDING - narandžasto
    else if (isPending) {
      borderColor = Colors.orange;
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade800;
    }
    // 🔵 WAITING - plavo
    else if (isWaiting) {
      borderColor = Colors.blue;
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade800;
    }

    return GestureDetector(
      onTap: (locked || isCancelled) ? null : () => _showTimePickerDialog(context),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: (isPending || isWaiting || isCancelled) ? 2 : 1,
          ),
        ),
        child: Center(
          child: hasTime
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCancelled) ...[
                      Icon(Icons.cancel, size: 12, color: textColor),
                      const SizedBox(width: 2),
                    ] else if (locked) ...[
                      Icon(Icons.check_circle, size: 12, color: Colors.green),
                      const SizedBox(width: 2),
                    ] else if (isPending) ...[
                      Icon(Icons.hourglass_empty, size: 12, color: textColor),
                      const SizedBox(width: 2),
                    ] else if (isWaiting) ...[
                      Icon(Icons.schedule, size: 12, color: textColor),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      value!,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: (isPending || isWaiting || locked || isCancelled) ? 12 : 14,
                      ),
                    ),
                  ],
                )
              : isCancelled
                  ? Icon(Icons.cancel, color: Colors.red.shade400, size: 18)
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
                      onTap: () async {
                        // Ako već postoji termin, pitaj za potvrdu
                        if (value != null && value!.isNotEmpty) {
                          final potvrda = await showDialog<bool>(
                            context: dialogContext,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Potvrda otkazivanja'),
                              content: const Text('Da li ste sigurni da želite da otkažete termin?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Ne'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Da', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (potvrda != true) return;
                        }
                        onChanged(null);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
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
