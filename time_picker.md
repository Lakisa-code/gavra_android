# Time Picker Funkcionalnosti i Poruke

U ovom fajlu ćemo dokumentovati sve logike, poruke i ponašanja `TimePickerCell` widgeta (`lib/widgets/shared/time_picker_cell.dart`).

## 1. Osnovne Funkcije (Logika)

### `_getDateForDay()`
Izračunava tačan `DateTime` za dan u nedelji (npr. "pon", "uto"). 
- Ako je prosleđeni dan već prošao u tekućoj nedelji, prebacuje ga na sledeću nedelju.
- Služi za preciznu proveru da li je neko vreme već prošlo.

### `_isTimePassed()`
Proverava da li je trenutno vreme prešlo zakazano vreme polaska.
- **Lock-out period**: Sadrži logiku koja zaključava izmenu **10 minuta pre polaska**. 
- Ako je polazak u 14:00, korisnik ne može da menja ništa od 13:50.

### `isLocked` (Getter)
Određuje da li je ćelija interaktivna.
- Zaključava sve dane u prošlosti.
- Zaključava današnji dan nakon **19:00h** (za rezervacije istog dana).
- **Pošiljke**: Nikada nisu zaključane (uvek mogu da se dodaju).
- **Dnevni putnici**: Imaju strožiji režim (vidi poruke).

---

## 2. Vizuelni Identitet (Boje i Ikonice)

Widget menja boju na osnovu statusa rezervacije:
- 🔴 **Crvena (`isCancelled`)**: Polazak je otkazan.
- ❌ **Narandžasto-crvena (`isRejected`)**: Admin je odbio zahtev (termin popunjen).
- ⬜ **Siva (`locked`)**: Prošli dani ili zaključani termini.
- 🟢 **Zelena (`isApproved` / `isConfirmed`)**: Odobren polazak.
- 🟠 **Narandžasta (`isPending`)**: Zahtev poslat, čeka se odobrenje admina.
- 🕒 **Ikonica sata**: Nema izabranog polaska (prazno).

---

## 3. Poruke Korisniku (SnackBars)

Prilikom klika na ćeliju, sistem šalje povratne informacije:

1. **Čekanje (`isPending`)**: 
   - **BLOKIRANO**: `⏳ Vaš zahtev je već u obradi. Molimo sačekajte odgovor.` (Sprečavanje spama).
2. **Odbijeno (`isRejected`)**: 
   - `❌ Ovaj termin je popunjen. Izaberite neko drugo slobodno vreme.`
3. **Odobreno (`isApproved`)**: 
   - **DOZVOLJENO**: Korisnik može da klikne na odobren termin kako bi ga otkazao ili izabrao novo vreme. Ako izabere novo vreme, proces se ponavlja (status ponovo ide u *pending* i čeka se odobrenje).
4. **Dnevni Putnici (Blokada)**: 
   - `Zbog optimizacije kapaciteta, rezervacije za dnevne putnike su moguće samo za tekući dan i sutrašnji dan. Hvala na razumevanju! 🚌`
5. **Brisanje termina**:
   - `Vreme polaska je obrisano.` (Kada korisnik izabere "Bez polaska").
   - `Vreme polaska je već prazno.` (Ako klikne na već prazno stanje).

---

## 4. Dialog Logika (`_showTimePickerDialog`)

Kada se otvori prozor za izbor vremena:
1. **Sezonski Filter**: Gleda `navBarTypeNotifier.value` (Pahulja/Sunce/Jelka) i iz `RouteConfig` vuče samo dozvoljena vremena za tu sezonu.
2. **"Vreme je prošlo" Banner**: Ako je polazak skoro (unutar 10 min) ili je prošao, prikazuje crveni baner koji kaže: `Možete samo da otkažete termin, izmena nije moguća.`
3. **Admin Mode**: Admin (`isAdmin == true`) može da ignoriše sva zaključavanja i menja vremena čak i ako su prošla.
4. **"Bez polaska"**: Specijalna opcija na vrhu liste koja služi za otkazivanje/brisanje termina.