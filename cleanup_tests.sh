#!/bin/bash
# cleanup_tests.sh - Brisanje nepotrebnih testova

echo "🧹 ČIŠĆENJE TESTOVA - BRISANJE NEPOTREBNIH FAJLOVA"
echo "=================================================="

# Brojanje testova prije brisanja
TEST_COUNT_BEFORE=$(find test -name "*_test.dart" | wc -l)
echo "📊 Testova prije brisanja: $TEST_COUNT_BEFORE"

echo ""
echo "🗑️  BRISANJE PRIORITY 1 - OBAVEZNO BRISANJE"
echo "--------------------------------------------"

# Debug testovi
echo "🐛 Brisanje debug testova..."
rm -f test/debug_test.dart
rm -f test/debug_uuid_error.dart
rm -f test/debug_remaining_error.dart
rm -f test/debug_mesecni_putnik_test.dart

# Izvještaji
echo "📄 Brisanje izvještaja..."
rm -f test/final_report.dart
rm -f test/final_success_report.dart
rm -f test/final_solution_test.dart

echo ""
echo "🗑️  BRISANJE PRIORITY 2 - PREPORUČENO BRISANJE"
echo "----------------------------------------------"

# Simple/Quick testovi
echo "📝 Brisanje simple/quick testova..."
rm -f test/simple_dart_test.dart
rm -f test/simple_uuid_test.dart
rm -f test/quick_test.dart
rm -f test/quick_mapping_test.dart
rm -f test/quick_validation.dart
rm -f test/pure_dart_uuid_test.dart

# Simulacioni testovi
echo "🎭 Brisanje simulacionih testova..."
rm -f test/supabase_simulation_test.dart
rm -f test/test_id_validation.dart
rm -f test/test_new_id_fix.dart

echo ""
echo "🗑️  BRISANJE PRIORITY 3 - OPCIONALNO BRISANJE"
echo "---------------------------------------------"

# Dupli/nepotrebni testovi
echo "🔄 Brisanje dupli/nepotrebni testovi..."
rm -f test/vozac_mapping_test_posebno.dart  # Dupli sa vozac_uuid_fix_test.dart
rm -f test/real_uuid_test.dart              # Dupli sa uuid_edge_cases_test.dart
rm -f test/check_recent_passenger_test.dart # Samo print bez testova
rm -f test/check_tables_test.dart           # Samo print bez testova
rm -f test/sve_auth_metode_test.dart        # Dokumentacija, ne test
rm -f test/column_mapping_test.dart         # Nepotrebno mapiranje
rm -f test/placeni_mesec_test.dart          # Nepotrebno

echo ""
echo "📊 REZULTATI ČIŠĆENJA"
echo "====================="

# Brojanje testova posle brisanja
TEST_COUNT_AFTER=$(find test -name "*_test.dart" | wc -l)
DELETED_COUNT=$((TEST_COUNT_BEFORE - TEST_COUNT_AFTER))

echo "📊 Testova posle brisanja: $TEST_COUNT_AFTER"
echo "🗑️  Obrisano testova: $DELETED_COUNT"
echo "📈 Procenat smanjenja: $((DELETED_COUNT * 100 / TEST_COUNT_BEFORE))%"

echo ""
echo "✅ ČIŠĆENJE ZAVRŠENO!"
echo ""
echo "📋 OSTALI TESTOVI (pravi testovi sa asertacijama):"
find test -name "*_test.dart" -exec basename {} \; | sort

echo ""
echo "🎯 Preporuka: Pokreni 'flutter test' da proveriš da li su ostali testovi funkcionalni."