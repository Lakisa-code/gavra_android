# ⏰ TIME PICKER PRAVILA — ADMIN vs PUTNIK

> **Ovo je autoritativni dokument.** Svaka promena logike u `TimePickerCell` mora biti konzistentna sa ovim pravilima.
> Fajl: `lib/widgets/shared/time_picker_cell.dart`

---

## 1. ZAJEDNIČKO (važi za SVE korisnike)

| Situacija | Ponašanje |
|---|---|
| Klik na cel — `pending` i ADMIN | ✅ Otvara se picker (admin nije blokiran) |
| Klik na cel — `pending` i NIJE admin | **BLOKIRANO** → „Vaš zahtev je već u obradi" |
| Klik na cel — `rejected` i NIJE admin | **BLOKIRANO** → „Ovaj termin je popunjen" |
| Tip putnika = `posiljka` | **NIKAD zaključano** — pošiljke se zakazuju uvek |

---

## 2. ADMIN (`isAdmin = true`)

Admin **nema nikakvih vremenskih ograničenja**. Sve je otvoreno u svakom trenutku.

| Situacija | Ponašanje admina |
|---|---|
| Dan je u prošlosti | ✅ Može da menja |
| Vreme je prošlo | ✅ Može da menja |
| Dan zaključan (`isLocked = true`) | ✅ Može da menja |
| Dnevni putnik — sutra ili kasniji dan | ✅ Može da zakazuje |
| Status `pending` | ✅ Može da menja |
| Status `rejected` | ✅ Može da menja |
| „Bez polaska" klik (ima zakazano vreme) | Briše vreme → poruka: _„Vreme polaska je obrisano."_ |
| „Bez polaska" klik (već prazno) | Poruka: _„Vreme polaska je već prazno."_ |
| Prošla vremena u listi | ✅ Prikazana i klikabilna (bez precrtavanja) |

### ⚠️ KONZISTENTNOST ADMIN AKCIJA (zacementirano)

> **Svaka promena koju admin napravi kroz bilo koji time picker ili ekran mora biti identična po efektu.**

- Nije bitno odakle admin menja (profil putnika, dodeli putnike, home screen, admin screen) — rezultat u bazi mora biti **isti**
- „Bez polaska" postavljen od strane admina → uvek se tretira kao **tiho brisanje** vremena (nije otkazivanje, **ne upisuje se u `voznje_log`** kao otkazano, status = `bez_polaska`)
- Novo vreme postavljeno od strane admina → odmah `confirmed`, **bez zahteva**, bez pending faze
- Promena se mora **odmah reflektovati** na svim ekranima koji prikazuju tog putnika (stream refresh)

### 📍 Admin ekrani koji koriste TimePickerCell

| Ekran | `isAdmin` | Null vreme (bez polaska) |
|---|---|---|
| `registrovani_putnik_profil_screen.dart` | ✅ `true` | `ukloniPolazak()` → `bez_polaska` |
| `putnik_card.dart` (home screen X) | — | `ukloniPolazak()` → `bez_polaska` |

> **ZABRANJENA GREŠKA**: Nikad ne pozivati `otkaziPutnika()` kada je admin kliknuo „Bez polaska". `otkaziPutnika()` je isključivo za putnike koji sami otkazuju (evidentira se u `voznje_log`).

---

## 3. PUTNIK (`isAdmin = false`)

Putnik ima stroge vremenske blokade.

### 3a. Zaključavanje celog dana (`isLocked`)

Dan je **zaključan** ako:
- Dan je **pre danas** (prošlost)

> Subota ≥ 02:00 = **nova nedelja** → svi dani (pon–pet) se računaju za sledeću nedelju.

Kada je zaključan i putnik klikne:
- Ima zakazano vreme → **zaključano**, nije klikabilno (vreme polaska je prošlo)
- Nema zakazano vreme → **zaključano**, prikazuje poruku `„🔒 Zakazivanje za ovo vreme je prošlo. Od subote kreće novi ciklus."`

### 3b. Lock NA VREME POLASKA (zacementirano)

> **Svaki time picker se zaključava tačno u trenutku polaska i ostaje zaključan sve do subote u 02:00.**

- Ćelija se **zaključava u trenutku polaska** (ne 10 min pre, ne posle — tačno na vreme polaska)
- Zaključana ostaje **neprekidno** sve dok ne dođe subota ≥ 02:00 (nova nedelja)
- **Nema privremenog otključavanja** između termina u toku dana
- **Status `approved` ili `confirmed` NE zaključava ćeliju** — putnik uvek može da klikne i pošalje zahtev za promenu
- Zaključava isključivo **prošlost** (prošlo vreme polaska + subota do 02:00)

### 3c. Individualno zaključavanje vremena u listi

Svako vreme u listi proverava `_isSpecificTimePassed(vreme)`:
- Dan je u prošlosti → **sva vremena disabled**
- Danas → disabled ako `now.hour > vreme.hour || (now.hour == vreme.hour && now.minute >= vreme.minute)`

Disabled vreme:
- Tekst: bela/38% opacity + ~~precrtano~~
- Ikonica: lokot (`Icons.lock_clock`) bela/38%
- Subtitle: `„⏰ Vreme je prošlo"`
- `onTap = null`

### 3d. Dnevni putnici (`tipPutnika == 'dnevni'` ili `tipPrikazivanja == 'DNEVNI'`)

Dnevni putnici mogu zakazivati **samo za tekući dan i sutrašnji dan**.

- Ako klikne na zaključani dan → `„Zbog optimizacije kapaciteta, rezervacije za dnevne putnike su moguće samo za tekući dan i sutrašnji dan."` → return
- Ova blokada se proverava **na dva mesta** (pre otvaranja dijaloga + unutar onTap ćelije)

### 3e. „Bez polaska" — za putnike = OTKAZIVANJE

| Stanje | Poruka |
|---|---|
| Ima zakazano vreme → klikne „Bez polaska" | `„Vožnja otkazana. Evidentirano kao otkazivanje."` (narandžasto warning) |
| Već prazno → klikne „Bez polaska" | `„Vreme polaska je već prazno."` (info) |

- Subtitle u listi: `„⚠️ Računa se kao otkazana vožnja"` (narandžasto, 11px)
- Ikonica „Bez polaska": crvena (`Colors.red.shade300`) kad ima vreme; zelena kad je prazno

---

## 4. STATUS BOJE (ćelija u grid-u)

| Status | Boja ćelije | Boja teksta | Ivica |
|---|---|---|---|
| `otkazano` (`isCancelled=true`) | `red.shade50` | `red.shade800` | crvena, 2px |
| `rejected` | `red.shade50` | `red.shade900` | `orange.shade800`, 1px |
| zaključano (prošlost) | `grey.shade200` | `grey.shade600` | `grey.shade400` |
| `approved` / `confirmed` | `green.shade50` | `green.shade800` | zelena |
| `pending` / `manual` | `orange.shade200` | `orange.shade900` | narandžasta, 2px |
| ima vreme (bez statusa) | `green.shade50` | `green.shade800` | zelena |
| prazno | bela | crna/87% | siva |

---

## 5. IKONE U ĆELIJI

| Stanje | Ikona |
|---|---|
| `isCancelled` | `Icons.cancel` (crvena) |
| `rejected` | `Icons.error_outline` |
| `pending` / `manual` | `Icons.hourglass_empty` |
| `approved` | `Icons.check_circle` |
| `confirmed` ili ima vreme bez statusa | `Icons.check_circle` |
| prazno | `Icons.access_time` |

---

## 6. SEZONA (ruta/vozni red)

Vremena u pickeru dolaze iz `RouteService.getVremenaPolazaka(grad, sezona)`.

Sezona se određuje iz globalnog `navBarTypeNotifier`:

| `navBarTypeNotifier.value` | Sezona |
|---|---|
| `'praznici'` | `praznici` |
| `'zimski'` | `zimski` |
| sve ostalo | `letnji` (default) |

---

## 7. NIKAD NE MENJAJ

1. **Admin uvek može sve** — nema blanket blokada za admina.
2. **Putnik može da traži promenu vremena samo dok vreme polaska još nije nastupilo** — čim nastupi vreme polaska, ćelija je zaključana do subote 02:00, bez izuzetka.
3. **Pošiljke nikad nisu zaključane** — proveravaj `tipPutnika == 'posiljka'` na prvom mestu.
4. **Lock = tačno na vreme polaska** (ne pre, ne posle). `approved`/`confirmed` status NE zaključava ćeliju.
5. **Nova nedelja kreće subotom u 02:00** — ne u ponoć, ne u petak.
6. **„Bez polaska" za putnika = otkazana vožnja** — uvek se evidentira.
