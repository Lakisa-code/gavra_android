# 🚀 SUPABASE КОНФИГУРАЦИЈА - GAVRA ANDROID

## ✅ ШТА РАДИ (КОРИСТИ ОВО!)

### 1. **Flutter App - REST API**

- **Фајл**: `lib/supabase_client.dart`
- **URL**: https://gjtabtwudbrmfeyjiicu.supabase.co
- **Кључеви**: anon key + service role key
- **Статус**: ✅ РАДИ 100%

### 2. **Supabase Web Dashboard**

- **URL**: https://supabase.com/dashboard
- **Логин**: преко GitHub/Google налога
- **Статус**: ✅ РАДИ 100%

### 3. **REST API тестирање**

- **Скрипт**: `test_supabase.ps1`
- **Команда**: `.\test_supabase.ps1`
- **Статус**: ✅ РАДИ 100%

### 4. **Помоћни сервиси**

- **SupabaseSafe** (`lib/services/supabase_safe.dart`) - безбедни wrapper
- **SupabaseManager** (`lib/services/supabase_manager.dart`) - connection manager
- **Статус**: ✅ КОРИСТЕ СЕ У АПП-У

---

## ❌ ШТА НЕ РАДИ (НЕ КОРИСТИ!)

### 1. **SQLTools / pgAdmin / DBeaver**

- **Проблем**: IPv6 networking не ради на локалној мрежи
- **Грешка**: Connection timeout
- **Решење**: Користи Web Dashboard уместо database GUI tools

### 2. **Локални Supabase CLI**

- **Фајл**: `supabase/config.toml`
- **Сврха**: Само за локални развој (`supabase start`)
- **Статус**: Не користи се за production

---

## 🔧 КАКО КОРИСТИТИ

### Брзи тест конекције:

```powershell
.\test_supabase.ps1
```

### Flutter код:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

// За читање
final vozaci = await Supabase.instance.client
  .from('vozaci')
  .select('ime')
  .limit(5);

// За упис
await Supabase.instance.client
  .from('mesecni_putnici')
  .insert({'putnik_ime': 'Нови путник'});
```

### REST API curl примери:

```bash
# Читање возача
curl -H "apikey: YOUR_ANON_KEY" \
     "https://gjtabtwudbrmfeyjiicu.supabase.co/rest/v1/vozaci?select=ime&limit=5"

# Упис путника
curl -X POST \
     -H "apikey: YOUR_SERVICE_KEY" \
     -H "Content-Type: application/json" \
     -d '{"putnik_ime":"Тест"}' \
     "https://gjtabtwudbrmfeyjiicu.supabase.co/rest/v1/mesecni_putnici"
```

---

## 📋 ФАЈЛОВИ У ПРОЈЕКТУ

| Фајл                                  | Сврха                    | Користи се |
| ------------------------------------- | ------------------------ | ---------- |
| `lib/supabase_client.dart`            | **Главна конфигурација** | ✅ ДА      |
| `lib/services/supabase_safe.dart`     | Безбедни wrapper         | ✅ ДА      |
| `lib/services/supabase_manager.dart`  | Connection manager       | ✅ ДА      |
| `lib/services/pametni_supabase.dart`  | Usage monitor            | ❓ МОЖДА   |
| `test_supabase.ps1`                   | Тест скрипт              | ✅ ДА      |
| `SUPABASE_CLOUD_GUIDE.md`             | Детаљно упутство         | ✅ ДА      |
| `supabase/config.toml`                | Локални CLI config       | ❌ НЕ      |
| `supabase_optimization_functions.sql` | SQL оптимизације         | ❓ МОЖДА   |

---

## 🚨 ВАЖНЕ НАПОМЕНЕ

1. **Никад не commituj API кључеве** у Git репозиторијум
2. **Користи само REST API** - direktna PostgreSQL konekција не ради
3. **Web Dashboard** је најбољи за администрацију базе
4. **test_supabase.ps1** користи за брзо тестирање конекције
5. **Не бриши** supabase_safe.dart и supabase_manager.dart - користе се у апп-у!

---

**Последња провера**: 19.10.2025 ✅  
**Тестирано**: Flutter app + REST API + Web Dashboard  
**Статус**: Све ради савршено! 🎉
