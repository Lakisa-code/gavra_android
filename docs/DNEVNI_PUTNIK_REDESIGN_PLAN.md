# Plan redizajna - Dnevni Putnik ekran

## Cilj
Prilagoditi `dnevni_putnik_screen.dart` da izgleda kao `mesecni_putnik_profil_screen.dart` (Moj profil ekran).

---

## Odgovori na pitanja ✅

1. **Podaci korisnika** - Koristi podatke iz `dnevni_putnici_registrovani` tabele (fetch po putnikId)
2. **Status kartica** - DA, treba KOMBI STATUS isto kao u Moj profil
3. **Slobodna mesta** - DA, treba SLOBODNA MESTA sekcija
4. **Boja avatara** - Konzistentno sa mesečnim putnicima
5. **Tema ikonica** - DA, treba palette ikonica za promenu teme

---

## Struktura mesecni_putnik_profil_screen.dart (referenca)

```
AppBar:
├── Back dugme (levo)
├── "👤 Moj profil" naslov
├── Palette ikonica (tema)
└── Logout dugme (desno)

Body:
├── Card (transparentna, border)
│   ├── Avatar (80x80, krug, gradijent, inicijali)
│   ├── Ime i prezime (22px, bold, belo)
│   ├── Badge-ovi (tip + telefon)
│   └── Adrese (🏠 BC, 💼 VS)
├── KombiEtaWidget (status kombija)
├── SlobodnaMestaWidget
└── Ostali sadržaj
```

---

## Plan izmena (detaljno)

### 1. AppBar izmene
**Trenutno:**
- Nema back dugme
- SliverAppBar sa avatrom i imenom
- Samo logout dugme

**Novo:**
- Običan AppBar (kao u mesecni_putnik_profil_screen)
- Back dugme (levo)
- "🚌 Dnevni putnik" naslov
- Palette ikonica za temu
- Logout dugme (desno, crveno)

### 2. Header Card sa profilom
**Trenutno:** Nema  
**Novo:**
- Card (transparentna, border)
- Avatar 80x80 sa inicijalima
- Gradijent: **plavi tonovi** (konzistentno sa mesečnim putnicima)
- Ime i prezime (bold, 22px)
- Badge "🚌 Dnevni putnik"
- Badge telefon
- Info: "🏠 [ADRESA]" • "📍 [GRAD]"

### 3. Kombi Status Widget
**Trenutno:** Nema  
**Novo:** Dodati KombiEtaWidget (kao u mesecni profilu)

### 4. Slobodna Mesta Widget
**Trenutno:** Nema  
**Novo:** Dodati SlobodnaMestaWidget

### 5. Zakaži vožnju forma
**Ostaje** - samo se pomera niže ispod profila i widgeta

### 6. Moji zahtevi sekcija
**Ostaje** - bez promena

---

## Potrebni podaci iz dnevni_putnici_registrovani

| Kolona | Korišćenje |
|--------|-----------|
| ime | Avatar inicijali, prikaz imena |
| prezime | Avatar inicijali, prikaz imena |
| telefon | Badge telefon |
| adresa | Info red |
| grad | Info red, KombiEtaWidget |

---

## Potrebni importi

```dart
import '../services/theme_manager.dart';
import '../widgets/kombi_eta_widget.dart';
import '../widgets/slobodna_mesta_widget.dart';
```

---

## Status
✅ Plan ažuriran
⏳ Čeka potvrdu za početak implementacije
