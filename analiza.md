# iOS Screenshots Workflow - Analiza i TODO

## TODO LISTA

### ✅ 1. Fix workflow iOS 17 -> iOS 18
- Workflow tražio iOS 17 runtime koji ne postoji na macos-latest
- Promenjeno: grep "iOS 17" → grep "iOS 18"  
- Ažurirani simulatori: iPhone 16 Plus, iPad Pro 13-inch (M4)

### ✅ 2. Verify Dart code fixes
- DropdownButtonFormField `initialValue` → `value` (4 fajla ispravljeno)
- TextFormField `initialValue` je OK (ostaje)
- Fajlovi: home_screen.dart, adrese_screen.dart, finansije_screen.dart, registrovani_putnik_dialog.dart

### ⏳ 3. Commit and push all changes
- Čeka izvršenje

### ⏳ 4. Run workflow again
- Čeka commit/push

---

## GREŠKE IZ PRETHODNIH RUNOVA

### Problem 1: Cache miss (nije kritično)
```
Cache not found for input keys: flutter-pub-macos-stable-3.27.0-arm64...
```

### Problem 2: Simulatori dostupni
- iOS 18.4, 18.5, 18.6, 26.0, 26.1 
- NEMA iOS 17! Zato je workflow padao

### Problem 3: Invalid runtime
```
Invalid runtime:
```
Uzrok: grep "iOS 17" nije našao ništa

### Problem 4: Build greška (GLAVNA)
```
Error (Xcode): lib/screens/home_screen.dart:771:23: Error: No named parameter with the name 'initialValue'.
```
Uzrok: DropdownButtonFormField nema `initialValue`, treba `value`

---

## SLEDEĆI KORACI

1. Sačuvati sve fajlove
2. `git add -A && git commit -m "fix: iOS 18 simulators + DropdownButtonFormField value" && git push`
3. `gh workflow run "iOS Screenshots"`
4. Pratiti: `gh run watch --exit-status`
