import 'package:flutter/material.dart';

import '../../globals.dart';
import '../../services/route_service.dart';
import '../../services/theme_manager.dart';
import '../../utils/app_snack_bar.dart';

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
  final String? status; // 🆕 pending, confirmed, null
  final String? dayName; // 🆕 Dan u nedelji (pon, uto, sre...) za zaključavanje prošlih dana
  final bool isCancelled; // 🆕 Da li je otkazan (crveno)
  final String? tipPutnika; // 🆕 Tip putnika: radnik, ucenik, dnevni
  final String? tipPrikazivanja; // 🆕 Režim prikaza: standard, DNEVNI
  final DateTime? datumKrajaMeseca; // 🆕 Datum do kog je plaćeno
  final bool isAdmin; // 🆕 Da li je admin (može da menja sve)

  const TimePickerCell({
    super.key,
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
    this.isAdmin = false,
  });

  // ─────────────────────────────────────────────────────────────────
  // CENTRALNA LOGIKA ZAKLJUČAVANJA
  //
  // Pravilo: ćelija je zaključana ako je trenutno vreme >= vreme polaska
  //          za taj dan u AKTIVNOJ nedelji.
  //
  // Aktivna nedelja:
  //   - sub >= 02:00 ili ned → pon-pet su u SLEDEĆOJ kalendarskoj nedelji
  //   - inače               → pon-pet su u TEKUĆOJ kalendarskoj nedelji
  //
  // Jedna metoda (_resolvePolazakDateTime) vraća tačan DateTime polaska.
  // Sve ostale metode koriste samo nju.
  // ─────────────────────────────────────────────────────────────────

  /// Vraća tačan DateTime polaska za ovaj widget (dan + vreme).
  /// Ako [vreme] nije prosleđen, koristi [value].
  /// Vraća null ako dayName ili vreme nisu dostupni/parsabilni.
  DateTime? _resolvePolazakDateTime({String? vreme}) {
    final v = vreme ?? value;
    if (dayName == null) return null;

    final now = DateTime.now();

    const daniMap = {'pon': 1, 'uto': 2, 'sre': 3, 'cet': 4, 'pet': 5, 'sub': 6, 'ned': 7};
    final targetWeekday = daniMap[dayName!.toLowerCase()];
    if (targetWeekday == null) return null;

    // Aktivna nedelja: sub >= 02:00 ili ned → sledeća nedelja
    final jeNovaNedelja = (now.weekday == 6 && now.hour >= 2) || now.weekday == 7;

    // Nađi ponedeljak aktivne nedelje
    late DateTime monday;
    if (jeNovaNedelja) {
      // Sledeći ponedeljak
      final daysToMonday = 8 - now.weekday; // sub(6)→2, ned(7)→1
      monday = DateTime(now.year, now.month, now.day).add(Duration(days: daysToMonday));
    } else {
      // Ponedeljak tekuće nedelje
      monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    }

    final dayDate = monday.add(Duration(days: targetWeekday - 1));

    // Ako nema vremena, vraćamo samo datum (bez sata) — za isLocked provjeru
    if (v == null || v.isEmpty) return dayDate;

    try {
      final parts = v.split(':');
      if (parts.length < 2) return dayDate;
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return DateTime(dayDate.year, dayDate.month, dayDate.day, h, m);
    } catch (_) {
      return dayDate;
    }
  }

  /// Ćelija je zaključana ako je vreme polaska nastupilo (now >= polazak).
  /// Bez vrednosti vremena: zaključano ako je dan u prošlosti.
  bool get isLocked {
    if (tipPutnika == 'posiljka') return false;
    if (dayName == null) return false;

    final polazak = _resolvePolazakDateTime();
    if (polazak == null) return false;

    final now = DateTime.now();

    if (value == null || value!.isEmpty) {
      // Nema zakazanog vremena — zaključano samo ako je dan prošao
      final dayOnly = DateTime(polazak.year, polazak.month, polazak.day);
      final todayOnly = DateTime(now.year, now.month, now.day);
      return dayOnly.isBefore(todayOnly);
    }

    // Ima zakazano vreme — zaključano čim nastupi vreme polaska
    return now.isAtSameMomentAs(polazak) || now.isAfter(polazak);
  }

  /// Da li je vreme polaska (value) nastupilo — alias za isLocked kada ima vrednost.
  bool _isTimePassed() => isLocked;

  /// Da li je specifično vreme u listi pickera već prošlo.
  bool _isSpecificTimePassed(String vreme) {
    if (dayName == null) return false;
    final polazak = _resolvePolazakDateTime(vreme: vreme);
    if (polazak == null) return false;
    final now = DateTime.now();
    return now.isAtSameMomentAs(polazak) || now.isAfter(polazak);
  }

  @override
  Widget build(BuildContext context) {
    final hasTime = value != null && value!.isNotEmpty;
    final isPending = status == 'pending' || status == 'manual';
    final isRejected = status == 'rejected';
    final isApproved = status == 'approved';
    final isConfirmed = status == 'confirmed';
    final locked = isAdmin ? false : isLocked;

    // debugPrint(
    //     '🎨 [TimePickerCell] value=$value, status=$status, isPending=$isPending, dayName=$dayName, locked=$locked, isCancelled=$isCancelled');

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
    // ❌ ODBIJENO - narandžasto/crvena ivica (da se razlikuje od otkazanog)
    else if (isRejected) {
      borderColor = Colors.orange.shade800;
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade900;
    }
    // ⬜ PROŠLI DAN (nije otkazan) - sivo
    else if (locked) {
      borderColor = Colors.grey.shade400;
      bgColor = Colors.grey.shade200;
      textColor = Colors.grey.shade600;
    }
    // 🟢 APPROVED ili CONFIRMED - zelena
    else if (isApproved || isConfirmed) {
      borderColor = Colors.green;
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade800;
    }
    // 🟠 PENDING - narandžasto (prioritet nad hasTime!)
    else if (isPending) {
      borderColor = Colors.orange;
      bgColor = Colors.orange.shade200; // Malo jača narandžasta
      textColor = Colors.orange.shade900;
    }
    // 🟢 IMA VREMENA - zelena (osnovna stanja - putnik je zakazao vreme)
    else if (hasTime) {
      borderColor = Colors.green;
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade800;
    }

    return GestureDetector(
      onTap: () async {
        // Omogućavamo otkazanim terminima da se ponovo aktiviraju ukoliko vreme nije prošlo
        if (isCancelled && _isTimePassed() && !isAdmin) return;

        // 🔒 VREME POLASKA JE NASTUPILO - zaključano do subote 02:00
        if (_isTimePassed() && !isAdmin) {
          AppSnackBar.warning(context, '🔒 Vreme polaska je nastupilo. Izmene nisu moguće do subote.');
          return;
        }

        final now = DateTime.now();

        // 🛡️ PROVERA PLAĆANJA I PORUKE (User requirement) - UKLONJENO

        // 🚫 BLOKADA ZA PENDING STATUS - čeka se odgovor (sprečavanje spama)
        if (isPending && !isAdmin) {
          AppSnackBar.warning(context, '⏳ Vaš zahtev je već u obradi. Molimo sačekajte odgovor.');
          return;
        }

        // ❌ BLOKADA ZA REJECTED STATUS - objasni korisniku
        if (isRejected && !isAdmin) {
          AppSnackBar.error(context, '❌ Ovaj termin je popunjen. Izaberite neko drugo slobodno vreme.');
          return;
        }

        // 🆕 UKLONJENA BLOKADA ZA APPROVED STATUS - dozvoljavamo otkazivanje
        // Putnik sada može da klikne na odobren termin i izabere "Bez polaska"

        // 🆕 EKSPLICITNA PORUKA DNEVNIM PUTNICIMA AKO JE ZAKLJUČANO
        if ((tipPutnika == 'dnevni' || tipPrikazivanja == 'DNEVNI') && isLocked && !isAdmin) {
          AppSnackBar.blocked(context,
              'Zbog optimizacije kapaciteta, rezervacije za dnevne putnike su moguće samo za tekući dan i sutrašnji dan. Hvala na razumevanju! 🚌');
          return;
        }

        if (locked && !isAdmin) {
          final msg = hasTime
              ? '🔒 Vreme polaska je nastupilo. Izmene nisu moguće do subote.'
              : '🔒 Zakazivanje za ovo vreme je prošlo. Od subote kreće novi ciklus.';
          AppSnackBar.warning(context, msg);
          return;
        }

        // 🆕 PROVERA ZA DNEVNE PUTNIKE - samo danas i sutra
        if ((tipPutnika == 'dnevni' || tipPrikazivanja == 'DNEVNI') && !isAdmin) {
          final now = DateTime.now();
          final todayOnly = DateTime(now.year, now.month, now.day);
          final tomorrowOnly = todayOnly.add(const Duration(days: 1));
          final dayDate = _resolvePolazakDateTime();
          if (dayDate != null) {
            final dayOnly = DateTime(dayDate.year, dayDate.month, dayDate.day);
            if (!dayOnly.isAtSameMomentAs(todayOnly) && !dayOnly.isAtSameMomentAs(tomorrowOnly)) {
              AppSnackBar.blocked(context,
                  'Zbog optimizacije kapaciteta, rezervacije za dnevne putnike su moguće samo za tekući dan i sutrašnji dan. Hvala na razumevanju! 🚌');
              return;
            }
          }
        }

        await _showTimePickerDialog(context);
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: (isPending || isCancelled) ? 2 : 1,
          ),
        ),
        child: Center(
          child: (hasTime || isPending || isRejected)
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCancelled) ...[
                      Icon(Icons.cancel, size: 12, color: textColor),
                      const SizedBox(width: 2),
                    ] else if (isRejected) ...[
                      // ❌ Ikonica za odbijen status
                      Icon(Icons.error_outline, size: 14, color: textColor),
                      const SizedBox(width: 2),
                    ] else if (isPending) ...[
                      Icon(Icons.hourglass_empty, size: 14, color: textColor),
                      const SizedBox(width: 2),
                    ] else if (isApproved) ...[
                      // ✅ Ikonica za approved status
                      Icon(Icons.check_circle, size: 12, color: textColor),
                      const SizedBox(width: 2),
                    ] else if (isConfirmed || (hasTime && status == null)) ...[
                      // ✅ Ikonica za confirmed status ili zakazane (implicitno kada nema statusa ali ima vreme)
                      Icon(Icons.check_circle, size: 12, color: textColor),
                      const SizedBox(width: 2),
                    ],
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasTime)
                            Text(
                              value!.split(':').take(2).join(':'),
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: (isPending || locked || isCancelled) ? 12 : 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          // "PENDING" text removed by user request
                        ],
                      ),
                    ),
                  ],
                )
              : Icon(
                  Icons.access_time,
                  color: textColor,
                  size: 18,
                ),
        ),
      ),
    );
  }

  Future<void> _showTimePickerDialog(BuildContext context) async {
    final timePassed = _isTimePassed();

    // Koristi navBarTypeNotifier za određivanje vremena (prati aktivan bottom nav bar)
    final navType = navBarTypeNotifier.value;
    List<String> vremena;

    // Mapiramo sezonu iz navType (AUTO je uklonjen)
    String sezona;
    if (navType == 'praznici') {
      sezona = 'praznici';
    } else if (navType == 'zimski') {
      sezona = 'zimski';
    } else {
      sezona = 'letnji'; // Default fallback je letnji
    }

    // Učitaj vremena iz RouteService
    final gradCode = isBC ? 'bc' : 'vs';

    // Učitaj vremena iz RouteService za sve korisnike (admin i putnici)
    // RouteService sada automatski vraća ispravna vremena iz RouteConfig-a
    vremena = await RouteService.getVremenaPolazaka(grad: gradCode, sezona: sezona);

    showDialog(
      context: context,
      builder: (dialogContext) {
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
                // ⚠️ VREME PROŠLO INFO BANER - samo ako nije admin
                if (timePassed && !isAdmin)
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
                  ),

                // Title - sa ili bez paddinga zavisno od banera
                Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: timePassed ? 12 : 16,
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
                      // "Bez polaska" - dostupno svima
                      // Admin: neutralno (bez_polaska), Putnik: računa se kao otkazivanje
                      ListTile(
                        title: Text(
                          'Bez polaska',
                          style: TextStyle(
                            color: isAdmin ? Colors.white70 : Colors.red.shade300,
                          ),
                        ),
                        leading: Icon(
                          value == null || value!.isEmpty ? Icons.check_circle : Icons.circle_outlined,
                          color: value == null || value!.isEmpty
                              ? Colors.green
                              : (isAdmin ? Colors.white54 : Colors.red.shade300),
                        ),
                        subtitle: !isAdmin
                            ? const Text(
                                '⚠️ Računa se kao otkazana vožnja',
                                style: TextStyle(color: Colors.orange, fontSize: 11),
                              )
                            : null,
                        onTap: () async {
                          if (value != null && value!.isNotEmpty) {
                            onChanged(null);
                            if (isAdmin) {
                              AppSnackBar.info(context, 'Vreme polaska je obrisano.');
                            } else {
                              AppSnackBar.warning(context, 'Vožnja otkazana. Evidentirano kao otkazivanje.');
                            }
                          } else {
                            AppSnackBar.info(context, 'Vreme polaska je već prazno.');
                          }
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                      ),
                      const Divider(color: Colors.white24),
                      // Time options - INDIVIDUALNO ZAKLJUČANA VREMENA
                      ...vremena.map((vreme) {
                        final isSelected = value == vreme;
                        final isTimePassedIndividual = _isSpecificTimePassed(vreme);
                        final isDisabled = !isAdmin && isTimePassedIndividual;

                        return ListTile(
                          enabled: !isDisabled,
                          title: Text(
                            vreme,
                            style: TextStyle(
                              color: isDisabled ? Colors.white38 : (isSelected ? Colors.white : Colors.white70),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              decoration: isDisabled ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          leading: Icon(
                            isDisabled ? Icons.lock_clock : (isSelected ? Icons.check_circle : Icons.circle_outlined),
                            color: isDisabled ? Colors.white38 : (isSelected ? Colors.green : Colors.white54),
                          ),
                          subtitle: isDisabled
                              ? const Text(
                                  '⏰ Vreme je prošlo',
                                  style: TextStyle(color: Colors.red, fontSize: 11),
                                )
                              : null,
                          onTap: isDisabled
                              ? null
                              : () {
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
        );
      },
    );
  }
}
