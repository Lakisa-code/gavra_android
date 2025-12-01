// Supabase Edge Function (Deno) - register-push-token
// Receives JSON payload { provider: 'huawei'|'fcm', token: string, user_id?: string }
// Stores tokens into your Supabase table (push_tokens).
// Environment variables SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are auto-injected by Supabase.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { provider, token, user_id } = await req.json()

        if (!provider || !token) {
            return new Response(
                JSON.stringify({ error: 'provider and token are required' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Get environment variables (auto-injected by Supabase)
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

        // Create Supabase admin client
        const supabase = createClient(supabaseUrl, serviceRoleKey)

        // Upsert token (update if exists, insert if not)
        const { data, error } = await supabase
            .from('push_tokens')
            .upsert(
                {
                    provider,
                    token,
                    user_id: user_id || null,
                    updated_at: new Date().toISOString(),
                },
                {
                    onConflict: 'token',
                    ignoreDuplicates: false,
                }
            )
            .select()

        if (error) {
            console.error('DB upsert error:', error)
            return new Response(
                JSON.stringify({ error: 'DB upsert failed', details: error.message }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        console.log('Token registered:', { provider, user_id, tokenPrefix: token.substring(0, 20) + '...' })

        return new Response(
            JSON.stringify({ success: true, data }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    } catch (e) {
        console.error('Function error:', e)
        return new Response(
            JSON.stringify({ error: e.message || String(e) }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
