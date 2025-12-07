# 📊 ANALIZA SCREENS - gavra_android

**Datum:** 7. decembar 2025  
**Folder:** `lib/screens/`  
**Ukupno fajlova:** 33 + 1 subfolder

---

## LISTA EKRANA:

| # | Ekran | Koristi se | Status |
|---|-------|------------|--------|
| 1 | `admin/address_geocoding_screen.dart` | **0** | 🗑️ OBRIŠI |
| 2 | `admin_map_screen.dart` | 1 | ✅ AKTIVAN - admin_screen |
| 3 | `admin_screen.dart` | 1 | ✅ AKTIVAN - home_screen |
| 4 | `auth_screen.dart` | 1 | ✅ AKTIVAN - admin_screen |
| 5 | `daily_checkin_screen.dart` | 5 | ✅ AKTIVAN - email_login, welcome, vozac_login |
| 6 | `danas_screen.dart` | 3 | ✅ AKTIVAN - local_notification, notification_navigation, home |
| 7 | `dashboard_screen.dart` | **0** | 🗑️ OBRIŠI |
| 8 | `dnevni_putnik_screen.dart` | 3 | ✅ AKTIVAN - zahtev_pristupa, putnik_cekanje |
| 9 | `dodeli_putnike_screen.dart` | 1 | ✅ AKTIVAN - admin_screen |
| 10 | `dugovi_screen.dart` | 3 | ✅ AKTIVAN - vozac, danas, admin |
| 11 | `email_login_screen.dart` | **0** | ⚠️ PROVERI - ali koristi EmailRegistrationScreen |
| 12 | `email_registration_screen.dart` | 1 | ✅ AKTIVAN - email_login_screen |
| 13 | `geocoding_admin_screen.dart` | 1 | ✅ AKTIVAN - admin_screen |
| 14 | `gps_mapa_screen.dart` | **0** | 🗑️ OBRIŠI |
| 15 | `home_screen.dart` | 3 | ✅ AKTIVAN - email_login, vozac_login, welcome |
| 16 | `kapacitet_screen.dart` | 1 | ✅ AKTIVAN - admin_screen |
| 17 | `loading_screen.dart` | 2 | ✅ AKTIVAN - main.dart |
| 18 | `mesecni_putnici_screen.dart` | 1 | ✅ AKTIVAN - admin_screen |
| 19 | `mesecni_putnik_detalji_screen.dart` | **0** | 🗑️ OBRIŠI |
| 20 | `mesecni_putnik_login_screen.dart` | 1 | ✅ AKTIVAN - welcome_screen |
| 21 | `mesecni_putnik_profil_screen.dart` | 1 | ✅ AKTIVAN - mesecni_putnik_login_screen |
| 22 | `monitoring_ekran.dart` | 1 | ✅ AKTIVAN - admin_screen |
| 23 | `o_nama_screen.dart` | 1 | ✅ AKTIVAN - welcome_screen |
| 24 | `performance_dashboard.dart` | **0** | 🗑️ OBRIŠI |
| 25 | `promena_sifre_screen.dart` | 1 | ✅ AKTIVAN - home_screen |
| 26 | `putnik_cekanje_screen.dart` | 1 | ✅ AKTIVAN - zahtev_pristupa_screen |
| 27 | `putovanja_istorija_screen.dart` | 1 | ✅ AKTIVAN - admin_screen |
| 28 | `statistika_detail_screen.dart` | 1 | ✅ AKTIVAN - admin_screen |
| 29 | `vozac_login_screen.dart` | 1 | ✅ AKTIVAN - welcome_screen |
| 30 | `vozac_screen.dart` | 4 | ✅ AKTIVAN - welcome, vozac_login, email_login, admin |
| 31 | `welcome_screen.dart` | 6 | ✅ AKTIVAN - main, auth_manager, email_login, home, vozac, danas |
| 32 | `zahtevi_pregled_screen.dart` | 1 | ✅ AKTIVAN - admin_screen |
| 33 | `zahtev_pristupa_screen.dart` | 1 | ✅ AKTIVAN - welcome_screen |

---

## 🗑️ ZA BRISANJE (5 ekrana):

| # | Ekran | Razlog |
|---|-------|--------|
| 1 | `admin/address_geocoding_screen.dart` | 0 importa, nikad korišćen |
| 2 | `dashboard_screen.dart` | 0 importa, nikad korišćen |
| 3 | `gps_mapa_screen.dart` | 0 importa, nikad korišćen |
| 4 | `mesecni_putnik_detalji_screen.dart` | 0 importa, nikad korišćen |
| 5 | `performance_dashboard.dart` | 0 importa, debug ekran |

---

## ⚠️ ZA PROVERU (1 ekran):

| # | Ekran | Razlog |
|---|-------|--------|
| 1 | `email_login_screen.dart` | Nema direktan import, ali se možda koristi iz main.dart? |

---

## ✅ ZA ZADRŽAVANJE (27 ekrana):

Svi ostali ekrani se aktivno koriste u navigaciji aplikacije.
