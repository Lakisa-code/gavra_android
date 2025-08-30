import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../models/putnik.dart';
import '../utils/vozac_boja.dart';
import '../services/putnik_service.dart';
import '../services/geocoding_service.dart';
import '../services/haptic_service.dart';
import '../services/mesecni_putnik_service.dart';
import '../services/permission_service.dart';

/// 🚨 PAŽNJA: Ovaj widget sada koristi nove tabele!
/// - mesecni_putnici za mesečne putnike (mesecnaKarta == true)
/// - putovanja_istorija za dnevne putnike (mesecnaKarta == false)
/// PutnikService koristi nove tabele

class PutnikCard extends StatefulWidget {
  final Putnik putnik;
  final bool showActions;
  final String? currentDriver;
  final int? redniBroj;
  final List<String>? bcVremena;
  final List<String>? vsVremena;

  const PutnikCard({
    Key? key,
    required this.putnik,
    this.showActions = true,
    this.currentDriver,
    this.redniBroj,
    this.bcVremena,
    this.vsVremena,
  }) : super(key: key);

  @override
  State<PutnikCard> createState() => _PutnikCardState();
}

class _PutnikCardState extends State<PutnikCard> {
  late Putnik _putnik;
  Timer? _longPressTimer;
  bool _isLongPressActive = false;

  // Za brži admin reset
  int _tapCount = 0;
  Timer? _tapTimer;

  @override
  void initState() {
    super.initState();
    _putnik = widget.putnik;
  }

  String _formatVremeDodavanja(DateTime vreme) {
    return '${vreme.day.toString().padLeft(2, '0')}.${vreme.month.toString().padLeft(2, '0')}.${vreme.year}. '
        '${vreme.hour.toString().padLeft(2, '0')}:${vreme.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handlePokupljen() async {
    debugPrint(
        '🔍 DEBUG _handlePokupljen POČETAK - ${_putnik.ime}: ID=${_putnik.id}, mesecnaKarta=${_putnik.mesecnaKarta}');

    if (_putnik.vremePokupljenja == null &&
        widget.showActions &&
        !_putnik.jeOtkazan) {
      try {
        // PROVERI DA LI JE ID NULL
        if (_putnik.id == null) {
          debugPrint(
              '❌ ERROR _handlePokupljen - ${_putnik.ime}: ID je null! Ne mogu da pozovem oznaciPokupljen');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Greška: ${_putnik.ime} nema validno ID za pokupljanje'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // STRIKTNA VALIDACIJA VOZAČA
        if (!VozacBoja.isValidDriver(widget.currentDriver)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'NEVALJAN VOZAČ! Dozvoljen je samo: ${VozacBoja.validDrivers.join(", ")}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // 📳 Haptic feedback za uspešnu akciju
        HapticService.success();

        debugPrint(
            '🔍 DEBUG _handlePokupljen - ${_putnik.ime}: pozivam oznaciPokupljen sa ID=${_putnik.id}, vozač=${widget.currentDriver}');

        try {
          debugPrint(
              '🔍 DEBUG _handlePokupljen - ${_putnik.ime}: POČETAK oznaciPokupljen poziva...');

          await PutnikService()
              .oznaciPokupljen(_putnik.id!, widget.currentDriver!);

          debugPrint(
              '🔍 DEBUG _handlePokupljen - ${_putnik.ime}: oznaciPokupljen ZAVRŠEN USPEŠNO');

          // 🔍 DEBUG: Loguj pokušaj ažuriranja
          debugPrint(
              '🔍 DEBUG _handlePokupljen - ${_putnik.ime}: pokušavam da dohvatim ažuriranog putnika iz baze');

          // 🆕 DODAJ KRATKU PAUZU pre dohvatanja (da se baza ažurira)
          await Future.delayed(const Duration(milliseconds: 500));

          // 🆕 KORISTI PUTNIK SERVICE da dohvati ažuriranog putnika
          final updatedPutnik =
              await PutnikService().getPutnikFromAnyTable(_putnik.id!);
          if (updatedPutnik != null) {
            debugPrint(
                '🔍 DEBUG _handlePokupljen - ${_putnik.ime}: dohvaćen ažurirani putnik sa vremePokupljenja=${updatedPutnik.vremePokupljenja}');

            // 🔥 FORSIRAJ UI AŽURIRANJE
            if (mounted) {
              setState(() {
                _putnik = updatedPutnik;
              });
              debugPrint(
                  '🔍 DEBUG _handlePokupljen - ${_putnik.ime}: setState() pozvan, UI treba biti ažuriran');
            }

            // 🎉 PRIKAZ USPEŠNE PORUKE
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ ${_putnik.ime} je pokupljen'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          } else {
            debugPrint(
                '❌ ERROR _handlePokupljen - ${_putnik.ime}: nije dohvaćen ažurirani putnik iz baze!');

            // 🔥 IPAK FORSIRAJ UI AŽURIRANJE - POKUŠAJ JEDNOSTAVAN REFRESH
            if (mounted) {
              debugPrint(
                  '🔍 DEBUG _handlePokupljen - ${_putnik.ime}: forsiran refresh putem setState()');
              setState(() {
                // Jednostavno forsiranje rebuild-a widgeta
              });
            }
          }
        } catch (e) {
          debugPrint(
              '❌ ERROR _handlePokupljen - ${_putnik.ime}: greška u oznaciPokupljen: $e');

          // 🚨 PRIKAZ GREŠKE KORISNIKU
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Greška pri pokupljanju ${_putnik.ime}: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        // Greška pri označavanju kao pokupljen
      }
    }
  }

  void _startLongPressTimer() {
    _isLongPressActive = true;
    _longPressTimer = Timer(const Duration(milliseconds: 1500), () async {
      if (_isLongPressActive) {
        // Ako je Bojan ili Svetlana i kartica nije u početnom stanju, resetuj je
        if (['Bojan', 'Svetlana'].contains(widget.currentDriver) &&
            _canResetCard()) {
          await _handleResetCard();
        }
        // Inače, ako nije pokupljen, označi kao pokupljen
        else if (_putnik.vremePokupljenja == null) {
          await _handlePokupljen();
          // 📳 Haptic feedback za pokupljanje - SUCCESS pattern!
          HapticService.success();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Putnik označen kao pokupljen (1.5s long press)')),
            );
          }
        }
      }
    });
  }

  // Brži admin reset sa triple tap
  void _handleTap() {
    debugPrint(
        '🔍 DEBUG _handleTap - ${_putnik.ime}: currentDriver="${widget.currentDriver}", canReset=${_canResetCard()}');

    // Samo za admin (Bojan i Svetlana) na kartice koje mogu da se resetuju
    if (!['Bojan', 'Svetlana'].contains(widget.currentDriver) ||
        !_canResetCard()) {
      debugPrint(
          '❌ TAP BLOCKED - ${_putnik.ime}: niet admin ili ne može reset');
      return;
    }

    _tapCount++;
    debugPrint('👆 TAP $_tapCount/3 - ${_putnik.ime}');

    // Resetuj timer za tap sequence
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 600), () {
      _tapCount = 0; // Reset tap count nakon 600ms
    });

    // Triple tap = instant reset
    if (_tapCount >= 3) {
      debugPrint('⚡ TRIPLE TAP RESET - ${_putnik.ime}: pokrećem reset!');
      _tapCount = 0;
      _tapTimer?.cancel();
      _handleResetCard();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ ADMIN RESET: ${_putnik.ime} (3x tap)'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  // Proverava da li se kartica može resetovati
  bool _canResetCard() {
    final canReset =
        _putnik.jePokupljen || _putnik.jePlacen || _putnik.jeOtkazan;
    debugPrint(
        '🔍 DEBUG _canResetCard - ${_putnik.ime}: jePokupljen=${_putnik.jePokupljen}, jePlacen=${_putnik.jePlacen}, jeOtkazan=${_putnik.jeOtkazan} => canReset=$canReset');
    return canReset;
  }

  // Resetuje karticu u početno (belo) stanje
  Future<void> _handleResetCard() async {
    try {
      debugPrint(
          '🔄 RESET CARD START - ${_putnik.ime}: pozivam resetPutnikCard');

      await PutnikService()
          .resetPutnikCard(_putnik.ime, widget.currentDriver ?? '');

      debugPrint(
          '✅ RESET CARD SUCCESS - ${_putnik.ime}: reset u service završen');

      // Refresh putnika iz baze
      final updatedPutnik = await PutnikService().getPutnikByName(_putnik.ime);
      if (updatedPutnik != null && mounted) {
        debugPrint(
            '🔄 RESET CARD REFRESH - ${_putnik.ime}: dobio ažurirane podatke iz baze');
        setState(() {
          _putnik = updatedPutnik;
        });
      } else {
        debugPrint(
            '❌ RESET CARD REFRESH FAILED - ${_putnik.ime}: nema ažuriranih podataka');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Kartica resetovana u početno stanje: ${_putnik.ime}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ RESET CARD ERROR - ${_putnik.ime}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri resetovanju kartice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Prikaži opcije za kontakt (poziv ili SMS)
  Future<void> _pozovi() async {
    if (_putnik.brojTelefona != null && _putnik.brojTelefona!.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kontaktiraj ${_putnik.ime}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.phone, color: Colors.green),
                title: const Text('Pozovi'),
                subtitle: Text(_putnik.brojTelefona!),
                onTap: () async {
                  Navigator.pop(context);
                  await _pozoviBroj();
                },
              ),
              ListTile(
                leading: const Icon(Icons.sms, color: Colors.blue),
                title: const Text('Pošalji SMS'),
                subtitle: Text(_putnik.brojTelefona!),
                onTap: () async {
                  Navigator.pop(context);
                  await _posaljiSMS();
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Otkaži'),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Pozovi putnika na telefon
  Future<void> _pozoviBroj() async {
    if (_putnik.brojTelefona != null && _putnik.brojTelefona!.isNotEmpty) {
      try {
        // 📞 HUAWEI KOMPATIBILNO - koristi Huawei specifičnu logiku
        final hasPermission =
            await PermissionService.ensurePhonePermissionHuawei();
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Dozvola za pozive je potrebna'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final phoneUrl = Uri.parse('tel:${_putnik.brojTelefona}');
        if (await canLaunchUrl(phoneUrl)) {
          await launchUrl(phoneUrl);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Nije moguće pozivanje sa ovog uređaja'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Greška pri pozivanju: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Pošalji SMS putiku
  Future<void> _posaljiSMS() async {
    if (_putnik.brojTelefona != null && _putnik.brojTelefona!.isNotEmpty) {
      try {
        // 📱 HUAWEI KOMPATIBILNO - koristi Huawei specifičnu logiku
        final hasPermission =
            await PermissionService.ensureSmsPermissionHuawei();
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Dozvola za SMS je potrebna'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final smsUrl = Uri.parse('sms:${_putnik.brojTelefona}');
        if (await canLaunchUrl(smsUrl)) {
          await launchUrl(smsUrl);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Nije moguće slanje SMS sa ovog uređaja'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Greška pri slanju SMS: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 💰 UNIVERZALNA METODA ZA PLAĆANJE - različita logika za obične i mesečne
  Future<void> _handlePayment() async {
    if (_putnik.mesecnaKarta == true) {
      // MESEČNI PUTNIK - direktna postavka mesečne cene
      await _handleMesecniPayment();
    } else {
      // OBIČNI PUTNIK - unos custom iznosa
      await _handleObicniPayment();
    }
  }

  // 📅 PLAĆANJE MESEČNE KARTE - proširena logika sa statistikama i mesecima
  Future<void> _handleMesecniPayment() async {
    // Prvo dohvati mesečnog putnika iz baze da dobijem statistike
    final mesecniPutnik =
        await MesecniPutnikService.getMesecniPutnikById(_putnik.id!);

    if (mesecniPutnik == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Greška: Mesečni putnik nije pronađen'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Izračunaj statistike od poslednjeg plaćanja do danas
    final currentDate = DateTime.now();
    final lastPaymentDate =
        mesecniPutnik.updatedAt; // ✅ KORISTI updated_at umesto datumPlacanja

    // Broj putovanja od poslednjeg plaćanja
    int brojPutovanja = 0;
    int brojOtkazivanja = 0;
    try {
      brojPutovanja =
          await MesecniPutnikService.izracunajBrojPutovanjaIzIstorije(
              _putnik.id!);
      // Za broj otkazivanja koristimo podatak iz modela jer nema specifičnu metodu
      brojOtkazivanja = mesecniPutnik.brojOtkazivanja;
    } catch (e) {
      // Fallback na podatke iz modela
      brojPutovanja = mesecniPutnik.brojPutovanja;
      brojOtkazivanja = mesecniPutnik.brojOtkazivanja;
    }

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        DateTime selectedMonth =
            DateTime(currentDate.year, currentDate.month, 1);

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.card_membership, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text('Mesečna karta'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Osnovne informacije
                  Text(
                    'Putnik: ${_putnik.ime}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Grad: ${_putnik.grad}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),

                  // 📊 STATISTIKE ODSEK
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.analytics,
                                color: Colors.blue[700], size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Statistike od poslednjeg plaćanja',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '🚗 Putovanja:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  '$brojPutovanja',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '❌ Otkazivanja:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  '$brojOtkazivanja',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (mesecniPutnik.jePlacen) ...[
                          // ✅ KORISTI jePlacen umesto datumPlacanja
                          const SizedBox(height: 6),
                          Text(
                            'Period: ${_formatDate(lastPaymentDate)} - ${_formatDate(currentDate)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // IZBOR MESECA
                  Text(
                    'Mesec za koji se plaća:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<DateTime>(
                        value: selectedMonth,
                        isExpanded: true,
                        items: _generateMonthOptions().map((month) {
                          return DropdownMenuItem<DateTime>(
                            value: month,
                            child: Text(_formatMonth(month)),
                          );
                        }).toList(),
                        onChanged: (DateTime? newMonth) {
                          if (newMonth != null) {
                            setState(() {
                              selectedMonth = newMonth;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // UNOS CENE
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Iznos (RSD)',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),

                  // INFO ODSEK
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.green[700], size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Možete platiti isti mesec više puta. Svako plaćanje se evidentira.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Odustani'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final value = double.tryParse(controller.text);
                  if (value != null && value > 0) {
                    Navigator.of(ctx).pop({
                      'iznos': value,
                      'mesec': selectedMonth,
                    });
                  }
                },
                icon: const Icon(Icons.payment),
                label: const Text('Potvrdi plaćanje'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result['iznos'] != null && mounted) {
      // Koristimo iznos koji je korisnik uneo u dialog
      await _executePayment(result['iznos'],
          isMesecni: true); // Koristi pravi iznos umesto fiksne vrednosti
    }
  }

  // 💵 PLAĆANJE OBIČNOG PUTNIKA - standardno
  Future<void> _handleObicniPayment() async {
    double? iznos = await showDialog<double>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text('Plaćanje putovanja'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Putnik: ${_putnik.ime}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Relacija: ${_putnik.grad}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              Text(
                'Polazak: ${_putnik.polazak}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Iznos (RSD)',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Odustani'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final value = double.tryParse(controller.text);
                if (value != null && value > 0) {
                  Navigator.of(ctx).pop(value);
                }
              },
              icon: const Icon(Icons.payment),
              label: const Text('Potvrdi plaćanje'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (iznos != null && iznos > 0) {
      await _executePayment(iznos, isMesecni: false);
    }
  }

  // 🎯 IZVRŠAVANJE PLAĆANJA - zajedničko za oba tipa
  Future<void> _executePayment(double iznos, {required bool isMesecni}) async {
    try {
      // STRIKTNA VALIDACIJA VOZAČA
      if (!VozacBoja.isValidDriver(widget.currentDriver)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'NEVALJAN VOZAČ! Dozvoljen je samo: ${VozacBoja.validDrivers.join(", ")}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Pozovi service za plaćanje
      await PutnikService()
          .oznaciPlaceno(_putnik.id!, iznos, widget.currentDriver!);

      if (mounted) {
        setState(() {});

        // Prikaži success poruku
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isMesecni
                ? '✅ Mesečna karta plaćena: ${_putnik.ime} (${iznos.toStringAsFixed(0)} RSD)'
                : '✅ Putovanje plaćeno: ${_putnik.ime} (${iznos.toStringAsFixed(0)} RSD)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška pri plaćanju: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelLongPressTimer() {
    _isLongPressActive = false;
    _longPressTimer?.cancel();
  }

  // 🏖️ Prikaži picker za odsustvo (godišnji/bolovanje)
  Future<void> _pokaziOdsustvoPicker() async {
    final String? odabraniStatus = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.beach_access, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Odsustvo putnika'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Izaberite tip odsustva za ${_putnik.ime}:',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            // Godišnji odmor dugme
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(ctx).pop('godisnji'),
                icon: const Icon(Icons.beach_access),
                label: const Text('🏖️ Godišnji odmor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Bolovanje dugme
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(ctx).pop('bolovanje'),
                icon: const Icon(Icons.sick),
                label: const Text('🤒 Bolovanje'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Odustani'),
          ),
        ],
      ),
    );

    if (odabraniStatus != null) {
      await _postaviOdsustvo(odabraniStatus);
    }
  }

  // 🎯 Postavi odsustvo za putnika
  Future<void> _postaviOdsustvo(String status) async {
    try {
      // Pozovi service za postavljanje statusa
      await PutnikService().oznaciBolovanjeGodisnji(
          _putnik.id!, status, widget.currentDriver ?? '');

      if (mounted) {
        setState(() {});

        final String statusLabel =
            status == 'godisnji' ? 'godišnji odmor' : 'bolovanje';
        final String emoji = status == 'godisnji' ? '🏖️' : '🤒';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('$emoji ${_putnik.ime} je postavljen na $statusLabel'),
            backgroundColor: status == 'godisnji' ? Colors.blue : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška pri postavljanju odsustva: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Dobija koordinate za adresu na osnovu grada i adrese (hibridni pristup)
  Future<String?> _getKoordinateZaAdresu(String? grad, String? adresa) async {
    if (grad == null || adresa == null) return null;

    // 1. Prvo proveri unapred definisane koordinate (brzo)
    const Map<String, Map<String, String>> predefinisaneKoordinate = {
      'Bela Crkva': {
        'VG': '44.880824,21.371678',
        'vg': '44.880824,21.371678',
      },
      'Vršac': {
        // Dodaj VS adrese ovde
      },
    };

    final predefinisane = predefinisaneKoordinate[grad]?[adresa];
    if (predefinisane != null) {
      return predefinisane;
    }

    // 2. Ako nema u predefinisanim, pozovi OpenStreetMap API
    try {
      final apiKoordinate =
          await GeocodingService.getKoordinateZaAdresu(grad, adresa);
      return apiKoordinate;
    } catch (e) {
      // API geocoding greška
      return null;
    }
  }

  // Otvara Google Maps navigaciju sa poboljšanim error handling-om
  Future<void> _otvoriNavigaciju(String koordinate) async {
    try {
      // 🛰️ INSTANT GPS - koristi novi PermissionService (bez dialoga)
      bool gpsReady = await PermissionService.ensureGpsForNavigation();
      if (!gpsReady) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.gps_off, color: Colors.white),
                  SizedBox(width: 8),
                  Text('❌ GPS nije dostupan - navigacija otkazana'),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final coords = koordinate.split(',');
      if (coords.length != 2) {
        throw Exception('Neispravne koordinate: $koordinate');
      }

      final lat = coords[0].trim();
      final lng = coords[1].trim();

      // Validuj da su koordinate brojevi
      final latNum = double.tryParse(lat);
      final lngNum = double.tryParse(lng);
      if (latNum == null || lngNum == null) {
        throw Exception('Koordinate nisu validni brojevi: $lat, $lng');
      }

      // 🚗 LISTA NAVIGACIJSKIH APLIKACIJA (Huawei/GBox kompatibilno)
      final navigacijeUrls = [
        // Google Maps (ako je dostupan)
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',

        // Petal Maps (Huawei)
        'petalmaps://route?daddr=$lat,$lng',

        // HERE WeGo (Huawei kompatibilan)
        'here-route://mylocation/$lat,$lng',

        // Waze
        'waze://?ll=$lat,$lng&navigate=yes',

        // Yandex Maps
        'yandexmaps://build_route_on_map?lat_to=$lat&lon_to=$lng',

        // Generic geo intent (Android fallback)
        'geo:$lat,$lng?q=$lat,$lng',

        // Browser fallback - uvek radi
        'https://maps.google.com/maps?q=$lat,$lng',
      ];

      bool uspesno = false;
      String poslednjaNGreska = '';

      // 🔄 POKUŠAJ REDOM SVE OPCIJE
      for (int i = 0; i < navigacijeUrls.length; i++) {
        try {
          final url = navigacijeUrls[i];
          final uri = Uri.parse(url);

          final canLaunch = await canLaunchUrl(uri);
          if (canLaunch) {
            final success = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );

            if (success) {
              uspesno = true;
              // 🎉 Pokaži potvrdu da je navigacija pokrenuta sa GPS-om
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.navigation, color: Colors.white),
                        SizedBox(width: 8),
                        Text('🛰️ Navigacija pokrenuta sa GPS-om'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              break;
            }
          }
        } catch (e) {
          poslednjaNGreska = e.toString();
          continue;
        }
      }

      if (!uspesno) {
        throw Exception(
            'Nijedna navigacijska aplikacija nije dostupna. Poslednja greška: $poslednjaNGreska');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('❌ Problem sa navigacijom'),
                Text('Greška: ${e.toString()}'),
                const Text('💡 Pokušajte instalirati:'),
                const Text('• Google Maps ili Petal Maps (Huawei)'),
                const Text('• HERE WeGo ili Waze'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'POKUŠAJ PONOVO',
              textColor: Colors.white,
              onPressed: () => _otvoriNavigaciju(koordinate),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _tapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔍 DEBUG: Dodaj debug ispis za pokupljene putnike
    if (_putnik.ime == 'Ljilla') {
      debugPrint(
          '🔍 DEBUG PutnikCard - ${_putnik.ime}: vremePokupljenja=${_putnik.vremePokupljenja}, jePokupljen=${_putnik.jePokupljen}');
    }

    // Uklonjen warning za nekorišćenu promenljivu driverColor
    final bool isSelected =
        _putnik.jePokupljen; // Koristi getter umesto direktno vremePokupljenja
    final bool isMesecna = _putnik.mesecnaKarta == true;
    final bool isPlaceno = (_putnik.iznosPlacanja ?? 0) > 0;
    final Color cardColor = _putnik.jeOtkazan
        ? const Color(0xFFFFE5E5) // ❌ Crveno za otkazane
        : _putnik.jeOdsustvo
            ? const Color(
                0xFFFFF59D) // 🏖️ Žuto za odsustvo (godišnji/bolovanje)
            : (isSelected
                ? (isMesecna || isPlaceno
                    ? const Color(0xFF388E3C) // ✅ Zeleno za mesečne/plaćene
                    : const Color(
                        0xFF7FB3D3)) // 🔵 Plavo za pokupljene neplaćene
                : Colors.white.withOpacity(0.96)); // ⚪ Belo za nepokupljene

    // Prava po vozaču
    final String? driver = widget.currentDriver;
    final bool isBojan = driver == 'Bojan';
    final bool isSvetlana = driver == 'Svetlana';
    final bool isAdmin = isBojan || isSvetlana; // Full admin prava
    final bool isBrudaOrBilevski = driver == 'Bruda' || driver == 'Bilevski';

    // 🔍 DEBUG LOG za Radošević problem (prošireno)
    if (_putnik.ime.toLowerCase().contains('rado') ||
        _putnik.ime.toLowerCase().contains('radoš') ||
        _putnik.ime.toLowerCase().contains('radosev')) {
      debugPrint(
          '🔍 RADOŠEVIĆ DEBUG: driver=$driver, isAdmin=$isAdmin, isBrudaOrBilevski=$isBrudaOrBilevski, showActions=${widget.showActions}');
      debugPrint(
          '🔍 RADOŠEVIĆ DEBUG: mesecnaKarta=${_putnik.mesecnaKarta}, jeOtkazan=${_putnik.jeOtkazan}, jePlacen=${_putnik.jePlacen}');
    }

    return GestureDetector(
      onTap: _handleTap, // Triple tap za brži admin reset
      onLongPressStart: (_) => _startLongPressTimer(),
      onLongPressEnd: (_) => _cancelLongPressTimer(),
      onLongPressCancel: _cancelLongPressTimer,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        decoration: BoxDecoration(
          gradient: _putnik.jeOtkazan
              ? null
              : _putnik.jeOdsustvo
                  ? LinearGradient(
                      colors: [
                        const Color(0xFFFFF59D)
                            .withOpacity(0.85), // 🏖️ Žuto za odsustvo
                        const Color(0xFFFFF59D),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.98),
                        isSelected
                            ? (isMesecna || isPlaceno
                                ? const Color(
                                    0xFF388E3C) // Zelena za mesečne/plaćene
                                : const Color(
                                    0xFF7FB3D3)) // Plava za pokupljene neplaćene
                            : Colors.white.withOpacity(0.98),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _putnik.jeOtkazan
                ? Colors.red.withOpacity(0.25)
                : _putnik.jeOdsustvo
                    ? const Color(0xFFFFC107)
                        .withOpacity(0.6) // 🏖️ Žuto za odsustvo
                    : isSelected
                        ? (isMesecna || isPlaceno
                            ? const Color(0xFF388E3C)
                                .withOpacity(0.4) // Zelena za mesečne/plaćene
                            : const Color(0xFF7FB3D3).withOpacity(
                                0.4)) // Plava za pokupljene neplaćene
                        : Colors.grey.withOpacity(0.10),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _putnik.jeOtkazan
                  ? Colors.red.withOpacity(0.08)
                  : _putnik.jeOdsustvo
                      ? const Color(0xFFFFC107)
                          .withOpacity(0.2) // 🏖️ Žuto za odsustvo
                      : isSelected
                          ? (isMesecna || isPlaceno
                              ? const Color(0xFF388E3C).withOpacity(
                                  0.15) // Zelena za mesečne/plaćene
                              : const Color(0xFF7FB3D3).withOpacity(
                                  0.15)) // Plava za pokupljene neplaćene
                          : Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (widget.redniBroj != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        '${widget.redniBroj}.',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: _putnik.jeOtkazan
                              ? Colors.red[400]
                              : isSelected
                                  ? (isMesecna || isPlaceno)
                                      ? (isMesecna
                                          ? Colors.green[600]
                                          : Colors.green[600])
                                      : const Color(0xFF0D47A1)
                                  : Colors.black,
                        ),
                      ),
                    ),
                  Icon(
                    Icons.person,
                    color: _putnik.jeOtkazan
                        ? Colors.red[400]
                        : isSelected
                            ? (isMesecna || isPlaceno)
                                ? (isMesecna
                                    ? Colors.green[600]
                                    : Colors.green[600])
                                : const Color(0xFF0D47A1)
                            : Colors.black,
                    size: 20,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _putnik.ime,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            fontSize: 15,
                            color: _putnik.jeOtkazan
                                ? Colors.red[400]
                                : isSelected
                                    ? (isMesecna || isPlaceno)
                                        ? (isMesecna
                                            ? Colors.green[600]
                                            : Colors.green[600])
                                        : const Color(0xFF0D47A1)
                                    : Colors.black,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        // Prikaži adresu ispod imena ako postoji
                        if (_putnik.adresa != null &&
                            _putnik.adresa!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _putnik.adresa!,
                              style: TextStyle(
                                fontSize: 12,
                                color: (_putnik.jeOtkazan
                                        ? Colors.red[300]
                                        : _putnik.jeOdsustvo
                                            ? Colors.orange[
                                                500] // 🟡 Oranž adresa za odsustvo
                                            : isSelected
                                                ? (isMesecna || isPlaceno)
                                                    ? Colors.green[500]
                                                    : const Color(0xFF0D47A1)
                                                : Colors.grey[600])
                                    ?.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 🎯 OPTIMIZOVANE ACTION IKONE - koristi Flexible + Wrap umesto fiksne širine
                  // da spreči overflow na manjim ekranima ili kada ima više ikona
                  if ((isAdmin || isBrudaOrBilevski) &&
                      widget.showActions &&
                      (driver ?? '').isNotEmpty)
                    Flexible(
                      child: Transform.translate(
                        offset: const Offset(-1, 0), // Pomera ikone levo za 1px
                        child: Container(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 📅 MESEČNA KARTA TEKST - sa fiksnom visinom da ne utiče na poravnavanje
                              SizedBox(
                                height: _putnik.mesecnaKarta == true ? 16 : 0,
                                child: _putnik.mesecnaKarta == true
                                    ? Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          '📅 MESEČNA KARTA',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700],
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              // 🎯 ULTRA-SAFE ADAPTIVE ACTION IKONE - potpuno eliminiše overflow
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  // Izračunaj dostupnu širinu za ikone
                                  final availableWidth = constraints.maxWidth;

                                  // Ultra-conservative prag sa safety margin - povećani pragovi
                                  final bool isMaliEkran =
                                      availableWidth < 180; // povećao sa 170
                                  final bool isMiniEkran =
                                      availableWidth < 150; // povećao sa 140

                                  // Tri nivoa adaptacije - značajno smanjene ikone za garantovano fitovanje u jedan red
                                  final double iconSize = isMiniEkran
                                      ? 20 // smanjio sa 22 za mini ekrane
                                      : (isMaliEkran
                                          ? 22 // smanjio sa 25 za male ekrane
                                          : 24); // smanjio sa 28 za normalne ekrane
                                  final double iconInnerSize = isMiniEkran
                                      ? 16 // smanjio sa 18
                                      : (isMaliEkran
                                          ? 18 // smanjio sa 21
                                          : 20); // smanjio sa 24

                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 📍 GPS IKONA ZA NAVIGACIJU - ako postoji adresa
                                      if (_putnik.adresa != null &&
                                          _putnik.adresa!.isNotEmpty) ...[
                                        GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Row(
                                                  children: [
                                                    const Icon(
                                                        Icons.location_on,
                                                        color: Colors.blue),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        '📍 ${_putnik.ime}',
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Adresa za pokupljanje:',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      width: double.infinity,
                                                      padding:
                                                          const EdgeInsets.all(
                                                              12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        border: Border.all(
                                                            color: Colors.blue
                                                                .withOpacity(
                                                                    0.3)),
                                                      ),
                                                      child: Text(
                                                        _putnik.adresa!,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                        overflow:
                                                            TextOverflow.fade,
                                                        maxLines: 3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  // Dugme za navigaciju - uvek prikaži, koordinate će se dobiti po potrebi
                                                  TextButton.icon(
                                                    onPressed: () async {
                                                      // Cache context pre async operacija
                                                      final cachedContext =
                                                          context;

                                                      // 🔒 INSTANT GPS - koristi novi PermissionService
                                                      final hasPermission =
                                                          await PermissionService
                                                              .ensureGpsForNavigation();
                                                      if (!hasPermission) {
                                                        if (mounted) {
                                                          // ignore: use_build_context_synchronously
                                                          ScaffoldMessenger.of(
                                                                  cachedContext)
                                                              .showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                  '❌ GPS dozvole su potrebne za navigaciju'),
                                                              backgroundColor:
                                                                  Colors.red,
                                                              duration:
                                                                  Duration(
                                                                      seconds:
                                                                          3),
                                                            ),
                                                          );
                                                        }
                                                        return;
                                                      }

                                                      // Proveri internetsku konekciju i dozvole
                                                      try {
                                                        // Pokaži loading sa dužim timeout-om
                                                        if (mounted) {
                                                          // ignore: use_build_context_synchronously
                                                          ScaffoldMessenger.of(
                                                                  cachedContext)
                                                              .showSnackBar(
                                                            const SnackBar(
                                                              content: Row(
                                                                children: [
                                                                  SizedBox(
                                                                    width: 16,
                                                                    height: 16,
                                                                    child:
                                                                        CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2,
                                                                      valueColor: AlwaysStoppedAnimation<
                                                                              Color>(
                                                                          Colors
                                                                              .white),
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                      width:
                                                                          10),
                                                                  Text(
                                                                      '🗺️ Pripremam navigaciju...'),
                                                                ],
                                                              ),
                                                              duration: Duration(
                                                                  seconds:
                                                                      15), // Duži timeout
                                                            ),
                                                          );
                                                        }

                                                        // Dobij koordinate (hibridno sa retry)
                                                        final koordinate =
                                                            await _getKoordinateZaAdresu(
                                                                _putnik.grad,
                                                                _putnik.adresa);

                                                        if (mounted) {
                                                          // ignore: use_build_context_synchronously
                                                          ScaffoldMessenger.of(
                                                                  cachedContext)
                                                              .hideCurrentSnackBar();

                                                          if (koordinate !=
                                                              null) {
                                                            // Uspešno - pokaži pozitivnu poruku
                                                            // ignore: use_build_context_synchronously
                                                            ScaffoldMessenger.of(
                                                                    cachedContext)
                                                                .showSnackBar(
                                                              const SnackBar(
                                                                content: Text(
                                                                    '✅ Otvaram navigaciju...'),
                                                                backgroundColor:
                                                                    Colors
                                                                        .green,
                                                                duration:
                                                                    Duration(
                                                                        seconds:
                                                                            1),
                                                              ),
                                                            );
                                                            await _otvoriNavigaciju(
                                                                koordinate);
                                                          } else {
                                                            // Neuspešno - pokaži detaljniju grešku
                                                            // ignore: use_build_context_synchronously
                                                            ScaffoldMessenger.of(
                                                                    cachedContext)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                content: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    const Text(
                                                                        '❌ Lokacija nije pronađena'),
                                                                    Text(
                                                                        'Adresa: ${_putnik.adresa}'),
                                                                    const Text(
                                                                        '💡 Pokušajte ponovo za 10 sekundi'),
                                                                  ],
                                                                ),
                                                                backgroundColor:
                                                                    Colors
                                                                        .orange,
                                                                duration:
                                                                    const Duration(
                                                                        seconds:
                                                                            4),
                                                                action:
                                                                    SnackBarAction(
                                                                  label:
                                                                      'POKUŠAJ PONOVO',
                                                                  textColor:
                                                                      Colors
                                                                          .white,
                                                                  onPressed:
                                                                      () {
                                                                    // Rekurzivno pozovi ponovo
                                                                    Future.delayed(
                                                                        const Duration(
                                                                            milliseconds:
                                                                                500),
                                                                        () {
                                                                      // Pozovi ponovo
                                                                    });
                                                                  },
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      } catch (e) {
                                                        if (mounted) {
                                                          // ignore: use_build_context_synchronously
                                                          ScaffoldMessenger.of(
                                                                  cachedContext)
                                                              .hideCurrentSnackBar();
                                                          // ignore: use_build_context_synchronously
                                                          ScaffoldMessenger.of(
                                                                  cachedContext)
                                                              .showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                  '💥 Greška: ${e.toString()}'),
                                                              backgroundColor:
                                                                  Colors.red,
                                                              duration:
                                                                  const Duration(
                                                                      seconds:
                                                                          3),
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    },
                                                    icon: const Icon(
                                                        Icons.navigation,
                                                        color: Colors.blue),
                                                    label: const Text(
                                                        'Navigacija'),
                                                    style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          Colors.blue,
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child:
                                                        const Text('Zatvori'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          child: Container(
                                            width:
                                                iconSize, // Adaptive veličina
                                            height: iconSize,
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.blue.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Icon(
                                              Icons.location_on,
                                              color: Colors.blue,
                                              size:
                                                  iconInnerSize, // Adaptive inner size
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                            width:
                                                0), // Adaptive spacing - uvek 0
                                      ],
                                      // 📞 TELEFON IKONA - ako putnik ima telefon
                                      if (_putnik.brojTelefona != null &&
                                          _putnik.brojTelefona!.isNotEmpty) ...[
                                        GestureDetector(
                                          onTap: _pozovi,
                                          child: Container(
                                            width: iconSize,
                                            height: iconSize,
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.green.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Icon(
                                              Icons.phone,
                                              color: Colors.green,
                                              size: iconInnerSize,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 0),
                                      ],
                                      // 🏖️ IKONA ZA GODIŠNJI/BOLOVANJE - samo za mesečne putnike koji rade
                                      if (_putnik.mesecnaKarta == true &&
                                          !_putnik.jeOtkazan &&
                                          !_putnik.jeOdsustvo &&
                                          isAdmin) ...[
                                        GestureDetector(
                                          onTap: () => _pokaziOdsustvoPicker(),
                                          child: Container(
                                            width: iconSize,
                                            height: iconSize,
                                            decoration: BoxDecoration(
                                              color: Colors.orange
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Icon(
                                              Icons.beach_access,
                                              color: Colors.orange,
                                              size: iconInnerSize,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 0),
                                      ],
                                      // 💰 JEDINSTVENA IKONA ZA PLAĆANJE - radi za sve tipove putnika
                                      if (!_putnik.jeOtkazan &&
                                          (_putnik.mesecnaKarta ==
                                                  true || // ✅ MESEČNI PUTNICI uvek mogu da se naplaćuju
                                              (_putnik.iznosPlacanja == null ||
                                                  _putnik.iznosPlacanja ==
                                                      0))) ...[
                                        GestureDetector(
                                          onTap: () async {
                                            await _handlePayment();
                                          },
                                          child: Container(
                                            width: iconSize,
                                            height: iconSize,
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.green.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Icon(
                                              Icons.attach_money,
                                              color: Colors.green,
                                              size: iconInnerSize,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 0),
                                      ],
                                      // Otkazivanje je moguće samo ako NIJE otkazan, NIJE pokupljen i za mesečne uvek
                                      if (!_putnik.jeOtkazan &&
                                          (_putnik.mesecnaKarta ==
                                                  true || // ✅ MESEČNI PUTNICI uvek mogu da se otkažu
                                              (_putnik.vremePokupljenja ==
                                                      null &&
                                                  (_putnik.iznosPlacanja ==
                                                          null ||
                                                      _putnik.iznosPlacanja ==
                                                          0))))
                                        if (isAdmin) ...[
                                          GestureDetector(
                                            onTap: () async {
                                              final confirm =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text(
                                                      'Otkazivanje putnika'),
                                                  content: const Text(
                                                      'Da li ste sigurni da želite da označite ovog putnika kao otkazanog?'),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(ctx)
                                                                .pop(false),
                                                        child:
                                                            const Text('Ne')),
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(ctx)
                                                                .pop(true),
                                                        child:
                                                            const Text('Da')),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                await PutnikService()
                                                    .otkaziPutnika(
                                                        _putnik.id!,
                                                        widget.currentDriver ??
                                                            '');
                                                if (mounted) {
                                                  // Realtime će automatski ažurirati UI
                                                }
                                              }
                                            },
                                            child: Container(
                                              width: iconSize,
                                              height: iconSize,
                                              decoration: BoxDecoration(
                                                color: Colors.orange
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Icon(
                                                Icons.close,
                                                color: Colors.orange,
                                                size: iconInnerSize,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 0),
                                          GestureDetector(
                                            onTap: () async {
                                              final confirm =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text(
                                                      'Brisanje putnika'),
                                                  content: const Text(
                                                      'Da li ste sigurni da želite da obrišete ovog putnika?'),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(ctx)
                                                                .pop(false),
                                                        child:
                                                            const Text('Ne')),
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(ctx)
                                                                .pop(true),
                                                        child:
                                                            const Text('Da')),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                await PutnikService()
                                                    .obrisiPutnika(_putnik.id!);
                                                if (mounted) setState(() {});
                                              }
                                            },
                                            child: Container(
                                              width: iconSize,
                                              height: iconSize,
                                              decoration: BoxDecoration(
                                                color:
                                                    Colors.red.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                                size: iconInnerSize,
                                              ),
                                            ),
                                          ),
                                        ] else ...[
                                          // Bruda i Bilevski: mogu samo otkazati SVE putnike (ne mogu da brišu)
                                          GestureDetector(
                                            onTap: () async {
                                              final confirm =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text(
                                                      'Otkazivanje putnika'),
                                                  content: const Text(
                                                      'Da li ste sigurni da želite da označite ovog putnika kao otkazanog?'),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(ctx)
                                                                .pop(false),
                                                        child:
                                                            const Text('Ne')),
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(ctx)
                                                                .pop(true),
                                                        child:
                                                            const Text('Da')),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                await PutnikService()
                                                    .otkaziPutnika(
                                                        _putnik.id!,
                                                        widget.currentDriver ??
                                                            '');
                                                if (mounted) {
                                                  // Realtime će automatski ažurirati UI
                                                }
                                              }
                                            },
                                            child: Container(
                                              width: iconSize,
                                              height: iconSize,
                                              decoration: BoxDecoration(
                                                color: Colors.orange
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Icon(
                                                Icons.close,
                                                color: Colors.orange,
                                                size: iconInnerSize,
                                              ),
                                            ),
                                          ),
                                        ],
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // Info row: Dodao, Pokupio, Plaćeno (jedan red)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.start,
                  spacing: 16,
                  runSpacing: 2,
                  children: [
                    // ✅ UVEK PRIKAŽI INFO O DODAVANJU - čak i kad nema podatke
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dodao:',
                          style: TextStyle(
                            fontSize: 13,
                            color: () {
                              // Debug log za praćenje dodaoVozac vrednosti
                              debugPrint(
                                  '🔍 DEBUG PutnikCard - ${_putnik.ime}: dodaoVozac = "${_putnik.dodaoVozac}", vremeDodavanja = ${_putnik.vremeDodavanja}');
                              return VozacBoja.get(_putnik.dodaoVozac);
                            }(),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _putnik.vremeDodavanja != null
                              ? _formatVremeDodavanja(_putnik.vremeDodavanja!)
                              : (_putnik.dodaoVozac?.isNotEmpty == true
                                  ? 'ranije'
                                  : 'sistem'),
                          style: TextStyle(
                            fontSize: 13,
                            color: VozacBoja.get(_putnik.dodaoVozac),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (_putnik.jeOtkazan)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Otkazano:',
                            style: TextStyle(
                              fontSize: 13,
                              color: VozacBoja.get(_putnik.otkazaoVozac),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _putnik.statusVreme != null
                                ? _formatVremeDodavanja(
                                    DateTime.parse(_putnik.statusVreme!))
                                : '-',
                            style: TextStyle(
                              fontSize: 13,
                              color: VozacBoja.get(_putnik.otkazaoVozac),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    if (_putnik.vremePokupljenja != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pokupljen',
                            style: TextStyle(
                              fontSize: 13,
                              color: VozacBoja.get(widget.currentDriver),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            () {
                              // 🔍 DEBUG: Ispis stvarnog vremena
                              final vreme = _putnik.vremePokupljenja!;
                              debugPrint(
                                  '🔍 DEBUG vremePokupljenja formatting - ${_putnik.ime}: vreme=$vreme, hour=${vreme.hour}, minute=${vreme.minute}');
                              return '${vreme.hour.toString().padLeft(2, '0')}:${vreme.minute.toString().padLeft(2, '0')}';
                            }(),
                            style: TextStyle(
                              fontSize: 13,
                              color: VozacBoja.get(widget.currentDriver),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    if (_putnik.iznosPlacanja != null &&
                        _putnik.iznosPlacanja! > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plaćeno:',
                            style: TextStyle(
                              fontSize: 13,
                              color: VozacBoja.get(_putnik.naplatioVozac),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _putnik.iznosPlacanja!.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 13,
                              color: VozacBoja.get(_putnik.naplatioVozac),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Status se prikazuje kroz ikone i boje (bolovanje/godišnji), 'radi' status se ne prikazuje
            ], // kraj children liste za Column
          ), // kraj Column
        ), // kraj Padding
      ), // kraj AnimatedContainer
    ); // kraj GestureDetector
  }

  // Helper metode za mesečno plaćanje
  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  String _formatMonth(DateTime date) {
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
    return '${months[date.month - 1]} ${date.year}';
  }

  List<DateTime> _generateMonthOptions() {
    final now = DateTime.now();
    final options = <DateTime>[];

    // Dodaj poslednja 3 meseca
    for (int i = 2; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      options.add(month);
    }

    // Dodaj sledeća 3 meseca
    for (int i = 1; i <= 3; i++) {
      final month = DateTime(now.year, now.month + i, 1);
      options.add(month);
    }

    return options;
  }
} // kraj klase
