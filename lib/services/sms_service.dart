import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/putnik.dart';
import 'firebase_service.dart';
import 'package:flutter/foundation.dart';

class SMSService {
  static Timer? _monthlyTimer;
  static bool _isServiceRunning = false;
  static final supabase = Supabase.instance.client;

  /// Pokretanje automatskog SMS servisa
  static void startAutomaticSMSService() {
    if (_isServiceRunning) return;

    _isServiceRunning = true;
    debugPrint('🚀 SMS servis pokrenut - dupli sistem:\n'
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
    debugPrint('🛑 SMS servis zaustavljen');
  }

  /// Provera da li je vreme za slanje SMS-a
  static Future<void> _checkAndSendMonthlySMS() async {
    DateTime now = DateTime.now();
    DateTime secondToLastDay = _getSecondToLastDayOfMonth(now);

    // Proverava da li je predzadnji dan u 20:00 - podsećaj da ističe sutra
    if (now.day == secondToLastDay.day &&
        now.hour == 20 &&
        now.minute >= 0 &&
        now.minute < 5) {
      // 5-minutni prozor

      debugPrint('📅 Predzadnji dan meseca u 20:00 - šaljem SMS podsećaje...');
      await sendSMSToUnpaidMonthlyPassengers();
    }

    // Proverava da li je prvi dan meseca u 10:00 - krajnji rok upozorenje
    if (now.day == 1 && now.hour == 10 && now.minute >= 0 && now.minute < 5) {
      // 5-minutni prozor

      debugPrint('📅 Prvi dan meseca u 10:00 - šaljem SMS krajnji rok...');
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
        debugPrint(
            '🚫 SMS servis dostupan samo za vozača Bojan. Trenutni vozač: $currentDriver');
        return;
      }

      debugPrint(
          '📱 Učitavam neplaćene mesečne putnike... (Vozač: $currentDriver)');

      // Učitaj sve mesečne putnike kojima ističe karta sutra
      DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
      String tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow);

      const mesecniFields = '*,'
          'polasci_po_danu,'
          'polazak_bc_pon,polazak_bc_uto,polazak_bc_sre,polazak_bc_cet,polazak_bc_pet,'
          'polazak_vs_pon,polazak_vs_uto,polazak_vs_sre,polazak_vs_cet,polazak_vs_pet';

      final response = await supabase
          .from('mesecni_putnici')
          .select(mesecniFields)
          .eq('datum_kraja_meseca', tomorrowStr);

      List<Putnik> unpaidPassengers = (response as List)
          .map((data) => Putnik.fromMesecniPutnici(data))
          .where((putnik) =>
              putnik.brojTelefona != null && putnik.brojTelefona!.isNotEmpty)
          .toList();

      debugPrint(
          '📋 Pronađeno ${unpaidPassengers.length} putnika kojima ističe karta sutra');

      int successCount = 0;
      int errorCount = 0;

      for (Putnik putnik in unpaidPassengers) {
        try {
          // Dobij statistike putovanja za putnika
          Map<String, dynamic> stats = await _getPaymentStats(putnik.id!);

          // Kreiraj SMS poruku
          String message = _createReminderSMS(
              putnik.ime,
              stats['lastPaymentDate'],
              stats['lastPaymentAmount'],
              stats['tripsSincePayment'],
              stats['cancellationsSincePayment']);

          // Pošalji SMS
          await _sendSMS(putnik.brojTelefona!, message);
          successCount++;

          debugPrint('✅ SMS poslat: ${putnik.ime} (${putnik.brojTelefona})');

          // Pauza između SMS-ova (da se izbegne spam)
          await Future.delayed(const Duration(seconds: 2));
        } catch (e) {
          errorCount++;
          debugPrint('❌ Greška slanja SMS: ${putnik.ime} - $e');
        }
      }

      debugPrint('📊 SMS rezultati: $successCount uspešno, $errorCount greška');
    } catch (e) {
      debugPrint('💥 Greška u SMS servisu: $e');
    }
  }

  /// Šalje SMS putnicima koji nisu platili za prethodni mesec (prvi dan meseca)
  static Future<void> sendSMSToOverdueMonthlyPassengers() async {
    try {
      // 🚨 SAMO BOJAN MOŽE DA ŠALJE SMS PORUKE
      final currentDriver = await FirebaseService.getCurrentDriver();

      if (currentDriver == null || currentDriver.toLowerCase() != 'bojan') {
        debugPrint(
            '🚫 SMS servis dostupan samo za vozača Bojan. Trenutni vozač: $currentDriver');
        return;
      }

      debugPrint(
          '📱 Učitavam putnike koji nisu platili za prethodni mesec... (Vozač: $currentDriver)');

      // Učitaj sve mesečne putnike kojima je istekla karta jučer (nisu platili za prethodni mesec)
      DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
      String yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

      const mesecniFields = '*,'
          'polasci_po_danu,'
          'polazak_bc_pon,polazak_bc_uto,polazak_bc_sre,polazak_bc_cet,polazak_bc_pet,'
          'polazak_vs_pon,polazak_vs_uto,polazak_vs_sre,polazak_vs_cet,polazak_vs_pet';

      final response = await supabase
          .from('mesecni_putnici')
          .select(mesecniFields)
          .eq('datum_kraja_meseca', yesterdayStr);

      List<Putnik> overduePassengers = (response as List)
          .map((data) => Putnik.fromMesecniPutnici(data))
          .where((putnik) =>
              putnik.brojTelefona != null && putnik.brojTelefona!.isNotEmpty)
          .toList();

      debugPrint(
          '📋 Pronađeno ${overduePassengers.length} putnika koji nisu platili za prethodni mesec');

      int successCount = 0;
      int errorCount = 0;

      for (Putnik putnik in overduePassengers) {
        try {
          // Dobij statistike putovanja za putnika
          Map<String, dynamic> stats = await _getPaymentStats(putnik.id!);

          // Kreiraj SMS poruku za krajnji rok
          String message = _createOverdueReminderSMS(
              putnik.ime,
              stats['lastPaymentDate'],
              stats['lastPaymentAmount'],
              stats['tripsSincePayment'],
              stats['cancellationsSincePayment']);

          // Pošalji SMS
          await _sendSMS(putnik.brojTelefona!, message);
          successCount++;

          debugPrint(
              '✅ Krajnji rok SMS poslat: ${putnik.ime} (${putnik.brojTelefona})');

          // Pauza između SMS-ova (da se izbegne spam)
          await Future.delayed(const Duration(seconds: 2));
        } catch (e) {
          errorCount++;
          debugPrint('❌ Greška slanja krajnji rok SMS: ${putnik.ime} - $e');
        }
      }

      debugPrint(
          '📊 Krajnji rok SMS rezultati: $successCount uspešno, $errorCount greška');
    } catch (e) {
      debugPrint('💥 Greška u krajnji rok SMS servisu: $e');
    }
  }

  /// Dobijanje statistika plaćanja za putnika
  static Future<Map<String, dynamic>> _getPaymentStats(String putnikId) async {
    try {
      // 1. Poslednja uplata
      final lastPaymentResponse = await supabase
          .from('putovanja_istorija')
          .select('datum_i_vreme, iznos_uplate')
          .eq('putnik_id', putnikId)
          .gt('iznos_uplate', 0)
          .order('datum_i_vreme', ascending: false)
          .limit(1);

      if (lastPaymentResponse.isEmpty) {
        return {
          'lastPaymentDate': 'Nema podataka',
          'lastPaymentAmount': 0,
          'tripsSincePayment': 0,
          'cancellationsSincePayment': 0,
        };
      }

      String lastPaymentDate = lastPaymentResponse[0]['datum_i_vreme'];
      int lastPaymentAmount = lastPaymentResponse[0]['iznos_uplate'];

      // 2. Putovanja od poslednje uplate
      final tripsResponse = await supabase
          .from('putovanja_istorija')
          .select('tip_promene')
          .eq('putnik_id', putnikId)
          .gte('datum_i_vreme', lastPaymentDate);

      // Brojanje putovanja i otkazivanja
      int putovanja =
          tripsResponse.where((t) => t['tip_promene'] == 'putovanje').length;

      int otkazivanja =
          tripsResponse.where((t) => t['tip_promene'] == 'otkazano').length;

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
      debugPrint('⚠️ Greška dobijanja statistika za putnika $putnikId: $e');
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

    return "🚌 PODSETNIK 🚌\n\n"
        "Poštovani $ime,\n"
        "Obaveštavamo Vas da izmirite obaveze za $nextMonth i da rok ističe sutra.\n\n"
        "📊 PODACI:\n"
        "• Poslednja uplata: $datum - $iznos RSD\n"
        "• Od tada: $putovanja putovanja\n"
        "• Otkazivanja: $otkazivanja\n\n"
        "Molimo platiti do kraja dana.\n"
        "Kontakt: Bojan - Gavra 013\n\n"
        "Hvala na razumevanju! 🚌\n"
        "---\n"
        "Automatska poruka.";
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

    return "⚠️ KRAJNJI ROK ⚠️\n\n"
        "Poštovani $ime,\n"
        "Podse​ćamo Vas da niste izmirili obaveze za $previousMonth i da je krajnji rok 5. u ovom mesecu.\n\n"
        "📊 PODACI:\n"
        "• Poslednja uplata: $datum - $iznos RSD\n"
        "• Od tada: $putovanja putovanja\n"
        "• Otkazivanja: $otkazivanja\n\n"
        "🚨 UPOZORENJE: Ako se ne plati do 5. u mesecu, automatski ćete biti skinuti sa liste mesečnih putnika.\n\n"
        "Kontakt: Bojan - Gavra 013\n\n"
        "Hvala na razumevanju! 🚌\n"
        "---\n"
        "Automatska poruka.";
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
      'Decembar'
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
        debugPrint('📤 SMS aplikacija otvorena za: $phoneNumber');
        debugPrint('📝 Poruka pripremljena, korisnik mora ručno da pošalje');
      } else {
        throw Exception('Ne mogu da pokrenemo SMS aplikaciju');
      }
    } catch (e) {
      debugPrint('📵 Greška otvaranja SMS aplikacije za $phoneNumber: $e');
      rethrow;
    }
  }

  /// Manuelno slanje SMS-a (za testiranje)
  static Future<void> sendTestSMS() async {
    debugPrint('🧪 Test SMS funkcionalnosti...');
    await sendSMSToUnpaidMonthlyPassengers();
  }

  /// Provera da li je danas predzadnji dan meseca
  static bool isSecondToLastDayOfMonth() {
    DateTime now = DateTime.now();
    DateTime secondToLastDay = _getSecondToLastDayOfMonth(now);
    return now.day == secondToLastDay.day;
  }

  /// Info o sledećem slanju SMS-a
  static String getNextSMSInfo() {
    DateTime now = DateTime.now();
    DateTime secondToLastDay = _getSecondToLastDayOfMonth(now);
    String dateStr = DateFormat('dd.MM.yyyy').format(secondToLastDay);

    if (now.day <= secondToLastDay.day) {
      return 'Sledeći SMS: $dateStr u 20:00';
    } else {
      // Sledeći mesec
      DateTime nextMonth = DateTime(now.year, now.month + 1, 1);
      DateTime nextSecondToLast = _getSecondToLastDayOfMonth(nextMonth);
      String nextDateStr = DateFormat('dd.MM.yyyy').format(nextSecondToLast);
      return 'Sledeći SMS: $nextDateStr u 20:00';
    }
  }
}
