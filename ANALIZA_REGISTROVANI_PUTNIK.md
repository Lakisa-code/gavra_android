# Analiza Registrovani Putnik Profil Screen

Ovaj dokument sadrži detaljnu analizu fajla `lib/screens/registrovani_putnik_profil_screen.dart` i povezane logike. Analiza pokriva potencijalne probleme, greške, performanse i UI/UX zapažanja.

## 1. Arhitektura i Kod

### ⚠️ Monolitna Klasa
*   **Problem:** Fajl ima preko 2500 linija koda. `RegistrovaniPutnikProfilScreen` radi previše stvari: upravlja stanjem, fetch-uje podatke, računa statistiku, upravlja notifikacijama, i renderuje kompleksan UI.
*   **Rizik:** Teško održavanje, velika verovatnoća uvođenja bugova pri izmenama, i nečitljivost.
*   **Preporuka:** Izdvojiti logiku u ViewModel ili Controller (npr. `RegistrovaniPutnikController`) i izdvojiti UI komponente (npr. `StatisticsWidget`, `ScheduleWidget`, `PaymentHistoryWidget`) u zasebne fajlove.

### ⚠️ Duplirana Logika
*   **Problem:** Logika za računanje duga u `_loadStatistike` delimično duplira logiku iz `CenaObracunService` (npr. iteriranje kroz `voznje_log`). Iako koristi service za cenu po danu, sama logika sabiranja je ponovljena u UI kluasi.
*   **Rizik:** Ako se promeni način obračuna na backendu ili u servisu, UI može prikazivati pogrešno stanje duga.

### ⚠️ Upravljanje Greškama (Error Handling)
*   **Problem:** Postoji nekoliko `catch (e) {}` blokova (npr. u `_refreshPutnikData`, `_loadIstorijuPlacanja`, `_getNextPolazak`) koji gutaju greške bez logovanja ili obaveštavanja korisnika/developera.
*   **Rizik:** Problemi u produkciji će biti teški za dijagnostikovanje jer neće biti tragova o greškama.

## 2. Podaci i Stanje

### ⚠️ Konzistentnost Podataka (Data Integrity)
*   **Merge Konflikti:** `_mergePolasciSaBazom` pokušava da pametno spoji lokalne i remote promene. Ovo je kompleksno i podložno greškama (race conditions) ako korisnik brzo menja raspored dok stižu update-i sa servera.
*   **Ručno Računanje Duga:** Dug se računa na klijentu (`ukupnoZaplacanje - ukupnoPlaceno`). Ovo bi idealno trebalo da bude podatak koji stiže sa servera ili kroz `RPC` poziv, kako bi bio "source of truth".

### ⚠️ Performanse
*   **Problem:** `_loadStatistike` ucitava **sve** vožnje i uplate od početka godine (`gte('datum', pocetakGodine...)`).
*   **Rizik:** Kako godina odmiče, ovaj query će vraćati sve više podataka. Za putnike koji putuju svaki dan, to je 500+ zapisa do kraja godine. Ovo može usporiti učitavanje profila i povećati potrošnju podataka.
*   **Preporuka:** Koristiti paginaciju ili backend funkciju koja vraća samo sumarne podatke.

### ⚠️ Memory Leaks
*   **Status Subscription:** Iako se `_statusSubscription` otkazuje u `dispose`, treba biti pažljiv sa svim async operacijama koje se pozivaju nakon `dispose` (npr. unutar `then` blokova ili `await` poziva). Provera `if (mounted)` se koristi često, što je dobro, ali treba preći ceo fajl da se osigura da je svuda prisutna.

## 3. UI i UX

### ⚠️ Hardkodovana Pravila
*   **Petak Blokada:** Logika za blokiranje izmena petkom (`if (now.weekday == DateTime.friday)`) je hardkodovana u UI.
*   **Rizik:** Ako želite da promenite dan ili ukinete pravilo, morate da update-ujete aplikaciju. Ovo treba da bude konfigurabilno sa servera.

### ⚠️ Neiskorišćen Kod
*   Postoje komentarisani delovi koda (npr. `_buildMiniLeaderboard`) i polja koja se ne koriste (označena sa `// ignore: unused_field`). Ovo treba očistiti.

### ⚠️ Feedback Korisniku
*   Kada se šalje zahtev (npr. za VS termin), korisnik dobija `SnackBar`. Ako je korisnik van aplikacije kada se status promeni, oslanja se na push notifikacije. Mehanizam deluje solidno, ali treba proveriti da li `_handleStatusChange` pokriva sve moguće tranzicije statusa ui-a.

## 4. Konkretni Predlozi za Popravke

1.  **Refaktoring `_loadStatistike`:** Prebaciti logiku računanja u dedicated service koji vraća Future sa gotovim `StatisticsData` objektom.
2.  **Optimizacija Upita:** Kreirati SQL View ili RPC funkciju na Supabase-u koja vraća agregirane podatke o dugu i broju vožnji, umesto da se raw podaci šalju klijentu na obradu.
3.  **Centralizacija Konfiguracije:** Izmestiti logiku "Petak Blokada" u `RouteConfig` ili sličan config fajl/servis.
4.  **Uklanjanje Dead Code-a:** Obrisati komentarisane blokove i unused polja.
5.  **Poboljšanje Catch Blokova:** Dodati bar `debugPrint('Error: $e')` u prazne catch blokove.

## Zaključak
Aplikacija deluje funkcionalno, ali je `RegistrovaniPutnikProfilScreen` postao prevelik i kompleksan. Glavni rizik je stabilnost i održavanje na duže staze, kao i potencijalni problemi sa performansama kako se količina podataka povećava. Preporučuje se postepeni refaktoring.
