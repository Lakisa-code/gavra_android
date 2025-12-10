// Supabase Edge Function (Deno) - send-push-notification
// Version: 2025-12-11-v3
// Receives JSON payload:
// { title, body, tokens: [{token, provider}] }
// or { title, body, topic: 'gavra_all_drivers' }
//
// Sends push notifications via FCM HTTP v1 API and Huawei Push API
// 
// HUAWEI CREDENTIALS:
// - Uses App ID (116046535) and App Secret from OAuth 2.0 client
// - NOT the agc-apiclient.json Project Client ID!

// Deno type declarations for VS Code
declare const Deno: {
    env: {
        get(key: string): string | undefined;
    };
};

// @ts-ignore - Deno imports
import { decodeBase64 } from "https://deno.land/std@0.208.0/encoding/base64.ts";
// @ts-ignore - Deno imports
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
// @ts-ignore - Deno imports
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Helper function for base64 decode
const base64Decode = (str: string): Uint8Array => decodeBase64(str)

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Cache for Google OAuth2 access token
let fcmAccessToken: string | null = null
let fcmTokenExpiry = 0

// Cache for Huawei OAuth2 access token  
let huaweiAccessToken: string | null = null
let huaweiTokenExpiry = 0

// Get Firebase service account from environment
function getFirebaseServiceAccount(): any | null {
    try {
        // Try plain JSON first
        let jsonStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')

        // Try Base64 encoded version
        if (!jsonStr) {
            const b64 = Deno.env.get('FCM_SERVICE_ACCOUNT_B64')
            if (b64) {
                const decoded = base64Decode(b64)
                jsonStr = new TextDecoder().decode(decoded)
            }
        }

        if (!jsonStr) return null
        return JSON.parse(jsonStr)
    } catch (e) {
        console.error('Failed to parse Firebase service account:', e)
        return null
    }
}

// Create JWT for Google OAuth2
async function createJwt(serviceAccount: any): Promise<string> {
    const header = { alg: 'RS256', typ: 'JWT' }
    const now = Math.floor(Date.now() / 1000)
    const payload = {
        iss: serviceAccount.client_email,
        sub: serviceAccount.client_email,
        aud: 'https://oauth2.googleapis.com/token',
        iat: now,
        exp: now + 3600,
        scope: 'https://www.googleapis.com/auth/firebase.messaging'
    }

    const encoder = new TextEncoder()
    const headerB64 = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
    const payloadB64 = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
    const unsignedToken = `${headerB64}.${payloadB64}`

    // Import private key and sign
    const pemHeader = '-----BEGIN PRIVATE KEY-----'
    const pemFooter = '-----END PRIVATE KEY-----'
    const pemContents = serviceAccount.private_key
        .replace(pemHeader, '')
        .replace(pemFooter, '')
        .replace(/\s/g, '')

    const binaryKey = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))

    const cryptoKey = await crypto.subtle.importKey(
        'pkcs8',
        binaryKey,
        { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
        false,
        ['sign']
    )

    const signature = await crypto.subtle.sign(
        'RSASSA-PKCS1-v1_5',
        cryptoKey,
        encoder.encode(unsignedToken)
    )

    const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
        .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

    return `${unsignedToken}.${signatureB64}`
}

// Get FCM access token using service account
async function getFcmAccessToken(): Promise<string | null> {
    const now = Date.now()
    if (fcmAccessToken && fcmTokenExpiry > now + 60000) {
        return fcmAccessToken
    }

    const serviceAccount = getFirebaseServiceAccount()
    if (!serviceAccount) {
        console.error('No Firebase service account configured')
        return null
    }

    try {
        const jwt = await createJwt(serviceAccount)

        const resp = await fetch('https://oauth2.googleapis.com/token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
        })

        if (!resp.ok) {
            const text = await resp.text()
            console.error('FCM token request failed:', text)
            return null
        }

        const data = await resp.json()
        fcmAccessToken = data.access_token
        fcmTokenExpiry = now + (data.expires_in * 1000)
        return fcmAccessToken
    } catch (e) {
        console.error('Failed to get FCM access token:', e)
        return null
    }
}

// Send FCM message via HTTP v1 API
async function sendFcmMessage(message: any): Promise<{ success: boolean, messageId?: string, error?: string }> {
    const accessToken = await getFcmAccessToken()
    if (!accessToken) {
        return { success: false, error: 'no-access-token' }
    }

    const serviceAccount = getFirebaseServiceAccount()
    if (!serviceAccount?.project_id) {
        return { success: false, error: 'no-project-id' }
    }

    try {
        const resp = await fetch(
            `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
            {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${accessToken}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ message })
            }
        )

        if (!resp.ok) {
            const text = await resp.text()
            console.error('FCM send failed:', text)
            return { success: false, error: text }
        }

        const data = await resp.json()
        return { success: true, messageId: data.name }
    } catch (e) {
        console.error('FCM send error:', e)
        return { success: false, error: String(e) }
    }
}

// Send to FCM topic
async function sendToFcmTopic(topic: string, title: string, body: string, data?: Record<string, string>): Promise<any> {
    const message: any = {
        topic: topic,
        notification: { title, body }
    }
    if (data) {
        // FCM data values must be strings
        message.data = Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, typeof v === 'string' ? v : JSON.stringify(v)])
        )
    }
    return await sendFcmMessage(message)
}

// Send to FCM token
async function sendToFcmToken(token: string, title: string, body: string, data?: Record<string, string>): Promise<any> {
    const message: any = {
        token: token,
        notification: { title, body }
    }
    if (data) {
        message.data = Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, typeof v === 'string' ? v : JSON.stringify(v)])
        )
    }
    return await sendFcmMessage(message)
}

// Get Huawei access token
async function getHuaweiAccessToken(): Promise<string | null> {
    const now = Date.now()
    if (huaweiAccessToken && huaweiTokenExpiry > now + 60000) {
        return huaweiAccessToken
    }

    try {
        // Use HMS App ID and App Secret (OAuth 2.0 client credentials)
        // These are from AGC Console > General information > OAuth 2.0 client ID
        const appId = Deno.env.get('HMS_APP_ID')
        const appSecret = Deno.env.get('HMS_APP_SECRET')

        if (!appId || !appSecret) {
            console.error('HMS_APP_ID or HMS_APP_SECRET not configured')
            return null
        }

        console.log('Requesting Huawei access token for App ID:', appId)

        const resp = await fetch('https://oauth-login.cloud.huawei.com/oauth2/v3/token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `grant_type=client_credentials&client_id=${encodeURIComponent(appId)}&client_secret=${encodeURIComponent(appSecret)}`
        })

        if (!resp.ok) {
            const errText = await resp.text()
            console.error('Huawei token request failed:', resp.status, errText)
            return null
        }

        const data = await resp.json()
        huaweiAccessToken = data.access_token
        huaweiTokenExpiry = now + (data.expires_in * 1000)
        console.log('Got Huawei access token, expires in', data.expires_in, 'seconds')
        return huaweiAccessToken
    } catch (e) {
        console.error('Huawei token error:', e)
        return null
    }
}

// Send to Huawei Push
async function sendToHuawei(token: string, title: string, body: string): Promise<any> {
    const accessToken = await getHuaweiAccessToken()
    if (!accessToken) {
        return { success: false, error: 'no-huawei-token' }
    }

    const appId = Deno.env.get('HMS_APP_ID')
    if (!appId) {
        return { success: false, error: 'no-hms-app-id' }
    }

    try {
        // Huawei Push requires android.notification for notification messages
        const resp = await fetch(`https://push-api.cloud.huawei.com/v1/${appId}/messages:send`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                message: {
                    android: {
                        notification: {
                            title: title,
                            body: body,
                            click_action: {
                                type: 3  // Open app
                            }
                        }
                    },
                    token: [token]
                }
            })
        })

        const text = await resp.text()
        return { success: resp.ok, status: resp.status, details: text }
    } catch (e) {
        return { success: false, error: String(e) }
    }
}

// Get all Huawei tokens from database
async function getHuaweiTokensFromDb(): Promise<string[]> {
    try {
        const supabaseUrl = Deno.env.get('SUPABASE_URL')
        const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

        if (!supabaseUrl || !serviceRoleKey) {
            console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY')
            return []
        }

        const supabase = createClient(supabaseUrl, serviceRoleKey)

        const { data, error } = await supabase
            .from('push_tokens')
            .select('token')
            .eq('provider', 'huawei')

        if (error) {
            console.error('Error fetching Huawei tokens:', error)
            return []
        }

        return (data || []).map((row: any) => row.token)
    } catch (e) {
        console.error('getHuaweiTokensFromDb error:', e)
        return []
    }
}

serve(async (req: Request) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { title, body, tokens, topic, data } = await req.json()

        if (!title || !body) {
            return new Response(
                JSON.stringify({ error: 'title and body required' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const results: any[] = []

        // 1. Send to FCM topic if provided
        if (topic) {
            const topicResult = await sendToFcmTopic(topic, title, body, data)
            results.push({ provider: 'fcm-topic', topic, ...topicResult })

            // 2. Also send to all Huawei devices from database (HMS doesn't support topics)
            const huaweiTokens = await getHuaweiTokensFromDb()
            console.log(`Found ${huaweiTokens.length} Huawei tokens in database`)

            for (const hmsToken of huaweiTokens) {
                const r = await sendToHuawei(hmsToken, title, body)
                results.push({ provider: 'huawei', ...r })
            }
        }

        // 3. Send to individual tokens if provided
        if (tokens && Array.isArray(tokens) && tokens.length > 0) {
            for (const t of tokens) {
                if (!t?.token || !t?.provider) continue

                if (t.provider === 'fcm') {
                    const r = await sendToFcmToken(t.token, title, body, data)
                    results.push({ provider: 'fcm', ...r })
                } else if (t.provider === 'huawei') {
                    const r = await sendToHuawei(t.token, title, body)
                    results.push({ provider: 'huawei', ...r })
                }
            }
        }

        // If no topic and no tokens, return error
        if (!topic && (!tokens || tokens.length === 0)) {
            return new Response(
                JSON.stringify({ error: 'topic or tokens required' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        console.log('Push notification results:', results)

        return new Response(
            JSON.stringify({ success: true, results }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    } catch (e) {
        console.error('Function error:', e)
        return new Response(
            JSON.stringify({ error: String(e) }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
