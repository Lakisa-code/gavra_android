# Google Play & Huawei AppGallery Build Status

## Trenutni Build

| Info | Vrednost |
|------|----------|
| **GitHub Run Number** | 313 |
| **versionCode** | 313 |
| **versionName** | 6.0.3 |
| **Status** | ⏳ U toku... |
| **Commit** | fix: remove unnecessary offset - actual versionCode on Play Store is just 1 |

## Istorija versionCode problema

| Pokušaj | versionCode | Rezultat | Problem |
|---------|-------------|----------|---------|
| 1 | 1 | ❌ | Već korišćen na Play Store |
| 2 | 202512271645 | ❌ | Prevelik (max 2.1B) |
| 3 | 2512271645 | ❌ | Prevelik (max 2.1B) |
| 4 | 25122716 | ❌ | Build OK, ali greška u offsetu |
| 5 | 2025122800 + run_number | ❌ | Nepotreban offset |
| **6** | **313** (run_number) | ⏳ | Čeka se rezultat |

## Rešenje

Koristi se `github.run_number` direktno kao versionCode:
- Jednostavan
- Uvek raste (312 → 313 → 314...)
- Manji od limita (2,100,000,000)
- Veći od prethodnog (1)

## Play Store Status

- Prethodni versionCode: **1** (od 1. novembra)
- Novi versionCode: **313**
