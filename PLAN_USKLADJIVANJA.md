# Plan usklađivanja koda sa bazom podataka (Seat Requests & Vožnje Log)

## 📝 Plan rada
Prilagođavanje Flutter aplikacije strukturi tabela u Supabase bazi podataka kako bi se osigurala konzistentnost i podržala automatizacija procesa.

---

## ✅ Status zadataka

### 1. Modeli podataka
- [x] Kreiranje modela `SeatRequest` u `lib/models/seat_request.dart` (usklađeno sa SQL strukturom)
- [x] Kreiranje modela `VoznjeLog` u `lib/models/voznje_log.dart` (usklađeno sa SQL strukturom)

### 2. Servisi (Logika)
- [x] Refaktorisanje `SeatRequestService` da koristi novi model i podržava sva polja (`priority`, `batch_id`, itd.)
- [x] Refaktorisanje `VoznjeLogService` da koristi novi model i podržava dodatna polja (`sati_pre_polaska`, `tip_placanja`, `status`)

### 3. UI i Integracija
- [x] Ažuriranje `SeatRequestsScreen` da koristi model `SeatRequest`
- [x] Integracija prikaza prioriteta, alternativa i broja mesta u `SeatRequestsScreen`
- [x] Unifikacija logovanja u `PutnikService` i `PutnikCard` korišćenjem `VoznjeLogService`
- [x] Provera integracije u `RegistrovaniPutnikDialog` i `VoznjeLogService` stream-ovima

---

## 📅 Dnevnik promena
- **2026-02-17**: Inicijalizacija plana. Kreirani modeli `SeatRequest` i `VoznjeLog`. Refaktorisani `SeatRequestService`, `VoznjeLogService` i `SeatRequestsScreen`. Povezani JOIN podaci (putnik pretraga). Unifikovano logovanje akcija u `PutnikService`, `PutnikCard` i `RegistrovaniPutnikDialog`. Dodati vizuelni indikatori za prioritete (amber) i alternative (cyan). Potvrđeno da je plaćanje samo u gotovini. Ažurirana statistika pazara da podržava različite tipove uplate kroz type-safe model.
