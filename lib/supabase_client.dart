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

// Use compile-time environment variables (set via --dart-define)
// to avoid committing secrets into source control.
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

// Service role key (admin) MUST NOT be committed. Provide it at build time
// using --dart-define=SUPABASE_SERVICE_ROLE_KEY=your-service-key OR via
// CI/Server environment secrets. Default is empty to ensure it isn't leaked.
const String supabaseServiceRoleKey = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY', defaultValue: '');

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
