# 🎨 VODIČ ZA KONZISTENTNOST TEMA

## 📊 **TRENUTNO STANJE**

### ❌ **PROBLEMI IDENTIFIKOVANI:**

1. **Mešanje hard-coded i theme boja kroz aplikaciju**
2. **Nekozistentnost između popup-ova i glavnih screen-ova**
3. **Hard-coded boje za učenik/radnik funkcionalnost**

### ✅ **REŠENJA IMPLEMENTIRANA:**

## 🎨 **NOVA THEME EXTENSIJA**

Dodato u `lib/theme.dart`:

```dart
extension AppColors on ColorScheme {
  // 🧑‍🎓 Student Colors
  Color get studentPrimary => const Color(0xFFFF9800); // Orange
  Color get studentContainer => const Color(0xFFFFF3E0);
  Color get onStudentContainer => const Color(0xFFE65100);
  
  // 💼 Worker Colors  
  Color get workerPrimary => const Color(0xFF009688); // Teal
  Color get workerContainer => const Color(0xFFE0F2F1);
  Color get onWorkerContainer => const Color(0xFF004D40);
  
  // Ostale boje...
}
```

## 🛠️ **HELPER KLASA**

```dart
class AppThemeHelpers {
  /// Vraća boju na osnovu tipa putnika
  static Color getTypeColor(String tip, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return tip == 'ucenik' ? colorScheme.studentPrimary : colorScheme.workerPrimary;
  }
  
  /// Vraća gradijent na osnovu tipa putnika
  static LinearGradient getTypeGradient(String tip, BuildContext context) {
    // Implementacija...
  }
  
  /// Ostale helper metode...
}
```

## 📋 **MIGRACIJA GUIDE**

### **UMESTO OVAKO (Hard-coded):**
```dart
// ❌ Loše
color: _noviTip == 'ucenik' ? Colors.orange : Colors.teal,

// ❌ Loše
decoration: BoxDecoration(
  color: Colors.blue.shade50,
  border: Border.all(color: Colors.blue.shade200),
),
```

### **KORISTI OVAKO (Theme-based):**
```dart
// ✅ Dobro
color: AppThemeHelpers.getTypeColor(_noviTip, context),

// ✅ Dobro
decoration: BoxDecoration(
  color: Theme.of(context).colorScheme.surface,
  border: Border.all(color: Theme.of(context).colorScheme.outline),
),
```

## 🎯 **PRIORITETNE IZMENE**

### **1. HOME SCREEN (home_screen.dart)**
- [ ] Zameniti hard-coded `Colors.blue.shade50` sa `Theme.of(context).colorScheme.surface`
- [ ] Zameniti `Colors.green` sa `Theme.of(context).colorScheme.successPrimary`
- [ ] Zameniti `Colors.orange` sa `Theme.of(context).colorScheme.warningPrimary`

### **2. MESEČNI PUTNICI SCREEN**
- [x] Delom implementirano - container header boje
- [ ] Potrebno zameniti sve hard-coded boje u popup-ovima
- [ ] Zameniti gradijente sa theme-based gradijentima

### **3. OSTALI SCREEN-OVI**
- [ ] Proveriti sve fajlove u `lib/screens/`
- [ ] Zameniti hard-coded boje sa theme bojama

## 📈 **MEASURING SUCCESS**

### **KAKO MERITI NAPREDAK:**

1. **Pretraga hard-coded boja:**
   ```bash
   grep -r "Colors\.(blue|orange|teal|green|red)\." lib/screens/
   ```

2. **Pretraga hex boja:**
   ```bash
   grep -r "Color(0x" lib/screens/
   ```

3. **Cilj:** Minimizovati gore navedene rezultate

## 🔮 **BUDUĆI KORACI**

1. **Automatizovana migracija** - Script za zamenu čestih pattern-a
2. **Linting pravila** - Dodati custom lint rules koje sprečavaju hard-coded boje
3. **Theme preview** - Tool za pregled kako različite teme utiču na UI

---

**Status:** 🟡 **U TOKU** - Delom implementirano, potreban rad na migraciji postojećeg koda