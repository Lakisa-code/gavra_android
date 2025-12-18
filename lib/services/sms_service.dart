import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/registrovani_putnik.dart';
import 'firebase_service.dart';

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
    if (now.day == secondToLastDay.day && now.hour == 20 && now.minute >= 0 && now.minute < 5) {
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

  /// Šalje SMS svim neplaćenim mesečnim putnicima (predzadnji dan meseca)
  static Future<void> sendSMSToUnpaidMonthlyPassengers() async {
    try {
      // 🚨 SAMO BOJAN MOŽE DA ŠALJE SMS PORUKE
      final currentDriver = await FirebaseService.getCurrentDriver();

      if (currentDriver == null || currentDriver.toLowerCase() != 'bojan') {
        debugPrint('🚫 SMS servis dostupan samo za vozača Bojan. Trenutni vozač: $currentDriver');
        return;
      }

      debugPrint('📱 Učitavam neplaćene mesečne putnike... (Vozač: $currentDriver)');

      // Trenutni mesec i godina
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      // Učitaj sve aktivne mesečne putnike koji NISU platili za trenutni mesec
      final response = await supabase
          .from('registrovani_putnici')
          .select('*')
          .eq('aktivan', true)
          .eq('obrisan', false)
          .neq('tip', 'dnevni'); // Samo mesečni (radnik, ucenik)

      final List<RegistrovaniPutnik> allPassengers =
          (response as List).map((data) => RegistrovaniPutnik.fromMap(data as Map<String, dynamic>)).toList();

      // Filtriraj one koji nisu platili za trenutni mesec
      final unpaidPassengers = allPassengers.where((putnik) {
        // Proveri da li ima telefon
        if (putnik.brojTelefona == null || putnik.brojTelefona!.isEmpty) {
          return false;
        }
        // Proveri da li je platio za trenutni mesec
        final placeniMesec = putnik.placeniMesec;
        final placenaGodina = putnik.placenaGodina;

        // Nije platio ako:
        // - Nema uopšte plaćanje
        // - Ili plaćanje nije za trenutni mesec/godinu
        if (placeniMesec == null || placenaGodina == null) {
          return true; // Nije nikad platio
        }
        if (placenaGodina < currentYear) {
          return true; // Platio prošle godine
        }
        if (placenaGodina == currentYear && placeniMesec < currentMonth) {
          return true; // Platio ranije ove godine
        }
        return false; // Platio za ovaj mesec
      }).toList();

      debugPrint('📋 Pronađeno ${unpaidPassengers.length} putnika koji nisu platili za ${_getMonthName(currentMonth)}');

      int successCount = 0;
      int errorCount = 0;

      for (RegistrovaniPutnik putnik in unpaidPassengers) {
        try {
          // Izračunaj dugovanje
          final cenaPoDoanu = putnik.cenaPoDanu ?? (putnik.tip == 'ucenik' ? 600.0 : 700.0);
          final brojPutovanja = putnik.brojPutovanja;
          final brojOtkazivanja = putnik.brojOtkazivanja;
          final dugovanje = cenaPoDoanu * brojPutovanja;

          // Kreiraj SMS poruku
          String message = _createReminderSMS(
            putnik.putnikIme,
            currentMonth,
            currentYear,
            brojPutovanja,
            brojOtkazivanja,
            dugovanje,
          );

          // Pošalji SMS putniku
          await _sendSMS(putnik.brojTelefona!, message);
          successCount++;
          debugPrint('SMS poslat: ${putnik.putnikIme} (${putnik.brojTelefona})');

          // Pošalji SMS i roditeljima za učenike
          if (putnik.tip == 'ucenik') {
            await _sendSMSToParents(putnik, message);
          }

          // Pauza između SMS-ova (da se izbegne spam)
          await Future<void>.delayed(const Duration(seconds: 2));
        } catch (e) {
          errorCount++;
          debugPrint('Greška slanja SMS: ${putnik.putnikIme} - $e');
        }
      }

      debugPrint('SMS rezultati: $successCount uspešno, $errorCount greška');
    } catch (e) {
      debugPrint('Greška u SMS servisu: $e');
    }
  }

  /// Šalje SMS putnicima koji nisu platili za prethodni mesec (prvi dan meseca)
  static Future<void> sendSMSToOverdueMonthlyPassengers() async {
    try {
      // 🚨 SAMO BOJAN MOŽE DA ŠALJE SMS PORUKE
      final currentDriver = await FirebaseService.getCurrentDriver();

      if (currentDriver == null || currentDriver.toLowerCase() != 'bojan') {
        debugPrint('🚫 SMS servis dostupan samo za vozača Bojan. Trenutni vozač: $currentDriver');
        return;
      }

      debugPrint('📱 Učitavam putnike koji nisu platili za prethodni mesec... (Vozač: $currentDriver)');

      // Prethodni mesec
      final now = DateTime.now();
      final previousMonth = now.month == 1 ? 12 : now.month - 1;
      final previousYear = now.month == 1 ? now.year - 1 : now.year;

      // Učitaj sve aktivne mesečne putnike koji NISU platili za prethodni mesec
      final response = await supabase
          .from('registrovani_putnici')
          .select('*')
          .eq('aktivan', true)
          .eq('obrisan', false)
          .neq('tip', 'dnevni');

      final List<RegistrovaniPutnik> allPassengers =
          (response as List).map((data) => RegistrovaniPutnik.fromMap(data as Map<String, dynamic>)).toList();

      // Filtriraj one koji nisu platili za prethodni mesec
      final overduePassengers = allPassengers.where((putnik) {
        if (putnik.brojTelefona == null || putnik.brojTelefona!.isEmpty) {
          return false;
        }
        final placeniMesec = putnik.placeniMesec;
        final placenaGodina = putnik.placenaGodina;

        if (placeniMesec == null || placenaGodina == null) {
          return true;
        }
        // Proveri da li je platio za prethodni mesec ili kasnije
        if (placenaGodina > previousYear) {
          return false; // Platio ove godine (nakon prethodnog meseca)
        }
        if (placenaGodina == previousYear && placeniMesec >= previousMonth) {
          return false; // Platio za prethodni mesec ili kasnije
        }
        return true; // Nije platio
      }).toList();

      debugPrint(
          '📋 Pronađeno ${overduePassengers.length} putnika koji nisu platili za ${_getMonthName(previousMonth)}');

      int successCount = 0;
      int errorCount = 0;

      for (RegistrovaniPutnik putnik in overduePassengers) {
        try {
          final cenaPoDoanu = putnik.cenaPoDanu ?? (putnik.tip == 'ucenik' ? 600.0 : 700.0);
          final brojPutovanja = putnik.brojPutovanja;
          final brojOtkazivanja = putnik.brojOtkazivanja;
          final dugovanje = cenaPoDoanu * brojPutovanja;

          // Kreiraj SMS poruku za krajnji rok
          String message = _createOverdueReminderSMS(
            putnik.putnikIme,
            previousMonth,
            previousYear,
            brojPutovanja,
            brojOtkazivanja,
            dugovanje,
          );

          // Pošalji SMS
          await _sendSMS(putnik.brojTelefona!, message);
          successCount++;
          debugPrint('✅ Krajnji rok SMS poslat: ${putnik.putnikIme} (${putnik.brojTelefona})');

          // Pošalji SMS i roditeljima za učenike
          if (putnik.tip == 'ucenik') {
            await _sendSMSToParents(putnik, message);
          }

          // Pauza između SMS-ova
          await Future<void>.delayed(const Duration(seconds: 2));
        } catch (e) {
          errorCount++;
          debugPrint('❌ Greška slanja krajnji rok SMS: ${putnik.putnikIme} - $e');
        }
      }

      debugPrint('📊 Krajnji rok SMS rezultati: $successCount uspešno, $errorCount greška');
    } catch (e) {
      debugPrint('💥 Greška u krajnji rok SMS servisu: $e');
    }
  }

  /// Kreiranje SMS poruke - PODSETNIK (predzadnji dan meseca)
  static String _createReminderSMS(
    String ime,
    int mesec,
    int godina,
    int putovanja,
    int otkazivanja,
    double dugovanje,
  ) {
    final mesecNaziv = _getMonthName(mesec);
    final lastDay = DateTime(godina, mesec + 1, 0).day;

    return '🚌 GAVRA PREVOZ\n\n'
        'OBAVEŠTENJE O ZADUŽENJU\n\n'
        'Poštovani gospodine $ime,\n\n'
        'Ovim putem Vas službeno obaveštavamo o Vašem trenutnom zaduženju prema našoj kompaniji.\n\n'
        '📊 Pregled vožnji za mesec $mesecNaziv $godina:\n'
        '✅ Realizovane vožnje: $putovanja\n'
        '❌ Otkazane vožnje: $otkazivanja\n'
        '💰 Ukupan iznos za uplatu: ${dugovanje.toStringAsFixed(0)} RSD\n\n'
        'Molimo Vas da izvršite uplatu najkasnije do $lastDay.$mesec.$godina., kako bi naša saradnja mogla da se nesmetano nastavi.\n\n'
        'Zahvaljujemo se na dosadašnjoj saradnji i blagovremenom izmirenju obaveza! 🙏\n\n'
        'S poštovanjem,\n'
        'Gavra Prevoz\n\n'
        'Kontakt za podršku: 0641162560\n\n'
        'Ova poruka je generisana automatski. Molimo ne odgovarajte na nju.';
  }

  /// Kreiranje SMS poruke za krajnji rok (prvi dan meseca)
  static String _createOverdueReminderSMS(
    String ime,
    int mesec,
    int godina,
    int putovanja,
    int otkazivanja,
    double dugovanje,
  ) {
    final mesecNaziv = _getMonthName(mesec);
    final now = DateTime.now();
    // Krajnji rok je 5. sledećeg meseca
    final krajnjiRokMesec = now.month;
    final krajnjiRokGodina = now.year;
    final krajnjiRokMesecNaziv = _getMonthName(krajnjiRokMesec);

    return '⚠️ KRAJNJI ROK – HITNO OBAVEŠTENJE ⚠️\n\n'
        '🚌 GAVRA PREVOZ\n\n'
        'Poštovani gospodine $ime,\n\n'
        'Ovo je poslednje obaveštenje u vezi sa Vašim neizmorenim dugom za mesec $mesecNaziv $godina.\n\n'
        '📊 Detalji duga:\n'
        '✅ Realizovane vožnje: $putovanja\n'
        '❌ Otkazane vožnje: $otkazivanja\n'
        '💰 Ukupan dug za uplatu: ${dugovanje.toStringAsFixed(0)} RSD\n\n'
        '🚨 Novi krajnji rok za izmirenje obaveza:\n'
        '05. $krajnjiRokMesecNaziv $krajnjiRokGodina. godine\n\n'
        'Molimo Vas da hitno izmirite dug kako bismo izbegli prekid saradnje i dodatne administrativne mere.\n\n'
        'Ukoliko ste već izvršili uplatu, zanemarite ovu poruku.\n\n'
        'Hvala na razumevanju i strpljenju.\n\n'
        'S poštovanjem,\n'
        'Gavra Prevoz\n\n'
        '📞 Kontakt za podršku:\n'
        'Bojan – Gavra 013';
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
      // NAPOMENA: Automatsko slanje SMS-a NIJE MOGUĆE zbog Android ograničenja
      // Ovaj pristup otvara SMS aplikaciju sa prethodno popunjenim podacima

      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        debugPrint('📤 SMS aplikacija otvorena za: $phoneNumber');
      } else {
        throw Exception('Ne mogu da pokrenemo SMS aplikaciju');
      }
    } catch (e) {
      debugPrint('📵 Greška otvaranja SMS aplikacije za $phoneNumber: $e');
      rethrow;
    }
  }

  /// Provera da li je danas predzadnji dan meseca
  static bool isSecondToLastDayOfMonth() {
    DateTime now = DateTime.now();
    DateTime secondToLastDay = _getSecondToLastDayOfMonth(now);
    return now.day == secondToLastDay.day;
  }

  /// Šalje SMS roditeljima učenika (majka i otac)
  static Future<void> _sendSMSToParents(RegistrovaniPutnik putnik, String message) async {
    try {
      List<String> roditeljiBrojevi = [];

      // Dodaj broj telefona oca ako postoji
      if (putnik.brojTelefonaOca != null && putnik.brojTelefonaOca!.isNotEmpty) {
        roditeljiBrojevi.add(putnik.brojTelefonaOca!);
      }

      // Dodaj broj telefona majke ako postoji
      if (putnik.brojTelefonaMajke != null && putnik.brojTelefonaMajke!.isNotEmpty) {
        roditeljiBrojevi.add(putnik.brojTelefonaMajke!);
      }

      if (roditeljiBrojevi.isEmpty) {
        debugPrint('⚠️ Nema brojeva telefona roditelja za učenika: ${putnik.putnikIme}');
        return;
      }

      // Pošalji SMS svim roditeljima
      for (String brojTelefona in roditeljiBrojevi) {
        try {
          // Dodaj prefiks da roditelji znaju da je poruka o detetu
          String roditeljskaPoruka = '📬 PORUKA O VAŠEM DETETU ${putnik.putnikIme.toUpperCase()}:\n\n$message';

          await _sendSMS(brojTelefona, roditeljskaPoruka);
          debugPrint('✅ SMS poslat roditelju: $brojTelefona za učenika ${putnik.putnikIme}');

          // Pauza između SMS-ova roditeljima
          await Future<void>.delayed(const Duration(seconds: 1));
        } catch (e) {
          debugPrint('❌ Greška slanja SMS roditelju $brojTelefona: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Greška u _sendSMSToParents za ${putnik.putnikIme}: $e');
    }
  }
}
