// Supabase Edge Function (Node) - register-push-token
// Receives JSON payload { provider: 'huawei'|'fcm', token: string, user_id?: string }
// Stores tokens into your Supabase table (push_tokens). This function expects
// environment variables: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.

const fetch = require('node-fetch');

module.exports = async (req, res) => {
    try {
        const body = await req.json();
        const { provider, token, user_id } = body || {};

        if (!provider || !token) {
            return res.status(400).json({ error: 'provider and token are required' });
        }

        const supabaseUrl = process.env.SUPABASE_URL;
        const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

        if (!supabaseUrl || !serviceKey) {
            return res.status(500).json({ error: 'SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not configured' });
        }

        // Persist into a table named `push_tokens` (create this in your DB)
        const insertBody = {
            provider,
            token,
            user_id: user_id || null,
            created_at: new Date().toISOString(),
        };

        const resp = await fetch(`${supabaseUrl}/rest/v1/push_tokens`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                apikey: serviceKey,
                Authorization: `Bearer ${serviceKey}`,
                Prefer: 'return=representation',
            },
            body: JSON.stringify(insertBody),
        });

        if (!resp.ok) {
            const txt = await resp.text();
            return res.status(500).json({ error: 'DB insert failed', details: txt });
        }

        const data = await resp.json();
        return res.status(200).json({ success: true, inserted: data });
    } catch (e) {
        return res.status(500).json({ error: e.message || e.toString() });
    }
};
