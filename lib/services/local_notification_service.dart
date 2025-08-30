import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../main.dart';
import '../screens/danas_screen.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static Future<void> initialize(BuildContext context) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
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
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Request permissions
    await _requestPermissions();
  }

  static Future<void> _requestPermissions() async {
    // Request notification permission using flutter_local_notifications
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Request only notification permission using permission_handler
    try {
      // Request notification permission
      await Permission.notification.request();
    } catch (e) {
      // Ignorišemo greške sa permission zahtevima
    }
  }

  /// Prikaz realtime notifikacije sa popup, zvuk i lock screen
  static Future<void> showRealtimeNotification({
    required String title,
    required String body,
    String? payload,
    bool playCustomSound = true,
  }) async {
    try {
      // 1. Prvo pusti custom zvuk
      if (playCustomSound) {
        await _playNotificationSound();
      }

      // 2. Vibracija da privuče pažnju
      await HapticFeedback.heavyImpact();

      // 3. Prikaz heads-up notifikacije
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000), // Unique ID
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'gavra_realtime_channel',
            'Gavra Realtime Notifikacije',
            channelDescription:
                'Kanal za realtime heads-up notifikacije sa zvukom',
            importance: Importance.max,
            priority: Priority.high,
            playSound: false, // Mi ćemo custom zvuk
            enableVibration: true,
            enableLights: true,
            showWhen: true,
            when: DateTime.now().millisecondsSinceEpoch,
            fullScreenIntent: true, // Za lock screen
            category: AndroidNotificationCategory.call, // Visok prioritet
            visibility: NotificationVisibility.public, // Prikaži na lock screen
            autoCancel: true,
            ongoing: false,
            showProgress: false,
            ticker: '$title - $body',
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            styleInformation: BigTextStyleInformation(
              body,
              htmlFormatBigText: true,
              contentTitle: title,
              htmlFormatContentTitle: true,
              summaryText: 'Gavra Transport',
              htmlFormatSummaryText: true,
            ),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: false, // Mi ćemo custom zvuk
            sound: null,
            badgeNumber: 1,
            threadIdentifier: 'gavra_realtime',
            categoryIdentifier: 'gavra_category',
            interruptionLevel: InterruptionLevel.critical, // Za lock screen
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      // Ignorišemo greške sa prikazivanjem notifikacija
    }
  }

  /// Pusti custom gavra.mp3 zvuk
  static Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.setAsset('assets/gavra.mp3');
      await _audioPlayer.setVolume(1.0); // Maksimalna glasnoća
      await _audioPlayer.play();
    } catch (e) {
      // Ignorišemo greške sa reprodukcijom zvuka
    }
  }

  /// Handle notification tap - navigate to passenger with filters
  static Future<void> _handleNotificationTap(
      NotificationResponse response) async {
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
          final Map<String, dynamic> payloadData =
              jsonDecode(response.payload!);

          notificationType = payloadData['type'];
          final putnikData = payloadData['putnik'];

          // Extract passenger name from different possible formats
          if (putnikData is Map<String, dynamic>) {
            putnikIme = putnikData['ime'] ?? putnikData['name'];
            putnikGrad = putnikData['grad'];
            putnikVreme = putnikData['vreme'] ?? putnikData['polazak'];
          } else if (putnikData is String) {
            // Try to parse if it's JSON string
            try {
              final putnikMap = jsonDecode(putnikData);
              if (putnikMap is Map<String, dynamic>) {
                putnikIme = putnikMap['ime'] ?? putnikMap['name'];
                putnikGrad = putnikMap['grad'];
                putnikVreme = putnikMap['vreme'] ?? putnikMap['polazak'];
              }
            } catch (e) {
              // If not JSON, use as direct string
              putnikIme = putnikData;
            }
          }

          // 🔍 DOHVATI PUTNIK PODATKE IZ BAZE ako nisu u payload-u
          if (putnikIme != null &&
              (putnikGrad == null || putnikVreme == null)) {
            try {
              final putnikInfo = await _fetchPutnikFromDatabase(putnikIme);
              if (putnikInfo != null) {
                putnikGrad = putnikGrad ?? putnikInfo['grad'];
                putnikVreme = putnikVreme ??
                    putnikInfo['polazak'] ??
                    putnikInfo['vreme_polaska'];
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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DanasScreen(
            highlightPutnikIme: putnikIme,
            filterGrad: putnikGrad,
            filterVreme: putnikVreme,
          ),
        ),
      );

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
                    child: Text(message,
                        style: const TextStyle(color: Colors.white))),
              ],
            ),
            backgroundColor: bgColor,
            duration: const Duration(seconds: 4),
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
      if (context != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
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
      playCustomSound: true,
    );
  }

  /// Očisti sve notifikacije
  static Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Dispose audio player
  static Future<void> dispose() async {
    await _audioPlayer.dispose();
  }

  /// 🔍 FETCH PUTNIK DATA FROM DATABASE BY NAME
  static Future<Map<String, dynamic>?> _fetchPutnikFromDatabase(
      String putnikIme) async {
    try {
      final supabase = Supabase.instance.client;

      // Traži u putovanja_istorija tabeli (dnevni putnici)
      final dnevniResult = await supabase
          .from('putovanja_istorija')
          .select('putnik_ime, grad, vreme_polaska, dan, polazak')
          .eq('putnik_ime', putnikIme)
          .eq('obrisan', false)
          .order('created_at', ascending: false)
          .limit(1);

      if (dnevniResult.isNotEmpty) {
        final data = dnevniResult.first;
        return {
          'grad': data['grad'],
          'polazak': data['vreme_polaska'] ?? data['polazak'],
          'dan': data['dan'],
          'tip': 'dnevni'
        };
      }

      // Traži u mesecni_putnici tabeli
      final mesecniResult = await supabase
          .from('mesecni_putnici')
          .select('putnik_ime, grad, polazak, dan')
          .eq('putnik_ime', putnikIme)
          .eq('aktivan', true)
          .eq('obrisan', false)
          .order('created_at', ascending: false)
          .limit(1);

      if (mesecniResult.isNotEmpty) {
        final data = mesecniResult.first;
        return {
          'grad': data['grad'],
          'polazak': data['polazak'],
          'dan': data['dan'],
          'tip': 'mesecni'
        };
      }

      return null;
    } catch (e) {
      // Return null on error - fallback to basic navigation
      return null;
    }
  }
}
