import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/registrovani_putnik.dart';
import '../screens/home_screen.dart';
import '../supabase_client.dart';
import 'notification_navigation_service.dart';
import 'realtime_notification_service.dart';
import 'seat_request_service.dart';
import 'voznje_log_service.dart';
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
  static final Map<String, bool> _processingLocks = {}; // 🔒 Lock za deduplikaciju
  static const Duration _dedupeDuration = Duration(seconds: 30);

  static Future<void> initialize(BuildContext context) async {
    // 📸 SCREENSHOT MODE - preskoči inicijalizaciju notifikacija
    const isScreenshotMode = bool.fromEnvironment('SCREENSHOT_MODE', defaultValue: false);
    if (isScreenshotMode) {
      return;
    }

    try {
      await flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('❌ [LocalNotif] Failed to clear notifications: $e');
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

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
    String dedupeKey = ''; // 🔑 Premesteno izvan try-catch da bude dostupno u finally bloku

    try {
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
        // fallback: simple hash of title+body (ignoring payload which may contain timestamps)
        // Ovo rešava problem duplih notifikacija kada backend stavi timestamp u payload.
        dedupeKey = '$title|$body';
      }

      // 🔒 MUTEX LOCK - Sprečava race condition kada Firebase i Huawei primaju istu notifikaciju istovremeno
      if (_processingLocks[dedupeKey] == true) {
        return; // Druga instanca već obrađuje ovu notifikaciju
      }
      _processingLocks[dedupeKey] = true;

      final now = DateTime.now();
      if (_recentNotificationIds.containsKey(dedupeKey)) {
        final last = _recentNotificationIds[dedupeKey]!;
        if (now.difference(last) < _dedupeDuration) {
          _processingLocks.remove(dedupeKey); // 🔓 Oslobodi lock
          return;
        }
      }
      _recentNotificationIds[dedupeKey] = now;
      _recentNotificationIds.removeWhere((k, v) => now.difference(v) > _dedupeDuration);

      // 📱 Pali ekran kada stigne notifikacija (za lock screen)
      try {
        await WakeLockService.wakeScreen(durationMs: 5000);
      } catch (e) {
        debugPrint('⚠️ Error waking screen: $e');
      }

      // 🎨 Specijalna obrada za seat_request_alternatives
      if (payload != null) {
        try {
          final Map<String, dynamic> data = jsonDecode(payload);
          if (data['type'] == 'seat_request_alternatives') {
            // 🛡️ PARSIRANJE ALTERNATIVA: Može biti List<String> ili String "[...]"
            List<String> parsedAlts = [];
            final rawAlts = data['alternatives'];
            if (rawAlts is List) {
              parsedAlts = rawAlts.map((e) => e.toString()).toList();
            } else if (rawAlts is String && rawAlts.startsWith('[') && rawAlts.endsWith(']')) {
              try {
                final cleaned = rawAlts.substring(1, rawAlts.length - 1);
                parsedAlts = cleaned.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              } catch (e) {
                debugPrint('⚠️ Error parsing stringified alternatives: $e');
              }
            }

            await showSeatRequestAlternativesNotification(
              id: data['id']?.toString() ?? '',
              zeljenoVreme: data['vreme']?.toString() ?? '',
              putnikId: data['putnik_id']?.toString() ?? '',
              grad: data['grad']?.toString() ?? 'BC',
              datum: data['datum']?.toString() ?? '',
              alternatives: parsedAlts,
              body: body,
            );
            _processingLocks.remove(dedupeKey);
            return;
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing payload for alternatives: $e');
        }
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

      // 🔓 Oslobodi lock nakon uspešnog slanja
      _processingLocks.remove(dedupeKey);
    } catch (e) {
      // 🔓 Oslobodi lock i u slučaju greške
      _processingLocks.remove(dedupeKey);
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
            'Trenutno nema slobodnih mesta za $zeljeniTermin. Ali ne brinite, imamo mesta u ovim terminima: ${altTermini.join(", ")}';
      } else {
        bodyText =
            'Trenutno nema slobodnih mesta za $zeljeniTermin. Nažalost, nemamo dostupnih polazaka u blizini tog vremena. ❌';
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
    String dedupeKey = ''; // 🔑 Premesteno izvan try-catch za finally blok

    try {
      if (payload != null && payload.isNotEmpty) {
        try {
          final Map<String, dynamic> data = jsonDecode(payload);

          // 🎨 SPECIJALNA OBRADA ZA ALTERNATIVE U POZADINI
          if (data['type'] == 'seat_request_alternatives') {
            // 🛡️ PARSIRANJE ALTERNATIVA: Može biti List<String> ili String "[...]"
            List<String> parsedAlts = [];
            final rawAlts = data['alternatives'];
            if (rawAlts is List) {
              parsedAlts = rawAlts.map((e) => e.toString()).toList();
            } else if (rawAlts is String && rawAlts.startsWith('[') && rawAlts.endsWith(']')) {
              try {
                final cleaned = rawAlts.substring(1, rawAlts.length - 1);
                parsedAlts = cleaned.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              } catch (e) {
                debugPrint('⚠️ Error parsing stringified alternatives: $e');
              }
            }

            await showSeatRequestAlternativesNotification(
              id: data['id']?.toString() ?? '',
              zeljenoVreme: data['vreme']?.toString() ?? '',
              putnikId: data['putnik_id']?.toString() ?? '',
              grad: data['grad']?.toString() ?? 'BC',
              datum: data['datum']?.toString() ?? '',
              alternatives: parsedAlts,
              body: body,
            );
            return; // Već je prikazana specijalna notifikacija
          }

          if (data['notification_id'] != null) {
            dedupeKey = data['notification_id'].toString();
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing background payload: $e');
        }
      }

      if (dedupeKey.isEmpty) dedupeKey = '$title|$body|${payload ?? ''}';

      // 🔒 MUTEX LOCK - Sprečava race condition kada foreground i background handleri rade istovremeno
      if (_processingLocks[dedupeKey] == true) {
        return; // Druga instanca već obrađuje ovu notifikaciju
      }
      _processingLocks[dedupeKey] = true;

      final now = DateTime.now();
      if (_recentNotificationIds.containsKey(dedupeKey)) {
        final last = _recentNotificationIds[dedupeKey]!;
        if (now.difference(last) < _dedupeDuration) {
          _processingLocks.remove(dedupeKey); // 🔓 Oslobodi lock
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

      await plugin.initialize(
        initializationSettings,
      );

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

      // 🔓 Oslobodi lock nakon uspešnog slanja
      _processingLocks.remove(dedupeKey);
    } catch (e) {
      // 🔓 Oslobodi lock i u slučaju greške
      _processingLocks.remove(dedupeKey);
    }
  }

  static Future<void> handleNotificationTap(
    NotificationResponse response,
  ) async {
    try {
      // 🎫 Handle Seat Request alternativa action buttons
      if (response.actionId != null && response.actionId!.startsWith('prihvati_alt_')) {
        await _handleSeatRequestAlternativeAction(response);
        return;
      }

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

          // 🛠️ FIX: Assign notificationType from payload
          notificationType = payloadData['type'] as String?;

          // 🎫 BC/VS alternativa ili Seat Request - otvori profil
          if (notificationType == 'bc_alternativa' ||
              notificationType == 'vs_alternativa' ||
              notificationType == 'seat_request_alternatives' ||
              notificationType == 'seat_request_approved' ||
              notificationType == 'seat_request_rejected') {
            await NotificationNavigationService.navigateToPassengerProfile();
            return;
          }

          // 🔐 PIN zahtev ili Manual Seat Request - otvori PIN zahtevi ekran (Admin/Vozac screen)
          if (notificationType == 'pin_zahtev' || notificationType == 'seat_request_manual') {
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
            builder: (context) => const HomeScreen(),
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
            builder: (context) => const HomeScreen(),
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

      // Dohvati tip korisnika za precizan log
      final putnikData =
          await supabase.from('registrovani_putnici').select('tip').eq('id', putnikId).limit(1).maybeSingle();
      final userType = putnikData?['tip'] ?? 'Putnik';

      // Sačuvaj u bazu
      await supabase.from('registrovani_putnici').update({
        'polasci_po_danu': polasci,
        if (radniDani != null) 'radni_dani': radniDani,
      }).eq('id', putnikId);

      // 📝 LOG U DNEVNIK
      try {
        await VoznjeLogService.logPotvrda(
          putnikId: putnikId,
          dan: dan,
          vreme: termin,
          grad: 'bc',
          tipPutnika: userType,
          detalji: 'Prihvaćen alternativni termin (Preko notifikacije)',
        );
      } catch (e) {
        debugPrint('⚠️ Error logging BC alternative: $e');
      }

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

      // Dohvati tip korisnika za precizan log
      final putnikResult =
          await supabase.from('registrovani_putnici').select('tip').eq('id', putnikId).limit(1).maybeSingle();
      final userType = putnikResult?['tip'] ?? 'Putnik';

      // Sačuvaj u bazu
      await supabase.from('registrovani_putnici').update({
        'polasci_po_danu': polasci,
        if (radniDani != null) 'radni_dani': radniDani,
      }).eq('id', putnikId);

      // 📝 LOG U DNEVNIK
      try {
        await VoznjeLogService.logPotvrda(
          putnikId: putnikId,
          dan: dan,
          vreme: termin,
          grad: 'vs',
          tipPutnika: userType,
          detalji: 'Prihvaćen alternativni termin (Preko notifikacije)',
        );
      } catch (e) {
        debugPrint('⚠️ Error logging VS alternative: $e');
      }

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

  /// 🎫 Prikazuje notifikaciju sa alternativnim polascima (+/- 3 sata)
  static Future<void> showSeatRequestAlternativesNotification({
    required String id,
    required String zeljenoVreme,
    required String putnikId,
    required String grad,
    required String datum,
    required List<String> alternatives,
    required String body,
  }) async {
    try {
      final payload = jsonEncode({
        'type': 'seat_request_alternatives',
        'id': id,
        'putnik_id': putnikId,
        'grad': grad,
        'zeljenoVreme': zeljenoVreme,
        'datum': datum,
        'alternatives': alternatives,
      });

      final actions = <AndroidNotificationAction>[];

      // Dodaj prve dve alternative kao dugmiće
      for (int i = 0; i < alternatives.length && i < 2; i++) {
        final alt = alternatives[i];
        final displayTime = alt.contains(':') ? '${alt.split(':')[0]}:${alt.split(':')[1]}' : alt;
        actions.add(AndroidNotificationAction(
          'prihvati_alt_$alt',
          '✅ $displayTime',
          showsUserInterface: true,
        ));
      }

      // Dugme za odbijanje (zatvaranje)
      actions.add(const AndroidNotificationAction(
        'odbij_alt',
        '❌ Odbij',
        cancelNotification: true,
      ));

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '🕐 Termin popunjen',
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'gavra_realtime_channel',
            'Gavra Realtime Notifikacije',
            channelDescription: 'Kanal za realtime notifikacije sa alternativama',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
            actions: actions,
            fullScreenIntent: true,
            autoCancel: true,
            category: AndroidNotificationCategory.message,
            visibility: NotificationVisibility.public,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('❌ Error showing seat request alternatives notification: $e');
    }
  }

  static Future<void> _handleSeatRequestAlternativeAction(NotificationResponse response) async {
    try {
      if (response.payload == null || response.actionId == null) return;
      final data = jsonDecode(response.payload!);
      final requestId = data['id']?.toString(); // 🆔 ID originalnog zahteva koji je odbijen
      final putnikId = data['putnik_id'];
      final grad = data['grad'] ?? 'BC';
      final datum = data['datum'];

      final selectedTime = response.actionId!.replaceFirst('prihvati_alt_', '');

      // 🚀 PRIHVATI ALTERNATIVU - Sada je ODMAH ODOBRENO bez ponovnog čekanja
      await SeatRequestService.acceptAlternative(
        requestId: requestId,
        putnikId: putnikId,
        novoVreme: selectedTime,
        grad: grad,
        datum: datum,
      );
    } catch (e) {
      debugPrint('❌ Error handling seat request alternative action: $e');
    }
  }
}
