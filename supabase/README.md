# Supabase SQL Skripte

## Redosled izvršavanja (pri setup-u ili migraciji)

### 1. `add_foreign_keys.sql`
- Indeksi i foreign key constraints na tabelama `voznje_log`, `seat_requests`, `registrovani_putnici`, itd.
- Pokrenuti **jednom** pri inicijalnom setup-u baze

### 2. `dispecer.sql`
- Sve funkcije Digitalnog Dispečera (V1.0)
- `get_dan_kratica()` — kratica dana iz datuma
- `get_cekanje_pravilo()` — pravila čekanja po tipu putnika i gradu
- `proveri_slobodna_mesta()` — broj slobodnih mesta za termin
- `obradi_seat_request()` — obrada jednog zahteva (approved/rejected + alternative)
- `dispecer_cron_obrada()` — batch obrada svih pending zahteva (poziva aplikacija ili cron)
- `update_putnik_polazak_v2()` — atomski UPSERT polaska u seat_requests
- `notify_seat_request_update()` — trigger za push notifikacije pri promeni statusa

### 3. `push_triggers.sql`
- Push notifikacijska infrastruktura
- `notify_push()` — helper za slanje push notifikacija
- `notify_seat_request_update()` — trigger na seat_requests tabeli
- Pokrenuti nakon `dispecer.sql`

---

## Statusi u `seat_requests`

| Status | Opis |
|---|---|
| `pending` | Zahtev primljen, čeka obradu dispečera |
| `manual` | Dnevni putnik — admin obrađuje ručno |
| `approved` | Odobreno od strane dispečera |
| `confirmed` | Potvrđeno od strane admina |
| `rejected` | Odbijeno (nema mesta), alternative ponuđene |
| `otkazano` | Putnik otkazao vožnju (upisuje se u voznje_log) |
| `bez_polaska` | Admin uklonio polazak (neutralno, ne upisuje se u log) |
| `cancelled` | Sistem poništio zahtev (npr. novo vreme izabrano) |

## Pravila čekanja

| Tip | Grad | Uslov | Čekanje | Provera kapaciteta |
|---|---|---|---|---|
| Učenik | BC | pre 16h, za sutra | 5 min | ❌ Garantovano |
| Učenik | BC | posle 16h, za sutra | do 20:00 | ✅ |
| Radnik | BC | — | 5 min | ✅ |
| Učenik/Radnik | VS | — | 10 min | ✅ |
| Dnevni | bilo koji | — | ♾️ nikad auto | Admin ručno |
