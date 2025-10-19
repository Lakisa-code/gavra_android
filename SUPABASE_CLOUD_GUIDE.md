# 🚀 SUPABASE CLOUD - ВОДИЧ ЗА КОРИШЋЕЊЕ

> **Статус**: ✅ 100% ФУНКЦИОНАЛНО  
> **Датум тестирања**: 19.10.2025

## 📋 ШТА РАДИ (користи ово!)

### 1. **Flutter Апликација** ✅

```dart
// У lib/supabase_client.dart су сви подаци
await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

// Све CRUD операције раде
final vozaci = await supabase.from('vozaci').select();
```

### 2. **REST API са curl** ✅

```bash
# Anon key за обичне операције
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk"

# Service key за админ операције
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHد1ZGJybWZleWppaWN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQzNjI5MiwiZXhwIjoyMDYzMDEyMjkyfQ.BrwnYQ6TWGB1BrmwaE0YnhMC5wMlBRdZUs1xv2dY5r4"

URL="https://gjtabtwudbrmfeyjiicu.supabase.co"

# Примери:
# GET сви возачи
curl -H "apikey: $ANON_KEY" "$URL/rest/v1/vozaci?select=ime,kusur"

# GET активни месечни путници
curl -H "apikey: $ANON_KEY" "$URL/rest/v1/mesecni_putnici?aktivan=eq.true&select=putnik_ime,tip"

# POST нови путник (admin операција)
curl -X POST \
  -H "apikey: $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"putnik_ime":"Тест путник","tip":"ucenik","aktivan":true}' \
  "$URL/rest/v1/mesecni_putnici"
```

### 3. **Supabase Dashboard** ✅

- URL: https://supabase.com/dashboard
- Логуј се и отвори пројекат `gjtabtwudbrmfeyjiicu`
- Table Editor за приказ/едитовање табела
- SQL Editor за SQL упите
- Auth за управљање корисницима

## ❌ ШТА НЕ РАДИ (не губи време!)

### 1. **SQLTools у VS Code** ❌

- Разлог: IPv6 connectivity проблем
- Симптом: "getaddrinfo ENOTFOUND" грешка
- Решење: Користи REST API или Dashboard

### 2. **DBeaver/pgAdmin** ❌

- Разлог: Исти IPv6 проблем
- Симптом: Cannot connect to server
- Решење: Користи REST API или Dashboard

### 3. **Директна PostgreSQL конекција** ❌

```bash
# Ово НЕ ради:
psql "postgresql://postgres.gjtabtwudbrmfeyjiicu:password@db.gjtabtwudbrmfeyjiicu.supabase.co:6543/postgres"
```

## 🛠️ БРЗЕ КОМАНДЕ

### Тестирање конекције:

```bash
curl -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHد1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk" \
"https://gjtabtwudbrmfeyjiicu.supabase.co/rest/v1/vozaci?select=ime&limit=1"
```

### Све табеле:

- `vozaci` - возачи
- `mesecni_putnici` - месечни путници
- `dnevni_putnici` - дневни путници
- `putovanja_istorija` - историја путовања
- `adrese` - адресе
- `vozila` - возила
- `gps_lokacije` - GPS локације
- `rute` - руте

## 🎯 ЗАКЉУЧАК

**Користи:**

1. Flutter код за развој апликације
2. REST API за тестирање и debugging
3. Supabase Dashboard за админ операције

**Избегавај:**

1. SQLTools (не ради)
2. Desktop database GUI tools (не ради)
3. Директне PostgreSQL конекције (не ради)

**Резултат**: 100% функционална апликација без главобоље! 🎉
