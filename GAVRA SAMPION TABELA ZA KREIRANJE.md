# GAVRA SAMPION TABELA ZA KREIRANJE

## 📋 SPISAK TABELA KOJE TREBAMO DA KREIRAMO

Ukupno tabela: 27 (od 30, minus 3 završene)

### PRIORITET 1: registrovani_putnici (20+ referenci u kodu)
- Najviše korišćena tabela
- Sadrži podatke o registrovanim putnicima

### PRIORITET 2: vozaci (vozači)
- Osnovna tabela za vozače
- Povezana sa mnogim drugim tabelama

### PRIORITET 3: vozila
- Tabela vozila
- Detaljne informacije o vozilima

### OSTALE TABELE (po abecednom redu):
- app_config
- app_settings
- finansije_licno
- finansije_troskovi
- fuel_logs
- kapacitet_polazaka
- ml_config
- payment_reminders_log
- pin_zahtevi
- promene_vremena_log
- push_tokens
- putnik_pickup_lokacije
- racun_sequence
- seat_requests
- troskovi_unosi
- user_daily_changes
- vozac_lokacije
- vozila_istorija
- voznje_log
- vreme_vozac
- weather_alerts_log

### ZAVRŠENE TABELE:
1. admin_audit_logs ✅
2. adrese ✅
3. daily_reports ✅

### NAPOMENA:
- Sistematska metoda: jedna tabela po jedna
- Svaka tabela sa direktnim kolonama (DECIMAL/VARCHAR)
- Realtime streaming za sve tabele
- Testovi posle implementacije