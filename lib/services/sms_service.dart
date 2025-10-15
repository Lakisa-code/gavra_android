import 'dart:async';

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/putnik.dart';
import '../utils/logging.dart';
import 'firebase_service.dart';
import 'supabase_safe.dart';

class SMSService {
  static Timer? _monthlyTimer;
  static bool _isServiceRunning = false;
  static final supabase = Supabase.instance.client;

  /// Pokretanje automatskog SMS servisa
  static void startAutomaticSMSService() {
    if (_isServiceRunning) return;

    _isServiceRunning = true;
    dlog('🚀 SMS servis pokrenut - dupli sistem:\n'
        '   📅 Predzadnji dan meseca u 20:00 - podsećaj da ističe sutra\n'
        '   📅 Prvi dan meseca u 10:00 - krajnji rok za prethodni mesec');

    // Provera svakih sat vremena
    _monthlyTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      await _checkAndSendMonthlySMS();
    });
  }

  /// Zaustavljanje automatskog SMS servisa
  static void stopAutomaticSMSService() {
    _monthlyTimer?.cancel();
    _monthlyTimer = null;
    _isServiceRunning = false;
    dlog('🛑 SMS servis zaustavljen');
  }

  /// Provera da li je vreme za slanje SMS-a
  static Future<void> _checkAndSendMonthlySMS() async {
    DateTime now = DateTime.now();
    DateTime secondToLastDay = _getSecondToLastDayOfMonth(now);

    // Proverava da li je predzadnji dan u 20:00 - podsećaj da ističe sutra
    if (now.day == secondToLastDay.day && now.hour == 20 && now.minute >= 0 && now.minute < 5) {
      // 5-minutni prozor

      dlog('📅 Predzadnji dan meseca u 20:00 - šaljem SMS podsećaje...');
      await sendSMSToUnpaidMonthlyPassengers();
    }

    // Proverava da li je prvi dan meseca u 10:00 - krajnji rok upozorenje
    if (now.day == 1 && now.hour == 10 && now.minute >= 0 && now.minute < 5) {
      // 5-minutni prozor

      dlog('📅 Prvi dan meseca u 10:00 - šaljem SMS krajnji rok...');
      await sendSMSToOverdueMonthlyPassengers();
    }
  }

  /// Računa predzadnji dan meseca
  static DateTime _getSecondToLastDayOfMonth(DateTime date) {
    // Poslednji dan meseca
    DateTime lastDay = DateTime(date.year, date.month + 1, 0);
    // Predzadnji dan meseca
    return lastDay.subtract(const Duration(days: 1));
  }

  /// Šalje SMS svim neplaćenim mesečnim putnicima
  static Future<void> sendSMSToUnpaidMonthlyPassengers() async {
    try {
      // 🚨 SAMO BOJAN MOŽE DA ŠALJE SMS PORUKE
      final currentDriver = await FirebaseService.getCurrentDriver();

      if (currentDriver == null || currentDriver.toLowerCase() != 'bojan') {
        dlog(
          '🚫 SMS servis dostupan samo za vozača Bojan. Trenutni vozač: $currentDriver',
        );
        return;
      }

      dlog('📱 Učitavam neplaćene mesečne putnike... (Vozač: $currentDriver)');

      // Učitaj sve mesečne putnike kojima ističe karta sutra
      DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
      String tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow);

      const mesecniFields = '*,'
          'polasci_po_danu';

      final response =
          await supabase.from('mesecni_putnici').select(mesecniFields).eq('datum_kraja_meseca', tomorrowStr);

      List<Putnik> unpaidPassengers = (response as List)
          .map(
            (data) => Putnik.fromMesecniPutnici(data as Map<String, dynamic>),
          )
          .where(
            (putnik) => putnik.brojTelefona != null && putnik.brojTelefona!.isNotEmpty,
          )
          .toList();

      dlog(
        '📋 Pronađeno ${unpaidPassengers.length} putnika kojima ističe karta sutra',
      );

      int successCount = 0;
      int errorCount = 0;

      for (Putnik putnik in unpaidPassengers) {
        try {
          // Dobij statistike putovanja za putnika
          Map<String, dynamic> stats = await _getPaymentStats(putnik.id as String);

          // Kreiraj SMS poruku
          String message = _createReminderSMS(
            putnik.ime,
            stats['lastPaymentDate'] as String,
            stats['lastPaymentAmount'] as int,
            stats['tripsSincePayment'] as int,
            stats['cancellationsSincePayment'] as int,
          );

          // Pošalji SMS
          await _sendSMS(putnik.brojTelefona!, message);
          successCount++;

          dlog('✅ SMS poslat: ${putnik.ime} (${putnik.brojTelefona})');

          // 🔥 NOVO: Pošalji SMS i roditeljima za učenike
          await _sendSMSToParents(putnik, message);

          // Pauza između SMS-ova (da se izbegne spam)
          await Future<void>.delayed(const Duration(seconds: 2));
        } catch (e) {
          errorCount++;
          dlog('❌ Greška slanja SMS: ${putnik.ime} - $e');
        }
      }

      dlog('📊 SMS rezultati: $successCount uspešno, $errorCount greška');
    } catch (e) {
      dlog('💥 Greška u SMS servisu: $e');
    }
  }

  /// Šalje SMS putnicima koji nisu platili za prethodni mesec (prvi dan meseca)
  static Future<void> sendSMSToOverdueMonthlyPassengers() async {
    try {
      // 🚨 SAMO BOJAN MOŽE DA ŠALJE SMS PORUKE
      final currentDriver = await FirebaseService.getCurrentDriver();

      if (currentDriver == null || currentDriver.toLowerCase() != 'bojan') {
        dlog(
          '🚫 SMS servis dostupan samo za vozača Bojan. Trenutni vozač: $currentDriver',
        );
        return;
      }

      dlog(
        '📱 Učitavam putnike koji nisu platili za prethodni mesec... (Vozač: $currentDriver)',
      );

      // Učitaj sve mesečne putnike kojima je istekla karta jučer (nisu platili za prethodni mesec)
      DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
      String yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

      const mesecniFields = '*,'
          'polasci_po_danu';

      final response =
          await supabase.from('mesecni_putnici').select(mesecniFields).eq('datum_kraja_meseca', yesterdayStr);

      List<Putnik> overduePassengers = (response as List)
          .map(
            (data) => Putnik.fromMesecniPutnici(data as Map<String, dynamic>),
          )
          .where(
            (putnik) => putnik.brojTelefona != null && putnik.brojTelefona!.isNotEmpty,
          )
          .toList();

      dlog(
        '📋 Pronađeno ${overduePassengers.length} putnika koji nisu platili za prethodni mesec',
      );

      int successCount = 0;
      int errorCount = 0;

      for (Putnik putnik in overduePassengers) {
        try {
          // Dobij statistike putovanja za putnika
          Map<String, dynamic> stats = await _getPaymentStats(putnik.id as String);

          // Kreiraj SMS poruku za krajnji rok
          String message = _createOverdueReminderSMS(
            putnik.ime,
            stats['lastPaymentDate'] as String,
            stats['lastPaymentAmount'] as int,
            stats['tripsSincePayment'] as int,
            stats['cancellationsSincePayment'] as int,
          );

          // Pošalji SMS
          await _sendSMS(putnik.brojTelefona!, message);
          successCount++;

          dlog(
            '✅ Krajnji rok SMS poslat: ${putnik.ime} (${putnik.brojTelefona})',
          );

          // 🔥 NOVO: Pošalji SMS i roditeljima za učenike (krajnji rok)
          await _sendSMSToParents(putnik, message);

          // Pauza između SMS-ova (da se izbegne spam)
          await Future<void>.delayed(const Duration(seconds: 2));
        } catch (e) {
          errorCount++;
          dlog('❌ Greška slanja krajnji rok SMS: ${putnik.ime} - $e');
        }
      }

      dlog(
        '📊 Krajnji rok SMS rezultati: $successCount uspešno, $errorCount greška',
      );
    } catch (e) {
      dlog('💥 Greška u krajnji rok SMS servisu: $e');
    }
  }

  /// Dobijanje statistika plaćanja za putnika
  static Future<Map<String, dynamic>> _getPaymentStats(String putnikId) async {
    try {
      // 1. Poslednja uplata
      final lastPaymentResponse = await SupabaseSafe.run(
        () => supabase
            .from('putovanja_istorija')
            .select('datum_i_vreme, iznos_uplate')
            .eq('putnik_id', putnikId)
            .gt('iznos_uplate', 0)
            .order('datum_i_vreme', ascending: false)
            .limit(1),
        fallback: <dynamic>[],
      );

      if (lastPaymentResponse is! List || lastPaymentResponse.isEmpty) {
        return {
          'lastPaymentDate': 'Nema podataka',
          'lastPaymentAmount': 0,
          'tripsSincePayment': 0,
          'cancellationsSincePayment': 0,
        };
      }

      String lastPaymentDate = lastPaymentResponse[0]['datum_i_vreme'] as String;
      int lastPaymentAmount = lastPaymentResponse[0]['iznos_uplate'] as int;

      // 2. Putovanja od poslednje uplate
      final tripsResponse = await SupabaseSafe.run(
        () => supabase
            .from('putovanja_istorija')
            .select('tip_promene')
            .eq('putnik_id', putnikId)
            .gte('datum_i_vreme', lastPaymentDate),
        fallback: <dynamic>[],
      );

      // Brojanje putovanja i otkazivanja
      int putovanja = 0;
      int otkazivanja = 0;
      if (tripsResponse is List) {
        putovanja = tripsResponse.where((t) => t['tip_promene'] == 'putovanje').length;
        otkazivanja = tripsResponse.where((t) => t['tip_promene'] == 'otkazano').length;
      }

      // Formatiranje datuma
      DateTime date = DateTime.parse(lastPaymentDate);
      String formattedDate = DateFormat('dd.MM.yyyy').format(date);

      return {
        'lastPaymentDate': formattedDate,
        'lastPaymentAmount': lastPaymentAmount,
        'tripsSincePayment': putovanja,
        'cancellationsSincePayment': otkazivanja,
      };
    } catch (e) {
      dlog('⚠️ Greška dobijanja statistika za putnika $putnikId: $e');
      return {
        'lastPaymentDate': 'Greška',
        'lastPaymentAmount': 0,
        'tripsSincePayment': 0,
        'cancellationsSincePayment': 0,
      };
    }
  }

  /// Kreiranje SMS poruke sa poboljšanim formatiranjem
  static String _createReminderSMS(
    String ime,
    String datum,
    int iznos,
    int putovanja,
    int otkazivanja,
  ) {
    // Određi koji mesec nije plaćen (sledeći mesec)
    DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    String nextMonth = _getMonthName(tomorrow.month);

    return '🚌 PODSETNIK 🚌\n\n'
        'Poštovani $ime,\n'
        'Obaveštavamo Vas da izmirite obaveze za $nextMonth i da rok ističe sutra.\n\n'
        '📊 PODACI:\n'
        '• Poslednja uplata: $datum - $iznos RSD\n'
        '• Od tada: $putovanja putovanja\n'
        '• Otkazivanja: $otkazivanja\n\n'
        'Molimo platiti do kraja dana.\n'
        'Kontakt: Bojan - Gavra 013\n\n'
        'Hvala na razumevanju! 🚌\n'
        '---\n'
        'Automatska poruka.';
  }

  /// Kreiranje SMS poruke za krajnji rok (prvi dan meseca)
  static String _createOverdueReminderSMS(
    String ime,
    String datum,
    int iznos,
    int putovanja,
    int otkazivanja,
  ) {
    // Određi koji mesec nije plaćen (prethodni mesec)
    DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
    String previousMonth = _getMonthName(yesterday.month);

    return '⚠️ KRAJNJI ROK ⚠️\n\n'
        'Poštovani $ime,\n'
        'Podse​ćamo Vas da niste izmirili obaveze za $previousMonth i da je krajnji rok 5. u ovom mesecu.\n\n'
        '📊 PODACI:\n'
        '• Poslednja uplata: $datum - $iznos RSD\n'
        '• Od tada: $putovanja putovanja\n'
        '• Otkazivanja: $otkazivanja\n\n'
        '🚨 UPOZORENJE: Ako se ne plati do 5. u mesecu, automatski ćete biti skinuti sa liste mesečnih putnika.\n\n'
        'Kontakt: Bojan - Gavra 013\n\n'
        'Hvala na razumevanju! 🚌\n'
        '---\n'
        'Automatska poruka.';
  }

  /// Dobijanje naziva meseca na srpskom
  static String _getMonthName(int month) {
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

  /// Slanje SMS poruke
  static Future<void> _sendSMS(String phoneNumber, String message) async {
    try {
      // NAPOMENA: Automatsko slanje SMS-a NIJE MOGUĆE zbog Android ograničenja i namespace problema
      // Android ograničava automatsko SMS slanje iz bezbednosnih razloga
      // Ovaj pristup otvara SMS aplikaciju sa prethodno popunjenim podacima

      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        dlog('📤 SMS aplikacija otvorena za: $phoneNumber');
        dlog('📝 Poruka pripremljena, korisnik mora ručno da pošalje');
      } else {
        throw Exception('Ne mogu da pokrenemo SMS aplikaciju');
      }
    } catch (e) {
      dlog('📵 Greška otvaranja SMS aplikacije za $phoneNumber: $e');
      rethrow;
    }
  }

  /// Provera da li je danas predzadnji dan meseca
  static bool isSecondToLastDayOfMonth() {
    DateTime now = DateTime.now();
    DateTime secondToLastDay = _getSecondToLastDayOfMonth(now);
    return now.day == secondToLastDay.day;
  }

  /// 🔥 NOVA FUNKCIJA: Šalje SMS roditeljima učenika (majka i otac)
  static Future<void> _sendSMSToParents(Putnik putnik, String message) async {
    try {
      // Trebamo pristupiti MesecniPutnik objektu za podatke o roditeljima
      // Pošto Putnik model ne sadrži podatke o roditeljima, trebamo ih učitati iz baze

      if (putnik.id == null) {
        dlog('⚠️ Nema ID za putnika: ${putnik.ime}');
        return;
      }

      // Učitaj mesečni putnik iz baze da dobijem podatke o roditeljima
      const mesecniFields = 'tip, broj_telefona_oca, broj_telefona_majke, putnik_ime';

      final response =
          await supabase.from('mesecni_putnici').select(mesecniFields).eq('id', putnik.id.toString()).single();

      // Provjeri da li je učenik (samo učenicima šaljemo roditeljima)
      final tip = response['tip'] as String?;
      if (tip == null || tip.toLowerCase() != 'učenik') {
        return; // Ne šalje roditeljima ako nije učenik
      }

      List<String> roditeljiBrojevi = [];

      // Dodaj broj telefona oca ako postoji
      final brojOca = response['broj_telefona_oca'] as String?;
      if (brojOca != null && brojOca.isNotEmpty) {
        roditeljiBrojevi.add(brojOca);
      }

      // Dodaj broj telefona majke ako postoji
      final brojMajke = response['broj_telefona_majke'] as String?;
      if (brojMajke != null && brojMajke.isNotEmpty) {
        roditeljiBrojevi.add(brojMajke);
      }

      if (roditeljiBrojevi.isEmpty) {
        dlog('⚠️ Nema brojeva telefona roditelja za učenika: ${putnik.ime}');
        return;
      }

      // Pošalji SMS svim roditeljima
      for (String brojTelefona in roditeljiBrojevi) {
        try {
          // Dodaj prefiks da roditelji znaju da je poruka o detetu
          String roditeljskaPorta = '📚 PORUKA O VAŠEM DETETU ${putnik.ime.toUpperCase()}: $message';

          await _sendSMS(brojTelefona, roditeljskaPorta);
          dlog(
            '✅ SMS poslat roditelju: $brojTelefona za učenika ${putnik.ime}',
          );

          // Pauza između SMS-ova roditeljima
          await Future<void>.delayed(const Duration(seconds: 1));
        } catch (e) {
          dlog('❌ Greška slanja SMS roditelju $brojTelefona: $e');
        }
      }
    } catch (e) {
      dlog('❌ Greška u _sendSMSToParents za ${putnik.ime}: $e');
    }
  }
}





