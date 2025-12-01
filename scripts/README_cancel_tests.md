# Test Scripts for Canceling Passengers

This directory contains test scripts in Node.js, Python, and Dart to test the passenger cancellation functionality in the Gavra Android app.

## Prerequisites

### Node.js Script
- Install Node.js
- Install Supabase client: `npm install @supabase/supabase-js`

### Python Script
- Install Python
- Install Supabase client: `pip install supabase`

### Dart Script
- Install Dart SDK
- Run `dart pub get` in `scripts/` after creating the `pubspec.yaml` (this script uses `http` package)

## Setup

1. **Authentication**: Replace the test email and password in each script with actual driver credentials that have permission to cancel passengers.

2. **Passenger ID**: The scripts already contain an example passenger ID (`2cf33687-f914-4dbb-99c2-6af515cf9bb0` - Djordje). Replace it with your own test passenger ID if needed. You can find passenger IDs by:
   - Running the `get_passenger_ids.dart` script in this directory
   - Checking the Supabase dashboard at https://supabase.com/dashboard
   - Using a query like:
     ```sql
     SELECT id, putnik_ime FROM mesecni_putnici WHERE aktivan = true LIMIT 5;
     ```
   - Or use the REST API:
     ```
     GET https://gjtabtwudbrmfeyjiicu.supabase.co/rest/v1/mesecni_putnici?select=id,putnik_ime&limit=5
     ```

   **Example IDs from the database:**
   - Monthly passenger: `2cf33687-f914-4dbb-99c2-6af515cf9bb0` (Djordje) - currently used in scripts
   - Monthly passenger: `af1bc58a-b9eb-408b-9786-946cd5ca9f6d` (Marin)
   - Daily passenger: `519e5fd3-1905-49a9-8e65-eaec6a91536c` (Kracun)

## Usage

### Node.js
```bash
node test_cancel_passenger_node.js
```

### Python
```bash
python test_cancel_passenger_python.py
```

### Dart
```bash
# Option A: set env vars in PowerShell for a single command (Windows PowerShell):
$env:TEST_DRIVER_EMAIL = "driver@example.com"; $env:TEST_DRIVER_PASSWORD = "driver-password"; dart run test_cancel_passenger_dart.dart

# Option B: UNIX / Linux / macOS shell:
export TEST_DRIVER_EMAIL="driver@example.com"; export TEST_DRIVER_PASSWORD="driver-password"; dart run test_cancel_passenger_dart.dart

# Option C: Use Supabase SERVICE ROLE KEY (admin) for direct DB updates without auth.
# ⚠️ WARNING: Service role key is powerful and should be used only on trusted local machines.
$env:SUPABASE_SERVICE_ROLE_KEY = "your-service-key"; $env:USE_SUPABASE_SERVICE_ROLE='true'; dart run test_cancel_passenger_dart.dart

# Or run with default test credentials directly (not recommended for real tests):
dart run test_cancel_passenger_dart.dart
```

## What the Scripts Do

1. **Sign in** as a driver using Supabase Auth
2. **Fetch** passenger data by ID
3. **Update** the passenger status to 'otkazan' (canceled)
4. **Sign out**

## Expected Output

- ✅ Signed in successfully
- 📋 Passenger data: [passenger details]
- ✅ Passenger canceled successfully!
- 📊 Update result: [update confirmation]
- 👋 Signed out

## Notes

- These scripts simulate the cancellation logic from the Flutter app
- Make sure the passenger exists and is not already canceled
- The scripts use the same Supabase configuration as the main app
- For production testing, use test accounts and data
- The scripts currently target `putovanja_istorija` table - adjust if testing monthly passengers (`mesecni_putnici`)</content>
<parameter name="filePath">c:\Users\Bojan\gavra_android\scripts\README_cancel_tests.md