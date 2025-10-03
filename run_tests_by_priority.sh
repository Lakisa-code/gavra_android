#!/bin/bash
# run_tests_by_priority.sh

echo "🚀 POKRETANJE TESTOVA PO PRIORITETIMA"
echo "===================================="

# Priority 1 - KRITIČNI TESTOVI
echo ""
echo "🔴 PRIORITY 1 - KRITIČNI TESTOVI"
echo "-------------------------------"
echo "Pokrećem najvažnije testove prvo..."

# Database testovi
echo "🗄️ Database testovi:"
flutter test test/database_vozac_test.dart || echo "❌ database_vozac_test.dart FAILED"
flutter test test/database_direct_check_test.dart || echo "❌ database_direct_check_test.dart FAILED"

# Vozac testovi
echo "🚗 Vozac testovi:"
flutter test test/vozac_login_demonstracija_test.dart || echo "❌ vozac_login_demonstracija_test.dart FAILED"
flutter test test/vozac_integracija_test.dart || echo "❌ vozac_integracija_test.dart FAILED"
flutter test test/vozac_uuid_fix_test.dart || echo "❌ vozac_uuid_fix_test.dart FAILED"

# Mesecni testovi
echo "📅 Mesecni putnik testovi:"
flutter test test/mesecni_putnik_test.dart || echo "❌ mesecni_putnik_test.dart FAILED"
flutter test test/mesecni_putnik_dodavanje_test.dart || echo "❌ mesecni_putnik_dodavanje_test.dart FAILED"

# Time validator
echo "⏰ Time validator:"
flutter test test/time_validator_test.dart || echo "❌ time_validator_test.dart FAILED"

# Comprehensive testovi
echo "🔍 Comprehensive testovi:"
flutter test test/comprehensive_geo_test.dart || echo "❌ comprehensive_geo_test.dart FAILED"
flutter test test/final_test.dart || echo "❌ final_test.dart FAILED"

echo ""
echo "🟡 PRIORITY 2 - VAŽNI TESTOVI"
echo "-----------------------------"

# UUID edge cases
echo "🔗 UUID edge cases:"
flutter test test/uuid_edge_cases_test.dart || echo "❌ uuid_edge_cases_test.dart FAILED"

# Utils
echo "🔧 Utils:"
flutter test test/utils/ || echo "❌ utils tests FAILED"

# Geographic
echo "🌍 Geographic:"
flutter test test/geographic_restrictions_test.dart || echo "❌ geographic_restrictions_test.dart FAILED"

echo ""
echo "🟢 PRIORITY 3 - MANJE VAŽNI TESTOVI"
echo "-----------------------------------"

# Boja testovi
echo "🎨 Boja testovi:"
flutter test test/vozac_boja_test.dart || echo "❌ vozac_boja_test.dart FAILED"
flutter test test/vozac_boja_konzistentnost_test.dart || echo "❌ vozac_boja_konzistentnost_test.dart FAILED"

# Debug testovi
echo "🐛 Debug testovi:"
flutter test test/debug_mesecni_putnik_test.dart || echo "❌ debug_mesecni_putnik_test.dart FAILED"
flutter test test/debug_test.dart || echo "❌ debug_test.dart FAILED"

# Simple testovi
echo "📝 Simple testovi:"
flutter test test/simple_dart_test.dart || echo "❌ simple_dart_test.dart FAILED"
flutter test test/quick_test.dart || echo "❌ quick_test.dart FAILED"

echo ""
echo "🔵 PRIORITY 4 - SPECIJALNI TESTOVI"
echo "----------------------------------"

# Check testovi
echo "✅ Check testovi:"
flutter test test/check_recent_passenger_test.dart || echo "❌ check_recent_passenger_test.dart FAILED"
flutter test test/check_tables_test.dart || echo "❌ check_tables_test.dart FAILED"

# Pure Dart
echo "🎯 Pure Dart testovi:"
flutter test test/pure_dart_uuid_test.dart || echo "❌ pure_dart_uuid_test.dart FAILED"

# Supabase simulation
echo "☁️ Supabase simulation:"
flutter test test/supabase_simulation_test.dart || echo "❌ supabase_simulation_test.dart FAILED"

echo ""
echo "📊 SAŽETAK TESTOVA"
echo "=================="
echo "✅ Kritični testovi (Priority 1) - Osnova aplikacije"
echo "🟡 Važni testovi (Priority 2) - Dodatne funkcionalnosti"
echo "🟢 Manje važni testovi (Priority 3) - Debug i testovi"
echo "🔵 Specijalni testovi (Priority 4) - Opcionalno"
echo ""
echo "💡 SAVJET: Ako neki testovi padaju, fokusirajte se na Priority 1 prvo,"
echo "zatim popravite Priority 2, a ostale ostavite za kasnije."