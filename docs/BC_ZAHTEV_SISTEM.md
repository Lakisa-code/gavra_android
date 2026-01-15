# BC Zahtev Sistem za Učenike i Radnike

## Kratki opis
Sistem za rezervaciju BC termina sa provjerom slobodnih mesta i alternativama.

---

## Flow po tipu putnika

### 🎓 UČENIK (tip='ucenik')

#### 1. Bira BC termin
- Odmah sačuva u bazu sa `bc_status: pending`
- Prikazuje: "⏳ Vaš zahtev je uspešno primljen"
- Pokreće Timer **5 minuta**

#### 2. Nakon 10 minuta

| Dan | Vreme | Provera mesta |
|-----|-------|---------------|
| Današnji | bilo koje | ✅ DA |
| Naredni | do 16h | ❌ NE (automatski potvrdi) |
| Naredni | posle 16h | ✅ DA |

---

### 👷 RADNIK (tip='radnik')

#### 1. Bira BC termin
- Odmah sačuva u bazu sa `bc_status: pending`
- Prikazuje: "⏳ Vaš zahtev je uspešno primljen"
- Pokreće Timer **5 minuta**

#### 2. Nakon 5 minuta - provera mesta

| Dan | Provera mesta |
|-----|---------------|
| Današnji | ✅ DA |
| Naredni | ✅ DA |

- **Ako IMA mesta**: Potvrdi, notifikacija "✅ Zahtev obrađen"
- **Ako NEMA mesta**: Notifikacija sa alternativama

---

### 🚐 VS (svi tipovi)
- Odmah čuvanje bez provere mesta

---

## Notifikacija sa alternativama

```
🕐 Izaberite termin
Nema mesta za 12:00.
Slobodni: 11:00, 13:00

[✅ 11:00] [✅ 13:00] [⏳ Čekaj 12:00] [❌ Odustani]
```

### Akcije:
| Dugme | Akcija | Status u bazi |
|-------|--------|---------------|
| ✅ 11:00 | Prihvata alternativu | `confirmed` |
| ✅ 13:00 | Prihvata alternativu | `confirmed` |
| ⏳ Čekaj 12:00 | Lista čekanja | `waiting` |
| ❌ Odustani | Ništa se ne sačuva | - |

---

## BC Statusi (`bc_status` u `polasci_po_danu`)

| Status | Značenje |
|--------|----------|
| `pending` | Zahtev primljen, čeka obradu (10 min) |
| `confirmed` | Termin potvrđen |
| `waiting` | Na listi čekanja za željeni termin |
| `null` | Nema zahteva |

---

## Izmenjeni fajlovi

1. **`lib/screens/registrovani_putnik_profil_screen.dart`**
   - `_updatePolazak()` - BC učenik flow sa Timer-om
   - `_confirmBcZahtev()` - provjera mesta + alternative
   - `_pronadjiAlternativneTermineDetaljno()` - nalazi pre/posle termine

2. **`lib/services/local_notification_service.dart`**
   - `showBcAlternativeNotification()` - notifikacija sa action buttons
   - `_handleBcAlternativaAction()` - handler za prihvat alternative
   - `_handleBcCekajAction()` - handler za listu čekanja

3. **`lib/services/slobodna_mesta_service.dart`**
   - Bypass za učenike+BC (nema limita kapaciteta pri zahtjevu)

---

## Napomene
- Timer radi samo dok je app otvoren
- Ako zatvori app: `pending` ostaje u bazi, ali notifikacija se ne šalje
- VS termini i radnici → direktno čuvanje bez čekanja
