# 📋 PLAN: Slobodna Mesta Widget

## 🎯 CILJ
Prikazati putnicima u realtime-u koliko ima slobodnih mesta za svaki polazak, omogućiti promenu vremena i adminu kontrolu kapaciteta.

---

## 📍 LOKACIJA WIDGETA
- **Ekran:** Moj profil (`mesecni_putnik_profil_screen.dart`)
- **Pozicija:** Ispod "Kombi status" widgeta
- **Naziv:** "Promena vremena uživo" ili "Slobodna mesta"

---

## 🖼️ DIZAJN WIDGETA

### Opcija A - Horizontalni scroll (kao bottom nav bar, samo obrnuto):
```
┌─────────────────────────────────────────────────┐
│ 🔄 PROMENA VREMENA UŽIVO                        │
│                                                 │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐       │
│  │5:00 │ │6:00 │ │7:00 │ │8:00 │ │9:00 │  →    │
│  │  5  │ │  3  │ │PUNO │ │  2  │ │  6  │       │
│  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘       │
│                                                 │
│  Tap za promenu vremena                         │
└─────────────────────────────────────────────────┘
```

### Opcija B - Grid prikaz:
```
┌─────────────────────────────────────────────────┐
│ 🔄 SLOBODNA MESTA - Bela Crkva                  │
├─────────────────────────────────────────────────┤
│  5:00 → 5    │  6:00 → 3    │  7:00 → PUNO     │
│  8:00 → 2    │  9:00 → 6    │ 11:00 → 4        │
│ 12:00 → 1    │ 13:00 → 5    │ 14:00 → 3        │
└─────────────────────────────────────────────────┘
```

### Boje:
- **Zeleno:** > 3 slobodna mesta
- **Žuto:** 1-3 slobodna mesta  
- **Crveno:** 0 slobodnih (PUNO)
- **Plavo:** Trenutno izabrano vreme putnika

---

## 🗄️ BAZA PODATAKA

### Nova tabela: `kapacitet_polazaka`
```sql
CREATE TABLE kapacitet_polazaka (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  grad TEXT NOT NULL,           -- 'BC' ili 'VS'
  vreme TEXT NOT NULL,          -- '5:00', '6:00', itd.
  max_mesta INT DEFAULT 8,      -- Maksimalan broj mesta
  aktivan BOOLEAN DEFAULT true, -- Da li je polazak aktivan
  napomena TEXT,                -- Opciona napomena (npr. "Mali kombi")
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(grad, vreme)
);

-- Omogući Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE kapacitet_polazaka;

-- RLS
ALTER TABLE kapacitet_polazaka ENABLE ROW LEVEL SECURITY;

-- Svi mogu čitati
CREATE POLICY "Svi mogu čitati kapacitet"
ON kapacitet_polazaka FOR SELECT USING (true);

-- Samo admin može menjati (preko service role)
CREATE POLICY "Admin može menjati kapacitet"
ON kapacitet_polazaka FOR ALL USING (true);
```

### Inicijalni podaci:
```sql
-- Bela Crkva polasci (zimski)
INSERT INTO kapacitet_polazaka (grad, vreme, max_mesta) VALUES
('BC', '5:00', 8),
('BC', '6:00', 8),
('BC', '7:00', 8),
('BC', '8:00', 8),
('BC', '9:00', 8),
('BC', '11:00', 8),
('BC', '12:00', 8),
('BC', '13:00', 8),
('BC', '14:00', 8),
('BC', '15:30', 8),
('BC', '18:00', 8);

-- Vršac polasci (zimski)
INSERT INTO kapacitet_polazaka (grad, vreme, max_mesta) VALUES
('VS', '6:00', 8),
('VS', '7:00', 8),
('VS', '8:00', 8),
('VS', '10:00', 8),
('VS', '11:00', 8),
('VS', '12:00', 8),
('VS', '13:00', 8),
('VS', '14:00', 8),
('VS', '15:30', 8),
('VS', '17:00', 8),
('VS', '19:00', 8);
```

---

## 🔧 SERVISI

### `KapacitetService` (novi)
```dart
class KapacitetService {
  // Dohvati kapacitet za grad
  static Future<Map<String, int>> getKapacitetZaGrad(String grad);
  
  // Stream kapaciteta (realtime)
  static Stream<Map<String, int>> streamKapacitet(String grad);
  
  // Admin: Promeni kapacitet
  static Future<void> setKapacitet(String grad, String vreme, int maxMesta);
  
  // Izračunaj slobodna mesta (kombinuje kapacitet i broj putnika)
  static Stream<Map<String, int>> streamSlobodnaMesta(String grad, String datum);
}
```

### Logika računanja:
```dart
slobodna_mesta[vreme] = kapacitet[vreme] - broj_putnika[vreme]
```

---

## 📱 WIDGET: `SlobodnaMestaWidget`

### Props:
```dart
class SlobodnaMestaWidget extends StatefulWidget {
  final String grad;              // 'BC' ili 'VS'  
  final String? trenutnoVreme;    // Trenutno vreme putnika (za highlight)
  final Function(String)? onVremeSelected; // Callback kad putnik izabere novo vreme
}
```

### Funkcionalnost:
1. Prikazuje sva vremena za grad putnika
2. Pokazuje slobodna mesta u realtime-u
3. Označava trenutno vreme putnika (plavo)
4. Boji prema popunjenosti (zeleno/žuto/crveno)
5. Tap na vreme → otvara dijalog za potvrdu promene

---

## 👨‍💼 ADMIN UI: `KapacitetScreen`

### Lokacija:
- Novo dugme "Kapacitet" u AdminScreen (pored Putnici, Statistike, API)

### Funkcionalnost:
```
┌─────────────────────────────────────────────────┐
│ ⚙️ PODEŠAVANJE KAPACITETA                       │
├─────────────────────────────────────────────────┤
│ [Bela Crkva ▼]                                  │
├─────────────────────────────────────────────────┤
│  5:00   [  8  ] [-] [+]                         │
│  6:00   [  8  ] [-] [+]                         │
│  7:00   [ 12  ] [-] [+]  ← Veći kombi           │
│  8:00   [  8  ] [-] [+]                         │
│  ...                                            │
├─────────────────────────────────────────────────┤
│ [ Postavi sve na 8 ]  [ Sačuvaj ]               │
└─────────────────────────────────────────────────┘
```

---

## 🔄 INTERAKCIJA PUTNIKA

### Scenario 1: Putnik vidi slobodna mesta
1. Otvori Moj profil
2. Ispod Kombi status vidi widget sa svim vremenima
3. Vidi da je 7:00 PUNO, ali 8:00 ima 3 mesta

### Scenario 2: Putnik menja vreme
1. Tap na 8:00 (ima mesta)
2. Dijalog: "Želite da promenite vreme sa 7:00 na 8:00?"
3. Potvrdi → Ažurira `polasci_po_danu` u bazi
4. Widget se osveži, 8:00 sada ima 2 mesta

### Scenario 3: Putnik pokušava puno vreme
1. Tap na 7:00 (PUNO)
2. Dijalog: "Nema slobodnih mesta za 7:00. Izaberite drugo vreme."

---

## 📋 FAZE IMPLEMENTACIJE

### Faza 1: Baza i servis
- [ ] SQL migracija za `kapacitet_polazaka`
- [ ] Kreirati `KapacitetService`
- [ ] Testirati stream slobodnih mesta

### Faza 2: Admin UI
- [ ] Kreirati `KapacitetScreen`
- [ ] Dodati dugme u AdminScreen
- [ ] Testirati promenu kapaciteta

### Faza 3: Widget za putnike
- [ ] Kreirati `SlobodnaMestaWidget`
- [ ] Integrisati u Moj profil
- [ ] Dodati promenu vremena

### Faza 4: Testiranje i polish
- [ ] Testirati realtime ažuriranje
- [ ] Testirati edge cases (puno, nema podataka)
- [ ] UI polish i animacije

---

## ❓ OTVORENA PITANJA

1. **Da li putnik može da menja vreme samo za danas ili za sve dane?**
   - ✅ **ODLUČENO:** Samo za danas - jednom dnevno (sprečava zloupotrebu)
   - ✅ **IZUZETAK:** Za celu nedelju - može više puta (npr. direktor promeni radno vreme)

2. **Da li se šalje notifikacija kad putnik promeni vreme?**
   - ✅ **ODLUČENO:** DA - notifikacija SVIM vozačima

3. **Da li prikazati oba grada ili samo grad putnika?**
   - ✅ **ODLUČENO:** OBA grada (BC i VS) sa tabovima ili sekcijama

4. **Šta ako putnik nema definisan polazak za danas?**
   - ✅ **ODLUČENO:** Može se dodati na listu za danas ako ima slobodnih mesta

5. **Da li admin treba notifikaciju kad se polazak napuni?**
   - ✅ **ODLUČENO:** DA - push notifikacija adminu (npr. "7:00 BC je pun!")

6. **Letnji vs zimski red vožnje?**
   - ✅ **ODLUČENO:** Jedan kapacitet za sve - automatski koristi postojeću logiku za letnji/zimski raspored

---

## 📝 NAPOMENE

- Widget koristi istu providnost kao KombiEtaWidget i IZMIRENO kocka
- Realtime stream za instant ažuriranje
- Kapacitet se čuva trajno u bazi (ne resetuje se)
- Broj putnika se računa iz postojeće `putnici` tabele
