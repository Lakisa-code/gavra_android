# Test script for canceling passengers using Python and Supabase
from supabase import create_client, Client
import os
from datetime import datetime

# Supabase configuration
supabase_url = 'https://gjtabtwudbrmfeyjiicu.supabase.co'
supabase_anon_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk'

use_service_role = os.getenv('USE_SUPABASE_SERVICE_ROLE', 'false').lower() == 'true'
service_role_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
supabase: Client = create_client(supabase_url, service_role_key if use_service_role and service_role_key else supabase_anon_key)

def test_cancel_passenger():
    try:
        print('🚀 Starting passenger cancel test...')

        # 1. Sign in as test driver (override via env: TEST_DRIVER_EMAIL & TEST_DRIVER_PASSWORD)
        email = os.getenv('TEST_DRIVER_EMAIL', 'test@example.com')
        password = os.getenv('TEST_DRIVER_PASSWORD', 'testpassword')
        print('📧 Signing in as test driver...', email)
        auth_response = supabase.auth.sign_in_with_password({
            'email': email,
            'password': password
        })

        driver_uuid = None
        if not use_service_role:
            if auth_response.user is None:
                print('❌ Auth failed')
                return
            driver_uuid = auth_response.user.id
        else:
            driver_uuid = os.getenv('TEST_DRIVER_UUID')
            print('❌ Auth failed')
            return

        print('✅ Signed in successfully')

        # 2. Get a test passenger to cancel (replace with actual passenger ID)
        test_passenger_id = '37219393-d1ab-4787-b35f-bf1a4314da33'  # Djordje (putovanja_istorija row)

        print(f'🎯 Canceling passenger with ID: {test_passenger_id}')

        # 3. Fetch passenger data
        passenger_response = supabase.table('putovanja_istorija').select('*').eq('id', test_passenger_id).execute()

        if not passenger_response.data:
            print('❌ Passenger not found')
            return

        passenger_data = passenger_response.data[0]
        print('📋 Passenger data:', passenger_data)

        # 4. Update status to 'otkazan' and append to action_log
        action_log = passenger_data.get('action_log') or {'actions': []}
        if isinstance(action_log, str):
            try:
                action_log = json.loads(action_log)
            except Exception:
                action_log = {'actions': []}
        action_log['actions'] = action_log.get('actions', [])
        cancel_action = {
            'type': 'cancelled',
            'vozac_id': driver_uuid,
            'timestamp': datetime.now().isoformat(),
            'note': 'Otkazano'
        }
        action_log['actions'].append(cancel_action)
        action_log['cancelled_by'] = driver_uuid or action_log.get('cancelled_by')

        update_response = supabase.table('putovanja_istorija').update({
            'status': 'otkazan',
            'updated_at': datetime.now().isoformat(),
            'action_log': action_log
        }).eq('id', test_passenger_id).execute()

        if update_response.data:
            print('✅ Passenger canceled successfully!')
            print('📊 Update result:', update_response.data)
        else:
            print('❌ Update failed')

    except Exception as e:
        print(f'❌ Test failed: {str(e)}')
    finally:
        # Sign out
        supabase.auth.sign_out()
        print('👋 Signed out')

if __name__ == '__main__':
    test_cancel_passenger()