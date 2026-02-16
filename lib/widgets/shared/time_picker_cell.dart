import 'package:flutter/material.dart';

import '../../globals.dart';
import '../../services/route_service.dart';
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
    final daysToAdd = diff == 0 ? 0 : (diff > 0 ? diff : diff + 7);
    return DateTime(now.year, now.month, now.day).add(Duration(days: daysToAdd));
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
    }
    return false;
  }

  /// Da li je dan zaključan (prošao ili danas posle 18:00)
  /// 🆕 Za dnevne putnike: zaključano ako admin nije omogućio zakazivanje, a ako jeste, SAMO tekući dan
  bool get isLocked {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final dayDate = _getDateForDay();

    // 🆕 POŠILJKE - Mogu se zakazivati uvek, ne zauzimaju mesto i ne podležu blokadama
    if (tipPutnika == 'posiljka') {
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
    final isPending = status == 'pending' || status == 'manual';
    final isRejected = status == 'rejected';
    final isApproved = status == 'approved';
    final isConfirmed = status == 'confirmed';
    final locked = isLocked;

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
        if (isCancelled && !isAdmin) return; // Otkazano - nema akcije (osim za admina)

        final now = DateTime.now();

        // 🛡️ PROVERA PLAĆANJA I PORUKE (User requirement) - UKLONJENO

        // 🚫 BLOKADA ZA PENDING STATUS - čeka se odgovor
        if (isPending && !isAdmin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⏳ Vaš zahtev je u obradi. Molimo sačekajte odgovor.')),
          );
          return;
        }

        // ❌ BLOKADA ZA REJECTED STATUS - objasni korisniku
        if (isRejected && !isAdmin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Ovaj termin je popunjen. Izaberite neko drugo slobodno vreme.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        // 🆕 UKLONJENA BLOKADA ZA APPROVED STATUS - dozvoljavamo otkazivanje
        // Putnik sada može da klikne na odobren termin i izabere "Bez polaska"

        // 🆕 EKSPLICITNA PORUKA DNEVNIM PUTNICIMA AKO JE ZAKLJUČANO
        if ((tipPutnika == 'dnevni' || tipPrikazivanja == 'DNEVNI') && isLocked && !isAdmin) {
          final now = DateTime.now();
          final todayOnly = DateTime(now.year, now.month, now.day);
          final dayDate = _getDateForDay();

          if (dayDate != null && !dayDate.isAtSameMomentAs(todayOnly)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Zbog optimizacije kapaciteta, rezervacije za dnevne putnike su moguće samo za tekući dan i sutrašnji dan. Hvala na razumevanju! 🚌'),
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        if (locked && !isAdmin) return; // Ostali slučajevi zaključavanja (npr. prošli dan)

        // 🆕 PROVERA ZA DNEVNE PUTNIKE - samo danas i sutra
        if ((tipPutnika == 'dnevni' || tipPrikazivanja == 'DNEVNI') && !isAdmin) {
          final now = DateTime.now();
          final todayOnly = DateTime(now.year, now.month, now.day);
          final tomorrowOnly = todayOnly.add(const Duration(days: 1));
          final dayDate = _getDateForDay();
          if (dayDate != null && !dayDate.isAtSameMomentAs(todayOnly) && !dayDate.isAtSameMomentAs(tomorrowOnly)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Zbog optimizacije kapaciteta, rezervacije za dnevne putnike su moguće samo za tekući dan i sutrašnji dan. Hvala na razumevanju! 🚌'),
                duration: Duration(seconds: 4),
              ),
            );
            return;
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

    // Mapiramo sezonu iz navType
    String sezona;
    switch (navType) {
      case 'praznici':
        sezona = 'praznici';
        break;
      case 'zimski':
        sezona = 'zimski';
        break;
      case 'letnji':
        sezona = 'letnji';
        break;
      default: // 'auto'
        final jeZimski = isZimski(DateTime.now());
        sezona = jeZimski ? 'zimski' : 'letnji';
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
                          // Uklonjena potvrda otkazivanja po zahtevu korisnika
                          // Proveri da li je vreme već prazno da izbegneš nepotrebni callback
                          if (value != null && value!.isNotEmpty) {
                            onChanged(null);
                            // Dodaj feedback korisniku
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vreme polaska je obrisano.')),
                            );
                          } else {
                            // Već je prazno, samo zatvori
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vreme polaska je već prazno.')),
                            );
                          }
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                      ),
                      const Divider(color: Colors.white24),
                      // Time options - BLOKIRANO AKO JE VREME PROŠLO (osim za admina)
                      if (!timePassed || isAdmin)
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
}
