// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/putnik.dart';
import '../models/registrovani_putnik.dart' as novi_model;
import '../services/adresa_supabase_service.dart';
import '../services/haptic_service.dart';
import '../services/permission_service.dart';
import '../services/putnik_service.dart';
import '../services/realtime_gps_service.dart';
import '../services/registrovani_putnik_service.dart';
import '../theme.dart';
import '../utils/card_color_helper.dart';
import '../utils/smart_colors.dart';
import '../utils/text_utils.dart';
import '../utils/vozac_boja.dart';

/// Widget za prikaz putnik kartice sa podrškom za mesečne i dnevne putnike

class PutnikCard extends StatefulWidget {
  const PutnikCard({
    Key? key,
    required this.putnik,
    this.showActions = true,
    required this.currentDriver,
    this.redniBroj,
    this.bcVremena,
    this.vsVremena,
    this.selectedVreme,
    this.selectedGrad,
    this.onChanged,
    this.onPokupljen,
  }) : super(key: key);
  final Putnik putnik;
  final bool showActions;
  final String currentDriver;
  final int? redniBroj;
  final List<String>? bcVremena;
  final List<String>? vsVremena;
  final String? selectedVreme;
  final String? selectedGrad;
  final VoidCallback? onChanged;
  final VoidCallback? onPokupljen;

  @override
  State<PutnikCard> createState() => _PutnikCardState();
}

class _PutnikCardState extends State<PutnikCard> {
  late Putnik _putnik;
  Timer? _longPressTimer;
  bool _isLongPressActive = false;
  bool _isProcessing = false; // 🔒 Sprečava duple klikove tokom procesiranja

  // 🔒 GLOBALNI LOCK - blokira SVE kartice dok jedan putnik nije završen u bazi
  static bool _globalProcessingLock = false;

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
    // 🔧 FIX: UVEK ažuriraj _putnik kada se widget promeni
    // Ovo garantuje da realtime promene (pokupljenje, otkazivanje, reset)
    // budu odmah vidljive bez obzira na == operator
    _putnik = widget.putnik;
  }

  // ignore: unused_element
  String _formatVremeDodavanja(DateTime vreme) {
    return '${vreme.day.toString().padLeft(2, '0')}.${vreme.month.toString().padLeft(2, '0')}.${vreme.year}. '
        '${vreme.hour.toString().padLeft(2, '0')}:${vreme.minute.toString().padLeft(2, '0')}';
  }

  // Format za otkazivanje - prikazuje vreme ako je danas, inače datum
  String _formatOtkazivanje(DateTime vreme) {
    final danas = DateTime.now();
    final jeDanas = vreme.year == danas.year && vreme.month == danas.month && vreme.day == danas.day;

    if (jeDanas) {
      // Danas - prikaži samo vreme
      return '${vreme.hour.toString().padLeft(2, '0')}:${vreme.minute.toString().padLeft(2, '0')}';
    } else {
      // Ranije - prikaži datum
      return '${vreme.day}.${vreme.month}.${vreme.year}';
    }
  }

  String _formatVreme(DateTime vreme) {
    return '${vreme.hour.toString().padLeft(2, '0')}:${vreme.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handlePokupljen() async {
    // 🔒 GLOBALNI LOCK - ako BILO KOJA kartica procesira, ignoriši
    if (_globalProcessingLock) return;
    // 🔒 ZAŠTITA OD DUPLOG KLIKA - ako već procesiramo, ignoriši
    if (_isProcessing) return;

    if (_putnik.vremePokupljenja == null && widget.showActions && !_putnik.jeOtkazan) {
      // Sačuvaj originalno ime pre bilo kakvih operacija
      final String originalnoIme = _putnik.ime;

      try {
        // PROVERI DA LI JE ID NULL
        if (_putnik.id == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SmartSnackBar.error(
                'Greška: $originalnoIme nema validno ID za pokupljanje',
                context,
              ),
            );
          }
          return;
        }

        // 🔒 POSTAVI OBA LOCK-A
        _globalProcessingLock = true;
        if (mounted) {
          setState(() {
            _isProcessing = true;
          });
        }

        // Uklonjena validacija vozača - prihvataju se svi vozači

        // ⏱️ SAČEKAJ 1.5 SEKUNDE - zaštita od slučajnog klika
        await Future<void>.delayed(const Duration(milliseconds: 1500));

        // Ako je korisnik otišao sa ekrana tokom čekanja, prekini
        if (!mounted) {
          _globalProcessingLock = false;
          return;
        }

        // 📳 Vibracija nakon 1.5s - potvrda da počinje procesiranje
        HapticService.putnikPokupljen();

        try {
          // ⏳ Baza radi
          await PutnikService()
              .oznaciPokupljen(_putnik.id!, widget.currentDriver, grad: _putnik.grad, selectedDan: _putnik.dan);

          // GPS LEARN: Sačuvaj koordinate ako adresa nema koordinate
          _tryGpsLearn();

          // FORSIRAJ UI REFRESH NA PARENT WIDGET
          if (mounted && widget.onChanged != null) {
            widget.onChanged!();
          }

          // DODAJ KRATKU PAUZU pre dohvatanja (da se baza ažurira)
          await Future<void>.delayed(const Duration(milliseconds: 500));

          final updatedPutnik = await PutnikService().getPutnikFromAnyTable(_putnik.id!);
          if (updatedPutnik != null && mounted) {
            if (mounted) {
              setState(() {
                _putnik = updatedPutnik;
                _isProcessing = false; // 🔓 Otključaj lokalni
              });
            }
            // 🔓 OTKLJUČAJ GLOBALNI - tek kad kartica pozeleni!
            _globalProcessingLock = false;

            // 🎉 PRIKAZ USPEŠNE PORUKE - koristi originalno ime
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SmartSnackBar.success('$originalnoIme je pokupljen', context),
              );
            }

            // NAJAVI SLEDEĆEG PUTNIKA (callback na danas_screen)
            if (widget.onPokupljen != null) {
              widget.onPokupljen!();
            }
          } else {
            // Forsiraj UI ažuriranje
            _globalProcessingLock = false; // 🔓 Otključaj globalni
            if (mounted) {
              setState(() {
                _isProcessing = false; // 🔓 Otključaj
              });
            }
          }
        } catch (e) {
          // ❌ GREŠKA - otključaj i prikaži grešku
          _globalProcessingLock = false; // 🔓 Otključaj globalni
          if (mounted) {
            setState(() {
              _isProcessing = false; // 🔓 Otključaj
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Greška pri pokupljanju $originalnoIme: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        // Greška pri označavanju kao pokupljen
        _globalProcessingLock = false; // 🔓 Otključaj globalni
        if (mounted) {
          setState(() {
            _isProcessing = false; // 🔓 Otključaj
          });
        }
      }
    }
  }

  /// GPS LEARN: Sačuvaj trenutnu GPS lokaciju za adresu putnika
  /// Ovo omogućava da sledeći put navigacija zna tačno gde je putnik pokupljen
  Future<void> _tryGpsLearn() async {
    try {
      // Proveri da li putnik ima adresaId
      final adresaId = _putnik.adresaId;
      if (adresaId == null || adresaId.isEmpty) {
        return; // Nema adresu za učenje
      }

      // Dobij trenutnu GPS lokaciju
      final position = await RealtimeGpsService.getCurrentPosition();

      // 📍 UPDATE DRIVER LOCATION (Admin Map)
      // Odmah pošalji lokaciju administratoru da zna da je putnik pokupljen baš OVDE

      // Sačuvaj koordinate u bazu
      final success = await AdresaSupabaseService.updateKoordinateFromGps(
        adresaId: adresaId,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (success && mounted) {
        // Opciono: pokaži diskretnu notifikaciju
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.location_on, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('📍 Lokacija naučena!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
    } catch (e) {
      // Silently ignore GPS learn errors - nije kritična funkcija
    }
  }

  void _startLongPressTimer() {
    _isLongPressActive = true;
    _longPressTimer = Timer(const Duration(milliseconds: 1500), () async {
      if (_isLongPressActive) {
        // Long press = SAMO pokupljanje

        if (_putnik.vremePokupljenja == null) {
          // 📳 JAKA VIBRACIJA ODMAH KAD SE AKTIVIRA (pre await)
          HapticService.heavyImpact();

          await _handlePokupljen();

          // FORSIRAJ PARENT WIDGET REFRESH
          if (mounted && widget.onChanged != null) {
            widget.onChanged!();
          }

          // FORSIRAJ UI REFRESH za promenu boje kartice
          if (mounted) {
            if (mounted) {
              setState(() {
                // Forsiranje rebuild-a za ažuriranje boje
              });
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Putnik pokupljen'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        }
      }
    });
  }

  // Brži admin reset sa triple tap
  void _handleTap() {
    // 🆕 DEBUG: Proveri ko je vozač i da li može da resetuje
    // ignore: avoid_print
    print('🔍 TAP: currentDriver="${widget.currentDriver}", canReset=${_canResetCard()}, tapCount=$_tapCount');

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
            content: Text('Admin reset: ${_putnik.ime} (3x tap)'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  // Proverava da li se kartica može resetovati
  bool _canResetCard() {
    // 👑 ADMIN JE TATA - može sve da resetuje
    if (['Bojan', 'Svetlana'].contains(widget.currentDriver)) {
      return true;
    }

    // Za ostale vozače - samo ako je nešto urađeno
    // Allow reset if putnik is marked as absent (bolovanje/godišnji)
    if (TextUtils.isStatusInCategory(_putnik.status, TextUtils.bolovanjeGodisnji)) {
      return true;
    }

    final canReset = _putnik.jePokupljen || _putnik.jePlacen || _putnik.jeOtkazan;
    return canReset;
  }

  // Resetuje karticu u početno (belo) stanje
  Future<void> _handleResetCard() async {
    try {
      // Prosleđuj selectedVreme i selectedGrad za tačan reset
      // ✅ FIX: Koristi _putnik.grad kao fallback ako selectedGrad nije prosleđen
      final gradZaReset = widget.selectedGrad ?? _putnik.grad;
      // ✅ FIX: Koristi _putnik.dan za tačan dan (ne današnji dan)
      final danZaReset = _putnik.dan.toLowerCase().substring(0, 3); // Pon -> pon
      // ignore: avoid_print
      print(
          '🔄 _handleResetCard: ime=${_putnik.ime}, grad=$gradZaReset, dan=$danZaReset, driver=${widget.currentDriver}');

      await PutnikService().resetPutnikCard(
        _putnik.ime,
        widget.currentDriver,
        selectedVreme: widget.selectedVreme,
        selectedGrad: gradZaReset,
        targetDan: danZaReset,
      );

      // Supabase realtime automatski triggeruje refresh
      // Malo sačekaj da se podaci propagiraju
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Refresh putnika iz baze - 🆕 prosleđujemo grad za tačan rezultat
      final updatedPutnik = await PutnikService().getPutnikByName(
        _putnik.ime,
        grad: widget.selectedGrad ?? _putnik.grad,
      );
      if (updatedPutnik != null && mounted) {
        setState(() {
          _putnik = updatedPutnik;
        });
      } else if (mounted) {
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
            status: 'radi', // Uvek radi kao početno stanje
            placeno: false,
            cena: 0,
            dodeljenVozac: _putnik.dodeljenVozac,
            grad: _putnik.grad,
            adresa: _putnik.adresa,
            priority: _putnik.priority,
            brojTelefona: _putnik.brojTelefona,
            otkazanZaPolazak: false, // 🆕 Reset otkazivanja
          );
        });
      }

      // OBAVESTI PARENT EKRAN DA OSVEŽI UI - KONZISTENTNO SA SVIM EKRANIMA
      if (mounted && widget.onChanged != null) {
        widget.onChanged!();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kartica resetovana u početno stanje: ${_putnik.ime}'),
            backgroundColor: Theme.of(context).colorScheme.warningPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri resetovanju kartice: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Prikaži opcije za kontakt (poziv i SMS)
  Future<void> _pozovi() async {
    final List<Widget> opcije = [];

    // Dohvati podatke o mesečnom putniku (ako je mesečni putnik)
    novi_model.RegistrovaniPutnik? registrovaniPutnik;
    if (_putnik.mesecnaKarta == true) {
      try {
        registrovaniPutnik = await RegistrovaniPutnikService.getRegistrovaniPutnikByIme(_putnik.ime);
      } catch (e) {
        // Ignoriši grešku, nastavi bez podataka o roditeljima
      }
    }

    // Glavni broj telefona putnika
    if (_putnik.brojTelefona != null && _putnik.brojTelefona!.isNotEmpty) {
      opcije.add(
        ListTile(
          leading: Icon(
            Icons.phone,
            color: Theme.of(context).colorScheme.successPrimary,
          ),
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
          leading: Icon(
            Icons.sms,
            color: Theme.of(context).colorScheme.successPrimary,
          ),
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
    if (registrovaniPutnik != null &&
        registrovaniPutnik.brojTelefonaOca != null &&
        registrovaniPutnik.brojTelefonaOca!.isNotEmpty) {
      opcije.add(
        ListTile(
          leading: Icon(Icons.man, color: Theme.of(context).colorScheme.primary),
          title: const Text('Pozovi oca'),
          subtitle: Text(registrovaniPutnik.brojTelefonaOca!),
          onTap: () async {
            Navigator.pop(context);

            await _pozoviBrojRoditelja(registrovaniPutnik!.brojTelefonaOca!);
          },
        ),
      );
      opcije.add(
        ListTile(
          leading: Icon(Icons.sms, color: Theme.of(context).colorScheme.primary),
          title: const Text('SMS otac'),
          subtitle: Text(registrovaniPutnik.brojTelefonaOca!),
          onTap: () async {
            Navigator.pop(context);

            await _posaljiSMS(registrovaniPutnik!.brojTelefonaOca!);
          },
        ),
      );
    }

    // Majka (ako postoji u mesečnim putnicima)
    if (registrovaniPutnik != null &&
        registrovaniPutnik.brojTelefonaMajke != null &&
        registrovaniPutnik.brojTelefonaMajke!.isNotEmpty) {
      opcije.add(
        ListTile(
          leading: const Icon(Icons.woman, color: Colors.pink),
          title: const Text('Pozovi majku'),
          subtitle: Text(registrovaniPutnik.brojTelefonaMajke!),
          onTap: () async {
            Navigator.pop(context);

            await _pozoviBrojRoditelja(registrovaniPutnik!.brojTelefonaMajke!);
          },
        ),
      );
      opcije.add(
        ListTile(
          leading: const Icon(Icons.sms, color: Colors.pink),
          title: const Text('SMS majka'),
          subtitle: Text(registrovaniPutnik.brojTelefonaMajke!),
          onTap: () async {
            Navigator.pop(context);

            await _posaljiSMS(registrovaniPutnik!.brojTelefonaMajke!);
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
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          decoration: TripleBlueFashionStyles.popupDecoration.copyWith(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kontaktiraj ${_putnik.ime}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              ...opcije,
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.shade400,
                      Colors.grey.shade600,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Otkaži',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pozovi putnika na telefon
  Future<void> _pozoviBroj() async {
    if (_putnik.brojTelefona != null && _putnik.brojTelefona!.isNotEmpty) {
      try {
        // HUAWEI KOMPATIBILNO - koristi Huawei specifičnu logiku
        final hasPermission = await PermissionService.ensurePhonePermissionHuawei();
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Dozvola za pozive je potrebna'),
                backgroundColor: Theme.of(context).colorScheme.error,
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
              SnackBar(
                content: const Text('Nije moguće pozivanje sa ovog uređaja'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Greška pri pozivanju: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  /// Pozovi roditelja na telefon (otac ili majka)
  Future<void> _pozoviBrojRoditelja(String brojTelefona) async {
    try {
      // HUAWEI KOMPATIBILNO - koristi Huawei specifičnu logiku
      final hasPermission = await PermissionService.ensurePhonePermissionHuawei();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Dozvola za pozive je potrebna'),
              backgroundColor: Theme.of(context).colorScheme.error,
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
            SnackBar(
              content: const Text('Nije moguće pozivanje sa ovog uređaja'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri pozivanju: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
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
            SnackBar(
              content: const Text('Nije moguće poslati SMS'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri slanju SMS: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // 💰 UNIVERZALNA METODA ZA PLAĆANJE - custom cena za sve tipove putnika
  Future<void> _handlePayment() async {
    // Validacija vozača pre pokušaja plaćanja
    final validni = ['Bruda', 'Bilevski', 'Bojan', 'Svetlana', 'Ivan'];
    if (!validni.contains(widget.currentDriver)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Greška: Vozač nije definisan'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    if (_putnik.mesecnaKarta == true) {
      // MESEČNI PUTNIK - CUSTOM CENA umesto fiksne
      await _handleRegistrovaniPayment();
    } else if (_putnik.isDnevniTip) {
      // DNEVNI PUTNIK - fiksna cena 600 RSD
      await _handleDnevniPayment();
    } else {
      // OBIČNI PUTNIK - unos custom iznosa
      await _handleObicniPayment();
    }
  }

  // 💵 PLAĆANJE DNEVNOG PUTNIKA - ukupna suma odjednom (YU auto, Pošiljka = 500 RSD po mestu)
  Future<void> _handleDnevniPayment() async {
    // YU auto i Pošiljka imaju specijalnu cenu od 500 RSD po mestu
    final double cenaPoMestu =
        (_putnik.tipPutnika == 'posiljka' || _putnik.ime.toLowerCase().contains('yu auto')) ? 500.0 : 600.0;

    final int brojMesta = _putnik.brojMesta;
    final double ukupnaSuma = cenaPoMestu * brojMesta;

    // Naplaćujemo sve odjednom
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline,
              width: 2,
            ),
          ),
          title: Row(
            children: [
              Icon(
                Icons.today,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Dnevna karta',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    if (brojMesta > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Ukupno za $brojMesta mesta:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${ukupnaSuma.toStringAsFixed(0)} RSD',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Odustani'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.payment),
              label: const Text('Potvrdi plaćanje'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // Provjeri da li putnik ima valjan ID
      if (_putnik.id == null || _putnik.id.toString().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Putnik nema valjan ID - ne može se naplatiti'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      // Izvrši plaćanje za sve odjednom
      await _executePayment(
        ukupnaSuma,
        isRegistrovani: false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Naplaćeno $brojMesta mesta - Ukupno: ${ukupnaSuma.toStringAsFixed(0)} RSD'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 📅 PLAĆANJE MESEČNE KARTE - CUSTOM CENA (korisnik unosi iznos)
  Future<void> _handleRegistrovaniPayment() async {
    // Prvo dohvati mesečnog putnika iz baze po imenu (ne po ID!)
    final registrovaniPutnik = await RegistrovaniPutnikService.getRegistrovaniPutnikByIme(_putnik.ime);

    if (registrovaniPutnik == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška: Mesečni putnik "${_putnik.ime}" nije pronađen'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    // UČITAJ SVA PLAĆANJA IZ BAZE za ovog putnika
    Set<String> placeniMeseci = {};
    try {
      final svaPlacanja = await RegistrovaniPutnikService().dohvatiPlacanjaZaPutnika(_putnik.ime);
      for (var placanje in svaPlacanja) {
        final mesec = placanje['placeniMesec'];
        final godina = placanje['placenaGodina'];
        if (mesec != null && godina != null) {
          // Format: "mesec-godina" za internu proveru
          placeniMeseci.add('$mesec-$godina');
        }
      }
    } catch (e) {
      // Ako ne možemo učitati, ostaje prazan set
    }

    // Računa za ceo trenutni mesec (1. do 30.)
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
      brojPutovanja = await RegistrovaniPutnikService.izracunajBrojPutovanjaIzIstorije(
        _putnik.id! as String,
      );
      // Računaj otkazivanja iz stvarne istorije
      brojOtkazivanja = await RegistrovaniPutnikService.izracunajBrojOtkazivanjaIzIstorije(
        _putnik.id! as String,
      );
    } catch (e) {
      // Greška pri čitanju - koristi 0
      brojPutovanja = 0;
      brojOtkazivanja = 0;
    }

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        String selectedMonth = '${_getMonthNameStatic(DateTime.now().month)} ${DateTime.now().year}';

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline,
                width: 2,
              ),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.card_membership,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Mesečna karta',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
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

                  // STATISTIKE ODSEK
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.analytics,
                              color: Theme.of(context).colorScheme.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Statistike za trenutni mesec',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
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
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.successPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Otkazivanja:',
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
                        if (placeniMeseci.isNotEmpty) ...[
                          // Prikaži period ako ima plaćanja
                          const SizedBox(height: 6),
                          Text(
                            'Period: ${_formatDate(firstDayOfMonth)} - ${_formatDate(lastDayOfMonth)}',
                            style: TextStyle(
                              fontSize: 12,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: TripleBlueFashionStyles.dropdownDecoration,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedMonth,
                        isExpanded: true,
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        items: _getMonthOptionsStatic().map((monthYear) {
                          // 💰 Proveri da li je mesec plaćen - KORISTI PODATKE IZ BAZE
                          final parts = monthYear.split(' ');
                          final monthNumber = _getMonthNumberStatic(parts[0]);
                          final year = int.tryParse(parts[1]) ?? 0;
                          final bool isPlacen = placeniMeseci.contains('$monthNumber-$year');

                          return DropdownMenuItem<String>(
                            value: monthYear,
                            child: Row(
                              children: [
                                Icon(
                                  isPlacen ? Icons.check_circle : Icons.calendar_today,
                                  size: 16,
                                  color: isPlacen
                                      ? Theme.of(context).colorScheme.successPrimary
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  monthYear,
                                  style: TextStyle(
                                    color: isPlacen ? Theme.of(context).colorScheme.successPrimary : null,
                                    fontWeight: isPlacen ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newMonth) {
                          if (newMonth != null) {
                            if (mounted) {
                              setState(() {
                                selectedMonth = newMonth;
                              });
                            }
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
                      color: Theme.of(context).colorScheme.successPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.successPrimary,
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
                  backgroundColor: Theme.of(context).colorScheme.successPrimary,
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
        isRegistrovani: true,
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
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline,
              width: 2,
            ),
          ),
          title: Row(
            children: [
              Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Plaćanje putovanja',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (iznos != null && iznos > 0) {
      // Provjeri da li putnik ima valjan ID
      if (_putnik.id == null || _putnik.id.toString().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Putnik nema valjan ID - ne može se naplatiti'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      try {
        await _executePayment(iznos, isRegistrovani: false);

        // Haptic feedback za uspešno plaćanje
        HapticService.lightImpact();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Greška pri plaćanju: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  // Izvršavanje plaćanja - zajedničko za oba tipa
  Future<void> _executePayment(
    double iznos, {
    required bool isRegistrovani,
    String? mesec,
  }) async {
    // 🔒 GLOBALNI LOCK - ako BILO KOJA kartica procesira, ignoriši
    if (_globalProcessingLock) return;
    // 🔒 ZAŠTITA OD DUPLOG KLIKA - ako već procesiramo, ignoriši
    if (_isProcessing) return;

    try {
      // 🔒 POSTAVI OBA LOCK-A
      _globalProcessingLock = true;
      if (mounted) {
        setState(() {
          _isProcessing = true;
        });
      }

      // ⏱️ SAČEKAJ 1.5 SEKUNDE - zaštita od slučajnog klika (isto kao kod pokupljanja)
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      // Ako je korisnik otišao sa ekrana tokom čekanja, prekini
      if (!mounted) {
        _globalProcessingLock = false;
        return;
      }

      // Pozovi odgovarajući service za plaćanje
      if (isRegistrovani && mesec != null) {
        // Validacija da putnik ime nije prazno
        if (_putnik.ime.trim().isEmpty) {
          throw Exception('Ime putnika je prazno - ne može se pronaći u bazi');
        }

        // Za mesečne putnike koristi funkciju iz registrovani_putnici_screen.dart
        final registrovaniPutnik = await RegistrovaniPutnikService.getRegistrovaniPutnikByIme(_putnik.ime);
        if (registrovaniPutnik != null) {
          // Koristi static funkciju kao u registrovani_putnici_screen.dart
          await _sacuvajPlacanjeStatic(
            putnikId: registrovaniPutnik.id,
            iznos: iznos,
            mesec: mesec,
            vozacIme: widget.currentDriver,
          );
        } else {
          throw Exception('Mesečni putnik "${_putnik.ime}" nije pronađen u bazi');
        }
      } else {
        // Za obične putnike koristi postojeći servis
        if (_putnik.id == null) {
          throw Exception('Putnik nema valjan ID - ne može se naplatiti');
        }

        // ✅ FIX: Šalji grad umesto place - oznaciPlaceno sada sam računa place
        // ISTO kao oznaciPokupljen - konzistentna logika!
        await PutnikService().oznaciPlaceno(
          _putnik.id!,
          iznos,
          widget.currentDriver,
          grad: _putnik.grad,
        );
      }

      if (mounted) {
        setState(() {
          _isProcessing = false; // Resetuj lokalni lock
        });
        _globalProcessingLock = false; // Resetuj globalni lock

        // Pozovi callback za refresh parent widget-a
        if (widget.onChanged != null) {
          widget.onChanged!();
        }

        // Prikaži success poruku
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRegistrovani
                  ? 'Mesečna karta plaćena: ${_putnik.ime} (${iznos.toStringAsFixed(0)} RSD)'
                  : 'Putovanje plaćeno: ${_putnik.ime} (${iznos.toStringAsFixed(0)} RSD)',
            ),
            backgroundColor: Theme.of(context).colorScheme.successPrimary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _globalProcessingLock = false;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri plaćanju: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _cancelLongPressTimer() {
    _isLongPressActive = false;
    _longPressTimer?.cancel();
  }

  // Prikaži picker za odsustvo (godišnji/bolovanje)
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
                  backgroundColor: Theme.of(context).colorScheme.primary,
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
                  backgroundColor: Theme.of(context).colorScheme.warningPrimary,
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

  // Postavi odsustvo za putnika
  Future<void> _postaviOdsustvo(String status) async {
    try {
      // DEBUG: Proveri ID pre poziva
      final putnikId = _putnik.id;
      if (putnikId == null || putnikId.isEmpty) {
        throw Exception('Putnik nema validan ID (id=$putnikId)');
      }

      // Pozovi service za postavljanje statusa
      await PutnikService().oznaciBolovanjeGodisnji(
        putnikId,
        status,
        widget.currentDriver,
      );

      if (mounted) {
        if (mounted) setState(() {});
        final String statusLabel = status == 'godisnji' ? 'godišnji odmor' : 'bolovanje';
        final String emoji = status == 'godisnji' ? '🏖️' : '🤒';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$emoji ${_putnik.ime} je postavljen na $statusLabel'),
            backgroundColor: status == 'godisnji' ? Colors.blue : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );

        // FORSIRAJ REFRESH LISTE
        if (widget.onChanged != null) {
          widget.onChanged!();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri postavljanju odsustva: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // Dobija koordinate za destinaciju - UNIFIKOVANO za sve putnike
  Future<String?> _getKoordinateZaAdresu(String? grad, String? adresa, String? adresaId) async {
    // PRIORITET 1: Ako imamo adresaId (UUID), direktno dohvati adresu sa koordinatama
    if (adresaId != null && adresaId.isNotEmpty) {
      try {
        final adresaObj = await AdresaSupabaseService.getAdresaByUuid(adresaId);
        if (adresaObj != null && adresaObj.hasValidCoordinates) {
          // Adresa ima koordinate - koristi ih direktno!
          return '${adresaObj.latitude},${adresaObj.longitude}';
        }

        // Ako nema koordinate, pokušaj pronaći po nazivu
        if (adresaObj != null && adresaObj.naziv.isNotEmpty) {
          final koordinate = await AdresaSupabaseService.findAdresaByNazivAndGrad(
            adresaObj.naziv,
            adresaObj.grad ?? grad ?? '',
          );
          if (koordinate?.hasValidCoordinates == true) {
            return '${koordinate!.latitude},${koordinate.longitude}';
          }
        }
      } catch (e) {
        // Nastavi sa fallback opcijama
      }
    }

    // PRIORITET 2: Ako imamo naziv adrese, traži u tabeli adrese
    if (adresa != null && adresa.isNotEmpty && adresa != 'Adresa nije definisana') {
      try {
        final koordinate = await AdresaSupabaseService.findAdresaByNazivAndGrad(adresa, grad ?? '');
        if (koordinate != null && koordinate.hasValidCoordinates) {
          return '${koordinate.latitude},${koordinate.longitude}';
        }
      } catch (e) {
        // Nastavi sa fallback opcijama
      }
    }

    // PRIORITET 3: Fallback na transport logiku (centar destinacije)
    // TRANSPORT LOGIKA: Navigiraj do centra destinacije
    // Svi iz Bela Crkva opštine → Vršac centar
    // Svi iz Vršac opštine → Bela Crkva centar
    const Map<String, String> destinacije = {
      'Bela Crkva': '45.1373,21.3056', // Vršac centar (destinacija za BC putnike)
      'Vršac': '44.9013,21.3425', // Bela Crkva centar (destinacija za VS putnike)
    };

    // FALLBACK: Ako grad nije postavljen, koristi default Vršac centar
    // jer vozite samo između ova 2 grada
    String gradZaKoordinat = grad ?? 'Vršac';

    // Vrati koordinate destinacije na osnovu grada putnika
    return destinacije[gradZaKoordinat] ?? destinacije['Vršac'];
  }

  // Otvara navigaciju sa poboljšanim error handling-om (preferirano OpenStreetMap - besplatno)
  Future<void> _otvoriNavigaciju(String koordinate) async {
    try {
      // INSTANT GPS - koristi novi PermissionService (bez dialoga)
      bool gpsReady = await PermissionService.ensureGpsForNavigation();
      if (!gpsReady) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.gps_off, color: Colors.white),
                  SizedBox(width: 8),
                  Text('GPS nije dostupan - navigacija otkazana'),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.warningPrimary,
              duration: const Duration(seconds: 3),
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

      // HERE WEGO - JEDINA NAVIGACIONA APLIKACIJA
      final navigacijeUrls = [
        // HERE WeGo - podržava sve uređaje (GMS i HMS)
        'here-route://mylocation/$lat,$lng',
      ];

      bool uspesno = false;
      String poslednjaNGreska = '';

      // POKUŠAJ REDOM SVE OPCIJE
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
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.navigation, color: Colors.white),
                        SizedBox(width: 8),
                        Text('🛰️ Navigacija pokrenuta sa GPS-om'),
                      ],
                    ),
                    backgroundColor: Theme.of(context).colorScheme.successPrimary,
                    duration: const Duration(seconds: 2),
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
                const Text('Problem sa navigacijom'),
                Text('Greška: ${e.toString()}'),
                const Text('Potrebno je instalirati HERE WeGo:'),
                const Text('• Besplatan'),
                const Text('• Podržava offline mape'),
                const Text('• Radi na svim uređajima'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
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

    // 🎨 BOJE KARTICE - koristi CardColorHelper sa proverom vozača
    final BoxDecoration cardDecoration = CardColorHelper.getCardDecorationWithDriver(
      _putnik,
      widget.currentDriver,
    );
    final Color textColor = CardColorHelper.getTextColorWithDriver(
      _putnik,
      widget.currentDriver,
      context,
      successPrimary: Theme.of(context).colorScheme.successPrimary,
    );
    final Color secondaryTextColor = CardColorHelper.getSecondaryTextColorWithDriver(
      _putnik,
      widget.currentDriver,
    );

    // Prava po vozaču
    final String driver = widget.currentDriver;
    final bool isBojan = driver == 'Bojan';
    final bool isSvetlana = driver == 'Svetlana';
    final bool isAdmin = isBojan || isSvetlana; // Full admin prava
    final bool isBrudaOrBilevski = driver == 'Bruda' || driver == 'Bilevski';
    final bool isIvan = driver == 'Ivan';
    final bool isVozac = isBrudaOrBilevski || isIvan; // Svi vozači

    if (_putnik.ime.toLowerCase().contains('rado') ||
        _putnik.ime.toLowerCase().contains('radoš') ||
        _putnik.ime.toLowerCase().contains('radosev')) {}

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // ✅ FIX: Hvata tap na celoj kartici
      onTap: _handleTap, // Triple tap za brži admin reset
      onLongPressStart: (_) => _startLongPressTimer(),
      onLongPressEnd: (_) => _cancelLongPressTimer(),
      onLongPressCancel: _cancelLongPressTimer,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
        decoration: cardDecoration, // Koristi CardColorHelper
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.redniBroj != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Text(
                        '${widget.redniBroj}.',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: textColor, // Koristi CardColorHelper
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _putnik.ime,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 14,
                                  color: textColor,
                                ),
                                // Forsiraj jedan red kao na Samsung-u
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            // Prikaži oznaku broja mesta ako je više od 1
                            if (_putnik.brojMesta > 1)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: textColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'x${_putnik.brojMesta} (${((_putnik.tipPutnika == 'posiljka' || _putnik.ime.toLowerCase().contains('yu auto')) ? 500 : 600) * _putnik.brojMesta} RSD)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // ADRESA - jednostavno prikaži adresu ako postoji
                        if (_putnik.adresa != null &&
                            _putnik.adresa!.isNotEmpty &&
                            _putnik.adresa != 'Adresa nije definisana')
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _putnik.adresa!,
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // OPTIMIZOVANE ACTION IKONE - koristi Flexible + Wrap umesto fiksne širine
                  // da spreči overflow na manjim ekranima ili kada ima više ikona
                  // Smanjen flex na 0 da ikone ne "kradu" prostor od imena
                  if ((isAdmin || isVozac) && widget.showActions && driver.isNotEmpty)
                    Flexible(
                      flex: 0, // Ne uzimaj dodatni prostor - koristi samo minimalno potreban
                      child: Transform.translate(
                        offset: const Offset(-1, 0), // Pomera ikone levo za 1px
                        child: Container(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 📅 MESEČNA BADGE — prikazuj samo za radnik i ucenik tipove
                              if (_putnik.isMesecniTip)
                                Align(
                                  alignment: Alignment.topRight,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.successPrimary.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '📅 MESEČNA',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.successPrimary,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              // ULTRA-SAFE ADAPTIVE ACTION IKONE - potpuno eliminiše overflow
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

                                  // Use a Wrap for action icons so they can flow to a
                                  // second line on very narrow devices instead of
                                  // compressing the name text down to a single line.
                                  return Wrap(
                                    alignment: WrapAlignment.end,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      // GPS IKONA ZA NAVIGACIJU - ako postoji adresa (mesečni ili dnevni putnik)
                                      if ((_putnik.mesecnaKarta == true) ||
                                          (_putnik.adresa != null && _putnik.adresa!.isNotEmpty)) ...[
                                        GestureDetector(
                                          onTap: () {
                                            showDialog<void>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.location_on,
                                                      color: Theme.of(context).colorScheme.primary,
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
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                            .withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: Colors.blue.withValues(alpha: 0.3),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        _putnik.adresa?.isNotEmpty == true
                                                            ? _putnik.adresa!
                                                            : 'Adresa nije definisana',
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
                                                      // INSTANT GPS - koristi novi PermissionService
                                                      final hasPermission =
                                                          await PermissionService.ensureGpsForNavigation();
                                                      if (!hasPermission) {
                                                        if (mounted && context.mounted) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: const Text(
                                                                '❌ GPS dozvole su potrebne za navigaciju',
                                                              ),
                                                              backgroundColor: Theme.of(
                                                                context,
                                                              ).colorScheme.error,
                                                              duration: const Duration(
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

                                                        // Dobij koordinate - UNIFIKOVANO za sve putnike
                                                        final koordinate = await _getKoordinateZaAdresu(
                                                          _putnik.grad,
                                                          _putnik.adresa,
                                                          _putnik.adresaId,
                                                        );

                                                        if (mounted && context.mounted) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).hideCurrentSnackBar();

                                                          if (koordinate != null) {
                                                            // Uspešno - pokaži pozitivnu poruku
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(
                                                                content: const Text(
                                                                  '✅ Otvaram navigaciju...',
                                                                ),
                                                                backgroundColor:
                                                                    Theme.of(context).colorScheme.successPrimary,
                                                                duration: const Duration(
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
                                                                backgroundColor:
                                                                    Theme.of(context).colorScheme.warningPrimary,
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
                                                              backgroundColor: Theme.of(
                                                                context,
                                                              ).colorScheme.error,
                                                              duration: const Duration(
                                                                seconds: 3,
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    },
                                                    icon: Icon(
                                                      Icons.navigation,
                                                      color: Theme.of(context).colorScheme.primary,
                                                    ),
                                                    label: const Text(
                                                      'Navigacija',
                                                    ),
                                                    style: TextButton.styleFrom(
                                                      foregroundColor: Theme.of(context).colorScheme.primary,
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
                                              // 🌟 Glassmorphism pozadina
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.white.withValues(alpha: 0.25),
                                                  Colors.white.withValues(alpha: 0.10),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.4),
                                                width: 1.0,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.15),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                '📡',
                                                style: TextStyle(fontSize: iconInnerSize * 0.8),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // keep spacing minimal for compact layout
                                      ],
                                      // TELEFON IKONA - ako putnik ima telefon
                                      if (_putnik.brojTelefona != null && _putnik.brojTelefona!.isNotEmpty) ...[
                                        GestureDetector(
                                          onTap: _pozovi,
                                          child: Container(
                                            width: iconSize,
                                            height: iconSize,
                                            decoration: BoxDecoration(
                                              // 🌟 Glassmorphism pozadina
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.white.withValues(alpha: 0.25),
                                                  Colors.white.withValues(alpha: 0.10),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.4),
                                                width: 1.0,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.15),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                '📞',
                                                style: TextStyle(fontSize: iconInnerSize * 0.8),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // spacer removed to let Wrap spacing control gaps
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
                                              // 🌟 Glassmorphism pozadina
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.white.withValues(alpha: 0.25),
                                                  Colors.white.withValues(alpha: 0.10),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.4),
                                                width: 1.0,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.15),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                '💵',
                                                style: TextStyle(fontSize: iconInnerSize * 0.8),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // spacer removed to let Wrap spacing control gaps
                                      ],
                                      // IKS DUGME - za sve korisnike (4. po redu)
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
                                              // 🌟 Glassmorphism pozadina
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.white.withValues(alpha: 0.25),
                                                  Colors.white.withValues(alpha: 0.10),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.4),
                                                width: 1.0,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.15),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                '❌',
                                                style: TextStyle(fontSize: iconInnerSize * 0.8),
                                              ),
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
              // Red 2: Pokupljen / Plaćeno / Otkazano / Odsustvo info
              if (_putnik.vremePokupljenja != null ||
                  _putnik.jeOtkazan ||
                  _putnik.jeOdsustvo ||
                  (_putnik.iznosPlacanja != null && _putnik.iznosPlacanja! > 0))
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Row(
                    children: [
                      // Pokupljen info
                      if (_putnik.vremePokupljenja != null)
                        Text(
                          'Pokupljen: ${_putnik.vremePokupljenja!.hour.toString().padLeft(2, '0')}:${_putnik.vremePokupljenja!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 13,
                            color: VozacBoja.getColorOrDefault(
                              _putnik.pokupioVozac ?? _putnik.vozac,
                              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      // Plaćeno info
                      if (_putnik.iznosPlacanja != null && _putnik.iznosPlacanja! > 0) ...[
                        if (_putnik.vremePokupljenja != null) const SizedBox(width: 12),
                        Text(
                          'Plaćeno: ${_putnik.iznosPlacanja!.toStringAsFixed(0)}${_putnik.vremePlacanja != null ? ' ${_formatVreme(_putnik.vremePlacanja!)}' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: VozacBoja.getColorOrDefault(
                              _putnik.naplatioVozac,
                              Colors.green,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      // Otkazano info
                      if (_putnik.jeOtkazan && _putnik.vremeOtkazivanja != null) ...[
                        if (_putnik.vremePokupljenja != null ||
                            (_putnik.iznosPlacanja != null && _putnik.iznosPlacanja! > 0))
                          const SizedBox(width: 12),
                        Text(
                          'Otkazao: ${_formatOtkazivanje(_putnik.vremeOtkazivanja!)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: VozacBoja.getColorOrDefault(
                              _putnik.otkazaoVozac,
                              Colors.red,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      // Odsustvo info
                      if (_putnik.jeOdsustvo) ...[
                        if (_putnik.vremePokupljenja != null ||
                            _putnik.jeOtkazan ||
                            (_putnik.iznosPlacanja != null && _putnik.iznosPlacanja! > 0))
                          const SizedBox(width: 12),
                        Text(
                          _putnik.jeBolovanje
                              ? 'Bolovanje'
                              : _putnik.jeGodisnji
                                  ? 'Godišnji'
                                  : 'Odsustvo',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

  // HELPER FUNKCIJE - ISTO kao u registrovani_putnici_screen.dart
  String _getMonthNameStatic(int month) {
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

  int _getMonthNumberStatic(String monthName) {
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

  List<String> _getMonthOptionsStatic() {
    final now = DateTime.now();
    List<String> options = [];

    // Dodaj svih 12 meseci trenutne godine
    for (int month = 1; month <= 12; month++) {
      final monthYear = '${_getMonthNameStatic(month)} ${now.year}';
      options.add(monthYear);
    }

    return options;
  }

  // 💰 ČUVANJE PLAĆANJA - KOPIJA iz registrovani_putnici_screen.dart
  Future<void> _sacuvajPlacanjeStatic({
    required String putnikId,
    required double iznos,
    required String mesec,
    required String vozacIme,
  }) async {
    try {
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

      // 🔧 FIX: Prosleđuj IME vozača, ne UUID - konverzija se radi u servisu
      // Ime vozača se koristi za prikaz boja u polasci_po_danu JSON

      // Koristi metodu koja postavlja vreme plaćanja na trenutni datum
      final uspeh = await RegistrovaniPutnikService().azurirajPlacanjeZaMesec(
        putnikId,
        iznos,
        vozacIme, // 🔧 FIX: Šaljemo IME, ne UUID
        pocetakMeseca,
        krajMeseca,
      );

      if (uspeh) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Plaćanje od ${iznos.toStringAsFixed(0)} RSD za $mesec je sačuvano',
              ),
              backgroundColor: Theme.of(context).colorScheme.successPrimary,
            ),
          );
        }
      } else {
        // 🔧 FIX: Baci exception da _executePayment ne prikaže uspešnu poruku
        throw Exception('Greška pri čuvanju plaćanja u bazu');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // ADMIN POPUP MENI - jedinstven pristup svim admin funkcijama
  void _showAdminPopup() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
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
                  color: Colors.red.withValues(alpha: 0.1),
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
                  // Ukloni iz termina
                  ListTile(
                    leading: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                    title: const Text('Ukloni iz termina'),
                    subtitle: const Text('Samo za ovaj datum i vreme'),
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // 🚫 OTKAZIVANJE - izdvojeno u funkciju
  Future<void> _handleOtkazivanje() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 2,
          ),
        ),
        title: Text(
          'Otkazivanje putnika',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Da li ste sigurni da želite da označite ovog putnika kao otkazanog?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey.shade400,
                  Colors.grey.shade600,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Ne',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: TripleBlueFashionStyles.gradientButton,
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Da',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await PutnikService().otkaziPutnika(
          _putnik.id!,
          widget.currentDriver,
          selectedVreme: _putnik.polazak,
          selectedGrad: _putnik.grad,
          selectedDan: _putnik.dan,
        );

        // Ažuriraj lokalni _putnik sa novim statusom
        if (mounted) {
          setState(() {
            _putnik = Putnik(
              id: _putnik.id,
              ime: _putnik.ime,
              polazak: _putnik.polazak,
              pokupljen: _putnik.pokupljen,
              vremeDodavanja: _putnik.vremeDodavanja,
              mesecnaKarta: _putnik.mesecnaKarta,
              dan: _putnik.dan,
              status: _putnik.status, // 🆕 Ne menjaj globalni status
              statusVreme: _putnik.statusVreme,
              vremePokupljenja: _putnik.vremePokupljenja,
              vremePlacanja: _putnik.vremePlacanja,
              placeno: _putnik.placeno,
              cena: _putnik.cena,
              naplatioVozac: _putnik.naplatioVozac,
              pokupioVozac: _putnik.pokupioVozac,
              dodeljenVozac: _putnik.dodeljenVozac,
              vozac: _putnik.vozac,
              grad: _putnik.grad,
              otkazaoVozac: widget.currentDriver,
              vremeOtkazivanja: DateTime.now(),
              adresa: _putnik.adresa,
              adresaId: _putnik.adresaId,
              obrisan: _putnik.obrisan,
              brojTelefona: _putnik.brojTelefona,
              brojMesta: _putnik.brojMesta,
              tipPutnika: _putnik.tipPutnika,
              otkazanZaPolazak: true, // ✅ DODATO: Instant UI update
            );
          });
        }

        // Pozovi parent callback da se lista ponovo sortira
        if (widget.onChanged != null) {
          widget.onChanged!();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Greška: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // UKLONI IZ TERMINA - samo nestane sa liste, bez otkazivanja
  Future<void> _handleBrisanje() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ukloni iz termina'),
        content: Text('Ukloniti ${_putnik.ime} sa liste?'),
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
        // Ukloni iz ovog termina (datum + vreme + grad)
        // Supabase realtime će automatski osvežiti listu
        await PutnikService().ukloniIzTermina(
          _putnik.id!,
          datum: _putnik.datum ?? DateTime.now().toIso8601String().split('T')[0],
          vreme: _putnik.polazak,
          grad: _putnik.grad,
        );

        // POZOVI onChanged callback da forsira parent refresh
        if (widget.onChanged != null) {
          widget.onChanged!();
        }

        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SmartSnackBar.success('${_putnik.ime} uklonjen/a iz termina', context),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SmartSnackBar.error('Greška: $e', context),
          );
        }
      }
    }
  }
} // kraj klase
