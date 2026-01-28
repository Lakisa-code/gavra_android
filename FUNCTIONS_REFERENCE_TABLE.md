# 📊 REFERENTNA TABELA SVIH FUNKCIJA

## 📍 PUTNIK SERVICE (40+ funkcija)

### Čitanje Podataka
| Funkcija | Tip | Ponos | Poziva | Opis |
|----------|-----|--------|--------|------|
| `getPutniciByDayIso` | `Future<List<Putnik>>` | ⭐⭐⭐ | 8+ | Pronađi sve putnike za dan |
| `streamKombinovaniPutniciFiltered` | `Stream<List<Putnik>>` | ⭐⭐⭐⭐ | 15+ | Realtime stream putnika sa filterima |
| `getPutnikFromAnyTable` | `Future<Putnik?>` | ⭐⭐ | 3 | Pronađi putnika u bilo kojoj tabeli |
| `getPutniciByIds` | `Future<List<Putnik>>` | ⭐⭐ | 2 | Batch učitavanje putnika |
| `getCachedPutniciForDay` | `List<Putnik>` | ⭐ | 1 | Cache iz memorije |
| `getAllPutnici` | `Future<List<Putnik>>` | ⭐⭐ | 4 | Svi putnici iz baze |
| `getPutnikById` | `Future<Putnik?>` | ⭐⭐ | 3 | Po ID-u |

**Pronalaženje:**
```
Ctrl+P > putnik_service > Ctrl+F > getPutniciByDayIso
```

### Pisanje Podataka
| Funkcija | Tip | Ponos | Poziva | Opis |
|----------|-----|--------|--------|------|
| `oznaciPokupljen` | `Future<void>` | ⭐⭐⭐⭐ | 5 | **KRITIČNA** - označi putnika |
| `otkaziPutnika` | `Future<void>` | ⭐⭐⭐ | 3 | **VAŽNA** - otkaži putnika |
| `ukloniIzTermina` | `Future<void>` | ⭐⭐⭐ | 7 | Ukloni iz termina |
| `dodajNovogPutnika` | `Future<void>` | ⭐⭐⭐ | 6 | Dodaj putnika |
| `updatePutnik` | `Future<void>` | ⭐⭐ | 4 | Ažuriraj putnika |
| `sacuvajPromenePutnika` | `Future<void>` | ⭐⭐ | 3 | Sačuvaj izmene |
| `deleteNovogPutnika` | `Future<void>` | ⭐⭐ | 2 | Obriši putnika |

**Pronalaženje:**
```
Ctrl+Shift+H na liniji: oznaciPokupljen() -> vidi sve pozive
```

### Stream Upravljanje
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `_streamKey` | `String` | ⭐ | Generiši stream ključ |
| `_ensureGlobalChannel` | `void` | ⭐⭐ | Konekcija na realtime |
| `_refreshAllStreams` | `Future<void>` | ⭐⭐⭐ | Osvezi sve streamove |
| `dispose` | `void` | ⭐⭐ | Cleanup resursa |

---

## 💰 REGISTROVANI PUTNIK SERVICE (30+ funkcija)

### Čitanje
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `getAktivniRegistrovaniPutnici` | `Future<List<RegistrovaniPutnik>>` | ⭐⭐⭐ | Svi aktivni |
| `getRegistrovaniPutnikByIme` | `Future<RegistrovaniPutnik?>` | ⭐⭐ | Po imenu |
| `streamAktivniRegistrovaniPutnici` | `Stream<List<RegistrovaniPutnik>>` | ⭐⭐⭐ | Realtime stream |
| `getAllRegistrovani` | `Future<List<RegistrovaniPutnik>>` | ⭐⭐ | Svi registrovani |

### Pisanje
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `azurirajPlacanjeZaMesec` | `Future<bool>` | ⭐⭐⭐⭐ | **KRITIČNA** - plaćanja |
| `dodajRegistrovanogPutnika` | `Future<void>` | ⭐⭐⭐ | Dodaj |
| `updateRegistrovaniPutnik` | `Future<void>` | ⭐⭐ | Ažuriraj |
| `deleteRegistrovani` | `Future<void>` | ⭐⭐ | Obriši |

---

## 🚗 VOZAČ SERVICE (25+ funkcija)

| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `sviVozaci` | `Future<List<Vozac>>` | ⭐⭐⭐ | Svi vozači |
| `vozacPoImenu` | `Future<Vozac?>` | ⭐⭐ | Po imenu |
| `streamSviVozaci` | `Stream<List<Vozac>>` | ⭐⭐⭐ | Realtime |
| `sacuvajVozaca` | `Future<void>` | ⭐⭐⭐ | Sačuvaj |
| `updateVozac` | `Future<void>` | ⭐⭐ | Ažuriraj |
| `deleteVozac` | `Future<void>` | ⭐⭐ | Obriši |
| `getVozacStats` | `Future<VozacStats>` | ⭐⭐ | Statistika |

---

## 🤖 ML SERVICE (35+ funkcija)

### Glavne Funkcije
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `predictOptimalTimes` | `Future<List<OptimalTimeSlot>>` | ⭐⭐⭐ | ML - best vremena |
| `rateDriverQuality` | `Future<DriverQualityScore>` | ⭐⭐⭐ | ML - ocena vozača |
| `optimizeLargeRoutes` | `Future<List<RouteSegment>>` | ⭐⭐⭐ | ML - rute |
| `detectAnomalies` | `Future<List<Anomaly>>` | ⭐⭐ | ML - anomalije |

### Pomoćne Funkcije
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `_calculateDistance` | `double` | ⭐⭐⭐ | Rastojanje |
| `_degreesToRadians` | `double` | ⭐⭐ | Konverzija |
| `_calculateBearing` | `double` | ⭐ | Pravac |
| `_estimateTime` | `Duration` | ⭐⭐ | Vreme vožnje |

---

## 🎨 PUTNIK CARD WIDGET (50+ funkcija)

### Glavne Funkcije
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `build` | `Widget` | ⭐⭐⭐⭐ | **KRITIČNA** - UI |
| `_buildContainer` | `Widget` | ⭐⭐⭐ | Kontejner UI |
| `_buildHeader` | `Widget` | ⭐⭐⭐ | Header |
| `_buildBody` | `Widget` | ⭐⭐⭐ | Body |
| `_buildFooter` | `Widget` | ⭐⭐⭐ | Footer |

### Interakcije
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `_oznaciPokupljenTap` | `Future<void>` | ⭐⭐⭐ | Tap na pokupljenje |
| `_otkaziTap` | `Future<void>` | ⭐⭐⭐ | Tap na otkazivanje |
| `_placanjeDialog` | `void` | ⭐⭐ | Dialog plaćanja |
| `_showAdminPopup` | `void` | ⭐⭐ | Admin menu |
| `_getKoordinateZaAdresu` | `Future<Koordinate?>` | ⭐⭐ | GPS koordinate |
| `_navigujNaAdresu` | `void` | ⭐⭐ | GPS navigacija |

### Plaćanja
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `_sacuvajPlacanjeStatic` | `Future<void>` | ⭐⭐⭐⭐ | **KRITIČNA** - logovanje |
| `_cacunaPlacanja` | `double` | ⭐⭐ | Izračunaj |
| `_formatPlacanjaText` | `String` | ⭐⭐ | Tekst |

---

## 📍 KOMBI ETA WIDGET (15+ funkcija)

| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `build` | `Widget` | ⭐⭐⭐⭐ | **KRITIČNA** - UI |
| `_loadGpsData` | `Future<void>` | ⭐⭐⭐ | GPS učitavanje |
| `_loadPokupljenjeIzBaze` | `Future<void>` | ⭐⭐⭐ | Podatke iz baze |
| `_buildContainer` | `Widget` | ⭐⭐⭐ | Kontejner |
| `_updateEta` | `void` | ⭐⭐⭐ | Osvezi ETA |
| `_subscribeToRealtimeChanges` | `void` | ⭐⭐⭐ | Realtime |
| `_calculateEta` | `String` | ⭐⭐ | ETA kalkulacija |
| `dispose` | `void` | ⭐⭐ | Cleanup |

---

## 🛣️ VOZNJE LOG SERVICE (20+ funkcija)

| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `logGeneric` | `Future<void>` | ⭐⭐⭐⭐ | **KRITIČNA** - logovanje |
| `getAllVoznjeLogs` | `Future<List<VoznjaLog>>` | ⭐⭐ | Svi logovi |
| `getVoznjeLogs` | `Stream<List<VoznjaLog>>` | ⭐⭐⭐ | Stream |
| `deleteVoznjaLog` | `Future<void>` | ⭐⭐ | Obriši |
| `getStatsByVozac` | `Future<Map>` | ⭐⭐ | Statistika |

---

## 📊 ANALYTICS & AUTONOMOUS (ML) SERVISI

### ml_dispatch_autonomous_service.dart
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `toggleAutopilot` | `void` | ⭐⭐⭐ | Automatsko dodeljiv |
| `_subscribeToBookingStream` | `void` | ⭐⭐⭐ | Realtime booking |
| `_startVelocityMonitoring` | `void` | ⭐⭐ | Monitorovanje brzine |
| `_startIntegrityCheck` | `void` | ⭐⭐ | Provera celovitosti |

### ml_finance_autonomous_service.dart
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `toggleAutopilot` | `void` | ⭐⭐⭐ | Automatsko plaćanje |
| `_loadHistoricalMemory` | `Future<void>` | ⭐⭐ | Istorija |
| `recordMilestone` | `void` | ⭐⭐ | Milstone logovanje |
| `_generateAdvice` | `Future<String>` | ⭐⭐ | AI saveti |

### ml_vehicle_autonomous_service.dart
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `stop` | `void` | ⭐⭐ | Zaustavi monitoring |
| `_subscribeToRealtimeChanges` | `void` | ⭐⭐⭐ | Realtime |
| `_discoverPotentialNewTables` | `Future<void>` | ⭐⭐ | Špekulacija |
| `_learnNewColumns` | `Future<void>` | ⭐⭐ | Učenja |

---

## 🔐 AUTENTIFIKACIJA & SIGURNOST

### auth_service.dart
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `loginWithPin` | `Future<bool>` | ⭐⭐⭐⭐ | **KRITIČNA** - login |
| `logout` | `Future<void>` | ⭐⭐⭐ | Logout |
| `getCurrentUser` | `User?` | ⭐⭐⭐ | Trenutni korisnik |
| `validatePin` | `bool` | ⭐⭐⭐ | Validacija PIN |

---

## 🌍 LOKACIJA & NAVIGACIJA

### driver_location_service.dart
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `_startStreamTracking` | `void` | ⭐⭐⭐ | GPS tracking |
| `getCurrentLocation` | `Future<LocationData>` | ⭐⭐⭐ | Trenutna lokacija |
| `dispose` | `void` | ⭐⭐ | Cleanup |

### here_wego_navigation_service.dart
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `startNavigation` | `Future<void>` | ⭐⭐⭐ | Počni navigaciju |
| `stopNavigation` | `void` | ⭐⭐⭐ | Zaustavi |
| `isNavigating` | `bool` | ⭐⭐ | Stanje |

---

## 📱 NOTIFIKACIJE

### realtime_notification_service.dart
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `sendNotificationToAllDrivers` | `Future<void>` | ⭐⭐⭐⭐ | **KRITIČNA** - obavesti |
| `sendDirectNotification` | `Future<void>` | ⭐⭐⭐ | Direktna obavest |
| `listenForNotifications` | `Stream` | ⭐⭐⭐ | Realtime listen |

### huawei_push_service.dart
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `initialize` | `Future<void>` | ⭐⭐⭐ | Inicijalizacija |
| `sendPushNotification` | `Future<void>` | ⭐⭐⭐ | Pošalji push |
| `_setupMessageListener` | `void` | ⭐⭐ | Setup listener |

---

## 🗓️ RESETOVANJE & SCHEDULING

### weekly_reset_service.dart
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `_executeWeeklyReset` | `Future<void>` | ⭐⭐⭐⭐ | **KRITIČNA** - reset |
| `_resetSchedules` | `Future<void>` | ⭐⭐⭐ | Resetuj termine |
| `_resetPayments` | `Future<void>` | ⭐⭐⭐ | Resetuj plaćanja |

---

## 🔄 CACHE UPRAVLJANJE

### cache_service.dart
| Funkcija | Tip | Ponos | Opis |
|----------|-----|--------|------|
| `set` | `Future<void>` | ⭐⭐ | Postavi cache |
| `get` | `T?` | ⭐⭐ | Uzmi cache |
| `clear` | `Future<void>` | ⭐⭐ | Obriši cache |
| `clearAll` | `Future<void>` | ⭐⭐ | Obriši sve |

---

## 🗂️ QUICK LOOKUP TABELA

### Po Kategoriji
```
KRITIČNE (❌ Ne meniaj bez razloga):
- oznaciPokupljen()
- otkaziPutnika()
- azurirajPlacanjeZaMesec()
- logGeneric()
- sendNotificationToAllDrivers()
- _executeWeeklyReset()
- loginWithPin()

VAŽNE (⚠️ Pazi pri izmeni):
- putnik_card.dart > build()
- kombi_eta_widget.dart > build()
- streamKombinovaniPutniciFiltered()
- getAktivniRegistrovaniPutnici()
- _startStreamTracking()

POMOĆNE (✅ Safe za izmenu):
- _calculateDistance()
- _formatText()
- _isValid...()
- _calculate...()
- _get...()
```

### Po Tipu
```
STREAM FUNKCIJE (Realtime):
- streamKombinovaniPutniciFiltered()
- streamAktivniRegistrovaniPutnici()
- streamSviVozaci()
- listenForNotifications()

ASYNC FUNKCIJE (Future):
- oznaciPokupljen()
- otkaziPutnika()
- azurirajPlacanjeZaMesec()
- getPutniciByDayIso()

WIDGET FUNKCIJE (UI):
- build() u svim widget datotekama
- _buildContainer()
- _buildHeader()
- _buildBody()
```

---

## 🚀 PREČICE ZA ČESTE TASKOVE

### "Trebam da pronađem gde se putnik označava kao pokupljen"
```
Ctrl+Shift+F > "oznaciPokupljen" > Enter
```

### "Trebam da vidim sve pozive funkcije X"
```
Ctrl+P > datoteka.dart
F12 na funkciji ili
Ctrl+Shift+H na funkciji
```

### "Trebam da preimenujem funkciju"
```
F2 na funkciji - automatski se preimenovavaju SVE reference
```

### "Trebam da vidim sve async funkcije u fajlu"
```
Ctrl+Shift+O > type "Future"
ili
Ctrl+F > Future< (u tome fajlu)
```

---

## 📈 FUNKCIJE PO BROJU REFERENCI

```
10+ reference = SUPER VAŽNA:
- logGeneric() - 11

5-9 reference = VAŽNA:
- oznaciPokupljen() - 5
- azurirajPlacanjeZaMesec() - 5
- sendNotificationToAllDrivers() - 5
- streamKombinovaniPutniciFiltered() - 8

2-4 reference = SREDNJA:
- _executeWeeklyReset() - 4
- updatePutnik() - 4
- otkaziPutnika() - 3
- getAktivniRegistrovaniPutnici() - 3

0-1 reference = POMOĆNA:
- _sacuvajPlacanjeStatic() - 2
- _calculateDistance() - 1
```

**Pronalaženje:** `Ctrl+Shift+H` na svakoj funkciji da vidiš broj referenci

---

## 💎 ZAKLJUČAK

Koristi ove alate:
1. **Ctrl+F** - brza pretraga u fajlu
2. **Ctrl+Shift+H** - sve reference funkcije
3. **F12** - idi na definiciju
4. **F2** - preimenujem svugde
5. **Ctrl+P** - pronađi fajl
6. **Ctrl+Shift+O** - outline svih funkcija

**Sada možeš brzo da pronađeš bilo koju funkciju! 🎯**
