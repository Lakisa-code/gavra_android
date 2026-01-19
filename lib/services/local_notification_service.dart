import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/registrovani_putnik.dart';
import '../screens/danas_screen.dart';
import '../supabase_client.dart';
import 'notification_navigation_service.dart';
import 'realtime_notification_service.dart';
import 'wake_lock_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  // 1. Inicijalizuj Supabase jer smo u background isolate-u
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    // Već inicijalizovano ili greška
  }

  // 2. Prosledi hendleru
  await LocalNotificationService.handleNotificationTap(notificationResponse);
}

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static final Map<String, DateTime> _recentNotificationIds = {};
  static const Duration _dedupeDuration = Duration(seconds: 30);

  static Future<void> initialize(BuildContext context) async {
    // 📸 SCREENSHOT MODE - preskoči inicijalizaciju notifikacija
    const isScreenshotMode = bool.fromEnvironment('SCREENSHOT_MODE', defaultValue: false);
    if (isScreenshotMode) {
      return;
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        handleNotificationTap(response);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'gavra_realtime_channel',
      'Gavra Realtime Notifikacije',
      description: 'Kanal za realtime heads-up notifikacije sa zvukom',
      importance: Importance.max,
      enableLights: true,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    final androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(channel);

    // 🔔 Request permission for exact alarms and full-screen intents (Android 12+)
    try {
      // Request permission to show full-screen notifications (for lock screen)
      await androidPlugin?.requestNotificationsPermission();
    } catch (e) {
      // Ignore if not supported
    }
  }

  static Future<void> showRealtimeNotification({
    required String title,
    required String body,
    String? payload,
    bool playCustomSound = false, // 🔇 ONEMOGUĆENO: Custom zvuk ne radi
  }) async {
    try {
      String dedupeKey = '';
      try {
        if (payload != null && payload.isNotEmpty) {
          final Map<String, dynamic> parsed = jsonDecode(payload);
          if (parsed['notification_id'] != null) {
            dedupeKey = parsed['notification_id'].toString();
          }
        }
      } catch (e) {
        // 🔇 Ignore
      }
      if (dedupeKey.isEmpty) {
        // fallback: simple hash of title+body+payload
        dedupeKey = '$title|$body|${payload ?? ''}';
      }
      final now = DateTime.now();
      if (_recentNotificationIds.containsKey(dedupeKey)) {
        final last = _recentNotificationIds[dedupeKey]!;
        if (now.difference(last) < _dedupeDuration) {
          return;
        }
      }
      _recentNotificationIds[dedupeKey] = now;
      _recentNotificationIds.removeWhere((k, v) => now.difference(v) > _dedupeDuration);

      // 📱 Pali ekran kada stigne notifikacija (za lock screen)
      try {
        await WakeLockService.wakeScreen(durationMs: 5000);
      } catch (_) {
        // WakeLock nije dostupan - nije kritično
      }

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'gavra_realtime_channel',
            'Gavra Realtime Notifikacije',
            channelDescription: 'Kanal za realtime heads-up notifikacije sa zvukom',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableLights: true,
            enableVibration: true,
            // 📳 Vibration pattern kao Viber - pali ekran na Huawei
            vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
            when: DateTime.now().millisecondsSinceEpoch,
            category: AndroidNotificationCategory.message,
            visibility: NotificationVisibility.public,
            ticker: '$title - $body',
            color: const Color(0xFF64CAFB),
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            styleInformation: BigTextStyleInformation(
              body,
              htmlFormatBigText: true,
              contentTitle: title,
              htmlFormatContentTitle: true,
            ),
            // 🔔 KRITIČNO: Full-screen intent za lock screen (Android 10+)
            fullScreenIntent: true,
            // 🔔 Dodatne opcije za garantovano prikazivanje
            channelShowBadge: true,
            onlyAlertOnce: false,
            autoCancel: true,
            ongoing: false,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      // 🔇 Ignore
    }
  }

  /// 🎫 Prikazuje notifikaciju sa alternativnim BC terminima
  /// Jedna notifikacija sa opcijama: alternativni termini ili čekanje
  static Future<void> showBcAlternativeNotification({
    required String zeljeniTermin,
    required String putnikId,
    required String dan,
    required Map<String, dynamic> polasci,
    required String radniDani,
    String? terminPre,
    String? terminPosle,
  }) async {
    try {
      // Kreiraj payload sa svim podacima
      final payload = jsonEncode({
        'type': 'bc_alternativa',
        'putnikId': putnikId,
        'dan': dan,
        'zeljeniTermin': zeljeniTermin,
        'polasci': polasci,
        'radniDani': radniDani,
      });

      // Kreiraj listu akcija
      final actions = <AndroidNotificationAction>[];

      // Dodaj alternativne termine ako postoje
      if (terminPre != null) {
        actions.add(AndroidNotificationAction(
          'prihvati_$terminPre',
          '✅ $terminPre',
          showsUserInterface: true,
        ));
      }

      if (terminPosle != null) {
        actions.add(AndroidNotificationAction(
          'prihvati_$terminPosle',
          '✅ $terminPosle',
          showsUserInterface: true,
        ));
      }

      // Dodaj opciju za čekanje željenog termina
      actions.add(AndroidNotificationAction(
        'cekaj_$zeljeniTermin',
        '⏳ Čekaj $zeljeniTermin',
        showsUserInterface: true,
      ));

      // Dodaj opciju za odustajanje
      actions.add(const AndroidNotificationAction(
        'odustani',
        '❌ Odustani',
        cancelNotification: true,
      ));

      // Kreiraj body text
      String bodyText;
      if (terminPre != null || terminPosle != null) {
        final altTermini = [if (terminPre != null) terminPre, if (terminPosle != null) terminPosle];
        bodyText =
            'Nažalost, termin u $zeljeniTermin je popunjen 😔. Ali ne brinite, imamo slobodna mesta u ovim terminima: ${altTermini.join(", ")}';
      } else {
        bodyText = 'Nažalost, termin u $zeljeniTermin je popunjen 😔. Trenutno nemamo alternativnih termina.';
      }

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '🕐 Izaberite termin',
        bodyText,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'gavra_realtime_channel',
            'Gavra Realtime Notifikacije',
            channelDescription: 'Kanal za realtime notifikacije',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableLights: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
            category: AndroidNotificationCategory.message,
            visibility: NotificationVisibility.public,
            // 🔔 KRITIČNO: Full-screen intent za lock screen (Android 10+)
            fullScreenIntent: true,
            // 🔔 Dodatne opcije za garantovano prikazivanje
            channelShowBadge: true,
            onlyAlertOnce: false,
            autoCancel: true,
            ongoing: false,
            styleInformation: BigTextStyleInformation(
              bodyText,
              contentTitle: '🕐 Izaberite termin',
            ),
            actions: actions,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      // 🔇 Ignore
    }
  }

  static Future<void> showNotificationFromBackground({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      String dedupeKey = '';
      try {
        if (payload != null && payload.isNotEmpty) {
          final Map<String, dynamic> parsed = jsonDecode(payload);
          if (parsed['notification_id'] != null) {
            dedupeKey = parsed['notification_id'].toString();
          }
        }
      } catch (e) {
        // 🔇 Ignore
      }
      if (dedupeKey.isEmpty) dedupeKey = '$title|$body|${payload ?? ''}';
      final now = DateTime.now();
      if (_recentNotificationIds.containsKey(dedupeKey)) {
        final last = _recentNotificationIds[dedupeKey]!;
        if (now.difference(last) < _dedupeDuration) {
          return;
        }
      }
      _recentNotificationIds[dedupeKey] = now;
      _recentNotificationIds.removeWhere((k, v) => now.difference(v) > _dedupeDuration);
      final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await plugin.initialize(initializationSettings);

      final androidDetails = AndroidNotificationDetails(
        'gavra_realtime_channel',
        'Gavra Realtime Notifikacije',
        channelDescription: 'Kanal za realtime heads-up notifikacije sa zvukom',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        // 📳 Vibration pattern kao Viber - pali ekran na Huawei
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        // 🔔 KRITIČNO: Full-screen intent za lock screen (Android 10+)
        fullScreenIntent: true,
        // 🔔 Dodatne opcije za garantovano prikazivanje
        channelShowBadge: true,
        onlyAlertOnce: false,
        autoCancel: true,
        ongoing: false,
        enableLights: true,
      );

      final platformChannelSpecifics = NotificationDetails(
        android: androidDetails,
      );

      // Wake screen for lock screen notifications
      await WakeLockService.wakeScreen(durationMs: 10000);

      await plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {
      // Can't do much in background isolate; swallow errors
    }
  }

  static Future<void> handleNotificationTap(
    NotificationResponse response,
  ) async {
    try {
      // 🎫 Handle BC alternativa action buttons
      if (response.actionId != null && response.actionId!.startsWith('prihvati_')) {
        await _handleBcAlternativaAction(response);
        return;
      }

      // 🎫 Handle VS alternativa action buttons
      if (response.actionId != null && response.actionId!.startsWith('vs_prihvati_')) {
        await _handleVsAlternativaAction(response);
        return;
      }

      // ⏳ Handle "čekaj željeni termin" akcija (BC)
      if (response.actionId != null && response.actionId!.startsWith('cekaj_')) {
        await _handleBcCekajAction(response);
        return;
      }

      // ⏳ Handle "čekaj željeni termin" akcija (VS)
      if (response.actionId != null && response.actionId!.startsWith('vs_cekaj_')) {
        await _handleVsCekajAction(response);
        return;
      }
      // 🆕 Handle "zadrži čekanje" akcija (Rush Hour) - isto što i Čekaj, ali samo conferma status
      if (response.actionId != null && response.actionId!.startsWith('vs_zadrzi_')) {
        await _handleVsZadrziAction(response);
        return;
      }

      // Odustani akcija (BC) - samo zatvori notifikaciju
      if (response.actionId == 'odustani') {
        return;
      }

      // Odustani akcija (VS)
      if (response.actionId == 'vs_odustani') {
        return;
      }

      final context = navigatorKey.currentContext;
      if (context == null) return;

      String? putnikIme;
      String? notificationType;
      String? putnikGrad;
      String? putnikVreme;

      if (response.payload != null) {
        try {
          final Map<String, dynamic> payloadData = jsonDecode(response.payload!) as Map<String, dynamic>;

          notificationType = payloadData['type'] as String?;

          // 🎫 BC/VS alternativa - samo otvori profil bez navigacije
          if (notificationType == 'bc_alternativa' || notificationType == 'vs_alternativa') {
            await NotificationNavigationService.navigateToPassengerProfile();
            return;
          }

          // 🔐 PIN zahtev - otvori PIN zahtevi ekran
          if (notificationType == 'pin_zahtev') {
            await NotificationNavigationService.navigateToPinZahtevi();
            return;
          }

          final putnikData = payloadData['putnik'];
          if (putnikData is Map<String, dynamic>) {
            putnikIme = (putnikData['ime'] ?? putnikData['name']) as String?;
            putnikGrad = putnikData['grad'] as String?;
            putnikVreme = (putnikData['vreme'] ?? putnikData['polazak']) as String?;
          } else if (putnikData is String) {
            try {
              final putnikMap = jsonDecode(putnikData);
              if (putnikMap is Map<String, dynamic>) {
                putnikIme = (putnikMap['ime'] ?? putnikMap['name']) as String?;
                putnikGrad = putnikMap['grad'] as String?;
                putnikVreme = (putnikMap['vreme'] ?? putnikMap['polazak']) as String?;
              }
            } catch (e) {
              putnikIme = putnikData;
            }
          }

          // 🔍 DOHVATI PUTNIK PODATKE IZ BAZE ako nisu u payload-u
          if (putnikIme != null && (putnikGrad == null || putnikVreme == null)) {
            try {
              final putnikInfo = await _fetchPutnikFromDatabase(putnikIme);
              if (putnikInfo != null) {
                putnikGrad = putnikGrad ?? putnikInfo['grad'] as String?;
                putnikVreme = putnikVreme ?? (putnikInfo['polazak'] ?? putnikInfo['vreme_polaska']) as String?;
              }
            } catch (e) {
              // 🔇 Ignore
            }
          }
        } catch (e) {
          // 🔇 Ignore
        }
      }

      // 🚐 Handle transport_started notifikacije - otvori putnikov profil
      if (notificationType == 'transport_started') {
        await NotificationNavigationService.navigateToPassengerProfile();
        return; // Ne navigiraj dalje
      }

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => DanasScreen(
              highlightPutnikIme: putnikIme,
              filterGrad: putnikGrad,
              filterVreme: putnikVreme,
            ),
          ),
        );
      }

      if (putnikIme != null && context.mounted) {
        String message;
        Color bgColor;
        IconData icon;

        if (notificationType == 'novi_putnik') {
          message = '🆕 Dodat putnik: $putnikIme';
          bgColor = Colors.green;
          icon = Icons.person_add;
        } else if (notificationType == 'otkazan_putnik') {
          message = '❌ Otkazan putnik: $putnikIme';
          bgColor = Colors.red;
          icon = Icons.person_remove;
        } else {
          message = '📢 Putnik: $putnikIme';
          bgColor = Colors.blue;
          icon = Icons.info;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: bgColor,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => const DanasScreen(),
          ),
        );
      }
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    await showRealtimeNotification(
      title: title,
      body: body,
    );
  }

  static Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// 🔍 FETCH PUTNIK DATA FROM DATABASE BY NAME
  /// 🔄 POJEDNOSTAVLJENO: Koristi samo registrovani_putnici
  static Future<Map<String, dynamic>?> _fetchPutnikFromDatabase(
    String putnikIme,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      const registrovaniFields = '*,'
          'polasci_po_danu';

      final registrovaniResult = await supabase
          .from('registrovani_putnici')
          .select(registrovaniFields)
          .eq('putnik_ime', putnikIme)
          .eq('aktivan', true)
          .eq('obrisan', false)
          .order('created_at', ascending: false)
          .limit(1);

      if (registrovaniResult.isNotEmpty) {
        final data = registrovaniResult.first;
        final registrovaniPutnik = RegistrovaniPutnik.fromMap(data);

        final sada = DateTime.now();
        final danNedelje = _getDanNedelje(sada.weekday);

        String? polazak;
        String? grad;

        final polazakBC = registrovaniPutnik.getPolazakBelaCrkvaZaDan(danNedelje);
        final polazakVS = registrovaniPutnik.getPolazakVrsacZaDan(danNedelje);

        if (polazakBC != null && polazakBC.isNotEmpty) {
          polazak = polazakBC;
          grad = 'Bela Crkva';
        } else if (polazakVS != null && polazakVS.isNotEmpty) {
          polazak = polazakVS;
          grad = 'Vršac';
        }

        if (polazak != null && grad != null) {
          return {
            'grad': grad,
            'polazak': polazak,
            'dan': danNedelje,
            'tip': 'registrovani', // ✅ FIX: koristi 'registrovani' umesto 'mesecni'
          };
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static String _getDanNedelje(int weekday) {
    switch (weekday) {
      case 1:
        return 'pon';
      case 2:
        return 'uto';
      case 3:
        return 'sre';
      case 4:
        return 'cet';
      case 5:
        return 'pet';
      case 6:
        return 'sub';
      case 7:
        return 'ned';
      default:
        return 'pon';
    }
  }

  /// 🎫 Handler za BC alternativa action button - sačuva izabrani termin
  static Future<void> _handleBcAlternativaAction(NotificationResponse response) async {
    try {
      if (response.payload == null || response.actionId == null) return;

      final payloadData = jsonDecode(response.payload!) as Map<String, dynamic>;

      // Izvuci termin iz actionId (format: "prihvati_7:00")
      final termin = response.actionId!.replaceFirst('prihvati_', '');

      final putnikId = payloadData['putnikId'] as String?;
      final dan = payloadData['dan'] as String?;
      final polasciRaw = payloadData['polasci'];
      final radniDani = payloadData['radniDani'] as String?;

      if (putnikId == null || dan == null || termin.isEmpty) return;

      // Parsiraj polasci
      Map<String, dynamic> polasci = {};
      if (polasciRaw is Map) {
        polasciRaw.forEach((key, value) {
          if (value is Map) {
            polasci[key.toString()] = Map<String, dynamic>.from(value);
          }
        });
      }

      // Ažuriraj sa novim terminom
      polasci[dan] ??= <String, dynamic>{'bc': null, 'vs': null};
      (polasci[dan] as Map<String, dynamic>)['bc'] = termin;
      (polasci[dan] as Map<String, dynamic>)['bc_status'] = 'confirmed';
      (polasci[dan] as Map<String, dynamic>)['bc_resolved_at'] = DateTime.now().toUtc().toIso8601String();
      // Očisti bc_ceka_od jer je resolved
      (polasci[dan] as Map<String, dynamic>).remove('bc_ceka_od');

      // Sačuvaj u bazu
      await Supabase.instance.client.from('registrovani_putnici').update({
        'polasci_po_danu': polasci,
        if (radniDani != null) 'radni_dani': radniDani,
      }).eq('id', putnikId);

      // 📲 Pošalji push notifikaciju putniku (radi čak i kad je app zatvoren)
      await RealtimeNotificationService.sendNotificationToPutnik(
        putnikId: putnikId,
        title: '✅ Mesto osigurano!',
        body: '✅ Mesto osigurano! Vaša rezervacija za $termin je potvrđena. Želimo vam ugodnu vožnju! 🚌',
        data: {'type': 'bc_alternativa_confirmed', 'termin': termin},
      );
    } catch (e) {
      // 🔇 Ignore errors
    }
  }

  /// ⏳ Handler za "čekaj željeni termin" akcija - ostavlja pending status
  static Future<void> _handleBcCekajAction(NotificationResponse response) async {
    try {
      if (response.payload == null || response.actionId == null) return;

      final payloadData = jsonDecode(response.payload!) as Map<String, dynamic>;

      // Izvuci željeni termin iz actionId (format: "cekaj_7:00")
      final zeljeniTermin = response.actionId!.replaceFirst('cekaj_', '');

      final putnikId = payloadData['putnikId'] as String?;
      final dan = payloadData['dan'] as String?;
      final polasciRaw = payloadData['polasci'];
      final radniDani = payloadData['radniDani'] as String?;

      if (putnikId == null || dan == null || zeljeniTermin.isEmpty) return;

      // Parsiraj polasci
      Map<String, dynamic> polasci = {};
      if (polasciRaw is Map) {
        polasciRaw.forEach((key, value) {
          if (value is Map) {
            polasci[key.toString()] = Map<String, dynamic>.from(value);
          }
        });
      }

      // Postavi željeni termin sa statusom "waiting" (čeka oslobađanje)
      polasci[dan] ??= <String, dynamic>{'bc': null, 'vs': null};
      (polasci[dan] as Map<String, dynamic>)['bc'] = zeljeniTermin;
      (polasci[dan] as Map<String, dynamic>)['vs_status'] = 'waiting';

      // Sačuvaj u bazu
      await Supabase.instance.client.from('registrovani_putnici').update({
        'polasci_po_danu': polasci,
        if (radniDani != null) 'radni_dani': radniDani,
      }).eq('id', putnikId);

      // 📲 Pošalji push notifikaciju putniku (radi čak i kad je app zatvoren)
      await RealtimeNotificationService.sendNotificationToPutnik(
        putnikId: putnikId,
        title: '✅ Zahtev primljen',
        body:
            '📨 Vaš zahtev je evidentiran! Proveravamo raspoloživost mesta i javljamo vam se u najkraćem mogućem roku!',
        data: {'type': 'vs_waiting_confirmed', 'termin': zeljeniTermin},
      );
    } catch (e) {
      // 🔇 Ignore errors
    }
  }

  /// 🎫 Prikazuje notifikaciju sa alternativnim VS terminima
  /// Jedna notifikacija sa opcijama: alternativni termini ili čekanje
  static Future<void> showVsAlternativeNotification({
    required String zeljeniTermin,
    required String putnikId,
    required String dan,
    required Map<String, dynamic> polasci,
    required String radniDani,
    String? terminPre,
    String? terminPosle,
    bool isRushHourWaiting = false, // 🆕 Flag za Rush Hour poruku
  }) async {
    try {
      // Kreiraj payload sa svim podacima
      final payload = jsonEncode({
        'type': 'vs_alternativa',
        'putnikId': putnikId,
        'dan': dan,
        'zeljeniTermin': zeljeniTermin,
        'polasci': polasci,
        'radniDani': radniDani,
      });

      // Kreiraj listu akcija
      final actions = <AndroidNotificationAction>[];

      // Dodaj alternativne termine ako postoje
      if (terminPre != null) {
        actions.add(AndroidNotificationAction(
          'vs_prihvati_$terminPre',
          '✅ $terminPre',
          showsUserInterface: true,
        ));
      }

      if (terminPosle != null) {
        actions.add(AndroidNotificationAction(
          'vs_prihvati_$terminPosle',
          '✅ $terminPosle',
          showsUserInterface: true,
        ));
      }

      // Dodaj opciju za čekanje željenog termina
      // Za Rush Hour je tekst specifičan "Sačekajte [Vreme]"
      actions.add(AndroidNotificationAction(
        isRushHourWaiting ? 'vs_zadrzi_$zeljeniTermin' : 'vs_cekaj_$zeljeniTermin',
        isRushHourWaiting ? '⏳ Sačekaj $zeljeniTermin' : '⏳ Lista čekanja',
        showsUserInterface: true,
      ));

      // Dodaj opciju za odustajanje (samo ako nije Rush Hour waiting, jer tu nema odustajanja eksplicitno, oni su već na čekanju)
      if (!isRushHourWaiting) {
        actions.add(const AndroidNotificationAction(
          'vs_odustani',
          '❌ Odustani',
          cancelNotification: true,
        ));
      }

      // Kreiraj body text
      String bodyText = 'Nažalost, termin u $zeljeniTermin je popunjen 😔.';

      if (isRushHourWaiting) {
        String alternativesPart = '';
        if (terminPre != null && terminPosle != null) {
          alternativesPart = 'u $terminPre i $terminPosle';
        } else if (terminPre != null) {
          alternativesPart = 'u $terminPre';
        } else if (terminPosle != null) {
          alternativesPart = 'u $terminPosle';
        }

        if (alternativesPart.isNotEmpty) {
          // 🆕 Kraći tekst: "Obrađuje se zahtev" umesto dugog pitanja
          bodyText = 'Obrađuje se zahtev. Imate alternativu $alternativesPart.';
        } else {
          // Fallback
          bodyText = 'Obrađuje se zahtev. Proveravamo slobodna mesta...';
        }
      } else {
        if (terminPre != null || terminPosle != null) {
          final altTermini = [if (terminPre != null) terminPre, if (terminPosle != null) terminPosle];
          bodyText += ' Ali ne brinite, imamo slobodna mesta u ovim terminima: ${altTermini.join(", ")}';
        }
      }

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        isRushHourWaiting ? '⏳ Izbor termina' : '🕐 [VS] Izaberite termin',
        bodyText,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'gavra_realtime_channel',
            'Gavra Realtime Notifikacije',
            channelDescription: 'Kanal za realtime notifikacije',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableLights: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
            category: AndroidNotificationCategory.message,
            visibility: NotificationVisibility.public,
            // 🔔 KRITIČNO: Full-screen intent za lock screen (Android 10+)
            fullScreenIntent: true,
            // 🔔 Dodatne opcije za garantovano prikazivanje
            channelShowBadge: true,
            onlyAlertOnce: false,
            autoCancel: true,
            ongoing: false,
            styleInformation: BigTextStyleInformation(
              bodyText, // Omogućava više redova teksta
              contentTitle: isRushHourWaiting ? '⏳ Izbor termina' : '🕐 [VS] Izaberite termin',
            ),
            actions: actions,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      // 🔇 Ignore
    }
  }

  /// 🎫 Handler za VS alternativa action button
  static Future<void> _handleVsAlternativaAction(NotificationResponse response) async {
    try {
      if (response.payload == null || response.actionId == null) return;

      final payloadData = jsonDecode(response.payload!) as Map<String, dynamic>;

      // Izvuci termin iz actionId (format: "vs_prihvati_7:00")
      final termin = response.actionId!.replaceFirst('vs_prihvati_', '');

      final putnikId = payloadData['putnikId'] as String?;
      final dan = payloadData['dan'] as String?;
      final polasciRaw = payloadData['polasci'];
      final radniDani = payloadData['radniDani'] as String?;

      if (putnikId == null || dan == null || termin.isEmpty) return;

      // Parsiraj polasci
      Map<String, dynamic> polasci = {};
      if (polasciRaw is Map) {
        polasciRaw.forEach((key, value) {
          if (value is Map) {
            polasci[key.toString()] = Map<String, dynamic>.from(value);
          }
        });
      }

      // Ažuriraj sa novim terminom
      polasci[dan] ??= <String, dynamic>{'bc': null, 'vs': null};
      (polasci[dan] as Map<String, dynamic>)['vs'] = termin;
      (polasci[dan] as Map<String, dynamic>)['vs_status'] = 'confirmed';
      (polasci[dan] as Map<String, dynamic>)['vs_resolved_at'] = DateTime.now().toUtc().toIso8601String();
      // Očisti vs_ceka_od jer je resolved
      (polasci[dan] as Map<String, dynamic>).remove('vs_ceka_od');

      // Sačuvaj u bazu
      await Supabase.instance.client.from('registrovani_putnici').update({
        'polasci_po_danu': polasci,
        if (radniDani != null) 'radni_dani': radniDani,
      }).eq('id', putnikId);

      // 📲 Pošalji push notifikaciju putniku (radi čak i kad je app zatvoren)
      await RealtimeNotificationService.sendNotificationToPutnik(
        putnikId: putnikId,
        title: '✅ [VS] Termin potvrđen',
        body: '✅ Mesto osigurano! Vaša rezervacija za $termin je potvrđena. Želimo vam ugodnu vožnju! 🚌',
        data: {'type': 'vs_alternativa_confirmed', 'termin': termin},
      );
    } catch (e) {
      // 🔇 Ignore
    }
  }

  /// ⏳ Handler za VS "čekaj željeni termin"
  static Future<void> _handleVsCekajAction(NotificationResponse response) async {
    try {
      if (response.payload == null || response.actionId == null) return;

      final payloadData = jsonDecode(response.payload!) as Map<String, dynamic>;

      // Izvuci željeni termin iz actionId (format: "vs_cekaj_7:00")
      final zeljeniTermin = response.actionId!.replaceFirst('vs_cekaj_', '');

      final putnikId = payloadData['putnikId'] as String?;
      final dan = payloadData['dan'] as String?;
      final polasciRaw = payloadData['polasci'];
      final radniDani = payloadData['radniDani'] as String?;

      if (putnikId == null || dan == null || zeljeniTermin.isEmpty) return;

      // Parsiraj polasci
      Map<String, dynamic> polasci = {};
      if (polasciRaw is Map) {
        polasciRaw.forEach((key, value) {
          if (value is Map) {
            polasci[key.toString()] = Map<String, dynamic>.from(value);
          }
        });
      }

      // Postavi željeni termin sa statusom "waiting"
      polasci[dan] ??= <String, dynamic>{'bc': null, 'vs': null};
      (polasci[dan] as Map<String, dynamic>)['vs'] = zeljeniTermin;
      (polasci[dan] as Map<String, dynamic>)['vs_status'] = 'waiting';

      // Sačuvaj u bazu
      await Supabase.instance.client.from('registrovani_putnici').update({
        'polasci_po_danu': polasci,
        if (radniDani != null) 'radni_dani': radniDani,
      }).eq('id', putnikId);

      // 📲 Pošalji push notifikaciju putniku (radi čak i kad je app zatvoren)
      await RealtimeNotificationService.sendNotificationToPutnik(
        putnikId: putnikId,
        title: '✅ Zahtev primljen',
        body:
            '📨 Vaš zahtev je evidentiran! Proveravamo raspoloživost mesta i javljamo vam se u najkraćem mogućem roku!',
        data: {'type': 'vs_waiting_confirmed', 'termin': zeljeniTermin},
      );
    } catch (e) {
      // 🔇 Ignore
    }
  }

  /// ⏳ Handler za VS "zadrži čekanje"
  static Future<void> _handleVsZadrziAction(NotificationResponse response) async {
    try {
      if (response.payload == null || response.actionId == null) return;

      final payloadData = jsonDecode(response.payload!) as Map<String, dynamic>;

      // Izvuci željeni termin iz actionId (format: "vs_zadrzi_7:00")
      final zeljeniTermin = response.actionId!.replaceFirst('vs_zadrzi_', '');

      final putnikId = payloadData['putnikId'] as String?;
      final dan = payloadData['dan'] as String?;
      final polasciRaw = payloadData['polasci'];
      final radniDani = payloadData['radniDani'] as String?;

      if (putnikId == null || dan == null || zeljeniTermin.isEmpty) return;

      // Parsiraj polasci
      Map<String, dynamic> polasci = {};
      if (polasciRaw is Map) {
        polasciRaw.forEach((key, value) {
          if (value is Map) {
            polasci[key.toString()] = Map<String, dynamic>.from(value);
          }
        });
      }

      // Potvrdi status 'ceka_mesto' (za svaki slučaj)
      polasci[dan] ??= <String, dynamic>{'bc': null, 'vs': null};
      (polasci[dan] as Map<String, dynamic>)['vs'] = zeljeniTermin;
      (polasci[dan] as Map<String, dynamic>)['vs_status'] = 'ceka_mesto';

      // Sačuvaj u bazu
      await Supabase.instance.client.from('registrovani_putnici').update({
        'polasci_po_danu': polasci,
        if (radniDani != null) 'radni_dani': radniDani,
      }).eq('id', putnikId);

      // 📲 Pošalji push notifikaciju putniku (radi čak i kad je app zatvoren)
      await RealtimeNotificationService.sendNotificationToPutnik(
        putnikId: putnikId,
        title: '✅ Zahtev primljen',
        body:
            '📨 Vaš zahtev je evidentiran! Proveravamo raspoloživost mesta i javljamo vam se u najkraćem mogućem roku!',
        data: {'type': 'vs_ceka_mesto_confirmed', 'termin': zeljeniTermin},
      );
    } catch (e) {
      // 🔇 Ignore
    }
  }
}
