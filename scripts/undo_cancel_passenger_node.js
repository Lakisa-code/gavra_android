// Undo cancel passenger script (Node.js)
// Usage (PowerShell):
// $env:TEST_DRIVER_EMAIL='gavriconi19@gmail.com'; $env:TEST_DRIVER_PASSWORD='191919'; node undo_cancel_passenger_node.js

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

// Optionally use service role
const useServiceRole = process.env.USE_SUPABASE_SERVICE_ROLE === 'true';
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabase = useServiceRole && supabaseServiceKey
    ? createClient(supabaseUrl, supabaseServiceKey)
    : createClient(supabaseUrl, supabaseAnonKey);

async function undoCancel(testPassengerId) {
    console.log('🔄 Undoing cancel for', testPassengerId);
    // sign in if we are not using service role
    let driverUuid = null;
    if (!useServiceRole) {
        const email = process.env.TEST_DRIVER_EMAIL || 'test@example.com';
        const password = process.env.TEST_DRIVER_PASSWORD || 'testpassword';
        console.log('📧 Signing in as', email);
        const { data: authData, error: authErr } = await supabase.auth.signInWithPassword({ email, password });
        if (authErr) {
            console.error('Auth error:', authErr);
            return;
        }
        driverUuid = authData?.user?.id || null;
    } else {
        driverUuid = process.env.TEST_DRIVER_UUID || null;
    }

    // fetch the passenger row
    const { data: rows, error: fetchErr } = await supabase.from('putovanja_istorija').select('*').eq('id', testPassengerId).single();
    if (fetchErr) {
        console.error('Fetch error:', fetchErr);
        return;
    }
    const row = rows;
    console.log('Current status:', row.status);

    // parse action_log
    let actionLog = row.action_log || { actions: [] };
    if (typeof actionLog === 'string') {
        try { actionLog = JSON.parse(actionLog); } catch (e) { actionLog = { actions: [] }; }
    }
    actionLog.actions = actionLog.actions || [];

    // find last cancelled action index
    let idx = -1;
    for (let i = actionLog.actions.length - 1; i >= 0; i--) {
        if (actionLog.actions[i] && actionLog.actions[i].type === 'cancelled') {
            idx = i; break;
        }
    }
    if (idx === -1) {
        console.log('No cancelled action found in action_log; nothing to undo.');
        return;
    }

    const removed = actionLog.actions.splice(idx, 1)[0];
    console.log('Removed cancelled action:', removed);

    // if there are no cancelled actions left, set cancelled_by to null
    actionLog.cancelled_by = actionLog.actions.find(a => a.type === 'cancelled') ? actionLog.cancelled_by : null;

    // determine previous status — try to find last non-cancelled action type
    // fallback to 'placeno' if not sure
    let previousStatus = 'placeno';
    // If there is a last 'paid' action, 'placeno'
    for (let i = actionLog.actions.length - 1; i >= 0; i--) {
        if (actionLog.actions[i].type === 'paid') { previousStatus = 'placeno'; break; }
        if (actionLog.actions[i].type === 'picked') { previousStatus = 'picked'; break; }
        if (actionLog.actions[i].type === 'reset') { previousStatus = 'resetovan'; break; }
    }

    // update row with previous status and new action_log
    const { data: updateData, error: updateErr } = await supabase.from('putovanja_istorija').update({ status: previousStatus, action_log: actionLog, updated_at: new Date().toISOString() }).eq('id', testPassengerId).select();
    if (updateErr) {
        console.error('Update error:', updateErr);
    } else {
        console.log('✅ Undo complete:', updateData);
    }
}

// Run
(async () => {
    const testPassengerId = process.env.TEST_PASSENGER_ID || '37219393-d1ab-4787-b35f-bf1a4314da33';
    await undoCancel(testPassengerId);
    await supabase.auth.signOut();
})();
