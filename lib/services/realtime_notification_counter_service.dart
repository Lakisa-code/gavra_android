import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';

/// 🔔 REAL-TIME NOTIFICATION COUNTER SERVICE
class RealtimeNotificationCounterService {
  static final _notificationCountController = StreamController<int>.broadcast();
  static int _unreadCount = 0;

  /// 🔔 STREAM BROJAČA NOTIFIKACIJA
  static Stream<int> get notificationCountStream =>
      _notificationCountController.stream;

  /// 📊 TRENUTNI BROJ NEPROČITANIH
  static int get unreadCount => _unreadCount;

  /// 🔔 INITIALIZE NOTIFICATION COUNTING
  static void initialize() {
    // Slušaj foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _incrementCount();
    });

    // Slušaj background messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _decrementCount(); // Notifikacija je otvorena, smanji broj
    });
  }

  /// ⬆️ POVEĆAJ BROJ NOTIFIKACIJA
  static void _incrementCount() {
    _unreadCount++;
    _notificationCountController.add(_unreadCount);
  }

  /// ⬇️ SMANJI BROJ NOTIFIKACIJA
  static void _decrementCount() {
    if (_unreadCount > 0) {
      _unreadCount--;
      _notificationCountController.add(_unreadCount);
    }
  }

  /// 🗑️ OZNAČI SVE KAO PROČITANE
  static void markAllAsRead() {
    _unreadCount = 0;
    _notificationCountController.add(_unreadCount);
  }

  /// 🔔 RUČNO DODAJ NOTIFIKACIJU
  static void addNotification() {
    _incrementCount();
  }

  /// 🛑 DISPOSE RESOURCES
  static void dispose() {
    _notificationCountController.close();
  }
}
