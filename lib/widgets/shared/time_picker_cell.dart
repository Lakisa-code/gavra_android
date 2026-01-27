import 'package:flutter/material.dart';

import '../../config/route_config.dart';
import '../../globals.dart';
import '../../helpers/gavra_ui.dart';
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
  final String? tipPrikazivanja; // 🆕 Režim prikaza: standard, DNEVNI
  final DateTime? datumKrajaMeseca; // 🆕 Datum do kog je plaćeno

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
    this.tipPrikazivanja,
    this.datumKrajaMeseca,
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

  /// Da li je vreme za ovaj dan već prošlo (ne može se menjati, samo otkazati)
  bool _isTimePassed() {
    if (value == null || value!.isEmpty || dayName == null) return false;

    final now = DateTime.now();
    final dayDate = _getDateForDay();
    if (dayDate == null) return false;

    // Ako je dan u prošlosti - vreme je prošlo
    final todayOnly = DateTime(now.year, now.month, now.day);
    if (dayDate.isBefore(todayOnly)) return true;

          // Ako je današnji dan - proveri da li je vreme prošlo
    if (dayDate.isAtSameMomentAs(todayOnly)) {
      try {
        final timeParts = value!.split(':');
        if (timeParts.length == 2) {
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          final scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);

          // 🆕 LOCK 10 MINUTA PRE POLASKA
          final lockTime = scheduledTime.subtract(const Duration(minutes: 10));

          // Ako je trenutno vreme >= lockTime - blokiran
          return now.isAtSameMomentAs(lockTime) || now.isAfter(lockTime);
        }
      } catch (e) {
        debugPrint('⚠️ [TimePickerCell] Greška pri parsiranju vremena: $e');
      }
    }    return false;
  }

  /// Da li je dan zaključan (prošao ili danas posle 18:00)
  /// 🆕 Za dnevne putnike: zaključano ako admin nije omogućio zakazivanje, a ako jeste, SAMO tekući dan
  bool get isLocked {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final dayDate = _getDateForDay();

    // 1️⃣ LOGIKA ZA PLAĆANJE (Prioritet) - važi za radnike i učenike
    if (tipPutnika == 'radnik' || tipPutnika == 'ucenik') {
      if (datumKrajaMeseca != null) {
        // Da li je plaćeno za tekući mesec?
        // Plaćeno je ako je datumKrajaMeseca u tekućem mesecu ili u budućnosti
        final lastDayOfCurrentMonth = DateTime(now.year, now.month + 1, 0);
        final isPaidForCurrentMonth = !datumKrajaMeseca!.isBefore(lastDayOfCurrentMonth);

        // Od 11. u mesecu se zaključava ako nije plaćeno za tekući mesec
        if (now.day >= 11 && !isPaidForCurrentMonth) {
          return true;
        }
      }
    }

    // 🆕 POŠILJKE - Mogu se zakazivati kad god (danas i unapred), ne zavise od admin prekidača
    if (tipPutnika == 'posiljka') {
      if (dayDate != null && dayDate.isBefore(todayOnly)) return true;
      return false;
    }

    if (dayName == null) return false;
    if (dayDate == null) return false;

    // 2️⃣ OSNOVNA LOGIKA (vreme/dan)
    // Zaključaj ako je dan pre danas (prošlost)
    if (dayDate.isBefore(todayOnly)) {
      return true;
    }

    // Zaključaj današnji dan posle 19:00 (nema smisla zakazivati uveče za isti dan)
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
      onTap: () {
        if (isCancelled) return; // Otkazano - nema akcije

        final now = DateTime.now();

        // 🛡️ PROVERA PLAĆANJA I PORUKE (User requirement)
        if (tipPutnika == 'radnik' || tipPutnika == 'ucenik') {
          if (datumKrajaMeseca != null) {
            final lastDayOfCurrentMonth = DateTime(now.year, now.month + 1, 0);
            final lastDayOfPrevMonth = DateTime(now.year, now.month, 0);

            final isPaidForCurrentMonth = !datumKrajaMeseca!.isBefore(lastDayOfCurrentMonth);
            final isPaidForPrevMonth = !datumKrajaMeseca!.isBefore(lastDayOfPrevMonth);

            // 1. 27. u mesecu do kraja meseca - Podsetnik za tekući mesec
            if (now.day >= 27 && !isPaidForCurrentMonth) {
              final tekuciMesec = _getSerbianMonthName(now.month);
              GavraUI.showSnackBar(
                context,
                message: '🔔 podsecamo vas da imate neizmirena dugovanja za $tekuciMesec',
                type: GavraNotificationType.info,
              );
            }

            // 2. Od 01. do 10. u mesecu - Upozorenje za prethodni mesec
            if (now.day >= 1 && now.day <= 10 && !isPaidForPrevMonth) {
              GavraUI.showSnackBar(
                context,
                message: '⚠️ podsecamo vas da rok za placanje istice 10.',
                type: GavraNotificationType.warning,
              );
            }

            // 3. 11. u mesecu - Zaključavanje za prethodni mesec
            if (now.day >= 11 && !isPaidForPrevMonth) {
              GavraUI.showSnackBar(
                context,
                message: '🚫 zakazaivanja su onemogucena dok ne izmirite dugovanj',
                type: GavraNotificationType.error,
              );
              return; // Ključ u bravu
            }
          }
        }

        // 🚫 BLOKADA ZA PENDING STATUS - čeka se odgovor
        if (isPending) {
          GavraUI.showSnackBar(
            context,
            message: '⏳ Vaš zahtev je u obradi. Molimo sačekajte odgovor.',
            type: GavraNotificationType.warning,
          );
          return;
        }

        // 🚫 BLOKADA ZA WAITING STATUS - čeka se oslobađanje mesta
        if (isWaiting) {
          GavraUI.showSnackBar(
            context,
            message: '⏳ Vaš zahtev je na listi čekanja. Javićemo vam se kada se oslobodi mesto.',
            type: GavraNotificationType.info,
          );
          return;
        }

        // 🆕 EKSPLICITNA PORUKA DNEVNIM PUTNICIMA AKO JE ZAKLJUČANO
        if ((tipPutnika == 'dnevni' || tipPrikazivanja == 'DNEVNI') && isLocked) {
          final now = DateTime.now();
          final todayOnly = DateTime(now.year, now.month, now.day);
          final dayDate = _getDateForDay();

          if (!isDnevniZakazivanjeAktivno) {
            GavraUI.showSnackBar(
              context,
              message: '⛔ Zakazivanje trenutno nije omogućeno od strane administratora.',
              type: GavraNotificationType.error,
            );
          } else if (dayDate != null && !dayDate.isAtSameMomentAs(todayOnly)) {
            GavraUI.showSnackBar(
              context,
              message:
                  'Zbog optimizacije kapaciteta, rezervacije za dnevne putnike su moguće samo za tekući dan. Hvala na razumevanju! 🚌',
              type: GavraNotificationType.warning,
              duration: const Duration(seconds: 4),
            );
          }
          return;
        }

        // 🆕 PORUKA ZA POŠILJKE AKO JE ZAKLJUČANO (PROŠLOST)
        if (tipPutnika == 'posiljka' && isLocked) {
          GavraUI.showSnackBar(
            context,
            message: '⌛ Pošiljka se može zakazati samo za današnji polazak ili unapred.',
            type: GavraNotificationType.warning,
          );
          return;
        }

        if (locked) return; // Ostali slučajevi zaključavanja (npr. prošli dan)

        _showTimePickerDialog(context);
      },
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
                    ] else if (isPending) ...[
                      Icon(Icons.hourglass_empty, size: 12, color: textColor),
                      const SizedBox(width: 2),
                    ] else if (isWaiting) ...[
                      Icon(Icons.schedule, size: 12, color: textColor),
                      const SizedBox(width: 2),
                    ] else if (status == 'confirmed' || (hasTime && status == null)) ...[
                      // ✅ Zelena ikonica za confirmed status (eksplicitno ili implicitno kada nema statusa ali ima vreme)
                      Icon(Icons.check_circle, size: 12, color: Colors.green),
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
    final timePassed = _isTimePassed();

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
      builder: (dialogContext) {
        // 📅 PROVERA DANA - PETAK INFO DIALOG
        // Ako je danas petak, prikaži informativni tekst na vrhu dijaloga
        final now = DateTime.now();
        final isFriday = now.weekday == DateTime.friday;

        return Dialog(
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
                // ⚠️ VREME PROŠLO INFO BANER
                if (timePassed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: const Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_clock, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'VREME JE PROŠLO',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Možete samo da otkažete termin, izmena nije moguća.',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                // ⚠️ PETAK INFO BANER
                else if (isFriday)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: const Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'ZAOŠTRAVANJE RASPOREDA',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Izmene koje sada pravite važe za OVO zakazivanje. Za sledeću nedelju raspored možete uneti tek od subote ujutru.',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                // Title - sa ili bez paddinga zavisno od banera
                Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: (isFriday || timePassed) ? 12 : 16,
                    bottom: 16,
                  ),
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
                      // Option to clear (UVEK DOSTUPNO)
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
                      // Time options - BLOKIRANO AKO JE VREME PROŠLO
                      if (!timePassed)
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
                        })
                      else
                        // Poruka kada je vreme prošlo
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              '🔒 Izmena vremena nije moguća.\nMožete samo otkazati termin.',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
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
        );
      },
    );
  }

  String _getSerbianMonthName(int month) {
    const months = [
      'Januar',
      'Februar',
      'Mart',
      'April',
      'Maj',
      'Jun',
      'Jul',
      'Avgust',
      'Septembar',
      'Oktobar',
      'Novembar',
      'Decembar'
    ];
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }
}
