# ⛔ PRAVILA — NIKAD NE KRŠITI

## SEDMIČNI CIKLUS — AUTOMATSKE OPERACIJE

| Vreme | Šta se dešava |
|-------|---------------|
| **Subota 01:00** | `sedmicni-reset-polazaka` — setuje sve seat_requests na `bez_polaska` |
| **Subota 01:00** | ⛔ **BRISANJE** — `ciscenje-seat-requests` fizički briše seat_requests starije od 30 dana |
| **Subota 02:00** | ✅ **TIME PICKER SE OTKLJUČAVA** — putnici mogu da prave nove zahteve za narednu sedmicu |

### ⚠️ VAŽNO ZA RAZVOJ
- seat_requests **POSTOJE** cijelu sedmicu — ne brišu se do subote 01:00
- Time picker se **ZAKLJUČAVA** po ćeliji — svaka ćelija se zaključava čim nastupi njeno vreme:
  - Pon 05:00 → zaključava se u pon u 05:00
  - Pon 06:00 → zaključava se u pon u 06:00
  - Pon 07:00 → zaključava se u pon u 07:00
  - Uto 05:00 → zaključava se u uto u 05:00
  - ... itd. za svaki dan i vreme
- Time picker se **OTKLJUČAVA** za narednu sedmicu u **subotu u 02:00** — tada svi dani/vremena postaju ponovo dostupni
- **Nedjelja** se ponaša isto kao subota >= 02:00 — aktivna sedmica je uvek **naredna**
- Admin uvek može da kreira termine ručno bez obzira na zaključanost
- Čišćenje starih seat_requests: **SUBOTA 01:00** (ne nedjelja, ne drugi dan)
- Nemoj kreirati logiku koja briše seat_requests van ovog rasporeda

---



## OSNOVNO PRAVILO APLIKACIJE

Svaka operacija je vezana za tačno:

```
DAN + GRAD + VREME
```

Ništa više, ništa manje.

---

## ŠTA OVO ZNAČI U PRAKSI

| Operacija       | Mora imati       | NE sme da dira           |
|-----------------|------------------|--------------------------|
| Otkazivanje     | DAN + GRAD + VREME | Druge dane, gradove, vremena |
| Dodela vozača   | DAN + GRAD + VREME | Druge dane, gradove, vremena |
| Plaćanje        | DAN + GRAD + VREME | Druge dane, gradove, vremena |
| Pokupljen       | DAN + GRAD + VREME | Druge dane, gradove, vremena |
| Kreiranje termina | DAN + GRAD + VREME | Postojeće termine za druge kombinacije |

---

## ZABRANJENA PONAŠANJA

### ❌ _syncSeatRequestsWithTemplate
- **ZABRANJENO**: Setovati `bez_polaska` kada je vreme prazno u formi
- **ZAŠTO**: Admin možda nije popunio polje, ali putnik ima ručno kreiran termin
- **PRAVILO**: Ako je vreme prazno → **preskoči, ne diraj ništa**
- **DOZVOLJENO**: Kreirati/ažurirati seat_request SAMO ako je vreme eksplicitno uneseno

### ❌ Cache ključevi bez DAN+GRAD+VREME
- **ZABRANJENO**: Cache ključ `putnikId|datum` — bez grad i vreme
- **ZAŠTO**: Putnik može ići BC 07:00 I VS 10:00 istog dana — to su DVA različita termina
- **PRAVILO**: Cache ključ mora biti `putnikId|datum|grad|vreme`

### ❌ Operacije bez filtera po gradu i vremenu
- **ZABRANJENO**: Update/delete seat_requests samo po `putnik_id` i `datum`
- **ZAŠTO**: Dirajući sve termine za taj dan, ne samo onaj koji treba
- **PRAVILO**: Uvek dodaj `.eq('grad', grad).eq('zeljeno_vreme', vreme)`

### ❌ Fallback bez vremena
- **ZABRANJENO**: Ako matching po `zeljeno_vreme` ne uspe, raditi update bez vremena
- **ZAŠTO**: Pokriva previše redova — menja termine koje ne treba
- **PRAVILO**: Ako ne nađeš tačan termin → logiraj grešku, ne radi fallback

---

## DVE TABELE — DVE ULOGE — NIKAD SE NE MEŠAJU

### seat_requests — OPERATIVNA TABELA
- Sadrži **tekuće stanje** vožnji
- Menja se svakodnevno: kreiranje, otkazivanje, pokupljen, plaćen
- **SME da se briše/menja** — to je njena svrha
- Jedan red = jedan putnik, jedan dan, jedan grad, jedno vreme

```
putnik_id | datum | grad | zeljeno_vreme | status
```

Svaka operacija mora da filtrira po **sva četiri polja**.

### voznje_log — STATISTIKA / ARHIVA
- Sadrži **trajni zapis** svega što se desilo
- **NIKAD SE NE BRIŠE, NIKAD SE NE MENJA**
- Samo INSERT — nikad UPDATE, nikad DELETE
- Kada se vožnja obriše iz seat_requests → voznje_log ostaje netaknut
- Kada se putnik otkaže → log ostaje
- Kada se status promeni → log ostaje
- Čuva i **termine** (datum, grad, vreme_polaska, dan_u_nedelji) — za rekonstrukciju istorije čak i kad seat_requests budu obrisani

```
putnik_id | datum | grad | vreme_polaska | dan_u_nedelji | tip | vozac_ime | iznos | ...
```

### ⛔ ZABRANJENO
- Brisati redove iz `voznje_log`
- Menjati redove u `voznje_log`
- Koristiti `voznje_log` kao operativni izvor podataka za prikaz
- Brisati `seat_requests` zbog statistike (za to postoji `voznje_log`)

---

## TABELA vreme_vozac

### Globalna dodela (za ceo termin):
```
grad | vreme | dan | vozac_ime    (putnik_id IS NULL)
```

### Individualna dodela (za konkretnog putnika):
```
putnik_id | datum | grad | vreme | vozac_ime    (putnik_id IS NOT NULL)
```

Cache ključ: `putnikId|datum|grad|vreme`

---

## KO SME DA MENJA OVAJ FAJL

Niko. Ovo su nepromenljiva pravila aplikacije.
Ako treba da se promeni logika — promeni KOD, ne pravila.
