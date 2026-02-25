# Seat Requests — Pravila i Analiza

> ⛔ **Zabranjeno je menjati bilo koji kod vezan za seat_requests bez eksplicitnog odobrenja vlasnika projekta.**

---

## 1. Šta je `seat_requests`?

Operativna tabela. Svaki red = jedan nedeljni termin jednog putnika.

**Jedinstveni ključ:** `putnik_id + grad + dan + zeljeno_vreme`  
➠️ **NOVI PRINCIP (25.02.2026):** Putnik **može** imati više različitih termina za **isti dan i grad**.  
Primer: Putnik može zakazati 07:00 i 15:00 za BC u ponedeljak — svaki zahtev se obrađuje **posebno**.  

Nije istorijska tabela — istorija se čuva u `voznje_log`.  
Stari redovi se **ne brišu automatski** (cron za brisanje je uklonjen 2026-02-23).

---

## 2. Kolone tabele

| Kolona | Tip | Opis |
|---|---|---|
| `id` | uuid | PK |
| `putnik_id` | uuid FK → `registrovani_putnici` | Ko je putnik (CASCADE DELETE) |
| `grad` | text | `'BC'` ili `'VS'` (uvek uppercase) |
| `dan` | text | Kratica dana: `pon`, `uto`, `sre`, `cet`, `pet`, `sub`, `ned` (uvek lowercase) |
| `zeljeno_vreme` | time | Vreme koje je putnik zatražio |
| `dodeljeno_vreme` | time | Vreme koje je stvarno dodeljeno (NULL dok nije odobreno) |
| `status` | text | Videti sekciju 3 |
| `priority` | integer | Default 1; >1 = prioritetni putnik (prikazuje se badge u UI) |
| `broj_mesta` | integer | Default 1; koliko mesta zauzima ovaj putnik |
| `alternative_vreme_1` | time | Slobodan termin PRE željenog (popunjava dispecer pri rejection) |
| `alternative_vreme_2` | time | Slobodan termin POSLE željenog (popunjava dispecer pri rejection) |
| `custom_adresa_id` | uuid FK → `adrese` | Custom adresa (SET NULL on delete) |
| `tip_putnika` | text | Kopija `tip` iz `registrovani_putnici` — automatski se kopira triggerom `trg_sync_tip_putnika` |
| `pokupljeno_by` | text | Ime vozača koji je označio putnika kao pokupljenog |
| `cancelled_by` | text | Ime vozača koji je otkazao vožnju |
| `created_at` | timestamptz | Kada je zahtev kreiran |
| `updated_at` | timestamptz | Poslednja izmena |
| `processed_at` | timestamptz | Kada je dispecer obradio zahtev |

> **Napomena:** `vozac_id` (UUID FK) **NE postoji** u `seat_requests` — čuva se **SAMO u `voznje_log`** audit tabeli (vidi sekciju Arhitektura).  
> U operacionoj tabeli dovoljni su `pokupljeno_by` i `cancelled_by` (text imena) za prikaz.

---

## 3. Statusi

| Status | Značenje | Ko postavlja |
|---|---|---|
| `pending` | Čeka obradu od strane digitalnog dispečera. Za `tip = 'dnevni'` — dispecer preskače, admin odobrava ručno. | Flutter app (`insertSeatRequest`) |
| `approved` | Odobren od dispečera ili admina | Dispecer SQL / `approveRequest()` / `acceptAlternative()` |
| `confirmed` | Admin je uneo vreme za putnika u "Uredi" dijalogu — odmah odobren bez čekanja | `_syncSeatRequestsWithTemplate` (poziva se automatski nakon čuvanja u "Uredi") |
| `rejected` | Odbijen — termin pun | Dispecer SQL (`obradi_seat_request`) |
| `otkazano` | Putnik otkazao vožnju | Vozač iz app-a (`putnik_service.dart`) |
| `cancelled` | Sistemski otkazano (npr. prihvatanje alternative) | `acceptAlternative()` u Dart kodu |
| `pokupljen` | Vozač potvrdio da je putnik ukrcan | Vozač iz app-a |
| `bez_polaska` | Putnik nema polazak (deaktiviran, ili eksplicitno) | `toggleAktivnost()` / admin |

---

## 4. Pravila čekanja (zacementirana 21.02.2026)

Važe za auto-obradu u `dispecer_cron_obrada()` → `get_cekanje_pravilo()`.

| Grad | Tip putnika | Čekanje | Provjera kapaciteta |
|---|---|---|---|
| BC | radnik | 5 min | DA |
| BC | učenik (zahtev poslat **pre** 16:00) | 5 min | **NE** — garantovano mesto |
| BC | učenik (zahtev poslat **posle** 16:00) | čeka do 20:00h | DA |
| BC | pošiljka | 5 min | **NE** (ne zauzima mesto) |
| BC | ostalo (default) | 5 min | DA |
| VS | radnik | 10 min | DA |
| VS | učenik | 10 min | DA |
| VS | pošiljka | 5 min | **NE** (ne zauzima mesto) |
| VS | ostalo (default) | 10 min | DA |
| **dnevni** | *svi gradovi* | **NIKAD auto-obrada** | — → ostaje `pending`, admin odobrava ručno |

> **Napomena:** Vreme čekanja meri se od `updated_at` reda (svaki novi zahtev ili promena termina resetuje `updated_at` i čekanje kreće iznova).  

> **UI blokada (25.02.2026):** Blokira se ponovni klik **samo na ISTO** `dan+grad+vreme` dok je status `pending` — prikazuje se poruka *"⏳ Vaš zahtev za ovo vreme je već u obradi. Molimo sačekajte odgovor."*  
> **Putnik MOŽE** imati više različitih termina za **isti dan** (npr. PON BC 05:00 + PON BC 18:00) — svaki se obrađuje **nezavisno**.  
> Blokada je u `time_picker_cell.dart`: `if (isPending && hasTime && !isAdmin) return;`  
> Admin nije blokiran.

---

## 5. Kapacitet

Funkcija `proveri_slobodna_mesta(grad, vreme, dan)`:
- Uzima `max_mesta` iz tabele `kapacitet_polazaka` (default 8 ako nema zapisa).
- Od toga oduzima `SUM(broj_mesta)` svih aktivnih zahteva za isti `dan + grad + zeljeno_vreme` sa statusima: `pending`, `manual`, `approved`, `confirmed`.
- Vraća slobodan broj mesta.

---

## 6. Logika upisivanja (Flutter `insertSeatRequest`)

1. Normalizuje `grad` (uppercase) i `vreme`.
2. **UPSERT po `putnik+grad+dan+VREME`** — svaki termin je **nezavisan**:
   - Ako postoji zahtev za **isti** `putnik+grad+dan+vreme` → ažurira se (status, broj_mesta, priority, custom_adresa_id).
   - Ako ne postoji → kreira se **novi** red (ne briše druge termine za taj dan).
   - `confirmed` status se čuva ako već postoji, ili se postavlja ako je eksplicitno proslijeđen.
3. Loguje u `voznje_log` tip `'zakazano'`.

**Promjena (25.02.2026):** Prije ove izmjene, upisivanje novog termina je **brisalo SVE** termine za `putnik+grad+dan`.  
Sada se **čuva više termina** za isti dan, svaki se obrađuje posebno.

---

## 7. Logika `_syncSeatRequestsWithTemplate` (sinhronizacija iz "Uredi")

Poziva se automatski kada admin sačuva izmene u "Uredi putnika" dijalogu.

- Ako ima vreme za `dan+grad` → kreira ili ažurira zahtev sa statusom `confirmed`.
- Ako je vreme prazno → **ne dira** postojeće termine (ne briše, ne postavlja `bez_polaska`).

---

## 8. Prihvatanje alternative (`acceptAlternative`)

Kada putnik prihvati alternativni termin (iz push notifikacije):

1. Otkaže se **samo originalni zahtev** (requestId) → status `cancelled`.
2. Isti red se **ažurira** sa: `zeljeno_vreme = novo vreme`, `dodeljeno_vreme = novo vreme`, `status = approved`. **Nema čekanja — putnik je odmah aktivan.**
3. **Ostali termini** (ako ih ima) za isti dan **ostaju netaknuti**.

**Promjena (25.02.2026):** Prije ove izmjene, prihvatanje alternative je **otkazivalo SVE** termine za `putnik+grad+dan`.  
Sada se otkazuje **samo konkretni originalni zahtev**, ostali se čuvaju.

---

## 9. Odobravanje i odbijanje (ručno, admin)

`approveRequest(id)`:
- Status → `approved`
- `dodeljeno_vreme = zeljeno_vreme`
- Puni `processed_at` i `updated_at`

`rejectRequest(id)`:
- Status → `rejected`
- Puni `processed_at` i `updated_at`
- Alternative **ne popunjava** ovde — popunjava ih `obradi_seat_request()` u SQL-u.

---

## 10. Push notifikacije (trigger `notify_seat_request_update`)

Okida se na svaku promenu statusa u tabeli.

| Status | Ko prima notifikaciju |
|---|---|
| `approved` | Putnik |
| `rejected` (bez alternativa) | Putnik |
| `rejected` (sa alternativama) | Putnik (sa dugmadima za izbor) |
| `pending` (dnevni/pošiljka) | Admin (Bojan) |
| `otkazano` | Svi vozači (osim onog koji je otkazao) |

---

## 11. Šta se prikazuje u `SeatRequestsScreen` (admin ekran)

- Prikazuje `pending` zahteve gde je `tip_putnika = 'dnevni'` ili `tip_putnika = 'posiljka'` (realtime stream).
- `tip_putnika` kolona u tabeli se automatski kopira triggerom `trg_sync_tip_putnika` iz `registrovani_putnici`.
- Admin može: **ODOBRI** (`approved`) ili **ODBIJ** (`rejected`).

---

## 12. Indeksi na tabeli

```
idx_seat_requests_putnik_id
idx_seat_requests_custom_adresa_id
idx_seat_requests_dan
idx_seat_requests_status
```

---

## 13. Arhitektura — Dve tabele

### 📋 `seat_requests` (operaciona tabela)
- Čuva aktivne zahteve za **tekuću nedelju**.
- Brzo procesiranje, mali dataset.
- **Kolone:** osnovni podaci + `pokupljeno_by`, `cancelled_by` (text imena).
- **Nema:** `vozac_id` FK, `placeno`, `placeno_at`, `kupovina_datum`.

### 🗄️ `voznje_log` (audit/istorijska tabela)
- Trajno čuva **SVE** vožnje.
- **Dodatne kolone:** `vozac_id` UUID FK → `vozaci`, `placeno`, `placeno_at`, `kupovina_datum`.
- Koristi se za računovodstvo, izveštaje, punu audit trail.

> **Razlog:** `seat_requests` je optimizovan za brzinu — ne treba mu FK na `vozaci` jer se ime vozača čuva u text polju.  
> Istorijski UUID link postoji **SAMO** u `voznje_log` gde je potreban za trajne zapise i finansijske izveštaje.

---

## 14. Ključna zabranjena pravila (ne menjati bez odobrenja)

1. `confirmed` status je isključivo adminova privilegija. Kada putnik promeni vreme, `confirmed` se briše i kreira se novi `pending` — ista logika kao za sve ostale statuse. Putnik ne može zadržati `confirmed` kroz `insertSeatRequest`.
2. Pravila čekanja u `get_cekanje_pravilo()` su zacementirana od 21.02.2026.
3. `dnevni` putnici dobijaju `pending` ali **nikad ne prolaze auto-obradu** (`dispecer_cron_obrada` ih preskače po tipu).
4. Ako admin ne unese vreme za `dan+grad` u "Uredi" dijalogu, ne sme se dirati postojeći `seat_request`.
5. Vreme čekanja meri se od `updated_at` reda, ne od `created_at`. Kada putnik promeni termin, `updated_at` se resetuje i čekanje kreće od početka.
6. Kapacitet se proverava po `zeljeno_vreme` (ne `dodeljeno_vreme`).