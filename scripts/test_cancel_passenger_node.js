// Test script for canceling passengers using Node.js and Supabase
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

// Optionally use service role key for direct updates (local only)
const useServiceRole = process.env.USE_SUPABASE_SERVICE_ROLE === 'true';
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabase = useServiceRole && supabaseServiceKey
    ? createClient(supabaseUrl, supabaseServiceKey)
    : createClient(supabaseUrl, supabaseAnonKey);

async function testCancelPassenger() {
    try {
        console.log('🚀 Starting passenger cancel test...');

        // 1. Sign in as test driver (you can override via env: TEST_DRIVER_EMAIL & TEST_DRIVER_PASSWORD)
        const email = process.env.TEST_DRIVER_EMAIL || 'test@example.com';
        const password = process.env.TEST_DRIVER_PASSWORD || 'testpassword';
        console.log('📧 Signing in as test driver...', email);
        let authError = null;
        let driverUuid = null;
        if (!useServiceRole) {
            const { data: authData, error: authErr } = await supabase.auth.signInWithPassword({
                email: email,
                password: password
            });
            authError = authErr;
            if (authData && authData.user) driverUuid = authData.user.id;
        } else {
            // If using service role, allow specifying driver uuid via env var
            driverUuid = process.env.TEST_DRIVER_UUID || null;
        }

        if (authError) {
            console.error('❌ Auth error:', authError.message);
            return;
        }

        console.log('✅ Signed in successfully');

        // 2. Get a test passenger to cancel (use specific putovanja_istorija id for Djordje)
        const testPassengerId = '37219393-d1ab-4787-b35f-bf1a4314da33'; // Djordje (putovanja_istorija row)

        console.log(`🎯 Canceling passenger with ID: ${testPassengerId}`);

        // 3. Call the cancel function (simulating the app's logic)
        // First, get passenger data
        const { data: passengerData, error: fetchError } = await supabase
            .from('putovanja_istorija') // or 'mesecni_putnici' depending on type
            .select('*')
            .eq('id', testPassengerId)
            .single();

        if (fetchError) {
            console.error('❌ Error fetching passenger:', fetchError.message);
            return;
        }

        console.log('📋 Passenger data:', passengerData);

        // 4. Update status to 'otkazan' and append action_log (including cancelled_by)
        let action_log = passengerData.action_log || { actions: [] };
        if (typeof action_log === 'string') {
            try { action_log = JSON.parse(action_log); } catch (e) { action_log = { actions: [] }; }
        }
        action_log.actions = action_log.actions || [];
        const cancelAction = {
            type: 'cancelled',
            vozac_id: driverUuid || null,
            timestamp: new Date().toISOString(),
            note: 'Otkazano'
        };
        action_log.actions.push(cancelAction);
        action_log.cancelled_by = driverUuid || action_log.cancelled_by || null;

        const { data: updateData, error: updateError } = await supabase
            .from('putovanja_istorija')
            .update({
                status: 'otkazan',
                updated_at: new Date().toISOString(),
                action_log: action_log
            })
            .eq('id', testPassengerId)
            .select();

        if (updateError) {
            console.error('❌ Error canceling passenger:', updateError.message);
            return;
        }

        console.log('✅ Passenger canceled successfully!');
        console.log('📊 Update result:', updateData);

    } catch (error) {
        console.error('❌ Test failed:', error.message);
    } finally {
        // Sign out
        await supabase.auth.signOut();
        console.log('👋 Signed out');
    }
}

// Run the test
testCancelPassenger();