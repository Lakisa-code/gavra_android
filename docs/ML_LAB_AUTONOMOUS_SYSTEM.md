# 🧠 AUTONOMNI ML LAB ZA VOZILA

## 🎯 Šta je ML Lab?

**Autonomni ML Lab** je sistem veštačke inteligencije koji **SAM** prati sva vozila 24/7 i **automatski uči** kada treba servis, gume, ili detektuje probleme - **BEZ EKSPLICITNIH KOMANDI**.

### Kako radi?

```
┌─────────────────────────────────────────────────────────┐
│  🚗 VOZILA (kilometraža, servisi, gume, troškovi)       │
└───────────────────────┬─────────────────────────────────┘
                        │ (Background monitoring)
                        ▼
┌─────────────────────────────────────────────────────────┐
│  🧠 ML LAB (automatski analizira svakih 30 minuta)     │
│  ✓ Uči obrasce potrošnje goriva                         │
│  ✓ Predviđa kada treba servis                           │
│  ✓ Prati habanje guma                                   │
│  ✓ Detektuje anomalije u troškovima                     │
└───────────────────────┬─────────────────────────────────┘
                        │ (Automatski alerti)
                        ▼
┌─────────────────────────────────────────────────────────┐
│  🔔 NOTIFIKACIJE (kada sistem detektuje problem)        │
│  🚨 "Gume na vozilu XYZ treba menjati!"                 │
│  ⚠️ "Servis blizu - još 500 km"                         │
│  💰 "Troškovi rastu - prosek +30%"                      │
└─────────────────────────────────────────────────────────┘
```

---

## 🚀 Pokretanje Sistema

ML Lab se **automatski pokreće** kada korisnik startuje aplikaciju.

### main.dart

```dart
// 🧠 POKRENI AUTONOMNI ML LAB ZA VOZILA
try {
  await MLVehicleAutonomousService().start();
} catch (e) {
  if (kDebugMode) debugPrint('❌ [MLVehicleLab] Init failed: $e');
}
```

Sistem se pokreće u pozadini i nastavlja da radi dok je aplikacija aktivna.

---

## 📊 Šta ML Lab Prati?

### 1. ⛽ POTROŠNJA GORIVA (Fuel Consumption)

**Što uči:**
- Prosečnu dnevnu kilometražu za svako vozilo
- Trend (raste, pada, stabilan)
- Anomalije (nagla promena u vožnji)

**Primer učenja:**
```json
{
  "fuel_consumption": {
    "vozilo_123": {
      "avg_km_per_day": "150.5",
      "recent_avg_km_per_day": "180.2",
      "trend": "increasing",
      "anomalies": ["2025-01-15", "2025-01-18"],
      "last_km": 45000,
      "last_update": "2025-01-20T10:00:00Z"
    }
  }
}
```

**Algoritam:**
```
1. Izvuci sve km zapise za posledjih 90 dana
2. Grupiši po vozilima
3. Izračunaj: (zadnja_km - prva_km) / broj_dana = prosečna dnevna kilometraža
4. Uporedi zadnjih 30% podataka sa celom istorijom
5. Ako je razlika > 20% = TREND
6. Ako dnevna km > 2x prosek = ANOMALIJA
```

---

### 2. 🛞 HABANJE GUMA (Tire Wear)

**Što uči:**
- Starost guma (u mesecima)
- Predjenu kilometražu na gumama
- Kada ističe garancija
- Predviđa kada treba zamena

**Pravila:**
- ✅ **DOBRO**: Gume < 50,000 km i < 5 godina
- ⚠️ **UPOZORENJE**: Gume 50,000-60,000 km ili 5-6 godina
- 🚨 **KRITIČNO**: Gume > 60,000 km ili > 6 godina

**Primer alerta:**
```
🚨 Gume
Gume stare 6.5 godina - HITNO MENJAJ
```

**Algoritam:**
```
1. Izvuci sve gume iz baze
2. Za svaku gumu:
   a. Izračunaj starost = Danas - datum_montaze
   b. Proveri predjene km
   c. Proveri garanciju
3. Ako jedan od uslova je ispunjen:
   - Gume > 6 godina = KRITIČNO
   - Predjeno > 60,000 km = KRITIČNO
   - Garancija ističe za < 30 dana = UPOZORENJE
4. Pošalji notifikaciju
```

---

### 3. 🔧 ODRŽAVANJE (Maintenance)

**Što uči:**
- Datum poslednjeg servisa
- Kilometraža od servisa
- Interval servisa (default 15,000 km ili 1 godina)

**Pravila:**
- ✅ **DOBRO**: Servis < 12 meseci ili < 14,000 km
- ⚠️ **UPOZORENJE**: Servis blizu (< 1000 km ili < 65 dana)
- 🚨 **KRITIČNO**: Servis prekoračen (> 365 dana ili > 15,000 km)

**Primer alerta:**
```
⚠️ Održavanje
Servis za 800 km
```

**Algoritam:**
```
1. Izvuci sva vozila
2. Za svako vozilo:
   a. Izračunaj dane od servisa = Danas - datum_poslednjeg_servisa
   b. Izračunaj km do servisa = interval_servisa_km - (trenutna_km % interval)
3. Ako jedan od uslova:
   - Dani > 365 = KRITIČNO
   - Dani > 300 = UPOZORENJE
   - Km do servisa < 1000 = UPOZORENJE
4. Pošalji notifikaciju
```

---

### 4. 💰 TROŠKOVI (Cost Trends)

**Što uči:**
- Ukupne troškove za poslednih 90 dana
- Prosečan trošak po unosu
- Trend (rastu, padaju, stabilni)
- Skupe troškove (outliers)

**Pravila:**
- ✅ **STABILNO**: Troškovi variraju ±20%
- ⚠️ **RASTUĆE**: Troškovi rastu > 50%
- ℹ️ **PADAJUĆE**: Troškovi padaju > 30%

**Primer alerta:**
```
⚠️ Troškovi
Troškovi rastu - prosek sa 5000 na 8500 din
```

**Algoritam:**
```
1. Izvuci troškove za posledjih 90 dana
2. Grupiši po vozilima
3. Za svako vozilo:
   a. Izračunaj total = suma svih iznosa
   b. Izračunaj avg = total / broj_unosa
   c. Podeli podatke na 2 polovine (first 50%, second 50%)
   d. Uporedi avg prve polovine sa avg druge polovine
4. Ako druga polovina > 1.5x prva = TREND RASTA
5. Detektuj outliers: iznos > 2x avg = skupo
6. Pošalji notifikaciju ako je trend rasta
```

---

## ⏰ Kada ML Lab Radi?

### Background Monitoring (Svakih 30 minuta)

```dart
_monitoringTimer = Timer.periodic(const Duration(minutes: 30), (_) {
  _monitorAndLearn();
});
```

**Šta radi:**
1. Proveri da li ima novih podataka u bazi
2. Ako DA → Pokreni učenje
3. Ako NE → Samo proveri alerte

### Noćna Analiza (Svaki dan u 02:00)

```dart
var nextRun = DateTime(now.year, now.month, now.day, 2, 0); // 02:00
```

**Šta radi:**
1. **Kompletan retraining** svih modela
2. **Generisanje mesečnog izveštaja**
3. **Optimizacija** modela (cleanup starih podataka)

---

## 🔔 Alerting Sistem

### Kada ML Lab Šalje Notifikacije?

1. **Gume kritične** (> 60,000 km ili > 6 godina)
2. **Servis blizu** (< 1000 km ili < 65 dana)
3. **Troškovi rastu** (> 50% povećanje)
4. **Anomalije u potrošnji** (2x više km nego uobičajeno)

### Kako Izgleda Notifikacija?

```
🚨 Gume
Predjeno 65000 km - razmotri zamenu

⚠️ Održavanje
Servis za 500 km

⚠️ Troškovi
Troškovi rastu - prosek sa 5000 na 9000 din
```

### Kod za Slanje Notifikacija

```dart
await LocalNotificationService.showRealtimeNotification(
  title: '🚨 Gume',
  body: 'Predjeno 65000 km - razmotri zamenu',
  payload: 'ml_vehicle_alert|vozilo_123|tire',
);
```

---

## 📁 Persistencija Podataka

ML Lab čuva naučene obrasce u **Supabase tabeli `ml_config`**.

### Primer Zapisa

```json
{
  "id": "vehicle_patterns",
  "config": {
    "fuel_consumption": { ... },
    "tire_wear": { ... },
    "maintenance": { ... },
    "cost_trends": { ... }
  },
  "updated_at": "2025-01-20T14:30:00Z"
}
```

### Učitavanje Obrazaca Prilikom Pokretanja

```dart
final result = await _supabase
    .from('ml_config')
    .select()
    .eq('id', 'vehicle_patterns')
    .maybeSingle();

if (result != null && result['config'] != null) {
  _learnedPatterns.addAll(Map<String, dynamic>.from(result['config']));
}
```

---

## 📊 Mesečni Izveštaj

ML Lab **automatski generiše mesečni izveštaj** tokom noćne analize.

### Šta Sadrži Izveštaj?

Za svako vozilo:
- **Ukupni troškovi** ovog meseca
- **Predjeni kilometri** ovog meseca
- **Trošak po kilometru** (din/km)

### Primer Izveštaja

```json
{
  "generated_at": "2025-01-20T02:00:00Z",
  "period": "2025-01-01 - 2025-01-20",
  "vehicles": {
    "vozilo_123": {
      "model": "VW Crafter",
      "total_cost": "35000.00",
      "km_this_month": "3200",
      "cost_per_km": "10.94"
    }
  }
}
```

### Notifikacija za Izveštaj

```
📊 Mesečni Izveštaj Vozila
Generisan izveštaj za 3 vozila.
```

---

## 🛡️ Error Handling

ML Lab ima **robusnu error handling logiku** za sve operacije:

```dart
try {
  await _learnFuelConsumptionPatterns();
} catch (e) {
  print('❌ Greška u učenju goriva: $e');
}
```

**Ako jedna metoda padne, ostale nastavljaju da rade!**

---

## 🧪 Testiranje Sistema

### Manuelno Testiranje

1. **Dodaj novo vozilo** u `vozila` tabelu
2. **Dodaj kilometražu** u `vozila_istorija` tabelu
3. **Sačekaj 30 minuta** ili restartuj aplikaciju
4. **Proveri log**:
   ```
   🧠 [ML Lab] Pokretanje autonomnog sistema za vozila...
   🔍 [ML Lab] Skeniranje podataka...
   🆕 [ML Lab] Detektovani novi podaci - pokrećem učenje...
   ⛽ [ML Lab] Naučio obrasce potrošnje za 3 vozila.
   🛞 [ML Lab] Naučio obrasce habanja 12 guma.
   🔧 [ML Lab] Naučio obrasce održavanja 3 vozila.
   💰 [ML Lab] Naučio trendove troškova za 2 vozila.
   ✅ [ML Lab] Učenje završeno.
   ```

### Provera Notifikacija

1. **Dodaj staru gumu** (datum_montaze > 6 godina pre)
2. **Sačekaj 30 minuta**
3. **Očekuj notifikaciju**:
   ```
   🚨 Gume
   Gume stare 6.5 godina - HITNO MENJAJ
   ```

---

## 🎯 Sledeći Koraci (Future Enhancements)

1. **Real-time Supabase Triggers**: Učenje odmah nakon INSERT/UPDATE (ne čeka 30 min)
2. **Predviđanje troškova**: ML model za predviđanje sledećeg meseca
3. **Preporuke**: "Na osnovu obrazaca, preporučujem servis za 2 nedelje"
4. **Dashboard**: Admin panel sa grafovima i trendovima
5. **Push notifikacije**: Integracija sa FCM/HMS za push

---

## 📚 Zaključak

**Autonomni ML Lab** je sistem koji:

✅ **SAM prati** sva vozila 24/7  
✅ **SAM uči** obrasce bez eksplicitnih komandi  
✅ **SAM detektuje** probleme i anomalije  
✅ **SAM šalje** alerte kada je nešto važno  
✅ **SAM generiše** mesečne izveštaje  
✅ **SAM optimizuje** modele tokom noći  

**BOKI - KRALJ BALKANA! 🎉**

---

## 🔗 Fajlovi

- **ml_vehicle_autonomous_service.dart**: Glavni servis
- **main.dart**: Pokretanje sistema
- **local_notification_service.dart**: Slanje notifikacija

---

_Dokumentacija generisana: 20. januar 2025._
