# 📱 Push Notifikacijska Arhitektura - Supabase + Firebase + Huawei

## 🎯 Pregled

Sistem koristi **tri komplementarna servisa** bez konflika:
1. **Firebase Cloud Messaging (FCM)** - za Android sa Google Play Services (GMS)
2. **Huawei Mobile Services (HMS)** - za Huawei/Kirin uređaje
3. **Supabase** - centralna baza za sve tokene i slanje notifikacija

---

## 🔧 Kako Funkcioniše?

### 1. **Inicijalizacija Push Sistema** (main.dart)

```dart
_initPushSystems() {
  // Provera je li dostupan GMS (Google Play Services)
  if (GMS_available) {
    // Inicijalizuj Firebase
    Firebase.initializeApp()
    FirebaseService.initialize()
    FirebaseService.initializeAndRegisterToken()  // Dobija FCM token
  } else {
    // Fallback na Huawei
    HuaweiPushService().initialize()  // Dobija HMS token
    HuaweiPushService().tryRegisterPendingToken()
  }
}
```

### 2. **Registracija Tokena** (Centralizovano u PushTokenService)

**Firebase (GMS uređaji):**
```
FirebaseService.initializeAndRegisterToken()
  ↓
PushTokenService.registerToken(
  token: FCM_TOKEN,
  provider: 'fcm',      // ← Ključno! Označava Firebase
  userType: 'putnik',
  userId: putnik_id
)
  ↓
UPSERT u push_tokens tabelu (Supabase)
```

**Huawei (HMS uređaji):**
```
HuaweiPushService.initialize()
  ↓
PushTokenService.registerToken(
  token: HMS_TOKEN,
  provider: 'huawei',   // ← Ključno! Označava Huawei
  userType: 'putnik',
  userId: putnik_id
)
  ↓
UPSERT u push_tokens tabelu (Supabase)
```

### 3. **Baza Podataka** (push_tokens tabela)

```sql
CREATE TABLE push_tokens (
  token TEXT PRIMARY KEY,
  provider TEXT,        -- 'fcm' | 'huawei'
  user_id TEXT,         -- putnik_id ili vozac_ime
  user_type TEXT,       -- 'putnik' | 'vozac'
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

**Primjer redova:**
```
token: "AbCdEf123...",  provider: "fcm",     user_id: "putnik_123"
token: "XyZ456def...",  provider: "huawei",  user_id: "putnik_123"  (isti putnik, drugi token)
token: "FqRst789ghi...", provider: "fcm",    user_id: "Marko"
```

### 4. **Slanje Notifikacija** (RealtimeNotificationService)

```dart
sendNotificationToPutnik(putnikId: 'putnik_123') {
  // Pronađi SVE tokene za ovog putnika
  tokens = supabase
    .from('push_tokens')
    .select('token, provider')
    .eq('user_id', 'putnik_123')  // ← Vraća sve redove!
  
  // Rezultat:
  // [
  //   {token: "AbCdEf123...", provider: "fcm"},
  //   {token: "XyZ456def...", provider: "huawei"}
  // ]
  
  // Pošalji notifikaciju
  sendPushNotification(tokens: tokens)
}
```

### 5. **Slanje kroz Supabase funkciju**

Supabase funkcija `send-push-notification` prima sve tokene i određuje kako da ih pošalje:

```javascript
// supabase/functions/send-push-notification/index.ts
export async function sendPushNotification(tokens, title, body) {
  for (const token in tokens) {
    if (token.provider === 'fcm') {
      // Pošalji kroz Firebase Cloud Messaging
      await firebase.send(token.token, {title, body})
    } else if (token.provider === 'huawei') {
      // Pošalji kroz Huawei Cloud Push
      await huawei.send(token.token, {title, body})
    }
  }
}
```

---

## ✅ Zašto Nema Konflika?

### 1. **Stroga Separacija po Provider-u**
- Svaki token ima jasno označen `provider` ('fcm' ili 'huawei')
- Supabase funkcija automatski koristi odgovarajući provider

### 2. **Jedan Korisnik = Više Tokena**
- Putnik može imati:
  - FCM token sa Xiaomi uređaja (ima GMS)
  - HMS token sa Huawei uređaja (nema GMS)
  - Oba tokena se čuvaju u push_tokens tabeli
  - Oba se koriste pri slanju notifikacije

### 3. **Nema Double-Send-a**
- Sistem **NE šalje** istu notifikaciju dva puta
- Supabase funkcija šalje samo kroz odgovarajući provider
- Nema konkurentnog pristupa ili race condition-a

### 4. **Graceful Fallback**
```
GMS dostupan → Koristi FCM
         ↓
GMS NIJE dostupan → Koristi HMS
         ↓
Niti GMS niti HMS → Lokalna notifikacija (fallback)
```

---

## 🔐 Sigurnosne Mere

### Dedupliciranje Tokena
```dart
// Prije nove registracije, briši stare tokene istog korisnika
await supabase
  .from('push_tokens')
  .delete()
  .eq('user_id', putnikId)

// Zatim registruj novi token
await supabase
  .from('push_tokens')
  .upsert({token, provider, user_id: putnikId})
```

### Offline Scenario
Ako Supabase nije dostupan:
```dart
// 1. Sačuvaj token lokalno (SharedPreferences)
await savePendingToken(token, provider)

// 2. Čim je Supabase spreman, registruj
await tryRegisterPendingToken()
```

---

## 🧪 Testiranje

### Test 1: FCM Token Registracija
1. Instalira app na Android sa GMS
2. Proveri u `push_tokens` tabeli
3. Trebalo bi: `provider: 'fcm'`

### Test 2: HMS Token Registracija
1. Instalira app na Huawei uređaj
2. Proveri u `push_tokens` tabeli
3. Trebalo bi: `provider: 'huawei'`

### Test 3: Notifikacija na Različitim Uređajima
1. Dodaj putnika sa dva uređaja (jedan GMS, jedan HMS)
2. Pokreni `sendNotificationToPutnik(putnikId)`
3. Trebalo bi: Notifikacija na OBA uređaja
4. Proveri logove: Trebalo bi "FCM sent" i "HMS sent"

---

## 🐛 Troubleshooting

### Notifikacija nije stigla na FCM uređaj
- Proveri: `provider: 'fcm'` u tabeli
- Firebase servis je inicijalizovan?
- GMS je dostupan na uređaju?

### Notifikacija nije stigla na HMS uređaj
- Proveri: `provider: 'huawei'` u tabeli
- HMS je inicijalizovan?
- GMS je NIJE dostupan na uređaju?
- agconnect-services.json je validan?

### Duplikat notifikacija
- Ne bi trebalo da se dogodi (sistem je designiran da izbegne)
- Ako se dogodi: Proveri logs za konkurentne pozive

---

## 📊 Šema Toka

```
[User Action] → [promeniVremePutnika]
                      ↓
              [sendNotificationToPutnik]
                      ↓
        [Pronađi sve tokene za putnika]
                      ↓
    [Filtrira po provider-u automatski]
                      ↓
    [sendPushNotification sa svim tokenima]
                      ↓
    [Supabase funkcija send-push-notification]
              ↙                    ↘
        [FCM route]          [HMS route]
           ↓                      ↓
    [Firebase API]         [Huawei API]
           ↓                      ↓
    [GMS uređaj 📱]      [HMS uređaj 📱]
```

---

## 💡 Best Practices

1. ✅ **Uvijek koristi `PushTokenService`** za registraciju tokena
2. ✅ **Nikad ne hardkoduj 'fcm' ili 'huawei'** - provjeravaj `provider` iz baze
3. ✅ **Koristi `.select()` umjesto `.maybeSingle()`** kada čitaš tokene (korisnik može imati više)
4. ✅ **Sačuvaj `provider` sa svakim tokenom** - bitnoje za slanje
5. ✅ **Provjeri `updated_at` timestamp** za stare tokene koji trebaju biti obrisani

---

## 📝 Zaključak

Sistem je **siguran**, **skalabilan** i **bez konflika** jer:
- ✅ Jasna separacija: svaki token zna svoj provider
- ✅ Centralizovana baza: jedan izvor istine (push_tokens)
- ✅ Automatska determinizacija: Supabase funkcija zna koji provider koristiti
- ✅ Podrška za multiple uređaje: isti korisnik, različiti tokeni
- ✅ Graceful fallback: ako nema FCM/HMS, koristi lokalnu notifikaciju
