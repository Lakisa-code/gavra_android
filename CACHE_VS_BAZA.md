# 📋 CACHE VS BAZA - Prioritizacija

| Prioritet | Servis | Akcija | Razlog |
|-----------|--------|--------|--------|
| ✅ 1 | racun_service.dart | PREBACI U BAZU | Sprečava duplikate računa |
| ❌ 2 | theme_manager.dart | OSTAVI | Tema je po uređaju, ne po vozaču |
| ✅ 3 | imena_service.dart | PREBACI U BAZU | Realna imena putnika |
| ✅ 4 | adrese_service.dart | PREBACI U BAZU | Deljeni autocomplete |
| ❌ | biometric_service.dart | OSTAVI | Specifično za uređaj |
| ❌ | battery_optimization_service.dart | OSTAVI | Specifično za uređaj |
| ❌ | permission_service.dart | OSTAVI | Specifično za uređaj |
| ❌ | cache_service.dart | OSTAVI | Keš mora biti lokalan |

---

## Završeno

**1. racun_service.dart** - Broj računa sada u bazi (tabela `racun_sequence`), sprečava duplikate između vozača.

**2. theme_manager.dart** - Analizirano, ostaje lokalno (tema je preferencija uređaja).

**3. imena_service.dart** - Autocomplete sada koristi realna imena iz `registrovani_putnici` tabele.

**4. adrese_service.dart** - ✅ MIGRIRAN! Autocomplete sada koristi `AdresaSupabaseService` umesto SharedPreferences.
   - Obrisan `lib/services/adrese_service.dart`
   - Widget `autocomplete_adresa_field.dart` koristi `AdresaSupabaseService.searchAdrese()`
   - Adrese se čitaju iz Supabase tabele `adrese`
   - Uklonjeni SharedPreferences ključevi: `adrese_bela_crkva`, `adrese_vrsac`