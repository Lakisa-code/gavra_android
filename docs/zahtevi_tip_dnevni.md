# Zahtevi — Filter tip "dnevni"

## Problem

`streamManualRequests()` i `streamManualRequestCount()` trenutno prikazuju SVE `pending` zahteve bez filtera na tip putnika.

## Cilj

Prikazivati u `SeatRequestsScreen` i badge-u na "Zahtevi" dugmetu **samo zahteve putnika tipa `dnevni`**.

---

## Pravila

1. `SeatRequestsScreen` i badge na dugmetu "Zahtevi" prikazuju **samo `dnevni` putnike**
2. Filter je **client-side** u Dart-u (`.where((sr) => sr.tipPutnika == 'dnevni')`) — bez filtera na Supabase nivou
3. `tip_putnika` kolona **postoji direktno** u `seat_requests` tabeli — vraća se kroz `.stream()` bez JOIN-a
4. Status koji se prikazuje: samo **`pending`**
5. `radnik`, `ucenik`, `posiljka` — **ne prikazuju se** u ovom ekranu
6. `manual` status je suvisno za `dnevni` putnike — digitalni dispečer eksplicitno isključuje `dnevni` tip (`.neq('registrovani_putnici.tip', 'dnevni')`)

## Tok statusa za `dnevni` putnika

```
pending  →  (admin ODOBRI)  →  approved  →  (vozač pokupi)  →  pokupljen
pending  →  (admin ODBIJE)  →  rejected
```

## Fajlovi koji su izmenjeni

- `lib/services/seat_request_service.dart`
  - `streamManualRequests()` — dodat `.where((sr) => sr.tipPutnika == 'dnevni')`
  - `streamManualRequestCount()` — dodat `.where((sr) => sr.tipPutnika == 'dnevni')`

