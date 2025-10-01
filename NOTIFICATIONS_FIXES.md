# Notifikacije Fixes

## Datum: 1. oktobar 2025.

## Problemi pronađeni i ispravljeni:

### 1. Nekonzistentni tipovi notifikacija
**Problem**: U `RealtimeNotificationService.listenForForegroundNotifications()` se filtriralo notifikacije samo za tipove "dodat" i "otkazan", ali se u `putnik_service.dart` šalju notifikacije sa tipovima "novi_putnik" i "otkazan_putnik".

**Rešenje**: Proširena filter logika da prihvata oba formata tipova.

### 2. Nedostatak filtera u navigaciji
**Problem**: U `NotificationNavigationService._navigateToAppropriateScreen()` se uvek navigiralo na `DanasScreen` bez filtera, što je činilo navigaciju beskorisnom.

**Rešenje**: Dodani filteri za ime putnika, grad i vreme kada se navigira iz notifikacije.

## Kako funkcioniše logika notifikacija:

### Multi-channel pristup:
- **Firebase Cloud Messaging (FCM)**: Za push notifikacije sa servera
- **OneSignal**: Za dodatne push notifikacije (koristi server za forward)
- **Lokalne notifikacije**: Za trenutne notifikacije sa zvukom i vibracijom

### Tok notifikacija:

1. **Dodavanje/Otkazivanje putnika** (`putnik_service.dart`):
   - Poziva se `RealtimeNotificationService.sendRealtimeNotification()`
   - Šalje se lokalna notifikacija odmah
   - Pokušava se poslati OneSignal notifikacija (ako je server podešen)

2. **Primanje Firebase notifikacija** (`RealtimeNotificationService`):
   - Filtrira se samo notifikacije za današnji dan
   - Prihvata tipove: "dodat", "novi_putnik", "otkazan", "otkazan_putnik"
   - Prikazuje lokalnu notifikaciju sa zvukom

3. **Klik na notifikaciju** (`LocalNotificationService`):
   - Parsira se payload (JSON string sa podacima o putniku)
   - Navigira se na `DanasScreen` sa filterima za putnika

4. **Brojanje notifikacija** (`RealtimeNotificationCounterService`):
   - Prati broj nepročitanih notifikacija
   - Ažurira se na osnovu Firebase događaja

### Konfiguracija:

- **OneSignal App ID**: Hardkodiran u `main.dart` - treba promeniti za produkciju
- **OneSignal Server URL**: Postavljen na localhost - treba promeniti za produkciju
- **Firebase**: Automatski konfiguriše se iz `firebase_options.dart`

### Fajlovi promenjeni:

- `lib/services/realtime_notification_service.dart` - Ispravljen filter tipova
- `lib/services/notification_navigation_service.dart` - Dodani filteri u navigaciji

### Testiranje:

Notifikacije sada treba da rade ispravno:
- ✅ Lokalne notifikacije sa zvukom pri dodavanju/otkazivanju putnika
- ✅ Filtriranje samo za današnje notifikacije
- ✅ Navigacija sa filterima kada se klikne na notifikaciju
- ✅ Brojanje nepročitanih notifikacija

### Napomene za produkciju:

1. **OneSignal App ID**: Promeniti u produkcijski App ID
2. **OneSignal Server URL**: Postaviti pravi server endpoint za forward notifikacija
3. **Firebase Cloud Messaging**: Implementirati server-side slanje notifikacija
4. **Permissions**: Osigurati da su notifikacione dozvole tražene i odobrene</content>
<parameter name="filePath">c:\Users\Bojan\gavra_android\NOTIFICATIONS_FIXES.md