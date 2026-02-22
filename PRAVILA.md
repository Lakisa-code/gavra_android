# ⛔ PRAVILA — NIKAD NE KRŠITI

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

## TABELA seat_requests

Jedan red = jedan putnik, jedan dan, jedan grad, jedno vreme.

```
putnik_id | datum | grad | zeljeno_vreme | status
```

Svaka operacija mora da filtrira po **sva četiri polja**.

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
