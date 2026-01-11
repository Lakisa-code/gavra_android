import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/registrovani_putnik.dart';
import '../screens/danas_screen.dart';
import 'wake_lock_service.dart';

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
        _handleNotificationTap(response);
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'gavra_realtime_channel',
      'Gavra Realtime Notifikacije',
      description: 'Kanal za realtime heads-up notifikacije sa zvukom',
      importance: Importance.max,
      enableLights: true,
      enableVibration: true,
      playSound: true,
    );

    final androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(channel);
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

  static Future<void> _handleNotificationTap(
    NotificationResponse response,
  ) async {
    try {
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
}
