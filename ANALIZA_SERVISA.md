# 📊 ANALIZA SERVISA - gavra_android

**Datum:** 7. decembar 2025  
**Ukupno servisa:** 84  
**Ukupno linija:** ~22,000+

---

## ✅ AKTIVNI SERVISI (koriste se)

| # | Servis | Linija | Importa | Status |
|---|--------|--------|---------|--------|
| 1 | `theme_manager` | 102 | 14 | ✅ Aktivno |
| 2 | `putnik_service` | 1863 | 11 | ✅ GLAVNI |
| 3 | `mesecni_putnik_service` | 912 | 8 | ✅ GLAVNI |
| 4 | `statistika_service` | 1062 | 7 | ✅ Aktivno |
| 5 | `auth_manager` | 307 | 7 | ✅ Aktivno |
| 6 | `simplified_daily_checkin` | 135 | 7 | ✅ Aktivno |
| 7 | `vozac_mapping_service` | 162 | 7 | ✅ Aktivno |
| 8 | `adresa_supabase_service` | 398 | 7 | ✅ Aktivno |
| 9 | `realtime_service` | 471 | 6 | ✅ GLAVNI |
| 10 | `realtime_notification_service` | 334 | 6 | ✅ Aktivno |
| 11 | `local_notification_service` | 401 | 5 | ✅ Aktivno |
| 12 | `firebase_service` | 87 | 5 | ✅ Aktivno |
| 13 | `permission_service` | 589 | 4 | ✅ Aktivno |
| 14 | `timer_manager` | 141 | 4 | ✅ Aktivno |
| 15 | `memory_management_service` | 255 | 4 | ✅ Aktivno |
| 16 | `performance_optimizer_service` | 135 | 4 | ✅ Aktivno |
| 17 | `smart_navigation_service` | 392 | 3 | ✅ Aktivno |
| 18 | `realtime_gps_service` | 79 | 3 | ✅ Aktivno |
| 19 | `offline_map_service` | 496 | 3 | ✅ Aktivno |
| 20 | `optimized_kusur_service` | 169 | 2 | ✅ Aktivno |
| 21 | `haptic_service` | 182 | 2 | ✅ Aktivno |
| 22 | `putnik_push_service` | 82 | 2 | ✅ Aktivno |
| 23 | `pickup_tracking_service` | 276 | 2 | ✅ Aktivno |
| 24 | `driver_location_service` | 239 | 2 | ✅ Aktivno |
| 25 | `slobodna_mesta_service` | 376 | 2 | ✅ Aktivno |
| 26 | `clean_statistika_service` | 92 | 2 | ✅ Aktivno |
| 27 | `simple_usage_monitor` | 100 | 2 | ✅ Aktivno |
| 28 | `route_optimization_service` | 436 | 2 | ✅ Aktivno |
| 29 | `voice_navigation_service` | 345 | 2 | ✅ Aktivno |
| 30 | `realtime_notification_counter_service` | 38 | 2 | ✅ Aktivno |

**Aktivni sa 1 importom (proveriti):**

| # | Servis | Linija | Importa | Komentar |
|---|--------|--------|---------|----------|
| 31 | `address_geocoding_batch_service` | 96 | 1 | 🗑️ OBRIŠI - ne koristi se geocoding |
| 32 | `vozac_service` | 143 | 1 | ✅ ZADRŽI - koristi ga vozac_mapping_service |
| 33 | `printing_service` | 389 | 1 | ✅ ZADRŽI - štampanje PDF |
| 34 | `realtime_network_status_service` | 222 | 1 | ✅ ZADRŽI - prati network status |
| 35 | `placanje_service` | 200 | 1 | ✅ ZADRŽI - plaćanja |
| 36 | `optimized_realtime_service` | 294 | 1 | 🗑️ OBRIŠI - duplikat realtime_service + widget unused |
| 37 | `putovanja_istorija_service` | 783 | 1 | ✅ ZADRŽI - istorija putovanja u Admin panelu |
| 38 | `background_gps_service` | 121 | 1 | 🗑️ OBRIŠI - enhanced_navigation_widget unused |
| 39 | `gps_manager` | 233 | 1 | 🗑️ OBRIŠI - gps_mapa_screen unused |
| 40 | `huawei_map_service` | 246 | 1 | ✅ ZADRŽI - main.dart, HMS podrška |
| 41 | `imena_service` | 98 | 1 | ✅ ZADRŽI - autocomplete ime na home_screen |
| 42 | `huawei_push_service` | 151 | 1 | ✅ ZADRŽI - main.dart + putnik_push, HMS podrška |
| 43 | `analytics_service` | 180 | 1 | ✅ ZADRŽI - 4 importa (main, firebase, theme, auth) |
| 44 | `cache_service` | 185 | 1 | ✅ ZADRŽI - main.dart + putovanja_istorija |
| 45 | `fail_fast_stream_manager_new` | 172 | 1 | ✅ ZADRŽI - danas_screen |
| 46 | `geocoding_stats_service` | 152 | 1 | 🗑️ OBRIŠI - ne koristimo Google API |
| 47 | `firebase_background_handler` | 32 | 1 | ✅ ZADRŽI - main + firebase_service |
| 48 | `improved_mesecni_putnik_service` | 190 | 1 | ✅ ZADRŽI - extends mesecni_putnik_service, SQL optimizacije |
| 49 | `kapacitet_service` | 181 | 1 | ✅ ZADRŽI - kapacitet_screen + slobodna_mesta |
| 50 | `daily_checkin_service` | 558 | 1 | ✅ ZADRŽI - basis za simplified_daily_checkin |
| 51 | `admin_security_service` | 72 | 1 | ✅ ZADRŽI - admin_screen sigurnost |
| 52 | `adrese_service` | 227 | 1 | ✅ ZADRŽI - autocomplete adresa na home_screen |
| 53 | `advanced_cache_manager` | 333 | 1 | 🗑️ OBRIŠI - performance_dashboard unused |

---

## ❌ NEAKTIVNI SERVISI (0 importa) - ZA BRISANJE

| # | Servis | Linija | Odluka |
|---|--------|--------|--------|
| 1 | `sms_service` | 365 | ✅ ZADRŽI - treba povezati |
| 2 | `advanced_geocoding_service` | 489 | ✅ ZADRŽI - koristi ga adresa_supabase_service |
| 3 | `supabase_manager` | 137 | 🗑️ OBRIŠI - laže da se koristi, 0 importa |
| 4 | `theme_service` | 26 | 🗑️ OBRIŠI - duplikat theme_manager |
| 5 | `zakazana_voznja_service` | 179 | 🗑️ OBRIŠI - ne koristi se |
| 6 | `smart_cache` | 240 | 🗑️ OBRIŠI - ima cache_service |
| 7 | `adresa_service` | 514 | ✅ ZADRŽI - koristi ga vozac_service |
| 8 | `update_service` | 194 | ✅ ZADRŽI - treba povezati, auto update check |
| 9 | `unified_geocoding_service` | 442 | ✅ ZADRŽI - koriste ga osrm_service i smart_navigation_service |
| 10 | `theme_registry` | 120 | 🗑️ OBRIŠI |
| 11 | `supabase_safe` | 70 | ✅ ZADRŽI - koriste ga putnik_service, realtime_service, local_notification_service |
| 12 | `vozilo_service` | 58 | 🗑️ OBRIŠI - ne koristi se |
| 13 | `advanced_caching_service` | 627 | 🗑️ OBRIŠI |
| 14 | `smart_address_autocomplete_service` | 677 | ✅ ZADRŽI - IMPLEMENTIRAJ, ML autocomplete |
| 15 | `pametni_supabase` | 32 | 🗑️ OBRIŠI - duplikat, supabase_safe je bolji |
| 16 | `osrm_service` | 377 | ✅ ZADRŽI - koristi ga smart_navigation_service za TSP |
| 17 | `performance_cache_service` | 66 | 🗑️ OBRIŠI - duplikat cache_service |
| 18 | `performance_analytics_service` | 844 | 🗑️ OBRIŠI - 977 linija mrtvog koda |
| 19 | `notification_navigation_service` | 198 | ✅ ZADRŽI - koristi ga realtime_notification_service |
| 20 | `network_status_service` | 45 | 🗑️ OBRIŠI - duplikat realtime_network_status_service |
| 21 | `kusur_service` | 95 | 🗑️ OBRIŠI (ima optimized_kusur) |
| 22 | `location_service` | 124 | 🗑️ OBRIŠI - duplikat driver_location_service + advanced_geocoding_service |
| 23 | `gps_service` | 120 | 🗑️ OBRIŠI - duplikat realtime_gps_service, niko ne koristi |
| 24 | `connection_resilience_service` | 157 | 🗑️ OBRIŠI - duplikat realtime_network_status_service |
| 25 | `multi_provider_navigation_service` | 345 | ✅ ZADRŽI - koristi ga smart_navigation_service za HERE WeGo |
| 26 | `batch_database_service` | 219 | 🗑️ OBRIŠI - koristi ga samo ruta_service koji se briše |
| 27 | `ruta_service` | 675 | 🗑️ OBRIŠI - ne koristi se, 782 linija mrtvog koda |
| 28 | `firebase_auth_service` | 37 | 🗑️ OBRIŠI - legacy shim, koristi AuthManager |
| 29 | `geocoding_service` | 277 | ✅ ZADRŽI - koristi ga unified_geocoding + adrese_service |
| 30 | `realtime_priority_service` | 339 | 🗑️ OBRIŠI - 0 importa, duplikat realtime_service |
| 31 | `dnevni_putnik_service` | 271 | 🗑️ OBRIŠI - 0 importa, screen koristi drugu tabelu direktno |

---



---


