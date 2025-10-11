import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/mesecni_putnik_novi.dart' as novi_model;
import '../models/putnik.dart';
import '../services/geocoding_service.dart';
import '../services/haptic_service.dart';
import '../services/mesecni_putnik_service_novi.dart';
import '../services/permission_service.dart';
import '../services/putnik_service.dart';
import '../utils/vozac_boja.dart';

/// 🚨 PAŽNJA: Ovaj widget sada koristi nove tabele!
/// - mesecni_putnici za mesečne putnike (mesecnaKarta == true)
/// - putovanja_istorija za dnevne putnike (mesecnaKarta == false)
/// PutnikService koristi nove tabele

class PutnikCard extends StatefulWidget {
  // 🆕 Callback za UI refresh

  const PutnikCard({
    Key? key,
    required this.putnik,
    this.showActions = true,
    this.currentDriver,
    this.redniBroj,
    this.bcVremena,
    this.vsVremena,
    this.selectedVreme, // 🆕 Trenutno selektovano vreme polaska
    this.selectedGrad, // 🆕 Trenutno selektovani grad
    this.onChanged, // 🆕 Callback za UI refresh
  }) : super(key: key);
  final Putnik putnik;
  final bool showActions;
  final String? currentDriver;
  final int? redniBroj;
  final List<String>? bcVremena;
  final List<String>? vsVremena;
  final String? selectedVreme; // 🆕 Trenutno selektovano vreme polaska
  final String? selectedGrad; // 🆕 Trenutno selektovani grad
  final VoidCallback? onChanged;

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

  @override
  void didUpdateWidget(PutnikCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ KLJUČNO: Ažuriraj _putnik kada se promeni widget.putnik iz StreamBuilder-a
    if (widget.putnik != oldWidget.putnik) {
      _putnik = widget.putnik;
    }
  }

  String _formatVremeDodavanja(DateTime vreme) {
    return '${vreme.day.toString().padLeft(2, '0')}.${vreme.month.toString().padLeft(2, '0')}.${vreme.year}. '
        '${vreme.hour.toString().padLeft(2, '0')}:${vreme.minute.toString().padLeft(2, '0')}';
  }

  String _formatVreme(DateTime vreme) {
    return '${vreme.hour.toString().padLeft(2, '0')}:${vreme.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handlePokupljen() async {
    if (_putnik.vremePokupljenja == null && widget.showActions && !_putnik.jeOtkazan) {
      try {
        // PROVERI DA LI JE ID NULL
        if (_putnik.id == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Greška: ${_putnik.ime} nema validno ID za pokupljanje',
                ),
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
                  'NEVALJAN VOZAČ! Dozvoljen je samo: ${VozacBoja.validDrivers.join(", ")}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // 📳 Haptic feedback za uspešnu akciju
        HapticService.success();

        try {
          await PutnikService().oznaciPokupljen(_putnik.id!, widget.currentDriver!);

          // � FORSIRAJ UI REFRESH NA PARENT WIDGET
          if (mounted && widget.onChanged != null) {
            widget.onChanged!();
          }

          // 🆕 DODAJ KRATKU PAUZU pre dohvatanja (da se baza ažurira)
          await Future<void>.delayed(const Duration(milliseconds: 500));

          final updatedPutnik = await PutnikService().getPutnikFromAnyTable(_putnik.id!);
          if (updatedPutnik != null) {
            setState(() {
              _putnik = updatedPutnik;
            });

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
            // 🔥 IPAK FORSIRAJ UI AŽURIRANJE - POKUŠAJ JEDNOSTAVAN REFRESH
            if (mounted) {
              setState(() {
                // Jednostavno forsiranje rebuild-a widgeta
              });
            }
          }
        } catch (e) {
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
        // Long press = SAMO pokupljanje
        if (_putnik.vremePokupljenja == null) {
          await _handlePokupljen();

          // 🔄 FORSIRAJ PARENT WIDGET REFRESH
          if (mounted && widget.onChanged != null) {
            widget.onChanged!();
          }

          // 🔄 FORSIRAJ UI REFRESH za promenu boje kartice
          if (mounted) {
            setState(() {
              // Forsiranje rebuild-a za ažuriranje boje
            });
          }

          // 📳 Haptic feedback za pokupljanje - SUCCESS pattern!
          HapticService.success();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Putnik označen kao pokupljen (1.5s long press)'),
              ),
            );
          }
        }
      }
    });
  }

  // Brži admin reset sa triple tap
  void _handleTap() {
    // Samo za admin (Bojan i Svetlana) na kartice koje mogu da se resetuju
    if (!['Bojan', 'Svetlana'].contains(widget.currentDriver) || !_canResetCard()) {
      return;
    }

    _tapCount++;

    // Resetuj timer za tap sequence
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 600), () {
      _tapCount = 0; // Reset tap count nakon 600ms
    });

    // Triple tap = instant reset
    if (_tapCount >= 3) {
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
    final canReset = _putnik.jePokupljen || _putnik.jePlacen || _putnik.jeOtkazan;
    return canReset;
  }

  // Resetuje karticu u početno (belo) stanje
  Future<void> _handleResetCard() async {
    try {
      await PutnikService().resetPutnikCard(_putnik.ime, widget.currentDriver ?? '');

      // Malo sačekaj da se baza updateuje
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Refresh putnika iz baze
      final updatedPutnik = await PutnikService().getPutnikByName(_putnik.ime);
      if (updatedPutnik != null && mounted) {
        setState(() {
          _putnik = updatedPutnik;
        });
      } else {
        // Fallback: kreiraj novo stanje putnika sa resetovanim vrednostima
        setState(() {
          _putnik = Putnik(
            id: _putnik.id,
            ime: _putnik.ime,
            polazak: _putnik.polazak,
            pokupljen: false,
            vremeDodavanja: _putnik.vremeDodavanja,
            mesecnaKarta: _putnik.mesecnaKarta,
            dan: _putnik.dan,
            status: _putnik.mesecnaKarta == true ? 'radi' : 'nije_se_pojavio',
            placeno: false,
            iznosPlacanja: 0,
            dodaoVozac: _putnik.dodaoVozac,
            grad: _putnik.grad,
            adresa: _putnik.adresa,
            priority: _putnik.priority,
            brojTelefona: _putnik.brojTelefona,
          );
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kartica resetovana u početno stanje: ${_putnik.ime}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
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

  /// Prikaži opcije za kontakt (poziv i SMS)
  Future<void> _pozovi() async {
    final List<Widget> opcije = [];

    // Dohvati podatke o mesečnom putniku (ako je mesečni putnik)
    novi_model.MesecniPutnik? mesecniPutnik;
    if (_putnik.mesecnaKarta == true) {
      try {
        mesecniPutnik = await MesecniPutnikServiceNovi.getMesecniPutnikByIme(_putnik.ime);
      } catch (e) {
        // Ignoriši grešku, nastavi bez podataka o roditeljima
      }
    }

    // 🔥 NOVA OPCIJA: Automatsko SMS roditeljima za plaćanje (samo za mesečne putnike učenike)
    if (_putnik.mesecnaKarta == true &&
        mesecniPutnik != null &&
        mesecniPutnik.tip == 'ucenik' &&
        ((mesecniPutnik.brojTelefonaOca != null && mesecniPutnik.brojTelefonaOca!.isNotEmpty) ||
            (mesecniPutnik.brojTelefonaMajke != null && mesecniPutnik.brojTelefonaMajke!.isNotEmpty))) {
      opcije.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: ListTile(
            leading: const Icon(Icons.family_restroom, color: Colors.blue),
            title: const Text(
              '💰 SMS Roditeljima - Plaćanje',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Automatska poruka za plaćanje mesečne karte'),
            onTap: () async {
              Navigator.pop(context);
              if (mesecniPutnik != null) {
                await _posaljiSMSRoditeljimePlacanje(mesecniPutnik);
              }
            },
          ),
        ),
      );
    }

    // Glavni broj telefona putnika
    if (_putnik.brojTelefona != null && _putnik.brojTelefona!.isNotEmpty) {
      opcije.add(
        ListTile(
          leading: const Icon(Icons.phone, color: Colors.green),
          title: const Text('Pozovi putnika'),
          subtitle: Text(_putnik.brojTelefona!),
          onTap: () async {
            Navigator.pop(context);
            await _pozoviBroj();
          },
        ),
      );
      opcije.add(
        ListTile(
          leading: const Icon(Icons.sms, color: Colors.green),
          title: const Text('SMS putnik'),
          subtitle: Text(_putnik.brojTelefona!),
          onTap: () async {
            Navigator.pop(context);
            await _posaljiSMS(_putnik.brojTelefona!);
          },
        ),
      );
    }

    // Otac (ako postoji u mesečnim putnicima)
    if (mesecniPutnik != null && mesecniPutnik.brojTelefonaOca != null && mesecniPutnik.brojTelefonaOca!.isNotEmpty) {
      opcije.add(
        ListTile(
          leading: const Icon(Icons.man, color: Colors.blue),
          title: const Text('Pozovi oca'),
          subtitle: Text(mesecniPutnik.brojTelefonaOca!),
          onTap: () async {
            Navigator.pop(context);
            await _pozoviBrojRoditelja(mesecniPutnik!.brojTelefonaOca!);
          },
        ),
      );
      opcije.add(
        ListTile(
          leading: const Icon(Icons.sms, color: Colors.blue),
          title: const Text('SMS otac'),
          subtitle: Text(mesecniPutnik.brojTelefonaOca!),
          onTap: () async {
            Navigator.pop(context);
            await _posaljiSMS(mesecniPutnik!.brojTelefonaOca!);
          },
        ),
      );
    }

    // Majka (ako postoji u mesečnim putnicima)
    if (mesecniPutnik != null &&
        mesecniPutnik.brojTelefonaMajke != null &&
        mesecniPutnik.brojTelefonaMajke!.isNotEmpty) {
      opcije.add(
        ListTile(
          leading: const Icon(Icons.woman, color: Colors.pink),
          title: const Text('Pozovi majku'),
          subtitle: Text(mesecniPutnik.brojTelefonaMajke!),
          onTap: () async {
            Navigator.pop(context);
            await _pozoviBrojRoditelja(mesecniPutnik!.brojTelefonaMajke!);
          },
        ),
      );
      opcije.add(
        ListTile(
          leading: const Icon(Icons.sms, color: Colors.pink),
          title: const Text('SMS majka'),
          subtitle: Text(mesecniPutnik.brojTelefonaMajke!),
          onTap: () async {
            Navigator.pop(context);
            await _posaljiSMS(mesecniPutnik!.brojTelefonaMajke!);
          },
        ),
      );
    }

    if (opcije.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nema dostupnih kontakata')),
      );
      return;
    }

    if (!mounted) return;
    showModalBottomSheet<void>(
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
            ...opcije,
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

  /// Pozovi putnika na telefon
  Future<void> _pozoviBroj() async {
    if (_putnik.brojTelefona != null && _putnik.brojTelefona!.isNotEmpty) {
      try {
        // 📞 HUAWEI KOMPATIBILNO - koristi Huawei specifičnu logiku
        final hasPermission = await PermissionService.ensurePhonePermissionHuawei();
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

  /// Pozovi roditelja na telefon (otac ili majka)
  Future<void> _pozoviBrojRoditelja(String brojTelefona) async {
    try {
      // 📞 HUAWEI KOMPATIBILNO - koristi Huawei specifičnu logiku
      final hasPermission = await PermissionService.ensurePhonePermissionHuawei();
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

      final phoneUrl = Uri.parse('tel:$brojTelefona');
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

  /// Pošalji SMS
  Future<void> _posaljiSMS(String brojTelefona) async {
    final url = Uri.parse('sms:$brojTelefona');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Nije moguće poslati SMS'),
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

  /// 🔥 NOVA FUNKCIJA: Automatsko SMS roditeljima za plaćanje (samo za mesečne putnike učenike)
  Future<void> _posaljiSMSRoditeljimePlacanje(novi_model.MesecniPutnik mesecniPutnik) async {
    final List<String> roditelji = [];

    // Dodaj broj oca ako postoji
    if (mesecniPutnik.brojTelefonaOca != null && mesecniPutnik.brojTelefonaOca!.isNotEmpty) {
      roditelji.add(mesecniPutnik.brojTelefonaOca!);
    }

    // Dodaj broj majke ako postoji
    if (mesecniPutnik.brojTelefonaMajke != null && mesecniPutnik.brojTelefonaMajke!.isNotEmpty) {
      roditelji.add(mesecniPutnik.brojTelefonaMajke!);
    }

    if (roditelji.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Nema brojeva telefona roditelja za slanje SMS'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Kreiraj automatsku poruku za plaćanje
    final DateTime now = DateTime.now();
    final String mesec = _getMonthName(now.month);
    final String godina = now.year.toString();

    final String poruka = '🚌 GAVRA PREVOZ 🚌\n\n'
        'Podsetnik za plaćanje mesečne karte:\n\n'
        '👤 Putnik: ${_putnik.ime}\n'
        '📅 Mesec: $mesec $godina\n'
        '💰 Iznos: Prema dogovoru\n\n'
        '📞 Kontakt: Bojan - Gavra 013\n\n'
        'Hvala na razumevanju! 🚌\n'
        '---\n'
        'Automatska poruka.';

    int poslato = 0;
    for (String broj in roditelji) {
      try {
        final url = Uri.parse('sms:$broj?body=${Uri.encodeComponent(poruka)}');
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
          poslato++;

          // Pauza između SMS-ova
          if (roditelji.length > 1) {
            await Future<void>.delayed(const Duration(seconds: 1));
          }
        }
      } catch (e) {
        // Ignoriši greške i nastavi sa sledećim brojem
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            poslato > 0
                ? '✅ SMS za plaćanje poslat roditeljima ($poslato/${roditelji.length})'
                : '❌ Nije moguće poslati SMS roditeljima',
          ),
          backgroundColor: poslato > 0 ? Colors.green : Colors.red,
        ),
      );
    }
  }

  /// Helper - dobijanje naziva meseca na srpskom
  String _getMonthName(int month) {
    const List<String> months = [
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
      'Decembar',
    ];
    return months[month - 1];
  }

  // 💰 UNIVERZALNA METODA ZA PLAĆANJE - custom cena za sve tipove putnika
  Future<void> _handlePayment() async {
    if (_putnik.mesecnaKarta == true) {
      // MESEČNI PUTNIK - CUSTOM CENA umesto fiksne
      await _handleMesecniPayment();
    } else {
      // OBIČNI PUTNIK - unos custom iznosa
      await _handleObicniPayment();
    }
  }

  // 📅 PLAĆANJE MESEČNE KARTE - CUSTOM CENA (korisnik unosi iznos)
  Future<void> _handleMesecniPayment() async {
    // Prvo dohvati mesečnog putnika iz baze po imenu (ne po ID!)
    final mesecniPutnik = await MesecniPutnikServiceNovi.getMesecniPutnikByIme(_putnik.ime);

    if (mesecniPutnik == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška: Mesečni putnik "${_putnik.ime}" nije pronađen'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // ✅ NOVA LOGIKA - računa za ceo trenutni mesec (1. do 30.)
    final currentDate = DateTime.now();
    final firstDayOfMonth = DateTime(currentDate.year, currentDate.month);
    final lastDayOfMonth = DateTime(
      currentDate.year,
      currentDate.month + 1,
      0,
    ); // poslednji dan u mesecu

    // Broj putovanja za trenutni mesec
    int brojPutovanja = 0;
    int brojOtkazivanja = 0;
    try {
      brojPutovanja = await MesecniPutnikServiceNovi.izracunajBrojPutovanjaIzIstorije(
        _putnik.id! as String,
      );
      // ✅ NOVA LOGIKA - računaj otkazivanja iz stvarne istorije
      brojOtkazivanja = await MesecniPutnikServiceNovi.izracunajBrojOtkazivanjaIzIstorije(
        _putnik.id! as String,
      );
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
        String selectedMonth = '${_getMonthNameStatic(DateTime.now().month)} ${DateTime.now().year}';

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
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
                            Icon(
                              Icons.analytics,
                              color: Colors.blue[700],
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Statistike za trenutni mesec',
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
                            'Period: ${_formatDate(firstDayOfMonth)} - ${_formatDate(lastDayOfMonth)}',
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedMonth,
                        isExpanded: true,
                        items: _getMonthOptionsStatic().map((monthYear) {
                          // 💰 Proveri da li je mesec plaćen - ISTO kao u mesecni_putnici_screen.dart
                          final bool isPlacen = _isMonthPaidStatic(monthYear, mesecniPutnik);

                          return DropdownMenuItem<String>(
                            value: monthYear,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: isPlacen ? Colors.green : Colors.blue.shade300,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  monthYear,
                                  style: TextStyle(
                                    color: isPlacen ? Colors.green[700] : null,
                                    fontWeight: isPlacen ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newMonth) {
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
                        Icon(
                          Icons.info_outline,
                          color: Colors.green[700],
                          size: 16,
                        ),
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
      await _executePayment(
        result['iznos'] as double,
        mesec: result['mesec'] as String?,
        isMesecni: true,
      );
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
  Future<void> _executePayment(
    double iznos, {
    required bool isMesecni,
    String? mesec,
  }) async {
    try {
      print('🔍 [DEBUG PAYMENT] currentDriver: "${widget.currentDriver}"');
      print('🔍 [DEBUG PAYMENT] validDrivers: ${VozacBoja.validDrivers}');
      print(
        '🔍 [DEBUG PAYMENT] isValidDriver: ${VozacBoja.isValidDriver(widget.currentDriver)}',
      );

      // ⚠️ BLAŽU VALIDACIJU VOZAČA - dozvoli i null/prazan vozač sa fallback
      String finalDriver = widget.currentDriver ?? 'Nepoznat vozač';

      if (!VozacBoja.isValidDriver(widget.currentDriver)) {
        print(
          '⚠️ [DEBUG PAYMENT] Driver not valid, using fallback: "$finalDriver"',
        );

        // Umesto da prekidamo plaćanje, koristimo fallback vozača
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'UPOZORENJE: Nepoznat vozač! Plaćanje se evidentira kao "$finalDriver"',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        // ⚠️ Ne prekidamo - nastavljamo sa fallback vozačem
      }

      // Pozovi odgovarajući service za plaćanje
      if (isMesecni && mesec != null) {
        // Za mesečne putnike koristi funkciju iz mesecni_putnici_screen.dart
        print('🔍 [DEBUG PAYMENT] Tražim mesečnog putnika po imenu: ${_putnik.ime}');
        final mesecniPutnik = await MesecniPutnikServiceNovi.getMesecniPutnikByIme(_putnik.ime);
        if (mesecniPutnik != null) {
          print('🔍 [DEBUG PAYMENT] Pronašao mesečnog putnika: ${mesecniPutnik.putnikIme}, ID: ${mesecniPutnik.id}');
          // Koristi static funkciju kao u mesecni_putnici_screen.dart
          await _sacuvajPlacanjeStatic(
            putnikId: mesecniPutnik.id,
            iznos: iznos,
            mesec: mesec,
            vozacIme: finalDriver, // ✅ Koristi finalDriver umesto currentDriver
          );
        } else {
          print('❌ [DEBUG PAYMENT] Mesečni putnik ${_putnik.ime} nije pronađen!');
          throw Exception('Mesečni putnik ${_putnik.ime} nije pronađen u bazi');
        }
      } else {
        // Za obične putnike koristi postojeći servis
        await PutnikService().oznaciPlaceno(
          _putnik.id!,
          iznos,
          finalDriver,
        ); // ✅ Koristi finalDriver
      }

      if (mounted) {
        setState(() {});

        // 🔄 KLJUČNO: Pozovi callback za refresh parent widget-a
        if (widget.onChanged != null) {
          print('🔄 [DEBUG PAYMENT] Pozivam onChanged callback za refresh');
          widget.onChanged!();
        } else {
          print('⚠️ [DEBUG PAYMENT] onChanged callback nije definisan!');
        }

        // Prikaži success poruku
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMesecni
                  ? '✅ Mesečna karta plaćena: ${_putnik.ime} (${iznos.toStringAsFixed(0)} RSD)'
                  : '✅ Putovanje plaćeno: ${_putnik.ime} (${iznos.toStringAsFixed(0)} RSD)',
            ),
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
        _putnik.id!,
        status,
        widget.currentDriver ?? '',
      );

      if (mounted) {
        setState(() {});
        final String statusLabel = status == 'godisnji' ? 'godišnji odmor' : 'bolovanje';
        final String emoji = status == 'godisnji' ? '🏖️' : '🤒';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$emoji ${_putnik.ime} je postavljen na $statusLabel'),
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
      final apiKoordinate = await GeocodingService.getKoordinateZaAdresu(grad, adresa);
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
          'Nijedna navigacijska aplikacija nije dostupna. Poslednja greška: $poslednjaNGreska',
        );
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
    // Proverava uslove za prikazivanje X ikone
    if (_putnik.ime == 'Ljilla') {}

    // Uklonjen warning za nekorišćenu promenljivu driverColor
    final bool isSelected = _putnik.jePokupljen; // Koristi getter umesto direktno vremePokupljenja
    final bool isMesecna = _putnik.mesecnaKarta == true;
    final bool isPlaceno = (_putnik.iznosPlacanja ?? 0) > 0;
    // 🎨 NOVI REDOSLED BOJA - PREMA SPECIFIKACIJI:
    // 1. BELE - nepokupljeni (default)
    // 2. PLAVE - pokupljeni neplaćeni
    // 3. ZELENE - pokupljeni plaćeni/mesečni
    // 4. CRVENE - otkazane
    // 5. ŽUTE - godišnji/bolovanje (najveći prioritet)
    final Color cardColor = _putnik.jeOdsustvo
        ? const Color(
            0xFFFFF59D,
          ) // 🟡 ŽUTO za odsustvo (godišnji/bolovanje) - NAJVEĆI PRIORITET
        : _putnik.jeOtkazan
            ? const Color(0xFFFFE5E5) // 🔴 CRVENO za otkazane - DRUGI PRIORITET
            : (isSelected
                ? (isMesecna || isPlaceno
                    ? const Color(
                        0xFF388E3C,
                      ) // 🟢 ZELENO za mesečne/plaćene - TREĆI PRIORITET
                    : const Color(
                        0xFF7FB3D3,
                      )) // 🔵 PLAVO za pokupljene neplaćene - ČETVRTI PRIORITET
                : Colors.white.withOpacity(
                    0.96,
                  )); // ⚪ BELO za nepokupljene - PETI PRIORITET (default)

    // Prava po vozaču
    final String? driver = widget.currentDriver;
    final bool isBojan = driver == 'Bojan';
    final bool isSvetlana = driver == 'Svetlana';
    final bool isAdmin = isBojan || isSvetlana; // Full admin prava
    final bool isBrudaOrBilevski = driver == 'Bruda' || driver == 'Bilevski';

    if (_putnik.ime.toLowerCase().contains('rado') ||
        _putnik.ime.toLowerCase().contains('radoš') ||
        _putnik.ime.toLowerCase().contains('radosev')) {}

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
          gradient: _putnik.jeOdsustvo
              ? LinearGradient(
                  colors: [
                    const Color(0xFFFFF59D).withOpacity(
                      0.85,
                    ), // 🟡 ŽUTO za odsustvo - NAJVEĆI PRIORITET
                    const Color(0xFFFFF59D),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : _putnik.jeOtkazan
                  ? null // 🔴 CRVENO za otkazane - bez gradient-a
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.98),
                        isSelected
                            ? (isMesecna || isPlaceno
                                ? const Color(
                                    0xFF388E3C,
                                  ) // Zelena za mesečne/plaćene
                                : const Color(
                                    0xFF7FB3D3,
                                  )) // Plava za pokupljene neplaćene
                            : Colors.white.withOpacity(0.98),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _putnik.jeOdsustvo
                ? const Color(0xFFFFC107).withOpacity(
                    0.6,
                  ) // 🟡 ŽUTO border za odsustvo - NAJVEĆI PRIORITET
                : _putnik.jeOtkazan
                    ? Colors.red.withOpacity(0.25) // 🔴 CRVENO border za otkazane
                    : isSelected
                        ? (isMesecna || isPlaceno
                            ? const Color(0xFF388E3C).withOpacity(
                                0.4,
                              ) // 🟢 ZELENO border za mesečne/plaćene
                            : const Color(0xFF7FB3D3).withOpacity(
                                0.4,
                              )) // 🔵 PLAVO border za pokupljene neplaćene
                        : Colors.grey.withOpacity(0.10), // ⚪ BELO border za nepokupljene
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _putnik.jeOdsustvo
                  ? const Color(0xFFFFC107).withOpacity(
                      0.2,
                    ) // 🟡 ŽUTO shadow za odsustvo - NAJVEĆI PRIORITET
                  : _putnik.jeOtkazan
                      ? Colors.red.withOpacity(0.08) // 🔴 CRVENO shadow za otkazane
                      : isSelected
                          ? (isMesecna || isPlaceno
                              ? const Color(0xFF388E3C).withOpacity(
                                  0.15,
                                ) // 🟢 ZELENO shadow za mesečne/plaćene
                              : const Color(0xFF7FB3D3).withOpacity(
                                  0.15,
                                )) // 🔵 PLAVO shadow za pokupljene neplaćene
                          : Colors.black.withOpacity(
                              0.07,
                            ), // ⚪ BELO shadow za nepokupljene
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
                children: [
                  if (widget.redniBroj != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        '${widget.redniBroj}.',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: _putnik.jeOdsustvo
                              ? Colors.orange[600] // 🟡 ŽUTO za odsustvo - NAJVEĆI PRIORITET
                              : _putnik.jeOtkazan
                                  ? Colors.red[400] // 🔴 CRVENO za otkazane
                                  : isSelected
                                      ? (isMesecna || isPlaceno)
                                          ? Colors.green[600] // 🟢 ZELENO za mesečne/plaćene
                                          : const Color(
                                              0xFF0D47A1,
                                            ) // 🔵 PLAVO za pokupljene neplaćene
                                      : Colors.black, // ⚪ BELO za nepokupljene
                        ),
                      ),
                    ),
                  Icon(
                    Icons.person,
                    color: _putnik.jeOdsustvo
                        ? Colors.orange[600] // 🟡 ŽUTO za odsustvo - NAJVEĆI PRIORITET
                        : _putnik.jeOtkazan
                            ? Colors.red[400] // 🔴 CRVENO za otkazane
                            : isSelected
                                ? (isMesecna || isPlaceno)
                                    ? Colors.green[600] // 🟢 ZELENO za mesečne/plaćene
                                    : const Color(
                                        0xFF0D47A1,
                                      ) // 🔵 PLAVO za pokupljene neplaćene
                                : Colors.black, // ⚪ BELO za nepokupljene
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
                            color: _putnik.jeOdsustvo
                                ? Colors.orange[600] // 🟡 ŽUTO za odsustvo - NAJVEĆI PRIORITET
                                : _putnik.jeOtkazan
                                    ? Colors.red[400] // 🔴 CRVENO za otkazane
                                    : isSelected
                                        ? (isMesecna || isPlaceno)
                                            ? Colors.green[600] // 🟢 ZELENO za mesečne/plaćene
                                            : const Color(
                                                0xFF0D47A1,
                                              ) // 🔵 PLAVO za pokupljene neplaćene
                                        : Colors.black, // ⚪ BELO za nepokupljene
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        // Prikaži adresu ispod imena ako postoji
                        if (_putnik.adresa != null && _putnik.adresa!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _putnik.adresa!,
                              style: TextStyle(
                                fontSize: 12,
                                color: (_putnik.jeOtkazan
                                        ? Colors.red[300]
                                        : _putnik.jeOdsustvo
                                            ? Colors.orange[500] // 🟡 Oranž adresa za odsustvo
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
                  if ((isAdmin || isBrudaOrBilevski) && widget.showActions && (driver ?? '').isNotEmpty)
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
                                        padding: const EdgeInsets.only(bottom: 4),
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
                                  final bool isMaliEkran = availableWidth < 180; // povećao sa 170
                                  final bool isMiniEkran = availableWidth < 150; // povećao sa 140

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
                                      if (_putnik.adresa != null && _putnik.adresa!.isNotEmpty) ...[
                                        GestureDetector(
                                          onTap: () {
                                            showDialog<void>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.location_on,
                                                      color: Colors.blue,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        '📍 ${_putnik.ime}',
                                                        overflow: TextOverflow.ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                content: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Adresa za pokupljanje:',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      width: double.infinity,
                                                      padding: const EdgeInsets.all(
                                                        12,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: Colors.blue.withOpacity(
                                                            0.3,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        _putnik.adresa!,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                        overflow: TextOverflow.fade,
                                                        maxLines: 3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  // Dugme za navigaciju - uvek prikaži, koordinate će se dobiti po potrebi
                                                  TextButton.icon(
                                                    onPressed: () async {
                                                      // 🔒 INSTANT GPS - koristi novi PermissionService
                                                      final hasPermission =
                                                          await PermissionService.ensureGpsForNavigation();
                                                      if (!hasPermission) {
                                                        if (mounted && context.mounted) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                '❌ GPS dozvole su potrebne za navigaciju',
                                                              ),
                                                              backgroundColor: Colors.red,
                                                              duration: Duration(
                                                                seconds: 3,
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                        return;
                                                      }

                                                      // Proveri internetsku konekciju i dozvole
                                                      try {
                                                        // Pokaži loading sa dužim timeout-om
                                                        if (mounted && context.mounted) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            const SnackBar(
                                                              content: Row(
                                                                children: [
                                                                  SizedBox(
                                                                    width: 16,
                                                                    height: 16,
                                                                    child: CircularProgressIndicator(
                                                                      strokeWidth: 2,
                                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                                        Colors.white,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 10,
                                                                  ),
                                                                  Text(
                                                                    '🗺️ Pripremam navigaciju...',
                                                                  ),
                                                                ],
                                                              ),
                                                              duration: Duration(
                                                                seconds: 15,
                                                              ), // Duži timeout
                                                            ),
                                                          );
                                                        }

                                                        // Dobij koordinate (hibridno sa retry)
                                                        final koordinate = await _getKoordinateZaAdresu(
                                                          _putnik.grad,
                                                          _putnik.adresa,
                                                        );

                                                        if (mounted && context.mounted) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).hideCurrentSnackBar();

                                                          if (koordinate != null) {
                                                            // Uspešno - pokaži pozitivnu poruku
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(
                                                                content: Text(
                                                                  '✅ Otvaram navigaciju...',
                                                                ),
                                                                backgroundColor: Colors.green,
                                                                duration: Duration(
                                                                  seconds: 1,
                                                                ),
                                                              ),
                                                            );
                                                            await _otvoriNavigaciju(
                                                              koordinate,
                                                            );
                                                          } else {
                                                            // Neuspešno - pokaži detaljniju grešku
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(
                                                                content: Column(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    const Text(
                                                                      '❌ Lokacija nije pronađena',
                                                                    ),
                                                                    Text(
                                                                      'Adresa: ${_putnik.adresa}',
                                                                    ),
                                                                    const Text(
                                                                      '💡 Pokušajte ponovo za 10 sekundi',
                                                                    ),
                                                                  ],
                                                                ),
                                                                backgroundColor: Colors.orange,
                                                                action: SnackBarAction(
                                                                  label: 'POKUŠAJ PONOVO',
                                                                  textColor: Colors.white,
                                                                  onPressed: () {
                                                                    // Rekurzivno pozovi ponovo
                                                                    Future.delayed(
                                                                        const Duration(
                                                                          milliseconds: 500,
                                                                        ), () {
                                                                      // Pozovi ponovo
                                                                    });
                                                                  },
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      } catch (e) {
                                                        if (mounted && context.mounted) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).hideCurrentSnackBar();
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                '💥 Greška: ${e.toString()}',
                                                              ),
                                                              backgroundColor: Colors.red,
                                                              duration: const Duration(
                                                                seconds: 3,
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    },
                                                    icon: const Icon(
                                                      Icons.navigation,
                                                      color: Colors.blue,
                                                    ),
                                                    label: const Text(
                                                      'Navigacija',
                                                    ),
                                                    style: TextButton.styleFrom(
                                                      foregroundColor: Colors.blue,
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    child: const Text('Zatvori'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          child: Container(
                                            width: iconSize, // Adaptive veličina
                                            height: iconSize,
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Icon(
                                              Icons.location_on,
                                              color: Colors.blue,
                                              size: iconInnerSize, // Adaptive inner size
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 0,
                                        ), // Adaptive spacing - uvek 0
                                      ],
                                      // 📞 TELEFON IKONA - ako putnik ima telefon
                                      if (_putnik.brojTelefona != null && _putnik.brojTelefona!.isNotEmpty) ...[
                                        GestureDetector(
                                          onTap: _pozovi,
                                          child: Container(
                                            width: iconSize,
                                            height: iconSize,
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
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
                                      // 💰 IKONA ZA PLAĆANJE - za sve korisnike (3. po redu)
                                      if (!_putnik.jeOtkazan &&
                                          (_putnik.mesecnaKarta == true ||
                                              (_putnik.iznosPlacanja == null || _putnik.iznosPlacanja == 0))) ...[
                                        GestureDetector(
                                          onTap: () => _handlePayment(),
                                          child: Container(
                                            width: iconSize,
                                            height: iconSize,
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
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
                                      // ❌ IKS DUGME - za sve korisnike (4. po redu)
                                      // Vozači: direktno otkazivanje | Admini: popup sa opcijama
                                      if (!_putnik.jeOtkazan &&
                                          (_putnik.mesecnaKarta == true ||
                                              (_putnik.vremePokupljenja == null &&
                                                  (_putnik.iznosPlacanja == null || _putnik.iznosPlacanja == 0))))
                                        GestureDetector(
                                          onTap: () {
                                            if (isAdmin) {
                                              _showAdminPopup();
                                            } else {
                                              _handleOtkazivanje();
                                            }
                                          },
                                          child: Container(
                                            width: iconSize,
                                            height: iconSize,
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              color: Colors.orange,
                                              size: iconInnerSize,
                                            ),
                                          ),
                                        ),
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
                              return VozacBoja.get(_putnik.dodaoVozac);
                            }(),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _putnik.vremeDodavanja != null
                              ? _formatVremeDodavanja(_putnik.vremeDodavanja!)
                              : (_putnik.dodaoVozac?.isNotEmpty == true ? 'ranije' : 'sistem'),
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
                            'Otkazao:',
                            style: TextStyle(
                              fontSize: 13,
                              color: VozacBoja.get(_putnik.otkazaoVozac),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _putnik.otkazaoVozac?.isNotEmpty == true ? _putnik.otkazaoVozac! : 'sistem',
                            style: TextStyle(
                              fontSize: 13,
                              color: VozacBoja.get(_putnik.otkazaoVozac),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_putnik.statusVreme != null)
                            Text(
                              _formatVremeDodavanja(
                                DateTime.parse(_putnik.statusVreme!),
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: VozacBoja.get(_putnik.otkazaoVozac).withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    // Prikaz statusa bolovanja ili godišnjeg
                    if (_putnik.jeOdsustvo)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _putnik.jeBolovanje
                                ? 'Bolovanje'
                                : _putnik.jeGodisnji
                                    ? 'Godišnji'
                                    : 'Odsustvo',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    if (_putnik.vremePokupljenja != null)
                      Text(
                        () {
                          final vreme = _putnik.vremePokupljenja!;
                          return 'Pokupljen ${vreme.hour.toString().padLeft(2, '0')}:${vreme.minute.toString().padLeft(2, '0')}';
                        }(),
                        style: TextStyle(
                          fontSize: 13,
                          color: VozacBoja.get(
                            _putnik.pokupioVozac ?? widget.currentDriver,
                          ), // ✅ KORISTI pokupioVozac!
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (_putnik.iznosPlacanja != null && _putnik.iznosPlacanja! > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plaćeno ${_putnik.iznosPlacanja!.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: VozacBoja.get(_putnik.vozac),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_putnik.vozac != null && _putnik.vozac!.isNotEmpty)
                            Text(
                              'Naplatio: ${_putnik.vozac}${_putnik.vremePlacanja != null ? ' ${_formatVreme(_putnik.vremePlacanja!)}' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: VozacBoja.get(_putnik.vozac).withOpacity(0.8),
                                fontStyle: FontStyle.italic,
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

  // 💰 PROVERA DA LI JE MESEC PLAĆEN - TAČNO ISTO kao u mesecni_putnici_screen.dart
  bool _isMonthPaidStatic(
    String monthYear,
    novi_model.MesecniPutnik? mesecniPutnik,
  ) {
    if (mesecniPutnik == null) return false;

    if (mesecniPutnik.vremePlacanja == null || mesecniPutnik.cena == null || mesecniPutnik.cena! <= 0) {
      return false;
    }

    // Ako imamo precizne podatke o plaćenom mesecu, koristi ih
    if (mesecniPutnik.placeniMesec != null && mesecniPutnik.placenaGodina != null) {
      // Izvuci mesec i godinu iz string-a (format: "Septembar 2025")
      final parts = monthYear.split(' ');
      if (parts.length != 2) return false;

      final monthName = parts[0];
      final year = int.tryParse(parts[1]);
      if (year == null) return false;

      final monthNumber = _getMonthNumberStatic(monthName);
      if (monthNumber == 0) return false;

      // Proveri da li se plaćeni mesec i godina poklapaju
      return mesecniPutnik.placeniMesec == monthNumber && mesecniPutnik.placenaGodina == year;
    }

    return false; // Fallback
  }

  // HELPER FUNKCIJE - ISTO kao u mesecni_putnici_screen.dart
  static String _getMonthNameStatic(int month) {
    const months = [
      '',
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
      'Decembar',
    ];
    return months[month];
  }

  static int _getMonthNumberStatic(String monthName) {
    const months = {
      'Januar': 1,
      'Februar': 2,
      'Mart': 3,
      'April': 4,
      'Maj': 5,
      'Jun': 6,
      'Jul': 7,
      'Avgust': 8,
      'Septembar': 9,
      'Oktobar': 10,
      'Novembar': 11,
      'Decembar': 12,
    };
    return months[monthName] ?? 0;
  }

  static List<String> _getMonthOptionsStatic() {
    final now = DateTime.now();
    List<String> options = [];

    // Dodaj svih 12 meseci trenutne godine
    for (int month = 1; month <= 12; month++) {
      final monthYear = '${_getMonthNameStatic(month)} ${now.year}';
      options.add(monthYear);
    }

    return options;
  }

  // 💰 ČUVANJE PLAĆANJA - KOPIJA iz mesecni_putnici_screen.dart
  Future<void> _sacuvajPlacanjeStatic({
    required String putnikId,
    required double iznos,
    required String mesec,
    required String vozacIme,
  }) async {
    try {
      print(
        '🔍 [DEBUG SAVE PAYMENT] Started - putnikId: $putnikId, iznos: $iznos, mesec: $mesec, vozacIme: "$vozacIme"',
      );

      // Parsiraj izabrani mesec (format: "Septembar 2025")
      final parts = mesec.split(' ');
      if (parts.length != 2) {
        throw Exception('Neispravno format meseca: $mesec');
      }

      final monthName = parts[0];
      final year = int.tryParse(parts[1]);
      if (year == null) {
        throw Exception('Neispravna godina: ${parts[1]}');
      }

      final monthNumber = _getMonthNumberStatic(monthName);
      if (monthNumber == 0) {
        throw Exception('Neispravno ime meseca: $monthName');
      }

      // Kreiraj DateTime za početak izabranog meseca
      final pocetakMeseca = DateTime(year, monthNumber);
      final krajMeseca = DateTime(year, monthNumber + 1, 0, 23, 59, 59);

      print('🔍 [DEBUG SAVE PAYMENT] Calling azurirajPlacanjeZaMesec...');

      // Koristi metodu koja postavlja vreme plaćanja na trenutni datum
      final uspeh = await MesecniPutnikServiceNovi().azurirajPlacanjeZaMesec(
        putnikId,
        iznos,
        vozacIme,
        pocetakMeseca,
        krajMeseca,
      );

      print('🔍 [DEBUG SAVE PAYMENT] azurirajPlacanjeZaMesec result: $uspeh');

      if (uspeh) {
        print('🔄 [DEBUG SAVE PAYMENT] Plaćanje uspešno sačuvano');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Plaćanje od ${iznos.toStringAsFixed(0)} din za $mesec je sačuvano',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('❌ [DEBUG SAVE PAYMENT] Plaćanje nije uspešno sačuvano');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Greška pri čuvanju plaćanja'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [DEBUG SAVE PAYMENT] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🎯 ADMIN POPUP MENI - jedinstven pristup svim admin funkcijama
  void _showAdminPopup() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Admin opcije - ${_putnik.ime}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            // Opcije
            Column(
              children: [
                // Otkaži
                if (!_putnik.jeOtkazan)
                  ListTile(
                    leading: const Icon(Icons.close, color: Colors.orange),
                    title: const Text('Otkaži putnika'),
                    subtitle: const Text('Otkaži za trenutno vreme i datum'),
                    onTap: () {
                      Navigator.pop(context);
                      _handleOtkazivanje();
                    },
                  ),
                // Obriši
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Obriši putnika'),
                  subtitle: const Text('Trajno ukloni iz baze'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleBrisanje();
                  },
                ),
                // Godišnji/Bolovanje
                if (_putnik.mesecnaKarta == true && !_putnik.jeOtkazan && !_putnik.jeOdsustvo)
                  ListTile(
                    leading: const Icon(Icons.beach_access, color: Colors.orange),
                    title: const Text('Godišnji/Bolovanje'),
                    subtitle: const Text('Postavi odsustvo'),
                    onTap: () {
                      Navigator.pop(context);
                      _pokaziOdsustvoPicker();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // 🚫 OTKAZIVANJE - izdvojeno u funkciju
  Future<void> _handleOtkazivanje() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Otkazivanje putnika'),
        content: const Text(
          'Da li ste sigurni da želite da označite ovog putnika kao otkazanog?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ne'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Da'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await PutnikService().otkaziPutnika(
          _putnik.id!,
          widget.currentDriver ?? '',
          selectedVreme: widget.selectedVreme,
          selectedGrad: widget.selectedGrad,
        );

        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        // Greška pri otkazivanju putnika - ignorisana
      }
    }
  }

  // 🗑️ BRISANJE - izdvojeno u funkciju
  Future<void> _handleBrisanje() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Brisanje putnika'),
        content: const Text('Da li ste sigurni da želite da obrišete ovog putnika?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ne'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Da'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await PutnikService().obrisiPutnika(_putnik.id!);
      if (mounted) {
        setState(() {});
      }
    }
  }
} // kraj klase
