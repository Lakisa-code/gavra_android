import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/route_config.dart';
import '../helpers/putnik_statistike_helper.dart'; // 📊 Zajednički dijalog za statistike
import '../services/cena_obracun_service.dart';
import '../services/local_notification_service.dart'; // 🔔 Lokalne notifikacije
import '../services/putnik_push_service.dart'; // 📱 Push notifikacije za putnike
import '../services/putnik_service.dart'; // 🏖️ Za bolovanje/godišnji
import '../services/slobodna_mesta_service.dart'; // 🎫 Provera slobodnih mesta
import '../services/theme_manager.dart';
import '../services/weather_service.dart'; // 🌤️ Vremenska prognoza
import '../theme.dart';
import '../utils/schedule_utils.dart';
import '../widgets/kombi_eta_widget.dart'; // 🆕 Jednostavan ETA widget
import '../widgets/shared/time_picker_cell.dart';

/// 📊 MESEČNI PUTNIK PROFIL SCREEN
/// Prikazuje podatke o mesečnom putniku: raspored, vožnje, dugovanja
class RegistrovaniPutnikProfilScreen extends StatefulWidget {
  final Map<String, dynamic> putnikData;

  const RegistrovaniPutnikProfilScreen({Key? key, required this.putnikData}) : super(key: key);

  @override
  State<RegistrovaniPutnikProfilScreen> createState() => _RegistrovaniPutnikProfilScreenState();
}

class _RegistrovaniPutnikProfilScreenState extends State<RegistrovaniPutnikProfilScreen> {
  Map<String, dynamic> _putnikData = {};
  bool _isLoading = false;
  int _brojVoznji = 0;
  int _brojOtkazivanja = 0;
  // ignore: unused_field
  double _dugovanje = 0.0;
  List<Map<String, dynamic>> _istorijaPl = [];

  // 📊 Statistike - detaljno po datumima (Set za jedinstvene datume)
  Map<String, Set<String>> _voznjeDetaljno = {}; // mesec -> set jedinstvenih datuma vožnji
  Map<String, Set<String>> _otkazivanjaDetaljno = {}; // mesec -> set jedinstvenih datuma otkazivanja
  double _ukupnoZaduzenje = 0.0; // ukupno zaduženje za celu godinu
  String? _adresaBC; // BC adresa
  String? _adresaVS; // VS adresa

  // 🚐 GPS Tracking - više se ne koristi direktno, ETA se čita iz KombiEtaWidget
  // ignore: unused_field
  double? _putnikLat;
  // ignore: unused_field
  double? _putnikLng;
  // ignore: unused_field
  String? _sledeciPolazak;
  // ignore: unused_field
  String _smerTure = 'BC_VS';
  String? _sledecaVoznjaInfo; // 🆕 Format: "Ponedeljak, 7:00 BC"

  // 🎯 Realtime subscription za status promene
  RealtimeChannel? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _putnikData = Map<String, dynamic>.from(widget.putnikData);
    _refreshPutnikData(); // 🔄 Učitaj sveže podatke iz baze
    _loadStatistike();
    _registerPushToken(); // 📱 Registruj push token (retry ako nije uspelo pri login-u)
    _checkAndResolvePendingRequests(); // 🆕 Proveri zaglavljene pending zahteve
    _cleanupOldSeatRequests(); // 🧹 Očisti stare seat_requests iz baze
    WeatherService.refreshAll(); // 🌤️ Učitaj vremensku prognozu
    _setupRealtimeListener(); // 🎯 Sluša promene statusa u realtime

    // 📅 Proveri podsetnik za raspored
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWeeklyScheduleReminder();
    });
  }

  @override
  void dispose() {
    _statusSubscription?.unsubscribe(); // 🛑 Zatvori Realtime listener
    super.dispose();
  }

  /// 📱 Registruje push token za notifikacije (retry mehanizam)
  Future<void> _registerPushToken() async {
    final putnikId = _putnikData['id'];
    if (putnikId != null) {
      await PutnikPushService.registerPutnikToken(putnikId);
    }
  }

  /// 🎯 Postavlja Realtime listener za status promene
  void _setupRealtimeListener() {
    final putnikId = _putnikData['id']?.toString();
    if (putnikId == null) return;

    // Pretplati se na promene u registrovani_putnici tabeli za ovog putnika
    _statusSubscription = Supabase.instance.client
        .channel('pending_status_$putnikId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'registrovani_putnici',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: putnikId,
          ),
          callback: (payload) {
            debugPrint('🎯 [Realtime] Status promena detektovana za putnika $putnikId');
            _handleStatusChange(payload);
          },
        )
        .subscribe();

    debugPrint('🎯 [Realtime] Listener aktivan za putnika $putnikId');
  }

  /// 🔔 Hendluje promenu statusa (confirmed/null) i šalje notifikaciju
  Future<void> _handleStatusChange(PostgresChangePayload payload) async {
    try {
      final newData = payload.newRecord;
      if (newData.isEmpty) return;

      final polasciPoDanu = newData['polasci_po_danu'] as Map<String, dynamic>?;
      if (polasciPoDanu == null) return;

      // Osvježi lokalne podatke
      if (mounted) {
        setState(() {
          _putnikData = Map<String, dynamic>.from(newData);
        });
      }

      // Proveri sve dane za status promene
      for (final dan in polasciPoDanu.keys) {
        final danData = polasciPoDanu[dan];
        if (danData is! Map) continue;

        // BC status promena
        final bcStatus = danData['bc_status']?.toString();
        final bcVreme = danData['bc']?.toString();

        if (bcStatus == 'confirmed' && bcVreme != null && bcVreme.isNotEmpty && bcVreme != 'null') {
          // ✅ POTVRĐENO
          await LocalNotificationService.showRealtimeNotification(
            title: '✅ Zahtev potvrđen!',
            body: 'Vaš zahtev za $dan $bcVreme (BC) je POTVRĐEN! 🚐',
          );
          debugPrint('✅ [Status] BC zahtev POTVRĐEN: $dan $bcVreme');
        } else if (bcStatus == 'rejected' || bcStatus == 'null' || (bcStatus == null && bcVreme == null && danData.containsKey('bc_resolved_at'))) {
          // ❌ ODBIJENO - nema mesta ili je termin obrisan po odbijanju
          await LocalNotificationService.showRealtimeNotification(
            title: '❌ Zahtev odbijen',
            body: 'Vaš zahtev za $dan BC polazak je odbijen. Nema slobodnih mesta.',
          );
          debugPrint('❌ [Status] BC zahtev ODBIJEN: $dan');
        }

        // VS status promena
        final vsStatus = danData['vs_status']?.toString();
        final vsVreme = danData['vs']?.toString();

        if (vsStatus == 'confirmed' && vsVreme != null && vsVreme.isNotEmpty && vsVreme != 'null') {
          // ✅ POTVRĐENO
          await LocalNotificationService.showRealtimeNotification(
            title: '✅ Zahtev potvrđen!',
            body: 'Vaš zahtev za $dan $vsVreme (VS) je POTVRĐEN! 🚐',
          );
          debugPrint('✅ [Status] VS zahtev POTVRĐEN: $dan $vsVreme');
        } else if (vsStatus == 'rejected' || vsStatus == 'null' || (vsStatus == null && vsVreme == null && danData.containsKey('vs_resolved_at'))) {
          // ❌ ODBIJENO - nema mesta
          await LocalNotificationService.showRealtimeNotification(
            title: '❌ Zahtev odbijen',
            body: 'Vaš zahtev za $dan VS polazak je odbijen. Nema slobodnih mesta.',
          );
          debugPrint('❌ [Status] VS zahtev ODBIJEN: $dan');
        }
      }
    } catch (e) {
      debugPrint('❌ [Realtime] Greška pri obradi status promene: $e');
    }
  }

  /// 🔄 Osvežava podatke putnika iz baze
  Future<void> _refreshPutnikData() async {
    try {
      final putnikId = _putnikData['id'];
      if (putnikId == null) return;

      final response = await Supabase.instance.client.from('registrovani_putnici').select().eq('id', putnikId).single();

      if (mounted) {
        setState(() {
          _putnikData = Map<String, dynamic>.from(response);
        });
      }
    } catch (e) {
      // Error refreshing data
    }
  }

  /// 🛡️ HELPER: Merge-uje nove promene sa postojećim markerima u bazi
  /// Čuva bc_pokupljeno, bc_placeno, vs_pokupljeno, vs_placeno i ostale markere
  Future<Map<String, dynamic>> _mergePolasciSaBazom(
    String putnikId,
    Map<String, dynamic> noviPolasci,
  ) async {
    try {
      // Učitaj trenutno stanje iz baze
      final response = await Supabase.instance.client
          .from('registrovani_putnici')
          .select('polasci_po_danu')
          .eq('id', putnikId)
          .maybeSingle();

      if (response == null) return noviPolasci;

      final postojeciPolasci = response['polasci_po_danu'] as Map<String, dynamic>? ?? {};
      final mergedPolasci = Map<String, dynamic>.from(postojeciPolasci);

      // Merge svakog dana
      for (final dan in noviPolasci.keys) {
        if (!mergedPolasci.containsKey(dan)) {
          mergedPolasci[dan] = noviPolasci[dan];
        } else {
          final postojeciDan = Map<String, dynamic>.from(mergedPolasci[dan] as Map);
          final noviDan = noviPolasci[dan] as Map<String, dynamic>;

          // Merge: novi podaci + čuvanje starih markera
          for (final key in noviDan.keys) {
            postojeciDan[key] = noviDan[key];
          }

          mergedPolasci[dan] = postojeciDan;
        }
      }

      return mergedPolasci;
    } catch (e) {
      debugPrint('❌ [Merge] Greška: $e');
      return noviPolasci;
    }
  }

  /// 🆕 Proverava i rešava zaglavljene pending zahteve
  /// Poziva se pri svakom otvaranju profila
  Future<void> _checkAndResolvePendingRequests() async {
    try {
      final putnikId = _putnikData['id']?.toString();
      if (putnikId == null) return;

      // Učitaj sveže podatke iz baze
      final response = await Supabase.instance.client
          .from('registrovani_putnici')
          .select('polasci_po_danu')
          .eq('id', putnikId)
          .maybeSingle();

      if (response == null) return;

      final polasci = response['polasci_po_danu'] as Map<String, dynamic>? ?? {};
      if (polasci.isEmpty) return;

      bool hasChanges = false;
      final now = DateTime.now();
      const daniMapa = {'pon': 1, 'uto': 2, 'sre': 3, 'cet': 4, 'pet': 5, 'sub': 6, 'ned': 7};

      for (final dan in polasci.keys) {
        final danData = polasci[dan];
        if (danData is! Map) continue;

        // Proveri BC pending
        final bcStatus = danData['bc_status']?.toString();
        final bcVreme = danData['bc']?.toString();
        final bcCekaOd = danData['bc_ceka_od']?.toString();

        if (bcStatus == 'pending' && bcVreme != null && bcVreme.isNotEmpty && bcVreme != 'null') {
          debugPrint('🔍 [PendingCheck] Pronađen BC pending za $dan: $bcVreme');

          // 🆕 Proveri starost pending zahteva (15 min timeout)
          if (bcCekaOd != null) {
            try {
              final cekaOdTime = DateTime.parse(bcCekaOd);
              final diff = now.difference(cekaOdTime).inMinutes;
              if (diff > 15) {
                // Pending zahtev je stariji od 15 minuta - automatski odbij
                (polasci[dan] as Map<String, dynamic>)['bc'] = null;
                (polasci[dan] as Map<String, dynamic>)['bc_status'] = null;
                (polasci[dan] as Map<String, dynamic>)['bc_ceka_od'] = null;
                debugPrint('⏰ [PendingCheck] BC $dan $bcVreme → EXPIRED (${diff}min) - odbijeno');
                hasChanges = true;
                continue; // Preskoči proveru mesta za expired zahteve
              }
            } catch (e) {
              debugPrint('⚠️ [PendingCheck] Greška pri parsiranju bc_ceka_od: $e');
            }
          }

          // Izračunaj ciljni datum
          final danWeekday = daniMapa[dan.toLowerCase()] ?? now.weekday;
          int diff = danWeekday - now.weekday;
          if (diff < 0) diff += 7;
          final targetDate = now.add(Duration(days: diff)).toIso8601String().split('T')[0];

          // Proveri mesta
          final imaMesta = await SlobodnaMestaService.imaSlobodnihMesta('BC', bcVreme,
              datum: targetDate, tipPutnika: _putnikData['tip']?.toString());
          if (imaMesta) {
            (polasci[dan] as Map<String, dynamic>)['bc_status'] = 'confirmed';
            debugPrint('✅ [PendingCheck] BC $dan $bcVreme → confirmed');
          } else {
            (polasci[dan] as Map<String, dynamic>)['bc'] = null;
            (polasci[dan] as Map<String, dynamic>)['bc_status'] = null;
            debugPrint('❌ [PendingCheck] BC $dan $bcVreme → odbijeno (nema mesta)');
          }
          hasChanges = true;
        }

        // Proveri VS pending
        final vsStatus = danData['vs_status']?.toString();
        final vsVreme = danData['vs']?.toString();
        final vsCekaOd = danData['vs_ceka_od']?.toString();

        if (vsStatus == 'pending' && vsVreme != null && vsVreme.isNotEmpty && vsVreme != 'null') {
          debugPrint('🔍 [PendingCheck] Pronađen VS pending za $dan: $vsVreme');

          // 🆕 Proveri starost pending zahteva (15 min timeout)
          if (vsCekaOd != null) {
            try {
              final cekaOdTime = DateTime.parse(vsCekaOd);
              final diffMinutes = now.difference(cekaOdTime).inMinutes;
              if (diffMinutes > 15) {
                // Pending zahtev je stariji od 15 minuta - automatski odbij
                (polasci[dan] as Map<String, dynamic>)['vs'] = null;
                (polasci[dan] as Map<String, dynamic>)['vs_status'] = null;
                (polasci[dan] as Map<String, dynamic>)['vs_ceka_od'] = null;
                debugPrint('⏰ [PendingCheck] VS $dan $vsVreme → EXPIRED (${diffMinutes}min) - odbijeno');
                hasChanges = true;
                continue; // Preskoči proveru mesta za expired zahteve
              }
            } catch (e) {
              debugPrint('⚠️ [PendingCheck] Greška pri parsiranju vs_ceka_od: $e');
            }
          }

          // Izračunaj ciljni datum
          final danWeekday = daniMapa[dan.toLowerCase()] ?? now.weekday;
          int diff = danWeekday - now.weekday;
          if (diff < 0) diff += 7;
          final targetDate = now.add(Duration(days: diff)).toIso8601String().split('T')[0];

          // Proveri mesta
          final imaMesta = await SlobodnaMestaService.imaSlobodnihMesta('VS', vsVreme,
              datum: targetDate, tipPutnika: _putnikData['tip']?.toString());
          if (imaMesta) {
            (polasci[dan] as Map<String, dynamic>)['vs_status'] = 'confirmed';
            debugPrint('✅ [PendingCheck] VS $dan $vsVreme → confirmed');
          } else {
            // Za VS rush hour, stavi na čekanje umesto odbijanja
            final isRushHour = ['13:00', '14:00', '15:30'].contains(vsVreme);
            if (isRushHour) {
              (polasci[dan] as Map<String, dynamic>)['vs_status'] = 'ceka_mesto';
              (polasci[dan] as Map<String, dynamic>)['vs_ceka_od'] = DateTime.now().toUtc().toIso8601String();
              debugPrint('⏳ [PendingCheck] VS $dan $vsVreme → ceka_mesto (rush hour)');
            } else {
              (polasci[dan] as Map<String, dynamic>)['vs'] = null;
              (polasci[dan] as Map<String, dynamic>)['vs_status'] = null;
              (polasci[dan] as Map<String, dynamic>)['vs_ceka_od'] = null;
              debugPrint('❌ [PendingCheck] VS $dan $vsVreme → odbijeno (nema mesta)');
            }
          }
          hasChanges = true;
        }
      }

      // Sačuvaj promene ako ih ima
      if (hasChanges) {
        // 🛡️ Merge sa postojećim markerima u bazi
        final mergedPolasci = await _mergePolasciSaBazom(putnikId, polasci);

        await Supabase.instance.client
            .from('registrovani_putnici')
            .update({'polasci_po_danu': mergedPolasci}).eq('id', putnikId);

        // Ažuriraj lokalni state
        if (mounted) {
          setState(() {
            _putnikData['polasci_po_danu'] = mergedPolasci;
          });
        }

        debugPrint('💾 [PendingCheck] Ažurirano ${hasChanges ? 'DA' : 'NE'} pending zahteva');
      }
    } catch (e) {
      debugPrint('❌ [PendingCheck] Greška: $e');
    }
  }

  /// 🧹 Očisti stare pending zahteve iz seat_requests tabele
  /// Briše zahteve starije od 1 dana
  Future<void> _cleanupOldSeatRequests() async {
    try {
      final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1)).toIso8601String();
      await Supabase.instance.client.from('seat_requests').delete().lt('created_at', yesterday).select();
    } catch (e) {
      debugPrint('❌ [Cleanup] Greška pri brisanju seat_requests: $e');
    }
  }

  // 📅 PROVERA NEDELJNOG RASPODA
  Future<void> _checkWeeklyScheduleReminder() async {
    // 1. Proveri tip putnika (samo za radnike)
    final tip = (_putnikData['tip'] ?? '').toString().toLowerCase();
    if (!tip.contains('radnik')) {
      return;
    }

    // 2. Izračunaj vreme poslednjeg reseta (Petak ponoć / Subota 00:00)
    final now = DateTime.now();
    // Weekday: Mon=1, ..., Fri=5, Sat=6, Sun=7
    int diff = (now.weekday - DateTime.saturday) % 7;
    if (diff < 0) diff += 7;
    final lastResetDate = now.subtract(Duration(days: diff));
    // Reset na 00:00:00
    final lastResetTime = DateTime(lastResetDate.year, lastResetDate.month, lastResetDate.day);

    // 3. Proveri SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final lastShownMs = prefs.getInt('last_schedule_reminder_timestamp') ?? 0;
    final lastShownTime = DateTime.fromMillisecondsSinceEpoch(lastShownMs);

    // Ako je poslednji put prikazano PRE poslednjeg reseta -> prikaži ponovo
    if (lastShownTime.isBefore(lastResetTime) && mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.calendar_month, color: Colors.blue),
              SizedBox(width: 8),
              Text('📅 Novi raspored'),
            ],
          ),
          content: const Text(
            'Stigao je novi nedeljni ciklus!\n\n'
            'Molimo vas da potvrdite ili ažurirate vaša vremena vožnje za sledeću nedelju, '
            'kako bismo na vreme organizovali prevoz.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('UREDU', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      // 4. Ažuriraj timestamp da ne prikazuje ponovo do sledećeg reset-a
      await prefs.setInt('last_schedule_reminder_timestamp', now.millisecondsSinceEpoch);
    }
  }

  Future<void> _loadStatistike() async {
    setState(() => _isLoading = true);

    try {
      final putnikId = _putnikData['id'];
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final pocetakGodine = DateTime(now.year, 1, 1);

      // Koristi voznje_log za statistiku vožnji
      // Broj vožnji ovog meseca - JEDINSTVENI DATUMI
      final voznjeResponse = await Supabase.instance.client
          .from('voznje_log')
          .select('datum')
          .eq('putnik_id', putnikId)
          .gte('datum', startOfMonth.toIso8601String().split('T')[0])
          .eq('tip', 'voznja');

      // Broji jedinstvene datume
      final jedinstveniDatumiVoznji = <String>{};
      for (final v in voznjeResponse) {
        final datum = v['datum'] as String?;
        if (datum != null) jedinstveniDatumiVoznji.add(datum);
      }
      final brojVoznji = jedinstveniDatumiVoznji.length;

      // Broj otkazivanja ovog meseca - JEDINSTVENI DATUMI
      final otkazivanjaResponse = await Supabase.instance.client
          .from('voznje_log')
          .select('datum')
          .eq('putnik_id', putnikId)
          .gte('datum', startOfMonth.toIso8601String().split('T')[0])
          .eq('tip', 'otkazivanje');

      // Broji jedinstvene datume otkazivanja
      final jedinstveniDatumiOtkazivanja = <String>{};
      for (final o in otkazivanjaResponse) {
        final datum = o['datum'] as String?;
        if (datum != null) jedinstveniDatumiOtkazivanja.add(datum);
      }
      final brojOtkazivanja = jedinstveniDatumiOtkazivanja.length;

      // Dugovanje
      final dug = _putnikData['dug'] ?? 0;

      // 🏠 Učitaj obe adrese iz tabele adrese (sa koordinatama za GPS tracking)
      String? adresaBcNaziv;
      String? adresaVsNaziv;
      double? putnikLat;
      double? putnikLng;
      final adresaBcId = _putnikData['adresa_bela_crkva_id'] as String?;
      final adresaVsId = _putnikData['adresa_vrsac_id'] as String?;
      final grad = _putnikData['grad'] as String? ?? 'BC';

      try {
        if (adresaBcId != null && adresaBcId.isNotEmpty) {
          final bcResponse = await Supabase.instance.client
              .from('adrese')
              .select('naziv, koordinate')
              .eq('id', adresaBcId)
              .maybeSingle();
          if (bcResponse != null) {
            adresaBcNaziv = bcResponse['naziv'] as String?;
            // Koordinate za BC adresu
            if (grad == 'BC' && bcResponse['koordinate'] != null) {
              final koordinate = bcResponse['koordinate'];
              if (koordinate is Map) {
                putnikLat = (koordinate['lat'] as num?)?.toDouble();
                putnikLng = (koordinate['lng'] as num?)?.toDouble();
              }
            }
          }
        }
        if (adresaVsId != null && adresaVsId.isNotEmpty) {
          final vsResponse = await Supabase.instance.client
              .from('adrese')
              .select('naziv, koordinate')
              .eq('id', adresaVsId)
              .maybeSingle();
          if (vsResponse != null) {
            adresaVsNaziv = vsResponse['naziv'] as String?;
            // Koordinate za VS adresu
            if (grad == 'VS' && vsResponse['koordinate'] != null) {
              final koordinate = vsResponse['koordinate'];
              if (koordinate is Map) {
                putnikLat = (koordinate['lat'] as num?)?.toDouble();
                putnikLng = (koordinate['lng'] as num?)?.toDouble();
              }
            }
          }
        }
      } catch (e) {
        // Error loading addresses
      }

      // 🚐 Određivanje sledećeg polaska za GPS tracking
      String? sledeciPolazak;

      // Dobavi vremena polazaka iz RouteConfig (automatski letnji/zimski)
      final vremenaPolazaka = RouteConfig.getVremenaPolazaka(
        grad: grad,
        letnji: !isZimski(now), // Automatska provera sezone
      );

      // Uzmi sledeći polazak (ili null ako nema više polazaka danas)
      sledeciPolazak = _getNextPolazak(vremenaPolazaka, now.hour, now.minute);

      // 💰 Istorija plaćanja - poslednjih 6 meseci
      final istorija = await _loadIstorijuPlacanja(putnikId);

      // 📊 Vožnje po mesecima (cela godina) - koristi voznje_log
      final sveVoznje = await Supabase.instance.client
          .from('voznje_log')
          .select('datum, tip, created_at')
          .eq('putnik_id', putnikId)
          .gte('datum', pocetakGodine.toIso8601String().split('T')[0])
          .order('datum', ascending: false);

      // Grupiši podatke po JEDINSTVENIM datumima
      final Map<String, Set<String>> voznjeDetaljnoMap = {};
      final Map<String, Set<String>> otkazivanjaDetaljnoMap = {};

      for (final v in sveVoznje) {
        final datumStr = v['datum'] as String?;
        if (datumStr == null) continue;

        final datum = DateTime.tryParse(datumStr);
        if (datum == null) continue;

        final mesecKey = '${datum.year}-${datum.month.toString().padLeft(2, '0')}';
        final tip = v['tip'] as String?;

        if (tip == 'otkazivanje') {
          // Otkazivanja
          otkazivanjaDetaljnoMap[mesecKey] = {...(otkazivanjaDetaljnoMap[mesecKey] ?? {}), datumStr};
        } else if (tip == 'voznja') {
          // Vožnje
          voznjeDetaljnoMap[mesecKey] = {...(voznjeDetaljnoMap[mesecKey] ?? {}), datumStr};
        }
      }

      // Izračunaj ukupno zaduženje
      final tipPutnika = _putnikData['tip'] ?? 'radnik';
      final cenaPoVoznji = CenaObracunService.getDefaultCenaByTip(tipPutnika);
      double ukupnoVoznji = 0;
      for (final lista in voznjeDetaljnoMap.values) {
        ukupnoVoznji += lista.length;
      }
      final ukupnoZaplacanje = ukupnoVoznji * cenaPoVoznji;

      // Ukupno plaćeno
      double ukupnoPlaceno = 0;
      for (final p in istorija) {
        ukupnoPlaceno += (p['iznos'] as double? ?? 0);
      }

      final zaduzenje = ukupnoZaplacanje - ukupnoPlaceno;

      setState(() {
        _brojVoznji = brojVoznji;
        _brojOtkazivanja = brojOtkazivanja;
        _dugovanje = (dug is int) ? dug.toDouble() : (dug as double);
        _istorijaPl = istorija;
        _voznjeDetaljno = voznjeDetaljnoMap;
        _otkazivanjaDetaljno = otkazivanjaDetaljnoMap;
        _ukupnoZaduzenje = zaduzenje;
        _adresaBC = adresaBcNaziv;
        _adresaVS = adresaVsNaziv;
        _putnikLat = putnikLat;
        _putnikLng = putnikLng;
        _sledeciPolazak = sledeciPolazak;
        // Odredi smer ture - ako je grad BC, putnik ide BC->VS, ako je VS ide VS->BC
        _smerTure = (grad == 'BC' || grad == 'Bela Crkva') ? 'BC_VS' : 'VS_BC';
        // 🆕 Izračunaj sledeću vožnju za Fazu 4
        _sledecaVoznjaInfo = _izracunajSledecuVoznju();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /// 🕐 Nađi sledeći polazak na osnovu trenutnog vremena
  /// Vraća polazak od 30 min PRE termina. Widget sam upravlja nestajanjem nakon pokupljenja.
  String? _getNextPolazak(List<String> vremena, int currentHour, int currentMinute) {
    final currentMinutes = currentHour * 60 + currentMinute;

    for (final vreme in vremena) {
      final parts = vreme.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final polazakMinutes = hour * 60 + minute;

      // Prozor za praćenje: 30 min pre polaska do 120 min posle (fallback)
      // Widget sam nestaje 60 min nakon pokupljenja ili kad vozač završi turu
      final windowStart = polazakMinutes - 30; // 30 min pre polaska
      final windowEnd = polazakMinutes + 120; // 120 min posle polaska (safety fallback)

      if (currentMinutes >= windowStart && currentMinutes <= windowEnd) {
        return vreme;
      }
    }

    return null; // Nema polazaka u aktivnom prozoru
  }

  /// 🆕 Izračunaj sledeću zakazanu vožnju putnika
  /// Vraća format: "Ponedeljak, 7:00 BC" ili null ako nema zakazanih vožnji
  String? _izracunajSledecuVoznju() {
    try {
      final polasciPoDanu = _putnikData['polasci_po_danu'];
      if (polasciPoDanu == null) return null;

      final now = DateTime.now();
      final daniNedelje = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      final daniPuniNaziv = {
        'pon': 'Ponedeljak',
        'uto': 'Utorak',
        'sre': 'Sreda',
        'cet': 'Četvrtak',
        'pet': 'Petak',
        'sub': 'Subota',
        'ned': 'Nedelja',
      };

      // Prođi kroz narednih 7 dana
      for (int i = 0; i < 7; i++) {
        final checkDate = now.add(Duration(days: i));
        final danIndex = checkDate.weekday - 1; // 0-6 (pon-ned)
        if (danIndex >= daniNedelje.length) continue;

        final dan = daniNedelje[danIndex];
        final polasciZaDan = polasciPoDanu[dan];
        if (polasciZaDan == null) continue;

        // Uzmi BC ili VS polazak
        String? polazak;
        String? grad;
        if (polasciZaDan is Map) {
          final bc = polasciZaDan['bc'] as String?;
          final vs = polasciZaDan['vs'] as String?;
          if (bc != null && bc.isNotEmpty && bc != '00:00:00') {
            polazak = bc.replaceAll(':00', '').replaceFirst(RegExp('^0'), '');
            grad = 'BC';
          } else if (vs != null && vs.isNotEmpty && vs != '00:00:00') {
            polazak = vs.replaceAll(':00', '').replaceFirst(RegExp('^0'), '');
            grad = 'VS';
          }
        }

        if (polazak == null || grad == null) continue;

        // Ako je danas, proveri da li je polazak već prošao
        if (i == 0) {
          final parts = polazak.split(':');
          final polazakHour = int.tryParse(parts[0]) ?? 0;
          final polazakMinute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          final polazakMinutes = polazakHour * 60 + polazakMinute;
          final currentMinutes = now.hour * 60 + now.minute;

          // Ako je polazak prošao, preskoči danas
          if (polazakMinutes < currentMinutes - 30) continue;
        }

        // Formatiraj rezultat
        final danNaziv = daniPuniNaziv[dan] ?? dan;
        return '$danNaziv, $polazak $grad';
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 💰 Učitaj istoriju plaćanja - od 1. januara tekuće godine
  /// 🔄 POJEDNOSTAVLJENO: Koristi voznje_log
  Future<List<Map<String, dynamic>>> _loadIstorijuPlacanja(String putnikId) async {
    try {
      final now = DateTime.now();
      final pocetakGodine = DateTime(now.year, 1, 1);

      // Koristi voznje_log za uplate
      final placanja = await Supabase.instance.client
          .from('voznje_log')
          .select('iznos, datum, created_at')
          .eq('putnik_id', putnikId)
          .inFilter('tip', ['uplata', 'uplata_mesecna', 'uplata_dnevna'])
          .gte('datum', pocetakGodine.toIso8601String().split('T')[0])
          .order('datum', ascending: false);

      // Grupiši po mesecima
      final Map<String, double> poMesecima = {};
      final Map<String, DateTime> poslednjeDatum = {};

      for (final p in placanja) {
        final datumStr = p['datum'] as String?;
        if (datumStr == null) continue;

        final datum = DateTime.tryParse(datumStr);
        if (datum == null) continue;

        final mesecKey = '${datum.year}-${datum.month.toString().padLeft(2, '0')}';
        final iznos = (p['iznos'] as num?)?.toDouble() ?? 0.0;

        poMesecima[mesecKey] = (poMesecima[mesecKey] ?? 0.0) + iznos;

        // Zapamti poslednji datum uplate za taj mesec
        if (!poslednjeDatum.containsKey(mesecKey) || datum.isAfter(poslednjeDatum[mesecKey]!)) {
          poslednjeDatum[mesecKey] = datum;
        }
      }

      // Konvertuj u listu sortiranu po datumu (najnoviji prvi)
      final result = poMesecima.entries.map((e) {
        final parts = e.key.split('-');
        final godina = int.parse(parts[0]);
        final mesec = int.parse(parts[1]);
        return {'mesec': mesec, 'godina': godina, 'iznos': e.value, 'datum': poslednjeDatum[e.key]};
      }).toList();

      result.sort((a, b) {
        final dateA = DateTime(a['godina'] as int, a['mesec'] as int);
        final dateB = DateTime(b['godina'] as int, b['mesec'] as int);
        return dateB.compareTo(dateA);
      });

      return result;
    } catch (e) {
      return [];
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Odjava?', style: TextStyle(color: Colors.white)),
        content: Text('Da li želiš da se odjaviš?', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ne')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Da, odjavi me'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('registrovani_putnik_telefon');

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  /// 🏖️ Dugme za postavljanje bolovanja/godišnjeg - SAMO za radnike
  Widget _buildOdsustvoButton() {
    final status = _putnikData['status']?.toString().toLowerCase() ?? 'radi';
    final jeNaOdsustvu = status == 'bolovanje' || status == 'godisnji';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: ListTile(
          leading: Icon(
            jeNaOdsustvu ? Icons.work : Icons.beach_access,
            color: jeNaOdsustvu ? Colors.green : Colors.orange,
          ),
          title: Text(
            jeNaOdsustvu ? 'Vratite se na posao' : 'Godišnji / Bolovanje',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            jeNaOdsustvu
                ? 'Trenutno ste na ${status == "godisnji" ? "godišnjem odmoru" : "bolovanju"}'
                : 'Postavite se na odsustvo',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
          onTap: () => _pokaziOdsustvoDialog(jeNaOdsustvu),
        ),
      ),
    );
  }

  /// 🏖️ Dialog za odabir tipa odsustva ili vraćanje na posao
  Future<void> _pokaziOdsustvoDialog(bool jeNaOdsustvu) async {
    if (jeNaOdsustvu) {
      // Vraćanje na posao
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Row(
            children: [
              Icon(Icons.work, color: Colors.green),
              SizedBox(width: 8),
              Expanded(child: Text('Povratak na posao')),
            ],
          ),
          content: const Text('Da li želite da se vratite na posao?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ne')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Da, vraćam se'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _postaviStatus('radi');
      }
    } else {
      // Odabir tipa odsustva
      final odabraniStatus = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Row(
            children: [
              Icon(Icons.beach_access, color: Colors.orange),
              SizedBox(width: 8),
              Text('Odsustvo'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Izaberite tip odsustva:'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'godisnji'),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'bolovanje'),
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
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Odustani'))],
        ),
      );

      if (odabraniStatus != null) {
        await _postaviStatus(odabraniStatus);
      }
    }
  }

  /// 🔄 Postavi status putnika u bazu
  Future<void> _postaviStatus(String noviStatus) async {
    try {
      final putnikId = _putnikData['id']?.toString();
      if (putnikId == null) return;

      await PutnikService().oznaciBolovanjeGodisnji(
        putnikId,
        noviStatus,
        'self', // Radnik sam sebi menja status
      );

      // Ažuriraj lokalni state
      setState(() {
        _putnikData['status'] = noviStatus;
      });

      if (mounted) {
        final poruka = noviStatus == 'radi'
            ? '✅ Vraćeni ste na posao'
            : noviStatus == 'godisnji'
                ? '🏖️ Postavljeni ste na godišnji odmor'
                : '🤒 Postavljeni ste na bolovanje';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(poruka), backgroundColor: noviStatus == 'radi' ? Colors.green : Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Greška: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // 🌤️ KOMPAKTAN PRIKAZ TEMPERATURE ZA GRAD (isti kao na danas_screen)
  Widget _buildWeatherCompact(String grad) {
    final stream = grad == 'BC' ? WeatherService.bcWeatherStream : WeatherService.vsWeatherStream;

    return StreamBuilder<WeatherData?>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final temp = data?.temperature;
        final icon = data?.icon ?? '🌡️';
        final tempStr = temp != null ? '${temp.round()}°' : '--';
        final tempColor = temp != null
            ? (temp < 0
                ? Colors.lightBlue
                : temp < 15
                    ? Colors.cyan
                    : temp < 25
                        ? Colors.green
                        : Colors.orange)
            : Colors.grey;

        // Widget za ikonu - slika ili emoji (usklađene veličine)
        Widget iconWidget;
        if (WeatherData.isAssetIcon(icon)) {
          iconWidget = Image.asset(WeatherData.getAssetPath(icon), width: 32, height: 32);
        } else {
          iconWidget = Text(icon, style: const TextStyle(fontSize: 14));
        }

        return GestureDetector(
          onTap: () => _showWeatherDialog(grad, data),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              const SizedBox(width: 2),
              Text(
                '$grad $tempStr',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tempColor,
                  shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black54)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🏆💀 MINI LEADERBOARD - Fame ili Shame - PRIVREMENO ISKLJUČENO
  /*
  Widget _buildMiniLeaderboard({required bool isShame}) {
    return FutureBuilder<LeaderboardData?>(
      future: LeaderboardService.getLeaderboard(tipPutnika: _putnikData['tip'] as String? ?? 'radnik'),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        final entries = isShame ? data.wallOfShame : data.wallOfFame;
        final title = isShame ? '💀 Shame' : '🏆 Fame';
        final titleColor = isShame ? Colors.redAccent : Colors.greenAccent;

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isShame
                  ? [Colors.red.shade900.withValues(alpha: 0.15), Colors.orange.shade900.withValues(alpha: 0.1)]
                  : [Colors.green.shade900.withValues(alpha: 0.15), Colors.teal.shade900.withValues(alpha: 0.1)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (isShame ? Colors.red : Colors.green).withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              if (entries.isEmpty)
                Text(
                  'Nema podataka',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ...entries.take(3).toList().asMap().entries.map((e) {
                  final rank = e.key + 1;
                  final entry = e.value;
                  String displayName = entry.ime;
                  if (displayName.length > 10) {
                    final parts = displayName.split(' ');
                    if (parts.length >= 2) {
                      displayName = '${parts[0]} ${parts[1][0]}.';
                    } else {
                      displayName = '${displayName.substring(0, 8)}..';
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      children: [
                        Text(
                          '$rank.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(entry.icon, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
  */

  // 🌤️ DIJALOG ZA DETALJNU VREMENSKU PROGNOZU
  void _showWeatherDialog(String grad, WeatherData? data) {
    final gradPun = grad == 'BC' ? 'Bela Crkva' : 'Vršac';

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
          decoration: BoxDecoration(
            gradient: Theme.of(context).backgroundGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).glassBorder, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).glassContainer,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '🌤️ Vreme - $gradPun',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: data != null
                    ? Column(
                        children: [
                          // Upozorenje za kišu/sneg
                          if (data.willSnow)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('❄️', style: TextStyle(fontSize: 20)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'SNEG ${data.precipitationStartTime ?? 'SADA'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (data.willRain)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.indigo.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🌧️', style: TextStyle(fontSize: 20)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'KIŠA ${data.precipitationStartTime ?? 'SADA'}${data.precipitationProbability != null ? ' (${data.precipitationProbability}%)' : ''}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Velika ikona i temperatura
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (WeatherData.isAssetIcon(data.icon))
                                Image.asset(WeatherData.getAssetPath(data.icon), width: 80, height: 80)
                              else
                                Text(data.icon, style: const TextStyle(fontSize: 60)),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${data.temperature.round()}°C',
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold,
                                      color: data.temperature < 0
                                          ? Colors.lightBlue
                                          : data.temperature < 15
                                              ? Colors.cyan
                                              : data.temperature < 25
                                                  ? Colors.white
                                                  : Colors.orange,
                                      shadows: const [
                                        Shadow(offset: Offset(2, 2), blurRadius: 4, color: Colors.black54),
                                      ],
                                    ),
                                  ),
                                  if (data.tempMin != null && data.tempMax != null)
                                    Text(
                                      '${data.tempMin!.round()}° / ${data.tempMax!.round()}°',
                                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Opis baziran na weather code
                          Text(
                            _getWeatherDescription(data.dailyWeatherCode ?? data.weatherCode),
                            style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : const Center(
                        child: Text('Podaci nisu dostupni', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getWeatherDescription(int code) {
    if (code == 0) return 'Vedro nebo';
    if (code == 1) return 'Pretežno vedro';
    if (code == 2) return 'Delimično oblačno';
    if (code == 3) return 'Oblačno';
    if (code >= 45 && code <= 48) return 'Magla';
    if (code >= 51 && code <= 55) return 'Sitna kiša';
    if (code >= 56 && code <= 57) return 'Ledena kiša';
    if (code >= 61 && code <= 65) return 'Kiša';
    if (code >= 66 && code <= 67) return 'Ledena kiša';
    if (code >= 71 && code <= 77) return 'Sneg';
    if (code >= 80 && code <= 82) return 'Pljuskovi';
    if (code >= 85 && code <= 86) return 'Snežni pljuskovi';
    if (code >= 95 && code <= 99) return 'Grmljavina';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    // Ime može biti u 'putnik_ime' ili odvojeno 'ime'/'prezime'
    final putnikIme = _putnikData['putnik_ime'] as String? ?? '';
    final ime = _putnikData['ime'] as String? ?? '';
    final prezime = _putnikData['prezime'] as String? ?? '';
    final fullName = putnikIme.isNotEmpty ? putnikIme : '$ime $prezime'.trim();

    // Razdvoji ime i prezime za avatar
    final nameParts = fullName.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.last : '';

    final telefon = _putnikData['broj_telefona'] as String? ?? '-';
    // ignore: unused_local_variable
    final grad = _putnikData['grad'] as String? ?? 'BC';
    final tip = _putnikData['tip'] as String? ?? 'radnik';
    // ignore: unused_local_variable
    final aktivan = _putnikData['aktivan'] as bool? ?? true;

    return Container(
      decoration: BoxDecoration(gradient: ThemeManager().currentGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            '👤 Moj profil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.palette, color: Colors.white),
              tooltip: 'Tema',
              onPressed: () async {
                await ThemeManager().nextTheme();
                if (mounted) setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: _logout,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 🌤️ VREMENSKA PROGNOZA - BC levo, VS desno
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Center(child: _buildWeatherCompact('BC'))),
                          const SizedBox(width: 16),
                          Expanded(child: Center(child: _buildWeatherCompact('VS'))),
                        ],
                      ),
                    ),
                    // Ime i status - Flow dizajn bez Card okvira
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Avatar - glassmorphism stil
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: tip == 'ucenik'
                                    ? [Colors.blue.shade400, Colors.indigo.shade600]
                                    : [Colors.orange.shade400, Colors.deepOrange.shade600],
                              ),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: (tip == 'ucenik' ? Colors.blue : Colors.orange).withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '${firstName.isNotEmpty ? firstName[0].toUpperCase() : ''}${lastName.isNotEmpty ? lastName[0].toUpperCase() : ''}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                  shadows: [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black38)],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Ime
                          Text(
                            fullName,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),

                          // Tip i grad
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tip == 'ucenik'
                                      ? Colors.blue.withValues(alpha: 0.3)
                                      : tip == 'dnevni'
                                          ? Colors.green.withValues(alpha: 0.3)
                                          : Colors.orange.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  tip == 'ucenik'
                                      ? '🎓 Učenik'
                                      : tip == 'dnevni'
                                          ? '📅 Dnevni'
                                          : '💼 Radnik',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if (telefon.isNotEmpty && telefon != '-') ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.phone, color: Colors.white70, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        telefon,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Adrese - BC levo, VS desno
                          if (_adresaBC != null || _adresaVS != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_adresaBC != null && _adresaBC!.isNotEmpty) ...[
                                  Icon(Icons.home, color: Colors.white70, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    _adresaBC!,
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                                  ),
                                ],
                                if (_adresaBC != null && _adresaVS != null) const SizedBox(width: 16),
                                if (_adresaVS != null && _adresaVS!.isNotEmpty) ...[
                                  Icon(Icons.work, color: Colors.white70, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    _adresaVS!,
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─────────── Divider ───────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Divider(color: Colors.white.withValues(alpha: 0.2), thickness: 1),
                    ),

                    // 🚐 ETA Widget sa 4 faze:
                    // 1. 30 min pre polaska: "Vozač će uskoro krenuti"
                    // 2. Vozač startovao rutu: Realtime ETA praćenje
                    // 3. Pokupljen: "Pokupljeni ste u HH:MM" (stoji 60 min) - ČITA IZ BAZE!
                    // 4. Nakon 60 min: "Vaša sledeća vožnja: dan, vreme"
                    if (_sledeciPolazak != null || _sledecaVoznjaInfo != null)
                      KombiEtaWidget(
                        putnikIme: fullName,
                        grad: grad,
                        vremePolaska: _sledeciPolazak,
                        sledecaVoznja: _sledecaVoznjaInfo,
                        putnikId: _putnikData['id']?.toString(), // 🆕 Za čitanje pokupljenja iz baze
                      ),

                    // ─────────── Divider ───────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Divider(color: Colors.white.withValues(alpha: 0.2), thickness: 1),
                    ),

                    // 🏆💀 FAME | SHAME - PRIVREMENO ISKLJUČENO
                    // if (tip == 'ucenik')
                    //   Padding(
                    //     padding: const EdgeInsets.symmetric(vertical: 8),
                    //     child: Row(
                    //       crossAxisAlignment: CrossAxisAlignment.start,
                    //       children: [
                    //         // 🏆 FAME - levo
                    //         Expanded(child: _buildMiniLeaderboard(isShame: false)),
                    //         const SizedBox(width: 16),
                    //         // 💀 SHAME - desno
                    //         Expanded(child: _buildMiniLeaderboard(isShame: true)),
                    //       ],
                    //     ),
                    //   ),

                    // ─────────── Divider ───────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Divider(color: Colors.white.withValues(alpha: 0.2), thickness: 1),
                    ),
                    const SizedBox(height: 8),

                    // Statistike
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard('🚌', 'Vožnje', _brojVoznji.toString(), Colors.blue, 'ovaj mesec'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            '❌',
                            'Otkazano',
                            _brojOtkazivanja.toString(),
                            Colors.orange,
                            'ovaj mesec',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 🏖️ Bolovanje/Godišnji dugme - SAMO za radnike
                    if (_putnikData['tip']?.toString().toLowerCase() == 'radnik') ...[
                      _buildOdsustvoButton(),
                      const SizedBox(height: 16),
                    ],

                    // 💰 TRENUTNO ZADUŽENJE
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _ukupnoZaduzenje > 0
                              ? [Colors.red.withValues(alpha: 0.2), Colors.red.withValues(alpha: 0.05)]
                              : [Colors.green.withValues(alpha: 0.2), Colors.green.withValues(alpha: 0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _ukupnoZaduzenje > 0
                              ? Colors.red.withValues(alpha: 0.3)
                              : Colors.green.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'TRENUTNO STANJE',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _ukupnoZaduzenje > 0 ? '${_ukupnoZaduzenje.toStringAsFixed(0)} RSD' : 'IZMIRENO ✓',
                            style: TextStyle(
                              color: _ukupnoZaduzenje > 0 ? Colors.red.shade200 : Colors.green.shade200,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 📊 Detaljne statistike - dugme za dijalog
                    _buildDetaljneStatistikeDugme(),
                    const SizedBox(height: 16),

                    // 📅 Raspored polazaka
                    _buildRasporedCard(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(String emoji, String label, String value, Color color, String subtitle) {
    // Flow dizajn - bez Card okvira
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
        ],
      ),
    );
  }

  /// 📅 Widget za prikaz rasporeda polazaka po danima - GRID STIL kao "Vremena polaska"
  Widget _buildRasporedCard() {
    // Parsiranje polasci_po_danu iz putnikData
    final polasciRaw = _putnikData['polasci_po_danu'];
    Map<String, Map<String, String?>> polasci = {};

    // Helper funkcija za sigurno parsiranje vremena
    String? parseVreme(dynamic value) {
      if (value == null) return null;
      final str = value.toString().trim();
      if (str.isEmpty || str == 'null') return null;
      return str;
    }

    if (polasciRaw != null && polasciRaw is Map) {
      polasciRaw.forEach((key, value) {
        if (value is Map) {
          polasci[key.toString()] = {
            'bc': parseVreme(value['bc']),
            'vs': parseVreme(value['vs']),
            'bc_status': parseVreme(value['bc_status']),
            'vs_status': parseVreme(value['vs_status']),
            'bc_otkazano': parseVreme(value['bc_otkazano']),
            'vs_otkazano': parseVreme(value['vs_otkazano']),
            'bc_otkazano_vreme': parseVreme(value['bc_otkazano_vreme']),
            'vs_otkazano_vreme': parseVreme(value['vs_otkazano_vreme']),
          };
        }
      });
    }

    final dani = ['pon', 'uto', 'sre', 'cet', 'pet'];
    final daniLabels = {'pon': 'Ponedeljak', 'uto': 'Utorak', 'sre': 'Sreda', 'cet': 'Četvrtak', 'pet': 'Petak'};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Center(
            child: Text(
              '🕐 Vremena polaska',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),

          // Header row - BC / VS
          Row(
            children: [
              const SizedBox(width: 100), // Prostor za naziv dana
              Expanded(
                child: Center(
                  child: Text(
                    'BC',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Grid za svaki dan
          ...dani.map((dan) {
            final danPolasci = polasci[dan];
            final bcVreme = danPolasci?['bc'];
            final vsVreme = danPolasci?['vs'];
            final bcStatus = danPolasci?['bc_status']?.toString();
            // 🆕 Mapiranje 'ceka_mesto' statusa u 'waiting' za UI
            final vsStatusRaw = danPolasci?['vs_status']?.toString();
            final vsStatus = vsStatusRaw == 'ceka_mesto' ? 'waiting' : vsStatusRaw;
            final bcOtkazano = danPolasci?['bc_otkazano'] != null;
            final vsOtkazano = danPolasci?['vs_otkazano'] != null;
            // 🆕 Otkazano vreme - prikazuje se u crvenom
            final bcOtkazanoVreme = danPolasci?['bc_otkazano_vreme'];
            final vsOtkazanoVreme = danPolasci?['vs_otkazano_vreme'];
            // Ako je otkazano, prikaži staro vreme; inače prikaži trenutno vreme
            final bcDisplayVreme = bcOtkazano ? bcOtkazanoVreme : bcVreme;
            final vsDisplayVreme = vsOtkazano ? vsOtkazanoVreme : vsVreme;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Naziv dana
                  SizedBox(
                    width: 100,
                    child: Text(daniLabels[dan] ?? dan, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                  // BC vreme - sa TimePickerCell
                  Expanded(
                    child: Center(
                      child: TimePickerCell(
                        value: bcDisplayVreme,
                        isBC: true,
                        status: bcStatus,
                        dayName: dan,
                        isCancelled: bcOtkazano,
                        tipPutnika: _putnikData['tip']?.toString(), // 🆕 Za proveru dnevnog zakazivanja
                        onChanged: (newValue) => _updatePolazak(dan, 'bc', newValue),
                      ),
                    ),
                  ),
                  // VS vreme - sa TimePickerCell
                  Expanded(
                    child: Center(
                      child: TimePickerCell(
                        value: vsDisplayVreme,
                        isBC: false,
                        status: vsStatus,
                        dayName: dan,
                        isCancelled: vsOtkazano,
                        tipPutnika: _putnikData['tip']?.toString(), // 🆕 Za proveru dnevnog zakazivanja
                        onChanged: (newValue) => _updatePolazak(dan, 'vs', newValue),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 🕐 Ažurira polazak za određeni dan i čuva u bazu
  /// - BC učenici: 10 min čekanje + provera mesta (danas) ili bez provere (naredni do 16h)
  /// - BC radnici: odmah provera mesta (bez čekanja)
  /// - VS svi: odmah čuvanje bez provere
  Future<void> _updatePolazak(String dan, String tipGrad, String? novoVreme) async {
    // 📅 BLOKADA PETKOM (za učenike i radnike)
    // Ako je danas PETAK, zabrani menjanje bilo kog dana osim (eventualno) današnjeg,
    // ali ovde blokiramo SVE jer je jednostavnije i sigurnije.
    final now = DateTime.now();
    if (now.weekday == DateTime.friday) {
      final tip = (_putnikData['tip'] ?? '').toString().toLowerCase();

      // Samo za radnike i učenike
      if (tip.contains('radnik') || tip.contains('ucenik')) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.calendar_month_outlined, color: Colors.blue),
                SizedBox(width: 8),
                Text('Priprema rasporeda'),
              ],
            ),
            content: const Text(
                'Zakazivanje termina za narednu nedelju počinje u petak posle ponoći (subota).\n\n'
                'Ovaj kratak prekid je neophodan kako bismo zatvorili trenutni ciklus i pripremili optimalne uslove za sledeću nedelju, radi osiguranja maksimalne tačnosti i kvaliteta usluge.\n\n'
                'Molimo vas da vaš novi raspored unesete sutra.',
                style: TextStyle(fontSize: 16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('RAZUMEM', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return; // 🛑 PREKINI IZVRŠAVANJE, NE MENJAJ NIŠTA
      }
    }

    debugPrint('🚀 [BC] _updatePolazak pozvan: dan=$dan, tipGrad=$tipGrad, novoVreme=$novoVreme');

    try {
      final putnikId = _putnikData['id']?.toString();
      final tipPutnika = _putnikData['tip']?.toString();
      final jeUcenik = tipPutnika == 'ucenik';
      final jeRadnik = tipPutnika == 'radnik';
      final jeDnevni = tipPutnika == 'dnevni';
      final jeBcUcenikZahtev = tipGrad == 'bc' && jeUcenik && novoVreme != null;
      final jeBcRadnikZahtev = tipGrad == 'bc' && jeRadnik && novoVreme != null;
      final jeBcDnevniZahtev = tipGrad == 'bc' && jeDnevni && novoVreme != null;

      debugPrint('📋 [BC] tipPutnika=$tipPutnika, jeUcenik=$jeUcenik, jeRadnik=$jeRadnik, jeDnevni=$jeDnevni');
      debugPrint(
        '📋 [BC] jeBcUcenikZahtev=$jeBcUcenikZahtev, jeBcRadnikZahtev=$jeBcRadnikZahtev, jeBcDnevniZahtev=$jeBcDnevniZahtev',
      );

      // Ažuriraj lokalno - ČUVAJ SVE PODATKE (pokupljeno, placeno, otkazano, itd.)
      final polasciRaw = _putnikData['polasci_po_danu'] ?? {};
      Map<String, dynamic> polasci = {};

      if (polasciRaw is Map) {
        polasciRaw.forEach((key, value) {
          if (value is Map) {
            polasci[key.toString()] = Map<String, dynamic>.from(value);
          } else {
            polasci[key.toString()] = {'bc': null, 'vs': null};
          }
        });
      }

      // Osiguraj da dan postoji
      polasci[dan] ??= <String, dynamic>{'bc': null, 'vs': null};

      // 🔴 OTKAZIVANJE - ako putnik briše vreme, zabeleži kao otkazano SA STARIM VREMENOM
      if (novoVreme == null) {
        final staroVreme = (polasci[dan] as Map<String, dynamic>)[tipGrad];
        final staroVremeStr = staroVreme?.toString() ?? '';
        final otkazanoKey = '${tipGrad}_otkazano';
        final otkazanoVremeKey = '${tipGrad}_otkazano_vreme';
        (polasci[dan] as Map<String, dynamic>)[otkazanoKey] = DateTime.now().toUtc().toIso8601String();
        // 🆕 Sačuvaj staro vreme da bi se moglo prikazati u crvenom
        if (staroVreme != null && staroVremeStr.isNotEmpty) {
          (polasci[dan] as Map<String, dynamic>)[otkazanoVremeKey] = staroVreme;
        }
        debugPrint('🔴 [$tipGrad] Putnik otkazao za $dan (staro vreme: $staroVreme)');

        // 🆕 AKO JE VS RUSH HOUR OTKAZIVANJE - obavesti sve koji čekaju
        if (tipGrad == 'vs' && ['13:00', '14:00', '15:30'].contains(staroVremeStr)) {
          debugPrint('🔔 [VS] Rush Hour otkazivanje - proveravamo ko čeka za $staroVremeStr');
          // Asinhrono obavesti (ne blokiraj UI)
          _notifyWaitingPassengers(staroVremeStr, dan);
        }
      } else {
        // Ako postavlja novo vreme, očisti otkazano
        final otkazanoKey = '${tipGrad}_otkazano';
        final otkazanoVremeKey = '${tipGrad}_otkazano_vreme';
        (polasci[dan] as Map<String, dynamic>)[otkazanoKey] = null;
        (polasci[dan] as Map<String, dynamic>)[otkazanoVremeKey] = null;
      }

      // Ažuriraj samo vreme, čuvaj ostale podatke
      (polasci[dan] as Map<String, dynamic>)[tipGrad] = novoVreme;
      // Očisti "null" string ako je prisutan
      if ((polasci[dan] as Map<String, dynamic>)[tipGrad] == 'null') {
        (polasci[dan] as Map<String, dynamic>)[tipGrad] = null;
      }

      // Sačuvaj u bazu
      if (putnikId != null) {
        // Automatski ažuriraj radni_dani na osnovu polasci_po_danu
        final Set<String> radniDaniSet = {};
        polasci.forEach((danKey, vrednosti) {
          if (vrednosti is Map) {
            final bcVreme = vrednosti['bc']?.toString();
            final vsVreme = vrednosti['vs']?.toString();
            if ((bcVreme != null && bcVreme.isNotEmpty && bcVreme != 'null') ||
                (vsVreme != null && vsVreme.isNotEmpty && vsVreme != 'null')) {
              radniDaniSet.add(danKey);
            }
          }
        });
        final noviRadniDani = radniDaniSet.join(',');

        if (jeBcUcenikZahtev) {
          // ⏱️ BC UČENIK - 10 min čekanje
          // (jeDanas i jePre16h variables uklonjene - nisu više potrebne)

          // 1. Sačuvaj odmah sa statusom pending + timestamp za autonomni sistem
          (polasci[dan] as Map<String, dynamic>)['bc_status'] = 'pending';
          (polasci[dan] as Map<String, dynamic>)['bc_ceka_od'] = DateTime.now().toUtc().toIso8601String();

          // 🛡️ Merge sa postojećim markerima u bazi
          final mergedPolasci = await _mergePolasciSaBazom(putnikId, polasci);

          await Supabase.instance.client
              .from('registrovani_putnici')
              .update({'polasci_po_danu': mergedPolasci, 'radni_dani': noviRadniDani}).eq('id', putnikId);

          // Ažuriraj lokalni state
          setState(() {
            _putnikData['polasci_po_danu'] = polasci;
            _putnikData['radni_dani'] = noviRadniDani;
          });

          // Prikaži poruku "zahtev primljen"
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '✅ Vaš zahtev je primljen i biće obrađen uskoro',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.blueGrey,
                duration: Duration(seconds: 5),
              ),
            );
          }

          debugPrint('✅ [BC] UČENIK: Zahtev sačuvan sa pending statusom');
        } else if (jeBcRadnikZahtev) {
          // 👷 BC RADNIK - sačuvaj kao pending, čekaj 5 minuta, proveri mesta

          (polasci[dan] as Map<String, dynamic>)['bc_status'] = 'pending';
          (polasci[dan] as Map<String, dynamic>)['bc_ceka_od'] = DateTime.now().toUtc().toIso8601String();

          // 🛡️ Merge sa postojećim markerima u bazi
          final mergedPolasci = await _mergePolasciSaBazom(putnikId, polasci);

          await Supabase.instance.client
              .from('registrovani_putnici')
              .update({'polasci_po_danu': mergedPolasci, 'radni_dani': noviRadniDani}).eq('id', putnikId);

          setState(() {
            _putnikData['polasci_po_danu'] = mergedPolasci;
            _putnikData['radni_dani'] = noviRadniDani;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '✅ Vaš zahtev je primljen i trenutno je u obradi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.blueGrey,
                duration: Duration(seconds: 5),
              ),
            );
          }

          debugPrint('✅ [BC] RADNIK: Zahtev sačuvan sa pending statusom');
        } else if (jeBcDnevniZahtev) {
          // 📅 BC DNEVNI - Wait 10 min then check
          (polasci[dan] as Map<String, dynamic>)['bc_status'] = 'pending';
          (polasci[dan] as Map<String, dynamic>)['bc_ceka_od'] = DateTime.now().toUtc().toIso8601String();

          // 🛡️ Merge sa postojećim markerima u bazi
          final mergedPolasci = await _mergePolasciSaBazom(putnikId, polasci);

          await Supabase.instance.client
              .from('registrovani_putnici')
              .update({'polasci_po_danu': mergedPolasci, 'radni_dani': noviRadniDani}).eq('id', putnikId);

          setState(() {
            _putnikData['polasci_po_danu'] = mergedPolasci;
            _putnikData['radni_dani'] = noviRadniDani;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '📨 Vaš zahtev je evidentiran! Proveravamo raspoloživost mesta i javljamo vam se u najkraćem mogućem roku!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 5),
              ),
            );
          }

          debugPrint('🎯 [BC] DNEVNI: Pending zahtev sačuvan');
        } else if (tipGrad == 'vs' && novoVreme != null && jeDnevni) {
          // 📅 VS DNEVNI - Wait 10 min then check
          (polasci[dan] as Map<String, dynamic>)['vs_status'] = 'pending';
          (polasci[dan] as Map<String, dynamic>)['vs_ceka_od'] = DateTime.now().toUtc().toIso8601String();

          // 🛡️ Merge sa postojećim markerima u bazi
          final mergedPolasci = await _mergePolasciSaBazom(putnikId, polasci);

          await Supabase.instance.client
              .from('registrovani_putnici')
              .update({'polasci_po_danu': mergedPolasci, 'radni_dani': noviRadniDani}).eq('id', putnikId);

          setState(() {
            _putnikData['polasci_po_danu'] = mergedPolasci;
            _putnikData['radni_dani'] = noviRadniDani;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '📨 Vaš zahtev je evidentiran! Proveravamo raspoloživost mesta i javljamo vam se u najkraćem mogućem roku!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 5),
              ),
            );
          }

          debugPrint('🎯 [VS] DNEVNI: Pending zahtev sačuvan');
        } else if (tipGrad == 'vs' && novoVreme != null) {
          // 🚐 VS LOGIKA - Pending + Timer + Provera mesta (za SVE dane)
          final danas = DateTime.now();
          const daniMapa = {'pon': 1, 'uto': 2, 'sre': 3, 'cet': 4, 'pet': 5, 'sub': 6, 'ned': 7};
          final danWeekday = daniMapa[dan.toLowerCase()] ?? danas.weekday;
          final jeDanas = danWeekday == danas.weekday;

          debugPrint('🎯 [VS] ZAHTEV - Pending status, 10 min timer (jeDanas=$jeDanas)');

          // Postavi status na pending
          (polasci[dan] as Map<String, dynamic>)['vs_status'] = 'pending';
          (polasci[dan] as Map<String, dynamic>)['vs_ceka_od'] = DateTime.now().toUtc().toIso8601String();

          // 🛡️ Merge sa postojećim markerima u bazi
          final mergedPolasci = await _mergePolasciSaBazom(putnikId, polasci);

          await Supabase.instance.client
              .from('registrovani_putnici')
              .update({'polasci_po_danu': mergedPolasci, 'radni_dani': noviRadniDani}).eq('id', putnikId);

          setState(() {
            _putnikData['polasci_po_danu'] = mergedPolasci;
            _putnikData['radni_dani'] = noviRadniDani;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '✅ Vaš zahtev je primljen i biće obrađen uskoro',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.blueGrey,
                duration: Duration(seconds: 5),
              ),
            );
          }

          debugPrint('🎯 [VS] Zahtev sačuvan sa pending statusom');
        } else {
          // ✅ NORMAL FLOW SAVE
          // Čuva promene direktno u bazu (za otkazivanje ili ne-kritične promene)
          Future<void> _saveNormalFlow(
            String putnikId,
            Map<String, dynamic> polasci,
            String radniDani,
            String tipGrad,
            String dan,
            String? vreme,
          ) async {
            try {
              // 🛡️ Merge sa postojećim markerima u bazi
              final mergedPolasci = await _mergePolasciSaBazom(putnikId, polasci);

              await Supabase.instance.client.from('registrovani_putnici').update({
                'polasci_po_danu': mergedPolasci,
                'radni_dani': radniDani,
              }).eq('id', putnikId);

              if (mounted) {
                setState(() {
                  _putnikData['polasci_po_danu'] = mergedPolasci;
                  _putnikData['radni_dani'] = radniDani;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '✅ Uspešno sačuvano',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '❌ Greška pri čuvanju: $e',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }

          // 🟢 NORMALAN FLOW - odmah sačuvaj (otkazivanje)
          _saveNormalFlow(putnikId, polasci, noviRadniDani, tipGrad, dan, novoVreme);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Greška: $e'), backgroundColor: Colors.red));
      }
    }
  }

  /// 🔍 Pronalazi alternativne termine detaljno (vraća pre i posle)
  Future<Map<String, String?>> _pronadjiAlternativneTermineDetaljno(
    String zeljeniTermin, [
    String? datum,
    String grad = 'BC',
  ]) async {
    try {
      final slobodna = await SlobodnaMestaService.getSlobodnaMesta(datum: datum);
      final termini = slobodna[grad] ?? [];

      final zeljenoMinuta = _vremeUMinute(zeljeniTermin);

      String? prviPre;
      String? prviPosle;
      int najblizePre = -99999;
      int najblizePosle = 99999;

      for (final termin in termini) {
        if (termin.jePuno) continue;

        final terminMinuta = _vremeUMinute(termin.vreme);

        if (terminMinuta < zeljenoMinuta) {
          if (terminMinuta > najblizePre) {
            najblizePre = terminMinuta;
            prviPre = termin.vreme;
          }
        } else if (terminMinuta > zeljenoMinuta) {
          if (terminMinuta < najblizePosle) {
            najblizePosle = terminMinuta;
            prviPosle = termin.vreme;
          }
        }
      }

      return {'pre': prviPre, 'posle': prviPosle};
    } catch (e) {
      return {'pre': null, 'posle': null};
    }
  }

  /// ⏰ Konvertuje vreme "HH:MM" u minute od ponoći
  int _vremeUMinute(String vreme) {
    try {
      final delovi = vreme.split(':');
      final sati = int.parse(delovi[0]);
      final minuti = delovi.length > 1 ? int.parse(delovi[1]) : 0;
      return sati * 60 + minuti;
    } catch (e) {
      return 0;
    }
  }

  /// 🔔 Obaveštava sve putnike koji čekaju za VS Rush Hour termin da se oslobodilo mesto
  Future<void> _notifyWaitingPassengers(String vreme, String dan) async {
    try {
      // Dohvati sve koji čekaju za ovaj termin
      final waitingIds = await SlobodnaMestaService.dohvatiCekaMestoZaVsTermin(vreme, dan);

      if (waitingIds.isEmpty) {
        debugPrint('📭 [VS] Nema nikoga na listi čekanja za $vreme');
        return;
      }

      debugPrint('📬 [VS] ${waitingIds.length} putnika čeka za $vreme - šaljem obaveštenje');

      // Pronađi alternative za ovaj termin
      final danas = DateTime.now().toIso8601String().split('T')[0];
      final alternative = await _pronadjiAlternativneTermineDetaljno(vreme, danas, 'VS');

      // Za svakog putnika na listi čekanja, pošalji notifikaciju
      for (final waitingPutnikId in waitingIds) {
        // Dohvati podatke putnika
        final putnikData = await Supabase.instance.client
            .from('registrovani_putnici')
            .select('polasci_po_danu, radni_dani')
            .eq('id', waitingPutnikId)
            .maybeSingle();

        if (putnikData == null) continue;

        final polasci = Map<String, dynamic>.from(putnikData['polasci_po_danu'] ?? {});
        final radniDani = putnikData['radni_dani'] as String? ?? '';

        // Pošalji notifikaciju sa ponudom
        await LocalNotificationService.showVsAlternativeNotification(
          zeljeniTermin: vreme,
          putnikId: waitingPutnikId,
          dan: dan,
          polasci: polasci,
          radniDani: radniDani,
          terminPre: alternative['pre'],
          terminPosle: alternative['posle'],
          isRushHourWaiting: true,
        );

        // Mali delay između notifikacija
        await Future.delayed(const Duration(milliseconds: 500));
      }

      debugPrint('✅ [VS] Obavešteno ${waitingIds.length} putnika o oslobođenom mestu');
    } catch (e) {
      debugPrint('❌ [VS] Greška pri obaveštavanju: $e');
    }
  }

  /// 📊 Dugme za otvaranje detaljnih statistika
  Widget _buildDetaljneStatistikeDugme() {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).glassBorder, width: 1.5),
      ),
      child: InkWell(
        onTap: () {
          PutnikStatistikeHelper.prikaziDetaljneStatistike(
            context: context,
            putnikId: _putnikData['id'] ?? '',
            putnikIme: _putnikData['putnik_ime'] ?? 'Nepoznato',
            tip: _putnikData['tip'] ?? 'radnik',
            tipSkole: _putnikData['tip_skole'],
            brojTelefona: _putnikData['broj_telefona'],
            radniDani: _putnikData['radni_dani'] ?? 'pon,uto,sre,cet,pet',
            createdAt:
                _putnikData['created_at'] != null ? DateTime.tryParse(_putnikData['created_at'].toString()) : null,
            updatedAt:
                _putnikData['updated_at'] != null ? DateTime.tryParse(_putnikData['updated_at'].toString()) : null,
            aktivan: _putnikData['aktivan'] ?? true,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined, color: Colors.blue.shade300, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Detaljne statistike',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.5), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 📊 Widget za prikaz stanja računa (STARI - nekoristi se više)
  // ignore: unused_element
  Widget _buildStatistikePoMesecimaCard() {
    final meseci = {
      1: 'Januar',
      2: 'Februar',
      3: 'Mart',
      4: 'April',
      5: 'Maj',
      6: 'Jun',
      7: 'Jul',
      8: 'Avgust',
      9: 'Septembar',
      10: 'Oktobar',
      11: 'Novembar',
      12: 'Decembar',
    };

    final daniUNedelji = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];

    // Cena po tipu
    final tip = _putnikData['tip'] ?? 'radnik';
    final cenaPoVoznji = CenaObracunService.getDefaultCenaByTip(tip);

    // Sortiraj mesece od najnovijeg
    final sortedKeys = <String>{..._voznjeDetaljno.keys, ..._otkazivanjaDetaljno.keys}.toList()
      ..sort((a, b) => b.compareTo(a));

    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).glassBorder, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TRENUTNO STANJE - veliko i vidljivo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _ukupnoZaduzenje > 0
                      ? [Colors.red.withValues(alpha: 0.3), Colors.red.withValues(alpha: 0.1)]
                      : [Colors.green.withValues(alpha: 0.5), Colors.green.withValues(alpha: 0.25)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _ukupnoZaduzenje > 0 ? Colors.red.withValues(alpha: 0.5) : Colors.green.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'VAŠE TRENUTNO STANJE',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, letterSpacing: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _ukupnoZaduzenje > 0 ? '${_ukupnoZaduzenje.toStringAsFixed(0)} RSD' : 'IZMIRENO',
                    style: TextStyle(
                      color: _ukupnoZaduzenje > 0 ? Colors.red.shade100 : Colors.green.shade100,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 📊 DUGME ZA DETALJNE STATISTIKE
            Center(
              child: TextButton.icon(
                onPressed: () {
                  PutnikStatistikeHelper.prikaziDetaljneStatistike(
                    context: context,
                    putnikId: _putnikData['id'] ?? '',
                    putnikIme: _putnikData['putnik_ime'] ?? 'Nepoznato',
                    tip: _putnikData['tip'] ?? 'radnik',
                    tipSkole: _putnikData['tip_skole'],
                    brojTelefona: _putnikData['broj_telefona'],
                    radniDani: _putnikData['radni_dani'] ?? 'pon,uto,sre,cet,pet',
                    createdAt: _putnikData['created_at'] != null
                        ? DateTime.tryParse(_putnikData['created_at'].toString())
                        : null,
                    updatedAt: _putnikData['updated_at'] != null
                        ? DateTime.tryParse(_putnikData['updated_at'].toString())
                        : null,
                    aktivan: _putnikData['aktivan'] ?? true,
                  );
                },
                icon: const Icon(Icons.analytics_outlined, size: 18),
                label: const Text('Detaljne statistike'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.9),
                  backgroundColor: Colors.blue.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.blue.withValues(alpha: 0.4)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Linija razdvajanja
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),

            const SizedBox(height: 16),

            // IZVOD PO MESECIMA
            const Center(
              child: Text(
                '📋 Izvod po mesecima',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),

            if (sortedKeys.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Nema podataka o vožnjama',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ...sortedKeys.map((key) {
                final parts = key.split('-');
                final godina = int.parse(parts[0]);
                final mesecNum = int.parse(parts[1]);
                final mesecNaziv = meseci[mesecNum] ?? key;

                // Konvertuj Set<String> u List<DateTime> za prikaz
                final voznjeSet = _voznjeDetaljno[key] ?? <String>{};
                final otkazivanjaSet = _otkazivanjaDetaljno[key] ?? <String>{};
                final voznjeList = voznjeSet.map((s) => DateTime.parse(s)).toList()..sort();
                final otkazivanjaList = otkazivanjaSet.map((s) => DateTime.parse(s)).toList()..sort();
                final brojVoznji = voznjeList.length;
                final brojOtkazivanja = otkazivanjaList.length;

                final ukupnoZaMesec = brojVoznji * cenaPoVoznji;

                // Plaćeno za ovaj mesec
                final placenoZaMesec = _istorijaPl
                    .where((p) => p['mesec'] == mesecNum && p['godina'] == godina)
                    .fold<double>(0, (sum, p) => sum + (p['iznos'] as double? ?? 0));

                final dugujeZaMesec = ukupnoZaMesec - placenoZaMesec;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    iconColor: Colors.white70,
                    collapsedIconColor: Colors.white70,
                    title: Row(
                      children: [
                        Text(
                          '$mesecNaziv $godina',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: dugujeZaMesec > 0
                                ? Colors.red.withValues(alpha: 0.3)
                                : Colors.green.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dugujeZaMesec > 0 ? '${dugujeZaMesec.toStringAsFixed(0)} RSD' : '✓',
                            style: TextStyle(
                              color: dugujeZaMesec > 0 ? Colors.red.shade100 : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '$brojVoznji vožnji × ${cenaPoVoznji.toStringAsFixed(0)} = ${ukupnoZaMesec.toStringAsFixed(0)} RSD',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    ),
                    children: [
                      // VOŽNJE PO DANIMA
                      if (voznjeList.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('🚌', style: TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Vožnje ($brojVoznji)',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: voznjeList.map((datum) {
                                  final dan = daniUNedelji[datum.weekday - 1];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$dan ${datum.day}.${datum.month}.',
                                      style: TextStyle(color: Colors.green.shade100, fontSize: 11),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // OTKAZIVANJA PO DANIMA
                      if (otkazivanjaList.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('❌', style: TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Otkazivanja ($brojOtkazivanja)',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: otkazivanjaList.map((datum) {
                                  final dan = daniUNedelji[datum.weekday - 1];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$dan ${datum.day}.${datum.month}.',
                                      style: TextStyle(color: Colors.orange.shade100, fontSize: 11),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ZBIR ZA MESEC
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            _buildZbirRow(
                              'Ukupno vožnji:',
                              '$brojVoznji × ${cenaPoVoznji.toStringAsFixed(0)}',
                              '${ukupnoZaMesec.toStringAsFixed(0)} RSD',
                            ),
                            const SizedBox(height: 6),
                            _buildZbirRow(
                              'Plaćeno:',
                              '',
                              '${placenoZaMesec.toStringAsFixed(0)} RSD',
                              color: Colors.green,
                            ),
                            const Divider(color: Colors.white24, height: 16),
                            _buildZbirRow(
                              dugujeZaMesec > 0 ? 'Za uplatu:' : 'Stanje:',
                              '',
                              dugujeZaMesec > 0 ? '${dugujeZaMesec.toStringAsFixed(0)} RSD' : 'IZMIRENO',
                              color: dugujeZaMesec > 0 ? Colors.red : Colors.green,
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
          ],
        ),
      ),
    );
  }

  Widget _buildZbirRow(String label, String formula, String value, {Color? color, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (formula.isNotEmpty)
          Text(formula, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
