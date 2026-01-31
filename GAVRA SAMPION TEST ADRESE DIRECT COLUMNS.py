#!/usr/bin/env python3
"""
GAVRA SAMPION TEST ADRESE DIRECT COLUMNS.py
Test script for adrese table with direct columns
"""
import subprocess
import sys
import time

def run_psql(command):
    """Run psql command and return (success, output)"""
    try:
        result = subprocess.run(
            ['psql', '$DATABASE_URL', '-c', command],
            capture_output=True,
            text=True,
            timeout=30
        )
        return result.returncode == 0, result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        return False, "TIMEOUT"
    except Exception as e:
        return False, str(e)

def test_table_exists():
    """Test 1: Check if table exists"""
    print("🧪 TEST 1: Table exists")
    success, output = run_psql("\\dt adrese")
    if success and "adrese" in output:
        print("✅ PASS: Table 'adrese' exists")
        return True
    else:
        print(f"❌ FAIL: Table not found\nOutput: {output}")
        return False

def test_column_count():
    """Test 2: Check column count"""
    print("\n🧪 TEST 2: Column count (8 columns expected)")
    success, output = run_psql("\\d adrese")
    if success:
        lines = [line.strip() for line in output.split('\n') if '|' in line and not line.startswith('+')]
        column_lines = [line for line in lines if len(line.split('|')) >= 2 and not line.split('|')[1].strip().startswith('-')]
        if len(column_lines) == 8:
            print("✅ PASS: 8 columns found")
            return True
        else:
            print(f"❌ FAIL: Expected 8 columns, found {len(column_lines)}")
            print(f"Columns: {[line.split('|')[1].strip() for line in column_lines]}")
            return False
    else:
        print(f"❌ FAIL: Could not describe table\nOutput: {output}")
        return False

def test_insert():
    """Test 3: INSERT operation"""
    print("\n🧪 TEST 3: INSERT operation")
    insert_sql = """
    INSERT INTO adrese (id, naziv, grad, ulica, broj, koordinate)
    VALUES (
        '550e8400-e29b-41d4-a716-446655440001',
        'Test Adresa 1',
        'Bela Crkva',
        'Glavna',
        '15',
        '{"lat": 44.75, "lng": 21.42}'
    );
    """
    success, output = run_psql(insert_sql)
    if success:
        print("✅ PASS: INSERT successful")
        return True
    else:
        print(f"❌ FAIL: INSERT failed\nOutput: {output}")
        return False

def test_select():
    """Test 4: SELECT operation"""
    print("\n🧪 TEST 4: SELECT operation")
    select_sql = "SELECT id, naziv, grad, ulica, broj, koordinate FROM adrese WHERE naziv = 'Test Adresa 1';"
    success, output = run_psql(select_sql)
    if success and 'Test Adresa 1' in output:
        print("✅ PASS: SELECT successful")
        return True
    else:
        print(f"❌ FAIL: SELECT failed\nOutput: {output}")
        return False

def test_update():
    """Test 5: UPDATE operation"""
    print("\n🧪 TEST 5: UPDATE operation")
    update_sql = """
    UPDATE adrese
    SET broj = '20', updated_at = NOW()
    WHERE naziv = 'Test Adresa 1';
    """
    success, output = run_psql(update_sql)
    if success:
        # Verify update
        verify_sql = "SELECT broj FROM adrese WHERE naziv = 'Test Adresa 1';"
        success2, output2 = run_psql(verify_sql)
        if success2 and '20' in output2:
            print("✅ PASS: UPDATE successful")
            return True
        else:
            print(f"❌ FAIL: UPDATE verification failed\nOutput: {output2}")
            return False
    else:
        print(f"❌ FAIL: UPDATE failed\nOutput: {output}")
        return False

def test_delete():
    """Test 6: DELETE operation"""
    print("\n🧪 TEST 6: DELETE operation")
    delete_sql = "DELETE FROM adrese WHERE naziv = 'Test Adresa 1';"
    success, output = run_psql(delete_sql)
    if success:
        # Verify deletion
        verify_sql = "SELECT COUNT(*) FROM adrese WHERE naziv = 'Test Adresa 1';"
        success2, output2 = run_psql(verify_sql)
        if success2 and '0' in output2:
            print("✅ PASS: DELETE successful")
            return True
        else:
            print(f"❌ FAIL: DELETE verification failed\nOutput: {output2}")
            return False
    else:
        print(f"❌ FAIL: DELETE failed\nOutput: {output}")
        return False

def main():
    print("🚀 GAVRA SAMPION TEST ADRESE DIRECT COLUMNS")
    print("=" * 50)

    tests = [
        test_table_exists,
        test_column_count,
        test_insert,
        test_select,
        test_update,
        test_delete
    ]

    passed = 0
    total = len(tests)

    for test in tests:
        if test():
            passed += 1
        time.sleep(0.5)  # Small delay between tests

    print("\n" + "=" * 50)
    print(f"📊 RESULTS: {passed}/{total} tests passed")

    if passed == total:
        print("🎉 ALL TESTS PASSED! Adrese table is working correctly.")
        sys.exit(0)
    else:
        print("❌ SOME TESTS FAILED! Check the output above.")
        sys.exit(1)

if __name__ == "__main__":
    main()