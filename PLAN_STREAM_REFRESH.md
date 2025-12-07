# 📊 ANALIZA ARHITEKTURE STREAM-OVA I REFRESH MEHANIZAMA

**Datum:** 7. decembar 2025  
**Status:** ANALIZA ZAVRŠENA - Čeka implementaciju

---

## 1. DIJAGRAM TOKA PODATAKA

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SUPABASE DATABASE                                  │
│   ┌─────────────────────┐    ┌──────────────────────┐                       │
│   │  mesecni_putnici    │    │  putovanja_istorija  │                       │
│   │  (aktivni mesečni)  │    │  (dnevni + overrides)│                       │
│   └──────────┬──────────┘    └───────────┬──────────┘                       │
└──────────────┼───────────────────────────┼──────────────────────────────────┘
               │                           │
               ▼                           ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                         REALTIME SERVICE (Singleton)                         │
│  • startForDriver() - pokreće stream subscription-e                          │
│  • tableStream() - vraća Supabase stream za tabelu                           │
│  • refreshNow() - forsirani refresh sa novim query-jem                       │
│  • combinedPutniciStream (broadcast StreamController)                        │
└──────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                           PUTNIK SERVICE                                     │
│  streamKombinovaniPutniciFiltered(isoDate, grad, vreme)                      │
│  • _streams: Map<String, StreamController<List<Putnik>>>                     │
│  • _lastValues: Map<String, List<Putnik>> - cached za replay                 │
│  • KEY: "${isoDate}|${grad}|${vreme}"                                        │
│                                                                              │
│  MEHANIZAM:                                                                  │
│  1. Ako postoji stream za key → vrati postojeći + emituj cache              │
│  2. Ako ne postoji → kreiraj novi StreamController.broadcast()              │
│  3. Pozovi doFetch() → query DB → controller.add(combined)                  │
│  4. Pretplati se na RealtimeService.combinedPutniciStream                   │
└──────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                             HOME/DANAS SCREEN                                │
│  StreamBuilder<List<Putnik>>(                                                │
│    stream: _putnikService.streamKombinovaniPutniciFiltered(...)              │
│  )                                                                           │
│                                                                              │
│  ⚠️ PROBLEM: StreamBuilder drži referencu na stream!                        │
│     Kada se _streams.clear() pozove, StreamBuilder i dalje sluša            │
│     stari (sad zatvoreni) stream!                                            │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. IDENTIFIKOVANI PROBLEMI

### 🔴 PROBLEM #1: `_streams.clear()` prekida aktivne StreamBuilder-e (KRITIČNO)

**Lokacija:** `PutnikService.obrisiPutnika()` linija ~1150

```dart
_streams.clear();  // ← ⚠️ OVO JE PROBLEM!
```

**Zašto je problem:**
- `DanasScreen` ima `StreamBuilder` koji drži referencu na stream iz `_streams` mape
- Kada se pozove `_streams.clear()`, stream controller se ne zatvara pravilno
- `StreamBuilder` i dalje sluša stari stream koji više ne prima nove podatke
- Novi stream se NE kreira jer ekran ne zna da treba ponovo da pozove `streamKombinovaniPutniciFiltered()`

---

### 🔴 PROBLEM #2: Nekonzistentno čišćenje cache-a (KRITIČNO)

**Lokacija:** `GlobalCacheManager.clearAllCachesAndRefresh()`

```dart
MesecniPutnikService.clearCache();           // ✅ Čisti
await RealtimeService.instance.refreshNow(); // ✅ Refreshuje
// ⚠️ NE ČISTI: PutnikService._streams i _lastValues!
```

---

### 🟡 PROBLEM #3: `onChanged` callback ne forsira novi stream (SREDNJI)

**Lokacija:** `PutnikCard._handleBrisanje()` → callback

`onChanged` je namenjen za reoptimizaciju rute, ne za refresh stream-a.

---

### 🟡 PROBLEM #4: Stream key se ne menja nakon brisanja (SREDNJI)

Čak i nakon `_streams.clear()`, sledeći poziv može vratiti cached `_lastValues`.

---

## 3. REŠENJA

### ✅ REŠENJE #1: Direktan emit na postojeći stream (NAJBRŽE - PREPORUČENO)

**Kompleksnost: ⭐ (Laka)**  
**Vreme implementacije: 30 min - 1 sat**

Umesto `_streams.clear()`, emituj nove podatke direktno na postojeće controllere:

```dart
// U PutnikService
Future<void> obrisiPutnika(dynamic id) async {
  // Soft delete
  await supabase.from(tabela).update({'obrisan': true}).eq('id', id as String);
  
  // ⚠️ NE POZIVAJ _streams.clear()!
  // Umesto toga, forsiraj refetch za SVE aktivne stream-ove
  await _refetchAllStreams();
}

Future<void> _refetchAllStreams() async {
  for (final entry in _streams.entries) {
    if (entry.value.isClosed) continue;
    
    final parts = entry.key.split('|');
    final isoDate = parts[0].isEmpty ? null : parts[0];
    final grad = parts[1].isEmpty ? null : parts[1];
    final vreme = parts[2].isEmpty ? null : parts[2];
    
    // Re-fetch podatke za ovaj stream
    final combined = await _fetchKombinovaniPutnici(isoDate, grad, vreme);
    
    _lastValues[entry.key] = combined;
    if (!entry.value.isClosed) {
      entry.value.add(combined);
    }
  }
}
```

---

### ✅ REŠENJE #2: ValueNotifier za reaktivni refresh

**Kompleksnost: ⭐⭐ (Srednja)**  
**Vreme implementacije: 2-3 sata**

```dart
// U PutnikService
static final ValueNotifier<int> refreshSignal = ValueNotifier(0);

static void triggerRefresh() {
  refreshSignal.value++;
}

// U DanasScreen/HomeScreen
ValueListenableBuilder<int>(
  valueListenable: PutnikService.refreshSignal,
  builder: (context, refreshCount, child) {
    return StreamBuilder<List<Putnik>>(
      key: ValueKey('stream_$refreshCount'),  // ← Forsira novi stream!
      stream: _putnikService.streamKombinovaniPutniciFiltered(...),
      builder: (context, snapshot) { /* ... */ },
    );
  },
)
```

---

### ✅ REŠENJE #3: GlobalCacheManager koji čisti i PutnikService

**Kompleksnost: ⭐⭐ (Srednja)**  
**Vreme implementacije: 1-2 sata**

Proširi `GlobalCacheManager` da čisti i `PutnikService` cache.

---

## 4. OCENA KOMPLEKSNOSTI

| Rešenje | Kompleksnost | Vreme | Rizik | Preporučujem |
|---------|-------------|-------|-------|--------------|
| #1 Direktan emit | ⭐ | 30min-1h | Nizak | ✅✅ Da (najbrže) |
| #2 ValueNotifier | ⭐⭐ | 2-3h | Nizak | ✅ Da |
| #3 GlobalCacheManager | ⭐⭐ | 1-2h | Srednji | ✅ Da |

---

## 5. PREPORUČENI PRISTUP

### Korak 1: Implementiraj Rešenje #1 (30 min)

Dodaj `_refetchAllStreams()` metodu i zameni `_streams.clear()` sa pozivom te metode.

### Korak 2: Testiraj

1. Otvori HomeScreen/DanasScreen (REZERVACIJE)
2. Obriši putnika (klik na X)
3. Lista treba da se automatski osveži bez promene filtera

---

## 6. FAJLOVI ZA IZMENU

1. `lib/services/putnik_service.dart`
   - Dodaj `_refetchAllStreams()` metodu
   - Zameni `_streams.clear()` sa `_refetchAllStreams()` u `obrisiPutnika()`

2. (Opciono) `lib/utils/global_cache_manager.dart`
   - Dodaj poziv `PutnikService.refetchAllActiveStreams()`
