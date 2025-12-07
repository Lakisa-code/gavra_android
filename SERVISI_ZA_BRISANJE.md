# 🗑️ SERVISI ZA BRISANJE - 17 fajlova

**Datum:** 7. decembar 2025  
**Ukupno linija za brisanje:** ~4,400+

---

## LISTA SERVISA ZA BRISANJE:

| # | Servis | Linija | Razlog | Status |
|---|--------|--------|--------|--------|
| 1 | `supabase_manager.dart` | 137 | 0 importa, laže da se koristi | ✅ OBRISANO |
| 2 | `theme_service.dart` | 26 | duplikat theme_manager | ✅ OBRISANO |
| 3 | `zakazana_voznja_service.dart` | 179 | ne koristi se | ✅ OBRISANO |
| 4 | `smart_cache.dart` | 240 | ima cache_service | ✅ OBRISANO |
| 5 | `theme_registry.dart` | 120 | ~~ne koristi se~~ | ❌ ZADRŽI - koristi ga theme_manager |
| 6 | `vozilo_service.dart` | 58 | ne koristi se | ✅ OBRISANO |
| 7 | `advanced_caching_service.dart` | 627 | ne koristi se | ✅ OBRISANO |
| 8 | `pametni_supabase.dart` | 32 | duplikat, supabase_safe je bolji | ✅ OBRISANO |
| 9 | `performance_cache_service.dart` | 66 | duplikat cache_service | ✅ OBRISANO |
| 10 | `performance_analytics_service.dart` | 844 | 0 importa, mrtav kod | ✅ OBRISANO |
| 11 | `network_status_service.dart` | 45 | duplikat realtime_network_status_service | ✅ OBRISANO |
| 12 | `kusur_service.dart` | 95 | ima optimized_kusur_service | ✅ OBRISANO |
| 13 | `location_service.dart` | 124 | duplikat driver_location_service | ✅ OBRISANO |
| 14 | `gps_service.dart` | 120 | duplikat realtime_gps_service | ✅ OBRISANO |
| 15 | `connection_resilience_service.dart` | 157 | duplikat realtime_network_status_service | ✅ OBRISANO |
| 16 | `batch_database_service.dart` | 219 | koristi ga samo ruta_service koji se briše | ✅ OBRISANO |
| 17 | `ruta_service.dart` | 675 | 0 importa, 782 linija mrtvog koda | ✅ OBRISANO |
| 18 | `firebase_auth_service.dart` | 37 | legacy shim, koristi AuthManager | ✅ OBRISANO |
| 19 | `realtime_priority_service.dart` | 339 | 0 importa, duplikat realtime_service | ✅ OBRISANO |
| 20 | `dnevni_putnik_service.dart` | 271 | 0 importa, screen koristi drugu tabelu direktno | ✅ OBRISANO |

---

## UKUPNO: 20 servisa = ~4,400 linija mrtvog koda

---

## KOMANDA ZA BRISANJE (PowerShell):

```powershell
# Premesti u backup folder pre brisanja
$backupDir = "backups/dead_services_$(Get-Date -Format 'yyyy-MM-dd')"
New-Item -ItemType Directory -Force -Path $backupDir

$files = @(
    "lib/services/supabase_manager.dart",
    "lib/services/theme_service.dart",
    "lib/services/zakazana_voznja_service.dart",
    "lib/services/smart_cache.dart",
    "lib/services/theme_registry.dart",
    "lib/services/vozilo_service.dart",
    "lib/services/advanced_caching_service.dart",
    "lib/services/pametni_supabase.dart",
    "lib/services/performance_cache_service.dart",
    "lib/services/performance_analytics_service.dart",
    "lib/services/network_status_service.dart",
    "lib/services/kusur_service.dart",
    "lib/services/location_service.dart",
    "lib/services/gps_service.dart",
    "lib/services/connection_resilience_service.dart",
    "lib/services/batch_database_service.dart",
    "lib/services/ruta_service.dart",
    "lib/services/firebase_auth_service.dart",
    "lib/services/realtime_priority_service.dart",
    "lib/services/dnevni_putnik_service.dart"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        Copy-Item $file -Destination $backupDir
        Remove-Item $file
        Write-Host "✅ Obrisano: $file"
    }
}

Write-Host "`n🎉 Završeno! Obrisano $($files.Count) fajlova."
```

---

## ⚠️ NAPOMENA:

Pre brisanja pokreni `flutter analyze` da proveriš da nema grešaka.
Nakon brisanja pokreni ponovo `flutter analyze` i `flutter run` za verifikaciju.
