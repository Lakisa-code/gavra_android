// Undo all 'otkazan' overrides for a mesecni_putnik_id (Node.js)
// Usage (PowerShell):
// $env:TEST_DRIVER_EMAIL='gavriconi19@gmail.com'; $env:TEST_DRIVER_PASSWORD='191919'; $env:MESecniID='b5298eb7-36ed-449f-8a29-618f5c5f7646'; node undo_all_overrides_node.js
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

// Optionally use service role
const useServiceRole = process.env.USE_SUPABASE_SERVICE_ROLE === 'true';
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabase = useServiceRole && supabaseServiceKey
    ? createClient(supabaseUrl, supabaseServiceKey)
    : createClient(supabaseUrl, supabaseAnonKey);

async function run(mesecniId) {
    // Fetch all rows for that mesecni_putnik_id that are otkazan
    console.log('🔍 Fetching overrides for', mesecniId);
    const { data: rows, error: fetchErr } = await supabase
        .from('putovanja_istorija')
        .select('*')
        .eq('mesecni_putnik_id', mesecniId);
    if (fetchErr) {
        console.error('Fetch error:', fetchErr);
        return;
    }
    console.log('Found', rows.length, 'rows');

    for (const r of rows) {
        const id = r.id;
        const status = r.status;
        if (status === 'otkazan') {
            console.log('Updating row', id, 'from otkazan -> placeno');
            let actionLog = r.action_log || { actions: [] };
            if (typeof actionLog === 'string') {
                try { actionLog = JSON.parse(actionLog); } catch (e) { actionLog = { actions: [] }; }
            }
            actionLog.actions = (actionLog.actions || []).filter(a => a.type !== 'cancelled');
            // If no more cancelled actions, clear cancelled_by
            if (!actionLog.actions.find(a => a.type === 'cancelled')) {
                actionLog.cancelled_by = null;
            }

            const { data: updateData, error: updateErr } = await supabase
                .from('putovanja_istorija')
                .update({ status: 'placeno', action_log: actionLog, updated_at: new Date().toISOString() })
                .eq('id', id)
                .select();
            if (updateErr) {
                console.error('Update error for', id, updateErr);
            } else {
                console.log('Updated', id);
            }
        }
    }
    console.log('Done.');
}

(async () => {
    const mesecniId = process.env.MESecniID || 'b5298eb7-36ed-449f-8a29-618f5c5f7646';
    await run(mesecniId);
})();
