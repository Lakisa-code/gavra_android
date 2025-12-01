// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/mesecni_putnik.dart' as novi_model;
import '../models/putnik.dart';
import '../services/adresa_supabase_service.dart';
import '../services/haptic_service.dart';
import '../services/mesecni_putnik_service.dart';
import '../services/permission_service.dart';
import '../services/putnik_service.dart';
import '../services/realtime_gps_service.dart'; // 📍 GPS LEARN
import '../services/vozac_mapping_service.dart';
import '../theme.dart';
import '../utils/global_cache_manager.dart'; // 🔄 DODATO za globalni cache manager
import '../utils/smart_colors.dart';
import '../utils/text_utils.dart';
import '../utils/vozac_boja.dart';

/// Widget za prikaz putnik kartice sa podrškom za mesečne i dnevne putnike

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
    this.onPokupljen, // 🔊 Callback za glasovnu najavu sledećeg putnika
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
  final VoidCallback? onPokupljen; // 🔊 Callback za glasovnu najavu sledećeg

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
    // Ažuriraj _putnik kada se promeni widget.putnik iz StreamBuilder-a
    if (widget.putnik != oldWidget.putnik) {
      debugPrint(
          '🔄 DIDUPDATEWIDGET: ${_putnik.ime} stari status=${oldWidget.putnik.status} novi status=${widget.putnik.status} jeOtkazan=${widget.putnik.jeOtkazan}');
      _putnik = widget.putnik;
    }
  }

  // ignore: unused_element
  String _formatVremeDodavanja(DateTime vreme) {
    return '${vreme.day.toString().padLeft(2, '0')}.${vreme.month.toString().padLeft(2, '0')}.${vreme.year}. '
        '${vreme.hour.toString().padLeft(2, '0')}:${vreme.minute.toString().padLeft(2, '0')}';
  }

  // Kraći format za kompaktan prikaz (bez godine)
  String _formatVremeDodavanjaKratko(DateTime vreme) {
    return '${vreme.day}.${vreme.month}. ${vreme.hour.toString().padLeft(2, '0')}:${vreme.minute.toString().padLeft(2, '0')}';
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
              SmartSnackBar.error(
                'Greška: ${_putnik.ime} nema validno ID za pokupljanje',
                context,
              ),
            );
          }
          return;
        }

        // Uklonjena validacija vozača - prihvataju se svi vozači

        // 📳 Haptic feedback za uspešnu akciju
        HapticService.success();

        try {
          await PutnikService().oznaciPokupljen(_putnik.id!, widget.currentDriver!);

          // 📍 GPS LEARN: Sačuvaj koordinate ako adresa nema koordinate
          _tryGpsLearn();

          // 🔄 FORSIRAJ UI REFRESH NA PARENT WIDGET
          if (mounted && widget.onChanged != null) {
            widget.onChanged!();
          }

          // 🔄 GLOBALNI CACHE CLEAR I FORSIRAJ REFRESH
          // Ensures UI reflects persisted pokupljen state on navigation refresh
          try {
            await GlobalCacheManager.clearAllCachesAndRefresh();
          } catch (e) {
            // Ignore cache refresh errors but log for debugging
            debugPrint('❌ Greška pri cache refresh-u nakon pokupljenja: $e');
          }

          // 🆕 DODAJ KRATKU PAUZU pre dohvatanja (da se baza ažurira)
          await Future<void>.delayed(const Duration(milliseconds: 500));

          final updatedPutnik = await PutnikService().getPutnikFromAnyTable(_putnik.id!);
          if (updatedPutnik != null && mounted) {
            if (mounted) {
              setState(() {
                _putnik = updatedPutnik;
              });
            }

            // 🎉 PRIKAZ USPEŠNE PORUKE
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SmartSnackBar.success('${_putnik.ime} je pokupljen', context),
              );
            }

            // 🔊 NAJAVI SLEDEĆEG PUTNIKA (callback na danas_screen)
            if (widget.onPokupljen != null) {
              widget.onPokupljen!();
            }
          } else {
            // Forsiraj UI ažuriranje
            if (mounted) {
              if (mounted) {
                setState(() {
                  // Jednostavno forsiranje rebuild-a widgeta
                });
              }
            }
          }
        } catch (e) {
          // Prikaz greške korisniku
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Greška pri pokupljanju ${_putnik.ime}: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
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

  /// 📍 GPS LEARN: Sačuvaj trenutnu GPS lokaciju za adresu putnika
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
          await _handlePokupljen();

          // 🔄 FORSIRAJ PARENT WIDGET REFRESH
          if (mounted && widget.onChanged != null) {
            widget.onChanged!();
          }

          // 🔄 FORSIRAJ UI REFRESH za promenu boje kartice
          if (mounted) {
            if (mounted) {
              setState(() {
                // Forsiranje rebuild-a za ažuriranje boje
              });
            }
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
      await PutnikService().resetPutnikCard(_putnik.ime, widget.currentDriver ?? '');

      // Malo sačekaj da se baza updateuje
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Refresh putnika iz baze
      final updatedPutnik = await PutnikService().getPutnikByName(_putnik.ime);
      if (updatedPutnik != null && mounted) {
        if (mounted) {
          setState(() {
            _putnik = updatedPutnik;
          });
        }
      } else if (mounted) {
        // Fallback: kreiraj novo stanje putnika sa resetovanim vrednostima
        if (mounted) {
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
              cena: 0,
              dodaoVozac: _putnik.dodaoVozac,
              grad: _putnik.grad,
              adresa: _putnik.adresa,
              priority: _putnik.priority,
              brojTelefona: _putnik.brojTelefona,
            );
          });
        }
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
    novi_model.MesecniPutnik? mesecniPutnik;
    if (_putnik.mesecnaKarta == true) {
      try {
        mesecniPutnik = await MesecniPutnikService.getMesecniPutnikByIme(_putnik.ime);
      } catch (e) {
        // Ignoriši grešku, nastavi bez podataka o roditeljima
      }
    }

    // Automatsko SMS roditeljima za plaćanje (samo za mesečne putnike učenike)
    if (_putnik.mesecnaKarta == true &&
        mesecniPutnik != null &&
        mesecniPutnik.tip == 'ucenik' &&
        ((mesecniPutnik.brojTelefonaOca != null && mesecniPutnik.brojTelefonaOca!.isNotEmpty) ||
            (mesecniPutnik.brojTelefonaMajke != null && mesecniPutnik.brojTelefonaMajke!.isNotEmpty))) {
      opcije.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: ListTile(
            leading: Icon(
              Icons.family_restroom,
              color: Theme.of(context).colorScheme.primary,
            ),
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
    if (mesecniPutnik != null && mesecniPutnik.brojTelefonaOca != null && mesecniPutnik.brojTelefonaOca!.isNotEmpty) {
      opcije.add(
        ListTile(
          leading: Icon(Icons.man, color: Theme.of(context).colorScheme.primary),
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
          leading: Icon(Icons.sms, color: Theme.of(context).colorScheme.primary),
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
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
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
      // 📞 HUAWEI KOMPATIBILNO - koristi Huawei specifičnu logiku
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

  /// Automatsko SMS roditeljima za plaćanje (samo za mesečne putnike učenike)
  Future<void> _posaljiSMSRoditeljimePlacanje(
    novi_model.MesecniPutnik mesecniPutnik,
  ) async {
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
          SnackBar(
            content: const Text('Nema brojeva telefona roditelja za slanje SMS'),
            backgroundColor: Theme.of(context).colorScheme.warningPrimary,
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
                ? 'SMS za plaćanje poslat roditeljima ($poslato/${roditelji.length})'
                : 'Nije moguće poslati SMS roditeljima',
          ),
          backgroundColor:
              poslato > 0 ? Theme.of(context).colorScheme.successPrimary : Theme.of(context).colorScheme.error,
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
    // Validacija vozača pre pokušaja plaćanja
    final validni = ['Bruda', 'Bilevski', 'Bojan', 'Svetlana', 'Vlajic'];
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
      await _handleMesecniPayment();
    } else {
      // OBIČNI PUTNIK - unos custom iznosa
      await _handleObicniPayment();
    }
  }

  // 📅 PLAĆANJE MESEČNE KARTE - CUSTOM CENA (korisnik unosi iznos)
  Future<void> _handleMesecniPayment() async {
    // Prvo dohvati mesečnog putnika iz baze po imenu (ne po ID!)
    final mesecniPutnik = await MesecniPutnikService.getMesecniPutnikByIme(_putnik.ime);

    if (mesecniPutnik == null) {
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
      brojPutovanja = await MesecniPutnikService.izracunajBrojPutovanjaIzIstorije(
        _putnik.id! as String,
      );
      // Računaj otkazivanja iz stvarne istorije
      brojOtkazivanja = await MesecniPutnikService.izracunajBrojOtkazivanjaIzIstorije(
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

                  // 📊 STATISTIKE ODSEK
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
                        if (mesecniPutnik.jePlacen) ...[
                          // Koristi jePlacen umesto datumPlacanja
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
                          // 💰 Proveri da li je mesec plaćen - ISTO kao u mesecni_putnici_screen.dart
                          final bool isPlacen = _isMonthPaidStatic(monthYear, mesecniPutnik);

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
              Text(
                'Plaćanje putovanja',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
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
        await _executePayment(iznos, isMesecni: false);

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
    required bool isMesecni,
    String? mesec,
  }) async {
    try {
      // Uklonjena validacija vozača - direktno koristi zadatog vozača
      String finalDriver = widget.currentDriver ?? 'Nepoznat vozač';

      // Pozovi odgovarajući service za plaćanje
      if (isMesecni && mesec != null) {
        // Validacija da putnik ime nije prazno
        if (_putnik.ime.trim().isEmpty) {
          throw Exception('Ime putnika je prazno - ne može se pronaći u bazi');
        }

        // Za mesečne putnike koristi funkciju iz mesecni_putnici_screen.dart
        final mesecniPutnik = await MesecniPutnikService.getMesecniPutnikByIme(_putnik.ime);
        if (mesecniPutnik != null) {
          // Koristi static funkciju kao u mesecni_putnici_screen.dart
          await _sacuvajPlacanjeStatic(
            putnikId: mesecniPutnik.id,
            iznos: iznos,
            mesec: mesec,
            vozacIme: finalDriver,
          );
        } else {
          throw Exception('Mesečni putnik "${_putnik.ime}" nije pronađen u bazi');
        }
      } else {
        // Za obične putnike koristi postojeći servis
        if (_putnik.id == null) {
          throw Exception('Putnik nema valjan ID - ne može se naplatiti');
        }

        await PutnikService().oznaciPlaceno(
          _putnik.id!,
          iznos,
          finalDriver,
        );
      }

      if (mounted) {
        setState(() {});

        // Pozovi callback za refresh parent widget-a
        if (widget.onChanged != null) {
          widget.onChanged!();
        }

        // Prikaži success poruku
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMesecni
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
      // 🔍 DEBUG: Proveri ID pre poziva
      final putnikId = _putnik.id;
      if (putnikId == null || putnikId.isEmpty) {
        throw Exception('Putnik nema validan ID (id=$putnikId)');
      }

      // Pozovi service za postavljanje statusa
      await PutnikService().oznaciBolovanjeGodisnji(
        putnikId,
        status,
        widget.currentDriver ?? '',
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

        // 🔄 FORSIRAJ REFRESH LISTE
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
    // 🎯 PRIORITET 1: Ako imamo adresaId (UUID), direktno dohvati adresu sa koordinatama
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

    // 🎯 PRIORITET 2: Ako imamo naziv adrese, traži u tabeli adrese
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

    // 🎯 PRIORITET 3: Fallback na transport logiku (centar destinacije)
    // 🚌 TRANSPORT LOGIKA: Navigiraj do centra destinacije
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
      // 🛰️ INSTANT GPS - koristi novi PermissionService (bez dialoga)
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

      // 🚗 LISTA NAVIGACIJSKIH APLIKACIJA (Huawei/GBox kompatibilno)
      final navigacijeUrls = [
        // Google Maps (Samsung i većina Android uređaja)
        'google.navigation:q=$lat,$lng',

        // Waze
        'waze://?ll=$lat,$lng&navigate=yes',

        // Petal Maps (Huawei)
        'petalmaps://route?daddr=$lat,$lng',

        // HERE WeGo (Huawei kompatibilan)
        'here-route://mylocation/$lat,$lng',

        // Yandex Maps
        'yandexmaps://build_route_on_map?lat_to=$lat&lon_to=$lng',

        // Generic geo intent (Android fallback - otvara Google Maps ako je instaliran)
        'geo:$lat,$lng?q=$lat,$lng',

        // Browser fallback using OpenStreetMap (poslednja opcija)
        'https://www.openstreetmap.org/directions?to=$lat,$lng',
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
                const Text('Pokušajte instalirati:'),
                const Text('• OsmAnd ili Maps.me (OpenStreetMap klijenti - besplatno)'),
                const Text('• Petal Maps (Huawei) ili HERE WeGo kao alternative'),
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

    // Uklonjen warning za nekorišćenu promenljivu driverColor
    final bool isSelected = _putnik.jePokupljen; // Koristi getter umesto direktno vremePokupljenja
    final bool isMesecna = _putnik.mesecnaKarta == true;
    final bool isPlaceno = (_putnik.iznosPlacanja ?? 0) > 0;
    // Redosled boja prema specifikaciji:
    // 1. BELE - nepokupljeni (default)
    // 2. PLAVE - pokupljeni neplaćeni
    // 3. ZELENE - pokupljeni plaćeni/mesečni
    // 4. CRVENE - otkazane
    // 5. ŽUTE - godišnji/bolovanje (najveći prioritet)
    final Color cardColor = _putnik.jeOdsustvo
        ? const Color(
            0xFFFFF59D,
          ) // ŽUTO za odsustvo (godišnji/bolovanje) - NAJVEĆI PRIORITET
        : _putnik.jeOtkazan
            ? const Color(0xFFFFE5E5) // CRVENO za otkazane - DRUGI PRIORITET
            : (isSelected
                ? (isMesecna || isPlaceno
                    ? const Color(
                        0xFF388E3C,
                      ) // ZELENO za mesečne/plaćene - TREĆI PRIORITET
                    : const Color(
                        0xFF7FB3D3,
                      )) // PLAVO za pokupljene neplaćene - ČETVRTI PRIORITET
                : Colors.white.withValues(
                    alpha: 0.70,
                  )); // ⚪ BELO za nepokupljene - PETI PRIORITET (default)

    // Prava po vozaču
    final String? driver = widget.currentDriver;
    final bool isBojan = driver == 'Bojan';
    final bool isSvetlana = driver == 'Svetlana';
    final bool isAdmin = isBojan || isSvetlana; // Full admin prava
    final bool isBrudaOrBilevski = driver == 'Bruda' || driver == 'Bilevski';
    final bool isVlajic = driver == 'Vlajic';
    final bool isVozac = isBrudaOrBilevski || isVlajic; // Svi vozači

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
        margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
        decoration: BoxDecoration(
          gradient: _putnik.jeOdsustvo
              ? LinearGradient(
                  colors: [
                    const Color(0xFFFFF59D).withValues(
                      alpha: 0.85,
                    ), // ŽUTO za odsustvo - NAJVEĆI PRIORITET
                    const Color(0xFFFFF59D),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : _putnik.jeOtkazan
                  ? null // CRVENO za otkazane - bez gradient-a
                  : LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.98),
                        isSelected
                            ? (isMesecna || isPlaceno
                                ? const Color(
                                    0xFF388E3C,
                                  ) // Zelena za mesečne/plaćene
                                : const Color(
                                    0xFF7FB3D3,
                                  )) // Plava za pokupljene neplaćene
                            : Colors.white.withValues(alpha: 0.98),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _putnik.jeOdsustvo
                ? const Color(0xFFFFC107).withValues(
                    alpha: 0.6,
                  ) // 🟡 ŽUTO border za odsustvo - NAJVEĆI PRIORITET
                : _putnik.jeOtkazan
                    ? Colors.red.withValues(alpha: 0.25) // 🔴 CRVENO border za otkazane
                    : isSelected
                        ? (isMesecna || isPlaceno
                            ? const Color(0xFF388E3C).withValues(alpha: 0.4) // 🟢 ZELENO border za mesečne/plaćene
                            : const Color(0xFF7FB3D3).withValues(alpha: 0.4)) // 🔵 PLAVO border za pokupljene neplaćene
                        : Colors.grey.withValues(alpha: 0.10), // ⚪ BELO border za nepokupljene
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _putnik.jeOdsustvo
                  ? const Color(0xFFFFC107).withValues(alpha: 0.2) // 🟡 ŽUTO shadow za odsustvo - NAJVEĆI PRIORITET
                  : _putnik.jeOtkazan
                      ? Colors.red.withValues(alpha: 0.08) // 🔴 CRVENO shadow za otkazane
                      : isSelected
                          ? (isMesecna || isPlaceno
                              ? const Color(0xFF388E3C).withValues(alpha: 0.15) // 🟢 ZELENO shadow za mesečne/plaćene
                              : const Color(0xFF7FB3D3)
                                  .withValues(alpha: 0.15)) // 🔵 PLAVO shadow za pokupljene neplaćene
                          : Colors.black.withValues(alpha: 0.07), // ⚪ BELO shadow za nepokupljene
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
                          color: _putnik.jeOdsustvo
                              ? Colors.orange[600] // 🟡 ŽUTO za odsustvo - NAJVEĆI PRIORITET
                              : _putnik.jeOtkazan
                                  ? Colors.red[400] // 🔴 CRVENO za otkazane
                                  : isSelected
                                      ? (isMesecna || isPlaceno)
                                          ? Theme.of(context).colorScheme.successPrimary // 🟢 ZELENO za mesečne/plaćene
                                          : const Color(
                                              0xFF0D47A1,
                                            ) // 🔵 PLAVO za pokupljene neplaćene
                                      : Colors.black, // ⚪ BELO za nepokupljene
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _putnik.ime,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            fontSize: 14, // 🔧 Smanjeno sa 15 za bolji fit na svim uređajima
                            color: _putnik.jeOdsustvo
                                ? Colors.orange[600] // 🟡 ŽUTO za odsustvo - NAJVEĆI PRIORITET
                                : _putnik.jeOtkazan
                                    ? Colors.red[400] // 🔴 CRVENO za otkazane
                                    : isSelected
                                        ? (isMesecna || isPlaceno)
                                            ? Theme.of(context)
                                                .colorScheme
                                                .successPrimary // 🟢 ZELENO za mesečne/plaćene
                                            : const Color(
                                                0xFF0D47A1,
                                              ) // 🔵 PLAVO za pokupljene neplaćene
                                        : Colors.black, // ⚪ BELO za nepokupljene
                          ),
                          // 🔧 FIX: Forsiraj jedan red kao na Samsung-u
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        // 🏠 ADRESE - prikaži adrese za mesečne putnike ili staru adresu za dnevne
                        if (_putnik.mesecnaKarta == true)
                          // Za mesečne putnike koristi novi UUID sistem
                          FutureBuilder<String>(
                            future: _getMesecniPutnikAdrese(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox.shrink(); // Ne prikazuj loading
                              }

                              if (snapshot.hasError ||
                                  !snapshot.hasData ||
                                  snapshot.data!.isEmpty ||
                                  snapshot.data == 'Nema adresa') {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  snapshot.data!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: (_putnik.jeOtkazan
                                            ? Colors.red[300]
                                            : _putnik.jeOdsustvo
                                                ? Colors.orange[500] // 🟡 Oranž adresa za odsustvo
                                                : isSelected
                                                    ? (isMesecna || isPlaceno)
                                                        ? Colors.green[500]
                                                        : const Color(0xFF0D47A1)
                                                    : Colors.grey[600])
                                        ?.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          )
                        else
                        // Za dnevne putnike koristi staro TEXT polje
                        if (_putnik.adresa != null && _putnik.adresa!.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _putnik.adresa!,
                              style: TextStyle(
                                fontSize: 14,
                                color: (_putnik.jeOtkazan
                                        ? Colors.red[300]
                                        : _putnik.jeOdsustvo
                                            ? Colors.orange[500] // 🟡 Oranž adresa za odsustvo
                                            : isSelected
                                                ? (isMesecna || isPlaceno)
                                                    ? Colors.green[500]
                                                    : const Color(0xFF0D47A1)
                                                : Colors.grey[600])
                                    ?.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 🎯 OPTIMIZOVANE ACTION IKONE - koristi Flexible + Wrap umesto fiksne širine
                  // da spreči overflow na manjim ekranima ili kada ima više ikona
                  // 🔧 FIX: Smanjen flex na 0 da ikone ne "kradu" prostor od imena
                  if ((isAdmin || isVozac) && widget.showActions && (driver ?? '').isNotEmpty)
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
                              // 📅 MESEČNA KARTA BADGE — make it a proper badge above icons
                              if (_putnik.mesecnaKarta == true)
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

                                  // Use a Wrap for action icons so they can flow to a
                                  // second line on very narrow devices instead of
                                  // compressing the name text down to a single line.
                                  return Wrap(
                                    alignment: WrapAlignment.end,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      // 📍 GPS IKONA ZA NAVIGACIJU - ako postoji adresa (mesečni ili dnevni putnik)
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
                                                      child: _putnik.mesecnaKarta == true
                                                          ? FutureBuilder<String>(
                                                              future: _getMesecniPutnikAdrese(),
                                                              builder: (context, snapshot) {
                                                                if (snapshot.connectionState ==
                                                                    ConnectionState.waiting) {
                                                                  return const Text('Učitavam...');
                                                                }
                                                                return Text(
                                                                  snapshot.data?.isNotEmpty == true
                                                                      ? snapshot.data!
                                                                      : 'Adresa nije definisana',
                                                                  style: const TextStyle(
                                                                    fontSize: 16,
                                                                    fontWeight: FontWeight.w600,
                                                                  ),
                                                                  overflow: TextOverflow.fade,
                                                                  maxLines: 3,
                                                                );
                                                              },
                                                            )
                                                          : Text(
                                                              _putnik.adresa ?? 'Adresa nije definisana',
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
                                                                backgroundColor: Theme.of(
                                                                  context,
                                                                ).colorScheme.successPrimary,
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
                                                                backgroundColor: Theme.of(
                                                                  context,
                                                                ).colorScheme.warningPrimary,
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
                                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Icon(
                                              Icons.location_on,
                                              color: Theme.of(context).colorScheme.primary,
                                              size: iconInnerSize, // Adaptive inner size
                                            ),
                                          ),
                                        ),
                                        // keep spacing minimal for compact layout
                                      ],
                                      // 📞 TELEFON IKONA - ako putnik ima telefon
                                      if (_putnik.brojTelefona != null && _putnik.brojTelefona!.isNotEmpty) ...[
                                        GestureDetector(
                                          onTap: _pozovi,
                                          child: Container(
                                            width: iconSize,
                                            height: iconSize,
                                            decoration: BoxDecoration(
                                              color:
                                                  Theme.of(context).colorScheme.successPrimary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Icon(
                                              Icons.phone,
                                              color: Theme.of(context).colorScheme.successPrimary,
                                              size: iconInnerSize,
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
                                              color:
                                                  Theme.of(context).colorScheme.successPrimary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Icon(
                                              Icons.attach_money,
                                              color: Theme.of(context).colorScheme.successPrimary,
                                              size: iconInnerSize,
                                            ),
                                          ),
                                        ),
                                        // spacer removed to let Wrap spacing control gaps
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
                                              color: Colors.orange.withValues(alpha: 0.1),
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
              // Info row: Dodao, Pokupio, Plaćeno (jedan red - kompaktan prikaz)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    // ✅ DODAO INFO - kompaktno
                    Text(
                      'Dodao: ${_putnik.vremeDodavanja != null ? _formatVremeDodavanjaKratko(_putnik.vremeDodavanja!) : (_putnik.dodaoVozac?.isNotEmpty == true ? 'ranije' : 'sistem')}',
                      style: TextStyle(
                        fontSize: 13,
                        color: VozacBoja.getColorOrDefault(
                          _putnik.dodaoVozac,
                          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Otkazano info
                    if (_putnik.jeOtkazan) ...[
                      const SizedBox(width: 12),
                      Text(
                        'Otkazao: ${_putnik.vremeOtkazivanja != null ? _formatVremeDodavanjaKratko(_putnik.vremeOtkazivanja!) : 'ranije'}',
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
                    // Pokupljen info
                    if (_putnik.vremePokupljenja != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        'Pokupljen ${_putnik.vremePokupljenja!.hour.toString().padLeft(2, '0')}:${_putnik.vremePokupljenja!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 13,
                          color: VozacBoja.getColorOrDefault(
                            _putnik.pokupioVozac,
                            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    // Plaćeno info
                    if (_putnik.iznosPlacanja != null && _putnik.iznosPlacanja! > 0) ...[
                      const SizedBox(width: 12),
                      Text(
                        'Plaćeno: ${_putnik.iznosPlacanja!.toStringAsFixed(0)}${_putnik.vremePlacanja != null ? ' ${_formatVreme(_putnik.vremePlacanja!)}' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: VozacBoja.getColorOrDefault(
                            _putnik.naplatioVozac,
                            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          fontWeight: FontWeight.w500,
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

      // 🔄 Konvertuj ime vozača u UUID - FIX ZA CONSTRAINT GREŠKU

      String vozacUuid;
      if (VozacMappingService.isValidVozacUuidSync(vozacIme)) {
        // Već je UUID format
        vozacUuid = vozacIme;
      } else {
        // Konvertuj ime u UUID
        final uuid = VozacMappingService.getVozacUuidSync(vozacIme);

        // FALLBACK sa pravim UUID-om vozača Bojan
        vozacUuid = uuid ?? '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e'; // Bojan UUID iz baze
      }

      // Koristi metodu koja postavlja vreme plaćanja na trenutni datum
      final uspeh = await MesecniPutnikService().azurirajPlacanjeZaMesec(
        putnikId,
        iznos,
        vozacUuid, // 🎯 PROSLIJEDI UUID UMESTO IMENA
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('❌ Greška pri čuvanju plaćanja'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
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
                // Obriši
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Obriši putnika'),
                  subtitle: const Text('Ukloni sa liste rezervacija'),
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
          widget.currentDriver ?? '',
          selectedVreme: _putnik.polazak,
          selectedGrad: _putnik.grad,
        );

        debugPrint('✅ OTKAZIVANJE USPEŠNO: ${_putnik.ime} - baza ažurirana');

        // ✅ FIX: Ažuriraj lokalni _putnik sa novim statusom
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
              status: 'otkazano', // ✅ Postavi status na otkazano
              statusVreme: _putnik.statusVreme,
              vremePokupljenja: _putnik.vremePokupljenja,
              vremePlacanja: _putnik.vremePlacanja,
              placeno: _putnik.placeno,
              cena: _putnik.cena,
              naplatioVozac: _putnik.naplatioVozac,
              pokupioVozac: _putnik.pokupioVozac,
              dodaoVozac: _putnik.dodaoVozac,
              vozac: _putnik.vozac,
              grad: _putnik.grad,
              otkazaoVozac: widget.currentDriver,
              vremeOtkazivanja: DateTime.now(),
              adresa: _putnik.adresa,
              adresaId: _putnik.adresaId,
              obrisan: _putnik.obrisan,
              priority: _putnik.priority,
              brojTelefona: _putnik.brojTelefona,
              datum: _putnik.datum,
            );
            debugPrint(
                '✅ LOKALNI _PUTNIK AŽURIRAN: ${_putnik.ime} status=${_putnik.status} jeOtkazan=${_putnik.jeOtkazan}');
          });
        }

        // ✅ FIX: Pozovi parent callback da se lista ponovo sortira
        if (widget.onChanged != null) {
          widget.onChanged!();
        }

        // 🔄 GLOBALNI CACHE CLEAR I FORSIRAJ REFRESH
        // Ovo osigurava da override entries (putovanja_istorija) postanu
        // vidljivi prilikom povratka na ekran (kartica ostaje crvena)
        try {
          await GlobalCacheManager.clearAllCachesAndRefresh();
        } catch (e) {
          debugPrint('❌ Greška pri čišćenju cache-a nakon otkazivanja: $e');
        }
      } catch (e) {
        debugPrint('❌ OTKAZIVANJE GREŠKA: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Greška: $e'), backgroundColor: Colors.red),
          );
        }
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

      // 🔄 GLOBALNI CACHE CLEAR I REFRESH
      await GlobalCacheManager.clearAllCachesAndRefresh();

      // 🔄 POZOVI onChanged callback da forsira parent refresh
      if (widget.onChanged != null) {
        widget.onChanged!();
      }

      if (mounted) {
        setState(() {});
      }
    }
  }

  /// Učitava formatirane adrese za mesečne putnike koristeći UUID reference
  Future<String> _getMesecniPutnikAdrese() async {
    if (_putnik.id == null) return '';

    try {
      // Učitaj mesečni putnik objekat iz baze koristeći ime putnika
      final mesecniService = MesecniPutnikService();
      final sviMesecniPutnici = await mesecniService.getAllMesecniPutnici();

      // Pronađi mesečni putnik objekat po imenu
      final mesecniPutnik = sviMesecniPutnici.firstWhere(
        (mp) => mp.putnikIme.trim().toLowerCase() == _putnik.ime.trim().toLowerCase(),
        orElse: () => throw Exception('Mesečni putnik nije pronađen'),
      );

      // Koristi getAdresaZaSelektovaniGrad metodu za kontekstualnu adresu.
      // Ako parent nije proslijedio `selectedGrad`, fallbackuj na grad iz samog
      // putnika kako bi prikaz bio konzistentan između različitih ekrana
      // (npr. DanasScreen često ne prosleđuje selectedGrad).
      final ctxGrad =
          (widget.selectedGrad != null && widget.selectedGrad!.isNotEmpty) ? widget.selectedGrad : _putnik.grad;

      return await mesecniPutnik.getAdresaZaSelektovaniGrad(ctxGrad);
    } catch (e) {
      // Ako ne može da učita, vrati prazan string
      return '';
    }
  }

  /// Dobija koordinate za navigaciju za mesečne putnike - traži po nazivu mesta
  /// DEPRECATED: Koristi _getKoordinateZaAdresu umesto ove funkcije
  /// Zadržano za kompatibilnost
} // kraj klase
