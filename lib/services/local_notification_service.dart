import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/registrovani_putnik.dart';
import '../screens/danas_screen.dart';
import 'supabase_safe.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Recent notifications cache to prevent duplicates (notification_id or hash)
  static final Map<String, DateTime> _recentNotificationIds = {};
  static const Duration _dedupeDuration = Duration(seconds: 30);

  static Future<void> initialize(BuildContext context) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap - navigate to today screen
        _handleNotificationTap(response);
      },
    );

    // Kreiraj kanal za heads-up notifikacije sa visokim prioritetom
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'gavra_realtime_channel',
      'Gavra Realtime Notifikacije',
      description: 'Kanal za realtime heads-up notifikacije sa zvukom',
      importance: Importance.max,
      enableLights: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Permission requests are handled by RealtimeNotificationService
    // to avoid conflicts - no local permission requests here
  }

  /// Prikaz realtime notifikacije sa popup, zvuk i lock screen
  static Future<void> showRealtimeNotification({
    required String title,
    required String body,
    String? payload,
    bool playCustomSound = false, // 🔇 ONEMOGUĆENO: Custom zvuk ne radi
  }) async {
    try {
      // Deduplicate based on payload id or title+body
      String dedupeKey = '';
      try {
        if (payload != null && payload.isNotEmpty) {
          final Map<String, dynamic> parsed = jsonDecode(payload);
          if (parsed['notification_id'] != null) {
            dedupeKey = parsed['notification_id'].toString();
          }
        }
      } catch (e) {
        // ignore
      }
      if (dedupeKey.isEmpty) {
        // fallback: simple hash of title+body+payload
        dedupeKey = '$title|$body|${payload ?? ''}';
      }
      // Check cache
      final now = DateTime.now();
      if (_recentNotificationIds.containsKey(dedupeKey)) {
        final last = _recentNotificationIds[dedupeKey]!;
        if (now.difference(last) < _dedupeDuration) {
          // Duplicate - ignore
          return;
        }
      }
      _recentNotificationIds[dedupeKey] = now;
      // Clean up old entries
      _recentNotificationIds.removeWhere((k, v) => now.difference(v) > _dedupeDuration);
      // 1. Preskoči custom zvuk - koristi sistemski
      // if (playCustomSound) {
      //   await _playNotificationSound(); // 🔇 ONEMOGUĆENO
      // }

      // 2. Vibracija da privuče pažnju
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000), // Unique ID
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'gavra_realtime_channel',
            'Gavra Realtime Notifikacije',
            channelDescription: 'Kanal za realtime heads-up notifikacije sa zvukom',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true, // 🔊 SISTEMSKI ZVUK umesto custom MP3
            enableLights: true,
            when: DateTime.now().millisecondsSinceEpoch,
            fullScreenIntent: true, // Za lock screen
            category: AndroidNotificationCategory.call, // Visok prioritet
            visibility: NotificationVisibility.public, // Prikaži na lock screen
            ticker: '$title - $body',
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            styleInformation: BigTextStyleInformation(
              body,
              htmlFormatBigText: true,
              contentTitle: title,
              htmlFormatContentTitle: true,
              summaryText: 'Gavra 013',
              htmlFormatSummaryText: true,
            ),
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      // Ignorišemo greške sa prikazivanjem notifikacija
    }
  }

  /// Background-safe helper to show a local notification from a background isolate
  /// This creates a fresh FlutterLocalNotificationsPlugin instance and shows a
  /// basic notification. Avoids UI and audio playback (audio not supported in background isolate).
  static Future<void> showNotificationFromBackground({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      // Deduplicate similar logic by payload or hash
      String dedupeKey = '';
      try {
        if (payload != null && payload.isNotEmpty) {
          final Map<String, dynamic> parsed = jsonDecode(payload);
          if (parsed['notification_id'] != null) {
            dedupeKey = parsed['notification_id'].toString();
          }
        }
      } catch (e) {
        // ignore parse errors
      }
      if (dedupeKey.isEmpty) dedupeKey = '$title|$body|${payload ?? ''}';
      final now = DateTime.now();
      if (_recentNotificationIds.containsKey(dedupeKey)) {
        final last = _recentNotificationIds[dedupeKey]!;
        if (now.difference(last) < _dedupeDuration) {
          return; // duplicate
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

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'gavra_realtime_channel',
        'Gavra Realtime Notifikacije',
        channelDescription: 'Kanal za realtime heads-up notifikacije sa zvukom',
        importance: Importance.max,
        priority: Priority.high,
        playSound: false,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidDetails,
      );

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

  /// Handle notification tap - navigate to passenger with filters
  static Future<void> _handleNotificationTap(
    NotificationResponse response,
  ) async {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      // Parse payload to get passenger info
      String? putnikIme;
      String? notificationType;
      String? putnikGrad;
      String? putnikVreme;

      if (response.payload != null) {
        try {
          // Parse the payload JSON
          final Map<String, dynamic> payloadData = jsonDecode(response.payload!) as Map<String, dynamic>;

          notificationType = payloadData['type'] as String?;
          final putnikData = payloadData['putnik'];

          // Extract passenger name from different possible formats
          if (putnikData is Map<String, dynamic>) {
            putnikIme = (putnikData['ime'] ?? putnikData['name']) as String?;
            putnikGrad = putnikData['grad'] as String?;
            putnikVreme = (putnikData['vreme'] ?? putnikData['polazak']) as String?;
          } else if (putnikData is String) {
            // Try to parse if it's JSON string
            try {
              final putnikMap = jsonDecode(putnikData);
              if (putnikMap is Map<String, dynamic>) {
                putnikIme = (putnikMap['ime'] ?? putnikMap['name']) as String?;
                putnikGrad = putnikMap['grad'] as String?;
                putnikVreme = (putnikMap['vreme'] ?? putnikMap['polazak']) as String?;
              }
            } catch (e) {
              // If not JSON, use as direct string
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
              // Ignore database fetch errors - fallback to basic navigation
            }
          }
        } catch (e) {
          // If payload parsing fails, fall back to simple navigation
        }
      }

      // Navigate to dagens screen with filter parameters
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

      // Show info about the passenger if available
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

        // Show snackbar with passenger info
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
      // Error handling notification tap - fallback to simple navigation
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

  /// Legacy metoda za kompatibilnost
  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    await showRealtimeNotification(
      title: title,
      body: body,
    );
  }

  /// Očisti sve notifikacije
  static Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// 🔍 FETCH PUTNIK DATA FROM DATABASE BY NAME
  static Future<Map<String, dynamic>?> _fetchPutnikFromDatabase(
    String putnikIme,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // Traži u putovanja_istorija tabeli (dnevni putnici)
      final dnevniResult = await SupabaseSafe.run(
        () => supabase
            .from('putovanja_istorija')
            .select('putnik_ime, grad, vreme_polaska, dan, polazak')
            .eq('putnik_ime', putnikIme)
            .eq('obrisan', false)
            .order('created_at', ascending: false)
            .limit(1),
        fallback: <dynamic>[],
      );

      if (dnevniResult is List && dnevniResult.isNotEmpty) {
        final data = dnevniResult.first;
        return {
          'grad': data['grad'],
          'polazak': data['vreme_polaska'] ?? data['polazak'],
          'dan': data['dan'],
          'tip': 'dnevni',
        };
      }

      // Traži u registrovani_putnici tabeli
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

        // Preuzmi trenutni dan i određi polazak
        final sada = DateTime.now();
        final danNedelje = _getDanNedelje(sada.weekday);

        String? polazak;
        String? grad;

        // Pokušaj da nađeš polazak za trenutni dan
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
            'tip': 'mesecni',
          };
        }
      }

      return null;
    } catch (e) {
      // Return null on error - fallback to basic navigation
      return null;
    }
  }

  // Helper metoda za formatiranje dana nedelje
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
