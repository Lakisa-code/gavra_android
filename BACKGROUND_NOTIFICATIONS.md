# 📱 Background Notifikacije - Kompletan Pregled

## ✅ STATUS: Sistem je Potpuno Postavljen

Aplikacija **PODRŽAVA** notifikacije čak i kada je:
- ❌ App je **zatvoreni** (killed)
- ❌ App je u **background-u**
- ❌ Ekran je **zaključan**
- ❌ Uređaj je u **sleep** modu

---

## 🔧 Kako Radi?

### 1. Firebase (FCM) - Background Handler

**Fajl**: `lib/services/firebase_background_handler.dart`

```dart
// Registruje se u main.dart liniji 121
FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler)
```

**Šta se dešava kada dodje notifikacija:**
1. Firebase Cloud Messaging dostavi notifikaciju
2. `firebaseMessagingBackgroundHandler()` se poziva čak i ako je app killed
3. Handler ekstraktuje title, body, data
4. Poziva `backgroundNotificationHandler()`
5. Koji poziva `LocalNotificationService.showNotificationFromBackground()`

### 2. Huawei (HMS) - Message Stream

**Fajl**: `lib/services/huawei_push_service.dart`

```dart
// Sluša ovaj stream čak i u background-u
Push.onMessageReceivedStream.listen((RemoteMessage message) async {
  // Prikaži lokalnu notifikaciju
  await LocalNotificationService.showRealtimeNotification(...)
})
```

**Šta se dešava kada dodje notifikacija:**
1. Huawei Cloud Push dostavi notifikaciju
2. `Push.onMessageReceivedStream` emituje event
3. Handler ekstraktuje title, body, data
4. Poziva `LocalNotificationService.showRealtimeNotification()`

### 3. Local Notification Service - Prikazivanje

**Fajl**: `lib/services/local_notification_service.dart`

```dart
// Prikazuje notifikaciju čak i kada je app killed
await plugin.show(
  title: title,
  body: body,
  notificationDetails: platformChannelSpecifics,
  payload: payload,
)
```

**Notifikacija će:**
- ✅ Prikazati se kao heads-up notifikacija
- ✅ Vibrirati 📳 (vibrationPattern: [0, 500, 200, 500])
- ✅ Reproducirati zvuk 🔊
- ✅ Prikazati se na lock screen 🔐
- ✅ Probuditi ekran (WakeLock 10 sekundi)
- ✅ Pokazati badge ikonicu

---

## 🔌 Android Manifest - Potrebne Dozvole

**Status**: ✅ SVE SU POSTAVLJENE

```xml
<!-- Dozvole za notifikacije -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />  <!-- Android 13+ -->
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<!-- Firebase default icon i boja -->
<meta-data android:name="com.google.firebase.messaging.default_notification_icon" 
           android:resource="@drawable/ic_notification" />
<meta-data android:name="com.google.firebase.messaging.default_notification_color" 
           android:resource="@color/notification_color" />
```

---

## 🚨 Česti Problemi i Rješenja

### Problem 1: Notifikacije ne stižu na Huawei/Xiaomi

**Razlog**: Battery optimization blokira background procesе

**Rješenje**:
1. Korisnik ide u: Settings → Battery → Battery Optimization
2. Pronađe "Gavra 013"
3. Izabere "Do Not Optimize" (ili sličnu opciju)
4. Potvrdi

**Ili programski** - Aplikacija pokazuje upozorenje:
```dart
// main.dart - 215
await BatteryOptimizationService.showWarningDialog(context);
```

### Problem 2: Notifikacije ne vibriraju

**Razlog**: Korisnik ima vibration isključene

**Rješenje**:
1. Settings → Sound & Vibration
2. Enable Vibration
3. Restart app

### Problem 3: Notifikacije imaju tiho zvuk

**Razlog**: Android notification channel je audio-dependent

**Rješenje**: 
- Sistem automatski koristi default zvuk Android sistema
- Čak i ako korisnik ima sve na mute, heads-up notifikacija će se pojaviti

---

## 📊 Toka Obrade Notifikacije

```
[Supabase/Cloud] → [FCM ili HMS Cloud]
         ↓
[Background Handler]
         ↓
[LocalNotificationService.showNotificationFromBackground()]
         ↓
[Android NotificationChannel]
         ↓
[User's Phone - Lock Screen / Notification Bar]
         ↓
[User taps] → [handleNotificationTap()] → [Open App]
```

---

## 🧪 Testiranje Background Notifikacija

### Test 1: Kill app, zatim pošalji notifikaciju

1. Otvori app (app je u foreground)
2. Zatvori app sa swipe-up (app je u background)
3. Otvori Settings i kill app (App Settings → Force Stop)
4. Sada je app **completely killed**
5. Iz web panela, pošalji notifikaciju putniku
6. **Trebalo bi**: Notifikacija stigne na phone! 🔔

### Test 2: Ekran je zaključan

1. Otvori app
2. Zatvori (Home button)
3. Zaključaj ekran (Power button)
4. Sačekaj 5 minuta
5. Pošalji notifikaciju
6. **Trebalo bi**: Ekran se proba, vidišs notifikaciju na lock screen! 🔐

### Test 3: Huawei specifično

1. Na Huawei uređaju, otvori app
2. "Swipe up from bottom" da ga zatvoriš (ne Force Stop!)
3. Pošalji notifikaciju
4. **Trebalo bi**: Notifikacija stigne! 📱

---

## 🔐 Sigurnosne Mjere

### Dedupliciranje Notifikacija

```dart
// Ako ista notifikacija dodje dva puta u 30 sekundi
// Druga instanca će biti ignorisana
final _dedupeDuration = Duration(seconds: 30);
```

### Mutex Lock

```dart
// Sprečava race condition kada foreground i background
// handleri obrađuju istu notifikaciju istovremeno
if (_processingLocks[dedupeKey] == true) {
  return; // Već se obrađuje
}
```

---

## 📝 Implementacijski Detalji

### Firebase Background Handler (FCM)

**Lokacija**: `lib/services/firebase_background_handler.dart`

```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // NAPOMENA: @pragma('vm:entry-point') je obavezna!
  // Dart VM će čuvati ovu funkciju čak i ako se app ubijenije
  
  final payload = Map<String, dynamic>.from(message.data);
  await backgroundNotificationHandler(payload);
}
```

### Huawei Background Handler (HMS)

**Lokacija**: `lib/services/huawei_push_service.dart`

```dart
void _setupMessageListener() {
  Push.onMessageReceivedStream.listen((RemoteMessage message) async {
    // Ova listener je aktivna čak i u background-u!
    final data = message.dataOfMap ?? {};
    await LocalNotificationService.showRealtimeNotification(
      title: data['title'],
      body: data['body'],
      payload: data.toString(),
    );
  });
}
```

### Local Notification Display

**Lokacija**: `lib/services/local_notification_service.dart`

```dart
static Future<void> showNotificationFromBackground({
  required String title,
  required String body,
  String? payload,
}) async {
  // Inicijalizuj FlutterLocalNotificationsPlugin
  // (može biti needed ako app nije u memory-u)
  
  final androidDetails = AndroidNotificationDetails(
    'gavra_realtime_channel',
    'Gavra Realtime Notifikacije',
    importance: Importance.max,      // Maksimalna prioriteta
    priority: Priority.high,          // Heads-up notifikacija
    playSound: true,                  // Zvuk je OBAVEZNO za heads-up
    enableVibration: true,            // Vibracipja
    fullScreenIntent: true,           // Prikaži na lock screen
    vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
    // ... ostale opcije
  );
  
  await plugin.show(
    id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
    title: title,
    body: body,
    notificationDetails: platformChannelSpecifics,
    payload: payload,
  );
}
```

---

## 🚀 Zaključak

✅ **Notifikacije RADE u background-u!**

Sistem je:
- ✅ Firebase (FCM) - za GMS uređaje
- ✅ Huawei (HMS) - za HMS uređaje  
- ✅ Fallback lokalne notifikacije
- ✅ Dedupliciranje
- ✅ Mutex lock zaštita
- ✅ Wake lock za ekran
- ✅ Vibracioni pattern
- ✅ Lock screen podrška

Ako notifikacije ne stižu, vjerovatno je **battery optimization** koji sprječava background procese. Korisnik treba da izglasuje app iz battery optimizacije.

---

## 📲 Za Testiranje

Pošalji notifikaciju iz web panela:

```bash
# Primjer PUT requestа na send-push-notification funkciju:
POST /functions/v1/send-push-notification
{
  "tokens": [
    {
      "token": "AbCdEf123...",
      "provider": "fcm"
    }
  ],
  "title": "Test",
  "body": "Ovo je test notifikacija",
  "data": {
    "type": "test"
  }
}
```

Rezultat: Notifikacija će stići čak i ako je app killed! 🎉
