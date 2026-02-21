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

// 🔐 Supabase credentials — loaded from .env file via ConfigService
// Fallback to compile-time --dart-define if running in background isolate
// where ConfigService/dotenv may not be available.
//
// Priority:
//   1. ConfigService (dotenv .env file) — main app
//   2. String.fromEnvironment (--dart-define) — CI/build pipeline
//   3. Empty string (will throw at Supabase.initialize)
const String supabaseUrl =
    String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const String supabaseAnonKey =
    String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
const String supabaseServiceRoleKey =
    String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY', defaultValue: '');

// 📖 БРЗА РЕФЕРЕНЦА - REST API ПРИМЕРИ:
//
// GET возачи:
// curl -H "apikey: $anonKey" "$url/rest/v1/vozaci?select=ime&limit=5"
//
// GET месечни путници:
// curl -H "apikey: $anonKey" "$url/rest/v1/registrovani_putnici?aktivan=eq.true"
//
// POST нови путник:
// curl -X POST -H "apikey: $serviceKey" -H "Content-Type: application/json" \
//      -d '{"putnik_ime":"Тест","tip":"ucenik"}' "$url/rest/v1/registrovani_putnici"
