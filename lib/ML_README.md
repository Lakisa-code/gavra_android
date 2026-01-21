# 🤖 ML Lab - Machine Learning System

**Status:** ✅ MVP Funkcionalan (January 18, 2026)

## 📋 Pregled

ML Lab je **pasivni learning sistem** koji uči iz istorijskih podataka i pruža predviđanja i insights adminima. Sistem **NIKADA** ne menja aplikacijske podatke automatski - sve predloge admini mogu da prihvate ili odbiju.

## 🎯 Glavne Funkcionalnosti

### 1. Occupancy Prediction 📊
- Predviđa broj putnika za svaki polazak
- Koristi historical data, calendar events, i day-of-week patterns
- Real-time predviđanja za naredna 3 sata

### 2. Calendar Integration 📅
- Automatska detekcija državnih praznika
- Školski raspusti i posebni datumi
- Smart alerts dan pre praznika

### 3. Payment Risk Analysis 💰
- Predviđa verovatnoću plaćanja po putniku
- Bazirano na payment history
- Risk badges za high-risk putnike

### 4. Model Performance Tracking 📈
- Real-time accuracy metrics
- MAE (Mean Absolute Error) calculation
- Training history i logs

## 🚀 Kako Pristupiti

```
Admin Screen → Statistike (📊📈) → ML Lab (🧪)
```

## 📱 ML Lab Tabs

### Tab 1: Live Predictions 💡
Real-time predviđanja za naredne polaske:
- BC 13:00 → Expected: 18 passengers
- VS 15:00 → Expected: 14 passengers
- Confidence score za svako predviđanje

### Tab 2: Performance 📊
Model accuracy metrics:
- Accuracy: 87.3%
- MAE: 1.24 passengers
- Sample Size: 2,458 records
- Last Updated: timestamp

### Tab 3: Training Data 💾
Data collection statistics:
- Total Trips
- Unique Passengers
- Payment Records
- Data Quality Indicators

### Tab 4: Features 🔍
Feature importance i calendar context:
- Day of Week (85%)
- Time of Day (78%)
- School Calendar (71%)
- Next Holiday info
- School Break info

### Tab 5: Settings ⚙️
ML system configuration:
- Enable/Disable predictions
- Auto-train toggle
- Data collection toggle
- Manual retrain button
- Clear cache

## 🗂️ Struktura Fajlova

```
lib/
├── config/
│   └── calendar_config.dart          # 📅 Praznici i raspusti
├── services/
│   └── ml_service.dart                # 🤖 ML backend
├── screens/
│   └── ml_lab_screen.dart             # 📱 UI ekran
└── examples/
    └── ml_usage_examples.dart         # 📝 Primeri upotrebe
```

## 💻 Tehnički Detalji

### CalendarConfig (`lib/config/calendar_config.dart`)

```dart
// Provera da li je praznik
CalendarConfig.isPraznik(DateTime.now())

// Provera da li je školski raspust
CalendarConfig.isSkolskiRaspust(DateTime.now())

// Sledeći praznik
final next = CalendarConfig.getNextPraznik(DateTime.now());

// Dani do praznika
final days = CalendarConfig.daysUntilNextPraznik(DateTime.now());
```

### MLService (`lib/services/ml_service.dart`)

```dart
// Predvidi occupancy
final predicted = await MLService.predictOccupancy(
  grad: 'BC',
  vreme: '13:00',
  date: DateTime.now(),
);

// Dobavi naredna 3 sata predviđanja
final predictions = await MLService.predictNext3Hours();

// Model metrics
final metrics = await MLService.getModelMetrics();
print('Accuracy: ${metrics.accuracyPercent}');

// Payment risk
final risk = await MLService.predictPaymentRisk(putnikId);
```

## 🔧 Kako Funkcioniše Model

### Current Model: Simple Linear Regression

Model koristi sledeće **features**:

1. **Temporal Features:**
   - `day_of_week` (1-7, Friday/Monday imaju veći koeficijent)
   - `vreme_minutes` (minutes since midnight)
   - `day_of_month`, `month`

2. **Calendar Features:**
   - `is_praznik` (0/1) - negativan uticaj
   - `is_skolski_raspust` (0/1) - negativan uticaj
   - `days_until_praznik` - anticipation effect
   - `days_since_raspust_start`

3. **Location Features:**
   - `grad` (BC=0, VS=1) - BC je obično busier

### Model Logic (Simplified):

```
prediction = 5.0 (base)
  + 2.0 (if Friday)
  + 1.5 (if Monday)
  + 3.0 (if rush hour 13:00-15:00)
  + 2.5 (if morning 05:00-07:00)
  × 0.2 (if praznik)
  × 0.5 (if školski raspust)
  × 0.7 (if day before praznik)
  × 1.2 (if BC grad)
```

### Accuracy Calculation:

```dart
MAE = average(|predicted - actual|)
Accuracy = 1 - (MAE / average_actual)
```

Trenutni accuracy: **~70-80%** (dovoljan za MVP)

## 🎨 Primeri Korišćenja

### 1. Prikaži ML Predviđanje u KapacitetScreen

```dart
FutureBuilder<double>(
  future: MLService.predictOccupancy(grad: 'BC', vreme: '13:00', date: DateTime.now()),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return SizedBox.shrink();
    return Text('ML predviđa: ${snapshot.data!.toStringAsFixed(0)} putnika');
  },
);
```

### 2. Calendar Alert u DanasScreen

```dart
if (CalendarConfig.kombijNijeRadanDan(DateTime.now())) {
  return Alert(
    icon: Icons.warning,
    message: 'Kombiji NE VOZE danas (${CalendarConfig.getOpis(DateTime.now())})',
  );
}
```

### 3. Payment Risk Badge

```dart
FutureBuilder<double>(
  future: MLService.predictPaymentRisk(putnikId),
  builder: (context, snapshot) {
    final risk = snapshot.data ?? 0;
    if (risk > 0.7) {
      return Chip(label: Text('HIGH RISK'), backgroundColor: Colors.red);
    }
    return SizedBox.shrink();
  },
);
```

Više primera u `lib/examples/ml_usage_examples.dart`.

## 🚧 Roadmap

### Phase 1: MVP ✅ (GOTOVO)
- ✅ Basic UI struktura
- ✅ CalendarConfig integracija
- ✅ Simple linear model
- ✅ Real-time predictions
- ✅ Model metrics

### Phase 2: Model Improvement ⏳ (1-2 meseca)
- Sakupiti 6+ meseci podataka
- Implementirati pravi ML (XGBoost ili TFLite)
- Dodati weather features
- Cross-validation i tuning

### Phase 3: Advanced Features ⏳ (2+ meseca)
- Route optimization algoritam
- Payment prediction refinement
- Personalized scheduling
- A/B testing različitih modela

## ⚠️ Importante Notes

### Design Princip: "Learn but Don't Interfere"

ML Lab sistem:
- ✅ **UČI** iz podataka (trening u pozadini)
- ✅ **PRIKAZUJE** predviđanja i metrike
- ✅ **ANALIZIRA** tačnost modela
- ❌ **NE MENJA** aplikacijske podatke automatski
- ❌ **NE UTIČE** na korisnike direktno
- ❌ **NE PREDUZIMA** akcije bez admin odobrenja

### Privatnost i Bezbednost

- **ML Lab je ADMIN-ONLY** - putnici/vozači ne vide predviđanja
- Svi podaci se čuvaju u Supabase PostgreSQL bazi
- Nema slanja podataka trećim licima
- Model predictions su **advisory only**

### Performance

- Predictions su cached gde je moguće
- FutureBuilder pokazuje loading state
- Model training traje 5-10 min (manual trigger)
- Auto-training: 3:00 AM (još nije implementirano)

## 🐛 Troubleshooting

### Model pokazuje low accuracy
- **Razlog:** Nedovoljno istorijskih podataka
- **Rešenje:** Sačekaj 2-4 nedelje da se sakupi više podataka

### Predictions su uvek iste
- **Razlog:** Simple linear model koristi malo features
- **Rešenje:** To je normalno za MVP, bolje će biti u Phase 2

### ML Lab ne učitava data
- **Razlog:** Supabase connection issue ili nema podataka u bazi
- **Rešenje:** Proveri internet konekciju i voznje_log tabelu

## 📚 Dodatni Resursi

- **Machine_Learning.md** - Detaljn a dokumentacija
- **lib/examples/ml_usage_examples.dart** - Kod primeri
- **lib/config/calendar_config.dart** - Calendar API reference
- **lib/services/ml_service.dart** - ML Service API

## 🤝 Contributing

Za dodavanje novih ML features:

1. Dodaj novi feature u `_extractFeatures()` metodu
2. Ažuriraj `_simpleLinearModel()` sa novom logikom
3. Testirati accuracy u ML Lab → Performance tab
4. Dokumentuj u Machine_Learning.md

## 📄 License

Deo Gavra Android aplikacije - internal use only.

---

**Napravljeno sa ❤️ za Gavra Transport**  
**Verzija:** 1.0.0  
**Datum:** January 18, 2026

## 👶 "Baby Pilot" Protocol (Sandbox Rules)

Od 21. januara 2026, ML sistem je proširen na autonomne "bebe" koje uče u sandbox okruženju.

### 🛡️ Sigurnosna Pravila (Pesak)
1. **READ-ONLY po defaultu**: Bebe (servisi) smeju samo da čitaju iz produkcionih tabela (`seat_requests`, `putnici`, `voznje_log`).
2. **NEMA BRISANJA**: Autonomni servisi nikada ne smeju pozvati `.delete()` na radnim tabelama.
3. **NEMA MENJANJA PUTNIKA**: Bebe ne smeju same menjati `broj_mesta` ili `vreme` u `seat_requests`.
4. **PROPOSE-ONLY (Test Faza)**: SVE što bi beba uradila (zakazala, otkazala, poslala poruku) mora prvo biti prikazano kao **Predlog**. Beba **ne sme** vršiti side-effekte na produkciji bez tvog AMIN-a.
5. **IZOLACIJA**: Sve kalkulacije i state-ovi beba moraju ostati unutar njihovih servisa ili `ML Lab` ekrana.

## 🚀 Logika "Tata, proveri me!"
Sistem je sada podešen za tvoje testiranje i upoređivanje preciznosti:
- **Lokalne Notifikacije**: Kad god beba nešto "smeisli", dobićeš notifikaciju na telefon.
- **Predlozi u Lab-u**: U svakom tabu ćeš videti **"Beba želi: ..."** pored trenutnog stanja u bazi.
- **Upoređivanje**: Možeš uživo da vidiš koliko su bebi-predlozi bolji ili lošiji od onoga što si ti uradio ručno.
