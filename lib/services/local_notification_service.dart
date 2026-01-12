import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/registrovani_putnik.dart';
import '../screens/danas_screen.dart';
import 'notification_navigation_service.dart';
import 'seat_request_service.dart';
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

      // 🎯 Handle seat_choice notifikacije posebno - prikaži dialog za izbor
      if (notificationType == 'seat_choice' && response.payload != null) {
        try {
          final payloadData = jsonDecode(response.payload!) as Map<String, dynamic>;
          if (context.mounted) {
            await _showSeatChoiceDialog(
              context: context,
              requestId: payloadData['requestId'] as String,
              zeljenoVreme: payloadData['zeljenoVreme'] as String,
              ranijaAlternativa: payloadData['ranijaAlternativa'] as String?,
              kasnijaAlternativa: payloadData['kasnijaAlternativa'] as String?,
            );
          }
          return; // Ne navigiraj dalje
        } catch (e) {
          print('❌ Greška pri prikazivanju izbora: $e');
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

  // ═══════════════════════════════════════════════════════════════════════
  // 🎯 SEAT CHOICE DIALOG - Putnik bira alternativu
  // ═══════════════════════════════════════════════════════════════════════

  /// Prikaži dialog za izbor alternativnog termina
  static Future<void> _showSeatChoiceDialog({
    required BuildContext context,
    required String requestId,
    required String zeljenoVreme,
    String? ranijaAlternativa,
    String? kasnijaAlternativa,
  }) async {
    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.access_time, color: Colors.orange.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Termin popunjen',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.grey.shade800, fontSize: 15),
                children: [
                  const TextSpan(text: 'Termin '),
                  TextSpan(
                    text: zeljenoVreme,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' je popunjen.\nIzaberi opciju:'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Opcije
            if (ranijaAlternativa != null)
              _buildChoiceOption(
                context: context,
                icon: Icons.arrow_back,
                color: Colors.blue,
                title: 'Raniji termin',
                subtitle: ranijaAlternativa,
                onTap: () => Navigator.of(context).pop(ranijaAlternativa),
              ),

            if (kasnijaAlternativa != null) ...[
              const SizedBox(height: 10),
              _buildChoiceOption(
                context: context,
                icon: Icons.arrow_forward,
                color: Colors.green,
                title: 'Kasniji termin',
                subtitle: kasnijaAlternativa,
                onTap: () => Navigator.of(context).pop(kasnijaAlternativa),
              ),
            ],

            const SizedBox(height: 10),
            _buildChoiceOption(
              context: context,
              icon: Icons.hourglass_empty,
              color: Colors.orange,
              title: 'Čekaj $zeljenoVreme',
              subtitle: 'Javićemo ti ako se oslobodi',
              onTap: () => Navigator.of(context).pop(null), // null = waitlist
            ),
          ],
        ),
      ),
    );

    // Procesira izbor
    if (result != null || result == null) {
      final success = await SeatRequestService.chooseAlternative(
        requestId: requestId,
        izabranoVreme: result, // null = čekaj originalni
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (result != null ? '✅ Rezervisano za $result' : '⏳ Na listi čekanja za $zeljenoVreme')
                  : '❌ Greška pri izboru',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  /// Gradi opciju za izbor
  static Widget _buildChoiceOption({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color.withValues(alpha: 0.8),
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
