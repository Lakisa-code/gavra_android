// 🔒 SUPABASE EDGE FUNCTION - Send push notification (FCM + Huawei)
// Accepts: { title, body, data, driver_ids?, tokens? }
// Looks up `push_players` for driver_ids and groups tokens by provider (fcm|huawei)
// Sends FCM notifications using FCM_SERVER_KEY and Huawei using HUAWEI credentials.

// @ts-ignore
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
// @ts-ignore
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
// DJWT for signing JWT tokens from a PEM private key
// @ts-ignore
import { create, getNumericDate } from 'https://deno.land/x/djwt@v2.8/mod.ts'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Minimal Huawei token helper
async function getHuaweiAccessToken(env: Record<string, string>) {
    const appId = env['HUAWEI_APP_ID']
    const appSecret = env['HUAWEI_APP_SECRET']
    if (!appId || !appSecret) throw new Error('Huawei credentials not configured')

    const res = await fetch('https://oauth-login.cloud.huawei.com/oauth2/v3/token', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: `grant_type=client_credentials&client_id=${encodeURIComponent(appId)}&client_secret=${encodeURIComponent(appSecret)}`
    })
    const json = await res.json()
    return json.access_token
}

// Cache for FCM v1 token
let _fcmV1TokenCache: { access_token: string; expires_at: number } | null = null

// Convert PEM string to ArrayBuffer/Uint8Array
function pemToArrayBuffer(pem: string) {
    // Remove header, footer, line breaks
    const clean = pem.replace(/-----BEGIN (.*)-----/, '')
        .replace(/-----END (.*)----/, '')
        .replace(/\n/g, '')
        .replace(/\r/g, '')
        .trim()
    const binary = atob(clean)
    const len = binary.length
    const bytes = new Uint8Array(len)
    for (let i = 0; i < len; i++) bytes[i] = binary.charCodeAt(i)
    return bytes.buffer
}

async function getFcmV1AccessTokenFromServiceAccount(saJsonStr?: string) {
    if (!saJsonStr) throw new Error('GOOGLE_SERVICE_ACCOUNT_JSON not provided')
    try {
        const sa: any = JSON.parse(saJsonStr)
        const now = Math.floor(Date.now() / 1000)

        const header = { alg: 'RS256', typ: 'JWT' }
        const claims = {
            iss: sa.client_email,
            scope: 'https://www.googleapis.com/auth/firebase.messaging',
            aud: 'https://oauth2.googleapis.com/token',
            iat: now,
            exp: now + 3600
        }

        // Create CryptoKey from PEM
        const pkcs8 = pemToArrayBuffer(sa.private_key)
        const cryptoKey = await crypto.subtle.importKey('pkcs8', pkcs8, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'])

        const jwt = await create(header, claims, cryptoKey)

        const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${encodeURIComponent(jwt)}`
        })
        const tokenJson = await tokenRes.json()
        if (!tokenRes.ok) throw new Error(JSON.stringify(tokenJson))

        // tokenJson: { access_token, expires_in, token_type }
        const expiresAt = (Date.now() / 1000) + (tokenJson.expires_in || 3600)
        _fcmV1TokenCache = { access_token: tokenJson.access_token, expires_at: expiresAt }
        return tokenJson.access_token
    } catch (err) {
        console.error('Failed to generate FCM v1 token from service account', err)
        throw err
    }
}

async function getFcmV1AccessToken(env: Record<string, string>) {
    // Priority: Explicit env token > cached token > service account JSON
    const explicitToken = Deno.env.get('FCM_V1_ACCESS_TOKEN')
    if (explicitToken) return explicitToken
    // Use cached token if valid
    if (_fcmV1TokenCache && _fcmV1TokenCache.expires_at > (Date.now() / 1000) + 30) return _fcmV1TokenCache.access_token
    const saJson = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON')
    if (!saJson) throw new Error('FCM_V1_ACCESS_TOKEN not provided and GOOGLE_SERVICE_ACCOUNT_JSON not configured')
    return await getFcmV1AccessTokenFromServiceAccount(saJson)
}

serve(async (req: any) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const body = await req.json()
        const { title, body: msgBody, data, driver_ids, tokens } = body

        // 🔒 Secrets
        const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')
        const HUAWEI_APP_ID = Deno.env.get('HUAWEI_APP_ID')
        const HUAWEI_APP_SECRET = Deno.env.get('HUAWEI_APP_SECRET')
        const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
        const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

        if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
            throw new Error('SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not configured')
        }

        const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

        // Gather tokens from push_players if driver_ids are provided OR segment=All for global broadcast
        let pushRows: Array<any> = []

        if (driver_ids && Array.isArray(driver_ids) && driver_ids.length > 0) {
            const filter = `driver_id=in.(${driver_ids.map(String).join(',')})`;
            const url = `${SUPABASE_URL}/rest/v1/push_players?${encodeURIComponent(filter)}&select=driver_id,player_id,provider,platform&is_active=eq.true`
            const res = await fetch(url, {
                method: 'GET',
                headers: { 'apikey': SUPABASE_SERVICE_ROLE_KEY, 'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` }
            })
            if (!res.ok) throw new Error('Failed to lookup push players')
            pushRows = await res.json()
        }

        // If segment=All, select all active push players
        if (body.segment && body.segment.toLowerCase() === 'all') {
            const url = `${SUPABASE_URL}/rest/v1/push_players?is_active=eq.true&select=driver_id,player_id,provider,platform`;
            const res = await fetch(url, { method: 'GET', headers: { 'apikey': SUPABASE_SERVICE_ROLE_KEY, 'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` } });
            if (!res.ok) throw new Error('Failed to lookup push players for segment');
            const rows = await res.json();
            pushRows = pushRows.concat(rows);
        }

        // Direct tokens provided take precedence
        if (tokens && Array.isArray(tokens) && tokens.length > 0) {
            for (const t of tokens) {
                // Expected shape { token, provider }
                pushRows.push({ player_id: t.token, provider: t.provider ?? 'fcm', platform: t.platform ?? 'android' })
            }
        }

        if (pushRows.length === 0) {
            return new Response(JSON.stringify({ success: false, message: 'No target tokens found' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }

        // Group by provider
        const byProvider = pushRows.reduce((acc: Record<string, any[]>, row: any) => {
            acc[row.provider] = acc[row.provider] ?? []
            acc[row.provider].push(row.player_id)
            return acc
        }, {})

        // Collect results
        const results: Record<string, any> = {}

        // FCM send
        if (byProvider['fcm'] && byProvider['fcm'].length > 0) {
            if (!FCM_SERVER_KEY && !Deno.env.get('FCM_V1_ACCESS_TOKEN')) throw new Error('FCM_SERVER_KEY not configured')

            const fcmPayload = {
                registration_ids: byProvider['fcm'],
                notification: { title, body: msgBody },
                data: data || {}
            }

            // If a server-side OAuth token for FCM v1 is provided, use it
            let fcmV1AccessToken: string | null = null
            try {
                fcmV1AccessToken = await getFcmV1AccessToken(Deno.env)
            } catch (err) {
                // Logging but falling back to FCM server key is allowed below
                console.warn('Could not obtain FCM v1 token', err)
            }
            if (fcmV1AccessToken) {
                const fcmProjectId = Deno.env.get('FCM_PROJECT_ID')
                if (!fcmProjectId) {
                    console.warn('FCM_PROJECT_ID not configured; skipping FCM v1 send')
                } else {
                    try {
                        // We will send messages serially in v1 using messages:send endpoint
                        const v1Results: any[] = []
                        for (const token of byProvider['fcm']) {
                            const v1Payload = { message: { token, notification: { title, body: msgBody }, data: data || {} } }
                            const v1Res = await fetch(`https://fcm.googleapis.com/v1/projects/${Deno.env.get('FCM_PROJECT_ID')}/messages:send`, {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${fcmV1AccessToken}` },
                                body: JSON.stringify(v1Payload)
                            })
                            v1Results.push(await v1Res.json())
                        }
                        results['fcm_v1'] = v1Results
                    } catch (err) {
                        console.warn('FCM v1 send failed, falling back to legacy FCM', err)
                    }
                }

                const fcmRes = await fetch('https://fcm.googleapis.com/fcm/send', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `key=${FCM_SERVER_KEY}`
                    },
                    body: JSON.stringify(fcmPayload)
                })
                const fcmJson = await fcmRes.json()
                results['fcm'] = fcmJson

                // Save stats
                await supabase.from('notification_stats').insert({
                    type: 'fcm',
                    title,
                    target_type: 'driver_ids',
                    target_value: driver_ids ? driver_ids.join(',') : 'manual_tokens',
                    success_count: fcmJson.success || 0,
                    failure_count: fcmJson.failure || 0,
                    created_at: new Date().toISOString()
                })
            }

            // Huawei send
            if (byProvider['huawei'] && byProvider['huawei'].length > 0) {
                // Acquire Huawei access token
                const token = await getHuaweiAccessToken({ HUAWEI_APP_ID, HUAWEI_APP_SECRET })

                // Huawei messaging endpoint
                const messages = byProvider['huawei'].map((tokenId: string) => ({
                    token: tokenId,
                    notification: {
                        title: title,
                        body: msgBody
                    }
                }))

                // Huawei supports bulk only via batch call; we map sequential calls for brevity
                const sendResults: any[] = []
                for (const m of messages) {
                    const huRes = await fetch('https://push-api-cloud.huawei.com/v1/' + HUAWEI_APP_ID + '/messages:send', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'Authorization': `Bearer ${token}`
                        },
                        body: JSON.stringify({ message: { token: [m.token], notification: m.notification } })
                    })
                    const huJson = await huRes.json()
                    sendResults.push(huJson)
                }
                results['huawei'] = sendResults

                // Save stats - simplified counts
                await supabase.from('notification_stats').insert({
                    type: 'huawei',
                    title,
                    target_type: 'driver_ids',
                    target_value: driver_ids ? driver_ids.join(',') : 'manual_tokens',
                    success_count: Array.isArray(results['huawei']) ? results['huawei'].length : 0,
                    failure_count: 0,
                    created_at: new Date().toISOString()
                })
            }

            return new Response(JSON.stringify({ success: true, results }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

        } catch (err: any) {
            console.error('send-push-notification error', err)
            return new Response(JSON.stringify({ success: false, message: err.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }
    })
