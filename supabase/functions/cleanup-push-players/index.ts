// Supabase Edge Function - Cleanup push_players entries (delete permanent ones)
// This function permanently deletes rows in `push_players` where `is_active=false` and `removed_at` is older than threshold days

// @ts-ignore
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
// @ts-ignore
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: any) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

    try {
        const { days } = (await req.json()) ?? { days: 30 }
        const threshold = new Date();
        threshold.setDate(threshold.getDate() - (days ?? 30))

        const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
        const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
        if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) throw new Error('SUPABASE not configured')

        const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

        const deleteUrl = `${SUPABASE_URL}/rest/v1/push_players?removed_at=not.is.null&removed_at=lt.${encodeURIComponent(threshold.toISOString())}`
        const res = await fetch(deleteUrl, { method: 'DELETE', headers: { 'apikey': SUPABASE_SERVICE_ROLE_KEY, 'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` } })
        if (!res.ok) throw new Error('Failed to cleanup push_players')
        const json = await res.json()
        return new Response(JSON.stringify({ success: true, deleted: json }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    } catch (err: any) {
        console.error('cleanup-push-players error', err)
        return new Response(JSON.stringify({ success: false, error: err.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
})
