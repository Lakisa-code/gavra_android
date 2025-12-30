import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/registrovani_putnik.dart';
import 'firebase_service.dart';
import 'registrovani_putnik_service.dart';

class SMSService {
  static Timer? _monthlyTimer;
  static bool _isServiceRunning = false;
  static final supabase = Supabase.instance.client;

  /// Pokretanje automatskog SMS servisa
  static void startAutomaticSMSService() {
    if (_isServiceRunning) return;

    _isServiceRunning = true;

    _monthlyTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      await _checkAndSendMonthlySMS();
    });
  }

  /// Zaustavljanje automatskog SMS servisa
  static void stopAutomaticSMSService() {
    _monthlyTimer?.cancel();
    _monthlyTimer = null;
    _isServiceRunning = false;
  }

  /// Provera da li je vreme za slanje SMS-a
  static Future<void> _checkAndSendMonthlySMS() async {
    DateTime now = DateTime.now();
    DateTime secondToLastDay = _getSecondToLastDayOfMonth(now);

    if (now.day == secondToLastDay.day && now.hour == 20 && now.minute >= 0 && now.minute < 5) {
      await sendSMSToUnpaidMonthlyPassengers();
    }

    if (now.day == 1 && now.hour == 10 && now.minute >= 0 && now.minute < 5) {
      await sendSMSToOverdueMonthlyPassengers();
    }
  }

  /// Računa predzadnji dan meseca
  static DateTime _getSecondToLastDayOfMonth(DateTime date) {
    DateTime lastDay = DateTime(date.year, date.month + 1, 0);
    return lastDay.subtract(const Duration(days: 1));
  }

  /// Šalje SMS svim neplaćenim mesečnim putnicima (predzadnji dan meseca)
  static Future<void> sendSMSToUnpaidMonthlyPassengers() async {
    try {
      // 🚨 SAMO BOJAN MOŽE DA ŠALJE SMS PORUKE
      final currentDriver = await FirebaseService.getCurrentDriver();

      if (currentDriver == null || currentDriver.toLowerCase() != 'bojan') {
        return;
      }

      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      final response = await supabase
          .from('registrovani_putnici')
          .select('*')
          .eq('aktivan', true)
          .eq('obrisan', false)
          .neq('tip', 'dnevni');

      final List<RegistrovaniPutnik> allPassengers =
          (response as List).map((data) => RegistrovaniPutnik.fromMap(data as Map<String, dynamic>)).toList();

      // Dohvati sva plaćanja za tekući mesec iz voznje_log
      final placanjaResponse = await supabase
          .from('voznje_log')
          .select('putnik_id, placeni_mesec, placena_godina')
          .eq('tip', 'uplata')
          .eq('placeni_mesec', currentMonth)
          .eq('placena_godina', currentYear);

      final Set<String> placeniPutnici = {};
      for (var p in placanjaResponse) {
        if (p['putnik_id'] != null) {
          placeniPutnici.add(p['putnik_id'] as String);
        }
      }

      final unpaidPassengers = allPassengers.where((putnik) {
        if (putnik.brojTelefona == null || putnik.brojTelefona!.isEmpty) {
          return false;
        }
        // Proveri da li je platio u voznje_log
        return !placeniPutnici.contains(putnik.id);
      }).toList();

      for (RegistrovaniPutnik putnik in unpaidPassengers) {
        try {
          final cenaPoDoanu = putnik.cenaPoDanu ?? (putnik.tip == 'ucenik' ? 600.0 : 700.0);
          // Dohvati broj putovanja iz voznje_log
          final brojPutovanja = await RegistrovaniPutnikService.izracunajBrojPutovanjaIzIstorije(putnik.id);
          final brojOtkazivanja = await RegistrovaniPutnikService.izracunajBrojOtkazivanjaIzIstorije(putnik.id);
          final dugovanje = cenaPoDoanu * brojPutovanja;

          String message = _createReminderSMS(
            putnik.putnikIme,
            currentMonth,
            currentYear,
            brojPutovanja,
            brojOtkazivanja,
            dugovanje,
          );

          await _sendSMS(putnik.brojTelefona!, message);

          if (putnik.tip == 'ucenik') {
            await _sendSMSToParents(putnik, message);
          }

          await Future<void>.delayed(const Duration(seconds: 2));
        } catch (_) {
          // SMS send error - silent
        }
      }
    } catch (_) {
      // SMS service error - silent
    }
  }

  /// Šalje SMS putnicima koji nisu platili za prethodni mesec (prvi dan meseca)
  static Future<void> sendSMSToOverdueMonthlyPassengers() async {
    try {
      // 🚨 SAMO BOJAN MOŽE DA ŠALJE SMS PORUKE
      final currentDriver = await FirebaseService.getCurrentDriver();

      if (currentDriver == null || currentDriver.toLowerCase() != 'bojan') {
        return;
      }

      final now = DateTime.now();
      final previousMonth = now.month == 1 ? 12 : now.month - 1;
      final previousYear = now.month == 1 ? now.year - 1 : now.year;

      final response = await supabase
          .from('registrovani_putnici')
          .select('*')
          .eq('aktivan', true)
          .eq('obrisan', false)
          .neq('tip', 'dnevni');

      final List<RegistrovaniPutnik> allPassengers =
          (response as List).map((data) => RegistrovaniPutnik.fromMap(data as Map<String, dynamic>)).toList();

      // Dohvati sva plaćanja za prethodni mesec iz voznje_log
      final placanjaResponse = await supabase
          .from('voznje_log')
          .select('putnik_id, placeni_mesec, placena_godina')
          .eq('tip', 'uplata')
          .eq('placeni_mesec', previousMonth)
          .eq('placena_godina', previousYear);

      final Set<String> placeniPutnici = {};
      for (var p in placanjaResponse) {
        if (p['putnik_id'] != null) {
          placeniPutnici.add(p['putnik_id'] as String);
        }
      }

      final overduePassengers = allPassengers.where((putnik) {
        if (putnik.brojTelefona == null || putnik.brojTelefona!.isEmpty) {
          return false;
        }
        // Proveri da li je platio u voznje_log
        return !placeniPutnici.contains(putnik.id);
      }).toList();

      for (RegistrovaniPutnik putnik in overduePassengers) {
        try {
          final cenaPoDoanu = putnik.cenaPoDanu ?? (putnik.tip == 'ucenik' ? 600.0 : 700.0);
          // Dohvati broj putovanja iz voznje_log
          final brojPutovanja = await RegistrovaniPutnikService.izracunajBrojPutovanjaIzIstorije(putnik.id);
          final brojOtkazivanja = await RegistrovaniPutnikService.izracunajBrojOtkazivanjaIzIstorije(putnik.id);
          final dugovanje = cenaPoDoanu * brojPutovanja;

          String message = _createOverdueReminderSMS(
            putnik.putnikIme,
            previousMonth,
            previousYear,
            brojPutovanja,
            brojOtkazivanja,
            dugovanje,
          );

          await _sendSMS(putnik.brojTelefona!, message);

          if (putnik.tip == 'ucenik') {
            await _sendSMSToParents(putnik, message);
          }

          await Future<void>.delayed(const Duration(seconds: 2));
        } catch (_) {
          // Overdue SMS send error - silent
        }
      }
    } catch (_) {
      // Overdue SMS service error - silent
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
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': message},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      throw Exception('Ne mogu da pokrenemo SMS aplikaciju');
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
        return;
      }

      // Pošalji SMS svim roditeljima
      for (String brojTelefona in roditeljiBrojevi) {
        try {
          // Dodaj prefiks da roditelji znaju da je poruka o detetu
          String roditeljskaPoruka = '📬 PORUKA O VAŠEM DETETU ${putnik.putnikIme.toUpperCase()}:\n\n$message';

          await _sendSMS(brojTelefona, roditeljskaPoruka);

          // Pauza između SMS-ova roditeljima
          await Future<void>.delayed(const Duration(seconds: 1));
        } catch (_) {
          // Parent SMS error - silent
        }
      }
    } catch (_) {
      // _sendSMSToParents error - silent
    }
  }
}
