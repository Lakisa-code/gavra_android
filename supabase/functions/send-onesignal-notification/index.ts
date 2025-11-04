// 🔒 SUPABASE EDGE FUNCTION - Sigurno slanje OneSignal notifikacija
// Ova funkcija čuva OneSignal REST API ključ na server-side

// @ts-ignore
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// @ts-ignore
serve(async (req: any) => {
    // Preflight CORS zahtev
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { app_id, title, body, player_id, segment, data } = await req.json()

        // 🔒 OneSignal credentials - SIGURNO NA SERVER-SIDE!
        // @ts-ignore
        const ONESIGNAL_REST_KEY = Deno.env.get('ONESIGNAL_REST_KEY') || 'dymepwhpkubkfxhqhc4mlh2x7'

        if (!app_id || !title || !body) {
            return new Response(
                JSON.stringify({
                    success: false,
                    error: 'Missing required fields: app_id, title, body'
                }),
                {
                    status: 400,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                }
            )
        }

        // OneSignal API payload
        const payload = {
            app_id: app_id,
            headings: { en: title },
            contents: { en: body },
            ...(player_id && { include_player_ids: [player_id] }),
            ...(segment && { included_segments: [segment] }),
            ...(data && { data: data }),
        }

        console.log('🔔 Sending OneSignal notification:', { title, body, segment, player_id })

        // Pošalji OneSignal notifikaciju
        const oneSignalResponse = await fetch('https://onesignal.com/api/v1/notifications', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Basic ${ONESIGNAL_REST_KEY}`,
            },
            body: JSON.stringify(payload),
        })

        const oneSignalData = await oneSignalResponse.json()

        if (oneSignalResponse.ok) {
            console.log('✅ OneSignal notification sent successfully:', oneSignalData.id)

            return new Response(
                JSON.stringify({
                    success: true,
                    notification_id: oneSignalData.id,
                    recipients: oneSignalData.recipients
                }),
                {
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                }
            )
        } else {
            console.error('❌ OneSignal API error:', oneSignalData)

            return new Response(
                JSON.stringify({
                    success: false,
                    error: 'OneSignal API error',
                    details: oneSignalData
                }),
                {
                    status: 500,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                }
            )
        }

    } catch (error: any) {
        console.error('🚨 Edge Function error:', error)

        return new Response(
            JSON.stringify({
                success: false,
                error: 'Internal server error',
                message: error?.message || 'Unknown error'
            }),
            {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            }
        )
    }
})