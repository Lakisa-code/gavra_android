import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/registrovani_putnik.dart';
import 'cena_obracun_service.dart';
import 'push_token_service.dart';
import 'realtime_notification_service.dart';

/// 📱 Servis za automatske podsetenike o plaćanju
/// - 27. u mesecu: podsetnik pre roka
/// - 5. u mesecu: podsetnik posle roka
class PaymentReminderService {
  static final _supabase = Supabase.instance.client;

  /// Glavna funkcija - proverava i šalje podsetnik ako treba
  /// Poziva se na app startup (main.dart)
  static Future<void> checkAndSendReminders() async {
    try {
      final count = await sendPaymentReminders();
      if (kDebugMode && count > 0) {
        debugPrint('✅ [PaymentReminder] Poslato $count podsetnika za plaćanje');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [PaymentReminder] Greška: $e');
    }
  }

  /// Proverava da li treba poslati podsetnik danas
  /// Vraća 'pre_roka', 'posle_roka' ili null
  static String? shouldSendReminder() {
    final now = DateTime.now();

    if (now.day == 27) return 'pre_roka';
    if (now.day == 5) return 'posle_roka';

    return null;
  }

  /// Broji vožnje/otkazivanja za određeni mesec iz voznje_log
  static Future<int> _countTripsForMonth(
    String putnikId,
    int mesec,
    int godina,
    String tip,
  ) async {
    try {
      final startDate = DateTime(godina, mesec, 1);
      final endDate = DateTime(godina, mesec + 1, 0); // Poslednji dan meseca

      final response = await _supabase
          .from('voznje_log')
          .select('datum')
          .eq('putnik_id', putnikId)
          .eq('tip', tip)
          .gte('datum', startDate.toIso8601String().split('T')[0])
          .lte('datum', endDate.toIso8601String().split('T')[0]);

      // Brojimo jedinstvene datume
      final jedinstveniDatumi = <String>{};
      for (final red in response) {
        if (red['datum'] != null) {
          jedinstveniDatumi.add(red['datum'] as String);
        }
      }

      return jedinstveniDatumi.length;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [PaymentReminder] Greška pri brojanju vožnji: $e');
      return 0;
    }
  }

  /// Proverava da li je podsetnik već poslat danas
  static Future<bool> isReminderAlreadySent(String tipPodsetnika) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final reminderType = tipPodsetnika == 'pre_roka' ? 'pre_deadline' : 'post_deadline';

      final response = await _supabase
          .from('payment_reminders_log')
          .select('id')
          .eq('reminder_type', reminderType)
          .eq('reminder_date', today.toIso8601String().split('T')[0])
          .maybeSingle();

      return response != null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [PaymentReminder] Greška pri proveri loga: $e');
      return false;
    }
  }

  /// Označi da je podsetnik poslat
  static Future<void> markReminderSent(String tipPodsetnika, int brojPutnika) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final reminderType = tipPodsetnika == 'pre_roka' ? 'pre_deadline' : 'post_deadline';

      await _supabase.from('payment_reminders_log').insert({
        'reminder_date': today.toIso8601String().split('T')[0],
        'reminder_type': reminderType,
        'total_unpaid_passengers': brojPutnika,
        'total_notifications_sent': brojPutnika,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [PaymentReminder] Greška pri upisu loga: $e');
    }
  }

  /// Dohvata listu neplaćenih putnika za tekući/prethodni mesec
  static Future<List<Map<String, dynamic>>> getUnpaidPassengers(String tipPodsetnika) async {
    try {
      final now = DateTime.now();
      int targetMonth;
      int targetYear;

      if (tipPodsetnika == 'pre_roka') {
        // 27. - provera za tekući mesec
        targetMonth = now.month;
        targetYear = now.year;
      } else {
        // 5. - provera za prethodni mesec
        targetMonth = now.month == 1 ? 12 : now.month - 1;
        targetYear = now.month == 1 ? now.year - 1 : now.year;
      }

      // Dohvati sve aktivne mesečne putnike
      final response = await _supabase
          .from('registrovani_putnici')
          .select('*')
          .eq('aktivan', true)
          .eq('obrisan', false)
          .neq('tip', 'dnevni');

      final List<RegistrovaniPutnik> allPassengers =
          (response as List).map((data) => RegistrovaniPutnik.fromMap(data as Map<String, dynamic>)).toList();

      // Dohvati sva plaćanja za ciljani mesec
      final placanjaResponse = await _supabase
          .from('voznje_log')
          .select('putnik_id')
          .inFilter('tip', ['uplata', 'uplata_mesecna', 'uplata_dnevna'])
          .eq('placeni_mesec', targetMonth)
          .eq('placena_godina', targetYear);

      final Set<String> placeniPutnici = {};
      for (var p in placanjaResponse) {
        if (p['putnik_id'] != null) {
          placeniPutnici.add(p['putnik_id'] as String);
        }
      }

      // Filtriraj neplaćene koji imaju push token
      final unpaidWithToken = <Map<String, dynamic>>[];

      for (final putnik in allPassengers) {
        if (placeniPutnici.contains(putnik.id)) continue;

        // Izračunaj dugovanje - dohvati broj vožnji za ciljani mesec
        final cenaPoDoanu = CenaObracunService.getCenaPoDanu(putnik);
        final brojPutovanja = await _countTripsForMonth(putnik.id, targetMonth, targetYear, 'voznja');
        final brojOtkazivanja = await _countTripsForMonth(putnik.id, targetMonth, targetYear, 'otkazivanje');
        final dugovanje = cenaPoDoanu * brojPutovanja;

        if (dugovanje <= 0) continue;

        unpaidWithToken.add({
          'putnik': putnik,
          'broj_putovanja': brojPutovanja,
          'broj_otkazivanja': brojOtkazivanja,
          'dugovanje': dugovanje,
          'mesec': targetMonth,
          'godina': targetYear,
        });
      }

      return unpaidWithToken;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [PaymentReminder] Greška pri dohvatanju neplaćenih: $e');
      return [];
    }
  }

  /// Šalje push notifikaciju neplaćenim putnicima
  static Future<int> sendPaymentReminders() async {
    final tipPodsetnika = shouldSendReminder();
    if (tipPodsetnika == null) return 0;

    // Proveri da li je već poslato danas
    final alreadySent = await isReminderAlreadySent(tipPodsetnika);
    if (alreadySent) {
      if (kDebugMode) debugPrint('ℹ️ [PaymentReminder] Podsetnik već poslat danas');
      return 0;
    }

    final unpaidPassengers = await getUnpaidPassengers(tipPodsetnika);
    if (unpaidPassengers.isEmpty) {
      if (kDebugMode) debugPrint('ℹ️ [PaymentReminder] Nema neplaćenih putnika');
      return 0;
    }

    int sentCount = 0;

    for (final data in unpaidPassengers) {
      final putnik = data['putnik'] as RegistrovaniPutnik;
      final brojPutovanja = data['broj_putovanja'] as int;
      final brojOtkazivanja = data['broj_otkazivanja'] as int;
      final dugovanje = data['dugovanje'] as double;
      final mesec = data['mesec'] as int;
      final godina = data['godina'] as int;

      // Dohvati push token za putnika
      final tokens = await PushTokenService.getTokensForPutnik(putnik.id);
      if (tokens.isEmpty) continue;

      // Kreiraj poruku
      final message = _createReminderMessage(
        tipPodsetnika: tipPodsetnika,
        ime: putnik.putnikIme,
        brojPutovanja: brojPutovanja,
        brojOtkazivanja: brojOtkazivanja,
        dugovanje: dugovanje,
        mesec: mesec,
        godina: godina,
      );

      // Pošalji notifikaciju
      final title = tipPodsetnika == 'pre_roka' ? '💰 Podsetnik za uplatu' : '⚠️ Neizmirene obaveze';

      try {
        await RealtimeNotificationService.sendPushNotification(
          title: title,
          body: message,
          tokens: tokens.map((t) => {'token': t['token']!, 'provider': t['provider']!}).toList(),
          data: {
            'type': 'payment_reminder',
            'tip': tipPodsetnika,
            'putnik_id': putnik.id,
          },
        );
        sentCount++;
      } catch (e) {
        if (kDebugMode) debugPrint('❌ [PaymentReminder] Greška pri slanju za ${putnik.putnikIme}: $e');
      }
    }

    // Zabeleži da je poslato
    if (sentCount > 0) {
      await markReminderSent(tipPodsetnika, sentCount);
      if (kDebugMode) debugPrint('✅ [PaymentReminder] Poslato $sentCount podsetnika');
    }

    return sentCount;
  }

  /// Kreira tekst poruke za podsetnik
  static String _createReminderMessage({
    required String tipPodsetnika,
    required String ime,
    required int brojPutovanja,
    required int brojOtkazivanja,
    required double dugovanje,
    required int mesec,
    required int godina,
  }) {
    final mesecNaziv = _getMonthName(mesec);

    if (tipPodsetnika == 'pre_roka') {
      final lastDay = DateTime(godina, mesec + 1, 0).day;
      return '🚌 GAVRA 013\n\n'
          'OBAVEŠTENJE O ZADUŽENJU\n\n'
          'Poštovani gospodine $ime,\n\n'
          'Ovim putem Vas službeno obaveštavamo o Vašem trenutnom zaduženju prema našoj kompaniji.\n\n'
          '📊 Pregled vožnji za mesec $mesecNaziv $godina:\n'
          '✅ Realizovane vožnje: $brojPutovanja\n'
          '❌ Otkazane vožnje: $brojOtkazivanja\n'
          '💰 Ukupan iznos za uplatu: ${dugovanje.toStringAsFixed(0)} RSD\n\n'
          'Molimo Vas da izvršite uplatu najkasnije do $lastDay.$mesec.$godina., kako bi naša saradnja mogla da se nesmetano nastavi.\n\n'
          'Zahvaljujemo se na dosadašnjoj saradnji i blagovremenom izmirenju obaveza! 🙏\n\n'
          'S poštovanjem,\n'
          'Gavra 013\n\n'
          'Kontakt: 0641162560';
    } else {
      return '🚌 GAVRA 013\n\n'
          'PODSETNIK - NEIZMIRENE OBAVEZE\n\n'
          'Poštovani gospodine $ime,\n\n'
          'Obaveštavamo Vas da niste izmirili obaveze za mesec $mesecNaziv $godina.\n\n'
          '📊 Pregled:\n'
          '✅ Realizovane vožnje: $brojPutovanja\n'
          '❌ Otkazane vožnje: $brojOtkazivanja\n'
          '💰 Ukupno dugovanje: ${dugovanje.toStringAsFixed(0)} RSD\n\n'
          'Molimo Vas da izvršite uplatu najkasnije do 10. u mesecu kako bi naša saradnja mogla nesmetano da se nastavi. '
          'Ukoliko to ne uradite, bićete automatski skinuti sa liste putnika.\n\n'
          'S poštovanjem,\n'
          'Gavra 013\n\n'
          'Kontakt: 0641162560';
    }
  }

  static String _getMonthName(int month) {
    const months = [
      'januar',
      'februar',
      'mart',
      'april',
      'maj',
      'jun',
      'jul',
      'avgust',
      'septembar',
      'oktobar',
      'novembar',
      'decembar'
    ];
    return months[month - 1];
  }
}
