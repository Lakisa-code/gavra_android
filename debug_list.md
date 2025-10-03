# Debug Statements List

This document lists all debug statements found in the Gavra Android codebase.

## Custom Debug Logging (`dlog()`)

The application uses a custom `dlog()` function defined in `lib/utils/logging.dart` for structured debug logging.

### VozacRegistracijaService (`lib/services/vozac_registracija_service.dart`)

1. `dlog('📱 Provjera SMS registracije za $vozacIme: $isRegistrovan');` - Line 13
2. `dlog('❌ Greška pri provjeri SMS registracije: $e');` - Line 16
3. `dlog('✅ Vozač $vozacIme označen kao SMS registrovan');` - Line 27
4. `dlog('❌ Greška pri označavanju SMS registracije: $e');` - Line 29
5. `dlog('❌ Greška pri dohvatanju datuma SMS registracije: $e');` - Line 43
6. `dlog('🔄 SMS registracija resetovana za $vozacIme');` - Line 54
7. `dlog('❌ Greška pri resetovanju SMS registracije: $e');` - Line 56
8. `dlog('❌ Greška pri dohvatanju registrovanih vozača: $e');` - Line 87

### VozacMappingService (`lib/services/vozac_mapping_service.dart`)

9. `dlog('⚠️ [VOZAC MAPPING] Nepoznato ime vozača: $ime');` - Line 22
10. `dlog('⚠️ [VOZAC MAPPING] Nepoznat UUID vozača: $uuid');` - Line 31
11. `dlog('🚗 [VOZAC MAPPING] Imena -> UUID:');` - Line 66
12. `dlog('  $ime -> $uuid');` - Line 68

### UpdateService (`lib/services/update_service.dart`)

13. `dlog('🔄 Pokretanje background update provere (svakih 60 min)');` - Line 30
14. `dlog('⏹️ Background update provera zaustavljena');` - Line 45
15. `dlog('🔍 Background provera update-a...');` - Line 51
16. `dlog('📝 Release je draft - nema update-a');` - Line 68
17. `dlog('🔍 Background: Current: $currentVersion, Latest: $latestVersion');` - Line 74
18. `dlog('✅ Background: Verzije su iste - nema update-a');` - Line 78
19. `dlog('🚀 Background: Nova verzija pronađena: $latestVersion');` - Line 90
20. `dlog('💾 Verzija sačuvana u SharedPreferences');` - Line 91
21. `dlog('📊 Background: Nema novije verzije');` - Line 93
22. `dlog('❌ Background: GitHub API greška: ${response.statusCode}');` - Line 95
23. `dlog('❌ Background: Greška pri proveri: $e');` - Line 98
24. `dlog('📝 Preskočena verzija: $version');` - Line 109
25. `dlog('✅ Verzija označena kao instalirana: $version');` - Line 116
26. `dlog('🕐 Sati od poslednje provere: $hoursSinceLastCheck');` - Line 137
27. `dlog('⏰ Prerano za novu proveru update-a');` - Line 152
28. `dlog('📝 Release je draft - nema update-a');` - Line 165
29. `dlog('🚀 Najnovija verzija na GitHub: $latestVersion');` - Line 169
30. `dlog('� Raw tag_name: ${data['tag_name']}');` - Line 170
31. `dlog('�🔍 Trenutna verzija aplikacije: $currentVersion');` - Line 171
32. `dlog('⚖️ String comparison: "$currentVersion" == "$latestVersion"');` - Line 172
33. `dlog('📊 Are equal? ${currentVersion == latestVersion}');` - Line 173
34. `dlog('✅ VERZIJE SU ISTE ($currentVersion == $latestVersion) - NEMA UPDATE-A!');` - Line 177
35. `dlog('⏭️ Verzija $latestVersion je već preskočena');` - Line 181
36. `dlog('💿 Verzija $latestVersion je već instalirana/download-ovana');` - Line 185
37. `dlog('⚠️ Nemože da parsira datum objave');` - Line 190
38. `dlog('🚀 Najnovija verzija na GitHub: $latestVersion');` - Line 194
39. `dlog('📅 Objavljena: ${publishedAt ?? "Nepoznato"}');` - Line 195
40. `dlog('📊 Dana od objave: $daysSincePublish');` - Line 201
41. `dlog('🕰️ Release je prestari ($daysSincePublish dana), preskačem update');` - Line 206
42. `dlog('🌙 Nightly/Beta release - preskačem update');` - Line 212
43. `dlog('📊 Ima update: $hasUpdate');` - Line 216
44. `dlog('🔍 DETALJNO: $currentVersion vs $latestVersion = ${hasUpdate ? "TREBA UPDATE" : "NEMA UPDATE"}');` - Line 218
45. `dlog('❌ GitHub API greška: ${response.statusCode}');` - Line 221
46. `dlog('❌ Greška pri proveri update-a: $e');` - Line 224
47. `dlog('🔗 Download URL: $apkDownloadUrl');` - Line 248
48. `dlog('❌ Greška pri dobijanju info o verziji: $e');` - Line 252
49. `dlog('❌ Greška pri poređenju verzija: $e');` - Line 286
50. `dlog('❌ Greška pri proveri major verzije: $e');` - Line 299
51. `dlog('❌ Greška u automatskoj proveri: $e');` - Line 318

## Standard Print Statements (`print()`)

### Test Files

#### vozac_uuid_fix_test.dart (`test/vozac_uuid_fix_test.dart`)

1. `print('\n🔧 VOZAC UUID-ovi iz VozacMappingService:');` - Line 9
2. `print('=' * 50);` - Line 10
3. `print('🚗 $vozac: $uuid');` - Line 17
4. `print('\n✅ Svi vozači imaju validne UUID-ove');` - Line 28
5. `print('\n🗄️ VOZACI UBAČENI U SUPABASE BAZU:');` - Line 32
6. `print('=' * 40);` - Line 33
7. `print('📋 Migration 20251003210001 je ubacila:');` - Line 35
8. `print("   • 8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f → 'Bilevski'");` - Line 36
9. `print("   • 7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f → 'Bruda'");` - Line 37
10. `print("   • 6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e → 'Bojan'");` - Line 38
11. `print("   • 5b379394-084e-1c7d-76bf-fc193a5b6c7d → 'Svetlana'");` - Line 39
12. `print('\n🔗 Foreign Key Constraint:');` - Line 41
13. `print('   • mesecni_putnici.vozac_id REFERENCES vozaci(id)');` - Line 42
14. `print('   • Sada neće više bacati PostgreSQL grešku 23503');` - Line 43
15. `print('\n✅ Problem sa "vozac_id_fkey" constraint riješen!');` - Line 45
16. `print('\n🚫 STARA GREŠKA (RIJEŠENA):');` - Line 49
17. `print('=' * 30);` - Line 50
18. `print('❌ PRIJE:');` - Line 52
19. `print('   Key (vozac_id)=(3333333-3333-3333-3333-333333333333)');` - Line 53
20. `print('   is not present in table "vozaci"');` - Line 54
21. `print('   PostgreException(message: insert or update');` - Line 55

## Summary

- **Total dlog() calls**: 51 (across 3 service files)
- **Total print() calls**: 21 (mostly in test files)
- **Total debugPrint() calls**: 0

The codebase uses a custom `dlog()` function for structured logging in production services, while `print()` statements are primarily used in test files for debugging output.