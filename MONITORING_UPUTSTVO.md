# 📱 JEDNOSTAVAN MONITORING - Uputstvo za upotrebu

**Kreiran:** October 15, 2025  
**Za:** Gavra Android aplikaciju  
**Nivo:** Početnik - ne treba znanje o Supabase

---

## 🚀 **KAKO DA POSTAVITE MONITORING (3 koraka):**

### **KORAK 1: Dodajte u main.dart**

```dart
// Na vrh main.dart fajla dodajte:
import 'services/simple_usage_monitor.dart';

// U main() funkciju dodajte:
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pokrenite monitoring
  await SimpleUsageMonitor.pokreni();

  // Ostalo vaš kod...
  runApp(MyApp());
}
```

### **KORAK 2: Zamenite Supabase pozive**

```dart
// UMESTO OVOGA:
import 'package:supabase_flutter/supabase_flutter.dart';
final supabase = Supabase.instance.client;
final data = await supabase.from('vozaci').select();

// KORISTITE OVAKO:
import 'services/pametni_supabase.dart';
final data = await PametniSupabase.from('vozaci').select();
```

### **KORAK 3: Dodajte dugme u meni**

```dart
// U vašem glavnom meniju dodajte:
ListTile(
  leading: Icon(Icons.analytics),
  title: Text('Supabase Monitoring'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MonitoringEkran()),
    );
  },
),
```

---

## 📊 **ŠTA MONITORING RADI:**

### **Automatski broji:**

- ✅ Svaki poziv ka Supabase bazi
- ✅ Dnevne statistike
- ✅ Mesečne procene
- ✅ Procenat od besplatnog limita

### **Upozorava kada:**

- 🟢 **0-20%** limita: "Sve je u redu!"
- 🟡 **20-50%** limita: "Normalna upotreba"
- 🟠 **50-80%** limita: "Počnite da pazite"
- 🔴 **80%+** limita: "Blizu ste limita!"

### **Lep prikaz:**

- 📱 Jednostavan ekran sa bojama
- 📊 Progress bar do limita
- 💡 Korisni saveti
- 🔄 Refresh povlačenjem nadole

---

## 💡 **ČESTO POSTAVLJANA PITANJA:**

### **Q: Koliko mogu da testiram besplatno?**

A: **PUNO!** Besplatno je 50,000 poziva mesečno. U development fazi to je skoro nemoguće potrošiti.

### **Q: Kada treba da platim Supabase Pro?**

A: Tek kada aplikacija krene u produkciju sa 100+ vozača. To je za 6-12 meseci minimum.

### **Q: Da li monitoring usporava aplikaciju?**

A: **NE!** Dodaje samo 1 liniju koda po pozivu. Neprimetno je.

### **Q: Šta ako zaboravim da koristim PametniSupabase?**

A: Ništa se neće pokvariti, samo neće brojiti te pozive. Postupno zamenite.

### **Q: Da li mogu da vidim statistike bez interneta?**

A: **DA!** Sve se čuva lokalno na telefonu.

---

## 🎯 **SAVETI ZA OPTIMIZACIJU:**

### **Tokom development-a:**

- Ne brinite o troškovima - testiranje je besplatno
- Koristite monitoring da vidite trend rasta
- Očistite test podatke povremeno

### **Kada krene produkcija:**

- Pratite monitoring nedeljno
- Ako vidite nagao skok - istražite zašto
- Optimizujte kad dođete do 60-70% limita

### **Ako prođete limite:**

- **Supabase Pro:** $25/mesec - platite kada baš morate
- **Google Play Developer:** $25 jednom - PRIORITET #1

---

## 🆘 **HITNA POMOĆ:**

### **Ako se monitoring ne pokreće:**

1. Proverite da li ste dodali `await SimpleUsageMonitor.pokreni();` u main()
2. Proverite da li ste importovali fajl
3. Restartujte aplikaciju

### **Ako ne broji pozive:**

1. Koristite `PametniSupabase.from()` umesto `supabase.from()`
2. Zamenite sve pozive postupno
3. Testiranje: dodajte neki poziv pa proverite da li se broj povećao

### **Ako monitoring ekran ne radi:**

1. Proverite da li ste dodali `import '../services/simple_usage_monitor.dart';`
2. Dodajte u routing/navigation vašeg menija
3. Potreban vam je `shared_preferences` package

---

## ✅ **CHECKLIST ZA SETUP:**

- [ ] Dodao `SimpleUsageMonitor.pokreni()` u main.dart
- [ ] Kreirao `PametniSupabase` import
- [ ] Zamenio bar jedan `supabase.from()` sa `PametniSupabase.from()`
- [ ] Dodao dugme u meni za MonitoringEkran
- [ ] Testirao da monitoring broji pozive
- [ ] Proverio da ekran lepo izgleda

---

**GOTOVO! Sada imate jednostavan monitoring koji će vam reći kada trebate da platite Supabase Pro.**

**Za sada ne brinite o troškovima - fokusirajte se na razvoj aplikacije!**
