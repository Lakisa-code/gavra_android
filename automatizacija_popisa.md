# Plan Automatizacije Popisa (21:00 Daily Report)

Ovaj dokument definiše prelazak sa ručnog popisa na potpuno automatizovani sistem izveštavanja koji se generiše svakog dana u 21:00.

## 📋 Zahtevi Izveštaja (Precizirana Logika)
Izveštaj se generiše **svakog radnog dana (Pon-Pet) u 21:00** i obuhvata period od 21:00 prethodnog radnog dana do 21:00 tekućeg dana. Vikendom se izveštaji ne šalju.

1. **Dodati putnici**: Broj putnika koje je **vozač ručno dodao** u spisak vožnji (ne računaju se oni koji su se sami rezervisali preko profila).
2. **Otkazani putnici**: Broj putnika koje je **vozač otkazao** (kliknuo na X) u spisku vožnji.
3. **Pošiljke**: Broj stavki tipa `posiljka` koje je vozač dodao i za koje je upisao naplatu.
4. **Ukupna naplata**: Suma svih `uplatа` (dnevnih i mesečnih) upisanih u tom periodu.
5. **Dugovanja**: Putnici tipa `dnevni` koji su obeleženi kao "pokupljeni" (status `voznja`), ali za njih nije upisana `uplata`.

## 🏗️ Tehnološka Arhitektura
- **Supabase Cron (pg_cron)**: Automatizovano okidanje `trigger_daily_popis_reports()` svakog radnog dana u 21:00.
- **SQL Data Aggregator**: Funkcija `get_automated_popis_stats(vozac_uuid, start_time, end_time)`.
- **Push Notification**: Slanje sumarnog izveštaja Adminu (`gavra.prevoz@gmail.com`) i Vozaču preko Edge funkcije.

## 🛠️ Koraci Implementacije
- [x] **SQL Logika**: Napravljena funkcija koja precizno razdvaja akcije vozača (preko `voznje_log`).
- [x] **Status 'Dug'**: Implementirano prepoznavanje dnevnih putnika bez uplate.
- [x] **Cron & Automation**: Podešen `pg_cron` (Pon-Pet u 21:00h).
- [x] **UI Cleanup**: Izbačeno `Popis` dugme i prateća logika iz `VozacScreen.dart`.

---
*Status: ZAVRŠENO - Sistem je u potpunosti automatizovan.*

