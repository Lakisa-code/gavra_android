import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import 'kapacitet_service.dart';
import 'realtime_notification_service.dart';
import 'slobodna_mesta_service.dart';

///  BEBA DISPEČER (ML Dispatch Autonomous Service)
///
/// 100% AUTONOMNA: Ne veruje u fiksne sektore ili "human" kategorije.
/// Uči isključivo iz protoka podataka i istorijskih afiniteta putnika.

class MLDispatchAutonomousService extends ChangeNotifier {
  static SupabaseClient get _supabase => supabase;

  //  REALTIME
  RealtimeChannel? _bookingStream;

  final Map<String, String> _passengerAffinity = {}; // putnik_id -> vozac_ime (Naučeno)
  double _avgHourlyBookings = 0.5;

  bool _isActive = false;
  bool _isAutopilotEnabled = false; //  100% Autonomija
  Timer? _velocityTimer;

  // Rezultati analize za UI
  final List<DispatchAdvice> _currentAdvice = <DispatchAdvice>[];

  // Singleton
  static final MLDispatchAutonomousService _instance = MLDispatchAutonomousService._internal();
  factory MLDispatchAutonomousService() => _instance;
  MLDispatchAutonomousService._internal();

  List<DispatchAdvice> get activeAdvice => List<DispatchAdvice>.unmodifiable(_currentAdvice);
  bool get isAutopilotEnabled => _isAutopilotEnabled;

  /// Prekidač za 100% Autonomiju
  void toggleAutopilot(bool value) {
    _isAutopilotEnabled = value;
    if (kDebugMode) print(' [ML Dispatch] Autopilot: $_isAutopilotEnabled');
    notifyListeners();
  }

  /// Broj putnika za koje je sistem naučio afinitet iz istorije (Pure Data)
  double get learnedAffinityCount => _passengerAffinity.length.toDouble();

  ///  LEARN FLOW (Unsupervised Affinity Learning)
  Future<void> _learnFromHistory() async {
    try {
      if (kDebugMode) print(' [ML Dispatch] Beba uči afinitete iz istorije...');

      final List<dynamic> logs = await _supabase
          .from('voznje_log')
          .select('putnik_id, vozac_id')
          .eq('tip', 'voznja')
          .order('created_at', ascending: false)
          .limit(1000);

      final Map<String, Map<String, int>> counts = {};
      for (var log in logs) {
        final pId = log['putnik_id']?.toString();
        final vId = log['vozac_id']?.toString();
        if (pId == null || vId == null) continue;

        counts.putIfAbsent(pId, () => {});
        counts[pId]![vId] = (counts[pId]![vId] ?? 0) + 1;
      }

      counts.forEach((pId, drivers) {
        final sorted = drivers.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        if (sorted.isNotEmpty && sorted.first.value >= 3) {
          _passengerAffinity[pId] = sorted.first.key;
        }
      });

      final List<dynamic> recentRequests =
          await _supabase.from('seat_requests').select('created_at').order('created_at', ascending: false).limit(100);

      if (recentRequests.length > 10) {
        _avgHourlyBookings = recentRequests.length / 48.0;
      }
    } catch (e) {
      if (kDebugMode) print(' [ML Dispatch] Greška pri učenju istorije: $e');
    } finally {
      notifyListeners();
    }
  }

  ///  POKRENI DISPEČERA
  Future<void> start() async {
    if (_isActive) return;
    _isActive = true;

    await _learnFromHistory();
    _startVelocityMonitoring();
    _startIntegrityCheck();

    // 🔧 FIX: Obradi postojeće pending zahteve pri pokretanju
    await _processNewSeatRequests();

    _subscribeToBookingStream();
  }

  void _subscribeToBookingStream() {
    try {
      _bookingStream = _supabase
          .channel('public:seat_requests')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'seat_requests',
            callback: (payload) => _analyzeRealtimeDemand(),
          )
          .subscribe();
    } catch (e) {
      if (kDebugMode) print(' [ML Dispatch] Stream subscribe error: $e');
    }
  }

  void stop() {
    _isActive = false;
    _velocityTimer?.cancel();
    _bookingStream?.unsubscribe();
  }

  void _startVelocityMonitoring() {
    // _velocityTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
    //   await _analyzeRealtimeDemand();
    // });
  }

  void _startIntegrityCheck() {
    // Timer.periodic(const Duration(minutes: 5), (timer) async {
    //   _currentAdvice.clear();
    //   await _analyzeMultiVanSplits();
    //   await _analyzeOptimalGrouping();
    //   await _analyzeCapacityOverflow();

    //   if (_isAutopilotEnabled) {
    //     await _executeAutopilotActions();
    //   }

    //   notifyListeners();
    // });
  }

  Future<void> _analyzeRealtimeDemand() async {
    try {
      final DateTime oneHourAgo = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      final dynamic recent =
          await _supabase.from('seat_requests').select().gt('created_at', oneHourAgo.toIso8601String());

      if (recent is List && recent.length >= 5) {
        _triggerAlert('REALTIME DEMAND', 'Nagli skok rezervacija (/h).');
      }

      // 🆕 Automatska obrada novih zahteva po BC LOGIKA pravilima
      await _processNewSeatRequests();
    } catch (e) {
      if (kDebugMode) print(' [ML Dispatch] Velocity error: $e');
    }
  }

  /// 🆕 AUTOMATSKA OBRADA ZAHTEVA PO BC LOGIKA PRAVILIMA
  Future<void> _processNewSeatRequests() async {
    try {
      if (kDebugMode) print(' [ML Dispatch] Proveravam nove seat requests...');

      // Nađi sve pending zahteve
      final pendingRequests =
          await _supabase.from('seat_requests').select('*').eq('status', 'pending').order('created_at');

      if (pendingRequests.isEmpty) return;

      for (var request in pendingRequests) {
        final requestId = request['id'] as String?;
        final putnikId = request['putnik_id'] as String?;

        // Provera da li su ključni podaci dostupni
        if (requestId == null || requestId.isEmpty || putnikId == null || putnikId.isEmpty) {
          if (kDebugMode) {
            print(' [ML Dispatch] ❌ Zahtev ima null requestId ili putnikId - preskačem');
          }
          continue;
        }

        // Dobaji tip putnika posebnim upitom
        try {
          final putnikData =
              await _supabase.from('registrovani_putnici').select('tip').eq('id', putnikId).maybeSingle() as Map?;

          final putnikTip = (putnikData?['tip'] as String?) ?? 'radnik'; // default radnik
          final datumStr = request['datum'] as String?;
          final vremeSlanjaZahtevaStr = request['created_at'] as String?;

          if (datumStr == null || vremeSlanjaZahtevaStr == null) {
            if (kDebugMode) print(' [ML Dispatch] ❌ Zahtev $requestId nema datuma ili vremena');
            continue;
          }

          final datum = DateTime.tryParse(datumStr);
          final vremeSlanjaZahteva = DateTime.tryParse(vremeSlanjaZahtevaStr);

          if (datum == null || vremeSlanjaZahteva == null) {
            if (kDebugMode) print(' [ML Dispatch] ❌ Zahtev $requestId ima invalidan datum format');
            continue;
          }

          // Odredi vreme čekanja po BC LOGIKA pravilima - računaj od vremena slanja zahteva
          final delay = _calculateProcessingDelay(putnikTip, datum, vremeSlanjaZahteva);

          if (delay != null) {
            // Zakazaj obradu za kasnije
            Future.delayed(delay, () => _processSingleRequest(requestId));
          } else {
            // Odmah obradi
            await _processSingleRequest(requestId);
          }
        } catch (e) {
          if (kDebugMode) print(' [ML Dispatch] ❌ Greška pri obradi zahteva $requestId: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) print(' [ML Dispatch] Greška pri procesuiranju: $e');
    }
  }

  /// Izračunaj vreme čekanja po BC LOGIKA pravilima (računa od vremena slanja zahteva)
  Duration? _calculateProcessingDelay(String tipPutnika, DateTime datumZahteva, DateTime vremeSlanja) {
    final sada = DateTime.now();
    final jeZaDanas = datumZahteva.year == vremeSlanja.year &&
        datumZahteva.month == vremeSlanja.month &&
        datumZahteva.day == vremeSlanja.day;

    final jeZaSutra = datumZahteva.year == vremeSlanja.year &&
        datumZahteva.month == vremeSlanja.month &&
        datumZahteva.day == vremeSlanja.day + 1;

    Duration? requiredDelay;

    if (tipPutnika == 'ucenik') {
      if (jeZaSutra) {
        // Sutra: proveri vreme dana kada je zahtev poslat
        final jePoslatDo16h = vremeSlanja.hour < 16;
        requiredDelay = jePoslatDo16h ? const Duration(minutes: 5) : const Duration(hours: 4); // do 20h
      } else if (jeZaDanas) {
        requiredDelay = const Duration(minutes: 10);
      }
    } else if (tipPutnika == 'radnik') {
      requiredDelay = const Duration(minutes: 5);
    } else if (tipPutnika == 'dnevni' && jeZaDanas) {
      requiredDelay = const Duration(minutes: 10);
    }

    // Ako nema required delay, odmah obradi
    if (requiredDelay == null) return null;

    // Izračunaj koliko je vremena prošlo od slanja zahteva
    final prosloVreme = sada.difference(vremeSlanja);

    // Ako je prošlo vreme veće od required delay-a, odmah obradi
    if (prosloVreme >= requiredDelay) return null;

    // Inače vrati preostalo vreme čekanja
    return requiredDelay - prosloVreme;
  }

  /// Obradi pojedinačni zahtev
  Future<void> _processSingleRequest(String requestId) async {
    try {
      // Proveri da li je još uvek pending
      final request =
          await _supabase.from('seat_requests').select('*').eq('id', requestId).eq('status', 'pending').maybeSingle();

      if (request == null) return; // Već obrađen

      final grad = request['grad'] as String?;
      final vreme = request['zeljeno_vreme'] as String?;
      final datum = request['datum'] as String?;
      final brojMesta = (request['broj_mesta'] as int?) ?? 1;

      // Proveri da li su kritični podaci dostupni
      if (grad == null || grad.isEmpty || vreme == null || vreme.isEmpty || datum == null || datum.isEmpty) {
        if (kDebugMode) {
          print(' [ML Dispatch] ❌ Zahtev $requestId ima nepotpune podatke: grad=$grad, vreme=$vreme, datum=$datum');
        }
        return;
      }

      // Proveri kapacitet
      final imaMesta = await SlobodnaMestaService.imaSlobodnihMesta(
        grad,
        vreme,
        datum: datum,
        brojMesta: brojMesta,
      );

      if (imaMesta) {
        // Odobri zahtev
        await _approveSeatRequest(requestId, vreme, request);
        if (kDebugMode) print(' [ML Dispatch] ✅ Odobren zahtev $requestId');
      } else {
        // Nema mesta - nađi alternativu
        final alternativeTimes = await findAlternativeTimes(grad, datum, vreme, brojMesta);
        if (alternativeTimes.isNotEmpty) {
          await _proposeAlternatives(requestId, alternativeTimes);
          if (kDebugMode) print(' [ML Dispatch] 🔄 Ponuđene alternative za $requestId: ${alternativeTimes.join(", ")}');
        } else {
          // Nema alternative - ostavi pending
          if (kDebugMode) print(' [ML Dispatch] ❌ Nema alternative za $requestId');
        }
      }
    } catch (e) {
      if (kDebugMode) print(' [ML Dispatch] Greška pri obradi $requestId: $e');
    }
  }

  /// Pomoćna funkcija za odobravanje zahteva
  Future<void> _approveSeatRequest(String requestId, String dodeljenoVreme, Map<String, dynamic> request) async {
    try {
      // 🛡️ VALIDACIJA: Proveri da li su kritični podaci dostupni i validni
      final putnikId = request['putnik_id'];
      final grad = request['grad'];
      final datum = request['datum'];

      if (putnikId == null || putnikId.toString().isEmpty) {
        if (kDebugMode) print(' [ML Dispatch] ❌ KRITIČNA GREŠKA: putnikId je null ili prazan! Ne mogu nastaviti.');
        return;
      }

      // 🛡️ VALIDACIJA UUID FORMAT
      if (!_isValidUuid(putnikId.toString())) {
        if (kDebugMode)
          print(
              ' [ML Dispatch] ❌ KRITIČNA GREŠKA: putnikId "$putnikId" nije validan UUID! Mogao bi obrisati sve putnike!');
        return;
      }

      if (grad == null || grad.toString().isEmpty) {
        if (kDebugMode) print(' [ML Dispatch] ❌ KRITIČNA GREŠKA: grad je null ili prazan! Ne mogu nastaviti.');
        return;
      }

      if (datum == null || datum.toString().isEmpty) {
        if (kDebugMode) print(' [ML Dispatch] ❌ KRITIČNA GREŠKA: datum je null ili prazan! Ne mogu nastaviti.');
        return;
      }

      await _supabase.from('seat_requests').update({
        'status': 'approved',
        'dodeljeno_vreme': dodeljenoVreme,
        'processed_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      // Sinhronizuj polasci_po_danu
      if (putnikId != null && grad != null && datum != null) {
        try {
          // Izračunaj dan u nedelji (1=pon, 2=uto, ..., 7=ned)
          final dateTime = DateTime.parse(datum);
          final danMap = {1: 'pon', 2: 'uto', 3: 'sre', 4: 'cet', 5: 'pet', 6: 'sub', 7: 'ned'};
          final dan = danMap[dateTime.weekday];

          if (dan != null) {
            // Dobij trenutni polasci_po_danu
            final putnikResponse =
                await _supabase.from('registrovani_putnici').select('polasci_po_danu').eq('id', putnikId).maybeSingle();

            if (putnikResponse != null) {
              final rawPolasci = putnikResponse['polasci_po_danu'];

              // Parsiraj polasci_po_danu - sada je JSONB objekat
              Map<String, dynamic> polasci = {};
              if (rawPolasci is Map) {
                polasci = Map<String, dynamic>.from(rawPolasci);
              }

              final rawDanData = polasci[dan];
              Map<String, dynamic> danData = {};
              if (rawDanData is Map) {
                danData = Map<String, dynamic>.from(rawDanData);
              }

              // Ažuriraj vrijeme i status na approved
              danData['${grad.toLowerCase()}'] = dodeljenoVreme;
              danData['${grad.toLowerCase()}_status'] = 'approved';

              polasci[dan] = danData;

              // 🛡️ KRITIČNA PROVERA 1: Nije dozvoljeno da se upiše prazna mapa!
              if (polasci.isEmpty) {
                if (kDebugMode)
                  print(
                      ' [ML Dispatch] ❌ KRITIČNA GREŠKA: polasci je prazan! Otkazujem update da ne obriše sve termine!');
                return;
              }

              // 🛡️ KRITIČNA PROVERA 2: Proveri da li putnikId još uvek validan
              if (!_isValidUuid(putnikId.toString())) {
                if (kDebugMode)
                  print(
                      ' [ML Dispatch] ❌ KRITIČNA GREŠKA: putnikId nije validan UUID nakon obrade! putnikId=$putnikId');
                return;
              }

              // Sačuvaj ažurirani polasci_po_danu
              try {
                await _supabase.from('registrovani_putnici').update({'polasci_po_danu': polasci}).eq('id', putnikId);

                if (kDebugMode) {
                  print(' [ML Dispatch] ✅ Ažuriran polasci_po_danu za $putnikId ($dan $grad)');
                }
              } catch (updateError) {
                if (kDebugMode) {
                  print(' [ML Dispatch] ❌ GREŠKA PRI UPDATE-U: $updateError');
                }
                rethrow;
              }
            }
          }
        } catch (e) {
          if (kDebugMode) print(' [ML Dispatch] ⚠️ Greška pri ažuriranju polasci_po_danu: $e');
        }
      }

      // Loguj odluku
      await _supabase.from('admin_audit_logs').insert({
        'action_type': 'AUTO_SEAT_APPROVAL',
        'details': 'Automatski odobren seat request: $requestId',
        'admin_name': 'system',
        'metadata': {'request_id': requestId, 'assigned_time': dodeljenoVreme},
        'created_at': DateTime.now().toIso8601String(),
      });

      // 📲 Pošalji notifikaciju putniku
      try {
        final gradNaziv = grad.toString().toLowerCase() == 'bc' ? 'Bela Crkva' : 'Vršac';
        // Formatiranje vremena bez sekundi (5:00:00 -> 5:00)
        final vremeFormatted = dodeljenoVreme.substring(0, dodeljenoVreme.lastIndexOf(':'));

        // Izračunaj dan iz datuma
        final date = DateTime.parse(datum.toString());
        const daniMap = {
          DateTime.monday: 'ponedeljak',
          DateTime.tuesday: 'utorak',
          DateTime.wednesday: 'sredu',
          DateTime.thursday: 'četvrtak',
          DateTime.friday: 'petak',
          DateTime.saturday: 'subotu',
          DateTime.sunday: 'nedelju'
        };
        final danNaziv = daniMap[date.weekday] ?? 'dan';

        await RealtimeNotificationService.sendNotificationToPutnik(
          putnikId: putnikId.toString(),
          title: '✅ Zahtev Odobren',
          body: 'Vaš zahtev za $danNaziv $gradNaziv u $vremeFormatted je odobren!',
          data: {
            'type': 'zahtev_odobren',
            'putnikId': putnikId.toString(),
            'vreme': dodeljenoVreme,
            'grad': grad.toString(),
          },
        );
        if (kDebugMode) print(' [ML Dispatch] 📲 Notifikacija poslata putniku $putnikId');
      } catch (notifError) {
        if (kDebugMode) print(' [ML Dispatch] ⚠️ Greška pri slanju notifikacije: $notifError');
      }
    } catch (e) {
      if (kDebugMode) print(' [ML Dispatch] Greška pri odobravanju: $e');
    }
  }

  /// Nađi NAJBLŽE alternativno vreme sa slobodnim mestima (±3 sata)
  Future<List<String>> findAlternativeTimes(String grad, String datum, String originalTime, int brojMesta) async {
    try {
      // Dobavi sva vremena za grad
      final svaVremena = KapacitetService.getVremenaZaGrad(grad);

      // Nađi indeks originalnog vremena
      final originalIndex = svaVremena.indexOf(originalTime);
      if (originalIndex == -1) return [];

      List<String> alternatives = [];

      // Nađi najbliže vreme PRE originalnog
      for (int i = originalIndex - 1; i >= 0 && (originalIndex - i) <= 3; i--) {
        final alternativeTime = svaVremena[i];
        final imaMesta = await SlobodnaMestaService.imaSlobodnihMesta(
          grad,
          alternativeTime,
          datum: datum,
          brojMesta: brojMesta,
        );
        if (imaMesta) {
          alternatives.add(alternativeTime);
          break; // Uzmi prvo (najbliže) što ima mesta
        }
      }

      // Nađi najbliže vreme POSLE originalnog
      for (int i = originalIndex + 1; i < svaVremena.length && (i - originalIndex) <= 3; i++) {
        final alternativeTime = svaVremena[i];
        final imaMesta = await SlobodnaMestaService.imaSlobodnihMesta(
          grad,
          alternativeTime,
          datum: datum,
          brojMesta: brojMesta,
        );
        if (imaMesta) {
          alternatives.add(alternativeTime);
          break; // Uzmi prvo (najbliže) što ima mesta
        }
      }

      return alternatives;
    } catch (e) {
      if (kDebugMode) print(' [ML Dispatch] Greška pri traženju alternative: $e');
      return [];
    }
  }

  /// Predloži alternativna vremena zahtevu
  Future<void> _proposeAlternatives(String requestId, List<String> alternativeTimes) async {
    try {
      final alternativesString = alternativeTimes.join(',');
      await _supabase.from('seat_requests').update({
        'status': 'alternative_proposed',
        'alternative_vreme': alternativesString,
        'processed_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      // Loguj predlog
      await _supabase.from('admin_audit_logs').insert({
        'action_type': 'AUTO_ALTERNATIVE_PROPOSED',
        'details': 'Automatski predložene alternative za seat request: $requestId - ${alternativeTimes.join(", ")}',
        'admin_name': 'system',
        'metadata': {'request_id': requestId, 'alternative_times': alternativeTimes},
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) print(' [ML Dispatch] Greška pri predlaganju alternative: $e');
    }
  }

  void _triggerAlert(String title, String body) {
    _currentAdvice.add(DispatchAdvice(
      title: title,
      description: body,
      priority: AdvicePriority.smart,
      action: 'Vidi',
    ));
    notifyListeners();
  }

  /// 🛡️ Validira UUID format
  bool _isValidUuid(String str) {
    if (str.isEmpty) return false;
    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
    return uuidRegex.hasMatch(str);
  }
}

enum AdvicePriority { smart, critical }

class DispatchAdvice {
  final String title;
  final String description;
  final AdvicePriority priority;
  final String action;
  final String? originalStatus;
  final String? proposedChange;
  final DateTime timestamp;

  DispatchAdvice({
    required this.title,
    required this.description,
    required this.priority,
    required this.action,
    this.originalStatus,
    this.proposedChange,
  }) : timestamp = DateTime.now();
}
