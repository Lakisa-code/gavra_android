# Refaktor: Standardizacija grad → BC/VS

**Datum:** 24.02.2026  
**Cilj:** Svuda u kodu i bazi koristiti samo `BC` i `VS` umesto `Bela Crkva` i `Vrsac` kao logički ključ.  
**`normalizeGrad()` u `GradAdresaValidator` već postoji i vraća `BC`/`VS` — arhitektura je zamišljena za ovo.**

---

## Napomena: Šta NE diramo
- UI labele: `'Adresa Bela Crkva'`, `'Adresa Vrsac'` (vidljivo korisniku)
- `printing_service.dart`: `'Bela Crkva - Vrsac'` na računu
- `racun_service.dart`: firma adresa `'Mihajla Pupina 74, 26340 Bela Crkva'`
- Komentari i docstrings
- `GradAdresaValidator` interna logika (`naseljaOpstineBelaCrkva`, itd.) — radi po normalized lowercase

---

## FAZA 1 — Baza podataka

### 1.1 `vreme_vozac` tabela ← KRENUTI OVDE
```sql
UPDATE vreme_vozac SET grad = 'BC' WHERE grad = 'Bela Crkva';
UPDATE vreme_vozac SET grad = 'VS' WHERE grad = 'Vrsac';
```
- [ ] Izvršeno

### 1.2 `adrese` tabela (ostaviti za kraj — zahteva promenu u kodu paralelno)
```sql
UPDATE adrese SET grad = 'BC' WHERE grad = 'Bela Crkva';
UPDATE adrese SET grad = 'VS' WHERE grad = 'Vrsac';
```
- [ ] Izvršeno

---

## FAZA 2 — Dart kod: Servisi

### 2.1 `lib/services/vreme_vozac_service.dart`
- [ ] L196: `isVrsac(...) ? 'Vrsac' : 'Bela Crkva'` → `normalizeGrad(...)`
- [ ] L380: ista promena
- [ ] Komentari L40, L65, L148: `'Bela Crkva' ili 'Vrsac'` → `'BC' ili 'VS'`

### 2.2 `lib/services/local_notification_service.dart`
- [ ] L648: ternary koji pravi `'Vrsac'`/`'Bela Crkva'` → `normalizeGrad(gradRaw)`

---

## FAZA 3 — Dart kod: Screens

### 3.1 `lib/screens/home_screen.dart`
- [ ] L66: `_selectedGrad = 'Bela Crkva'` → `'BC'`
- [ ] L106: `'$v Bela Crkva'` — UI prikaz, možda ostaviti ili promeniti u `'$v BC'`

### 3.2 `lib/screens/vozac_screen.dart`
- [ ] L58: `_selectedGrad = 'Bela Crkva'` → `'BC'`
- [ ] L155: `'$v Bela Crkva'` — proveriti kontekst
- [ ] L925: `isVrsac(...) ? 'Vrsac' : 'Bela Crkva'` → `normalizeGrad(...)`
- [ ] L1061: `.where((v) => v['grad'] == 'Bela Crkva')` → `== 'BC'`
- [ ] L1278: `gradLower.contains('bela crkva') || gradLower == 'bc'` → `normalizeGrad(grad) == 'BC'`

### 3.3 `lib/screens/dodeli_putnike_screen.dart`
- [ ] L37: `_selectedGrad = 'Bela Crkva'` → `'BC'`
- [ ] L88: `'$v Bela Crkva'` — proveriti kontekst

### 3.4 `lib/screens/putnik_action_log_screen.dart`
- [ ] L161: `grad = 'Bela Crkva'` → `'BC'`
- [ ] L136 (vozac_action_log): `grad = 'Bela Crkva'` → `'BC'`
- [ ] L623: reverse lookup funkcija → koristiti `normalizeGrad()`

### 3.5 `lib/screens/registrovani_putnik_profil_screen.dart`
- [ ] L553: `isVrsac(...) ? 'Vrsac' : 'Bela Crkva'` → `normalizeGrad(...)`
- [ ] L878: `grad == 'BC' ? 'Bela Crkva' : 'Vrsac'` — ovo je UI prikaz, ostaviti ili prebaciti u helper

---

## FAZA 4 — Dart kod: Widgets

### 4.1 `lib/widgets/bottom_nav_bar_zimski.dart`
- [ ] L70: `selectedGrad == 'Bela Crkva'` → `== 'BC'`
- [ ] L80: `selectedGrad == 'Vrsac'` → `== 'VS'`
- [ ] L139: `grad: 'Bela Crkva'` → `'BC'`
- [ ] L159: `grad: 'Vrsac'` → `'VS'`

### 4.2 `lib/widgets/bottom_nav_bar_letnji.dart`
- [ ] Iste promene kao zimski

### 4.3 `lib/widgets/bottom_nav_bar_praznici.dart`
- [ ] Iste promene kao zimski

### 4.4 `lib/widgets/registrovani_putnik_dialog.dart`
- [ ] L98: `getAdreseZaGrad('Bela Crkva')` → `'BC'` (tek nakon Faze 1.2)
- [ ] L99: `getAdreseZaGrad('Vrsac')` → `'VS'` (tek nakon Faze 1.2)

### 4.5 `lib/models/registrovani_putnik.dart`
- [ ] L170: `'Bela Crkva'`/`'Vrsac'` inference → `normalizeGrad()`

---

## STATUS

| Faza | Status |
|------|--------|
| **Faza 1** — SQL migracije (`vreme_vozac`, `adrese`) | ✅ Završeno — baza čista, samo `BC`/`VS`, nula `null` |
| **Faza 2** — Servisi (`vreme_vozac_service`, `local_notification_service`) | ✅ Završeno |
| **Faza 3** — Screens (svi ekrani) | ✅ Završeno |
| **Faza 4** — Widgets (bottom nav bars, dialozi) | ✅ Završeno |

**Sve faze završene. 24.02.2026.**
