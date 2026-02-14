import 'dart:async';
import 'dart:convert'; // Added for safe JSON parsing

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/route_config.dart';
import '../constants/day_constants.dart';
import '../globals.dart';
import '../helpers/putnik_statistike_helper.dart'; // 📊 Zajednički dijalog za statistike
import '../models/registrovani_putnik.dart';
import '../services/cena_obracun_service.dart';
import '../services/local_notification_service.dart'; // 🔔 Lokalne notifikacije
import '../services/putnik_push_service.dart'; // 📱 Push notifikacije za putnike
import '../services/putnik_service.dart'; // 🏖️ Za bolovanje/godišnji
import '../services/realtime/realtime_manager.dart';
import '../services/realtime_notification_service.dart'; // 🔔 Push notifikacije za vozače
import '../services/seat_request_service.dart';
import '../services/theme_manager.dart';
import '../services/voznje_log_service.dart';
import '../services/weather_service.dart'; // 🌤️ Vremenska prognoza
import '../theme.dart';
import '../utils/registrovani_helpers.dart';
import '../utils/schedule_utils.dart';
import '../widgets/kombi_eta_widget.dart'; // 🆕 Jednostavan ETA widget
import '../widgets/shared/time_picker_cell.dart';

/// 📊 MESEČNI PUTNIK PROFIL SCREEN
/// Prikazuje podatke o mesečnom putniku: raspored, vožnje, dugovanja
class RegistrovaniPutnikProfilScreen extends StatefulWidget {
  final Map<String, dynamic> putnikData;

  const RegistrovaniPutnikProfilScreen({super.key, required this.putnikData});

  @override
  State<RegistrovaniPutnikProfilScreen> createState() => _RegistrovaniPutnikProfilScreenState();
}

class _RegistrovaniPutnikProfilScreenState extends State<RegistrovaniPutnikProfilScreen> with WidgetsBindingObserver {
  Map<String, dynamic> _putnikData = {};
  bool _isLoading = false;
  // 🔔 Status notifikacija
  PermissionStatus _notificationStatus = PermissionStatus.granted;

  int _brojVoznji = 0;
  int _brojOtkazivanja = 0;
  // ignore: unused_field
  double _dugovanje = 0.0;
  List<Map<String, dynamic>> _istorijaPl = [];

  // 📊 Statistike - detaljno po zapisima iz dnevnika
  final Map<String, List<Map<String, dynamic>>> _voznjeDetaljno = {}; // mesec -> lista zapisa vožnji
  final Map<String, List<Map<String, dynamic>>> _otkazivanjaDetaljno = {}; // mesec -> lista zapisa otkazivanja
  final Map<String, int> _brojMestaPoVoznji = {}; // datum -> broj_mesta (za tačan obračun)
  double _ukupnoZaduzenje = 0.0; // ukupno zaduženje za celu godinu
  double _cenaPoVoznji = 0.0; // 💰 Cena po vožnji/danu
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
  StreamSubscription? _statusSubscription;
  // 🆕 Realtime subscription za seat request approvals
  StreamSubscription? _seatRequestSubscription;

  /// HELPER za bezbedno kastovanje JSONB podataka koji mogu doći kao String ili Map
  Map<String, dynamic> _safeMap(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 🕵️ Prati lifecycle aplikacije
    _checkNotificationPermission(); // 🔍 Proveri dozvolu za notifikacije

    _putnikData = Map<String, dynamic>.from(widget.putnikData);
    _refreshPutnikData(); // 🔄 Učitaj sveže podatke iz baze
    _loadStatistike();
    _registerPushToken(); // 📱 Registruj push token (retry ako nije uspelo pri login-u)
    // ❌ UKLONJENO: Client-side pending resolution - sada se radi putem Supabase cron jobs
    // _checkAndResolvePendingRequests();
    _cleanupOldSeatRequests(); // 🧹 Očisti stare seat_requests iz baze
    WeatherService.refreshAll(); // 🌤️ Učitaj vremensku prognozu
    _setupRealtimeListener(); // 🎯 Sluša promene statusa u realtime
  }

  /// 🔄 Proverava da li je vreme isteklo (za automatsko otkazivanje)
  bool _isExpired(String vreme, DateTime now) {
    try {
      final parts = vreme.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final min = int.parse(parts[1]);
        final scheduled = DateTime(now.year, now.month, now.day, hour, min);
        return now.isAfter(scheduled);
      }
    } catch (_) {}
    return false;
  }

  /// 📅 Proverava da li je dan "danas"
  bool _isDanas(String danKratica) {
    const daniMap = {
      'pon': DateTime.monday,
      'uto': DateTime.tuesday,
      'sre': DateTime.wednesday,
      'cet': DateTime.thursday,
      'pet': DateTime.friday,
      'sub': DateTime.saturday,
      'ned': DateTime.sunday
    };
    final target = daniMap[danKratica.toLowerCase()];
    return target == DateTime.now().weekday;
  }

  /// 🔴 Automatski postavlja pending zahtev na "pending" status ako je istekao
  /// ✅ ISPRAVLJENO: Ne briše vreme - čuva ga i postavi napomenu "Čeka potvrdu"
  Future<void> _autoCancelPending(String dan, String grad) async {
    try {
      final putnikId = _putnikData['id']?.toString();
      if (putnikId == null) return;

      debugPrint('🕒 [AutoCancel] Pending zahtev za $dan $grad ostaje na čekanju');

      final response =
          await supabase.from('registrovani_putnici').select('polasci_po_danu').eq('id', putnikId).maybeSingle();

      if (response == null) return;
      final polasci = _safeMap(response['polasci_po_danu']);
      if (polasci[dan] == null) return;

      final danData = Map<String, dynamic>.from(polasci[dan] as Map);
      final staroVreme = danData[grad];

      // ✅ ISPRAVLJENO: Čuva vreme, ne briši ga - samo postavlja napomenu
      danData['${grad}_status'] = 'pending';
      danData['${grad}_napomena'] = 'Čeka potvrdu';
      // Čuvaj staro vreme ako je već sačuvano
      if (danData['${grad}_otkazano_vreme'] == null && staroVreme != null) {
        danData['${grad}_otkazano_vreme'] = staroVreme;
      }

      polasci[dan] = danData;

      await supabase.from('registrovani_putnici').update({'polasci_po_danu': polasci}).eq('id', putnikId);

      if (mounted) {
        setState(() {
          _putnikData['polasci_po_danu'] = polasci;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⏳ Zahtev za $staroVreme ($dan) ostaje na čekanju za potvrdu.')),
        );
      }
    } catch (e) {
      debugPrint('❌ [AutoCancel] Greška: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 🛑 Zatvori lifecycle observer
    _statusSubscription?.cancel(); // 🛑 Zatvori Realtime listener
    _seatRequestSubscription?.cancel(); // 🛑 Zatvori Seat Request listener
    RealtimeManager.instance.unsubscribe('registrovani_putnici');
    RealtimeManager.instance.unsubscribe('seat_requests');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 🔄 Kada se korisnik vrati u aplikaciju, proveri notifikacije ponovo
    if (state == AppLifecycleState.resumed) {
      _checkNotificationPermission();
    }
  }

  /// 🔍 Proverava status notifikacija
  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() {
        _notificationStatus = status;
      });
    }
  }

  /// 🔓 Traži dozvolu ili otvara podešavanja
  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (mounted) {
      setState(() {
        _notificationStatus = status;
      });
    }

    // Ako je trajno odbijeno, otvori podešavanja
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
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

    // Koristi RealtimeManager za centralizovanu pretplatu
    _statusSubscription = RealtimeManager.instance.subscribe('registrovani_putnici').where((payload) {
      // Filtriraj samo ako je ažuriran ovaj putnik
      return payload.newRecord['id'].toString() == putnikId;
    }).listen((payload) {
      debugPrint('🎯 [Realtime] Status promena detektovana za putnika $putnikId');
      _handleStatusChange(payload);
    });

    // 🆕 Dodaj listener za seat_requests approvals
    _seatRequestSubscription = RealtimeManager.instance.subscribe('seat_requests').where((payload) {
      // Filtriraj samo za ovog putnika i UPDATE event
      return payload.eventType == PostgresChangeEvent.update &&
          payload.newRecord['putnik_id'].toString() == putnikId &&
          payload.newRecord['status'] == 'approved';
    }).listen((payload) {
      debugPrint('🆕 [Realtime] Seat request approved za putnika $putnikId');
      _handleSeatRequestApproval(payload);
    });

    debugPrint('🎯 [Realtime] Listener aktivan za putnika $putnikId');
  }

  /// 🔔 Hendluje promenu statusa (confirmed/null) - samo osvežava UI
  /// Notifikacije šalje Job #3 preko push sistema
  Future<void> _handleStatusChange(PostgresChangePayload payload) async {
    try {
      final newData = payload.newRecord;
      if (newData.isEmpty) return;

      // 🔄 Osvježi lokalne podatke odmah za bilo koju promenu (ime, tip, status...)
      if (mounted) {
        setState(() {
          _putnikData = Map<String, dynamic>.from(newData);
        });
      }

      final polasciPoDanu = _safeMap(newData['polasci_po_danu']);
      if (polasciPoDanu.isEmpty) return;

      // Logovanje status promena (bez slanja notifikacija - to radi Job #3)
      for (final dan in polasciPoDanu.keys) {
        final danData = polasciPoDanu[dan];
        if (danData is! Map) {
          continue;
        }

        final bcStatus = danData['bc_status']?.toString();
        final bcVreme = danData['bc']?.toString();
        final vsStatus = danData['vs_status']?.toString();
        final vsVreme = danData['vs']?.toString();

        if (bcStatus == 'confirmed' && bcVreme != null && bcVreme.isNotEmpty && bcVreme != 'null') {
          debugPrint('✅ [Status] BC zahtev POTVRĐEN: $dan $bcVreme');
        } else if (bcStatus == 'rejected' || bcStatus == 'null') {
          debugPrint('❌ [Status] BC zahtev ODBIJEN: $dan');
        }

        if (vsStatus == 'confirmed' && vsVreme != null && vsVreme.isNotEmpty && vsVreme != 'null') {
          debugPrint('✅ [Status] VS zahtev POTVRĐEN: $dan $vsVreme');
        } else if (vsStatus == 'rejected' || vsStatus == 'null') {
          debugPrint('❌ [Status] VS zahtev ODBIJEN: $dan');
        }
      }
    } catch (e) {
      debugPrint('❌ [Realtime] Greška pri obradi status promene: $e');
    }
  }

  /// 🆕 Hendluje approval seat request-a - ažurira registrovani_putnici na 'confirmed'
  Future<void> _handleSeatRequestApproval(PostgresChangePayload payload) async {
    try {
      final newRecord = payload.newRecord;
      final putnikId = newRecord['putnik_id'].toString();
      final grad = newRecord['grad'].toString().toLowerCase(); // 'bc' ili 'vs'
      final datum = newRecord['datum'].toString();
      final vreme = newRecord['zeljeno_vreme'].toString();

      // 🛡️ PROVERA: Odbaci stare notifikacije (starije od 2 minuta)
      final processedAt = newRecord['processed_at'];
      if (processedAt != null) {
        final processedTime = DateTime.parse(processedAt.toString());
        final now = DateTime.now();
        if (now.difference(processedTime).inMinutes > 2) {
          debugPrint(
              '⏭️ [SeatRequestApproval] Odbačena stara notifikacija (processed ${now.difference(processedTime).inMinutes} min ago)');
          return;
        }
      }

      // Izračunaj dan iz datuma
      final date = DateTime.parse(datum);
      const daniMap = {
        DateTime.monday: 'pon',
        DateTime.tuesday: 'uto',
        DateTime.wednesday: 'sre',
        DateTime.thursday: 'cet',
        DateTime.friday: 'pet',
        DateTime.saturday: 'sub',
        DateTime.sunday: 'ned'
      };
      final dan = daniMap[date.weekday] ?? 'pon';

      debugPrint('🆕 [SeatRequestApproval] Ažuriram registrovani_putnici: $putnikId, $dan, $grad, $vreme');

      // Dohvati trenutne podatke
      final response =
          await supabase.from('registrovani_putnici').select('polasci_po_danu').eq('id', putnikId).maybeSingle();
      if (response == null) return;

      final polasci = _safeMap(response['polasci_po_danu']);
      if (polasci[dan] == null) return;

      final danData = Map<String, dynamic>.from(polasci[dan] as Map);

      // Ažuriraj status na confirmed i vreme
      danData[grad] = vreme;
      danData['${grad}_status'] = 'confirmed';
      danData.remove('${grad}_napomena'); // Ukloni pending napomenu
      danData.remove('${grad}_ceka_od'); // Ukloni pending timestamp
      danData.remove('${grad}_otkazano_vreme'); // Ukloni otkazano vreme

      polasci[dan] = danData;

      // Sačuvaj u bazi
      await supabase.from('registrovani_putnici').update({'polasci_po_danu': polasci}).eq('id', putnikId);

      // Ažuriraj lokalni state
      if (mounted) {
        setState(() {
          _putnikData['polasci_po_danu'] = polasci;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Vaš zahtev za $vreme ($dan ${grad.toUpperCase()}) je odobren!')),
        );
      }

      // 🔔 Pošalji push notifikaciju (foreground/background/lock screen)
      try {
        final dniOznake = <String, String>{};
        for (int i = 0; i < DayConstants.dayAbbreviations.length; i++) {
          dniOznake[DayConstants.dayAbbreviations[i]] = DayConstants.dayNamesInternal[i];
        }
        final danNaziv = dniOznake[dan] ?? dan;
        final gradNaziv = grad.toUpperCase();

        await LocalNotificationService.showRealtimeNotification(
          title: '✅ Zahtev Odobren!',
          body: 'Vaš zahtev za $vreme ($danNaziv $gradNaziv) je odobren. Slobodno mesto je dostupno!',
          payload: jsonEncode({
            'notification_id': 'seat_request_approval_$putnikId',
            'type': 'seat_request_approval',
            'putnik_id': putnikId,
            'dan': dan,
            'grad': grad,
            'vreme': vreme,
          }),
        );
      } catch (e) {
        debugPrint('⚠️ [SeatRequestApproval] Greška pri slanju notifikacije: $e');
      }

      debugPrint('✅ [SeatRequestApproval] Registrovani putnici ažuriran');
    } catch (e) {
      debugPrint('❌ [SeatRequestApproval] Greška: $e');
    }
  }

  /// 🔄 Osvežava podatke putnika iz baze
  Future<void> _refreshPutnikData() async {
    try {
      final putnikId = _putnikData['id'];
      if (putnikId == null) return;

      final response = await supabase.from('registrovani_putnici').select().eq('id', putnikId).single();

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
  // ❌ UKLONJENO: _checkAndResolvePendingRequests() funkcija
  // Razlog: Client-side pending resolution je konflikovao sa Supabase cron jobs
  // Sva pending logika se sada obrađuje server-side putem:
  // - Job #7: resolve-pending-main (svaki minut)
  // - Job #5: resolve-pending-20h-ucenici (u 20:00)
  // - Job #6: cleanup-expired-pending (svakih 5 minuta)

  /// 🧹 Očisti stare pending zahteve iz seat_requests tabele
  /// Briše zahteve starije od 1 dana
  Future<void> _cleanupOldSeatRequests() async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String();
      final oldRequests = await supabase.from('seat_requests').select('id').lt('created_at', yesterday);

      if (oldRequests.isNotEmpty) {
        debugPrint('🧹 [Cleanup] Brisanje ${oldRequests.length} starih zahteva...');

        // Briši stare zahteve
        await supabase.from('seat_requests').delete().lt('created_at', yesterday);
      }
    } catch (e) {
      debugPrint('❌ [Cleanup] Greška: $e');
    }
  }

  /// 🔧 Helperi za sigurno parsiranje brojeva iz Supabase-a (koji mogu biti String)
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic v, {int defaultValue = 1}) {
    if (v == null) return defaultValue;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? defaultValue;
    return defaultValue;
  }

  /// 📊 Učitava statistike za profil (vožnje i otkazivanja)
  Future<void> _loadStatistike() async {
    final now = DateTime.now();
    final pocetakMeseca = DateTime(now.year, now.month, 1).toUtc().toIso8601String();
    final pocetakGodine = DateTime(now.year, 1, 1);
    final putnikId = _putnikData['id'];
    if (putnikId == null) return;

    try {
      final tipPutnikaRaw = (_putnikData['tip'] ?? 'radnik').toString().toLowerCase();
      bool isJeDnevni(String t) => t.contains('dnevni') || t.contains('posiljka') || t.contains('pošiljka');
      final jeDnevni = isJeDnevni(tipPutnikaRaw);

      // 1. Dohvati vožnje za TEKUĆI MESEC (kroz datum kolonu, ne created_at)
      final datumPocetakMeseca = DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];
      final datumKrajMeseca = DateTime(now.year, now.month + 1, 0).toIso8601String().split('T')[0];

      final voznjeResponse = await supabase
          .from('voznje_log')
          .select('datum, tip, broj_mesta')
          .eq('putnik_id', putnikId)
          .eq('tip', 'voznja')
          .gte('datum', datumPocetakMeseca)
          .lte('datum', datumKrajMeseca);

      // 2. Dohvati otkazivanja za TEKUĆI MESEC
      final otkazivanjaResponse = await supabase
          .from('voznje_log')
          .select('datum, tip, broj_mesta')
          .eq('putnik_id', putnikId)
          .eq('tip', 'otkazivanje')
          .gte('datum', datumPocetakMeseca)
          .lte('datum', datumKrajMeseca);

      // Broj vožnji ovog meseca (Logika identična kao za obračun dugovanja)
      int brojVoznjiTotal = 0;
      if (jeDnevni) {
        for (final v in voznjeResponse) {
          brojVoznjiTotal += _toInt(v['broj_mesta']);
        }
      } else {
        final Map<String, int> dailyMaxSeats = {};
        for (final v in voznjeResponse) {
          final d = v['datum'] as String?;
          if (d != null) {
            final bm = _toInt(v['broj_mesta']);
            if (bm > (dailyMaxSeats[d] ?? 0)) {
              dailyMaxSeats[d] = bm;
            }
          }
        }
        dailyMaxSeats.forEach((_, val) => brojVoznjiTotal += val);
      }

      // Broj otkazivanja ovog meseca
      int brojOtkazivanjaTotal = 0;
      if (jeDnevni) {
        for (final o in otkazivanjaResponse) {
          brojOtkazivanjaTotal += _toInt(o['broj_mesta']);
        }
      } else {
        final Map<String, int> dailyMaxSeats = {};
        for (final o in otkazivanjaResponse) {
          final d = o['datum'] as String?;
          if (d != null) {
            final bm = _toInt(o['broj_mesta']);
            if (bm > (dailyMaxSeats[d] ?? 0)) {
              dailyMaxSeats[d] = bm;
            }
          }
        }
        dailyMaxSeats.forEach((_, val) => brojOtkazivanjaTotal += val);
      }

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
          final bcResponse =
              await supabase.from('adrese').select('naziv, gps_lat, gps_lng').eq('id', adresaBcId).maybeSingle();
          if (bcResponse != null) {
            adresaBcNaziv = bcResponse['naziv'] as String?;
            // Koordinate za BC adresu
            if (grad == 'BC' && bcResponse['gps_lat'] != null && bcResponse['gps_lng'] != null) {
              putnikLat = _toDouble(bcResponse['gps_lat']);
              putnikLng = _toDouble(bcResponse['gps_lng']);
            }
          }
        }
        if (adresaVsId != null && adresaVsId.isNotEmpty) {
          final vsResponse =
              await supabase.from('adrese').select('naziv, gps_lat, gps_lng').eq('id', adresaVsId).maybeSingle();
          if (vsResponse != null) {
            adresaVsNaziv = vsResponse['naziv'] as String?;
            // Koordinate za VS adresu
            if (grad == 'VS' && vsResponse['gps_lat'] != null && vsResponse['gps_lng'] != null) {
              putnikLat = _toDouble(vsResponse['gps_lat']);
              putnikLng = _toDouble(vsResponse['gps_lng']);
            }
          }
        }
      } catch (e) {
        // Error loading addresses
      }

      // 🚐 Određivanje sledećeg polaska za GPS tracking
      String? sledeciPolazak;

      // Dobavi vremena polazaka iz RouteConfig (automatski letnji/zimski)
      final vremenaPolazaka = await RouteConfig.getVremenaPolazaka(
        grad: grad,
        letnji: !isZimski(now), // Automatska provera sezone
      );

      // Uzmi sledeći polazak (ili null ako nema više polazaka danas)
      sledeciPolazak = _getNextPolazak(vremenaPolazaka, now.hour, now.minute);

      // 💰 Istorija plaćanja - poslednjih 6 meseci
      final istorija = await _loadIstorijuPlacanja(putnikId);

      // 📊 Vožnje po mesecima (cela godina) - koristi voznje_log
      final sveVoznje = await supabase
          .from('voznje_log')
          .select('datum, tip, created_at')
          .eq('putnik_id', putnikId)
          .gte('datum', pocetakGodine.toIso8601String().split('T')[0])
          .order('datum', ascending: false);

      // Grupiši podatke po mesecima (čuvamo sve zapise za Dnevni/Pošiljka)
      final Map<String, List<Map<String, dynamic>>> voznjeDetaljnoMap = {};
      final Map<String, List<Map<String, dynamic>>> otkazivanjaDetaljnoMap = {};

      for (final v in sveVoznje) {
        final datumStr = v['datum'] as String?;
        if (datumStr == null) {
          continue;
        }

        final datum = DateTime.tryParse(datumStr);
        if (datum == null) {
          continue;
        }

        final mesecKey = '${datum.year}-${datum.month.toString().padLeft(2, '0')}';
        final tip = v['tip'] as String?;

        if (tip == 'otkazivanje') {
          otkazivanjaDetaljnoMap[mesecKey] = [...(otkazivanjaDetaljnoMap[mesecKey] ?? []), v];
        } else if (tip == 'voznja') {
          voznjeDetaljnoMap[mesecKey] = [...(voznjeDetaljnoMap[mesecKey] ?? []), v];
        }
      }

      // 💰 PRIORITET: Koristi centralnu logiku iz CenaObracunService (podržava custom cene i specijalne slučajeve poput "zubi")
      final putnikModel = RegistrovaniPutnik.fromMap(_putnikData);
      final cenaPoVoznji = CenaObracunService.getCenaPoDanu(putnikModel);

      // 🔧 ISPRAVKA: Za izračun dugovanja koristimo SVE vožnje (bez gte filters), kako ne bismo propustili dug iz prošle godine
      double ukupnoZaplacanje = 0;
      final Map<String, int> brojMestaPoVoznji = {};
      try {
        final sveVoznjeZaDug =
            await supabase.from('voznje_log').select('datum, broj_mesta').eq('putnik_id', putnikId).eq('tip', 'voznja');

        final tipLower = tipPutnikaRaw.toLowerCase();
        final jeDnevniIliPosiljka =
            tipLower.contains('dnevni') || tipLower.contains('posiljka') || tipLower.contains('pošiljka');

        if (jeDnevniIliPosiljka) {
          for (final voznja in sveVoznjeZaDug) {
            final bm = _toInt(voznja['broj_mesta']);
            ukupnoZaplacanje += bm * cenaPoVoznji;

            final dStr = voznja['datum'] as String?;
            if (dStr != null) {
              brojMestaPoVoznji[dStr] = (brojMestaPoVoznji[dStr] ?? 0) + bm;
            }
          }
        } else {
          final Map<String, int> dnevniMaxMesta = {};
          for (final voznja in sveVoznjeZaDug) {
            final dStr = voznja['datum'] as String?;
            if (dStr == null) {
              continue;
            }
            final bm = _toInt(voznja['broj_mesta']);
            if (bm > (dnevniMaxMesta[dStr] ?? 0)) {
              dnevniMaxMesta[dStr] = bm;
            }
          }
          dnevniMaxMesta.forEach((datum, maxMesta) {
            ukupnoZaplacanje += maxMesta * cenaPoVoznji;
            brojMestaPoVoznji[datum] = maxMesta;
          });
        }
      } catch (e) {
        // Fallback
        double ukupnoVoznji = 0;
        for (final lista in voznjeDetaljnoMap.values) {
          ukupnoVoznji += lista.length;
        }
        ukupnoZaplacanje = ukupnoVoznji * cenaPoVoznji;
      }

      // 🔧 ISPRAVKA: Dohvati SVE uplate za tačan balans
      double ukupnoUplaceno = 0;
      try {
        final uplateResponse = await supabase
            .from('voznje_log')
            .select('iznos')
            .eq('putnik_id', putnikId)
            .filter('tip', 'in', '("uplata","uplata_mesecna","uplata_dnevna")');

        for (final u in uplateResponse) {
          ukupnoUplaceno += _toDouble(u['iznos']);
        }
      } catch (e) {
        // Fallback na istoriju koja je već učitana (iako je ona možda filtrirana)
        for (final p in istorija) {
          ukupnoUplaceno += _toDouble(p['iznos']);
        }
      }

      // Finalno zaduženje (Uključuje i eventualni početni dug iz profila ako postoji)
      final pocetniDug = _toDouble(_putnikData['dug']);
      final zaduzenje = pocetniDug + (ukupnoZaplacanje - ukupnoUplaceno);

      setState(() {
        _brojVoznji = brojVoznjiTotal;
        _brojOtkazivanja = brojOtkazivanjaTotal;
        _dugovanje = zaduzenje;
        _istorijaPl = istorija;
        _voznjeDetaljno.clear();
        _voznjeDetaljno.addAll(voznjeDetaljnoMap);
        _otkazivanjaDetaljno.clear();
        _otkazivanjaDetaljno.addAll(otkazivanjaDetaljnoMap);
        _brojMestaPoVoznji.clear();
        _brojMestaPoVoznji.addAll(brojMestaPoVoznji);
        _ukupnoZaduzenje = zaduzenje;
        _cenaPoVoznji = cenaPoVoznji;
        _adresaBC = adresaBcNaziv;
        _adresaVS = adresaVsNaziv;
        _putnikLat = putnikLat;
        _putnikLng = putnikLng;
        _sledeciPolazak = sledeciPolazak;
        _smerTure = (grad == 'BC' || grad == 'Bela Crkva') ? 'BC_VS' : 'VS_BC';
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
      final polasciPoDanu = _safeMap(_putnikData['polasci_po_danu']);
      if (polasciPoDanu.isEmpty) return null;

      final now = DateTime.now();
      final daniNedelje = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      final daniPuniNaziv = <String, String>{};
      for (int i = 0; i < DayConstants.dayAbbreviations.length; i++) {
        daniPuniNaziv[DayConstants.dayAbbreviations[i]] = DayConstants.dayNamesInternal[i];
      }

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
      final placanja = await supabase
          .from('voznje_log')
          .select('iznos, datum, created_at')
          .eq('putnik_id', putnikId)
          .filter('tip', 'in', '("uplata","uplata_mesecna","uplata_dnevna")')
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
        final iznos = _toDouble(p['iznos']);

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
        content: Text('Da li želiš da se odjaviš?', style: TextStyle(color: Colors.white.withOpacity(0.8))),
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
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
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
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
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
            ? 'Vraćeni ste na posao'
            : noviStatus == 'godisnji'
                ? 'Postavljeni ste na godišnji odmor'
                : 'Postavljeni ste na bolovanje';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(poruka)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
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
                                color: Colors.blue.withOpacity(0.3),
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
                                color: Colors.indigo.withOpacity(0.3),
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
                                      'KIŠA ${data.precipitationStartTime ?? 'SADA'}${data.precipitationProbability != null ? " (${data.precipitationProbability}%)" : ''}',
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
    final tipPrikazivanja = _putnikData['tip_prikazivanja'] as String? ?? 'standard';
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
            'Moj profil',
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

                    // ⚠️ NOTIFIKACIJE UPOZORENJE (ako su ugašene)
                    if (_notificationStatus.isDenied || _notificationStatus.isPermanentlyDenied)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_off, color: Colors.white),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Notifikacije isključene!',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Nećete videti potvrde vožnji.',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _requestNotificationPermission,
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('UKLJUČI'),
                            ),
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
                                    : tip == 'posiljka'
                                        ? [Colors.purple.shade400, Colors.deepPurple.shade600]
                                        : [Colors.orange.shade400, Colors.deepOrange.shade600],
                              ),
                              border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: (tip == 'ucenik'
                                          ? Colors.blue
                                          : tip == 'posiljka'
                                              ? Colors.purple
                                              : Colors.orange)
                                      .withOpacity(0.4),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Tip i grad
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tip == 'ucenik'
                                      ? Colors.blue.withOpacity(0.3)
                                      : (tip == 'dnevni' || tipPrikazivanja == 'DNEVNI')
                                          ? Colors.green.withOpacity(0.3)
                                          : tip == 'posiljka'
                                              ? Colors.purple.withOpacity(0.3)
                                              : Colors.orange.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: Text(
                                  tip == 'ucenik'
                                      ? '🎓 Učenik'
                                      : tip == 'posiljka'
                                          ? '📦 Pošiljka'
                                          : tip == 'radnik'
                                              ? '💼 Radnik'
                                              : tip == 'dnevni'
                                                  ? '📅 Dnevni'
                                                  : '👤 Putnik',
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
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.3)),
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
                                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                                  ),
                                ],
                                if (_adresaBC != null && _adresaVS != null) const SizedBox(width: 16),
                                if (_adresaVS != null && _adresaVS!.isNotEmpty) ...[
                                  Icon(Icons.work, color: Colors.white70, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    _adresaVS!,
                                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
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
                      child: Divider(color: Colors.white.withOpacity(0.2), thickness: 1),
                    ),

                    // 🚐 ETA Widget sa fazama:
                    // 0. Nema dozvola: "Odobravanjem GPS i notifikacija ovde će vam biti prikazano vreme dolaska prevoza"
                    // 1. 30 min pre polaska: "Vozač će uskoro krenuti"
                    // 2. Vozač startovao rutu: Realtime ETA praćenje
                    // 3. Pokupljen: "Pokupljeni ste u HH:MM" (stoji 60 min) - ČITA IZ BAZE!
                    // 4. Nakon 60 min: "Vaša sledeća vožnja: dan, vreme"
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
                      child: Divider(color: Colors.white.withOpacity(0.2), thickness: 1),
                    ),
                    const SizedBox(height: 8),

                    // Statistike - Prikazano za sve, ali dnevni/pošiljka broje svako pokupljenje
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
                    if (_putnikData['cena_po_danu'] != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _ukupnoZaduzenje > 0
                                ? [Colors.red.withOpacity(0.2), Colors.red.withOpacity(0.05)]
                                : [Colors.green.withOpacity(0.2), Colors.green.withOpacity(0.05)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _ukupnoZaduzenje > 0 ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'TRENUTNO STANJE',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _ukupnoZaduzenje > 0 ? '${_ukupnoZaduzenje.toStringAsFixed(0)} RSD' : 'IZMIRENO OK',
                              style: TextStyle(
                                color: _ukupnoZaduzenje > 0 ? Colors.red.shade200 : Colors.green.shade200,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_cenaPoVoznji > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Cena: ${_cenaPoVoznji.toStringAsFixed(0)} RSD / ${tip.toLowerCase() == 'radnik' || tip.toLowerCase() == 'ucenik' ? 'dan' : 'vožnja'}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

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
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
        ],
      ),
    );
  }

  /// 📅 Widget za prikaz rasporeda polazaka po danima - GRID STIL kao "Vremena polaska"
  Widget _buildRasporedCard() {
    final tip = _putnikData['tip'] as String? ?? 'radnik';
    final tipPrikazivanja = _putnikData['tip_prikazivanja'] as String? ?? 'standard';
    // Parsiranje polasci_po_danu iz putnikData
    final polasciRaw = _safeMap(_putnikData['polasci_po_danu']);
    Map<String, Map<String, String?>> polasci = {};

    // Helper funkcija za sigurno parsiranje vremena
    String? parseVreme(dynamic value) {
      if (value == null) return null;
      final str = value.toString().trim();
      if (str.isEmpty || str == 'null') return null;
      return str;
    }

    polasciRaw.forEach((key, value) {
      if (value is Map) {
        final danName = key.toString();
        final bcStatus = parseVreme(value['bc_status']);
        final vsStatus = parseVreme(value['vs_status']);
        String? bcVreme = parseVreme(value['bc']);
        String? vsVreme = parseVreme(value['vs']);

        // 🆕 AUTOMATSKO OTKAZIVANJE ISTEKLIH PENDING ZAHTEVA
        final now = DateTime.now();
        if (_isDanas(danName)) {
          // BC Pending
          if (bcStatus == 'waiting' && bcVreme != null && _isExpired(bcVreme, now)) {
            bcVreme = null;
            _autoCancelPending(danName, 'bc');
          }
          // VS Pending
          if (vsStatus == 'waiting' && vsVreme != null && _isExpired(vsVreme, now)) {
            vsVreme = null;
            _autoCancelPending(danName, 'vs');
          }
        }

        polasci[danName] = {
          'bc': bcVreme,
          'vs': vsVreme,
          'bc_status': bcStatus,
          'vs_status': vsStatus,
          'bc_otkazano': parseVreme(value['bc_otkazano']),
          'vs_otkazano': parseVreme(value['vs_otkazano']),
          'bc_otkazano_vreme': parseVreme(value['bc_otkazano_vreme']),
          'vs_otkazano_vreme': parseVreme(value['vs_otkazano_vreme']),
          'bc_placanja': value['bc_placanja'], // 🆕 Dodaj plaćanja za BC
          'vs_placanja': value['vs_placanja'], // 🆕 Dodaj plaćanja za VS
        };
      }
    });

    final dani = DayConstants.dayAbbreviations.sublist(0, 5); // Samo radni dani
    final daniLabels = <String, String>{};
    for (int i = 0; i < DayConstants.dayAbbreviations.length && i < 5; i++) {
      daniLabels[DayConstants.dayAbbreviations[i]] = DayConstants.dayNamesInternal[i];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.13)),
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
                      color: Colors.white.withOpacity(0.7),
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
                      color: Colors.white.withOpacity(0.7),
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
            // Koristi 'waiting' status direktno
            final vsStatus = danPolasci?['vs_status']?.toString();
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
                        tipPutnika: tip.toString(), // 🆕 Za proveru dnevnog zakazivanja
                        tipPrikazivanja: tipPrikazivanja, // 🆕 Režim prikaza
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
                        tipPutnika: tip.toString(), // 🆕 Za proveru dnevnog zakazivanja
                        tipPrikazivanja: tipPrikazivanja, // 🆕 Režim prikaza
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
    debugPrint('🚀 [BC] _updatePolazak pozvan: dan=$dan, tipGrad=$tipGrad, novoVreme=$novoVreme');

    // 🔔 PROVERA NOTIFIKACIJA PRE ZAKAZIVANJA
    if (novoVreme != null && (_notificationStatus.isDenied || _notificationStatus.isPermanentlyDenied)) {
      final shouldEnable = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notification_important, color: Colors.orange),
              SizedBox(width: 8),
              Text('Važno obaveštenje'),
            ],
          ),
          content: const Text(
            'Da biste dobili potvrdu o slobodnom mestu, morate uključiti notifikacije.\n\n'
            'Ako ostanu isključene, morate ručno proveravati status u aplikaciji.\n\n'
            'Želite li da ih uključite sada?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('NE ŽELIM'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('UKLJUČI'),
            ),
          ],
        ),
      );

      if (shouldEnable == true) {
        await _requestNotificationPermission();
      }
    }

    final putnikId = _putnikData['id']?.toString();
    if (putnikId == null) return;

    final tipPutnika = (_putnikData['tip'] ?? '').toString().toLowerCase();
    final jeUcenik = tipPutnika.contains('ucenik');
    final jeRadnik = tipPutnika.contains('radnik');
    final jeDnevni =
        tipPutnika.contains('dnevni') || tipPutnika.contains('posiljka') || tipPutnika.contains('pošiljka');

    final String? normalizedVreme = novoVreme == null ? null : RegistrovaniHelpers.normalizeTime(novoVreme);
    final String seatVreme =
        (normalizedVreme != null && normalizedVreme.isNotEmpty) ? normalizedVreme : (novoVreme ?? '');

    String? rpcStatus;
    String? rpcCekaOd;
    String? rpcOtkazano;
    String? rpcOtkazanoVreme;
    String? rpcOtkazaoVozac;

    if (normalizedVreme == null || normalizedVreme.isEmpty) {
      // Otkazivanje
      final staroPolasci = _safeMap(_putnikData['polasci_po_danu']);
      final staroDanData = _safeMap(staroPolasci[dan]);
      final staroVreme = staroDanData[tipGrad]?.toString();
      final staroVremeNorm = RegistrovaniHelpers.normalizeTime(staroVreme ?? '');

      rpcOtkazano = DateTime.now().toUtc().toIso8601String();
      rpcOtkazaoVozac = 'Putnik';
      if (staroVreme != null && staroVreme.isNotEmpty) {
        rpcOtkazanoVreme = (staroVremeNorm != null && staroVremeNorm.isNotEmpty) ? staroVremeNorm : staroVreme;
      }
    } else {
      // Zakazivanje
      final jeBcUcenikZahtev = tipGrad == 'bc' && jeUcenik;
      final jeBcRadnikZahtev = tipGrad == 'bc' && jeRadnik;
      final jeVsZahtev = tipGrad == 'vs'; // I VS ide u pending na 10 min da dispečer može da reaguje

      if (jeBcUcenikZahtev || jeBcRadnikZahtev || jeVsZahtev) {
        rpcStatus = 'pending';
        rpcCekaOd = DateTime.now().toUtc().toIso8601String();
      } else if (tipGrad == 'bc' && jeDnevni) {
        rpcStatus = 'manual';
        rpcCekaOd = DateTime.now().toUtc().toIso8601String();
      }
    }

    // Sačuvaj staro stanje za slučaj greške (Deep copy)
    final oldPolasci = jsonDecode(jsonEncode(_safeMap(_putnikData['polasci_po_danu'])));
    final oldRadniDani = _putnikData['radni_dani']?.toString();

    // --- OPTIMISTIČNI UI APDEJT ---
    setState(() {
      final polasci = Map<String, dynamic>.from(_safeMap(_putnikData['polasci_po_danu']));
      final danData = Map<String, dynamic>.from(_safeMap(polasci[dan]));

      danData[tipGrad] = normalizedVreme;
      danData['${tipGrad}_status'] = rpcStatus;
      danData['${tipGrad}_ceka_od'] = rpcCekaOd;
      danData['${tipGrad}_otkazano'] = rpcOtkazano;
      danData['${tipGrad}_otkazano_vreme'] = rpcOtkazanoVreme;
      danData['${tipGrad}_otkazao_vozac'] = rpcOtkazaoVozac;

      if (rpcStatus != 'confirmed' && rpcStatus != 'approved') {
        danData.remove('${tipGrad}_resolved_at');
      }

      polasci[dan] = danData;
      _putnikData['polasci_po_danu'] = polasci;

      // Update radni dani string
      final Set<String> radniSet = {};
      polasci.forEach((k, v) {
        if (v is Map) {
          if ((v['bc'] != null && v['bc'].toString().isNotEmpty && v['bc'] != 'null') ||
              (v['vs'] != null && v['vs'].toString().isNotEmpty && v['vs'] != 'null')) {
            radniSet.add(k);
          }
        }
      });
      _putnikData['radni_dani'] = radniSet.join(',');
    });

    try {
      // 1. RPC poziv (Atomski u bazi sa proverom kapaciteta)
      await supabase.rpc('update_putnik_polazak_v2', params: {
        'p_id': putnikId,
        'p_dan': dan,
        'p_grad': tipGrad,
        'p_vreme': normalizedVreme,
        'p_status': rpcStatus,
        'p_ceka_od': rpcCekaOd,
        'p_otkazano': rpcOtkazano,
        'p_otkazano_vreme': rpcOtkazanoVreme,
        'p_otkazao_vozac': rpcOtkazaoVozac,
      });

      // 2. SeatRequest i pozadinski procesi (Bez await-a gde može da bi bilo brže za korisnika)
      if (normalizedVreme != null && normalizedVreme.isNotEmpty) {
        SeatRequestService.insertSeatRequest(
          putnikId: putnikId,
          dan: dan,
          vreme: seatVreme,
          grad: tipGrad,
          brojMesta: _putnikData['broj_mesta'] ?? 1,
          status: rpcStatus ?? 'pending',
        ).catchError((e) => debugPrint('Error inserting seat request: $e'));

        VoznjeLogService.logZahtev(
          putnikId: putnikId,
          dan: dan,
          vreme: seatVreme,
          grad: tipGrad,
          tipPutnika: jeDnevni ? 'Dnevni' : (jeUcenik ? 'Učenik' : 'Radnik'),
          status: rpcStatus == 'manual' ? 'Čeka odobrenje admina (Manual)' : 'Čeka potvrdu (Pending)',
        ).catchError((e) => debugPrint('Error logging request: $e'));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zahtev primljen, biće obrađen uskoro.'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // Otkazivanje - pozadinska obaveštenja
        _handleOtkazivanjeBackground(dan, tipGrad, rpcOtkazanoVreme ?? '');
      }
    } catch (e) {
      debugPrint('❌ [BC] Greška u _updatePolazak: $e');
      if (mounted) {
        // Rollback UI na staro stanje
        setState(() {
          _putnikData['polasci_po_danu'] = oldPolasci;
          _putnikData['radni_dani'] = oldRadniDani;
        });

        String errorMsg = 'Greška pri čuvanju promene.';
        if (e.toString().contains('KAPACITET_PUN')) {
          errorMsg = 'Žao nam je, u terminu $normalizedVreme više nema slobodnih mesta.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Pomoćna za pozadinsko slanje notifikacija kod otkazivanja
  void _handleOtkazivanjeBackground(String dan, String tipGrad, String displayVreme) {
    VoznjeLogService.logGeneric(
      tip: 'otkazivanje_putnika',
      putnikId: _putnikData['id']?.toString(),
      detalji: 'Otkazan termin (${tipGrad.toUpperCase()}) za $dan ($displayVreme)',
    ).catchError((_) {});

    final now = DateTime.now();
    final todayName = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'][now.weekday - 1];
    if (dan.toLowerCase() == todayName) {
      final putnikIme = _putnikData['putnik_ime'] ?? _putnikData['ime'] ?? 'Putnik';
      RealtimeNotificationService.sendNotificationToAllDrivers(
        title: 'Otkazan putnik (samostalno)',
        body: '$putnikIme ($displayVreme)',
        data: {
          'type': 'otkazan_putnik',
          'datum': now.toIso8601String(),
          'putnik': {'id': _putnikData['id'], 'ime': putnikIme, 'grad': tipGrad.toUpperCase(), 'vreme': displayVreme},
        },
      ).catchError((_) {});
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
              Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.5), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
