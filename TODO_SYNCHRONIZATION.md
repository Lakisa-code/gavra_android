# 📝 PLAN SINHRONIZACIJE I JEDNOSTAVNOSTI

Ovaj dokument služi kao jedinstveni izvor istine za proces uprošćavanja i sinhronizacije aplikacije (Admin vs. Putnik).

---

## 📅 STATUS: U RADU 🚧

- [x] **JEDAN IZVOR ISTINE**: Rezervacija u Supabase je svetinja. Ako postoji termin (Dan/Grad/Vreme), svi ga vide isto. No-template policy.
- [x] **STATUS OTKAZANO**: Za statistiku koristimo isključivo status `otkazano`. Ništa se ne briše što je bitno za istoriju.
- [x] **POGLED UNAPRED**: Admin dijalog prikazuje stvarno stanje za narednih 5 radnih dana.
- [x] **AUTOMATSKO AŽURIRANJE**: Promena u dijalogu (šablonu) automatski ažurira sve zakazane vožnje u narednoj nedelji da bi se izbegla nesinhronizovanost.

---

## 📋 TODO LISTA

### 1. ANALIZA I ČINJENICE
- [x] Utvrđeno: `seat_requests` tabele i `polasci_po_danu` moraju biti "merdžovani" u Admin dijalogu.
- [x] Utvrđeno: Funkcija "Ukloni iz termina" je KOMPLETNO IZBAČENA iz aplikacije.
- [x] Utvrđeno: Status `otkazano` je jedini marker za micanje putnika sa aktivne liste.

### 2. SINHRONIZACIJA ADMIN DIJALOGA (`lib/widgets/registrovani_putnik_dialog.dart`) ✅
- [x] Prepraviti `_loadDataFromExistingPutnik` da učita i `seat_requests` za narednih 7 dana.
- [x] Izmeniti `_getStatusForDay` da prioritet da statusu iz `seat_requests`.
- [x] Obojiti termine u dijalogu (preko `TimeRow` i `TimePickerCell`):
    - Narandžasto: Pending (čeka odobrenje).
    - Zeleno: Odobreno / Confirmed.
    - Crveno: Otkazano.

### 3. SINHRONIZACIJA SERVISA I KONKURENCIJE ✅
- [x] Funkcija `ukloniIzTermina` je UKLONJENA. Pozivi preusmereni na `otkaziPutnika`.
- [x] Izmeniti `otkaziPutnika`: Dodata sinhronizacija sa `seat_requests` (status `otkazano`).
- [x] Sinhronizovan `RegistrovaniPutnikProfilScreen` (putnikov pogled) da podržava `otkazano` status iz baze.
- [ ] Implementirati logiku u `sacuvajPutnika`: Ako Admin promeni vreme u dijalogu, automatski update-ovati i `seat_requests` za tu nedelju (TBD).

---

## 🛠️ BELEŠKE I DOGOVORI
- Sve promene se vrše isključivo prema Supabase bazi.
- Nema "šablona" koji sakrivaju istinu.
- Admin i Putnik moraju videti isti status u svakom trenutku.
