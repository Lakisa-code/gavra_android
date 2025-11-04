// 🔥 SUPABASE EDGE FUNCTION - FCM Server Integration
// Šalje Firebase Cloud Messaging notifikacije sa servera

// @ts-ignore
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
// @ts-ignore
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// @ts-ignore
serve(async (req: any) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { title, body, data, target } = await req.json()

        // 🔒 Firebase Server Key - SIGURNO NA SERVER-SIDE!
        // @ts-ignore
        const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')
        const FCM_PROJECT_ID = 'gavra-notif-20250920162521'

        if (!FCM_SERVER_KEY) {
            throw new Error('FCM_SERVER_KEY not configured')
        }

        // 🎯 TARGETING OPTIONS:
        let fcmPayload

        if (target.type === 'token') {
            // Pošalji specific device token
            fcmPayload = {
                to: target.value,
                notification: { title, body },
                data: data || {},
            }
        } else if (target.type === 'topic') {
            // Pošalji svim pretplatnicima na topic (npr. 'gavra_all_drivers')
            fcmPayload = {
                to: `/topics/${target.value}`,
                notification: { title, body },
                data: data || {},
            }
        } else if (target.type === 'condition') {
            // Pošalji na osnovu uslova (npr. "'gavra_driver_bojan' in topics")
            fcmPayload = {
                condition: target.value,
                notification: { title, body },
                data: data || {},
            }
        } else {
            throw new Error('Invalid target type. Use: token, topic, or condition')
        }

        console.log('🔥 Sending FCM notification:', { title, body, target })

        // 📡 POŠALJI FCM NOTIFIKACIJU
        const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `key=${FCM_SERVER_KEY}`,
            },
            body: JSON.stringify(fcmPayload),
        })

        const fcmData = await fcmResponse.json()

        if (fcmResponse.ok && fcmData.success >= 0) {
            console.log('✅ FCM notification sent:', {
                success: fcmData.success,
                failure: fcmData.failure,
                multicast_id: fcmData.multicast_id
            })

            // 📊 OPTIONAL: Save delivery stats to database
            // @ts-ignore
            const supabase = createClient(
                // @ts-ignore
                Deno.env.get('SUPABASE_URL') ?? '',
                // @ts-ignore
                Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
            )

            await supabase.from('notification_stats').insert({
                type: 'fcm',
                title: title,
                target_type: target.type,
                target_value: target.value,
                success_count: fcmData.success || 0,
                failure_count: fcmData.failure || 0,
                multicast_id: fcmData.multicast_id,
                created_at: new Date().toISOString(),
            })

            return new Response(
                JSON.stringify({
                    success: true,
                    fcm_success: fcmData.success,
                    fcm_failure: fcmData.failure,
                    multicast_id: fcmData.multicast_id
                }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        } else {
            console.error('❌ FCM API error:', fcmData)

            return new Response(
                JSON.stringify({
                    success: false,
                    error: 'FCM API error',
                    details: fcmData
                }),
                {
                    status: 500,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                }
            )
        }

    } catch (error: any) {
        console.error('🚨 FCM Edge Function error:', error)

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