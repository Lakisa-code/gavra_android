# REALTIME ANALIZA

## CILJ
1 stream → 1 tabela (`registrovani_putnici`) → svi vozači vide sve promene odmah

## TRENUTNO STANJE

### Fajlovi koji koriste stream:

**EKRANI (9 ekrana koji TREBAJU realtime):**
1. `home_screen.dart` - StreamBuilder linija 2021
2. `danas_screen.dart` - StreamBuilder linija 2259, 2796 + više za statistiku
3. `vozac_screen.dart` - StreamBuilder linija 732, 1539, 1681
4. `admin_screen.dart` - StreamBuilder linija 1005, 1220, 1354 (pazar/kusur statistika)
5. `admin_map_screen.dart` - direktan Supabase stream linija 53 (GPS lokacije)
6. `registrovani_putnici_screen.dart` - StreamBuilder linija 764
7. `dugovi_screen.dart` - koristi streamKombinovaniPutniciFiltered linija 122
8. `dodeli_putnike_screen.dart` - koristi streamKombinovaniPutniciFiltered linija 143
9. `kapacitet_screen.dart` - ⚠️ NEMA STREAM - promene kapaciteta se ne vide uživo!

**SERVISI (3 servisa):**
1. `realtime_service.dart` - glavni servis sa tableStream(), combinedPutniciStream
2. `putnik_service.dart` - streamKombinovaniPutniciFiltered() sa keširanjem
3. `registrovani_putnik_service.dart` - poziva RealtimeService.refreshNow()

**WIDGETI:**
1. `putnik_card.dart` - poziva RealtimeService.instance.refreshNow() na 5 mesta
2. `putnik_list.dart` - StreamBuilder linija 110

### LANAC POZIVA (previše komplikovan):
```
Supabase tabela
    ↓
RealtimeService.tableStream('registrovani_putnici')
    ↓
RealtimeService._registrovaniSub listener
    ↓
RealtimeService._emitCombinedPutnici()
    ↓
RealtimeService.combinedPutniciStream
    ↓
PutnikService.streamKombinovaniPutniciFiltered() listener
    ↓
PutnikService._doFetchForStream() - PONOVO FETCHUJE IZ BAZE!
    ↓
PutnikService._streams[key] controller
    ↓
StreamBuilder u ekranu
```

### PROBLEMI:
1. Previše slojeva između Supabase i UI
2. `PutnikService` kešira streamove po ključu (isoDate|grad|vreme) - može da se zaglavi
3. Kada stigne event, `_doFetchForStream()` ponovo radi SELECT iz baze umesto da koristi podatke iz eventa
4. `refreshNow()` se poziva ručno na mnogo mesta - znak da automatski refresh ne radi

## PLAN POJEDNOSTAVLJENJA

**OPCIJA A - Minimalna promena:**
Popraviti samo mesto gde se stream "zaglavi" - verovatno u PutnikService keširanju

**OPCIJA B - Srednja promena:**
Ukloniti keširanje u PutnikService, svaki put kreirati nov stream

**OPCIJA C - Potpuno pojednostavljenje:**
Direktno koristiti `Supabase.from('registrovani_putnici').stream()` u ekranima, bez posrednika

