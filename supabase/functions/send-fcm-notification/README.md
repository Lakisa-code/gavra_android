# 🔥 FCM Server Integration - Setup Guide

## 🎯 Zašto FCM Server Integration?

Firebase Cloud Messaging **MORA** da se šalje sa servera jer:
- 🔒 **Sigurnost**: Server key ne sme biti u aplikaciji
- 🎯 **Targeting**: Možete ciljati hiljade korisnika odjednom
- 📊 **Analytics**: Centralizovano praćenje delivery rates
- ⚡ **Performance**: Batch slanje na preko 1000 devices

## 🛠️ Setup Proces:

### 1. **Dobijte FCM Server Key**

1. Idite na [Firebase Console](https://console.firebase.google.com/)
2. Izaberite projekat `gavra-notif-20250920162521`
3. Project Settings > Cloud Messaging
4. **Server Key** - kopirajte vrednost

### 2. **Deploy Supabase Edge Function**

```bash
# Deploy FCM edge function
supabase functions deploy send-fcm-notification

# Set environment variables
supabase secrets set FCM_SERVER_KEY=your-server-key-here
supabase secrets set SUPABASE_URL=your-supabase-url
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

### 3. **Kreiranje notification_stats tabele**

```sql
-- Kreiranje tabele za praćenje notifikacija
CREATE TABLE notification_stats (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  type text NOT NULL, -- 'fcm', 'huawei', 'local'
  title text NOT NULL,
  target_type text NOT NULL, -- 'token', 'topic', 'condition'
  target_value text NOT NULL,
  success_count integer DEFAULT 0,
  failure_count integer DEFAULT 0,
  multicast_id text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT notification_stats_type_check CHECK (type IN ('fcm', 'huawei', 'local'))
);

-- Index za performance
CREATE INDEX idx_notification_stats_created_at ON notification_stats(created_at DESC);
CREATE INDEX idx_notification_stats_type ON notification_stats(type);
```

## 🎯 Kako koristiti iz Flutter app-a:

### **1. Pošalji svim vozačima:**
```dart
await RealtimeNotificationService.sendNotificationToAllDrivers(
  title: 'Nova putanja!',
  body: 'Dodato je novo putovanje za danas',
  data: {'type': 'novi_putnik', 'putnik_id': '123'},
);
```

### **2. Pošalji specifičnom vozaču:**
```dart
await RealtimeNotificationService.sendNotificationToDriver(
  driverId: 'bojan',
  title: 'Putovanje otkazano',
  body: 'Marko Petrović je otkazao putovanje',
  data: {'type': 'otkazan_putnik', 'putnik_id': '456'},
);
```

### **3. Custom targeting:**
```dart
await RealtimeNotificationService.sendFCMNotification(
  title: 'Custom poruka',
  body: 'Poruka za specifične device tokene',
  targetType: 'condition',
  targetValue: "'gavra_driver_bojan' in topics && 'premium_user' in topics",
  data: {'custom_key': 'custom_value'},
);
```

## 📊 Targeting Options:

| Target Type | Target Value | Opis |
|-------------|--------------|------|
| **token** | Device token | Pojedinačni uređaj |
| **topic** | `gavra_all_drivers` | Svi vozači |
| **topic** | `gavra_driver_bojan` | Specifični vozač |
| **condition** | Complex query | Kombinacija topics |

## 🔄 Migration Strategy:

### **Staro (direktno iz app-a - NEĆE RADITI):**
```dart
// ❌ OVO NEĆE RADITI - nema server key u klijentskom kodu
FirebaseMessaging.instance.sendMessage(...) // Ne postoji!
```

### **Novo (preko Supabase Edge Function):**
```dart
// ✅ OVO RADI - server-side slanje
await RealtimeNotificationService.sendFCMNotification(...)
```

## 🚀 Benefits:

- ✅ **Sigurnost**: Server key sakriven
- ✅ **Skalabilnost**: Može slati hiljadama korisnika
- ✅ **Analytics**: Praćenje delivery rates
- ✅ **Fallback**: Kombinacija FCM + Huawei + Local
- ✅ **Performance**: Batch operations
- ✅ **Cost Effective**: FCM je besplatan za osnovne potrebe

## 💡 Pro Tips:

1. **Rate Limiting**: FCM ima limit od 100 req/sec
2. **Batch Operations**: Grupišite notifikacije kada možete
3. **Topic Management**: Koristite topics umesto individual tokens
4. **Analytics**: Pratite delivery rates u `notification_stats` tabeli
5. **Error Handling**: Implementirajte retry logiku za failed notifications