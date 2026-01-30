# Detaljna analiza anomalije seat_requests vs voznje_log

## Anomalija identifikovana

**Problem:** Nekonzistentnost između tabela
- **voznje_log** ima 7 zakazivanja za 29.01.2026
- **seat_requests** ima samo 2 zahteva za isti datum
- **Razlika:** 5 zahteva postoji samo u logu

## Dubinska analiza

### 1. Funkcije tabela

**seat_requests:**
- **Namenjenje:** Privremena tabela za zahteve koji čekaju automatsku obradu
- **Životni ciklus:** pending → confirmed → briše se nakon vožnje/obrade
- **Korišćenje:** Automatski sistemi za raspodelu sedišta
- **Kolona status:** 'pending', 'confirmed'
- **Obrada:** ML Dispatch Autonomous Service čita zahteve

**voznje_log:**
- **Namenjenje:** Trajna istorija SVIH aktivnosti sistema
- **Životni ciklus:** Trajno čuvanje
- **Korišćenje:** Admin panel, statistike, monitoring
- **Tipovi:** 'zakazivanje_putnika', 'potvrda_zakazivanja', 'voznja', 'otkazivanje' itd.
- **Meta podaci:** Detaljne informacije o aktivnosti

### 2. Kôd analiza

**Kada se insertuje u seat_requests:**
- U `registrovani_putnik_profil_screen.dart` `_updatePolazak()`
- Poziva se `_insertSeatRequest()` za:
  - BC zahtevi (učenici, radnici, dnevni)
  - VS zahtevi (svi tipovi putnika)

**Kada se loguje u voznje_log:**
- U istom kodu, poziva se `VoznjeLogService.logZahtev()`
- Takođe u `local_notification_service.dart` za "waiting" status (samo log, bez seat_requests)

### 3. Uzrok anomalije

**Identifikovani uzroci:**

1. **Različiti tokovi zakazivanja:**
   - **Profil ekran:** Insert u seat_requests + log
   - **Push notifikacije:** Samo log (bez seat_requests)
   - **Automatizovani sistemi:** Mogu samo logovati

2. **Problem sa datumima:**
   - `seat_requests` koristi `_getNextDateForDay()` - daje sledeći dan u nedelji
   - `voznje_log` koristi `DateTime.now()` - uvek današnji datum
   - Za zahtev za "cet" (četvrtak) kada je danas srijeda → seat_requests dobija 30.01, log 29.01

3. **Brisanje obrađenih zahteva:**
   - seat_requests se brišu nakon potvrde/vožnje
   - voznje_log ostaje kao istorija
   - Ivana Vincilov ima potvrđen zahtev → seat_request obrisan, log ostao

### 4. Primer anomalije - Ivana Vincilov

**Zakazivanje 29.01 u 09:00:**
- **seat_requests:** Nema zapis (obrisan nakon potvrde)
- **voznje_log:** Ima 2 zakazivanja za cet 12:00 vs
- **Potvrda:** Sistem potvrdio u 10:07
- **Rezultat:** Zahtev vidljiv samo u logu

### 5. Rešenja

**Preporučena rešenja:**

1. **Unifikacija logike:**
   ```dart
   // U svim mestima gde se loguje zakazivanje, dodati:
   await _insertSeatRequest(putnikId, dan, vreme, grad);
   ```

2. **Konzistentnost datuma:**
   ```dart
   // Koristiti istu logiku za datum u obe tabele
   final datum = _getNextDateForDay(DateTime.now(), dan);
   ```

3. **Cleanup obrađenih zahteva:**
   ```dart
   // Nakon potvrde, obrisati seat_request
   await supabase.from('seat_requests')
     .delete()
     .eq('putnik_id', putnikId)
     .eq('grad', grad)
     .eq('datum', datum);
   ```

4. **Prikaz u admin panelu:**
   - Dodati prikaz seat_requests u admin_zahtevi_screen
   - Kombinovati podatke iz obe tabele

### 6. Zaključak

**Anomalija je sistemska greška** u dizajnu:
- Nedosledno beleženje zahteva
- Različite logike za datume
- Nedostatak cleanup-a

**Rešenje:** Unifikovati tokove i dodati odgovarajući cleanup kod.