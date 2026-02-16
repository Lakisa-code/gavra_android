# Plan Implementacije Pravih Push Notifikacija (FCM + Supabase Edge Functions)

Ovaj dokument služi kao osnova za prelazak sa lokalnih Realtime notifikacija na serverski vođene Push notifikacije koje rade u svim stanjima (Background, Lock Screen, Terminated).

## 📋 Osnovna Pravila
1. **Database-First**: Notifikaciju pokreće baza podataka (Supabase) putem Trigger-a, a ne sama aplikacija.
2. **SSOT (Single Source of Truth)**: Tabela `push_tokens` mora biti uvek ažurna sa validnim tokenima korisnika.
3. **No-Duplication**: Kada se aktivira serverski sistem, brišu se lokalni pozivi za `LocalNotificationService` u Realtime listenerima.
4. **Smart Routing**: Svaka notifikacija mora sadržati `data` payload koji aplikaciju vodi na tačan ekran (Profil, Vozač, itd.).
5. **Cross-Platform**: Podrška za Android, iOS i Huawei (HMS).
6. **Personalizacija**: Poruke moraju sadržati ime putnika, vreme i relaciju (npr. "Marko, tvoj polazak u 07:00 je potvrđen!").

## 🏗️ Arhitektura
- **Trigger**: SQL funkcija koja prati promene u ključnim tabelama (`seat_requests`, `voznje`, itd.).
- **Edge Function**: Supabase Edge funkcija (npr. `send-push-notification`) koja koristi Firebase Admin SDK za slanje.
- **Service**: 
    - **FCM**: Glavni kanal za Android i iOS.
    - **HMS**: Specijalni kanal za Huawei uređaje bez Google servisa.

## 🛠️ Koraci Implementacije (Plan)
1. [x] **Faza 1: Infrastruktura (Reset)** `[ZAVRŠENO]`
   - [x] Priprema `service_account.json` za Firebase.
   - [x] Prikupljanje Huawei HMS ključeva.
   - [x] Kreiranje koda za `send-push-notification` Edge funkciju.
   - [x] Konfiguracija tajni preko `server_secrets` tabele (Automatizovano).

2. [x] **Faza 2: SQL Automatizacija** `[ZAVRŠENO]`
   - [x] Kreiranje SQL funkcije `notify_seat_request_update()`.
   - [x] Implementacija podrške za alternative u SQL-u.
   - [x] Aktivacija `tr_seat_request_notification` triggera.

3. [x] **Faza 3: App Integracija** `[ZAVRŠENO]`
   - [x] Registracija FCM/HMS tokena u bazu.
   - [x] Rukovanje pozadinskim notifikacijama.
   - [x] Navigacija na klik (Profil/Pin Zahtevi).
   - [x] Uklanjanje duplicirane logike slanja iz Flutter koda.

