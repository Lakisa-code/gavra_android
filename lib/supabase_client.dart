// 🚀 SUPABASE CLOUD КОНФИГУРАЦИЈА
// ✅ РАДИ 100% - Тестирано 19.10.2025
//
// 📋 КАКО КОРИСТИТИ:
// 1. Flutter App - користи supabaseUrl + supabaseAnonKey (РАДИ ✅)
// 2. REST API - користи curl са anon или service key (РАДИ ✅)
// 3. Supabase Dashboard - https://supabase.com/dashboard (РАДИ ✅)
//
// ❌ ШТО НЕ РАДИ:
// - SQLTools (IPv6 проблем)
// - DBeaver/pgAdmin (IPv6 проблем)
// - Директна PostgreSQL конекција (IPv6 проблем)
//
// 💡 РЕШЕЊЕ: Користи REST API и Web Dashboard уместо database GUI tools

const String supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

// Service role key за административне операције (креирање табела, итд.)
const String supabaseServiceRoleKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzQzNjI5MiwiZXhwIjoyMDYzMDEyMjkyfQ.BrwnYQ6TWGB1BrmwaE0YnhMC5wMlBRdZUs1xv2dY5r4';

// 📖 БРЗА РЕФЕРЕНЦА - REST API ПРИМЕРИ:
// 
// GET возачи:
// curl -H "apikey: $anonKey" "$url/rest/v1/vozaci?select=ime&limit=5"
//
// GET месечни путници:
// curl -H "apikey: $anonKey" "$url/rest/v1/mesecni_putnici?aktivan=eq.true"
//
// POST нови путник:
// curl -X POST -H "apikey: $serviceKey" -H "Content-Type: application/json" \
//      -d '{"putnik_ime":"Тест","tip":"ucenik"}' "$url/rest/v1/mesecni_putnici"





