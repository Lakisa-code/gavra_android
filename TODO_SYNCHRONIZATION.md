# 📝 PLAN SINHRONIZACIJE I JEDNOSTAVNOSTI

Ovaj dokument služi kao jedinstveni izvor istine za proces uprošćavanja i sinhronizacije aplikacije (Admin vs. Putnik).

---

## 📅 STATUS: PRIPREMA (USVOJENO ✅)

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

### 2. SINHRONIZACIJA ADMIN DIJALOGA (`lib/widgets/registrovani_putnik_dialog.dart`)
- [ ] Prepraviti `_loadDataFromExistingPutnik` da učita i `seat_requests` za narednih 7 dana.
- [ ] Izmeniti `_getStatusForDay` da prioritet da statusu iz `seat_requests`.
- [ ] Obojiti termine u dijalogu:
    - Normalno (Plavo/Crno): Stalni polazak.
    - Narandžasto: Pending (čeka odobrenje).
    - Zeleno: Odobreno (vanredni/učenik).
    - Precrtano/Crveno: Otkazano.

### 3. SINHRONIZACIJA SERVISA (`lib/services/putnik_service.dart`)
- [x] Funkcija `ukloniIzTermina` je UKLONJENA. Pozivi preusmereni na `otkaziPutnika`.
- [x] Izmeniti `otkaziPutnika`: Dodata sinhronizacija sa `seat_requests` (status `otkazano`).
- [ ] Implementirati logiku u `sacuvajPutnika` (ili sličnoj metodi za update): Ako Admin promeni vreme u dijalogu, automatski update-ovati i `seat_requests` za tu nedelju.

---

## 🛠️ BELEŠKE I DOGOVORI
- Sve promene se vrše isključivo prema Supabase bazi.
- Nema "šablona" koji sakrivaju istinu.
- Admin i Putnik moraju videti isti status u svakom trenutku.
