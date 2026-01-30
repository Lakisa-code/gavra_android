# ⚡ ULTRA DETALJNA PERFORMANCE ANALIZA
## 📅 Datum: 2026-01-29 23:17:05

---

## 🚀 STARTUP PERFORMANCE

- **Veličina main.dart**: 9192 karaktera
- **Broj importa**: 32
- **Teških importa**: 4
- **Lazy loading**: ✅ Implementiran

### Teški importi pri pokretanju:
- `package:firebase_core/firebase_core.dart`
- `package:supabase_flutter/supabase_flutter.dart`
- `services/firebase_service.dart`
- `supabase_client.dart`

### ⚠️ Startup problemi:
- Previše importa u main.dart - razmotri lazy loading

---

## 💾 MEMORY USAGE

- **Velikih widgeta**: 28
- **Memory intenzivnih operacija**: 0
- **Caching implementacija**: 0 fajlova

### Najveći widget-i:
- `AdminMapScreen` (299 linija) - `lib\screens\admin_map_screen.dart`
- `AdminScreen` (1436 linija) - `lib\screens\admin_screen.dart`
- `AdminZahteviScreen` (127 linija) - `lib\screens\admin_zahtevi_screen.dart`
- `AdreseScreen` (133 linija) - `lib\screens\adrese_screen.dart`
- `AuthScreen` (187 linija) - `lib\screens\auth_screen.dart`

### ⚠️ Memory problemi:
- 28 velikih widgeta (>100 linija)

---

## 🌐 NETWORK PERFORMANCE

- **Ukupno API poziva**: 308
- **Caching strategija**: 31 fajlova

### API pozivi po servisu:
- **Firebase**: 8 poziva (`lib\main.dart`)
- **Supabase**: 1 poziva (`lib\supabase_client.dart`)
- **Firebase**: 1 poziva (`test\phase_4_scenarios_test.dart`)
- **HTTP Client**: 2 poziva (`test\verify_addresses.dart`)
- **Supabase**: 1 poziva (`lib\helpers\putnik_statistike_helper.dart`)

### ⚠️ Network problemi:
- Previše API poziva (308) - razmotri caching

---

## 🗄️ DATABASE PERFORMANCE

- **Query pattern-a**: 187
- **Optimizacionih prilika**: 47

### Optimizacione prilike:
- **Potential N+1 Query** in `lib\helpers\putnik_statistike_helper.dart`
- **Missing LIMIT clause** in `lib\helpers\putnik_statistike_helper.dart`
- **Potential N+1 Query** in `lib\models\registrovani_putnik.dart`
- **Potential N+1 Query** in `lib\screens\admin_map_screen.dart`
- **Missing LIMIT clause** in `lib\screens\admin_zahtevi_screen.dart`

### ⚠️ Database problemi:
- 47 optimizacionih prilika

---

## 📊 VIZUELIZACIJE

Generisane su sledeće vizuelizacije:
- `performance_large_widgets.png` - Najveći widget-i
- `performance_api_calls.png` - Distribucija API poziva

---
*Generisano Ultra Detailed Performance Analyzer v1.0*
