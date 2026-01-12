# Smart Sistem

## 📊 Trenutno stanje

- **76 putnika** ukupno (ponedeljak BC)
- **Kapacitet je DINAMIČAN** - admin podešava po terminu
- Tabela `kapacitet_polazaka` u Supabase

---

## ✅ VEĆ IMPLEMENTIRANO

### 1. `SeatRequestService` (lib/services/seat_request_service.dart)
- Kreiranje zahteva (`createRequest`)
- Statusi: `pending`, `approved`, `needsChoice`, `waitlist`, `cancelled`, `expired`
- Prioritet putnika (tip + kvalitet)
- Batch processing (automatski svakih X minuta)
- Manual mode (admin preuzima kontrolu)
- Optimizacija - balansiranje po terminima
- Notifikacije kad se odobri/predloži alternativa
- Lista čekanja ako je puno

### 2. `SeatManagementScreen` (lib/screens/seat_management_screen.dart)
- Admin vidi sve zahteve po danu/gradu
- Odobrava/odbija pojedinačno
- Batch processing dugme "Procesiraj (X)"
- Tab za optimizaciju

### 3. Tabela `seat_requests` (Supabase)
- `putnik_id`, `grad`, `datum`, `zeljeno_vreme`
- `dodeljeno_vreme` (ako je drugačije od željenog)
- `status`, `priority`, `alternatives`
- `batch_id`, `processed_at`

### 4. Admin alati
- **Kapacitet po terminu** - admin menja ručno (`kapacitet_polazaka`)
- **Brojač đaka** - realtime na `danas_screen` (ostalo/ukupno)

---

## 🔔 Notifikacije učenicima

### Kad se šalju?

| Status | Notifikacija | Poruka |
|--------|-------------|--------|
| `approved` | ✅ Odobreno | "Odobreno! ✅ Tvoj polazak je u XX:XX" |
| `needsChoice` | 🔄 Alternativa | "Željeno vrijeme nije dostupno, izaberi drugo" |
| `waitlist` | ⏳ Lista čekanja | "Na listi čekanja si. Javimo ti ako se oslobodi mjesto" |

### Implementacija:
- `_sendApprovalNotification()` - kad je odobreno
- `_sendChoiceNotification()` - kad treba izabrati alternativu
- Koristi Huawei Push / FCM preko `RealtimeNotificationService`

### Tok:
```
Batch processing završen
  ↓
Za svakog putnika:
  → approved? → _sendApprovalNotification()
  → needsChoice? → _sendChoiceNotification()
  → waitlist? → (notifikacija za waitlist - TODO)
```

---

## 🤖 Smart sistem - pravila

### Aktivacija
- **Automatski u pozadini** - uvek aktivan, radi non-stop

### Vremenski opseg
- **Samo tekući dan** - procesira zahteve samo za današnji datum
- **Samo VS pravac** - BC se zakazuje dan prije (do 16h), admin ručno
- Ne gleda sutra niti prethodne dane

### Razdvojena logika BC vs VS

**BC (odlazak u školu):**
- Zahtevi stižu **do 16:00h** dan prije
- Admin ručno upravlja rasporedom
- Smart sistem NE procesira BC (samo tekući dan)

**VS (povratak iz škole):**
- Zahtevi stižu ujutru za danas popodne
- Smart sistem automatski odlučuje (vidi dole)
- Škola se završava 13-14h

---

## 🤖 Smart VS algoritam (povratak iz škole)

### Automatska odluka = Vreme + Popunjenost

Sistem **sam gleda oba faktora** i odlučuje koliko brzo da odobri:

| Vreme | Popunjenost | Akcija |
|-------|-------------|--------|
| Pre 10:00 | < 50% | ✅ Odobri brzo (5 min) |
| Pre 10:00 | > 50% | ⏳ Uspori (15 min) - nešto se dešava |
| 10:00-11:30 | < 80% | 🔄 Batch svakih 15 min |
| 10:00-11:30 | > 80% | ⏸️ Čekaj do 11:30 - skoro puno |
| Posle 11:30 | bilo koja | 🏁 Finalni batch - šta ima, ima |

### Prednosti:
- ❌ Nema utrkivanja "ko prvi klikne"
- ✅ Sistem sam prilagođava brzinu
- ✅ Admin ne mora da razmišlja
- ✅ Fer za sve učenike

*(Plan za implementaciju - može se prilagoditi na osnovu prakse)*

---

### Kapacitet
- **Prati kapacitet koji admin postavi** - ne menja ga automatski

### Ograničenja po tipu putnika

**Učenik:**
- Promene dozvoljene samo do **16:00h**
- Max **1 promena** po pravcu/danu

**Radnik / Dnevni:**
- Bez ograničenja

### Ograničenja po pravcu (BC vs VS)

| Pravac | Kad zakazuje | Za kad zakazuje | Deadline zakazivanja |
|--------|--------------|-----------------|----------------------|
| **BC** (odlazak) | Dan prije | Sutra ujutru | Do **16:00h** dan prije |
| **VS** (povratak) | Ujutru | Danas popodne | Do **10 min** prije polaska (max 16:00h) |

**Primer BC:**
- Nedelja do 16:00 → učenik zakaže za ponedeljak 7:00
- Posle 16:00 nedelja → prekasno, ne može zakazati BC za ponedeljak

**Primer VS:**
- Ponedeljak 8:00 → učenik zakaže povratak za 13:00
- Može promeniti do 12:50 (10 min prije) ili do 16:00h - šta god dođe prije
- Ako je termin 17:00 → rok je 16:00h (ne 16:50)

*(Implementirano u `slobodna_mesta_service.dart` - ⚠️ POTREBNO RAZDVOJITI BC/VS LOGIKU)*

---

## ⏰ Zakasneli zahtevi (deadline logika)

### Deadline = 10 minuta prije polaska

Funkcija `isDeadlinePassed()` provjerava da li je prošao rok.

### Hibridni pristup

| Situacija | Slobodna mjesta? | Akcija |
|-----------|------------------|--------|
| Zahtev stigao **prije** deadline-a | ✅ / ❌ | Normalno procesiranje |
| Zahtev stigao **nakon** deadline-a | ✅ Da | ✅ Dozvoli (direktno odobri) |
| Zahtev stigao **nakon** deadline-a | ❌ Ne (puno) | ❌ Odbij zahtev |

### Logika:
```
ako (deadline_prošao) {
  ako (ima_slobodnih_mjesta) {
    → Odobri odmah (nema smisla čekati)
  } inače {
    → Odbij: "Žao nam je, termin je popunjen"
  }
} inače {
  → Normalno procesiranje (pending → batch)
}
```

### Zašto hibrid?
- ✅ Fer za one koji se jave na vrijeme
- ✅ Fleksibilno ako ima mjesta
- ❌ Nema "utrkivanja u zadnji čas" za pune termine

*(Implementacija: Dodati provjeru u `createRequest` funkciju)*

---

## 📱 Workflow - kako učenik traži povratak

### Korak 1: Učenik otvara app i bira termin
```
Odaberite termin povratka:
○ 12:00
○ 13:00
○ 14:00
○ 15:30
○ 17:00
```
**❌ NE vidi broj slobodnih mesta** - da se ne utrkuju


### Korak 2: Učenik klikne na termin
- ✅ "Vaš zahtev je primljen"
- **NE** dobije odmah potvrdu da je upisan
- Zahtev ide u "čekaonicu" (status: `pending`)

### Korak 3: Smart sistem skuplja zahteve
- Čeka određeno vreme dok se skupe zahtevi
- Admin ima vremena da vidi celu sliku

### Korak 4: Optimizacija
- Smart sistem **balansira** zahteve po terminima
- Ako je 13:00 prepun → preraspodeljuje na 14:00 ili 15:30
- Admin pregleda i odobri (ili koristi batch processing)

### Korak 5: Potvrda učenicima
- Učenik dobije notifikaciju: "Vaš povratak je potvrđen za 13:00"
- Status se menja u `approved`

---

## 🔒 PRAVILO: Slobodna mesta su SKRIVENA od učenika

**Učenik NE VIDI slobodna mesta - NIGDE i NI U KOM OBLIKU!**

- ❌ Ne vidi broj slobodnih mesta
- ❌ Ne vidi "popunjeno" / "ima mesta"
- ❌ Ne vidi procenat popunjenosti
- ✅ Vidi samo listu termina - svi izgledaju isto
- ✅ Može da klikne na bilo koji termin i pošalje zahtev

**Razlog:** Da se ne utrkuju "ko prvi klikne"

**Napomena:** Na `registrovani_putnici` ekranu se ovo već ne vidi - OK!

~~`SeatRequestWidget`~~ - **OBRISANO** (nije se koristio nigdje u projektu)

---

## 🧠 Inputi za algoritam

| Input | Status | Važnost |
|-------|--------|---------|
| Kapacitet po terminu (admin) | ✅ Ima | 🔴 Kritično |
| Slobodna mesta po terminu | ✅ Ima (samo za algoritam) | 🔴 Kritično |
| Tip putnika (učenik/radnik) | ✅ Ima | 🟡 Visoka |
| Prioritet putnika | ✅ Ima | 🟡 Visoka |
| Istorija putovanja | ❌ Nema | 🟢 Bonus (za 2-3 nedelje) |

---

## 💡 Napomena

- Učenik = povratak 13:00-15:00 (kraj škole)
- Radnik = povratak zavisi od smene
- Algoritam koristi tip putnika za pametnije predloge

---

## 📅 Plan

1. **Danas:** Koristi admin kapacitet, svi termini ravnopravni
2. **Za 2-3 nedelje:** Dovoljno istorije za predikcije i obrasce

